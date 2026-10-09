-- TycoonService
-- Gives each player a plot and keeps its 3D world in sync with their save:
-- workers (your friends' avatars!) appear when hired, Cores light up, displayed Verities float on their
-- pedestals, the barn door opens when unlocked, and the held egg/Verity sits in your hand.
-- (Upgrades happen through the E prompts; the client calls the "upgrade" action.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Actions = require(Shared:WaitForChild("Actions"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local WorkerAvatars = require(script.Parent:WaitForChild("WorkerAvatars"))

local TycoonService = {}

local ctx = nil -- { DataService, notify }
local plots = {} -- array of plot records
local plotByPlayer = {} -- [Player] = plot record
local zones = {} -- bump areas (the locked door): { part, plot, kind, roomId }
local inside = {} -- [zone] = { [Player] = true }

local STAFFED_COLOR = Color3.fromHex("#FFD84D")
local IDLE_COLOR = Color3.fromHex("#5B5F73")
local MAT_HIRED = Color3.fromHex("#4CD07D")
local MAT_EMPTY = Color3.fromHex("#5B5F73")
local INK = Color3.fromHex("#2B2140")
local HOLD_GRIP = CFrame.new(0, 0, -0.9) -- where a held egg / Verity sits relative to the hand

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function setVisible(model: Instance, visible: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("BaseTransparency") == nil then
				d:SetAttribute("BaseTransparency", d.Transparency)
			end
			d.Transparency = if visible then d:GetAttribute("BaseTransparency") else 1
		end
	end
end

local function tierLabelColor(tier: string): string
	if tier == "unknown" then
		return "#C04CFF"
	end
	local info = Config.TIER_INFO[tier]
	return if info then info.color else "#FFFFFF"
end

---------------------------------------------------------------------------
-- Reading a plot model into a record
---------------------------------------------------------------------------
local function addZone(zone)
	table.insert(zones, zone)
	inside[zone] = {}
end

local function parsePlot(model: Model, index: number)
	local rec = { model = model, index = index, owner = nil, rooms = {}, slots = {}, friends = nil, friendSlot = {} }
	-- each station gets its own friend: house 1-4 are friends 1-4, the barn's are 5-8, ...
	local n = 0
	for _, roomId in Config.ROOM_ORDER do
		for i = 1, #Config.ROOMS[roomId].stations do
			n += 1
			rec.friendSlot[roomId .. ":" .. i] = n
		end
	end
	rec.spawn = model:FindFirstChild("Spawn")
	rec.ownerLabel = model:FindFirstChild("OwnerLabel", true)
	rec.barnLabel = model:FindFirstChild("BarnLabel", true)

	for _, room in model.Rooms:GetChildren() do
		local roomId = room:GetAttribute("RoomId")
		local roomRec = { model = room, stations = {} }
		for _, st in room.Stations:GetChildren() do
			local i = st:GetAttribute("StationIndex")
			roomRec.stations[i] = {
				model = st,
				orb = st.Orb,
				light = st.Orb:FindFirstChildOfClass("PointLight"),
				spot = st.WorkerSpot,
				mat = st:FindFirstChild("Mat"),
			}
		end
		local door = room:FindFirstChild("Door")
		if door then
			local panel = door.Panel
			local w = panel.Size.X
			local closed = panel.CFrame
			roomRec.door = {
				model = door,
				panel = panel,
				lock = door.Lock,
				boards = door.Boards,
				closedCF = closed,
				-- hinge on the left edge, swing inward
				openCF = closed * CFrame.new(-w / 2, 0, 0) * CFrame.Angles(0, math.rad(-100), 0) * CFrame.new(w / 2, 0, 0),
				open = nil,
			}
			addZone({ part = door.BumpZone, plot = rec, kind = "door", roomId = roomId })
		end
		rec.rooms[roomId] = roomRec
	end

	for _, slot in model.Display:GetChildren() do
		local i = slot:GetAttribute("SlotIndex")
		local info = slot.Top:FindFirstChild("Info")
		-- keep the label readable up close instead of filling the screen
		if info and info:FindFirstChild("Label") and not info.Label:FindFirstChildOfClass("UITextSizeConstraint") then
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = 30
			cap.Parent = info.Label
		end
		rec.slots[i] = {
			model = slot,
			anchor = slot.Anchor,
			lock = slot.Lock,
			infoLabel = info and info.Label,
			prompt = slot.Top:FindFirstChild("PedestalPrompt"),
		}
	end
	return rec
end

---------------------------------------------------------------------------
-- Keeping the 3D world in sync with a save (data = nil means vacant)
---------------------------------------------------------------------------
-- Puts a worker at a station: a stand-in ball right away, then the friend's avatar once it loads
local function placeWorker(stRec, friend)
	local token = {}
	stRec.token = token
	local placeholder = ModelFactory.worker()
	placeholder.Name = "Worker"
	placeholder:SetAttribute("FriendId", if friend then friend.id else 0)
	placeholder:PivotTo(stRec.spot.CFrame * CFrame.new(0, ModelFactory.WORKER_FLOOR_OFFSET, 0))
	CollectionService:AddTag(placeholder, "VerityWorker")
	placeholder.Parent = stRec.model
	if not friend then
		return
	end
	task.spawn(function()
		local rig = WorkerAvatars.rig(friend.id)
		if stRec.token ~= token or not rig then
			if rig then
				rig:Destroy()
			end
			return
		end
		local current = stRec.model:FindFirstChild("Worker")
		if current then
			current:Destroy()
		end
		rig.Name = "Worker"
		rig:SetAttribute("FriendId", friend.id)
		rig:PivotTo(stRec.spot.CFrame * CFrame.new(0, WorkerAvatars.floorOffset(rig), 0))
		CollectionService:AddTag(rig, "FriendWorker")
		rig.Parent = stRec.model
		WorkerAvatars.playIdle(rig)
	end)
end

local function setStation(stRec, level: number, friend)
	local hired = level > 0
	stRec.model:SetAttribute("Level", level) -- every client reads this for the floating panel
	stRec.model:SetAttribute("WorkerName", if hired and friend then friend.name else nil)
	local orb = stRec.orb
	orb:SetAttribute("Staffed", hired)
	if hired then
		orb.Color = STAFFED_COLOR
		orb.Material = Enum.Material.Neon
		orb.Transparency = 0
	else
		orb.Color = IDLE_COLOR
		orb.Material = Enum.Material.SmoothPlastic
		orb.Transparency = 0.35
	end
	if stRec.light then
		stRec.light.Enabled = hired
	end
	if stRec.mat then
		stRec.mat.Color = if hired then MAT_HIRED else MAT_EMPTY
	end

	local worker = stRec.model:FindFirstChild("Worker")
	local wantId = if friend then friend.id else 0
	if hired then
		if not worker or worker:GetAttribute("FriendId") ~= wantId then
			if worker then
				worker:Destroy()
			end
			placeWorker(stRec, friend)
		end
	else
		stRec.token = nil
		if worker then
			worker:Destroy()
		end
	end
end

local function setDoor(door, unlocked: boolean)
	if door.open == unlocked then
		return
	end
	door.open = unlocked
	if unlocked then
		door.lock.Parent = nil
		door.boards.Parent = nil
		door.panel.CanCollide = false
		TweenService:Create(door.panel, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = door.openCF }):Play()
	else
		door.panel.CFrame = door.closedCF
		door.panel.CanCollide = true
		door.lock.Parent = door.model
		door.boards.Parent = door.model
	end
end

local function refreshSlot(i: number, slot, data)
	local equipped = if data then data.slots.equipped else {}
	local owned = if data then #equipped else Config.STARTING_DISPLAY_SLOTS
	local state = "locked"
	if i <= owned then
		state = "active"
	elseif data and i == owned + 1 and Actions.nextSlotInfo(data) then
		state = "buyable"
	end

	local verity = nil
	if state == "active" and data and equipped[i] ~= "" then
		local _, v = Actions.findVerity(data, equipped[i])
		verity = v
	end
	local current = slot.model:FindFirstChild("DisplayVerity")
	if current and (not verity or current:GetAttribute("VerityId") ~= verity.id) then
		current:Destroy()
		current = nil
	end
	if verity and not current then
		local m = ModelFactory.verity(verity.variant, 4)
		m.Name = "DisplayVerity"
		m:SetAttribute("VerityId", verity.id)
		m:PivotTo(slot.anchor.CFrame)
		local variant = Config.VARIANTS[verity.variant]
		local tier = Config.TIER_INFO[verity.tier]
		-- three lines, like "Ice Maker / x4 income / Lemon Stand"
		local gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.fromScale(8, 4)
		gui.StudsOffset = Vector3.new(0, 4.6, 0)
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		gui.Adornee = m.PrimaryPart
		-- { text, colour, y, height, biggest text size up close }
		local lines = {
			{ variant and variant.displayName or "???", "#FFD23F", 0, 0.32, 32 },
			{ Economy.formatMultiplier(Economy.verityMultiplier(verity.variant)) .. " income", "#5BF26B", 0.3, 0.44, 44 },
			{ tier and tier.displayName or "", tierLabelColor(verity.tier), 0.74, 0.24, 24 },
		}
		for _, line in lines do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0, line[3])
			label.Size = UDim2.fromScale(1, line[4])
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.Text = line[1]
			label.TextColor3 = Color3.fromHex(line[2])
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = INK
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = line[5]
			cap.Parent = label
			label.Parent = gui
		end
		gui.Parent = m.PrimaryPart
		CollectionService:AddTag(m, "DisplayVerity")
		m.Parent = slot.model
	end

	setVisible(slot.lock, state ~= "active")
	slot.model:SetAttribute("State", state)

	if slot.prompt then
		slot.prompt.ObjectText = "Slot " .. i
		if state == "active" then
			slot.prompt.ActionText = if verity then "Swap Verity" else "Display Verity"
		elseif state == "buyable" then
			slot.prompt.ActionText = "Unlock Slot"
		else
			slot.prompt.ActionText = "Locked"
		end
	end

	if slot.infoLabel then
		if state == "buyable" then
			local info = Actions.nextSlotInfo(data)
			slot.infoLabel.Text = string.format(
				'<font color="#FFD23F">Unlock slot %d</font>\n%d quests + %s coins',
				i,
				info.questsRequired,
				Economy.formatCoins(info.cost)
			)
		elseif state == "locked" then
			slot.infoLabel.Text = if data then "Locked" else ""
		elseif not verity and data then
			slot.infoLabel.Text = '<font color="#FFF7E3">Empty slot</font>'
		else
			slot.infoLabel.Text = ""
		end
	end
end

local function refreshPlot(rec, data)
	local owner = rec.owner
	if rec.ownerLabel then
		rec.ownerLabel.Text = if owner then owner.DisplayName .. "'s House" else "Vacant"
	end
	if rec.barnLabel then
		rec.barnLabel.Text = if owner then owner.DisplayName .. "'s Barn" else "The Barn"
	end
	rec.model:SetAttribute("OwnerUserId", if owner then owner.UserId else nil)
	rec.model:SetAttribute("Multiplier", if data then Economy.displayMultiplier(data) else 1)
	for roomId, roomDef in Config.ROOMS do
		local roomRec = rec.rooms[roomId]
		if roomRec then
			local roomData = data and data.rooms[roomId]
			local unlocked = if roomData then roomData.unlocked else roomDef.startsUnlocked == true
			roomRec.model:SetAttribute("Unlocked", unlocked and data ~= nil)
			for i, stRec in roomRec.stations do
				local level = if roomData and unlocked then (roomData.levels[i] or 0) else 0
				local friend = rec.friends and rec.friends[rec.friendSlot[roomId .. ":" .. i]]
				setStation(stRec, level, friend)
			end
			if roomRec.door then
				setDoor(roomRec.door, unlocked and data ~= nil)
			end
		end
	end
	for i, slot in rec.slots do
		refreshSlot(i, slot, data)
	end
end

---------------------------------------------------------------------------
-- The egg or Verity in the player's hand is a Tool, so the arm holds it out
---------------------------------------------------------------------------
local function heldKey(data)
	local hand = data and data.hand
	if not hand then
		return "", nil
	end
	if hand.kind == "egg" then
		local _, egg = Actions.findEgg(data, hand.id)
		if egg then
			return "egg:" .. egg.id .. ":" .. egg.type, egg
		end
	else
		local _, v = Actions.findVerity(data, hand.id)
		if v then
			return "verity:" .. v.id .. ":" .. v.variant, v
		end
	end
	return "", nil
end

local function refreshHeld(player: Player, data)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local key, item = heldKey(data)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local current = char:FindFirstChild("HeldItem") or (backpack and backpack:FindFirstChild("HeldItem"))
	if current and current:GetAttribute("Key") == key then
		if current.Parent ~= char then
			humanoid:EquipTool(current)
		end
		return
	end
	if current then
		current:Destroy()
	end
	if key == "" or not backpack then
		return
	end

	local model = if data.hand.kind == "egg" then ModelFactory.egg(item.type, 1.5) else ModelFactory.verity(item.variant, 1.7)
	ModelFactory.makeHoldable(model)
	local tool = Instance.new("Tool")
	tool.Name = "HeldItem"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	-- push the item out by its own radius so a big Verity never clips through the hand
	local radius = model:GetExtentsSize().Magnitude / 2 / 1.2
	tool.Grip = CFrame.new(0, 0, -(radius + 0.5))
	tool:SetAttribute("Key", key)
	model.PrimaryPart.Name = "Handle"
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

---------------------------------------------------------------------------
-- Bumping into the locked door
---------------------------------------------------------------------------
local function zoneContains(part: BasePart, pos: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X + 0.6 and math.abs(p.Z) <= half.Z + 0.6 and p.Y >= -half.Y - 1 and p.Y <= half.Y + 6
end

local function onZoneEnter(player: Player, zone)
	local rec = zone.plot
	if zone.kind ~= "door" then
		return
	end
	local roomDef = Config.ROOMS[zone.roomId]
	if rec.owner ~= player then
		local roomRec = rec.rooms[zone.roomId]
		if not (roomRec and roomRec.door and roomRec.door.open) then
			local text = if rec.owner
				then rec.owner.DisplayName .. " hasn't opened their " .. roomDef.displayName:lower() .. " yet."
				else "Nobody lives here yet."
			ctx.notify(player, "Toast", { text = text, kind = "info" })
		end
		return
	end
	local data = ctx.DataService.get(player)
	local req = data and Actions.roomRequirements(data, zone.roomId)
	if req and not req.unlocked then
		ctx.notify(player, "RoomLocked", { roomId = zone.roomId, req = req })
	end
end

local function zoneLoop()
	while true do
		task.wait(0.1)
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			local alive = root ~= nil and humanoid ~= nil and humanoid.Health > 0
			for _, zone in zones do
				local set = inside[zone]
				local isIn = alive and zoneContains(zone.part, root.Position)
				if isIn and not set[player] then
					set[player] = true
					task.spawn(onZoneEnter, player, zone)
				elseif not isIn and set[player] then
					set[player] = nil
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Players and plots
---------------------------------------------------------------------------
local function spawnCFrame(rec): CFrame?
	return rec and rec.spawn and rec.spawn.CFrame * CFrame.new(0, 3.5, 0)
end

local function onCharacter(player: Player, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	local cf = spawnCFrame(plotByPlayer[player])
	if root and cf then
		task.wait()
		char:PivotTo(cf)
	end
	char:WaitForChild("Humanoid", 5)
	task.wait(0.5)
	if char.Parent then
		refreshHeld(player, ctx.DataService.get(player))
	end
end

function TycoonService.init(context)
	ctx = context
	local template = ServerStorage:WaitForChild("TycoonTemplate")
	local anchorFolder = workspace:WaitForChild("PlotAnchors")
	local old = workspace:FindFirstChild("Plots")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	local anchors = anchorFolder:GetChildren()
	table.sort(anchors, function(a, b)
		return a.Name < b.Name
	end)
	for i, anchor in anchors do
		local model = template:Clone()
		model.Name = "Plot" .. i
		model:PivotTo(anchor.CFrame)
		model.Parent = folder
		local rec = parsePlot(model, i)
		table.insert(plots, rec)
		refreshPlot(rec, nil)
	end
	folder.Parent = workspace
	task.spawn(zoneLoop)
end

function TycoonService.assign(player: Player)
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	local rec = nil
	for _, candidate in plots do
		if not candidate.owner then
			rec = candidate
			break
		end
	end
	if not rec then
		warn("[TycoonService] No free plot for " .. player.Name)
		return nil
	end
	rec.owner = player
	rec.friends = nil
	plotByPlayer[player] = rec
	player:SetAttribute("Plot", rec.model.Name)
	refreshPlot(rec, nil)
	task.spawn(function()
		local friends = WorkerAvatars.friendsOf(player)
		if plotByPlayer[player] == rec then
			rec.friends = friends
			TycoonService.refresh(player)
		end
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	return rec
end

function TycoonService.unassign(player: Player)
	for _, set in inside do
		set[player] = nil
	end
	local rec = plotByPlayer[player]
	if not rec then
		return
	end
	plotByPlayer[player] = nil
	rec.owner = nil
	rec.friends = nil
	refreshPlot(rec, nil)
end

-- Call after any change to the player's save
function TycoonService.refresh(player: Player)
	local data = ctx.DataService.get(player)
	local rec = plotByPlayer[player]
	if rec then
		refreshPlot(rec, data)
	end
	refreshHeld(player, data)
end

-- The friend at a station waves after an upgrade
function TycoonService.celebrate(player: Player, roomId: string, index: number)
	local rec = plotByPlayer[player]
	local roomRec = rec and rec.rooms[roomId]
	local stRec = roomRec and roomRec.stations[index]
	local worker = stRec and stRec.model:FindFirstChild("Worker")
	if worker and worker:FindFirstChildOfClass("Humanoid") then
		WorkerAvatars.wave(worker)
	end
end

function TycoonService.goHome(player: Player): boolean
	local cf = spawnCFrame(plotByPlayer[player])
	local char = player.Character
	if not cf or not char or not char:FindFirstChild("HumanoidRootPart") then
		return false
	end
	char:PivotTo(cf)
	return true
end

return TycoonService
