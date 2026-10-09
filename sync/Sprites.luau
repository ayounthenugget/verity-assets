-- Sprites: the Roblox image IDs for the ChatGPT-made art (eggs and UI icons).
-- Re-import an image in Asset Manager, then paste its new ID here.

local Sprites = {
	coin = "rbxassetid://134203917389701",
	bag = "rbxassetid://119355777476710",
	home = "rbxassetid://114613208089749",
	income = "rbxassetid://99632800043277",
	upgrade = "rbxassetid://72083835195556",
	worker = "rbxassetid://75052357254772",
	lock = "rbxassetid://139548057475351",
	barn = "rbxassetid://124256335956342",
	panel = "rbxassetid://88736630987439",
}

Sprites.eggs = {
	common = "rbxassetid://106802707346368",
	rare = "rbxassetid://73519335067902",
	epic = "rbxassetid://130312795640634",
	legendary = "rbxassetid://78857843088254",
	unknown = "rbxassetid://124401931533976",
}

-- The 3D egg (made in Blender): one mesh, one texture per rarity.
-- Import assets/eggs3d/egg.fbx and the egg_*.png files in Asset Manager and paste the IDs here.
-- While these are blank the game falls back to the simple built-in egg.
Sprites.eggMesh = "" -- e.g. "rbxassetid://123"
Sprites.eggTextures = {
	common = "",
	rare = "",
	epic = "",
	legendary = "",
	unknown = "",
}

function Sprites.eggTexture(eggType: string?): string
	return Sprites.eggTextures[eggType or "common"] or Sprites.eggTextures.common
end

-- The starter egg looks like a common one.
function Sprites.egg(eggType: string?): string
	return Sprites.eggs[eggType or "common"] or Sprites.eggs.common
end

return Sprites
