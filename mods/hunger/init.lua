
hunger = {}

local hungers = {}
local enabled = false
local rate    = 10

function hunger:disable()
	hungers = {}
end

function hunger:enable(hungerRate)
	rate = hungerRate or 10
	for _,player in ipairs(minetest.get_connected_players()) do
		hungers[player:get_player_name()] = 80
	end
	enabled = true
end

local timer = 0
local ticks = 0
minetest.register_globalstep(function(dtime)
	if not enabled then
		return
	end
	timer = timer + dtime;
	if timer >= rate then
		for _,player in ipairs(minetest.get_connected_players()) do
			local name = player:get_player_name()
			local total = hungers[name]
			total = total - 1
			if total <= 0 then
				minetest.chat_send_player(name, "You are starving to death! Eat something!")
				player:set_hp(player:get_hp() - 1)
				total = 1
			elseif total < 20 and math.fmod(ticks, 3) then
				minetest.chat_send_player(name, "You are starving!")
			elseif total < 40 and math.fmod(ticks, 12) then
				minetest.chat_send_player(name, "You are hungry.")
			end
			hungers[name] = total
			minetest.log("action", tostring(total))
		end
		timer = 0
		ticks = ticks + 1
	end
end)

minetest.register_on_joinplayer(function(player)
	if enabled then
		hungers[player:get_player_name()] = 80
	end
end)

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing)
	if enabled then
		local name = user:get_player_name()
		local total = hungers[name] + hp_change * 2
		if total > 100 then
			hungers[name] = 100
			minetest.chat_send_player(name, "You are very full!")
		elseif total > 80 then
			hungers[name] = total
			minetest.chat_send_player(name, "You are full.")
		elseif total > 60 then
			hungers[name] = total
			minetest.chat_send_player(name, "You are satiated.")
		elseif total > 40 then
			hungers[name] = total
			minetest.chat_send_player(name, "You are still hungry.")
		elseif total > 20 then
			hungers[name] = total + hp_change / 2
			minetest.chat_send_player(name, "You are still very hungry.")
		else
			hungers[name] = total + hp_change
			minetest.chat_send_player(name, "You are still starving!")
		end
		itemstack:take_item()
		return itemstack
	end
	return false
end)
