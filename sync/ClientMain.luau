-- Main (client): starts the UI and world effects, and reacts to messages from the server.

local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = script.Parent
local player = Players.LocalPlayer
local Quests = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"))
local Format = require(modules.Format)
local State = require(modules.State)
local Toasts = require(modules.Toasts)
local Messages = require(modules.Messages)
local Dialogs = require(modules.Dialogs)
local Shop = require(modules.Shop)
local Hud = require(modules.Hud)
local WorldFx = require(modules.WorldFx)
local Stations = require(modules.Stations)
local Pads = require(modules.Pads)
local QuestHud = require(modules.QuestHud)
local Npcs = require(modules.Npcs)
local DialogueBox = require(modules.DialogueBox)
local Cutscene = require(modules.Cutscene)
local Cutscenes = require(modules.Cutscenes)
local Sounds = require(modules.Sounds)

-- The egg / Verity you hold is a Tool, so hide Roblox's default hotbar
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			break
		end
		task.wait(0.5)
	end
end)

Hud.init()
WorldFx.init()
Stations.init()
Pads.init()
QuestHud.init()
QuestHud.onFinale = function()
	if not Cutscene.isActive() then
		Cutscene.play(Cutscenes.finale)
	end
end
Npcs.init()

-- E prompts in the world
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local action = prompt:GetAttribute("Action")
	if action == "OpenShop" then
		Shop.open()
	elseif action == "Pedestal" then
		local slot = prompt:GetAttribute("SlotIndex")
		local ok, result = State.invoke("usePedestal", slot)
		if ok and type(result) == "table" then
			if result.bought then
				Sounds.play("reveal")
				Toasts.show("Display slot " .. result.bought .. " unlocked!", "big")
			else
				Sounds.play("pop")
				Toasts.show("On display in slot " .. result.slot .. "! Your Verity Coin income is multiplied.", "good")
			end
		elseif not ok then
			Toasts.show(Messages.forError(result), "bad")
		end
	end
end)

-- Messages from the server
State.Notice:Connect(function(kind, payload)
	if kind == "OfflineEarnings" then
		Dialogs.offlineEarnings(payload.seconds, payload.coins)
	elseif kind == "RoomLocked" then
		-- the glowing pad in front of the door shows the tasks now (see Pads)
	elseif kind == "Dialogue" then
		task.spawn(function()
			while Cutscene.isActive() do
				task.wait(0.2)
			end
			DialogueBox.play(payload.id)
		end)
	elseif kind == "QuestStarted" then
		Sounds.play("open")
		Toasts.show("New quest: " .. Quests.name(payload.id), "good")
	elseif kind == "QuestDone" then
		Sounds.play("reveal")
		local msg = "Quest complete: " .. Quests.name(payload.id)
		if payload.coins and payload.coins > 0 then
			msg ..= "  +" .. Format.coins(payload.coins) .. " coins"
		end
		Toasts.show(msg, "big")
		if payload.egg then
			Toasts.show("You got an egg!", "good")
		end
	elseif kind == "Toast" then
		Toasts.show(payload.text, payload.kind)
	elseif kind == "ActionFailed" then
		Toasts.show(Messages.forError(payload.err, payload), "bad")
	end
end)

-- Celebrate when a locked place opens
local unlocked = {}
State.Changed:Connect(function(data)
	for roomId, room in data.rooms do
		if unlocked[roomId] == false and room.unlocked then
			WorldFx.onUnlocked(roomId)
		end
		unlocked[roomId] = room.unlocked
	end
end)

---------------------------------------------------------------------------
-- The opening cutscene plays once, for a brand-new save
---------------------------------------------------------------------------
local introRunning = false
local function maybeIntro(data)
	if introRunning or not data or data.flags.introSeen then
		return
	end
	introRunning = true
	task.spawn(function()
		-- wait for the world and your character
		for _ = 1, 40 do
			local char = player.Character
			if State.plot() and char and char:FindFirstChild("HumanoidRootPart") then
				break
			end
			task.wait(0.5)
		end
		task.wait(1)
		Cutscene.play(Cutscenes.intro)
		State.invoke("introSeen")
		introRunning = false
	end)
end
State.Changed:Connect(maybeIntro)
maybeIntro(State.data)
