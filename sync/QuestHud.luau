-- QuestHud: the "Next goal" card in the top-left corner, and the green arrow that goes with it.
-- Reads the current quest and objective from your save (data.quests) so it always matches the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared:WaitForChild("Quests"))
local QuestTargets = require(Shared:WaitForChild("QuestTargets"))

local Theme = require(script.Parent.Theme)
local Gui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local Format = require(script.Parent.Format)
local Guide = require(script.Parent.Guide)

local QuestHud = {}

QuestHud.onFinale = nil -- set by Main: starts the ending

-- which spot the arrow should point to for each kind of objective
local function guideKey(obj, data): (string?, number?)
	local k = obj.kind
	if k == "goto" then
		return obj.target, obj.radius
	elseif k == "display" then
		return "display:1", 9
	elseif k == "buyEgg" then
		return "shop", 12
	elseif k == "level" then
		return "station:house:1", 10
	elseif k == "unlock" then
		return "barnDoor", 8
	elseif k == "hire" then
		-- the next worker you haven't hired yet
		for _, room in { "house", "barn" } do
			local state = data.rooms[room]
			if state and state.unlocked then
				for i, level in state.levels do
					if level == 0 then
						return "station:" .. room .. ":" .. i, 10
					end
				end
			end
		end
	end
	return nil, nil
end

function QuestHud.init()
	local root = Gui.layer("Hud", 1, false)
	local holder, face = Theme.card({
		Name = "NextGoal",
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.fromOffset(320, 112),
		Radius = 24,
		Top = Color3.fromHex("#4A3FB0"),
		Bottom = Color3.fromHex("#1E1752"),
		Visible = false,
		Parent = root,
	})
	local tag = Theme.text({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.fromOffset(200, 18),
		Text = "NEXT GOAL",
		Font = Theme.Chunky,
		TextColor3 = Theme.C.Yellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Outline = 2,
		Parent = face,
	})
	local title = Theme.text({
		Position = UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -32, 0, 28),
		Font = Theme.Chunky,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Outline = 3,
		Parent = face,
	})
	local objective = Theme.text({
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromHex("#E6E1FF"),
		MaxTextSize = 19,
		Outline = false,
		Parent = face,
	})
	local barBack = Theme.make("Frame", {
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -32, 0, 14),
		BackgroundColor3 = Color3.fromHex("#120D33"),
		Parent = face,
	}, { Theme.corner(7), Theme.stroke(Theme.C.Line, 2.5) })
	local barFill = Theme.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromHex("#3DFF6A"),
		BorderSizePixel = 0,
		Parent = barBack,
	}, { Theme.corner(7), Theme.gradient(Color3.fromHex("#9BFF7A"), Color3.fromHex("#2AD13B"), 90) })
	local begin = Theme.button({
		Text = "BEGIN",
		Size = UDim2.fromOffset(120, 40),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -10),
		Color = Theme.C.Green,
		Deep = Theme.C.GreenDeep,
		Visible = false,
		Parent = face,
		OnClick = function()
			if QuestHud.onFinale then
				QuestHud.onFinale()
			end
		end,
	})

	local function refresh(data)
		if not data or not data.flags.introSeen or data.quests.activeId == "" then
			holder.Visible = false
			Guide.setTarget(nil)
			return
		end
		local def = Quests.defs[data.quests.activeId]
		local obj = def and def.objectives[data.quests.step]
		if not def or not obj then
			holder.Visible = false
			Guide.setTarget(nil)
			return
		end
		holder.Visible = true
		title.Text = def.displayName
		local done, have, need = Quests.check(obj, data)
		local text = obj.text
		if need and need > 1 and obj.kind ~= "coins" then
			text ..= "  (" .. have .. "/" .. need .. ")"
		end
		objective.Text = text
		barBack.Visible = need ~= nil and need > 1
		local frac = if need and need > 0 then have / need else 0
		barFill.Size = UDim2.fromScale(math.clamp(frac, 0.02, 1), 1)
		if obj.kind == "coins" then
			objective.Text = obj.text .. "  (" .. Format.coins(math.floor(State.coins())) .. ")"
		end
		begin.Holder.Visible = obj.kind == "finale"

		local key, radius = guideKey(obj, data)
		local pos = key and QuestTargets.position(State.plot(), key)
		Guide.setTarget(pos, radius)
	end

	State.Changed:Connect(refresh)
	refresh(State.data)
	-- the plot loads a moment after the save; aim again once it exists
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(1)
			if State.plot() then
				refresh(State.data)
				break
			end
		end
	end)
end

return QuestHud
