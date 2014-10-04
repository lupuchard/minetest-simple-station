
-- Mostly a copy of technic's nuclear reactor, but that one requires more uranium
-- and provides power for an ENTIRE REAL LIFE WEEK at a time.
-- This one should be better suited for ss13.

local burn_ticks      = 10 * 60                -- (ten minutes).
local power_supply    = 100000                 -- EUs
local fuel_type       = "ss13:uranium_fuel"    -- The reactor burns this stuff
local other_fuel_type = "technic:uranium_fuel" -- worth ~25 times that of ss13 uranium fuel

local S = technic.getter

if not vector.length_square then
	vector.length_square = function (v)
		return v.x*v.x + v.y*v.y + v.z*v.z
	end
end

minetest.register_craftitem("ss13:uranium_fuel", {
	description = "Uranium Fuel",
	inventory_image = "ss13_uranium_fuel.png",
})
minetest.register_craft({
	type = "shapeless",
	output = "ss13:uranium_fuel 5",
	recipe = {"technic:uranium35_ingot"},
})

minetest.register_craft({
	output = 'ss13:hv_nuclear_reactor_core',
	recipe = {
		{'technic:carbon_plate',              'default:glass', 'technic:carbon_plate'},
		{'technic:composite_plate',  'technic:machine_casing', 'technic:composite_plate'},
		{'technic:stainless_steel_ingot', 'technic:hv_cable0', 'technic:stainless_steel_ingot'},
	}
})

local generator_formspec =
	"invsize[8,9;]"..
	"list[current_name;src;3,1.5;1,1;]"..
	"list[current_player;main;0,5;8,4;]"

-- "Boxy sphere"
local nodebox = {
	{ -0.353, -0.353, -0.353, 0.353, 0.353, 0.353 }, -- Box
	{ -0.500, -0.191, -0.191, 0.500, 0.191, 0.191 },
	{ -0.433, -0.249, -0.249, 0.433, 0.249, 0.249 },
	{ -0.397, -0.303, -0.303, 0.397, 0.303, 0.303 },
	{ -0.305, -0.396, -0.305, 0.305, 0.396, 0.305 }, -- Circle +-y
	{ -0.250, -0.432, -0.250, 0.250, 0.432, 0.250 },
	{ -0.191, -0.500, -0.191, 0.191, 0.500, 0.191 },
	{ -0.191, -0.191, -0.500, 0.191, 0.191, 0.500 },
	{ -0.249, -0.249, -0.433, 0.249, 0.249, 0.433 },
	{ -0.303, -0.303, -0.397, 0.303, 0.303, 0.397 },
}

local reactor_siren = {}
local function siren_set_state(pos, newstate)
	local hpos = minetest.hash_node_position(pos)
	local siren = reactor_siren[hpos]
	if not siren then
		if newstate == "off" then return end
		siren = {state="off"}
		reactor_siren[hpos] = siren
	end
	if newstate == "danger" and siren.state ~= "danger" then
		if siren.handle then minetest.sound_stop(siren.handle) end
		siren.handle = minetest.sound_play("technic_hv_nuclear_reactor_siren_danger_loop", {pos=pos, gain=1.5, loop=true, max_hear_distance=48})
		siren.state = "danger"
	elseif newstate == "clear" then
		if siren.handle then minetest.sound_stop(siren.handle) end
		local clear_handle = minetest.sound_play("technic_hv_nuclear_reactor_siren_clear", {pos=pos, gain=1.5, loop=false, max_hear_distance=48})
		siren.handle = clear_handle
		siren.state = "clear"
		minetest.after(10, function ()
			if siren.handle == clear_handle then
				minetest.sound_stop(clear_handle)
				if reactor_siren[hpos] == siren then
					reactor_siren[hpos] = nil
				end
			end
		end)
	elseif newstate == "off" and siren.state ~= "off" then
		if siren.handle then minetest.sound_stop(siren.handle) end
		siren.handle = nil
		reactor_siren[hpos] = nil
	end
end
local function siren_danger(pos, meta)
	meta:set_int("siren", 1)
	siren_set_state(pos, "danger")
end
local function siren_clear(pos, meta)
	if meta:get_int("siren") ~= 0 then
		siren_set_state(pos, "clear")
		meta:set_int("siren", 0)
	end
end


-- Change: somewhat lower requirements than technic's reactor has
local WATER_REQ = 20
local STEEL_REQ = 90
local BLAST_REQ = 300
local reactor_structure_badness = function(pos)
	local vm = VoxelManip()
	local pos1 = vector.subtract(pos, 3)
	local pos2 = vector.add(pos, 3)
	local MinEdge, MaxEdge = vm:read_from_map(pos1, pos2)
	local data = vm:get_data()
	local area = VoxelArea:new({MinEdge=MinEdge, MaxEdge=MaxEdge})

	local c_blast_concrete  = minetest.get_content_id("technic:blast_resistant_concrete")
	local c_cast_iron       = minetest.get_content_id("technic:cast_iron_block")
	local c_diamond         = minetest.get_content_id("default:diamondblock")

	local c_stainless_steel = minetest.get_content_id("technic:stainless_steel_block")
	local c_mithril         = minetest.get_content_id("moreores:mithril_block")
	local c_nyan            = minetest.get_content_id("default:nyan_cat")

	local c_water_source    = minetest.get_content_id("default:water_source")
	local c_water_flowing   = minetest.get_content_id("default:water_flowing")
	local c_ice             = minetest.get_content_id("default:ice")

	local blastlayer, steellayer, waterlayer = 0, 0, 0

	for z = pos1.z, pos2.z do
	for y = pos1.y, pos2.y do
	for x = pos1.x, pos2.x do
		local dist = math.max(math.abs(pos.x - x), math.abs(pos.y - y), math.abs(pos.z - z))
		local cid  = data[area:index(x, y, z)]
		if cid == c_water_source or cid == c_water_flowing or cid == c_ice then
			if dist <= 1 then
				waterlayer = waterlayer + 1
			end
		elseif cid == c_stainless_steel or cid == c_mithril or cid == c_nyan then
			if dist <= 2 then
				steellayer = steellayer + 1
			end
			blastlayer = blastlayer + 1
		elseif cid == c_blast_concrete or cid == c_cast_iron or cid == c_diamond then
			blastlayer = blastlayer + 1
		end
	end
	end
	end
	if waterlayer > WATER_REQ then waterlayer = WATER_REQ end
	if steellayer > STEEL_REQ then steellayer = STEEL_REQ end
	if blastlayer > BLAST_REQ then blastlayer = BLAST_REQ end
	print("Water: " .. tostring(waterlayer) .. ", Steel: " .. tostring(steellayer) .. ", Blast: " .. tostring(blastlayer))
	return (WATER_REQ - waterlayer) + (STEEL_REQ - steellayer) + (BLAST_REQ - blastlayer)
end

local function meltdown_reactor(pos)
	print("A reactor melted down at "..minetest.pos_to_string(pos))
	minetest.set_node(pos, {name="technic:corium_source"})
end

-- Change: only one fuel required to start reactor, and can be one of either
minetest.register_abm({
	nodenames = {"ss13:hv_nuclear_reactor_core_active"},
	interval = 1,
	chance = 1,
	action = function (pos, node)
		local meta = minetest.get_meta(pos)
		local badness = reactor_structure_badness(pos)
		local accum_badness = meta:get_int("structure_accumulated_badness")
		if badness == 0 then
			if accum_badness ~= 0 then
				meta:set_int("structure_accumulated_badness", accum_badness - 1)
				siren_clear(pos, meta)
			end
		else
			siren_danger(pos, meta)
			accum_badness = accum_badness + badness
			if accum_badness >= 100 then
				meltdown_reactor(pos)
			else
				meta:set_int("structure_accumulated_badness", accum_badness)
			end
		end
	end,
})

local run = function(pos, node)
	local meta = minetest.get_meta(pos)
	local machine_name = S("Nuclear %s Generator Core"):format("HV")
	local burn_time = meta:get_int("burn_time") or 0

	--minetest.chat_send_all("happen")

	if burn_time <= 0 then
		--minetest.chat_send_all("happen2 " .. tostring(reactor_structure_badness(pos)))
		local inv = meta:get_inventory()
		if not inv:is_empty("src") and reactor_structure_badness(pos) == 0 then
			--minetest.chat_send_all("happen3")
			local srclist = inv:get_list("src")
			srcstack = srclist[1]
			if srcstack:get_name() == fuel_type or srcstack:get_name() == other_fuel_type then
				if srcstack:get_name() == fuel_type then
					meta:set_int("burn_time", burn_ticks)
				else
					meta:set_int("burn_time", burn_ticks * 30)
				end
				technic.swap_node(pos, "ss13:hv_nuclear_reactor_core_active")
				meta:set_int("HV_EU_supply", power_supply)
				srcstack:take_item()
				inv:set_stack("src", 1, srcstack)
				return
			end
		end
		meta:set_int("HV_EU_supply", 0)
		meta:set_int("burn_time", 0)
		meta:set_string("infotext", S("%s Idle"):format(machine_name))
		technic.swap_node(pos, "ss13:hv_nuclear_reactor_core")
		meta:set_int("structure_accumulated_badness", 0)
		siren_clear(pos, meta)
	elseif burn_time > 0 then
		burn_time = burn_time - 1
		meta:set_int("burn_time", burn_time)
		local percent = math.floor(burn_time / burn_ticks * 100)
		meta:set_string("infotext", machine_name.." ("..percent.."%)")
		meta:set_int("HV_EU_supply", power_supply)
	end
end

minetest.register_node("ss13:hv_nuclear_reactor_core", {
	description = "Nuclear %s Generator Core",
	tiles = {"technic_hv_nuclear_reactor_core.png", "technic_hv_nuclear_reactor_core.png",
	         "technic_hv_nuclear_reactor_core.png", "technic_hv_nuclear_reactor_core.png",
	         "technic_hv_nuclear_reactor_core.png", "technic_hv_nuclear_reactor_core.png"},
	groups = {cracky=1, technic_machine=1},
	legacy_facedir_simple = true,
	sounds = default.node_sound_wood_defaults(),
	drawtype="nodebox",
	paramtype = "light",
	stack_max = 1,
	node_box = {
		type = "fixed",
		fixed = nodebox
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", S("Nuclear %s Generator Core"):format("HV"))
		meta:set_int("HV_EU_supply", 0)
		-- Signal to the switching station that this device burns some
		-- sort of fuel and needs special handling
		meta:set_int("HV_EU_from_fuel", 1)
		meta:set_int("burn_time", 0)
		meta:set_string("formspec", generator_formspec)
		local inv = meta:get_inventory()
		inv:set_size("src", 1)
	end,	
	can_dig = technic.machine_can_dig,
	on_destruct = function(pos) siren_set_state(pos, "off") end,
	allow_metadata_inventory_put = technic.machine_inventory_put,
	allow_metadata_inventory_take = technic.machine_inventory_take,
	allow_metadata_inventory_move = technic.machine_inventory_move,
	technic_run = run,
})

minetest.register_node("ss13:hv_nuclear_reactor_core_active", {
	tiles = {"technic_hv_nuclear_reactor_core.png", "technic_hv_nuclear_reactor_core.png",
	         "technic_hv_nuclear_reactor_core.png", "technic_hv_nuclear_reactor_core.png",
		 "technic_hv_nuclear_reactor_core.png", "technic_hv_nuclear_reactor_core.png"},
	groups = {cracky=1, technic_machine=1, radioactive=11000, not_in_creative_inventory=1},
	legacy_facedir_simple = true,
	sounds = default.node_sound_wood_defaults(),
	drop="ss13:hv_nuclear_reactor_core",
	drawtype="nodebox",
	light_source = 15,
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = nodebox
	},
	can_dig = technic.machine_can_dig,
	after_dig_node = meltdown_reactor,
	on_destruct = function(pos) siren_set_state(pos, "off") end,
	allow_metadata_inventory_put = technic.machine_inventory_put,
	allow_metadata_inventory_take = technic.machine_inventory_take,
	allow_metadata_inventory_move = technic.machine_inventory_move,
	technic_run = run,
	technic_on_disable = function(pos, node)
		local timer = minetest.get_node_timer(pos)
        	timer:start(1)
        end,
	on_timer = function(pos, node)
		local meta = minetest.get_meta(pos)
		
		-- Connected back?
		if meta:get_int("HV_EU_timeout") > 0 then return end	
		
		local burn_time = meta:get_int("burn_time") or 0

		if burn_time >= burn_ticks or burn_time == 0 then
			meta:set_int("HV_EU_supply", 0)
			meta:set_int("burn_time", 0)
			technic.swap_node(pos, "technic:hv_nuclear_reactor_core")
			meta:set_int("structure_accumulated_badness", 0)
			siren_clear(pos, meta)
			return
		end
		
		meta:set_int("burn_time", burn_time + 1)
		local timer = minetest.get_node_timer(pos)
        timer:start(1)
	end,
})
technic.register_machine("HV", "ss13:hv_nuclear_reactor_core",        technic.producer)
technic.register_machine("HV", "ss13:hv_nuclear_reactor_core_active", technic.producer)
