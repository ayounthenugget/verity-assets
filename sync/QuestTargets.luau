-- QuestTargets: where things are in the world, by name. Used by the server to see
-- whether you reached something and by the client to aim the green arrow.
--   "spawn"  "shop"  "display:N"  "station:room:N"  "barnDoor"  "farmer"

local QuestTargets = {}

-- the farmer waits beside the barn door (the client builds him there)
function QuestTargets.farmerCFrame(plot: Instance): CFrame?
	local rooms = plot and plot:FindFirstChild("Rooms")
	local door = rooms and rooms:FindFirstChild("Barn") and rooms.Barn:FindFirstChild("Door")
	local zone = door and door:FindFirstChild("BumpZone")
	if not zone then
		return nil
	end
	local base = zone.CFrame * CFrame.new(11, 0, -6) -- a few steps to the side and out front
	local pos = Vector3.new(base.Position.X, 3.1, base.Position.Z)
	return CFrame.lookAt(pos, Vector3.new(zone.Position.X, pos.Y, zone.Position.Z))
end

function QuestTargets.position(plot: Instance?, key: string): Vector3?
	if key == "shop" then
		local hub = workspace:FindFirstChild("Hub")
		local counter = hub and hub:FindFirstChild("EggShop") and hub.EggShop:FindFirstChild("Counter")
		return counter and counter.Position
	end
	if not plot then
		return nil
	end
	if key == "spawn" then
		local s = plot:FindFirstChild("Spawn")
		return s and s.Position
	elseif key == "barnDoor" then
		local rooms = plot:FindFirstChild("Rooms")
		local zone = rooms and rooms:FindFirstChild("Barn") and rooms.Barn:FindFirstChild("Door") and rooms.Barn.Door:FindFirstChild("BumpZone")
		return zone and zone.Position
	elseif key == "farmer" then
		local cf = QuestTargets.farmerCFrame(plot)
		return cf and cf.Position
	end
	local kind, a, b = string.match(key, "^(%a+):([%w]+):?(%d*)$")
	if kind == "display" then
		local d = plot:FindFirstChild("Display")
		for _, slot in if d then d:GetChildren() else {} do
			if slot:GetAttribute("SlotIndex") == tonumber(a) and slot:FindFirstChild("Anchor") then
				return slot.Anchor.Position
			end
		end
	elseif kind == "station" then
		local rooms = plot:FindFirstChild("Rooms")
		local room = rooms and rooms:FindFirstChild(string.upper(string.sub(a, 1, 1)) .. string.sub(a, 2))
		local st = room and room:FindFirstChild("Stations") and room.Stations:FindFirstChild("Station" .. b)
		return st and st:FindFirstChild("Orb") and st.Orb.Position
	end
	return nil
end

return QuestTargets
