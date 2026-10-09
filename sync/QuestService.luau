-- QuestService: runs the questline for every player.
-- Quests start one after another once the opening cutscene has been seen. Each quest is a list of
-- objectives (see Shared/Quests). Everything except "reach a place" is read straight from the save.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Actions = require(Shared:WaitForChild("Actions"))
local Quests = require(Shared:WaitForChild("Quests"))
local QuestTargets = require(Shared:WaitForChild("QuestTargets"))

local QuestService = {}
local ctx

local function plotOf(player: Player): Instance?
	local name = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	return name and plots and plots:FindFirstChild(name)
end

local function reached(player: Player, obj): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pos = QuestTargets.position(plotOf(player), obj.target)
	if not root or not pos then
		return false
	end
	local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
	return flat.Magnitude <= (obj.radius or 10)
end

local function objectiveDone(player: Player, data, obj): boolean
	if obj.kind == "goto" then
		return reached(player, obj)
	elseif obj.kind == "finale" then
		return (data.flags.endingChoice or "") ~= ""
	end
	return (Quests.check(obj, data))
end

local function finish(player: Player, data, questId: string, def)
	Actions.completeQuest(data, questId)
	local reward = def.reward or {}
	if reward.coins then
		Actions.addCoins(data, reward.coins)
	end
	local gotEgg = nil
	if reward.egg and Actions.grantEgg(data, reward.egg) then
		gotEgg = reward.egg
	end
	data.quests.activeId = ""
	data.quests.step = 0
	ctx.notify(player, "QuestDone", { id = questId, coins = reward.coins or 0, egg = gotEgg })
	if def.outro then
		ctx.notify(player, "Dialogue", { id = def.outro })
	end
end

-- Returns true if anything in the save changed
local function advance(player: Player, data): boolean
	local q = data.quests
	local changed = false

	-- a dev command may have completed the active quest behind our back
	if q.activeId ~= "" and q.completed[q.activeId] then
		q.activeId, q.step = "", 0
		changed = true
	end

	if q.activeId == "" then
		local nextId = Quests.nextId(data)
		if not nextId then
			return changed
		end
		q.activeId, q.step, q.progress = nextId, 1, 0
		ctx.notify(player, "QuestStarted", { id = nextId })
		local intro = Quests.defs[nextId].intro
		if intro then
			ctx.notify(player, "Dialogue", { id = intro })
		end
		changed = true
	end

	local def = Quests.defs[q.activeId]
	if not def then
		q.activeId, q.step = "", 0
		return true
	end
	while q.step >= 1 and q.step <= #def.objectives do
		local obj = def.objectives[q.step]
		if not objectiveDone(player, data, obj) then
			return changed
		end
		if obj.dialogue then
			ctx.notify(player, "Dialogue", { id = obj.dialogue })
		end
		q.step += 1
		changed = true
	end
	if q.step > #def.objectives then
		finish(player, data, q.activeId, def)
		changed = true
	end
	return changed
end

-- Called from actions
function QuestService.introSeen(data)
	if data.flags.introSeen then
		return true
	end
	data.flags.introSeen = true
	if not data.flags.starterEggGranted and Actions.grantEgg(data, "starter") then
		data.flags.starterEggGranted = true
	end
	return true
end

function QuestService.chooseEnding(data, choice)
	local q = data.quests
	if q.activeId ~= "where_do_i_belong" then
		return false, "NotReady"
	end
	if choice ~= "backrooms" and choice ~= "blocklands" then
		return false, "InvalidArgs"
	end
	if (data.flags.endingChoice or "") ~= "" then
		return false, "AlreadyChosen"
	end
	data.flags.endingChoice = choice
	return true
end

function QuestService.init(context)
	ctx = context
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local data = ctx.DataService.get(player)
				if data and data.flags.introSeen then
					local ok, changed = pcall(advance, player, data)
					if not ok then
						warn("[QuestService] " .. tostring(changed))
					elseif changed then
						ctx.DataService.markChanged(player)
						ctx.DataService.requestSave(player)
					end
				end
			end
		end
	end)
end

return QuestService
