-- Guide: the green arrow. A glowing arrow floats beside your avatar and points the way to the
-- current quest goal. It asks Roblox's pathfinder for a route, so it steers around walls and
-- fences, with a trail of green dots on the ground and a column of light at the destination.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Guide = {}
local player = Players.LocalPlayer

local GREEN = Color3.fromHex("#3DFF6A")
local TRAIL_SPACING = 7
local MAX_TRAIL = 9

local arrow, trail, marker = nil, {}, nil
local target = nil -- Vector3?
local radius = 8
local waypoints = {} -- Vector3 list from the last path
local lastPathAt, lastPathFrom, lastTarget = 0, nil, nil
local aimDir = Vector3.new(0, 0, -1)
local computing = false

local function neon(part: BasePart)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	part.Color = GREEN
end

local function buildArrow()
	local m = Instance.new("Model")
	m.Name = "GuideArrow"
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.9, 0.45, 2.4)
	neon(shaft)
	shaft.Parent = m
	-- arrowhead: two right-triangle wedges laid flat, mirrored, tip pointing forward (-Z)
	for i, sign in { 1, -1 } do
		local w = Instance.new("WedgePart")
		w.Name = "Head" .. i
		w.Size = Vector3.new(0.45, 1.3, 2.2) -- (thickness, half-width, length)
		neon(w)
		w.Parent = m
	end
	m.PrimaryPart = shaft
	m.Parent = workspace.CurrentCamera
	return m
end

local function placeArrow(cf: CFrame)
	-- shaft sits behind the head
	arrow.Shaft.CFrame = cf * CFrame.new(0, 0, 1.2)
	local headBase = cf * CFrame.new(0, 0, -0.4)
	-- wedges: rotate so their triangle lies in the XZ plane
	arrow.Head1.CFrame = headBase * CFrame.new(0.65, 0, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(180), 0)
	arrow.Head2.CFrame = headBase * CFrame.new(-0.65, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
end

local function buildMarker()
	local m = Instance.new("Model")
	m.Name = "GuideMarker"
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 12, 12)
	neon(ring)
	ring.Transparency = 0.35
	ring.Parent = m
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Size = Vector3.new(2.2, 60, 2.2)
	neon(beam)
	beam.Transparency = 0.7
	beam.Parent = m
	m.PrimaryPart = ring
	m.Parent = workspace.CurrentCamera
	return m
end

local function clearTrail()
	for _, p in trail do
		p:Destroy()
	end
	table.clear(trail)
end

local function ensure()
	if not arrow or not arrow.Parent then
		arrow = buildArrow()
	end
	if not marker or not marker.Parent then
		marker = buildMarker()
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function repath(from: Vector3, to: Vector3)
	if computing then
		return
	end
	computing = true
	lastPathAt, lastPathFrom, lastTarget = os.clock(), from, to
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false })
		local ok = pcall(function()
			path:ComputeAsync(from, to)
		end)
		local pts = {}
		if ok and path.Status == Enum.PathStatus.Success then
			for _, wp in path:GetWaypoints() do
				table.insert(pts, wp.Position)
			end
		end
		if #pts == 0 then
			pts = { to } -- no route found: point straight at it
		end
		waypoints = pts
		computing = false
	end)
end

-- Pass a world position (or nil to hide the arrow) and how close counts as "arrived"
function Guide.setTarget(pos: Vector3?, arrivedRadius: number?)
	target = pos
	radius = arrivedRadius or 8
	if not pos then
		waypoints = {}
		lastTarget = nil
		if arrow then
			arrow:Destroy()
			arrow = nil
		end
		if marker then
			marker:Destroy()
			marker = nil
		end
		clearTrail()
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not target then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	ensure()
	local here = root.Position
	local distance = flat(target - here).Magnitude

	-- the light column and ring at the destination
	local groundY = target.Y
	marker.Ring.CFrame = CFrame.new(target.X, groundY + 0.4, target.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Ring.Size = Vector3.new(0.3, radius * 1.6, radius * 1.6)
	marker.Beam.CFrame = CFrame.new(target.X, groundY + 30, target.Z)

	if distance <= radius then
		arrow.Parent = nil
		clearTrail()
		return
	end
	arrow.Parent = workspace.CurrentCamera

	-- refresh the route every second or so (or if the goal moved / you wandered off it)
	if not lastTarget or (lastTarget - target).Magnitude > 2 or os.clock() - lastPathAt > 1.2 then
		repath(here, target)
	end

	-- next waypoint that's a few studs ahead
	local nextPoint = target
	for _, p in waypoints do
		if flat(p - here).Magnitude > 5 then
			nextPoint = p
			break
		end
	end
	local want = flat(nextPoint - here)
	if want.Magnitude > 0.1 then
		aimDir = aimDir:Lerp(want.Unit, math.min(1, dt * 9))
		if aimDir.Magnitude < 0.05 then
			aimDir = want.Unit
		end
	end
	local dir = aimDir.Unit
	local bob = math.sin(os.clock() * 4) * 0.35
	local base = here + Vector3.new(0, 5.4 + bob, 0) + dir * 3.2
	placeArrow(CFrame.lookAt(base, base + dir))

	-- the trail of dots along the route
	local drawn = 0
	local carry = 0
	local prev = here
	for _, p in waypoints do
		local seg = (p - prev)
		local len = seg.Magnitude
		local d = TRAIL_SPACING - carry
		while d <= len and drawn < MAX_TRAIL do
			drawn += 1
			local dot = trail[drawn]
			if not dot then
				dot = Instance.new("Part")
				dot.Shape = Enum.PartType.Ball
				dot.Size = Vector3.new(0.9, 0.9, 0.9)
				neon(dot)
				dot.Parent = workspace.CurrentCamera
				trail[drawn] = dot
			end
			local pos = prev + seg.Unit * d
			dot.Position = pos + Vector3.new(0, 0.9 + math.sin(os.clock() * 5 + drawn) * 0.15, 0)
			d += TRAIL_SPACING
		end
		carry = (carry + len) % TRAIL_SPACING
		prev = p
		if drawn >= MAX_TRAIL then
			break
		end
	end
	for i = drawn + 1, #trail do
		trail[i].Position = Vector3.new(0, -500, 0)
	end
end)

return Guide
