-- Quests: the questline. Each quest is a list of objectives done in order.
--   kinds:  goto{target,radius,dialogue?}  hold  hatch{n}  display  buyEgg  hire{n}  level{n}
--           coins{n}  unlock{room}  tier{tier}  slots{n}  finale
-- Objectives other than goto are read straight from your save, so progress can never get lost.
-- Quests 3, 6 and 10 matter: they open extra display slots (Config.EXTRA_SLOTS).

local Quests = {}

Quests.order = {
	"hello_verity",
	"show_off",
	"first_friend",
	"egg_shopping",
	"full_house",
	"farmers_call",
	"barn_raising",
	"barn_hands",
	"collector",
	"the_dark_egg",
	"hum_of_the_world",
	"where_do_i_belong",
}

Quests.defs = {
	hello_verity = {
		displayName = "Hello, Verity",
		summary = "Meet Verity and hatch your very first egg.",
		intro = "intro_after_cutscene",
		outro = "hatched_first",
		reward = { coins = 40 },
		objectives = {
			{ kind = "hold", text = "Open your Bag and hold the Starter Egg" },
			{ kind = "hatch", n = 1, text = "Press HATCH!" },
		},
	},
	show_off = {
		displayName = "Show Off",
		summary = "Put your new Verity on display. It boosts your income!",
		intro = "show_off_intro",
		reward = { coins = 60 },
		objectives = {
			{ kind = "goto", target = "display:1", radius = 9, text = "Walk to the glowing display stand" },
			{ kind = "display", text = "Put your Verity on display (press E)" },
		},
	},
	first_friend = {
		displayName = "A First Friend",
		summary = "Hire your first worker at a Spark Core.",
		intro = "first_friend_intro",
		outro = "first_friend_done",
		reward = { coins = 120 },
		objectives = {
			{ kind = "goto", target = "station:house:1", radius = 10, text = "Walk to the Spark Core" },
			{ kind = "hire", n = 1, text = "Hire a friend (press E)" },
		},
	},
	egg_shopping = {
		displayName = "Egg Shopping",
		summary = "Buy an egg from the Egg Shop.",
		intro = "egg_shopping_intro",
		reward = { coins = 250 },
		objectives = {
			{ kind = "coins", n = 250, text = "Earn 250 Verity Coins" },
			{ kind = "goto", target = "shop", radius = 12, text = "Walk to the Egg Shop" },
			{ kind = "buyEgg", text = "Buy any egg (press E)" },
		},
	},
	full_house = {
		displayName = "Full House",
		summary = "Staff three Verity Cores in the house.",
		intro = "full_house_intro",
		reward = { coins = 1500, egg = "common" },
		objectives = {
			{ kind = "hire", n = 3, text = "Hire 3 workers" },
		},
	},
	farmers_call = {
		displayName = "Farmer's Call",
		summary = "Help the old farmer, and he'll hand over the key to the barn.",
		intro = "farmers_call_intro",
		outro = "farmers_call_done",
		reward = { coins = 3000 },
		objectives = {
			{ kind = "goto", target = "farmer", radius = 12, dialogue = "farmer_talk", text = "Find the farmer by the barn" },
			{ kind = "level", n = 10, text = "Level a worker up to 10" },
		},
	},
	barn_raising = {
		displayName = "Barn Raising",
		summary = "Open the barn.",
		intro = "barn_raising_intro",
		outro = "barn_open",
		reward = { coins = 20000 },
		objectives = {
			{ kind = "coins", n = 50000, text = "Gather 50,000 Verity Coins" },
			{ kind = "goto", target = "barnDoor", radius = 8, text = "Step on the barn's glowing pad" },
			{ kind = "unlock", room = "barn", text = "Unlock the barn" },
		},
	},
	barn_hands = {
		displayName = "Barn Hands",
		summary = "Put the whole barn to work.",
		intro = "barn_hands_intro",
		reward = { coins = 150000, egg = "rare" },
		objectives = {
			{ kind = "hire", n = 6, text = "Have 6 workers hired" },
		},
	},
	collector = {
		displayName = "Collector",
		summary = "Gather a little family of Verities.",
		intro = "collector_intro",
		reward = { coins = 400000 },
		objectives = {
			{ kind = "verities", n = 4, text = "Own 4 Verities" },
			{ kind = "slots", n = 3, text = "Have 3 display slots" },
		},
	},
	the_dark_egg = {
		displayName = "The Dark Egg",
		summary = "Something is humming inside a dark egg.",
		intro = "dark_egg_intro",
		outro = "dark_egg_done",
		reward = { coins = 2000000 },
		objectives = {
			{ kind = "tier", tier = "unknown", text = "Hatch an Unknown Verity" },
		},
	},
	hum_of_the_world = {
		displayName = "The Hum of the World",
		summary = "Every core is awake. Listen.",
		intro = "hum_intro",
		reward = { coins = 20000000 },
		objectives = {
			{ kind = "hire", n = 8, text = "Hire all 8 workers" },
			{ kind = "coins", n = 5000000, text = "Gather 5,000,000 Verity Coins" },
		},
	},
	where_do_i_belong = {
		displayName = "Where Do I Belong?",
		summary = "Verity is ready to find his place.",
		intro = "finale_intro",
		reward = { coins = 100000000 },
		objectives = {
			{ kind = "finale", text = "Talk with Verity" },
		},
	},
}

function Quests.name(questId: string?): string
	local def = questId and Quests.defs[questId]
	return def and def.displayName or tostring(questId)
end

function Quests.nextId(data): string?
	for _, id in Quests.order do
		if not data.quests.completed[id] then
			return id
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Reading objectives from a save. Returns done, have, need.
---------------------------------------------------------------------------
local function hiredCount(data): number
	local n = 0
	for _, room in data.rooms do
		for _, level in room.levels do
			if level > 0 then
				n += 1
			end
		end
	end
	return n
end

local function maxLevel(data): number
	local m = 0
	for _, room in data.rooms do
		for _, level in room.levels do
			m = math.max(m, level)
		end
	end
	return m
end

function Quests.check(obj, data)
	local kind = obj.kind
	if kind == "hold" then
		local ok = data.hand ~= nil
		return ok, ok and 1 or 0, 1
	elseif kind == "hatch" or kind == "verities" then
		local have = #data.backpack.verities
		return have >= obj.n, math.min(have, obj.n), obj.n
	elseif kind == "display" then
		for _, id in data.slots.equipped do
			if id ~= "" then
				return true, 1, 1
			end
		end
		return false, 0, 1
	elseif kind == "slots" then
		local have = #data.slots.equipped
		return have >= obj.n, math.min(have, obj.n), obj.n
	elseif kind == "buyEgg" then
		local total = 0
		for _, n in data.eggPurchases do
			total += n
		end
		return total >= 1, math.min(total, 1), 1
	elseif kind == "hire" then
		local have = hiredCount(data)
		return have >= obj.n, math.min(have, obj.n), obj.n
	elseif kind == "level" then
		local have = maxLevel(data)
		return have >= obj.n, math.min(have, obj.n), obj.n
	elseif kind == "coins" then
		return data.coins >= obj.n, math.min(data.coins, obj.n), obj.n
	elseif kind == "unlock" then
		local room = data.rooms[obj.room]
		local ok = room ~= nil and room.unlocked == true
		return ok, ok and 1 or 0, 1
	elseif kind == "tier" then
		for _, v in data.backpack.verities do
			if v.tier == obj.tier then
				return true, 1, 1
			end
		end
		return false, 0, 1
	end
	-- goto and finale are decided by the server (position / the ending), never by the save
	return false, 0, 1
end

return Quests
