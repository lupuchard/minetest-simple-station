
local dataPath = minetest.get_worldpath() .. "/ss13data.json"
local dataFile = assert(io.open(dataPath, "r"))
local datas = minetest.parse_json(dataFile:read("*all"))
dataFile:close()
local editingMode = datas.editing
local corn1 = datas.space_corners[1]
corn1.x = math.floor(corn1.x)
corn1.y = math.floor(corn1.y)
corn1.z = math.floor(corn1.z)
local corn2 = datas.space_corners[2]
corn2.x = math.floor(corn2.x)
corn2.y = math.floor(corn2.y)
corn2.z = math.floor(corn2.z)
corn1, corn2 = worldedit.sort_pos(corn1, corn2)

local ROLES = {
	{
		name = "farmer",
		access = {"hydroponics"},
	},
	{
		name = "bartender",
		access = {"bartend"},
	},
	{
		name = "crab",
		access = {},
	},
}

local playerDatas = {}

local CPY_OFF = 1024
corn1off = vector.new(corn1.x, corn1.y + CPY_OFF, corn1.z)
corn2off = vector.new(corn2.x, corn2.y + CPY_OFF, corn2.z)

if editingMode then
	dofile(minetest.get_modpath("ss13").."/editing.lua")

	local function saveData()
		local dataFile = assert(io.open(dataPath, "w"))
		dataFile:write(minetest.write_json(datas, true))
		dataFile:close()
	end
	minetest.register_chatcommand("save", {
		params = "",
		description = "Saves the current editing world.",
		func = function(name, params)
			saveData()
		end,
	})
	minetest.register_on_shutdown(function()
		saveData()
	end)

else
	dofile(minetest.get_modpath("ss13").."/gameplay.lua")

	local inGame = false
	local timer = 0
	local waitingStep = 0

	local function startGame()
		minetest.chat_send_all("The game has begun!")

		for _, player in ipairs(minetest.get_connected_players()) do
			playerName = player:get_player_name()
			player:setpos(spawnPosition)

			playerData = playerDatas[playerName]
			if playerData == nil then
				playerDatas[playerName] = {}
				playerData = playerDatas[playerName]
			end
			playerData.role = math.random(#ROLES)

			minetest.chat_send_player(playerName, "You are the " .. ROLES[playerData.role].name .. "!")
		end

		inGame = true
	end

	local function endGame()
		for _, player in ipairs(minetest.get_connected_players()) do
			player:setpos(lobbyPosition)
		end
		minetest.chat_send_all("The game has ended!")

		inGame = false
		waitingStep = 0
	end

	local function reconstructSpaceship()
		minetest.chat_send_all("Reconstructing station...")
		numb = worldedit.copy(corn1off, corn2off, "y", -CPY_OFF)
		minetest.chat_send_all("Reconstruction complete.")
	end

	local spaceshipCopied = false
	minetest.register_globalstep(function(dtime)
		if not spaceshipCopied then
			spaceshipCopied = true
			minetest.chat_send_all("Scanning spaceship...")
			print(worldedit.copy(corn1, corn2, "y", CPY_OFF))
			minetest.chat_send_all("Spaceship scanned.")
		end

		timer = timer + dtime
		if inGame == false and timer >= 1 then
			waitingStep = waitingStep + 1
			timer = 0
			if waitingStep == 10 then
				reconstructSpaceship()
			elseif waitingStep == 120 then
				--startGame()
				waitingStep = 0
			end
		end
	end)

	minetest.register_chatcommand("endgame", {
		params = "",
		description = "Ends the game in progress.",
		func = function(name, param)
			endGame()
			return true, "Done."
		end,
	})

	minetest.register_on_joinplayer(function(player)
		--player:setpos(lobbyPosition)
	end)
end
