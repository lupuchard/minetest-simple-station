
local function vector_floor(vec)
	return vector.new(math.floor(vec.x), math.floor(vec.y), math.floor(vec.z))
end


-- Open data file
local dataPath = minetest.get_worldpath() .. "/ss13data.json"
local dataFile = assert(io.open(dataPath, "r"))
local datas = minetest.parse_json(dataFile:read("*all"))
dataFile:close()

-- In editing mode, games don't start and you have better edit tools
local editingMode = datas.editing

-- The corners of the space ship area
local corn1 = vector_floor(datas.space_corners[1])
local corn2 = vector_floor(datas.space_corners[2])
corn1, corn2 = worldedit.sort_pos(corn1, corn2)


ROLES = {
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

equipment:enable({
	{pos = {x = 0, y = 0}, name = "facegear"},
	{pos = {x = 1, y = 0}, name = "headgear"},
	{pos = {x = 2, y = 0}, name = "headset"},
	{pos = {x = 0, y = 1}, name = "gloves"},
	{pos = {x = 1, y = 1}, name = "shirt"},
	{pos = {x = 2, y = 1}, name = "armor"},
	{pos = {x = 0, y = 2}, name = "shoes"},
	{pos = {x = 1, y = 2}, name = "pants"},
	{pos = {x = 2, y = 2}, name = "card"},
}, 2, 4)

local playerDatas = {}

local CPY_OFF = 512
local corn1off = vector.new(corn1.x, corn1.y + CPY_OFF, corn1.z)
local corn2off = vector.new(corn2.x, corn2.y + CPY_OFF, corn2.z)


print("BALLER")


minetest.register_privilege("gm", "Player can start and end games whenever.")
minetest.register_privilege("edit_ship", "Player can save changes to the spaceship.")


print("SPAZZTASTIC")

local function saveData()
	local dataFile = assert(io.open(dataPath, "w"))
	dataFile:write(minetest.write_json(datas, true))
	dataFile:close()
end
local function saveSpaceship()
	minetest.chat_send_all("Scanning spaceship...")
	print(worldedit.copy(corn1, corn2, "y", CPY_OFF))
	minetest.chat_send_all("Spaceship scanned.")
end
minetest.register_chatcommand("save_ship", {
	params = "",
	description = "Saves the current spaceship.",
	privs = {edit_ship = true},
	func = function(name, params)
		saveData()
		saveSpaceship()
	end,
})
minetest.register_chatcommand("setcorner", {
	params = "corner",
	description = "Sets one of the corners (1 or 2) of the simulated space area around the ship.",
	privs = {edit_ship = true},
	func = function(name, corner)
		local player = minetest.get_player_by_name(name)
		datas.space_corners[tonumber(corner)] = player:getpos()
		minetest.chat_send_player(name, "Corner " .. corner .. " set to " .. minetest.pos_to_string(player:getpos()) .. ".")
	end,
})

print("WHOOPITY")

if editingMode then
	dofile(minetest.get_modpath("ss13").."/editor_nodes.lua")
else
	dofile(minetest.get_modpath("ss13").."/editor_nodes_locked.lua")
end
dofile(minetest.get_modpath("ss13").."/airlocks.lua")

print("ALLRITYTHEN")

local inGame = false
local timer = 0
local waitingStep = 0

-- Starts a new game.
local function startGame()
	if inGame then return end -- Can't start a game when one is in progress

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

-- Ends the current game.
local function endGame()
	for _, player in ipairs(minetest.get_connected_players()) do
		player:setpos(lobbyPosition)
	end
	minetest.chat_send_all("The game has ended!")

	inGame = false
	waitingStep = 0
end

-- Copies the spaceship from the saved spaceship.
-- Should happen between games.
local function reconstructSpaceship()
	minetest.chat_send_all("Reconstructing station...")
	numb = worldedit.copy(corn1off, corn2off, "y", -CPY_OFF)
	minetest.chat_send_all("Reconstruction complete.")
end

minetest.register_globalstep(function(dtime)
	if editingMode then return end

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
	privs = {gm = true},
	func = function(name, param)
		endGame()
		return true, "Done."
	end,
})

minetest.register_on_joinplayer(function(player)
	--player:setpos(lobbyPosition)
	player:override_day_night_ratio(0)
end)

if not editingMode then
	hunger:enable(20)
end

if editingMode then
	minetest.register_on_shutdown(function()
		saveData()
		saveSpaceship()
	end)
end
