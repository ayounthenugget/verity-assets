-- Npcs: characters standing in your world that only you see (client-built).
-- Right now: the old farmer beside the barn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local QuestTargets = require(Shared:WaitForChild("QuestTargets"))

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)

local Npcs = {}

local function nameTag(model: Model, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = model.PrimaryPart
	gui.Size = UDim2.fromOffset(150, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = model.PrimaryPart
	Theme.text({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		Font = Theme.Chunky,
		TextColor3 = Color3.fromHex("#FF9F43"),
		MaxTextSize = 30,
		Outline = 3,
		Parent = gui,
	})
end

local function spawnFarmer(plot: Instance)
	local cf = QuestTargets.farmerCFrame(plot)
	if not cf then
		return
	end
	local farmer = ModelFactory.farmer(3.4)
	farmer:PivotTo(cf)
	farmer.Parent = workspace
	nameTag(farmer, "Farmer")
	local base = cf
	local blinkAt = os.clock() + 2
	local closed = false
	RunService.Heartbeat:Connect(function()
		if not farmer.Parent then
			return
		end
		local t = os.clock()
		farmer:PivotTo(base * CFrame.new(0, math.abs(math.sin(t * 1.6)) * 0.35, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.2, 0))
		if t > blinkAt then
			closed = not closed
			ModelFactory.setFace(farmer, if closed then "blink" else "happy")
			blinkAt = t + (if closed then 0.14 else math.random(2, 5))
		end
	end)
	plot.AncestryChanged:Connect(function()
		if not plot.Parent then
			farmer:Destroy()
		end
	end)
end

function Npcs.init()
	task.spawn(function()
		local built = nil
		while true do
			local plot = State.plot()
			if plot and plot ~= built and plot:FindFirstChild("Rooms") then
				built = plot
				spawnFarmer(plot)
			end
			task.wait(1)
		end
	end)
end

return Npcs
