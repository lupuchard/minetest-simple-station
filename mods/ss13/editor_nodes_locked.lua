
-- The spawn node needs to exist in normal gameplay too, but
-- should just be invisible and intangible.
minetest.register_node("ss13:spawn", {
	drawtype  = "airlike",
	paramtype = "light",
	walkable  = false,
	pointable = false,
	groups = {cracky = 3},
})
