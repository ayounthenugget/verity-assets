-- Dialogue: everything Verity (and friends) say. Each line: who, mood, text.
-- moods: happy talk excited surprised worried sad smug sleepy
-- Add a script here, then point a quest's intro / outro / objective.dialogue at its id.

local Dialogue = {}

local V = "Verity"
local F = "Farmer"

Dialogue.speakers = {
	Verity = { color = "#FFD84D" },
	Farmer = { color = "#FF9F43" },
	["???"] = { color = "#7CF0FF" },
}

Dialogue.scripts = {
	-- plays right after the opening cutscene
	intro_after_cutscene = {
		{ who = V, mood = "happy", text = "Oh! You can see me? Hi! Hello! I'm Verity!" },
		{ who = V, mood = "worried", text = "I... don't know what I'm FOR yet. But I found this egg, and it's warm." },
		{ who = V, mood = "excited", text = "Open your Bag and hold the egg. Let's see who's inside!" },
	},
	hatched_first = {
		{ who = V, mood = "surprised", text = "It HATCHED! Look at them! A little face, just like mine!" },
		{ who = V, mood = "happy", text = "More Verities means more sunshine. And sunshine means Verity Coins." },
	},
	show_off_intro = {
		{ who = V, mood = "talk", text = "Verities love being looked at. Put yours on a display stand and they'll boost everything you earn." },
		{ who = V, mood = "happy", text = "Follow the green arrow!" },
	},
	first_friend_intro = {
		{ who = V, mood = "talk", text = "The Spark Core hums when a friend works beside it. Every friend you hire makes coins for you." },
		{ who = V, mood = "excited", text = "Even when you're away. They never get tired. They LOVE it." },
	},
	first_friend_done = {
		{ who = V, mood = "excited", text = "Look at them go! Keep pressing E on the panel to make them faster." },
	},
	egg_shopping_intro = {
		{ who = V, mood = "talk", text = "The Egg Shop sells eggs from the common ones all the way to... well. The Unknown." },
		{ who = V, mood = "smug", text = "The further you go, the better your luck gets. Quests help too." },
	},
	full_house_intro = {
		{ who = V, mood = "talk", text = "Three cores humming together sound like a song. Can you hear it?" },
	},
	farmers_call_intro = {
		{ who = V, mood = "surprised", text = "Someone's waving at us from beside the barn! Let's go say hi." },
	},
	farmer_talk = {
		{ who = F, mood = "talk", text = "Well, I'll be. A yellow ball with a face. Haven't seen one of you in an age." },
		{ who = V, mood = "worried", text = "There are others like me?" },
		{ who = F, mood = "talk", text = "Somewhere. This barn used to hum like your cores. It's been quiet since the walls started... changing." },
		{ who = F, mood = "smug", text = "Grow your workers a bit, and I'll hand you the key. Deal?" },
		{ who = V, mood = "excited", text = "Deal!" },
	},
	farmers_call_done = {
		{ who = F, mood = "happy", text = "That's the spirit! The barn's yours. It's a big job, so bring coins." },
	},
	barn_raising_intro = {
		{ who = V, mood = "talk", text = "The barn door needs 50,000 coins to wake up. Step on its glowing pad when you're ready." },
	},
	barn_open = {
		{ who = V, mood = "excited", text = "It's OPEN! Oh, the hay smells like... like something I used to know." },
	},
	barn_hands_intro = {
		{ who = V, mood = "talk", text = "Four more cores are waiting in there. Let's staff all of them!" },
	},
	collector_intro = {
		{ who = V, mood = "happy", text = "I like having a family of Verities. Let's keep collecting. Check your Bag for room." },
	},
	dark_egg_intro = {
		{ who = V, mood = "worried", text = "Do you hear that? A low hum... under the ground. It's coming from a dark egg." },
		{ who = "???", mood = "talk", text = "...yellow... come... see..." },
		{ who = V, mood = "surprised", text = "Who said that?!" },
	},
	dark_egg_done = {
		{ who = V, mood = "sad", text = "That Verity looks sad, and a little like me." },
		{ who = V, mood = "worried", text = "The voice mentioned two places. A hall of humming yellow walls, and a land of square hills." },
	},
	hum_intro = {
		{ who = V, mood = "talk", text = "Every core is awake. Can you feel it? The whole world is humming one note." },
		{ who = V, mood = "worried", text = "It's getting louder. Keep going. I think it's calling me." },
	},
	finale_intro = {
		{ who = V, mood = "sad", text = "I think I know why I'm here. And I'm scared." },
		{ who = V, mood = "talk", text = "Two doors are opening. I have to go through one. Will you walk with me?" },
	},
}

return Dialogue
