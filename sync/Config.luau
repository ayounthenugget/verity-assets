-- Config
-- Every tunable number for Verity Tycoon lives here.
-- Values marked TUNE are placeholders. Changing them never needs a save migration.
-- To rename something players see, change displayName, never the key (keys are saved).

local Config = {}

---------------------------------------------------------------------------
-- Save data
---------------------------------------------------------------------------
Config.DATA_VERSION = 2
Config.DATASTORE_NAME = "VerityTycoon_Players"
Config.AUTOSAVE_INTERVAL = 120 -- seconds between background saves
Config.SESSION_LOCK_STALE = 360 -- a server lock older than this counts as abandoned (crashed server)
Config.LOAD_RETRIES = 6
Config.LOAD_RETRY_DELAY = 3
Config.SAVE_RETRIES = 3

---------------------------------------------------------------------------
-- Starting state
---------------------------------------------------------------------------
Config.STARTING_COINS = 10 -- enough to hire the first worker. TUNE
Config.STARTING_BACKPACK_CAPACITY = 5 -- eggs and Verities share this
Config.STARTING_DISPLAY_SLOTS = 3

-- Prototype helper: hand everyone the Starter Egg on first join.
-- Turn this off once the tutorial quest chain gives it out.
Config.DEV_GRANT_STARTER_EGG_ON_JOIN = false

-- Playtest switch: show the Dev panel (coins, quests, eggs, reset) to EVERY player, not just in Studio.
-- Each player can only change their own save. Set to false before the real launch.
Config.DEV_MENU_FOR_ALL = true

-- Remote spam protection: actions per second per player (holding E buys about 8 a second)
Config.ACTION_RATE_LIMIT = 14

---------------------------------------------------------------------------
-- Rarity tiers, lowest to highest
---------------------------------------------------------------------------
Config.TIERS = { "common", "rare", "epic", "legendary", "unknown" }

-- multiplier = how much a Verity of this tier multiplies ALL your Verity Coin income while on display.
-- Displayed Verities multiply together: x2 and x3 on display = x6. TUNE
Config.TIER_INFO = {
	common = { displayName = "Common", color = "#B8C0CC", multiplier = 1.2 },
	rare = { displayName = "Rare", color = "#4FA3FF", multiplier = 1.5 },
	epic = { displayName = "Epic", color = "#B05CFF", multiplier = 2 },
	legendary = { displayName = "Legendary", color = "#FFC23D", multiplier = 3 },
	unknown = { displayName = "Unknown", color = "#FF4FD8", multiplier = 5 },
}

---------------------------------------------------------------------------
-- Verity variants (the smiley ball characters). Verity himself is the hero, not hatchable.
-- Optional looks:  face = "smile" | "angry" | "flat" | "wavy" | "sad" | "smug"
--                  shape = "cube"   pattern = "rainbow"   ghost = true   size = 0.7 (smaller)
-- Add `multiplier = 1.3` to a variant to override its tier's multiplier. Tiers are TUNE.
---------------------------------------------------------------------------
Config.VARIANTS = {
	-- common
	falsity = { displayName = "Falsity", tier = "common", color = "#1F5FE0" },
	lovity = { displayName = "Lovity", tier = "common", color = "#FF4FD8" },
	helpity = { displayName = "Helpity", tier = "common", color = "#C79BFF" },
	boredity = { displayName = "Boredity", tier = "common", color = "#D6D6D6", face = "flat" },
	plantity = { displayName = "Plantity", tier = "common", color = "#7FA03A" },
	niceity = { displayName = "Niceity", tier = "common", color = "#FF9A1F" },
	blueity = { displayName = "Blueity", tier = "common", color = "#33B5FF" },
	-- rare
	curiosity = { displayName = "Curiosity", tier = "rare", color = "#2EDB2E" },
	buildity = { displayName = "Buildity", tier = "rare", color = "#FF5A1F" },
	cloudity = { displayName = "Cloudity", tier = "rare", color = "#8FF5FF" },
	friendlity = { displayName = "Friendlity", tier = "rare", color = "#C9971C" },
	cuteity = { displayName = "Cuteity", tier = "rare", color = "#FFB3DA", face = "wavy" },
	videoity = { displayName = "Videoity", tier = "rare", color = "#19E6B5" },
	-- epic
	cruelty = { displayName = "Cruelty", tier = "epic", color = "#F01E1E", face = "angry" },
	manipulity = { displayName = "Manipulity", tier = "epic", color = "#8A2BE2" },
	mineity = { displayName = "Mineity", tier = "epic", color = "#E040FB" },
	sadity = { displayName = "Sadity", tier = "epic", color = "#5B2BD9", face = "sad" },
	moggity = { displayName = "Moggity", tier = "epic", color = "#FFE135", face = "smug" },
	-- legendary
	rainbowity = { displayName = "Rainbowity", tier = "legendary", color = "#FF3B3B", pattern = "rainbow" },
	squishity = { displayName = "Squishity", tier = "legendary", color = "#29A8FF", shape = "cube" },
	invisibility = { displayName = "Invisibility", tier = "legendary", color = "#FFFFFF", ghost = true },
	-- unknown
	verity2 = { displayName = "Verity.2", tier = "unknown", color = "#FFC20E" },
	verityfalsitychild = { displayName = "Verity x Falsity Child", tier = "unknown", color = "#9CF04A", size = 0.7 },
}

---------------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------------
Config.EGG_PRICE_GROWTH = 1.037 -- each purchase of an egg type multiplies its price (5 buys = about 1.2x)
Config.REFUND_RATE = 0.8 -- discarding returns 80% of what was paid. TUNE

-- Completing quests nudges every egg toward rarer tiers.
Config.QUEST_LUCK_PER_QUEST = 0.02 -- TUNE
Config.QUEST_LUCK_MAX = 0.5 -- TUNE

Config.SHOP_EGGS = { "common", "rare", "epic", "legendary", "unknown" } -- shop display order

-- weights: relative chance of each tier. Missing tier = cannot roll. TUNE
Config.EGGS = {
	starter = {
		displayName = "Starter Egg",
		basePrice = 0,
		inShop = false,
		fixedVariant = "lovity", -- everyone's first Verity. TUNE
	},
	common = {
		displayName = "Common Egg",
		basePrice = 250,
		inShop = true,
		weights = { common = 80, rare = 18, epic = 2 },
	},
	rare = {
		displayName = "Rare Egg",
		basePrice = 5_000,
		inShop = true,
		weights = { common = 30, rare = 55, epic = 13, legendary = 2 },
	},
	epic = {
		displayName = "Epic Egg",
		basePrice = 150_000,
		inShop = true,
		weights = { rare = 35, epic = 50, legendary = 14, unknown = 1 },
	},
	legendary = {
		displayName = "Legendary Egg",
		basePrice = 5_000_000,
		inShop = true,
		weights = { epic = 40, legendary = 52, unknown = 8 },
	},
	unknown = {
		displayName = "Unknown Egg",
		basePrice = 250_000_000,
		inShop = true,
		weights = { legendary = 70, unknown = 30 },
	},
}

---------------------------------------------------------------------------
-- Display slots in front of the tycoon
-- Each extra slot needs completed quests AND Verity coins. TUNE
---------------------------------------------------------------------------
Config.EXTRA_SLOTS = {
	{ questsRequired = 3, cost = 25_000 }, -- slot 4
	{ questsRequired = 6, cost = 2_500_000 }, -- slot 5
	{ questsRequired = 10, cost = 250_000_000 }, -- slot 6
}

---------------------------------------------------------------------------
-- Locations and their workers
-- Each location has worker stations (a worker + their Verity Core).
-- Press E at a station to hire its worker (level 1), then again to level them up.
-- Stations in a location are hired in order. Every level adds `revenue` per cycle;
-- every MILESTONE level doubles that worker's speed (the X2 / X4 badge).
--   revenue: Verity coins per cycle at level 1      cycle: seconds per cycle at level 1
--   cost: price of the first hire                   growth: each level costs this much more
---------------------------------------------------------------------------
Config.MILESTONES = { 10, 25, 50, 100, 150, 200, 300, 400, 500, 750, 1000 } -- TUNE
Config.MIN_SHOWN_CYCLE = 0.05 -- the "every 0.05s" bar never shows faster than this
Config.MAX_LEVEL = 5000

Config.ROOM_ORDER = { "house", "barn" }

Config.ROOMS = {
	house = {
		displayName = "House",
		startsUnlocked = true,
		stations = { -- TUNE
			{ displayName = "Spark Core", revenue = 1, cycle = 1, cost = 10, growth = 1.09 },
			{ displayName = "Glow Core", revenue = 12, cycle = 3, cost = 150, growth = 1.11 },
			{ displayName = "Hum Core", revenue = 90, cycle = 6, cost = 2_000, growth = 1.12 },
			{ displayName = "Pulse Core", revenue = 700, cycle = 12, cost = 25_000, growth = 1.13 },
		},
	},
	barn = {
		displayName = "Barn",
		startsUnlocked = false,
		unlockQuest = "farmers_call", -- quest that must be complete first
		unlockCost = 50_000, -- Verity coins spent to open the door. TUNE
		stations = { -- TUNE
			{ displayName = "Hay Core", revenue = 6_000, cycle = 20, cost = 120_000, growth = 1.13 },
			{ displayName = "Lantern Core", revenue = 40_000, cycle = 30, cost = 1_000_000, growth = 1.14 },
			{ displayName = "Lemon Core", revenue = 250_000, cycle = 45, cost = 9_000_000, growth = 1.14 },
			{ displayName = "Harvest Core", revenue = 1_600_000, cycle = 60, cost = 80_000_000, growth = 1.15 },
		},
	},
}

---------------------------------------------------------------------------
-- Offline earnings: uncapped, but the rate drops the longer you are away
---------------------------------------------------------------------------
Config.OFFLINE_TIERS = {
	{ upToSeconds = 3_600, rate = 1.0 }, -- first hour: full rate
	{ upToSeconds = 4 * 3_600, rate = 0.5 }, -- hours 1 to 4: half rate
	{ upToSeconds = math.huge, rate = 0.25 }, -- after that: quarter rate, forever
}
Config.OFFLINE_MIN_SECONDS = 60 -- shorter absences earn nothing extra

return Config
