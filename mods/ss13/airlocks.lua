
ss13.ACCESSES = {"noone", "everyone", "cabin", "hydroponics", "kitchen", "security"}

--------------
--------------
-- ID CARDS --
--------------
--------------
ss13.Card = {}

-- The idcard is used for identification and airlock access.
minetest.register_craftitem("ss13:idcard", {
	description = "ID Card",
	groups = {card = 1},
	stack_max = 1,
	inventory_image = "card.png",

	-- on_use for certain items will just be for displaying information about them.
	-- This prints the owner's name and the access it grants.
	on_use = function(itemstack, user, pointed_thing)
		local meta = minetest.deserialize(itemstack:get_metadata())
		local name = user:get_player_name()
		if type(meta) ~= "table" then
			minetest.chat_send_player(name, "This ID is seemingly blank.")
		else
			minetest.chat_send_player(name, "Owner: " .. tostring(meta.owner))
			if #meta.access > 0 then
				local access_str = "Access: "
				for _, val in ipairs(meta.access) do
					access_str = access_str .. tostring(val) .. " "
				end
				minetest.chat_send_player(name, access_str)
			else
				minetest.chat_send_player(name, "Access: none")
			end
		end
		return nil
	end,
})

--- Create an ss13:idcard with the given owner and accesses.
-- @tparam string owner   The name put on the id.
-- @tparam array accesses Strings for the places the card should have access to.
-- @treturn ItemStack The created idcard.
function ss13.Card.create_id(owner, accesses)
	assert(type(owner) == "string")
	assert(type(accesses) == "table")
	local metadata = minetest.serialize({owner = owner, access = accesses})
	return ItemStack({name = "ss13:idcard", count = 1, wear = 0, metadata = metadata})
end

--- Tells whether or not the given item is an idcard and grants access to the given place.
-- @tparam ItemStack itemstack May or may not be a card.
-- @tparam string    access    Location to check for access to.
-- @treturn bool Whether or not access can be granted.
function ss13.Card.has_access(itemstack, access)
	if itemstack == nil then return false end
	local meta = minetest.deserialize(itemstack:get_metadata())
	if type(meta) == "table" and type(meta.access) == "table" then
		for _, val in ipairs(meta.access) do
			if val == access then return true end
		end
	end
	return false
end

minetest.register_chatcommand("create_id", {
	params = "<owner> <access>...",
	description = "Creates an id for the given owner with the given accesses.",
	func = function(name, param)
		local player = minetest.env:get_player_by_name(name)
		local parameters = param:split(" ")
		if #parameters == 0 then
			return
		end
		local accesses = {}
		for i, val in ipairs(parameters) do
			if i ~= 1 then
				table.insert(accesses, val)
			end
		end
		local id = ss13.Card.create_id(parameters[1], accesses)
		player:get_inventory():add_item("main", id)
	end,
})


--------------
--------------
-- AIRLOCKS --
--------------
--------------
ss13.Airlock = {}

ss13.Airlock.USE_DELAY = 0.5
ss13.Airlock.AUTOMATIC_CLOSE_DELAY = 5.0

function ss13.Airlock.set_state(pos, state)
	local meta = minetest.get_meta(pos)
	meta:set_string("al_state", state)
end

-- Closes the given airlock block. Only one block.
function ss13.Airlock.close(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_string("al_state") == "open" then
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		technic.swap_node(pos, def.closed_node)
		meta:set_string("al_state", "closed_delay")
		minetest.after(ss13.Airlock.USE_DELAY, ss13.Airlock.set_state, pos, "closed")
	end
end

-- Opens the given airlock block. Only one block.
function ss13.Airlock.open(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_string("al_state") == "closed" then
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		print(tostring(pos.x).." "..tostring(pos.y).." "..tostring(pos.y).." "..tostring(def.open_node))
		technic.swap_node(pos, def.open_node)
		meta:set_string("al_state", "open_delay")
		minetest.after(ss13.Airlock.USE_DELAY, ss13.Airlock.set_state, pos, "open")
		minetest.after(ss13.Airlock.AUTOMATIC_CLOSE_DELAY, ss13.Airlock.close, pos)
	end
end

-- Tells whether or not the airlock at the given position
-- grants access to the given player if the player is holding
-- the given itemstack.
function ss13.Airlock.has_access(pos, player, itemstack)
	local meta = minetest.get_meta(pos)
	local access = meta:get_string("al_access")

	if access == "unknown" then
		return false
	elseif access == "everyone" then
		return true
	elseif ss13.Card.has_access(itemstack, access) then
		return true
	elseif ss13.Card.has_access(equipment:get_equipped(player, "card"), access) then
		return true
	end

	return false
end

-- Returns all the airlocks next to the given position
-- (including possibly the one at the given position)
function ss13.Airlock.get_adjacent(pos)
	airlocks = {}
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				local rpos = vector.new(x, y, z)
				local apos = vector.add(pos, rpos)
				local node = minetest.get_node(apos)
				if minetest.get_item_group(node.name, "airlock") == 1 then
					table.insert(airlocks, apos)
				end
			end
		end
	end
	return airlocks
end

--- Registers a new airlock node.
-- @tparam string name        The name of the airlock. No node will be named exactly this.
-- @tparam string tiles       A table of the tiles used for the texture.
-- {
--  closed = The front tile when airlock is closed.
--  open   = The front tile when airlock is open (optional).
--  side   = The sides of the airlock.
--  top    = The top of the airlock node (optional).
--  bottom = The bottom of the airlock node (optional).
-- }
-- @tparam bool   left        Whether this airlock opens to the left or the right.
function ss13.Airlock.register(name, tiles, left)
	local closed_tile = tiles.closed or tiles.front
	local open_tile   = tiles.open   or closed_tile
	local side_tile   = tiles.side   or closed_tile
	local top_tile    = tiles.top    or side_tile
	local bottom_tile = tiles.bottom or side_tile
	minetest.register_node(name .. "_closed", {
		drawtype = "nodebox",
		description = name,
		tiles = {top_tile, bottom_tile, side_tile, side_tile, 
				closed_tile.."^[transformFX", closed_tile},
		node_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.25, 0.5, 0.5, 0.25}
		},
		inventory_image = closed_tile,
		paramtype  = "light",
		paramtype2 = "facedir",
		groups = {cracky = 1, airlock = 1},
		use_texture_alpha = true,
		open_node = name.."_open",
		after_place_node = function(pos, placer, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos)
			meta:set_string("al_state", "closed")
			meta:set_string("al_access", "unknown")
		end,
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos)
			if meta:get_string("al_state") == "closed_delay" then
				return itemstack
			end

			local airlocks = ss13.Airlock.get_adjacent(pos)
			
			local has_access = false
			for i, apos in ipairs(airlocks) do
				if ss13.Airlock.has_access(apos, player, itemstack) then
					has_access = true
				end
			end
			
			if has_access then
				for i, apos in ipairs(airlocks) do
					ss13.Airlock.open(apos)
					minetest.sound_play("airlock", {pos = apos, gain = 0.2})
				end
			end

			return itemstack
		end,
	})

	function get_nodebox(left)
		if left then
			return {-0.5, -0.5, -0.25, -0.25, 0.5, 0.25}
		else
			return {0.25, -0.5, -0.25, 0.5, 0.5, 0.25}
		end
	end
	
	minetest.register_node(name .. "_open", {
		drawtype = "nodebox",
		tiles = {side_tile, side_tile, side_tile, side_tile, 
				open_tile.."^[transformFX", open_tile},
		node_box = {
			type = "fixed",
			fixed = get_nodebox(left)
		},
		inventory_image = closed_tile,
		paramtype  = "light",
		paramtype2 = "facedir",
		groups = {cracky = 1, airlock = 1, not_in_creative_inventory = 1},
		walkable  = true,
		pointable = true,
		closed_node = name.."_closed",
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos)
			if meta:get_string("al_state") == "open_delay" then
				return itemstack
			end

			local airlocks = ss13.Airlock.get_adjacent(pos)
			
			local has_access = false
			for i, apos in ipairs(airlocks) do
				if ss13.Airlock.has_access(apos, player, itemstack) then
					has_access = true
				end
			end
			
			if has_access then
				for i, apos in ipairs(airlocks) do
					ss13.Airlock.close(apos)
				end
			end

			return itemstack
		end,
	})
end

local function register_airlock_type(type, name, side, glass)
	glass = glass or ""
	local nodename = "ss13:"..type..name
	if glass ~= "" then nodename = nodename.."g" end

	local tiles = {
		closed = "al_"..type.."c"..name..glass..".png",
		open   = "al_"..type.."o"..name..       ".png",
		side   = side..".png",
	}

	if glass ~= "" then
		local str = "al_"..name..glass.."_side.png"
		if type:sub(2, 2) == "r" then
			str = str.."^[transformFX"
		end
		if type:sub(1, 1) == "l" then
			 tiles.top    = str
		else tiles.bottom = str end
	end

	ss13.Airlock.register(nodename, tiles, type:sub(2, 2) == "l")
end
local function register_airlock_group(name, side, glass)
	register_airlock_type("ll", name, side, glass)
	register_airlock_type("lr", name, side, glass)
	register_airlock_type("ul", name, side, glass)
	register_airlock_type("ur", name, side, glass)
end

register_airlock_group("maint", "dot")
register_airlock_group("maint", "dot", "glass")
register_airlock_group("sec", "rdot")
register_airlock_group("sec", "rdot", "glass")
register_airlock_group("glass", "dot")
register_airlock_group("wood", "bdot")
