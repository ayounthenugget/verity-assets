-- DefaultData
-- The save file a brand-new player starts with.
-- Arrays never contain nil holes (DataStores turn those into broken JSON);
-- an empty display slot is "".

local Config = require(script.Parent.Config)

local DefaultData = {}

function DefaultData.new()
	local rooms = {}
	for roomId, room in Config.ROOMS do
		local levels = {}
		for i = 1, #room.stations do
			levels[i] = 0 -- worker level at each station; 0 = not hired yet
		end
		rooms[roomId] = {
			unlocked = room.startsUnlocked == true,
			levels = levels,
		}
	end

	local equipped = {}
	for i = 1, Config.STARTING_DISPLAY_SLOTS do
		equipped[i] = ""
	end

	local eggPurchases = {}
	for eggType in Config.EGGS do
		eggPurchases[eggType] = 0 -- drives egg price scaling
	end

	return {
		version = Config.DATA_VERSION,
		coins = Config.STARTING_COINS,
		lifetimeCoins = 0,
		lastSeen = 0, -- os.time() of the last save; used for offline earnings
		nextId = 1, -- counter for unique egg and Verity ids

		backpack = {
			capacity = Config.STARTING_BACKPACK_CAPACITY,
			eggs = {}, -- { id, type, paid }
			verities = {}, -- { id, variant, tier, paid }
		},
		hand = nil, -- { kind = "egg" | "verity", id } or nil

		slots = {
			equipped = equipped, -- Verity ids on display; "" = empty. Length = slots owned
		},

		eggPurchases = eggPurchases,
		rooms = rooms,

		quests = {
			completed = {}, -- [questId] = true
			activeId = "",
			step = 0,
			progress = 0,
		},

		flags = {
			introSeen = false,
			tutorialDone = false,
			starterEggGranted = false,
			endingChoice = "", -- "" | "backrooms" | "blocklands"
		},
	}
end

return DefaultData
