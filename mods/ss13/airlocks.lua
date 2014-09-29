
local accesses = {"noone", "everyone", "cabin", "hydroponics", "kitchen", "security"}

local function open_airlock(pos)
	local meta = minetest.get_meta(pos)
	print(meta:get_string("al_state"))
	if meta:get_string("al_state") == "closed" then
		local meta_table = meta:to_table()
		local node = minetest.get_node(pos)
		minetest.set_node(pos, {name = meta_table.fields.al_open, param1 = node.param1, param2 = node.param2})
		meta_table.fields.al_state = "open"
		minetest.get_meta(pos):from_table(meta_table)
	end
end
local function close_airlock(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_string("al_state") == "open" then
		local meta_table = meta:to_table()
		local node = minetest.get_node(pos)
		minetest.set_node(pos, {name = meta_table.fields.al_closed, param1 = node.param1, param2 = node.param2})
		meta_table.fields.al_state = "closed"
		minetest.get_meta(pos):from_table(meta_table)
	end
end
local function airlock_has_access(pos)
	local meta = minetest.get_meta(pos)
	if meta:get_string("al_access") ~= "unknown" then
		return true
	end
	return false
end
local function get_adjacent_airlocks(pos)
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

function register_airlock(name, closed_tile, open_tile, side_tile, left)
	minetest.register_node(name .. "_closed", {
		drawtype = "nodebox",
		description = name,
		tiles = {side_tile, side_tile, side_tile, side_tile, 
				closed_tile.."^[transformFX", closed_tile},
		node_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.25, 0.5, 0.5, 0.25}
		},
		inventory_image = closed_tile,
		paramtype  = "light",
		paramtype2 = "facedir",
		groups = {cracky = 1, airlock = 1},
		after_place_node = function(pos, placer, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos)
			meta:set_string("al_state", "closed")
			meta:set_string("al_open", name.."_open")
			meta:set_string("al_closed", name.."_closed")
			meta:set_string("al_access", "unknown")
		end,
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local airlocks = get_adjacent_airlocks(pos)
			
			local has_access = false
			for i, apos in ipairs(airlocks) do
				if airlock_has_access(apos) then
					has_access = true
				end
			end
			
			if has_access then
				for i, apos in ipairs(airlocks) do
					open_airlock(apos)
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
		groups = {cracky = 1, airlock = 1},
		walkable  = true,
		pointable = true,
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local airlocks = get_adjacent_airlocks(pos)
			
			local has_access = false
			for i, apos in ipairs(airlocks) do
				if airlock_has_access(apos) then
					has_access = true
				end
			end
			
			if has_access then
				for i, apos in ipairs(airlocks) do
					close_airlock(apos)
				end
			end

			return itemstack
		end,
	})
end

register_airlock("ss13:llmaint", "llcmaint.png", "llomaint.png", "dot.png", true)
register_airlock("ss13:lrmaint", "lrcmaint.png", "lromaint.png", "dot.png", false)
register_airlock("ss13:ulmaint", "ulcmaint.png", "ulomaint.png", "dot.png", true)
register_airlock("ss13:urmaint", "urcmaint.png", "uromaint.png", "dot.png", false)