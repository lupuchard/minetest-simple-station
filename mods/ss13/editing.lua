
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

minetest.register_chatcommand("setcorner", {
	params = "corner",
	description = "Sets one of the corners (1 or 2) of the simulated space area around the ship.",
	func = function(name, corner)
		local player = minetest.get_player_by_name(name)
		datas.space_corners[tonumber(corner)] = player:getpos()
		minetest.chat_send_player(name, "Corner " .. corner .. " set to " .. minetest.pos_to_string(player:getpos()) .. ".")
	end,
})

equipment:enable({
{
	name = "facegear",
	pos = {x = 0, y = 0}
},
{
	name = "headgear",
	pos = {x = 1, y = 0}
},
{
	name = "headset",
	pos = {x = 2, y = 0}
},
{
	name = "gloves",
	pos = {x = 0, y = 1}
},
{
	name = "shirt",
	pos = {x = 1, y = 1}
},
{
	name = "armor",
	pos = {x = 2, y = 1}
},
{
	name = "shoes",
	pos = {x = 0, y = 2}
},
{
	name = "pants",
	pos = {x = 1, y = 2}
},
{
	name = "card",
	pos = {x = 2, y = 2}
},
}, 3, 4)