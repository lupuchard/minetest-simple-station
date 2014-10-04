
local lamp_box = {
	type = "wallmounted",
	wall_top = {-0.3125,0.375,-0.3125,0.3125,0.5,0.3125},
	wall_bottom = {-0.3125,-0.5,-0.3125,0.3125,-0.375,0.3125},
	wall_side = {-0.375,-0.3125,-0.3125,-0.5,0.3125,0.3125},
}

ss13.register_inductive_device("ss13:lamp_off", {
	drawtype = "nodebox",
	tiles = {"jeija_meselamp_off.png"},
	inventory_image = "jeija_meselamp.png",
	wield_image = "jeija_meselamp.png",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	walkable = true,
	node_box = lamp_box,
	selection_box = lamp_box,
	groups = {cracky = 3},
    description = "Lamp",
	sounds = default.node_sound_glass_defaults(),
	induction_turn_on = function(pos)
		technic.swap_node(pos, "ss13:lamp_on")
	end,
	induction_demand = 100,
}, "ss13:lamp_on", {
	drawtype = "nodebox",
	tiles = {"jeija_meselamp_on.png"},
	paramtype = "light",
	paramtype2 = "wallmounted",
	legacy_wallmounted = true,
	sunlight_propagates = true,
	walkable = true,
	light_source = LIGHT_MAX,
	node_box = lamp_box,
	selection_box = lamp_box,
	groups = {cracky = 3},
	drop = "ss13:lamp_off 1",
	off_node = "ss13:lamp_off",
	sounds = default.node_sound_glass_defaults(),
	induction_turn_off = function(pos)
		technic.swap_node(pos, "ss13:lamp_off")
	end,
	induction_demand = 100,
})

minetest.register_craft({
	output = "ss13:lamp_off 1",
	recipe = {
		{"", "default:glass", ""},
		{"technic:copper_coil", "default:steel_ingot", "technic:copper_coil"},
		{"", "default:glass", ""},
	}
})
