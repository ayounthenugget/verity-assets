-- Main (server)
-- Wires everything together: save data, the tycoon plots, offline earnings,
-- income ticks, the leaderboard, and the remotes the client UI talks to.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Actions = require(Shared:WaitForChild("Actions"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local TycoonService = require(script.Parent:WaitForChild("TycoonService"))
local DevService = require(script.Parent:WaitForChild("DevService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

DataService.start()

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local oldRemotes = ReplicatedStorage:FindFirstChild("Remotes")
if oldRemotes then
	oldRemotes:Destroy()
end
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local actionRemote = Instance.new("RemoteFunction")
actionRemote.Name = "Action" -- client -> server: ok, result = Action:InvokeServer("buyEgg", "common")
actionRemote.Parent = remotes

local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State" -- server -> client: full save snapshot after any change
stateRemote.Parent = remotes

local noticeRemote = Instance.new("RemoteEvent")
noticeRemote.Name = "Notice" -- server -> client: (kind, payload), e.g. ("Hired", { roomId, core })
noticeRemote.Parent = remotes

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local function notify(player: Player, kind: string, payload)
	if player.Parent then
		noticeRemote:FireClient(player, kind, payload)
	end
end

local coinLabels = {} -- [Player] = StringValue in leaderstats

local function refreshCoins(player: Player, data)
	player:SetAttribute("Coins", data.coins)
	local label = coinLabels[player]
	if label then
		label.Value = Economy.formatCoins(data.coins)
	end
end

local function pushState(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local view = table.clone(data)
	view.session = nil
	view.incomePerSecond = Economy.incomePerSecond(data)
	view.displayMultiplier = Economy.displayMultiplier(data)
	player:SetAttribute("IncomePerSecond", view.incomePerSecond)
	refreshCoins(player, data)
	stateRemote:FireClient(player, view)
end

DataService.onChanged(function(player)
	pushState(player)
	TycoonService.refresh(player)
end)

---------------------------------------------------------------------------
-- Actions: every change to a save goes through applyAction
---------------------------------------------------------------------------
local handlers = {
	buyEgg = function(data, eggType)
		return Actions.buyEgg(data, eggType)
	end,
	hold = function(data, kind, id)
		return Actions.hold(data, kind, id)
	end,
	unhold = function(data)
		return Actions.unhold(data)
	end,
	hatch = function(data)
		return Actions.hatchHeld(data, rng)
	end,
	discard = function(data, kind, id)
		return Actions.discard(data, kind, id)
	end,
	equip = function(data, verityId, slotIndex)
		return Actions.equip(data, verityId, slotIndex)
	end,
	unequip = function(data, slotIndex)
		return Actions.unequip(data, slotIndex)
	end,
	buySlot = function(data)
		return Actions.buySlot(data)
	end,
	unlockRoom = function(data, roomId)
		return Actions.unlockRoom(data, roomId)
	end,
	introSeen = function(data)
		return QuestService.introSeen(data)
	end,
	chooseEnding = function(data, choice)
		return QuestService.chooseEnding(data, choice)
	end,
	upgrade = function(data, roomId, index)
		return Actions.upgrade(data, roomId, index)
	end,
	usePedestal = function(data, slotIndex)
		return Actions.usePedestal(data, slotIndex)
	end,
	roomRequirements = function(data, roomId)
		local req = Actions.roomRequirements(data, roomId)
		if not req then
			return false, "NotFound"
		end
		return true, req
	end,
}

-- Wave from the friend you just upgraded (not on every rapid buy)
local lastWave = {}
local function maybeWave(player, roomId, index)
	local key = player.UserId .. roomId .. tostring(index)
	local now = os.clock()
	if (lastWave[key] or 0) + 2.5 < now then
		lastWave[key] = now
		TycoonService.celebrate(player, roomId, index)
	end
end

local READ_ONLY = { roomRequirements = true }
local SAVE_SOON = { introSeen = true, chooseEnding = true, buyEgg = true, hatch = true, discard = true, unlockRoom = true, buySlot = true, usePedestal = true }

local function applyAction(player: Player, action: string, ...)
	local handler = handlers[action]
	if not handler then
		return false, "UnknownAction"
	end
	local data = DataService.get(player)
	if not data then
		return false, "NotLoaded"
	end
	local callOk, ok, result = pcall(handler, data, ...)
	if not callOk then
		warn("[Main] Action '" .. action .. "' errored: " .. tostring(ok))
		return false, "ServerError"
	end
	if ok and not READ_ONLY[action] then
		DataService.markChanged(player)
		if action == "upgrade" then
			local roomId, index = ...
			maybeWave(player, roomId, index)
		end
		if SAVE_SOON[action] then
			DataService.requestSave(player)
		end
	end
	return ok, result
end

local function giveOfflineEarnings(player: Player, data, awaySeconds: number)
	if awaySeconds < Config.OFFLINE_MIN_SECONDS then
		return
	end
	local earned = Economy.offlineEarnings(Economy.incomePerSecond(data), awaySeconds)
	if earned > 0 then
		Actions.addCoins(data, earned)
		notify(player, "OfflineEarnings", { seconds = awaySeconds, coins = earned })
	end
end

TycoonService.init({ DataService = DataService, notify = notify })
QuestService.init({ DataService = DataService, notify = notify })
DevService.init({
	DataService = DataService,
	remotes = remotes,
	notify = notify,
	simulateOffline = function(player, seconds)
		local data = DataService.get(player)
		if data then
			giveOfflineEarnings(player, data, seconds)
		end
	end,
})

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------------
-- Join / leave
---------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	TycoonService.assign(player) -- first, so the character spawns at home

	local data = DataService.load(player)
	if not data then
		if player.Parent then
			player:Kick("We couldn't load your save right now. Please rejoin in a minute.")
		end
		return
	end

	-- Offline earnings (uncapped, diminishing)
	local now = os.time()
	if data.lastSeen > 0 then
		giveOfflineEarnings(player, data, now - data.lastSeen)
	end
	data.lastSeen = now

	-- Prototype: hand out the Starter Egg until the tutorial does it.
	if Config.DEV_GRANT_STARTER_EGG_ON_JOIN and not data.flags.starterEggGranted then
		if Actions.grantEgg(data, "starter") then
			data.flags.starterEggGranted = true
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Verity Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player
	coinLabels[player] = coins

	player:SetAttribute("DataLoaded", true)
	DataService.markChanged(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local buckets = {}

Players.PlayerRemoving:Connect(function(player)
	coinLabels[player] = nil
	buckets[player] = nil
	TycoonService.unassign(player)
	DataService.release(player)
end)

---------------------------------------------------------------------------
-- Income: every second, each player's tycoon pays out
---------------------------------------------------------------------------
task.spawn(function()
	while true do
		local dt = task.wait(1)
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			if data then
				local rate = Economy.incomePerSecond(data)
				if rate > 0 then
					Actions.addCoins(data, rate * dt)
					refreshCoins(player, data)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Action remote: menus and E prompts both call actions through here.
---------------------------------------------------------------------------
-- Simple token bucket so a client can't spam actions
local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = Config.ACTION_RATE_LIMIT, last = now }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(Config.ACTION_RATE_LIMIT, bucket.tokens + (now - bucket.last) * Config.ACTION_RATE_LIMIT)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

actionRemote.OnServerInvoke = function(player, action, ...)
	if type(action) ~= "string" then
		return false, "InvalidArgs"
	end
	if not allow(player) then
		return false, "TooFast"
	end
	if action == "sync" then
		pushState(player)
		return true
	elseif action == "goHome" then
		return TycoonService.goHome(player), nil
	end
	return applyAction(player, action, ...)
end
