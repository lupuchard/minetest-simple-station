
dongle = {}

function dongle:edit(player, pos)
	local meta_table = minetest.get_meta(pos):to_table().fields

	local empty = true
	for k,v in pairs(meta_table) do
		empty = false
		break
	end
	if empty then
		meta_table["example_key_1"] = "example_value_1"
		meta_table["example_key_2"] = "example_value_2"
	end

	local tablestr = minetest.write_json(meta_table)

	local formspec = "size[14,10;]textarea[0,0;10,10;meta;;"..tablestr.."]"..
	           "field[-99,-99;1,1;p;;"..minetest.write_json(pos).."]"..
	           "button_exit[12,9;2,1;exit;Done]"

	minetest.show_formspec(player:get_player_name(), "dongle:dongle", formspec)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "dongle:dongle" then
		local pos = minetest.parse_json(fields.p)
		local meta_table = minetest.parse_json(fields.meta)
		if meta_table == nil then return end
		meta_table.example_key_1 = nil
		meta_table.example_key_2 = nil

		local meta = minetest.get_meta(pos)
		local full_table = meta:to_table()
		full_table.fields = meta_table
		meta:from_table(full_table)
	end
end)

minetest.register_craftitem("dongle:dongle", {
	description = "Donger",
	stack_max = 1,
	inventory_image = "usb_dongle.png",
	on_place = function(itemstack, placer, pointed_thing)
		dongle:edit(placer, pointed_thing.under)
		return nil
	end,
})
