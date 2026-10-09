-- Voice: the "talking" sound. One tiny blip per letter, pitched by who is speaking, the letter and
-- their mood (the Animal Crossing / Undertale way of giving someone a voice without recorded audio).
-- It uses a sound that ships with Roblox, so nothing needs uploading. To use your own blip, set BLIP_ID.

local SoundService = game:GetService("SoundService")

local Voice = {}

local BLIP_ID = "rbxasset://sounds/clickfast.wav"
local BASE_PITCH = { Verity = 1.55, Farmer = 0.8, ["???"] = 0.5 }
local MOOD_SHIFT = { excited = 0.18, surprised = 0.25, happy = 0.05, sad = -0.2, worried = -0.08, smug = -0.05, sleepy = -0.25 }
local POOL = 4

local sounds = {}
local nextSound = 1

local function getSound()
	if #sounds == 0 then
		for i = 1, POOL do
			local s = Instance.new("Sound")
			s.Name = "VoiceBlip" .. i
			s.SoundId = BLIP_ID
			s.Volume = 0.35
			s.Parent = SoundService
			sounds[i] = s
		end
	end
	local s = sounds[nextSound]
	nextSound = nextSound % POOL + 1
	return s
end

-- Plays one blip for a character. Spaces and punctuation stay silent.
function Voice.blip(who: string?, char: string, mood: string?)
	if not string.match(char, "%w") then
		return
	end
	local base = BASE_PITCH[who or "Verity"] or 1.2
	local letter = string.byte(string.lower(char)) % 9 -- 0..8
	local pitch = base + (MOOD_SHIFT[mood or "happy"] or 0) + letter * 0.045
	local s = getSound()
	s.PlaybackSpeed = math.clamp(pitch, 0.3, 2.6)
	s.TimePosition = 0
	s:Play()
end

return Voice
