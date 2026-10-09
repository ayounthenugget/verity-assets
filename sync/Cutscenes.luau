-- Cutscenes: the actual movies. Each is function(c) using the helpers from Cutscene.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local QuestTargets = require(Shared:WaitForChild("QuestTargets"))

local State = require(script.Parent.State)

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

return Cutscenes
