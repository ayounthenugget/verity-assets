-- DevService
-- Testing shortcuts for playtesting: always in Studio, and for everyone while
-- Config.DEV_MENU_FOR_ALL is true (turn it off for a real launch): give coins, finish quests, grant eggs, reset your save.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Actions = require(Shared:WaitForChild("Actions"))
local DefaultData = require(Shared:WaitForChild("DefaultData"))

local DevService = {}

function DevService.init(ctx)
	if not (RunService:IsStudio() or Config.DEV_MENU_FOR_ALL) then
		return
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Dev"
	remote.Parent = ctx.remotes

	remote.OnServerInvoke = function(player, command, arg)
		local data = ctx.DataService.get(player)
		if not data then
			return false, "NotLoaded"
		end
		if command == "coins" then
			Actions.addCoins(data, tonumber(arg) or 0)
		elseif command == "quest" then
			if type(arg) ~= "string" or arg == "" then
				arg = "dev_quest_" .. (Actions.questsCompleted(data) + 1)
			end
			Actions.completeQuest(data, arg)
		elseif command == "egg" then
			local ok, err = Actions.grantEgg(data, tostring(arg))
			if not ok then
				return false, err
			end
		elseif command == "reset" then
			local fresh = DefaultData.new()
			fresh.lastSeen = os.time()
			if Config.DEV_GRANT_STARTER_EGG_ON_JOIN and Actions.grantEgg(fresh, "starter") then
				fresh.flags.starterEggGranted = true
			end
			ctx.DataService.replaceData(player, fresh)
		elseif command == "offline" then
			-- pretend the player was away for `arg` seconds
			ctx.simulateOffline(player, tonumber(arg) or 3600)
		else
			return false, "UnknownCommand"
		end
		ctx.DataService.markChanged(player)
		return true
	end
end

return DevService
