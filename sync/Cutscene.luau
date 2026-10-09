-- Cutscene: the little movie engine.
--   Cutscene.play(function(c) ... end)  runs a scene; yields until it ends (or the player skips).
-- Helpers on `c` (all of them skip-aware, so skipping jumps straight to the end):
--   c.wait(s)  c.camSet(cf, fov)  c.camTo(cf, fov, s, style?, dir?)  c.rig(s, function(alpha, t) return cf, fov end)
--   c.shake(amount, s)  c.punch(fovKick, s)  c.fade(opacity, s, color?)  c.flash(s, color?)
--   c.say(who, text, mood, hold?, model?)  c.onStep(function(t, dt))  c.track(instance)  c.spawn(fn)
--   c.void(origin)  c.dust(position)  c.skipped()
-- Letterbox bars, a Skip button (touch friendly), hidden HUD and frozen controls are handled here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Gui = require(script.Parent.Gui)
local DialogueBox = require(script.Parent.DialogueBox)
local Sounds = require(script.Parent.Sounds)
local ModelFactory = require(game:GetService("ReplicatedStorage").Shared.ModelFactory)

local Cutscene = {}
local player = Players.LocalPlayer
local active = false

function Cutscene.isActive(): boolean
	return active
end

local function ease(alpha: number, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): number
	return TweenService:GetValue(math.clamp(alpha, 0, 1), style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut)
end

local function playerControls()
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, controls = pcall(function()
		return require(module):GetControls()
	end)
	return if ok then controls else nil
end

function Cutscene.play(scene: (any) -> ())
	if active then
		return
	end
	active = true
	local cam = workspace.CurrentCamera
	local saved = { type = cam.CameraType, fov = cam.FieldOfView, subject = cam.CameraSubject, cf = cam.CFrame }
	local skipped = false
	local tracked, conns, cleanups = {}, {}, {}
	local state = { cf = cam.CFrame, fov = cam.FieldOfView, shakes = {}, kick = 0 }

	-- screen furniture
	local root = Gui.layer("Cutscene", 50, true)
	local holder = Theme.make("Frame", { Name = "Scene", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
	local topBar = Theme.make("Frame", { AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = holder })
	local botBar = Theme.make("Frame", { Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = holder })
	topBar.Position = UDim2.fromScale(0, 0)
	local fadeFrame = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 10, Parent = holder })
	local skipBtn = Theme.button({
		Text = "SKIP  ▶▶",
		Size = UDim2.fromOffset(150, 46),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 76),
		Color = Theme.C.Grey,
		Deep = Theme.C.GreyDeep,
		Parent = holder,
		ZIndex = 20,
		OnClick = function()
			skipped = true
		end,
	})

	local savedLayers = { "Hud", "Toasts", "Backpack", "Shop" }
	for _, name in savedLayers do
		Gui.setLayerVisible(name, false)
	end
	local controls = playerControls()
	if controls then
		controls:Disable()
	end
	-- belt and braces: also freeze the humanoid so nobody wanders off mid-scene
	local frozenHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local savedSpeed, savedJump = nil, nil
	if frozenHumanoid then
		savedSpeed, savedJump = frozenHumanoid.WalkSpeed, frozenHumanoid.JumpPower
		frozenHumanoid.WalkSpeed, frozenHumanoid.JumpPower = 0, 0
	end
	cam.CameraType = Enum.CameraType.Scriptable

	RunService:BindToRenderStep("VerityCutscene", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local offset = CFrame.identity
		for i = #state.shakes, 1, -1 do
			local s = state.shakes[i]
			s.t += dt
			if s.t >= s.dur then
				table.remove(state.shakes, i)
			else
				local k = s.amp * (1 - s.t / s.dur)
				offset *= CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.04)
			end
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = state.cf * offset
		cam.FieldOfView = state.fov + state.kick
		state.kick *= math.max(0, 1 - dt * 7)
	end)

	local c = {}
	function c.skipped()
		return skipped
	end
	function c.track(inst)
		table.insert(tracked, inst)
		return inst
	end
	function c.spawn(fn)
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then
				warn("[Cutscene] " .. tostring(err))
			end
		end)
	end
	function c.wait(s: number)
		local t = 0
		while t < s and not skipped do
			t += task.wait()
		end
	end
	function c.camSet(cf: CFrame, fov: number?)
		state.cf = cf
		if fov then
			state.fov = fov
		end
	end
	function c.rig(duration: number, fn, style, dir)
		local t = 0
		while t < duration and not skipped do
			t += task.wait()
			local a = ease(t / duration, style, dir)
			local cf, fov = fn(a, t)
			state.cf = cf
			if fov then
				state.fov = fov
			end
		end
		if skipped then
			local cf, fov = fn(1, duration)
			state.cf = cf
			if fov then
				state.fov = fov
			end
		end
	end
	function c.camTo(cf: CFrame, fov: number?, duration: number, style, dir)
		local from, fromFov = state.cf, state.fov
		c.rig(duration, function(a)
			return from:Lerp(cf, a), fromFov + ((fov or fromFov) - fromFov) * a
		end, style, dir)
	end
	function c.shake(amount: number, duration: number)
		table.insert(state.shakes, { amp = amount, dur = duration, t = 0 })
	end
	function c.punch(fovKick: number)
		state.kick = fovKick
	end
	function c.fade(opacity: number, duration: number, color: Color3?)
		if color then
			fadeFrame.BackgroundColor3 = color
		end
		local tween = TweenService:Create(fadeFrame, TweenInfo.new(math.max(duration, 0.01), Enum.EasingStyle.Sine), { BackgroundTransparency = 1 - opacity })
		tween:Play()
		c.wait(duration)
		tween:Cancel()
		fadeFrame.BackgroundTransparency = 1 - opacity
	end
	function c.flash(duration: number, color: Color3?)
		fadeFrame.BackgroundColor3 = color or Color3.new(1, 1, 1)
		fadeFrame.BackgroundTransparency = 0
		Sounds.play("flash")
		c.fade(0, duration)
	end
	function c.onStep(fn)
		local t = 0
		local conn = RunService.RenderStepped:Connect(function(dt)
			t += dt
			fn(t, dt)
		end)
		table.insert(conns, conn)
		return conn
	end
	function c.say(who: string, text: string, mood: string?, hold: number?, model: Model?)
		local open = false
		DialogueBox.subtitle(who, text, mood, hold, function(i)
			if model and model.Parent and i % 3 == 1 then
				open = not open
				ModelFactory.setFace(model, mood, if open then 0.9 else 0.1)
			end
		end, function()
			return skipped
		end)
		if model and model.Parent then
			ModelFactory.setFace(model, mood, 0)
		end
	end

	-- a dark room full of drifting stars, for scenes "outside the world"
	function c.void(origin: Vector3)
		local folder = c.track(Instance.new("Folder"))
		folder.Name = "CutsceneVoid"
		local size, half = 420, 210
		local faces = {
			{ Vector3.new(size, 2, size), Vector3.new(0, -half, 0) },
			{ Vector3.new(size, 2, size), Vector3.new(0, half, 0) },
			{ Vector3.new(2, size, size), Vector3.new(-half, 0, 0) },
			{ Vector3.new(2, size, size), Vector3.new(half, 0, 0) },
			{ Vector3.new(size, size, 2), Vector3.new(0, 0, -half) },
			{ Vector3.new(size, size, 2), Vector3.new(0, 0, half) },
		}
		for _, f in faces do
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Size = f[1]
			p.Position = origin + f[2]
			p.Color = Color3.fromHex("#0B0826")
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = folder
		end
		local rng = Random.new(11)
		local stars = {}
		for i = 1, 110 do
			local s = Instance.new("Part")
			s.Shape = Enum.PartType.Ball
			s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
			local d = rng:NextNumber(0.5, 2.2)
			s.Size = Vector3.new(d, d, d)
			s.Material = Enum.Material.Neon
			s.Color = if rng:NextInteger(1, 4) == 1 then Color3.fromHex("#7CF0FF") else Color3.fromHex("#FFE9A0")
			local base = origin + Vector3.new(rng:NextNumber(-160, 160), rng:NextNumber(-100, 140), rng:NextNumber(-160, 160))
			s.Position = base
			s.Parent = folder
			stars[i] = { part = s, base = base, phase = rng:NextNumber(0, 6) }
		end
		c.onStep(function(t)
			for _, s in stars do
				s.part.Position = s.base + Vector3.new(0, math.sin(t * 0.6 + s.phase) * 3, 0)
			end
		end)
		folder.Parent = workspace
		return folder
	end

	function c.dust(position: Vector3)
		local p = c.track(Instance.new("Part"))
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
		p.Size = Vector3.new(1, 1, 1)
		p.Position = position
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.5, 1)
		e.Speed = NumberRange.new(14, 24)
		e.SpreadAngle = Vector2.new(180, 20)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromHex("#FFF3C4"))
		e.Parent = p
		p.Parent = workspace
		e:Emit(36)
	end

	-- run something when the movie ends (even when skipped), e.g. put the lighting back
	function c.onEnd(fn)
		table.insert(cleanups, fn)
	end
	-- a choice cannot be skipped: forget any Skip press so later scenes play properly again
	function c.unskip()
		skipped = false
	end

	-- big touch-friendly buttons in the middle of the screen; yields until one is picked.
	-- options = { { id = "a", text = "THE BACKROOMS", color = Theme.C.Yellow, deep = Theme.C.YellowDeep }, ... }
	function c.choose(title: string, options)
		skipped = false
		skipBtn.Holder.Visible = false
		local picked
		local box = Theme.make("Frame", {
			Name = "Choice",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.74),
			Size = UDim2.fromOffset(780, 190),
			BackgroundTransparency = 1,
			ZIndex = 15,
			Parent = holder,
		})
		Theme.text({
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(780, 54),
			Text = title,
			Font = Theme.Display,
			TextColor3 = Color3.new(1, 1, 1),
			MaxTextSize = 42,
			ZIndex = 16,
			Parent = box,
		})
		for i, opt in options do
			Theme.button({
				Text = opt.text,
				Size = UDim2.fromOffset(370, 110),
				Position = UDim2.fromOffset((i - 1) * 410, 70),
				Color = opt.color,
				Deep = opt.deep,
				Parent = box,
				ZIndex = 16,
				OnClick = function()
					picked = opt.id
				end,
			})
		end
		Gui.pop(box)
		while not picked and holder.Parent do
			task.wait(0.1)
		end
		box:Destroy()
		skipBtn.Holder.Visible = true
		return picked
	end

	-- a title card over the (usually dark) screen
	function c.card(title: string, sub: string?, hold: number)
		local card = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12, Parent = holder })
		local t = Theme.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(900, 90), Text = title, Font = Theme.Display, TextColor3 = Theme.C.Yellow, MaxTextSize = 70, ZIndex = 13, Parent = card })
		if sub then
			Theme.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(900, 50), Text = sub, Font = Theme.Display, TextColor3 = Color3.new(1, 1, 1), MaxTextSize = 30, ZIndex = 13, Parent = card })
		end
		Gui.pop(card)
		c.wait(hold)
		card:Destroy()
	end

	-- bars slide in, the scene runs
	topBar.Position = UDim2.fromOffset(0, -64)
	botBar.Position = UDim2.new(0, 0, 1, 0)
	topBar.AnchorPoint, botBar.AnchorPoint = Vector2.new(0, 0), Vector2.new(0, 0)
	TweenService:Create(topBar, TweenInfo.new(0.5), { Position = UDim2.fromOffset(0, 0) }):Play()
	TweenService:Create(botBar, TweenInfo.new(0.5), { Position = UDim2.new(0, 0, 1, -64) }):Play()

	local ok, err = pcall(scene, c)
	if not ok then
		warn("[Cutscene] " .. tostring(err))
	end

	-- always put everything back
	for _, fn in cleanups do
		pcall(fn)
	end
	DialogueBox.hideSubtitle()
	RunService:UnbindFromRenderStep("VerityCutscene")
	for _, conn in conns do
		conn:Disconnect()
	end
	for _, inst in tracked do
		if inst.Parent then
			inst:Destroy()
		end
	end
	cam.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	cam.CameraSubject = humanoid or saved.subject
	cam.FieldOfView = saved.fov
	if controls then
		controls:Enable()
	end
	if frozenHumanoid and frozenHumanoid.Parent then
		frozenHumanoid.WalkSpeed, frozenHumanoid.JumpPower = savedSpeed, savedJump
	end
	for _, name in savedLayers do
		Gui.setLayerVisible(name, true)
	end
	TweenService:Create(fadeFrame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	task.wait(0.45)
	holder:Destroy()
	active = false
end

return Cutscene
