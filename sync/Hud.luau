-- Hud: coin counter, income multiplier, the side buttons, and the "holding"
-- bar (with the big HATCH button while you hold an egg). Studio also gets a dev panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Economy = require(Shared:WaitForChild("Economy"))
local Actions = require(Shared:WaitForChild("Actions"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))

local Theme = require(script.Parent.Theme)
local Gui = require(script.Parent.Gui)
local Format = require(script.Parent.Format)
local State = require(script.Parent.State)
local Viewport = require(script.Parent.Viewport)
local Toasts = require(script.Parent.Toasts)
local Messages = require(script.Parent.Messages)
local Backpack = require(script.Parent.Backpack)
local HatchReveal = require(script.Parent.HatchReveal)

local Hud = {}
local player = Players.LocalPlayer

local function sideButton(parent, order: number, icon: string, label: string, color: Color3, deep: Color3, onClick)
	local api = Theme.button({
		Text = "",
		Size = UDim2.fromOffset(88, 92),
		LayoutOrder = order,
		Color = color,
		Deep = deep,
		Radius = 22,
		Parent = parent,
		OnClick = onClick,
	})
	if string.sub(icon, 1, 13) == "rbxassetid://" then
		Theme.make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 5),
			Size = UDim2.fromOffset(50, 50),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = api.Face,
		})
	else
		Theme.text({
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 46),
			Text = icon,
			ZIndex = 3,
			Parent = api.Face,
		})
	end
	Theme.text({
		Position = UDim2.new(0, 4, 1, -32),
		Size = UDim2.new(1, -8, 0, 26),
		Text = label,
		Font = Theme.Chunky,
		MaxTextSize = 20,
		Outline = 2.5,
		ZIndex = 3,
		Parent = api.Face,
	})
	return api
end

function Hud.init()
	local root = Gui.layer("Hud", 1, false)

	---------------------------------------------------------------------------
	-- Coins
	---------------------------------------------------------------------------
	local coinHolder, coinPill = Theme.card({
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(250, 78),
		Radius = 28,
		Top = Color3.fromHex("#4A3FB0"), -- Midnight Sunshine: deep violet with a golden number
		Bottom = Color3.fromHex("#1E1752"),
		Parent = root,
	})
	local coinIcon = Theme.coin(58, { Position = UDim2.fromOffset(14, 10), Parent = coinPill })
	local amountLabel = Theme.text({
		Position = UDim2.fromOffset(84, 6),
		Size = UDim2.new(1, -100, 1, -12),
		Text = "0",
		Font = Theme.Chunky,
		TextColor3 = Color3.fromHex("#FFE27A"),
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 44,
		Outline = 3,
		Parent = coinPill,
	})
	local boostPill, boostFace = Theme.card({
		Name = "Boost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 106),
		Size = UDim2.fromOffset(190, 46),
		Radius = 20,
		Lip = 6,
		Top = Color3.fromHex("#7CFF8A"),
		Bottom = Color3.fromHex("#1FB85A"),
		Visible = false,
		Parent = root,
	})
	local boostLabel = Theme.text({
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		Font = Theme.Chunky,
		MaxTextSize = 24,
		Outline = 2.5,
		Parent = boostFace,
	})

	local shown = 0
	local lastWhole = -1
	RunService.Heartbeat:Connect(function(dt)
		local target = State.coins()
		if math.abs(target - shown) < 0.5 then
			shown = target
		else
			shown += (target - shown) * math.min(1, dt * 8)
		end
		local whole = math.floor(shown)
		if whole ~= lastWhole then
			lastWhole = whole
			amountLabel.Text = Format.coins(whole)
		end
	end)
	local bounce = Instance.new("UIScale")
	bounce.Parent = coinIcon
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		bounce.Scale = 1.15
		TweenService:Create(bounce, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)

	---------------------------------------------------------------------------
	-- Side buttons
	---------------------------------------------------------------------------
	local side = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(92, 210),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Theme.make("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local bag = sideButton(side, 1, Sprites.bag, "Bag", Theme.C.Violet, Theme.C.VioletDeep, function()
		Backpack.toggle()
	end)
	local bagBadge = Theme.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 10, 0, -10),
		Size = UDim2.fromOffset(48, 26),
		BackgroundColor3 = Theme.C.Red,
		ZIndex = 4,
		Parent = bag.Holder,
	}, { Theme.corner(13), Theme.stroke(Theme.C.Line, 3) })
	local bagCount = Theme.text({ Size = UDim2.fromScale(1, 1), Font = Theme.Chunky, MaxTextSize = 15, Outline = 1.5, ZIndex = 4, Parent = bagBadge })

	sideButton(side, 2, Sprites.home, "Home", Theme.C.Cyan, Theme.C.CyanDeep, function()
		State.invoke("goHome")
	end)

	---------------------------------------------------------------------------
	-- Holding bar
	---------------------------------------------------------------------------
	local heldBar, heldFace = Theme.card({
		Name = "Holding",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(470, 100),
		Radius = 26,
		Visible = false,
		Parent = root,
	})
	local heldVpf = Theme.make("ViewportFrame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(72, 72),
		BackgroundTransparency = 1,
		Parent = heldFace,
	})
	Theme.text({
		Position = UDim2.fromOffset(94, 16),
		Size = UDim2.fromOffset(160, 18),
		Text = "HOLDING",
		TextColor3 = Color3.fromHex("#4A4470"),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = heldFace,
	})
	local heldName = Theme.text({
		Position = UDim2.fromOffset(94, 34),
		Size = UDim2.fromOffset(170, 32),
		Font = Theme.Chunky,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Outline = 2,
		Parent = heldFace,
	})
	local heldHint = Theme.text({
		Position = UDim2.fromOffset(94, 66),
		Size = UDim2.fromOffset(156, 15),
		TextColor3 = Color3.fromHex("#4A4470"),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 12,
		Parent = heldFace,
	})
	local hatching = false
	local hatchButton = Theme.button({
		Text = "HATCH!",
		Font = Theme.Chunky,
		Size = UDim2.fromOffset(116, 64),
		Position = UDim2.new(1, -190, 0, 14),
		Color = Theme.C.Green,
		Deep = Theme.C.GreenDeep,
		Sound = "pop",
		MaxTextSize = 26,
		Parent = heldFace,
		OnClick = function()
			local data = State.data
			if hatching or not data or not data.hand or data.hand.kind ~= "egg" then
				return
			end
			local egg = State.findItem("egg", data.hand.id)
			if not egg then
				return
			end
			hatching = true
			local ok, result = State.invoke("hatch")
			hatching = false
			if ok then
				HatchReveal.play(egg.type, result)
			else
				Toasts.show(Messages.forError(result), "bad")
			end
		end,
	})
	Theme.button({
		Text = "X",
		Font = Theme.Chunky,
		Size = UDim2.fromOffset(62, 64),
		Position = UDim2.new(1, -70, 0, 14),
		Color = Theme.C.Red,
		Deep = Theme.C.RedDeep,
		Parent = heldFace,
		OnClick = function()
			State.invoke("unhold")
		end,
	})

	local heldKey = ""
	local function refresh(data)
		if not data then
			return
		end
		local mult = data.displayMultiplier or 1
		boostPill.Visible = mult > 1.0001
		boostLabel.Text = Economy.formatMultiplier(mult) .. " income"
		bagCount.Text = Actions.backpackCount(data) .. "/" .. data.backpack.capacity

		local hand = data.hand
		local item = hand and State.findItem(hand.kind, hand.id)
		if not item then
			heldBar.Visible = false
			heldKey = ""
			return
		end
		local key = hand.kind .. ":" .. hand.id
		heldBar.Visible = true
		if key ~= heldKey then
			heldKey = key
			if hand.kind == "egg" then
				local def = Config.EGGS[item.type]
				heldName.Text = def and def.displayName or "Egg"
				heldName.TextColor3 = Theme.rarity(if item.type == "starter" then "common" else item.type)
				heldHint.Text = "Tap HATCH to see who's inside!"
				Viewport.set(heldVpf, ModelFactory.egg(item.type, 2), { zoom = 1.1, sway = 1.2 })
			else
				local variant = Config.VARIANTS[item.variant]
				heldName.Text = variant and variant.displayName or "???"
				heldName.TextColor3 = Theme.rarity(item.tier)
				heldHint.Text = "Press E at a pedestal out front to display"
				Viewport.set(heldVpf, ModelFactory.verity(item.variant, 2.4), { zoom = 1.1, sway = 1.2 })
			end
			Gui.pop(heldBar, 0.85)
		end
		hatchButton.Holder.Visible = hand.kind == "egg"
	end
	State.Changed:Connect(refresh)
	if State.data then
		refresh(State.data)
	end

	---------------------------------------------------------------------------
	-- Dev panel (Studio, or everyone while Config.DEV_MENU_FOR_ALL is on)
	---------------------------------------------------------------------------
	task.spawn(function()
		local dev = State.devRemote() or ReplicatedStorage.Remotes:WaitForChild("Dev", 3)
		if not dev then
			return
		end
		local panel = Theme.make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -24, 0, 92),
			Size = UDim2.fromOffset(160, 360),
			BackgroundTransparency = 1,
			Parent = root,
		}, { Theme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local open = false
		local items = {}
		local header = Theme.button({
			Text = "DEV +",
			Size = UDim2.fromOffset(160, 42),
			LayoutOrder = 0,
			Color = Theme.C.Grey,
			Deep = Theme.C.GreyDeep,
			MaxTextSize = 18,
			Parent = panel,
		})
		local function devButton(order, text, command, arg)
			local b = Theme.button({
				Text = text,
				Size = UDim2.fromOffset(160, 38),
				LayoutOrder = order,
				Color = Theme.C.CardHi,
				Deep = Theme.C.Line,
				MaxTextSize = 15,
				Visible = false,
				Parent = panel,
				OnClick = function()
					local ok, err = dev:InvokeServer(command, arg)
					Toasts.show(if ok then "Dev: " .. text else "Dev failed: " .. tostring(err), if ok then "info" else "bad")
				end,
			})
			table.insert(items, b)
		end
		devButton(1, "+1K coins", "coins", 1000)
		devButton(2, "+100K coins", "coins", 100000)
		devButton(3, "+10M coins", "coins", 10000000)
		devButton(4, "Finish Farmer's Call", "quest", "farmers_call")
		devButton(5, "+1 quest", "quest", "")
		devButton(6, "Give Starter Egg", "egg", "starter")
		devButton(7, "Away 3 hours", "offline", 3 * 3600)
		devButton(8, "Reset save", "reset", nil)
		header.Face.Activated:Connect(function()
			open = not open
			header.setText(if open then "DEV -" else "DEV +")
			for _, b in items do
				b.Holder.Visible = open
			end
		end)
	end)
end

return Hud
