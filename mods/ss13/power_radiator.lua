
local POWER_RADIUS = 12

local function iterate_radius(pos, target)
	local positions = minetest.find_nodes_in_area(
		{x = pos.x - POWER_RADIUS, y = pos.y - POWER_RADIUS, z = pos.z - POWER_RADIUS},
		{x = pos.x + POWER_RADIUS, y = pos.y + POWER_RADIUS, z = pos.z + POWER_RADIUS},
		target)
	return ipairs(positions)
end

local function connect_device_to_radiator(device_pos, rad_pos)
	local rad_node = minetest.get_node(rad_pos)
	if not minetest.get_item_group(rad_node.name, "power_radiator") then
		return false
	end

	local device_meta = minetest.get_meta(device_pos)
	local rad_meta    = minetest.get_meta(rad_pos)

	local connected_devices = minetest.deserialize(rad_meta:get_string("connected_devices"))
	if connected_devices == nil then
		connected_devices = {}
	end

	connected_devices[minetest.serialize(device_pos)] = true
	rad_meta:set_string("connected_devices", minetest.serialize(connected_devices))
	device_meta:set_string("connected_to", minetest.serialize(rad_pos))
	print("aruaeouaou")
	print(minetest.pos_to_string(minetest.deserialize(device_meta:get_string("connected_to"))))

	return true
end

local function get_radiator_meta(device_meta)
	local connected_to = device_meta:get_string("connected_to")
	if connected_to == "none" then return nil end
	local rad_pos = minetest.deserialize(connected_to)
	return minetest.get_meta(rad_pos)
end

local function destroy_device(pos)
	local node = minetest.get_node(pos)
	if not minetest.get_item_group(node.name, "inductive") then
		return
	end

	local meta = minetest.get_meta(pos)
	local rad_meta = get_radiator_meta(meta)
	if rad_meta == nil then return end

	if meta:get_int("active") == 1 then
		local def = minetest.registered_nodes[node.name]
		local demand = rad_meta:get_int("MV_EU_demand") - def.induction_demand
		if demand < 0 then demand = 0 end
		rad_meta:set_int("MV_EU_demand", demand)
	end

	local connected_devices = minetest.deserialize(rad_meta:get_string("connected_devices"))
	if connected_devices ~= nil then
		connected_devices[minetest.serialize(pos)] = nil
	end
	rad_meta:set_string("connected_devices", connected_devices)
end

local function toggle_device_active(pos)
	local node = minetest.get_node(pos)
	if not minetest.get_item_group(node.name, "inductive") then
		return 0
	end
	local def = minetest.registered_nodes[node.name]

	local meta = minetest.get_meta(pos)
	if meta:get_string("connected_to") == "none" then
		return 0
	end

	local rad_meta = get_radiator_meta(meta)

	if meta:get_int("active") == 1 then
		meta:set_int("active", 0)

		local demand = rad_meta:get_int("MV_EU_demand") - def.induction_demand
		if demand < 0 then
			demand = 0
		end
		rad_meta:set_int("MV_EU_demand", demand)

		return 0
	else
		meta:set_int("active", 1)

		local demand = rad_meta:get_int("MV_EU_demand") + def.induction_demand
		rad_meta:set_int("MV_EU_demand", demand)

		return 1
	end
end

function ss13.register_inductive_device(off_name, off_def, on_name, on_def)

	off_def.groups.inductive = 1
	on_def.groups.inductive  = 1

	off_def.on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("active", 0)
		meta:set_string("connected_to", "none")

		for _, rad_pos in iterate_radius(pos, "ss13:power_radiator") do
			success = connect_device_to_radiator(pos, rad_pos)
			if success then break end
		end
	end
	off_def.on_destruct = function(pos)
		destroy_device(pos)
	end
	off_def.on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		active = toggle_device_active(pos)
		if active == 1 then
			rad_meta = get_radiator_meta(minetest.get_meta(pos))
			print(rad_meta:get_string("connected_devices"))
			if rad_meta:get_int("powered") == 1 then
				off_def.induction_turn_on(pos)
			end
		end
	end

	on_def.on_destruct = function(pos)
		destroy_device(pos)
	end
	on_def.on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		active = toggle_device_active(pos)
		if active == 0 then
			on_def.induction_turn_off(pos)
		end
	end

	minetest.register_node(off_name, off_def)
	minetest.register_node(on_name, on_def)
end

local function turn_off_devices(pos)
	local meta = minetest.get_meta(pos)
	local connected_devices = minetest.deserialize(meta:get_string("connected_devices"))
	if connected_devices ~= nil then
		for device_pos_hash, _ in pairs(connected_devices) do
			local device_pos = minetest.deserialize(device_pos_hash)
			local device_node = minetest.get_node(pos)
			if minetest.get_item_group(device_node.name, "inductive") == 1 then
				if device_node.induction_turn_off ~= nil then
					device_node.induction_turn_off(device_pos)
				end
			end
		end
	end
end

local function turn_on_devices(pos)
	local meta = minetest.get_meta(pos)
	local connected_devices = minetest.deserialize(meta:get_string("connected_devices"))
	if connected_devices ~= nil then
		for device_pos_hash, _ in pairs(connected_devices) do
			local device_pos = minetest.deserialize(device_pos_hash)
			local device_meta = minetest.get_meta(pos)
			if device_meta:get_int("active") == 1 then
				local device_node = minetest.get_node(pos)
				if minetest.get_item_group(device_node.name, "inductive") == 1 then
					if device_node.induction_turn_on ~= nil then
						device_node.induction_turn_on(device_pos)
					end
				end
			end
		end
	end
end

local function shutdown_devices(pos)
	local meta = minetest.get_meta(pos)
	local connected_devices = minetest.deserialize(meta:get_string("connected_devices"))
	if connected_devices ~= nil then
		for device_pos_hash, _ in pairs(connected_devices) do
			local device_pos = minetest.deserialize(device_pos_hash)
			local node = minetest.get_node(device_pos)
			if minetest.get_item_group(node.name, "inductive") then
				local device_meta = minetest.get_meta(device_pos)
				if device_meta:get_int("active") == 1 then
					device_meta:set_int("active", 0)
					device_meta:set_string("connected_to", "none")
					local def = minetest.registered_nodes[node.name]
					def.induction_turn_off(device_pos)
				end
			end
		end
	end
end

local function connect_nearby_devices(pos)
	local pos_hash = minetest.serialize(pos)

	local connected = {}
	for _, device_pos in iterate_radius(pos, "group:inductive") do
		local device_meta = minetest.get_meta(device_pos)
		if device_meta:get_string("connected_to") == "none" then
			device_meta:set_string("connected_to", pos_hash)
			connected[minetest.serialize(device_pos)] = true
		end
	end
	local meta = minetest.get_meta(pos)
	meta:set_string("connected_devices", minetest.serialize(connected))
end

local run = function(pos, node, active_object_count, active_object_count_wider)
	local meta      = minetest.get_meta(pos)
	local eu_input  = meta:get_int("MV_EU_input")
	local eu_demand = meta:get_int("MV_EU_demand")
	local powered   = meta:get_int("powered")
	local machine_name = "Power Radiator"

	if powered == 1 then
		if eu_input < eu_demand then
			print("POWERED OFF")
			meta:set_int("powered", 0)
			meta:set_string("infotext", "Disabled Power Radiator")
			turn_off_devices(pos)
		end
	else
		if eu_input >= eu_demand then
			print("POWERED ON")
			meta:set_int("powered", 1)
			meta:set_string("infotext", "Power Radiator")
			turn_on_devices(pos)
		end
	end
end

minetest.register_node("ss13:power_radiator", {
	description = "MV Power Radiator",
	tiles = {"technic_lv_cable.png"},
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2, power_radiator = 1, technic_machine = 1},
	sounds = default.node_sound_wood_defaults(),
	paramtype = "light",
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("MV_EU_input",  0)
		meta:set_int("MV_EU_demand", 0)
		meta:set_int("powered", 1)
		connect_nearby_devices(pos)
	end,
	on_destruct = function(pos, node, digger)
		shutdown_devices(pos)
	end,
	technic_run = run,
	technic_on_disable = function(pos, node)
		print("POWERED OFF")
		local meta = minetest.get_meta(pos)
		meta:set_int("powered", 0)
		meta:set_string("infotext", "Disabled Power Radiator")
		turn_off_devices(pos)
	end,
})
technic.register_machine("MV", "ss13:power_radiator", technic.receiver)

-- TODO change craft
minetest.register_craft({
	output = 'ss13:power_radiator 1',
	recipe = {
		{'technic:stainless_steel_ingot', 'technic:mv_transformer', 'technic:stainless_steel_ingot'},
		{'technic:copper_coil',           'technic:machine_casing', 'technic:copper_coil'},
		{'technic:rubber',                'technic:mv_cable0',      'technic:rubber'},
	}
})

