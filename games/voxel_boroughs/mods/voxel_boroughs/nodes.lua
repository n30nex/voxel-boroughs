-- SPDX-License-Identifier: MIT

local function solid_node(name, description, color, extra)
	local definition = {
		description = description,
		tiles = {"blank.png^[noalpha^[colorize:" .. color .. ":255"},
		inventory_image = "blank.png^[noalpha^[colorize:" .. color .. ":255",
		wield_image = "blank.png^[noalpha^[colorize:" .. color .. ":255",
		is_ground_content = false,
		diggable = false,
		groups = {not_in_creative_inventory = 1},
	}
	for key, value in pairs(extra or {}) do
		definition[key] = value
	end
	core.register_node("voxel_boroughs:" .. name, definition)
end

solid_node("stone", "Subsoil", "#59636B", {
	is_ground_content = true,
	groups = {terrain = 1, stone = 1, not_in_creative_inventory = 1},
})
solid_node("earth", "Earth", "#806443", {
	is_ground_content = true,
	groups = {terrain = 1, soil = 1, not_in_creative_inventory = 1},
})
solid_node("grass", "Borough Grass", "#70A95B", {
	is_ground_content = true,
	groups = {terrain = 1, soil = 1, not_in_creative_inventory = 1},
})
solid_node("road", "Road", "#343B42")
solid_node("road_line", "Road Marking", "#E8DFA8", {light_source = 1})
solid_node("zone_r", "Residential Zone", "#4E9A73")
solid_node("zone_c", "Commercial Zone", "#4B7FB5")
solid_node("zone_i", "Industrial Zone", "#C99A42")
solid_node("power_pad", "Power Utility", "#A75A43")
solid_node("water_pad", "Water Utility", "#4A96A8")
solid_node("building_r", "Residential Building", "#D7A786")
solid_node("building_c", "Commercial Building", "#72A9CC")
solid_node("building_i", "Industrial Building", "#B89A66")
solid_node("utility_wall", "Utility Building", "#D7D0BA")
solid_node("roof", "Building Roof", "#ECE8DD")

local tool_colors = {
	road = "#343B42",
	power = "#D26345",
	water = "#49AFC5",
	zone_r = "#4E9A73",
	zone_c = "#4B7FB5",
	zone_i = "#C99A42",
	bulldoze = "#C94E4E",
}

local tool_descriptions = {
	road = "Road — $100/cell",
	power = "Power Plant — $2,500",
	water = "Water Tower — $1,500",
	zone_r = "Low-density Residential — $20/cell",
	zone_c = "Low-density Commercial — $20/cell",
	zone_i = "Low-density Industrial — $20/cell",
	bulldoze = "Bulldoze — $10/cell",
}

for action, color in pairs(tool_colors) do
	local selected_action = action
	core.register_tool("voxel_boroughs:tool_" .. action, {
		description = tool_descriptions[action],
		inventory_image = "blank.png^[noalpha^[colorize:" .. color .. ":255",
		range = 300,
		on_use = function(itemstack, user, pointed_thing)
			voxel_boroughs.use_build_tool(user, pointed_thing, selected_action)
			return itemstack
		end,
		-- The branded client reserves right-drag for orbiting.
		on_place = function(itemstack)
			return itemstack
		end,
	})
end

core.register_tool("voxel_boroughs:tool_city", {
	description = "City Hall — dashboard and inspector",
	inventory_image = "blank.png^[noalpha^[colorize:#EDE1B6:255",
	range = 300,
	on_use = function(itemstack, user, pointed_thing)
		voxel_boroughs.show_dashboard(user, pointed_thing)
		return itemstack
	end,
	on_place = function(itemstack)
		return itemstack
	end,
})

