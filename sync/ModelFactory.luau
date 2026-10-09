-- ModelFactory
-- Builds the game's small 3D models in code: Verities (smiley balls), eggs and
-- stand-in workers. Nothing has to be uploaded, and the same code makes the 3D world
-- models (server) and the 3D previews in menus (client).
-- Every model faces -Z (its face looks along its LookVector) and pivots on its body's centre.

local Config = require(script.Parent.Config)
local Sprites = require(script.Parent.Sprites)

local ModelFactory = {}

local INK = Color3.fromRGB(20, 16, 26)
local HERO_YELLOW = "#FFD84D"
local RAINBOW = { "#FF3B3B", "#FF8A1F", "#FFD21F", "#3DDB4A", "#29A8FF", "#5B4BFF", "#B04CFF" }

local function newPart(name, shape, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape -- set before Size: balls force a uniform size
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function ball(model, name, d, pos, color, material)
	local p = newPart(name, Enum.PartType.Ball, Vector3.new(d, d, d), CFrame.new(pos), color, material)
	p.Parent = model
	return p
end

local function block(model, name, size, cf, color, material)
	local p = newPart(name, Enum.PartType.Block, size, cf, color, material)
	p.Parent = model
	return p
end

local function ellipsoid(model, name, size, cf, color)
	local p = block(model, name, size, cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Upright cylinder centred on pos
local function cylinder(model, name, diameter, height, pos, color, material)
	local p = newPart(
		name,
		Enum.PartType.Cylinder,
		Vector3.new(height, diameter, diameter),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Parent = model
	return p
end

---------------------------------------------------------------------------
-- Faces. Points are given in "face space": x, y from -1 to 1 across the front.
---------------------------------------------------------------------------
-- Returns a point on the body's front surface and the outward normal there
local function surface(shape: string, r: number, x: number, y: number): (Vector3, Vector3)
	if shape == "cube" then
		return Vector3.new(x * r, y * r, -r), Vector3.new(0, 0, -1)
	end
	local z = math.sqrt(math.max(0.02, 1 - x * x - y * y))
	local n = Vector3.new(x, y, -z).Unit
	return n * r, n
end

-- A line drawn on the face through a list of face-space points
local function stroke(model, name, shape, r, points, width, color)
	for i = 1, #points - 1 do
		local pa = surface(shape, r, points[i].X, points[i].Y)
		local pb = surface(shape, r, points[i + 1].X, points[i + 1].Y)
		local pos, normal = surface(shape, r, (points[i].X + points[i + 1].X) / 2, (points[i].Y + points[i + 1].Y) / 2)
		local along = pb - pa
		if along.Magnitude > 1e-4 then
			local t = along.Unit
			local side = t:Cross(normal).Unit
			local fixedNormal = side:Cross(t)
			block(model, name .. i, Vector3.new(along.Magnitude + width * 0.9, r * 0.07, width), CFrame.fromMatrix(pos, t, fixedNormal, side), color)
		end
	end
	for i, pt in points do
		if i == 1 or i == #points then
			local pos = surface(shape, r, pt.X, pt.Y)
			ball(model, name .. "End" .. i, width * 1.02, pos, color)
		end
	end
end

-- A curved mouth: a smile (U) or, with frown = true, a frown
local function arc(cy, width, depth, steps, frown)
	local pts = {}
	for i = 0, steps do
		local u = -1.15 + 2.3 * i / steps
		local y = if frown then cy + depth * (math.cos(u) - 1) else cy - depth * math.cos(u)
		table.insert(pts, Vector2.new(width * math.sin(u), y))
	end
	return pts
end

local function addFace(model, shape, r, faceType, inkColor)
	local ink = inkColor or INK
	local w = r * 0.12 -- line thickness
	-- eyes: tall black ovals
	for _, side in { -1, 1 } do
		local pos, normal = surface(shape, r, side * 0.3, 0.2)
		ellipsoid(model, if side < 0 then "EyeL" else "EyeR", Vector3.new(r * 0.2, r * 0.38, r * 0.16), CFrame.lookAt(pos, pos + normal), ink)
	end
	local mouth
	if faceType == "flat" then
		mouth = { Vector2.new(-0.3, -0.32), Vector2.new(0, -0.32), Vector2.new(0.3, -0.32) }
	elseif faceType == "sad" then
		mouth = arc(-0.26, 0.3, 0.2, 8, true)
	elseif faceType == "wavy" then
		mouth = {}
		for i = 0, 10 do
			local x = -0.32 + 0.64 * i / 10
			table.insert(mouth, Vector2.new(x, -0.28 - 0.09 * math.abs(math.sin(x * math.pi / 0.32))))
		end
	elseif faceType == "smug" then
		mouth = {}
		for i = 0, 8 do
			local x = -0.28 + 0.62 * i / 8
			local lift = math.max(0, x + 0.05)
			table.insert(mouth, Vector2.new(x, -0.34 + 0.55 * lift * lift))
		end
	else
		mouth = arc(-0.13, 0.44, 0.28, 10, false) -- big smile
	end
	stroke(model, "Mouth", shape, r, mouth, w, ink)

	if faceType == "angry" then
		stroke(model, "BrowL", shape, r, { Vector2.new(-0.48, 0.52), Vector2.new(-0.14, 0.4) }, w, ink)
		stroke(model, "BrowR", shape, r, { Vector2.new(0.48, 0.52), Vector2.new(0.14, 0.4) }, w, ink)
	elseif faceType == "sad" then
		stroke(model, "BrowL", shape, r, { Vector2.new(-0.46, 0.42), Vector2.new(-0.16, 0.52) }, w * 0.8, ink)
		stroke(model, "BrowR", shape, r, { Vector2.new(0.46, 0.42), Vector2.new(0.16, 0.52) }, w * 0.8, ink)
	elseif faceType == "smug" then
		stroke(model, "BrowL", shape, r, { Vector2.new(-0.46, 0.46), Vector2.new(-0.14, 0.46) }, w * 0.8, ink)
		stroke(model, "BrowR", shape, r, { Vector2.new(0.14, 0.5), Vector2.new(0.46, 0.6) }, w * 0.8, ink)
	end
end

---------------------------------------------------------------------------
-- Changing a ball's face on the fly (cutscenes, dialogue portraits).
-- moods: happy talk excited surprised worried sad smug sleepy blink angry
-- open (0..1) opens the mouth wide, used for talking
---------------------------------------------------------------------------
local MOODS = {
	happy = { eyes = "normal", mouth = "smile" },
	talk = { eyes = "normal", mouth = "smile" },
	excited = { eyes = "wide", mouth = "grin" },
	surprised = { eyes = "wide", mouth = "o" },
	worried = { eyes = "normal", mouth = "wavy", brows = "sad" },
	sad = { eyes = "normal", mouth = "frown", brows = "sad" },
	smug = { eyes = "normal", mouth = "smug", brows = "smug" },
	sleepy = { eyes = "closed", mouth = "flat" },
	blink = { eyes = "closed", mouth = "smile" },
	angry = { eyes = "normal", mouth = "flat", brows = "angry" },
}

function ModelFactory.setFace(model: Model, mood: string?, open: number?)
	local look = MOODS[mood or "happy"] or MOODS.happy
	local body = model.PrimaryPart
	if not body then
		return
	end
	for _, child in model:GetChildren() do
		local n = child.Name
		if string.sub(n, 1, 3) == "Eye" or string.sub(n, 1, 5) == "Mouth" or string.sub(n, 1, 4) == "Brow" then
			child:Destroy()
		end
	end
	local r = body.Size.X / 2
	local w = r * 0.12
	local ink = INK
	open = open or 0

	-- eyes
	if look.eyes == "closed" then
		for _, side in { -1, 1 } do
			stroke(model, if side < 0 then "EyeL" else "EyeR", "ball", r, { Vector2.new(side * 0.18, 0.2), Vector2.new(side * 0.42, 0.2) }, w, ink)
		end
	else
		local wide = look.eyes == "wide"
		for _, side in { -1, 1 } do
			local pos, normal = surface("ball", r, side * 0.3, if wide then 0.22 else 0.2)
			local size = if wide then Vector3.new(r * 0.27, r * 0.5, r * 0.16) else Vector3.new(r * 0.2, r * 0.38, r * 0.16)
			ellipsoid(model, if side < 0 then "EyeL" else "EyeR", size, CFrame.lookAt(pos, pos + normal), ink)
		end
	end

	-- mouth
	if open > 0.08 or look.mouth == "grin" or look.mouth == "o" then
		local h, wd
		if look.mouth == "o" then
			h, wd = 0.26 + open * 0.1, 0.2
		elseif look.mouth == "grin" then
			h, wd = 0.3 + open * 0.2, 0.52
		else
			h, wd = 0.1 + open * 0.3, 0.34
		end
		local pos, normal = surface("ball", r, 0, -0.26)
		ellipsoid(model, "MouthO", Vector3.new(r * wd, r * h, r * 0.14), CFrame.lookAt(pos, pos + normal), ink)
	else
		local m = look.mouth
		local pts
		if m == "flat" then
			pts = { Vector2.new(-0.3, -0.32), Vector2.new(0, -0.32), Vector2.new(0.3, -0.32) }
		elseif m == "frown" then
			pts = arc(-0.26, 0.3, 0.2, 8, true)
		elseif m == "wavy" then
			pts = {}
			for i = 0, 10 do
				local x = -0.32 + 0.64 * i / 10
				table.insert(pts, Vector2.new(x, -0.28 - 0.09 * math.abs(math.sin(x * math.pi / 0.32))))
			end
		elseif m == "smug" then
			pts = {}
			for i = 0, 8 do
				local x = -0.28 + 0.62 * i / 8
				local lift = math.max(0, x + 0.05)
				table.insert(pts, Vector2.new(x, -0.34 + 0.55 * lift * lift))
			end
		else
			pts = arc(-0.13, 0.44, 0.28, 10, false)
		end
		stroke(model, "Mouth", "ball", r, pts, w, ink)
	end

	-- brows
	if look.brows == "angry" then
		stroke(model, "BrowL", "ball", r, { Vector2.new(-0.48, 0.52), Vector2.new(-0.14, 0.4) }, w, ink)
		stroke(model, "BrowR", "ball", r, { Vector2.new(0.48, 0.52), Vector2.new(0.14, 0.4) }, w, ink)
	elseif look.brows == "sad" then
		stroke(model, "BrowL", "ball", r, { Vector2.new(-0.46, 0.46), Vector2.new(-0.16, 0.58) }, w * 0.8, ink)
		stroke(model, "BrowR", "ball", r, { Vector2.new(0.46, 0.46), Vector2.new(0.16, 0.58) }, w * 0.8, ink)
	elseif look.brows == "smug" then
		stroke(model, "BrowL", "ball", r, { Vector2.new(-0.46, 0.46), Vector2.new(-0.14, 0.46) }, w * 0.8, ink)
		stroke(model, "BrowR", "ball", r, { Vector2.new(0.14, 0.5), Vector2.new(0.46, 0.6) }, w * 0.8, ink)
	end
end

-- The old farmer: a tan ball under a big straw hat
function ModelFactory.farmer(diameter: number?)
	local d = diameter or 3.2
	local model = Instance.new("Model")
	model.Name = "Farmer"
	local body = ball(model, "Body", d, Vector3.zero, Color3.fromHex("#E8C07A"))
	addFace(model, "ball", d / 2, "smile")
	local straw = Color3.fromHex("#E3B04B")
	ball(model, "HatDome", d * 0.62, Vector3.new(0, d * 0.34, d * 0.02), straw)
	cylinder(model, "HatBrim", d * 1.25, d * 0.06, Vector3.new(0, d * 0.28, -d * 0.04), straw)
	cylinder(model, "HatBand", d * 0.64, d * 0.07, Vector3.new(0, d * 0.3, d * 0.0), Color3.fromHex("#B5532A"))
	ball(model, "FootL", d * 0.28, Vector3.new(-d * 0.2, -d * 0.44, -d * 0.06), Color3.fromHex("#5B3A21"))
	ball(model, "FootR", d * 0.28, Vector3.new(d * 0.2, -d * 0.44, -d * 0.06), Color3.fromHex("#5B3A21"))
	model.PrimaryPart = body
	return model
end

---------------------------------------------------------------------------
-- Verities. nil variant = Verity, the yellow hero.
---------------------------------------------------------------------------
function ModelFactory.verity(variantId: string?, diameter: number?)
	local variant = variantId and Config.VARIANTS[variantId]
	local d = (diameter or 4) * (variant and variant.size or 1)
	local r = d / 2
	local color = Color3.fromHex(variant and variant.color or HERO_YELLOW)
	local shape = variant and variant.shape or "ball"

	local model = Instance.new("Model")
	model.Name = variant and variant.displayName or "Verity"
	local body
	if shape == "cube" then
		body = block(model, "Body", Vector3.new(d, d, d) * 0.92, CFrame.new(), color)
		-- squishy two-tone: a pink back half
		block(model, "Back", Vector3.new(d * 0.93, d * 0.93, d * 0.4), CFrame.new(0, 0, d * 0.27), Color3.fromHex("#FF4FA8"))
		r = d * 0.46
	elseif variant and variant.pattern == "rainbow" then
		-- stacked rainbow slices
		local slices = 14
		local mid = math.ceil(slices / 2)
		for i = 1, slices do
			local y0 = -r + (i - 1) * d / slices
			local yMid = y0 + d / slices / 2
			local chord = 2 * math.sqrt(math.max(0, r * r - yMid * yMid))
			local band = Color3.fromHex(RAINBOW[math.floor((i - 1) * #RAINBOW / slices) + 1])
			local s = cylinder(model, if i == mid then "Body" else "Slice" .. i, math.max(chord, d * 0.08), d / slices + 0.01, Vector3.new(0, yMid, 0), band)
			if i == mid then
				body = s
			end
		end
	else
		body = ball(model, "Body", d, Vector3.zero, color)
		if variant and variant.ghost then
			body.Transparency = 0.55
		end
	end
	addFace(model, shape, r, variant and variant.face or "smile")

	model:SetAttribute("Variant", variantId or "")
	model:SetAttribute("Tier", variant and variant.tier or "")
	model.PrimaryPart = body
	return model
end

---------------------------------------------------------------------------
-- Eggs: tinted by rarity, with spots
---------------------------------------------------------------------------
local SPOT_DIRS = {
	Vector3.new(0.5, 0.45, -0.75),
	Vector3.new(-0.6, 0.1, -0.8),
	Vector3.new(0.15, -0.35, -0.95),
	Vector3.new(-0.2, 0.75, -0.6),
	Vector3.new(0.85, -0.2, -0.45),
	Vector3.new(-0.8, -0.45, 0.4),
	Vector3.new(0.4, 0.3, 0.85),
	Vector3.new(-0.3, 0.2, 0.9),
}

function ModelFactory.eggColor(eggType: string): Color3
	if eggType == "starter" then
		return Color3.fromHex(HERO_YELLOW)
	elseif eggType == "unknown" then
		return Color3.fromHex("#1A1626") -- a dark, mysterious egg
	end
	local tier = Config.TIER_INFO[eggType]
	return if tier then Color3.fromHex(tier.color) else Color3.new(1, 1, 1)
end

function ModelFactory.egg(eggType: string, diameter: number?)
	local d = diameter or 2.4
	local spotColor, spotMaterial = Color3.new(1, 1, 1), Enum.Material.SmoothPlastic
	if eggType == "unknown" then
		spotColor, spotMaterial = Color3.fromHex("#C04CFF"), Enum.Material.Neon
	elseif eggType == "starter" then
		spotColor = Color3.fromHex("#FF9F43")
	end

	local model = Instance.new("Model")
	local def = Config.EGGS[eggType]
	model.Name = def and def.displayName or "Egg"

	-- the Blender egg, once its asset IDs are in Sprites
	local texture = Sprites.eggTexture(eggType)
	if Sprites.eggMesh ~= "" and texture ~= "" then
		local body = Instance.new("MeshPart")
		body.Name = "Body"
		body.MeshId = Sprites.eggMesh
		body.TextureID = texture
		body.Size = Vector3.new(d, d * 1.3, d)
		body.Anchored = true
		body.TopSurface = Enum.SurfaceType.Smooth
		body.BottomSurface = Enum.SurfaceType.Smooth
		body.Parent = model
		model:SetAttribute("EggType", eggType)
		model.PrimaryPart = body
		return model
	end

	local body = block(model, "Body", Vector3.new(d, d, d), CFrame.new(), ModelFactory.eggColor(eggType))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = body

	local r = d / 2
	for i, dir in SPOT_DIRS do
		local u = dir.Unit
		local t = 1 / math.sqrt((u.X / r) ^ 2 + (u.Y / (1.3 * r)) ^ 2 + (u.Z / r) ^ 2)
		ball(model, "Spot" .. i, d * 0.2, u * (t - d * 0.04), spotColor, spotMaterial)
	end

	model:SetAttribute("EggType", eggType)
	model.PrimaryPart = body
	return model
end

---------------------------------------------------------------------------
-- Stand-in worker (used when a friend's avatar isn't available):
-- a little smiley ball in a hard hat
---------------------------------------------------------------------------
ModelFactory.WORKER_SIZE = 2.8
ModelFactory.WORKER_FLOOR_OFFSET = 2.8 * 0.59 -- body centre height above the floor

function ModelFactory.worker(diameter: number?)
	local d = diameter or ModelFactory.WORKER_SIZE
	local model = Instance.new("Model")
	model.Name = "Worker"
	local body = ball(model, "Body", d, Vector3.zero, Color3.fromHex("#F4F4F4"))
	addFace(model, "ball", d / 2, "smile")
	local hat = Color3.fromHex("#FFC93C")
	ball(model, "HatDome", d * 0.7, Vector3.new(0, d * 0.27, d * 0.02), hat)
	cylinder(model, "HatBrim", d * 0.9, d * 0.06, Vector3.new(0, d * 0.36, -d * 0.06), hat)
	local feet = Color3.fromHex("#3B3F52")
	ball(model, "FootL", d * 0.3, Vector3.new(-d * 0.2, -d * 0.44, -d * 0.06), feet)
	ball(model, "FootR", d * 0.3, Vector3.new(d * 0.2, -d * 0.44, -d * 0.06), feet)
	model.PrimaryPart = body
	return model
end

---------------------------------------------------------------------------
-- Turn a built model into something that can be welded to a character
---------------------------------------------------------------------------
function ModelFactory.makeHoldable(model: Model)
	local body = model.PrimaryPart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if part ~= body then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	return model
end

return ModelFactory
