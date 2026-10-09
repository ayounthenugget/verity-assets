-- DialogueBox: the talking box at the bottom of the screen, and cutscene subtitles.
--   DialogueBox.play(lines)        shows each line with a typewriter and a blip voice; waits for taps
--   DialogueBox.subtitle(...)      a non-interactive subtitle strip (used in cutscenes)
-- Tap / click / E / Space / Enter moves on. Works with touch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dialogue = require(Shared:WaitForChild("Dialogue"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))

local Theme = require(script.Parent.Theme)
local Gui = require(script.Parent.Gui)
local Viewport = require(script.Parent.Viewport)
local Voice = require(script.Parent.Voice)

local DialogueBox = {}

local CHAR_DELAY = 0.032
local ui = nil -- built on first use
local busy = false
local queue = {}

local function speakerColor(who: string): Color3
	local def = Dialogue.speakers[who]
	return Color3.fromHex(def and def.color or "#FFFFFF")
end

local function buildPortraitModel(who: string)
	local model
	if who == "Farmer" then
		model = ModelFactory.farmer(3)
	else
		model = ModelFactory.verity(nil, 3)
		if who == "???" then
			local body = model.PrimaryPart
			body.Color = Color3.fromHex("#7CF0FF")
			body.Transparency = 0.35
		end
	end
	return model
end

local function build()
	local root = Gui.layer("Dialogue", 60, true)

	-- catches taps anywhere on screen while a line is showing
	local tap = Theme.make("TextButton", {
		Name = "Tap",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 1,
		Parent = root,
	})

	local holder, face = Theme.card({
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -26),
		Size = UDim2.fromOffset(860, 176),
		Radius = 28,
		Top = Color3.fromHex("#3A2F8F"),
		Bottom = Color3.fromHex("#1B1442"),
		Visible = false,
		ZIndex = 2,
		Parent = root,
	})
	local portraitFrame = Theme.make("Frame", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(148, 148),
		BackgroundColor3 = Color3.fromHex("#FFE9A0"),
		ZIndex = 3,
		Parent = face,
	}, { Theme.corner(24), Theme.stroke(Theme.C.Line, 4), Theme.gradient(Color3.fromHex("#FFF4C2"), Color3.fromHex("#FFC94A"), 90) })
	local vpf = Theme.make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = portraitFrame,
	})
	local nameTag = Theme.text({
		Position = UDim2.fromOffset(184, 12),
		Size = UDim2.fromOffset(400, 32),
		Font = Theme.Chunky,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Outline = 3,
		ZIndex = 3,
		Parent = face,
	})
	local body = Theme.text({
		Position = UDim2.fromOffset(184, 50),
		Size = UDim2.new(1, -208, 0, 94),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromHex("#FFFFFF"),
		MaxTextSize = 28,
		Outline = false,
		ZIndex = 3,
		Parent = face,
	})
	local prompt = Theme.text({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -10),
		Size = UDim2.fromOffset(150, 24),
		Text = "TAP  ▶",
		Font = Theme.Chunky,
		TextColor3 = Theme.C.Yellow,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 20,
		Outline = 2,
		Visible = false,
		ZIndex = 3,
		Parent = face,
	})

	-- subtitles for cutscenes: a slim strip near the bottom
	local sub = Theme.make("Frame", {
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.fromOffset(820, 74),
		BackgroundColor3 = Color3.fromHex("#0A0720"),
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 40,
		Parent = root,
	}, { Theme.corner(18), Theme.stroke(Theme.C.Line, 3, 0.3) })
	local subName = Theme.text({
		Position = UDim2.fromOffset(18, 6),
		Size = UDim2.fromOffset(300, 22),
		Font = Theme.Chunky,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Outline = 2,
		ZIndex = 41,
		Parent = sub,
	})
	local subText = Theme.text({
		Position = UDim2.fromOffset(18, 30),
		Size = UDim2.new(1, -36, 0, 38),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 26,
		Outline = 2,
		ZIndex = 41,
		Parent = sub,
	})

	ui = { root = root, tap = tap, holder = holder, vpf = vpf, name = nameTag, body = body, prompt = prompt, sub = sub, subName = subName, subText = subText }
end

---------------------------------------------------------------------------
-- Typing a line
---------------------------------------------------------------------------
-- Types `text` into `label`, blipping, calling onChar(i) for each letter. Returns early if skip() is true.
local function typeText(label: TextLabel, text: string, who: string, mood: string, skip: () -> boolean, onChar)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local n = utf8.len(text) or #text
	for i = 1, n do
		if skip() then
			break
		end
		label.MaxVisibleGraphemes = i
		local ch = utf8.char(utf8.codepoint(text, utf8.offset(text, i)))
		Voice.blip(who, ch, mood)
		if onChar then
			onChar(i, ch)
		end
		local wait = CHAR_DELAY
		if ch == "," then
			wait = 0.14
		elseif ch == "." or ch == "!" or ch == "?" then
			wait = 0.22
		end
		task.wait(wait)
	end
	label.MaxVisibleGraphemes = -1
end

---------------------------------------------------------------------------
-- Full dialogue (interactive)
---------------------------------------------------------------------------
local function playLines(lines)
	if not ui then
		build()
	end
	ui.tap.Visible = true
	ui.holder.Visible = true
	Gui.pop(ui.holder, 0.9)

	local tapped = false
	local conn1 = ui.tap.Activated:Connect(function()
		tapped = true
	end)
	local conn2 = UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
			tapped = true
		end
	end)

	local lastWho = nil
	local model = nil
	for _, line in lines do
		local who, mood = line.who or "Verity", line.mood or "happy"
		if who ~= lastWho then
			model = buildPortraitModel(who)
			Viewport.set(ui.vpf, model, { zoom = 0.9, sway = 1.2 })
			model = ui.vpf:FindFirstChildWhichIsA("Model")
			lastWho = who
		end
		ModelFactory.setFace(model, mood, 0)
		ui.name.Text = who
		ui.name.TextColor3 = speakerColor(who)
		ui.prompt.Visible = false
		tapped = false
		local open = false
		typeText(ui.body, line.text, who, mood, function()
			return tapped
		end, function(i)
			if i % 3 == 1 then
				open = not open
				ModelFactory.setFace(model, mood, if open then 0.9 else 0.1)
			end
		end)
		ModelFactory.setFace(model, mood, 0)
		ui.prompt.Visible = true
		tapped = false
		while not tapped do
			task.wait()
		end
	end

	conn1:Disconnect()
	conn2:Disconnect()
	ui.holder.Visible = false
	ui.tap.Visible = false
	Viewport.set(ui.vpf, nil)
end

-- Plays a script by id (or a lines table). Scripts that arrive while one is playing wait their turn.
function DialogueBox.play(scriptOrId)
	local lines = if type(scriptOrId) == "string" then Dialogue.scripts[scriptOrId] else scriptOrId
	if not lines then
		return
	end
	table.insert(queue, lines)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			local nextLines = table.remove(queue, 1)
			local ok, err = pcall(playLines, nextLines)
			if not ok then
				warn("[DialogueBox] " .. tostring(err))
				if ui then
					ui.holder.Visible = false
					ui.tap.Visible = false
				end
			end
		end
		busy = false
	end)
end

function DialogueBox.isBusy(): boolean
	return busy
end

-- Wait until every queued dialogue has finished
function DialogueBox.waitIdle()
	while busy do
		task.wait(0.1)
	end
end

---------------------------------------------------------------------------
-- Cutscene subtitle: types the line, holds it, hides it. Yields until done.
--   onChar(i): called per letter (the cutscene flaps the 3D face with it)
---------------------------------------------------------------------------
function DialogueBox.subtitle(who: string, text: string, mood: string?, hold: number?, onChar, skip: (() -> boolean)?)
	if not ui then
		build()
	end
	ui.sub.Visible = true
	ui.subName.Text = who
	ui.subName.TextColor3 = speakerColor(who)
	ui.subText.TextColor3 = Color3.new(1, 1, 1)
	local stop = skip or function()
		return false
	end
	typeText(ui.subText, text, who, mood or "talk", stop, onChar)
	local t = 0
	local holdFor = hold or math.clamp(#text * 0.03, 0.8, 3)
	while t < holdFor and not stop() do
		t += task.wait()
	end
	ui.sub.Visible = false
end

function DialogueBox.hideSubtitle()
	if ui then
		ui.sub.Visible = false
	end
end

return DialogueBox
