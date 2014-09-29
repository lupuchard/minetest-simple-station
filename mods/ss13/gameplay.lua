
-- The spawn node needs to exist in normal gameplay too, but
-- should just be invisible and intangible.
minetest.register_node("ss13:spawn", {
	drawtype  = "airlike",
	paramtype = "light",
	walkable  = false,
	pointable = false,
	groups = {cracky = 3},
})

hunger:enable(20)

equipment:enable({
{
	name = "facegear",
	pos = {x = 0, y = 0}
},
{
	name = "headgear",
	pos = {x = 1, y = 0}
},
{
	name = "headset",
	pos = {x = 2, y = 0}
},
{
	name = "gloves",
	pos = {x = 0, y = 1}
},
{
	name = "shirt",
	pos = {x = 1, y = 1}
},
{
	name = "armor",
	pos = {x = 2, y = 1}
},
{
	name = "shoes",
	pos = {x = 0, y = 2}
},
{
	name = "pants",
	pos = {x = 1, y = 2}
},
{
	name = "card",
	pos = {x = 2, y = 2}
},
}, 2, 3)