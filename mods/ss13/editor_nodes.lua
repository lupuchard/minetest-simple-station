
-- The spawn node defines a player spawn point.
-- You can punch the block to cycle the spawn point forward
-- or right click on it to cycle it backwards.
-- The spawn point is stored as an int "role" in the metadata, with
-- a value of 0 for the lobby and the index of a role for the roles
local function displayRole(role, setter)
	local str = ""
	if role == 0 then
		str = "lobby"
	else
		print(tostring(role))
		str = ROLES[role].name
	end
	minetest.chat_send_player(setter:get_player_name(), "Spawn point set to " .. str .. ".")
end
minetest.register_node("ss13:spawn", {
	drawtype  = "airlike",
	paramtype = "light",
	walkable  = false,
	pointable = true,
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		-- set role to lobby upon placing
		minetest.get_meta(pos):set_int("role", 0)
		displayRole(0, placer)
	end,
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		-- clear meta upon removal
		minetest.get_meta(pos):from_table(nil)
	end,
	on_punch = function(pos, node, puncher, pointed_thing)
		-- iterate roll forward
		local meta = minetest.get_meta(pos)
		local val  = meta:get_int("role")
		if val >= #ROLES then
			val = 0
		else
			val = val + 1
		end
		meta:set_int("role", val)
		displayRole(val, puncher)
	end,
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		-- iterate roll backward
		local meta = minetest.get_meta(pos)
		local val  = meta:get_int("role")
		if val <= 0 then
			val = #ROLES
		else
			val = val - 1
		end
		meta:set_int("role", val)
		displayRole(val, player)
	end,
	groups = {cracky = 3},
})

