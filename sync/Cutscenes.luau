-- Cutscenes: the actual movies. Each is function(c) using the helpers from Cutscene.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local QuestTargets = require(Shared:WaitForChild("QuestTargets"))

local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local Sounds = require(script.Parent.Sounds)

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Cutscenes = {}

local V = "Verity"

local function newHero(c, size: number?)
	local hero = ModelFactory.verity(nil, size or 6)
	c.track(hero)
	for _, part in hero:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	hero.Parent = workspace
	return hero
end

local function groundAt(plot, pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { game:GetService("Players").LocalPlayer.Character }
	local hit = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	return hit and hit.Position.Y or 0.5
end

---------------------------------------------------------------------------
-- Opening: a tiny light in the dark wakes up, falls into the world, and meets you.
---------------------------------------------------------------------------
function Cutscenes.intro(c)
	local origin = Vector3.new(0, 3000, 0)
	c.void(origin)
	local hero = newHero(c, 6)
	hero:PivotTo(CFrame.new(origin))
	ModelFactory.setFace(hero, "sleepy")
	local glow = Instance.new("PointLight")
	glow.Color, glow.Brightness, glow.Range = Color3.fromHex("#FFE9A0"), 3, 50
	glow.Parent = hero.PrimaryPart

	-- he floats and turns gently the whole scene
	local floating = true
	c.onStep(function(t)
		if floating then
			hero:PivotTo(CFrame.new(origin + Vector3.new(0, math.sin(t * 1.4) * 0.7, 0)) * CFrame.Angles(0, math.sin(t * 0.8) * 0.35, math.sin(t * 1.1) * 0.06))
		end
	end)

	-- 1. out of the black, a slow push in
	c.camSet(CFrame.lookAt(origin + Vector3.new(0, 4, -70), origin), 70)
	c.fade(0, 2.6, Color3.new(0, 0, 0))
	c.spawn(function()
		c.camTo(CFrame.lookAt(origin + Vector3.new(2, 1.5, -17), origin), 42, 6.5)
	end)
	c.wait(1.6)
	c.say(V, "...", "sleepy", 0.8, hero)
	c.say(V, "...hello?", "sleepy", 1.0, hero)

	-- 2. eyes open: punch in, shake, whip around him
	ModelFactory.setFace(hero, "surprised")
	c.shake(1.4, 0.5)
	c.punch(22)
	c.say(V, "Wait. I'm... awake?", "surprised", 1.0, hero)
	ModelFactory.setFace(hero, "excited")
	c.spawn(function()
		c.say(V, "I have a FACE! Look at this! I have a face!", "excited", 1.2, hero)
	end)
	c.rig(2.4, function(a)
		local ang = math.rad(-90 + 400 * a)
		local dist = 15 - 4 * math.sin(a * math.pi)
		local p = origin + Vector3.new(math.sin(ang) * dist, 2 + 3 * math.sin(a * math.pi), -math.cos(ang) * dist)
		return CFrame.lookAt(p, origin), 55 + 25 * math.sin(a * math.pi)
	end, Enum.EasingStyle.Quad)
	c.wait(1.2)
	ModelFactory.setFace(hero, "worried")
	c.camTo(CFrame.lookAt(origin + Vector3.new(0, 0.5, -9), origin), 36, 1.6)
	c.say(V, "But... where is everybody? Hello? Anyone?", "worried", 1.2, hero)
	c.say(V, "Something is calling me. Warm. Down there.", "talk", 1.1, hero)

	-- 3. he decides: a burst of light and we cut to the world
	ModelFactory.setFace(hero, "excited")
	c.shake(2, 0.9)
	c.punch(-18)
	c.camTo(CFrame.lookAt(origin + Vector3.new(0, 0, -9), origin), 30, 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	c.flash(0.9)
	floating = false
	hero.Parent = nil

	-- 4. the sky above the plot: a very fast dive while Verity falls ahead of us
	local plot = State.plot()
	local spawnPos = QuestTargets.position(plot, "spawn") or Vector3.new(0, 5, 0)
	local landing = Vector3.new(spawnPos.X + 6, 0, spawnPos.Z + 4)
	local ground = groundAt(plot, landing)
	local rest = Vector3.new(landing.X, ground + 3, landing.Z)
	local dropFrom = rest + Vector3.new(-2, 190, -3)
	hero.Parent = workspace
	ModelFactory.setFace(hero, "excited")

	local fallTime = 3.0
	local landed = false
	c.spawn(function()
		local t = 0
		while t < fallTime and not c.skipped() do
			t += task.wait()
			local a = math.clamp(t / fallTime, 0, 1)
			local y = dropFrom.Y + (rest.Y - dropFrom.Y) * (a * a) -- accelerating fall
			local pos = Vector3.new(dropFrom.X + (rest.X - dropFrom.X) * a, y, dropFrom.Z + (rest.Z - dropFrom.Z) * a)
			hero:PivotTo(CFrame.new(pos) * CFrame.Angles(a * 14, a * 9, 0))
		end
		hero:PivotTo(CFrame.new(rest))
		landed = true
	end)
	c.rig(fallTime, function(a)
		-- the camera chases him down, then swings to the side as he arrives
		local heroPos = dropFrom:Lerp(rest, a * a)
		local chase = heroPos + Vector3.new(0, 20 * (1 - a) + 6, -26 + 8 * a)
		local side = rest + Vector3.new(14, 7, -12)
		local p = chase:Lerp(side, a ^ 4)
		return CFrame.lookAt(p, heroPos + Vector3.new(0, 1, 0)), 92 - 40 * a
	end, Enum.EasingStyle.Linear)
	c.wait(0.05)
	hero:PivotTo(CFrame.new(rest))
	c.dust(Vector3.new(rest.X, ground + 0.6, rest.Z))
	c.shake(2.6, 0.7)
	c.punch(14)

	-- squash and bounce
	c.spawn(function()
		local base = hero:GetScale()
		for _, k in { 0.8, 1.12, 0.94, 1.03, 1 } do
			hero:ScaleTo(base * k)
			c.wait(0.09)
		end
		local up = 0
		while up < 1 and not c.skipped() do
			up += task.wait() * 3.2
			hero:PivotTo(CFrame.new(rest + Vector3.new(0, math.sin(math.min(up, 1) * math.pi) * 2.2, 0)) * CFrame.Angles(0, up * math.pi * 2, 0))
		end
		hero:PivotTo(CFrame.new(rest) * CFrame.Angles(0, math.rad(200), 0))
	end)
	c.wait(0.9)

	-- 5. close up: he spots you
	local char = game:GetService("Players").LocalPlayer.Character
	local you = char and char:FindFirstChild("HumanoidRootPart")
	local lookAt = if you then Vector3.new(you.Position.X, rest.Y, you.Position.Z) else rest + Vector3.new(0, 0, 10)
	hero:PivotTo(CFrame.lookAt(rest, lookAt) * CFrame.Angles(0, math.pi, 0))
	local face = (lookAt - rest).Unit
	c.camTo(CFrame.lookAt(rest + face * 11 + Vector3.new(2, 2.5, 0), rest + Vector3.new(0, 0.6, 0)), 44, 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	ModelFactory.setFace(hero, "surprised")
	c.say(V, "Oh! A WORLD! And... is that someone else?", "surprised", 1.1, hero)
	ModelFactory.setFace(hero, "happy")
	c.say(V, "Hi! I'm Verity, I think. Hello hello hello!", "excited", 1.1, hero)
	c.fade(1, 0.5, Color3.new(0, 0, 0))
end

---------------------------------------------------------------------------
-- Finale: the sky tears open, two doors rise, and you choose where Verity belongs.
---------------------------------------------------------------------------
local function part(parent, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if name then
		p.Name = name
	end
	p.Parent = parent
	return p
end

-- the direction with the most open space around a point (so the doors do not rise inside a house)
local function openDirection(origin: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { game:GetService("Players").LocalPlayer.Character }
	local best, bestD = Vector3.new(0, 0, 1), -1
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local d = 70
		for _, h in { 2, 8, 18 } do
			local hit = workspace:Raycast(origin + Vector3.new(0, h, 0), dir * 70, params)
			d = math.min(d, hit and hit.Distance or 70)
		end
		-- also the two sides where the doors will stand
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for _, sgn in { -1, 1 } do
			local hit = workspace:Raycast(origin + dir * 30 + Vector3.new(0, 8, 0) + side * sgn * 4, side * sgn * 18, params)
			d = math.min(d, 40 + (hit and hit.Distance or 18))
		end
		if d > bestD + 0.5 then
			best, bestD = dir, d
		end
	end
	return best
end

-- ground height under a point, ignoring roofs and anything far above the reference height
local function groundNear(pos: Vector3, refY: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { game:GetService("Players").LocalPlayer.Character }
	local hit = workspace:Raycast(Vector3.new(pos.X, refY + 6, pos.Z), Vector3.new(0, -40, 0), params)
	return hit and hit.Position.Y or refY
end

local function bodyOf(hero)
	return hero:FindFirstChild("Body") or hero.PrimaryPart
end

-- a fluorescent yellow door, humming
local function backroomsDoor(parent, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "BackroomsDoor"
	local yellow = Color3.fromHex("#FFE84A")
	part(parent, Vector3.new(1.6, 22, 1.6), cf * CFrame.new(-7, 11, 0), yellow, Enum.Material.Neon).Parent = m
	part(parent, Vector3.new(1.6, 22, 1.6), cf * CFrame.new(7, 11, 0), yellow, Enum.Material.Neon).Parent = m
	part(parent, Vector3.new(15.6, 1.6, 1.6), cf * CFrame.new(0, 22.4, 0), yellow, Enum.Material.Neon).Parent = m
	local panel = part(parent, Vector3.new(12.4, 21.6, 0.6), cf * CFrame.new(0, 10.8, 0), Color3.fromHex("#D9C45A"), Enum.Material.Neon)
	panel.Parent = m
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromHex("#FFEE7A"), 45, 1.6
	glow.Parent = panel
	-- stripes of wallpaper inside the doorway
	for i = -2, 2 do
		part(parent, Vector3.new(0.5, 21.6, 0.7), cf * CFrame.new(i * 2.4, 10.8, -0.1), Color3.fromHex("#B59B30"), Enum.Material.Neon).Parent = m
	end
	m.Parent = parent
	return m, panel
end

-- a green cube door built from 3-stud blocks
local function blocklandsDoor(parent, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "BlocklandsDoor"
	local rng = Random.new(5)
	local size = 3
	for x = -2, 2 do
		for y = 0, 6 do
			if math.abs(x) == 2 or y == 6 then
				local top = y == 6
				local color = if top then (if rng:NextInteger(1, 2) == 1 then Color3.fromHex("#4FBF3A") else Color3.fromHex("#3DA02E")) else (if rng:NextInteger(1, 2) == 1 then Color3.fromHex("#8A5A33") else Color3.fromHex("#6B4426"))
				part(parent, Vector3.new(size, size, size) * 0.98, cf * CFrame.new(x * size, y * size + size / 2, 0), color).Parent = m
			end
		end
	end
	local panel = part(parent, Vector3.new(9, 18, 0.6), cf * CFrame.new(0, 9 + 0.0, 0), Color3.fromHex("#4DFF6A"), Enum.Material.Neon)
	panel.Parent = m
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromHex("#8BFFB0"), 45, 1.6
	glow.Parent = panel
	m.Parent = parent
	return m, panel
end

local function rise(c, model: Model, finalCf: CFrame, drop: number, duration: number)
	c.spawn(function()
		local t = 0
		while t < duration and not c.skipped() do
			t += task.wait()
			local a = math.clamp(t / duration, 0, 1)
			local e = TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			model:PivotTo(finalCf * CFrame.new(0, -drop * (1 - e), 0))
		end
		model:PivotTo(finalCf)
	end)
end

-- a faint hum of "everything is going to change" while the sky darkens, and back to normal afterwards
local function lightingRig(c)
	local saved = {
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
	}
	local tweens = {}
	c.onEnd(function()
		for _, tw in tweens do
			tw:Cancel()
		end
		for k, v in saved do
			Lighting[k] = v
		end
	end)
	return function(props, dur: number)
		local tw = TweenService:Create(Lighting, TweenInfo.new(math.max(dur, 0.01), Enum.EasingStyle.Sine), props)
		table.insert(tweens, tw)
		tw:Play()
	end
end

local function glowTween(light: PointLight, brightness: number, range: number, dur: number)
	TweenService:Create(light, TweenInfo.new(dur, Enum.EasingStyle.Quad), { Brightness = brightness, Range = range }):Play()
end

---- the Backrooms ending ---------------------------------------------------
local function endingBackrooms(c, hero, lightTo)
	local origin = Vector3.new(0, 3400, 0)
	c.flash(0.7, Color3.fromHex("#FFF1A0"))
	lightTo({ ClockTime = 0, Ambient = Color3.fromRGB(10, 9, 5), OutdoorAmbient = Color3.fromRGB(10, 9, 5) }, 0.1)

	local hall = c.track(Instance.new("Folder"))
	hall.Name = "CutsceneBackrooms"
	local carpet, wall, ceiling = Color3.fromHex("#8F7B35"), Color3.fromHex("#CDB85A"), Color3.fromHex("#BBA84F")
	local length = 260
	part(hall, Vector3.new(26, 1, length), CFrame.new(origin + Vector3.new(0, -0.5, -length / 2 + 30)), carpet)
	part(hall, Vector3.new(26, 1, length), CFrame.new(origin + Vector3.new(0, 16, -length / 2 + 30)), ceiling)
	part(hall, Vector3.new(1, 17, length), CFrame.new(origin + Vector3.new(-13, 8, -length / 2 + 30)), wall)
	part(hall, Vector3.new(1, 17, length), CFrame.new(origin + Vector3.new(13, 8, -length / 2 + 30)), wall)
	part(hall, Vector3.new(26, 17, 1), CFrame.new(origin + Vector3.new(0, 8, 31)), wall)
	-- wallpaper stripes and baseboards
	for z = 20, -length + 30, -6 do
		part(hall, Vector3.new(0.3, 17, 0.5), CFrame.new(origin + Vector3.new(-12.4, 8, z)), Color3.fromHex("#B09A3E"))
		part(hall, Vector3.new(0.3, 17, 0.5), CFrame.new(origin + Vector3.new(12.4, 8, z)), Color3.fromHex("#B09A3E"))
	end
	-- pillars every so often, to make it feel endless and a little wrong
	for z = -10, -length + 30, -48 do
		part(hall, Vector3.new(5, 17, 5), CFrame.new(origin + Vector3.new(if (z // 48) % 2 == 0 then -7 else 7, 8, z)), wall)
	end
	-- the ceiling lights, off for now
	local lamps = {}
	for z = 10, -length + 40, -22 do
		local lamp = part(hall, Vector3.new(7, 0.4, 3.4), CFrame.new(origin + Vector3.new(0, 15.7, z)), Color3.fromHex("#4A4220"))
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Enabled = Color3.fromHex("#FFF2A0"), 34, 2.4, false
		l.Parent = lamp
		table.insert(lamps, { part = lamp, light = l })
	end
	hall.Parent = workspace

	local body = bodyOf(hero)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromHex("#FFE070"), 10, 0.6
	glow.Parent = body
	local start = origin + Vector3.new(0, 3, 14)
	hero:PivotTo(CFrame.lookAt(start, start + Vector3.new(0, 0, -1)) * CFrame.Angles(0, math.pi, 0))
	ModelFactory.setFace(hero, "sad")
	c.camSet(CFrame.lookAt(start + Vector3.new(4, 4, 20), start + Vector3.new(0, 1, -4)), 52)
	c.fade(0, 0.5)

	-- he rolls into the dark hall
	c.spawn(function()
		local t = 0
		while t < 3.6 and not c.skipped() do
			t += task.wait()
			local z = start.Z - t * 4.2
			hero:PivotTo(CFrame.new(Vector3.new(start.X, start.Y + math.abs(math.sin(t * 5)) * 0.35, z)) * CFrame.Angles(0, math.pi, 0))
		end
	end)
	c.rig(3.6, function(a)
		local z = start.Z - 3.6 * a * 4.2
		return CFrame.lookAt(Vector3.new(start.X + 5 - 3 * a, start.Y + 2, z + 16 - 2 * a), Vector3.new(start.X, start.Y, z)), 52 - 8 * a
	end, Enum.EasingStyle.Linear)
	c.say(V, "It's so... empty in here.", "sad", 1.1, hero)
	c.say(V, "Yellow walls. A hum with nobody in it. Everything is waiting for something.", "worried", 1.4, hero)
	c.say(V, "Maybe it's waiting for me.", "talk", 1.1, hero)

	-- he lights up, and the hall wakes one lamp at a time
	local end3 = bodyOf(hero).Position
	ModelFactory.setFace(hero, "excited")
	glowTween(glow, 5, 70, 1.4)
	c.punch(14)
	c.shake(3, 1.2)
	c.camTo(CFrame.lookAt(end3 + Vector3.new(6, 6, 26), end3 + Vector3.new(0, 2, -30)), 60, 1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	c.spawn(function()
		for _, lamp in lamps do
			if lamp.part.Position.Z < end3.Z + 30 then
				lamp.part.Material = Enum.Material.Neon
				lamp.part.Color = Color3.fromHex("#FFF6B0")
				lamp.light.Enabled = true
				Sounds.play("flash", 1.4)
				c.wait(0.16)
			end
		end
	end)
	c.rig(3.2, function(a)
		return CFrame.lookAt(end3 + Vector3.new(6 - 8 * a, 6 + 4 * a, 26 + 14 * a), end3 + Vector3.new(0, 3, -30 - 20 * a)), 60 + 14 * a
	end, Enum.EasingStyle.Sine)
	lightTo({ Ambient = Color3.fromRGB(60, 54, 25), OutdoorAmbient = Color3.fromRGB(60, 54, 25) }, 2)
	ModelFactory.setFace(hero, "happy")
	c.say(V, "It was never missing walls. It was missing light.", "excited", 1.3, hero)
	c.say(V, "I'm the light in the empty places. That's what I'm FOR!", "excited", 1.4, hero)
	c.say(V, "Thank you for walking with me. Come visit sometime. I'll leave a lamp on.", "happy", 1.5, hero)
	c.flash(1.0, Color3.fromHex("#FFF6B0"))
	c.fade(1, 0.5, Color3.new(0, 0, 0))
	c.card("THE LIGHT IN THE EMPTY PLACES", "Ending: The Backrooms", 2.6)
end

---- the Blocklands ending --------------------------------------------------
local function endingBlocklands(c, hero, lightTo)
	local origin = Vector3.new(0, 3800, 0)
	c.flash(0.7, Color3.fromHex("#B8FFC0"))
	lightTo({ ClockTime = 0.5, Ambient = Color3.fromRGB(18, 22, 46), OutdoorAmbient = Color3.fromRGB(18, 22, 46) }, 0.1)

	local land = c.track(Instance.new("Folder"))
	land.Name = "CutsceneBlocklands"
	local rng = Random.new(21)
	local grass = { Color3.fromHex("#4FBF3A"), Color3.fromHex("#45AE33"), Color3.fromHex("#5BCB45") }
	local dirt = Color3.fromHex("#7A4E2B")
	part(land, Vector3.new(520, 2, 520), CFrame.new(origin + Vector3.new(0, -1, 0)), Color3.fromHex("#3DA02E"))
	-- stepped square hills
	local hills = {}
	for gx = -9, 9 do
		for gz = -2, 12 do
			local h = math.floor(math.max(0, 3.2 * math.sin(gx * 0.45) + 2.4 * math.cos(gz * 0.55 + gx * 0.2) + rng:NextNumber(-0.6, 0.6)))
			if h > 0 then
				local b = Vector3.new(origin.X + gx * 12, origin.Y, origin.Z - 40 - gz * 12)
				part(land, Vector3.new(12, h * 4, 12), CFrame.new(b + Vector3.new(0, h * 2, 0)), dirt)
				part(land, Vector3.new(12, 1.2, 12), CFrame.new(b + Vector3.new(0, h * 4 + 0.6, 0)), grass[rng:NextInteger(1, 3)])
				if h >= 2 then
					table.insert(hills, b + Vector3.new(0, h * 4 + 1.2, 0))
				end
			end
		end
	end
	land.Parent = workspace

	local body = bodyOf(hero)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromHex("#FFE070"), 40, 3
	glow.Parent = body

	-- a square halo of light around him: twelve glowing edges of a cube
	local halo = c.track(Instance.new("Model"))
	halo.Name = "SquareSun"
	local R, T = 9, 0.7
	local sun = Color3.fromHex("#FFE45A")
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			part(halo, Vector3.new(2 * R + T, T, T), CFrame.new(0, a * R, b * R), sun, Enum.Material.Neon)
			part(halo, Vector3.new(T, 2 * R + T, T), CFrame.new(a * R, 0, b * R), sun, Enum.Material.Neon)
			part(halo, Vector3.new(T, T, 2 * R + T), CFrame.new(a * R, b * R, 0), sun, Enum.Material.Neon)
		end
	end
	local core = part(halo, Vector3.new(1, 1, 1), CFrame.new(), sun)
	core.Transparency = 1
	halo.PrimaryPart = core
	halo.Parent = nil

	local base = origin + Vector3.new(0, 0, -30)
	local hidden = base + Vector3.new(0, -2, -20)
	hero:PivotTo(CFrame.new(hidden))
	ModelFactory.setFace(hero, "worried")
	c.camSet(CFrame.lookAt(origin + Vector3.new(0, 8, 40), base + Vector3.new(0, 14, -20)), 58)
	c.fade(0, 0.5)
	c.say(V, "Square hills... and lights in the windows. Somebody's building out there.", "surprised", 1.3, hero)

	-- he rises like a sunrise
	hero:PivotTo(CFrame.new(hidden + Vector3.new(0, 1, 0)))
	halo.Parent = workspace
	local risingDone = false
	c.spawn(function()
		local t = 0
		while t < 5 and not c.skipped() do
			t += task.wait()
			local a = TweenService:GetValue(math.clamp(t / 5, 0, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			local pos = hidden + Vector3.new(0, 8 + 26 * a, 6 * a)
			hero:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.pi, 0))
			halo:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 0.5, t * 0.8, t * 0.3))
		end
		risingDone = true
	end)
	lightTo({ ClockTime = 6.6, Ambient = Color3.fromRGB(120, 120, 140), OutdoorAmbient = Color3.fromRGB(120, 130, 150) }, 5)
	ModelFactory.setFace(hero, "excited")
	c.rig(5, function(a)
		return CFrame.lookAt(origin + Vector3.new(0, 6 + 3 * a, 36 - 8 * a), hidden + Vector3.new(0, 8 + 26 * a, 6 * a)), 58 + 6 * a
	end, Enum.EasingStyle.Sine)
	c.shake(2.5, 1)
	c.punch(14)

	-- the builders pop up and cheer
	c.spawn(function()
		local palette = { "#FF5A6A", "#3DE0FF", "#FFD84D", "#A35BFF", "#FF5FC8" }
		for i, top in hills do
			if i % 3 == 0 then
				local block = part(land, Vector3.new(0.1, 0.1, 0.1), CFrame.new(top + Vector3.new(0, 1.5, 0)), Color3.fromHex(palette[(i % #palette) + 1]))
				TweenService:Create(block, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(3, 3, 3) }):Play()
				c.spawn(function()
					for hop = 1, 6 do
						TweenService:Create(block, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = top + Vector3.new(0, 4, 0) }):Play()
						c.wait(0.22)
						TweenService:Create(block, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = top + Vector3.new(0, 1.5, 0) }):Play()
						c.wait(0.22)
					end
				end)
				c.wait(0.12)
			end
		end
	end)
	ModelFactory.setFace(hero, "happy")
	c.say(V, "They're cheering. They look up at me like I'm the morning.", "excited", 1.4, hero)
	c.say(V, "I can be that. The morning for everyone who builds!", "excited", 1.4, hero)
	c.say(V, "Thank you for walking with me. Come visit. Bring bricks.", "happy", 1.5, hero)
	c.flash(1.0, Color3.fromHex("#E8FFD0"))
	c.fade(1, 0.5, Color3.new(0, 0, 0))
	c.card("THE MORNING FOR EVERYONE WHO BUILDS", "Ending: The Blocklands", 2.6)
end

function Cutscenes.finale(c)
	local lightTo = lightingRig(c)
	local plot = State.plot()
	local char = game:GetService("Players").LocalPlayer.Character
	local you = char and char:FindFirstChild("HumanoidRootPart")
	local here = if you then you.Position else (QuestTargets.position(plot, "spawn") or Vector3.new(0, 3, 0))
	local f = openDirection(here)
	local r = f:Cross(Vector3.yAxis)
	local ground = groundNear(here, here.Y - 2.5)
	local hp = Vector3.new(here.X, ground + 3, here.Z) + f * 9
	local leftDoor = hp + f * 34 - r * 18 -- the Backrooms
	local rightDoor = hp + f * 34 + r * 18 -- the Blocklands
	leftDoor = Vector3.new(leftDoor.X, groundNear(leftDoor, ground), leftDoor.Z)
	rightDoor = Vector3.new(rightDoor.X, groundNear(rightDoor, ground), rightDoor.Z)

	local hero = newHero(c, 6)
	hero:PivotTo(CFrame.lookAt(hp, hp + f) * CFrame.Angles(0, math.pi, 0))
	ModelFactory.setFace(hero, "sad")
	local body = bodyOf(hero)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromHex("#FFE9A0"), 0, 0
	glow.Parent = body

	-- 1. a quiet moment
	c.camSet(CFrame.lookAt(hp - f * 17 + r * 7 + Vector3.new(0, 4, 0), hp + Vector3.new(0, 1.5, 0)), 50)
	c.fade(0, 0.9)
	c.camTo(CFrame.lookAt(hp - f * 11 + r * 4 + Vector3.new(0, 3.4, 0), hp + Vector3.new(0, 1.5, 0)), 44, 2.4, Enum.EasingStyle.Sine)
	c.say(V, "I think I know why I'm here. And I'm scared.", "sad", 1.3, hero)
	c.say(V, "Two doors are opening. I have to go through one. Will you walk with me?", "talk", 1.3, hero)

	-- 2. the sky goes dark and starts to crack
	lightTo({ ClockTime = 0, Ambient = Color3.fromRGB(26, 22, 60), OutdoorAmbient = Color3.fromRGB(26, 22, 60) }, 2.5)
	ModelFactory.setFace(hero, "worried")
	c.shake(1.4, 2.4)
	local mid = (leftDoor + rightDoor) / 2
	c.camTo(CFrame.lookAt(hp - f * 8 + Vector3.new(0, 1.2, 0), mid + Vector3.new(0, 55, 0)), 70, 1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local tear = c.track(Instance.new("Part"))
	tear.Anchored, tear.CanCollide, tear.CanQuery, tear.CanTouch, tear.CastShadow = true, false, false, false, false
	tear.Material, tear.Color = Enum.Material.Neon, Color3.fromHex("#FFF7C2")
	tear.Size = Vector3.new(0.3, 120, 0.3)
	tear.CFrame = CFrame.lookAt(mid + Vector3.new(0, 70, 0), mid + Vector3.new(0, 70, 0) + f)
	local tearLight = Instance.new("PointLight")
	tearLight.Color, tearLight.Range, tearLight.Brightness = Color3.fromHex("#FFF2B0"), 0, 0
	tearLight.Parent = tear
	tear.Parent = workspace
	c.punch(16)
	c.shake(4, 1.4)
	c.flash(0.5, Color3.fromHex("#FFF7C2"))
	TweenService:Create(tear, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(16, 120, 0.6) }):Play()
	glowTween(tearLight, 1.6, 80, 1.2)
	ModelFactory.setFace(hero, "surprised")
	c.wait(0.9)

	-- 3. the doors rise
	local backModel = backroomsDoor(workspace, CFrame.lookAt(leftDoor, leftDoor + f))
	local blockModel = blocklandsDoor(workspace, CFrame.lookAt(rightDoor, rightDoor + f))
	c.track(backModel)
	c.track(blockModel)
	rise(c, backModel, backModel:GetPivot(), 26, 1.3)
	rise(c, blockModel, blockModel:GetPivot(), 26, 1.3)
	Sounds.play("reveal")
	c.dust(leftDoor + Vector3.new(0, 0.6, 0))
	c.dust(rightDoor + Vector3.new(0, 0.6, 0))
	c.shake(4.5, 1.2)
	-- whip to each door in turn
	c.camTo(CFrame.lookAt(leftDoor - f * 22 + r * 4 + Vector3.new(0, 7, 0), leftDoor + Vector3.new(0, 11, 0)), 58, 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	ModelFactory.setFace(hero, "worried")
	c.wait(0.45)
	c.camTo(CFrame.lookAt(rightDoor - f * 22 - r * 4 + Vector3.new(0, 7, 0), rightDoor + Vector3.new(0, 10, 0)), 58, 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	ModelFactory.setFace(hero, "surprised")
	c.wait(0.45)

	-- his face runs through everything while the camera circles him
	local faces = { "worried", "surprised", "excited", "sad", "worried", "happy" }
	c.spawn(function()
		for _, mood in faces do
			if c.skipped() then
				break
			end
			ModelFactory.setFace(hero, mood)
			c.wait(0.3)
		end
	end)
	c.rig(2.0, function(a)
		local ang = math.pi * 1.6 * a - 0.8
		local p = hp + (-f * math.cos(ang) + r * math.sin(ang)) * 15 + Vector3.new(0, 4 + 2 * a, 0)
		return CFrame.lookAt(p, hp + Vector3.new(0, 1.5, 0)), 62 - 14 * a
	end, Enum.EasingStyle.Sine)

	-- 4. pull back and ask
	ModelFactory.setFace(hero, "worried")
	c.camTo(CFrame.lookAt(hp - f * 28 + Vector3.new(0, 14, 0), mid + Vector3.new(0, 7, 0)), 64, 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	c.say(V, "One is warm and humming. One is square and green. Which one is mine?", "worried", 1.4, hero)
	c.unskip()
	local choice = c.choose("Where does Verity belong?", {
		{ id = "backrooms", text = "THE BACKROOMS", color = Theme.C.Yellow, deep = Theme.C.YellowDeep },
		{ id = "blocklands", text = "THE BLOCKLANDS", color = Theme.C.Green, deep = Theme.C.GreenDeep },
	})
	State.invoke("chooseEnding", choice)

	-- 5. he runs for it
	local door = if choice == "backrooms" then leftDoor else rightDoor
	local doorFace = if choice == "backrooms" then Vector3.new(0, 11, 0) else Vector3.new(0, 9, 0)
	ModelFactory.setFace(hero, "excited")
	c.spawn(function()
		local startPos = hp
		local t = 0
		while t < 1.7 and not c.skipped() do
			t += task.wait()
			local a = math.clamp(t / 1.7, 0, 1)
			local e = a * a
			local pos = startPos:Lerp(door + Vector3.new(0, 3, 0), e) + Vector3.new(0, math.abs(math.sin(t * 9)) * 1.4 * (1 - a), 0)
			hero:PivotTo(CFrame.lookAt(pos, door + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.pi, 0))
		end
	end)
	c.shake(1.5, 1.6)
	c.rig(1.7, function(a)
		local p = hp - f * (22 - 10 * a) + Vector3.new(0, 7 - 2 * a, 0) + r * ((if choice == "backrooms" then -1 else 1) * 8 * a)
		return CFrame.lookAt(p, hp:Lerp(door, a * a) + Vector3.new(0, 3, 0)), 60 - 10 * a
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	c.punch(18)

	if choice == "backrooms" then
		endingBackrooms(c, hero, lightTo)
	else
		endingBlocklands(c, hero, lightTo)
	end
end

return Cutscenes
