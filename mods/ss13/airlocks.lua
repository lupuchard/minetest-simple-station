
local accesses = {"noone", "everyone", "cabin", "hydroponics", "kitchen", "security"}


--------------
--------------
-- ID CARDS --
--------------
--------------
Card = {}

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
function Card.create_id(owner, accesses)
	assert(type(owner) == "string")
	assert(type(accesses) == "table")
	local metadata = minetest.serialize({owner = owner, access = accesses})
	return ItemStack({name = "ss13:idcard", count = 1, wear = 0, metadata = metadata})
end

--- Tells whether or not the given item is an idcard and grants access to the given place.
-- @tparam ItemStack itemstack May or may not be a card.
-- @tparam string    access    Location to check for access to.
-- @treturn bool Whether or not access can be granted.
function Card.has_access(itemstack, access)
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
		local id = Card.create_id(parameters[1], accesses)
		player:get_inventory():add_item("main", id)
	end,
})


--------------
--------------
-- AIRLOCKS --
--------------
--------------
Airlock = {}

Airlock.USE_DELAY = 0.5
Airlock.AUTOMATIC_CLOSE_DELAY = 5.0

function Airlock.set_state(pos, state)
	local meta = minetest.get_meta(pos)
	meta:set_string("al_state", state)
end

-- Closes the given airlock block. Only one block.
function Airlock.close(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_string("al_state") == "open" then
		local meta_table = meta:to_table()
		local node = minetest.get_node(pos)
		minetest.set_node(pos, {name = meta_table.fields.al_closed, param1 = node.param1, param2 = node.param2})
		meta_table.fields.al_state = "closed_delay"
		minetest.get_meta(pos):from_table(meta_table)
		minetest.after(Airlock.USE_DELAY, Airlock.set_state, pos, "closed")
	end
end

-- Opens the given airlock block. Only one block.
function Airlock.open(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_string("al_state") == "closed" then
		local meta_table = meta:to_table()
		local node = minetest.get_node(pos)
		minetest.set_node(pos, {name = meta_table.fields.al_open, param1 = node.param1, param2 = node.param2})
		meta_table.fields.al_state = "open_delay"
		minetest.get_meta(pos):from_table(meta_table)
		minetest.after(Airlock.USE_DELAY, Airlock.set_state, pos, "open")
		minetest.after(Airlock.AUTOMATIC_CLOSE_DELAY, Airlock.close, pos)
	end
end

-- Tells whether or not the airlock at the given position
-- grants access to the given player if the player is holding
-- the given itemstack.
function Airlock.has_access(pos, player, itemstack)
	local meta = minetest.get_meta(pos)
	local access = meta:get_string("al_access")

	if access == "unknown" then
		return false
	elseif access == "everyone" then
		return true
	elseif Card.has_access(itemstack, access) then
		return true
	elseif Card.has_access(equipment:get_equipped(player, "card"), access) then
		return true
	end

	return false
end

-- Returns all the airlocks next to the given position
-- (including possibly the one at the given position)
function Airlock.get_adjacent(pos)
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
function Airlock.register(name, tiles, left)
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
		after_place_node = function(pos, placer, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos)
			meta:set_string("al_state", "closed")
			meta:set_string("al_open", name.."_open")
			meta:set_string("al_closed", name.."_closed")
			meta:set_string("al_access", "unknown")
		end,
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos)
			if meta:get_string("al_state") == "closed_delay" then
				return itemstack
			end

			local airlocks = Airlock.get_adjacent(pos)
			
			local has_access = false
			for i, apos in ipairs(airlocks) do
				if Airlock.has_access(apos, player, itemstack) then
					has_access = true
				end
			end
			
			if has_access then
				for i, apos in ipairs(airlocks) do
					Airlock.open(apos)
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
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos)
			if meta:get_string("al_state") == "open_delay" then
				return itemstack
			end

			local airlocks = Airlock.get_adjacent(pos)
			
			local has_access = false
			for i, apos in ipairs(airlocks) do
				if Airlock.has_access(apos, player, itemstack) then
					has_access = true
				end
			end
			
			if has_access then
				for i, apos in ipairs(airlocks) do
					Airlock.close(apos)
				end
			end

			return itemstack
		end,
	})
end

-- maintenance airlocks
Airlock.register("ss13:llmaint", {closed = "al_llcmaint.png", open = "al_llomaint.png", side = "dot.png"}, true)
Airlock.register("ss13:lrmaint", {closed = "al_lrcmaint.png", open = "al_lromaint.png", side = "dot.png"}, false)
Airlock.register("ss13:ulmaint", {closed = "al_ulcmaint.png", open = "al_ulomaint.png", side = "dot.png"}, true)
Airlock.register("ss13:urmaint", {closed = "al_urcmaint.png", open = "al_uromaint.png", side = "dot.png"}, false)
Airlock.register("ss13:llmaintg", {closed = "al_llcmaintglass.png", open = "al_llomaint.png", side = "dot.png", top    = "al_maintglass_side.png"} , true)
Airlock.register("ss13:lrmaintg", {closed = "al_lrcmaintglass.png", open = "al_lromaint.png", side = "dot.png", top    = "al_maintglass_side.png^[transformFX"} , false)
Airlock.register("ss13:ulmaintg", {closed = "al_ulcmaintglass.png", open = "al_ulomaint.png", side = "dot.png", bottom = "al_maintglass_side.png"} , true)
Airlock.register("ss13:urmaintg", {closed = "al_urcmaintglass.png", open = "al_uromaint.png", side = "dot.png", bottom = "al_maintglass_side.png^[transformFX"} , false)

-- security airlocks
Airlock.register("ss13:llsec", {closed = "al_llcsec.png", open = "al_llosec.png", side = "rdot.png"}, true)
Airlock.register("ss13:lrsec", {closed = "al_lrcsec.png", open = "al_lrosec.png", side = "rdot.png"}, false)
Airlock.register("ss13:ulsec", {closed = "al_ulcsec.png", open = "al_ulosec.png", side = "rdot.png"}, true)
Airlock.register("ss13:ursec", {closed = "al_urcsec.png", open = "al_urosec.png", side = "rdot.png"}, false)
Airlock.register("ss13:llsecg", {closed = "al_llcsecglass.png", open = "al_llosec.png", side = "rdot.png", top    = "al_secglass_side.png"}, true)
Airlock.register("ss13:lrsecg", {closed = "al_lrcsecglass.png", open = "al_lrosec.png", side = "rdot.png", top    = "al_secglass_side.png^[transformFX"}, false)
Airlock.register("ss13:ulsecg", {closed = "al_ulcsecglass.png", open = "al_ulosec.png", side = "rdot.png", bottom = "al_secglass_side.png"}, true)
Airlock.register("ss13:ursecg", {closed = "al_urcsecglass.png", open = "al_urosec.png", side = "rdot.png", bottom = "al_secglass_side.png^[transformFX"}, false)