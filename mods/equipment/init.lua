
equipment = {}

local function equipsFormspec(playerName, slots)
	str = ""
	for i, slot in ipairs(slots) do
		str = str .. "list[detached:"..playerName.."_equips;"..slot.name..";"..slot.pos.x..","..slot.pos.y..";1,1;]"
	end
	--str = "list[detached:"..playerName.."_equips;main;1,1;1,1;]"


	return str
end

local function bagFormspec(bagDepth)
	return "list[current_player;main;0,3.5;8," .. tostring(bagDepth)..";]"
end

local function craftFormspec(craftSize)
	local off   = 3 - craftSize
	local cs    = tostring(craftSize)
	local craft = "list[current_player;craft;"..tostring(3.5 + off)..","..tostring(off / 2)..";"..cs..","..cs..";]"
	local craftPreview = "list[current_player;craftpreview;7,1;1,1;]"
	return craft .. craftPreview
end

--[[--
equipment:enable(slots, [craftSize = 3, bagDepth = 4, onEquip, onUnequip])
slots should be a list of slots, with each slot a table
{
	name = the slot's name
	allow_multiple = whether or not you can stack this equipment in it's slot
	allow_anything = items don't need to have a group that matches this slot's name to be equipped to it
	pos = {x, y} (the coordinates on the menu)
}
]]
function equipment:enable(slots, craftSize, bagDepth, onEquip, onUnequip)

	craftSize  = craftSize or 3
	bagDepth   = bagDepth or 4
	onEquip   = onEquip   or function(def, player) end
	onUnequip = onUnequip or function(def, player) end

	equipmentInventories = {}

	slotsMap = {}
	for _, slot in pairs(slots) do
		slotsMap[slot.name] = slot
	end

	local allowPut = function(inv, listname, index, stack, player)
		local def = stack:get_definition()
		if def == nil then return 0 end
		local slot = slotsMap[listname]
		if slot.allow_anything or def.groups[listname] then
			if slot.allow_multiple then
				return stack:get_count()
			else return 1 end
		end
		return 0
	end
	local onPut =  function(inv, listname, index, stack, player)
		onEquip(stack, player)
	end
	local onTake = function(inv, listname, index, stack, player)
		onUnequip(stack, player)
	end

	--[[--
	Returns the sum of the values the equipments
	have for a particular group.
	]]
	function equipment:get_group_sum(player, group)
		total = 0
		inv = equipmentInventories[player:get_player_name()]
		for slotName, _ in pairs(slotsMap) do
			item = inv:get_list(slotName)[0]
			if item ~= nil then
				groupVal = item:get_definition().groups[group]
				if groupVal ~= nil then total = total + groupVal end
			end
		end
		return total
	end

	--[[--
	Returns the item equipped on the given player in the given slot
	]]
	function equipment:get_equipped(player, slot)
		inv = equipmentInventories[player:get_player_name()]
		return inv:get_list(slot)[0]
	end

	minetest.register_on_joinplayer(function(player)
		local name = player:get_player_name()
		local inv = minetest.create_detached_inventory(name .. "_equips", {
			allow_put = allowPut,
			allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
				return allowPut(inv, to_list, to_index, inv:get_stack(from_list, from_index), player)
			end,
			on_put = onPut,
			on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
				onPut(inv, to_list, to_index, inv:get_stack(from_list, from_index), player)
			end,
			on_take = onTake,
		})
		equipmentInventories[name] = inv
		for _, slot in ipairs(slots) do
			inv:set_size(slot.name, 1)
		end
		local formspec = "size[8,"..tostring(5 + bagDepth)..";]"..
			equipsFormspec(name, slots)..
			bagFormspec(bagDepth)..
			craftFormspec(craftSize)

		player:set_inventory_formspec(formspec)
	end)
end

