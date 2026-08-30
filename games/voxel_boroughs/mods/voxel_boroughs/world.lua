-- SPDX-License-Identifier: MIT

local vb = voxel_boroughs
local sim = vb.simulation

core.set_mapgen_setting("mg_name", "singlenode", true)
core.set_mapgen_setting("water_level", "-31000", true)

core.register_on_generated(function(minp, maxp)
	if minp.y > 0 then
		return
	end

	local vm, emerged_min, emerged_max = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emerged_min, MaxEdge = emerged_max})
	local data = vm:get_data()
	local stone = core.get_content_id("voxel_boroughs:stone")
	local earth = core.get_content_id("voxel_boroughs:earth")
	local grass = core.get_content_id("voxel_boroughs:grass")
	local top = math.min(maxp.y, 0)

	for z = minp.z, maxp.z do
		for y = minp.y, top do
			local content = stone
			if y == 0 then
				content = grass
			elseif y >= -3 then
				content = earth
			end
			local index = area:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				data[index] = content
				index = index + 1
			end
		end
	end

	vm:set_data(data)
	vm:calc_lighting(minp, maxp)
	vm:write_to_map()
end)

local floor_nodes = {
	road = "voxel_boroughs:road",
	power = "voxel_boroughs:power_pad",
	water = "voxel_boroughs:water_pad",
	zone_r = "voxel_boroughs:zone_r",
	zone_c = "voxel_boroughs:zone_c",
	zone_i = "voxel_boroughs:zone_i",
}

local building_nodes = {
	zone_r = "voxel_boroughs:building_r",
	zone_c = "voxel_boroughs:building_c",
	zone_i = "voxel_boroughs:building_i",
}

local function is_building_voxel(cell, ox, y, oz)
	if not cell or (cell.stage or 0) < 1 then
		return false
	end
	local inset = cell.kind == "zone_r" and 2 or 1
	local high = 7 - inset
	local height = (cell.kind == "zone_i" and 2 or 3) + cell.stage * 2
	return ox >= inset and ox <= high and oz >= inset and oz <= high and y <= height
end

function vb.render_cell_by_key(key)
	local cx, cz = sim.parse_cell_key(key)
	if not cx then
		return
	end
	local cell = vb.state.cells[key]
	local x0 = cx * sim.CELL_SIZE
	local z0 = cz * sim.CELL_SIZE
	local p1 = {x = x0, y = 0, z = z0}
	local p2 = {x = x0 + sim.CELL_SIZE - 1, y = 12, z = z0 + sim.CELL_SIZE - 1}
	local vm = VoxelManip(p1, p2)
	local emerged_min, emerged_max = vm:read_from_map(p1, p2)
	local area = VoxelArea:new({MinEdge = emerged_min, MaxEdge = emerged_max})
	local data = vm:get_data()
	local air = core.CONTENT_AIR
	local grass = core.get_content_id("voxel_boroughs:grass")
	local floor = core.get_content_id(cell and floor_nodes[cell.kind] or "voxel_boroughs:grass")
	local building = cell and building_nodes[cell.kind]
	local building_id = building and core.get_content_id(building) or nil
	local utility = core.get_content_id("voxel_boroughs:utility_wall")
	local roof = core.get_content_id("voxel_boroughs:roof")
	local road_line = core.get_content_id("voxel_boroughs:road_line")

	for z = z0, z0 + 7 do
		for y = 0, 12 do
			for x = x0, x0 + 7 do
				local content = y == 0 and (floor or grass) or air
				local ox = x - x0
				local oz = z - z0
				if cell and cell.kind == "road" and y == 0 and (ox == 3 or oz == 3) then
					content = road_line
				elseif building_id and is_building_voxel(cell, ox, y, oz) then
					content = building_id
					local height = (cell.kind == "zone_i" and 2 or 3) + cell.stage * 2
					if y == height then
						content = roof
					end
				elseif cell and cell.kind == "power" and ox >= 2 and ox <= 5
						and oz >= 2 and oz <= 5 and y >= 1 and y <= 4 then
					content = y == 4 and roof or utility
				elseif cell and cell.kind == "power" and ox == 5 and oz == 5
						and y >= 5 and y <= 8 then
					content = utility
				elseif cell and cell.kind == "water" and ox >= 2 and ox <= 5
						and oz >= 2 and oz <= 5 and y >= 4 and y <= 6 then
					content = y == 6 and roof or utility
				elseif cell and cell.kind == "water" and y >= 1 and y <= 3
						and ((ox == 2 or ox == 5) and (oz == 2 or oz == 5)) then
					content = utility
				end
				data[area:index(x, y, z)] = content
			end
		end
	end

	vm:set_data(data)
	vm:calc_lighting(p1, p2)
	vm:write_to_map()
end

function vb.render_all_cells()
	for _, key in ipairs(sim.sorted_cell_keys(vb.state)) do
		vb.render_cell_by_key(key)
	end
end

local function setup_player(player)
	player:set_physics_override({
		speed = 2.5,
		jump = 0,
		gravity = 0,
		sneak = false,
	})
	player:hud_set_flags({
		healthbar = false,
		breathbar = false,
		crosshair = false,
		wielditem = false,
		minimap = false,
	})
	player:set_properties({pointable = false})
	local pos = player:get_pos()
	if not pos or pos.y < 1 or pos.y > 10 then
		player:set_pos({x = 0, y = 2, z = 0})
	end

	local inventory = player:get_inventory()
	inventory:set_size("main", 8)
	inventory:set_list("main", {
		"voxel_boroughs:tool_road",
		"voxel_boroughs:tool_power",
		"voxel_boroughs:tool_water",
		"voxel_boroughs:tool_zone_r",
		"voxel_boroughs:tool_zone_c",
		"voxel_boroughs:tool_zone_i",
		"voxel_boroughs:tool_bulldoze",
		"voxel_boroughs:tool_city",
	})
	player:hud_set_hotbar_itemcount(8)
	vb.ensure_hud(player)
end

core.register_on_newplayer(function(player)
	player:set_pos({x = 0, y = 2, z = 0})
end)

core.register_on_respawnplayer(function(player)
	player:set_pos({x = 0, y = 2, z = 0})
	return true
end)

core.register_on_joinplayer(function(player)
	setup_player(player)
	core.after(1, function()
		if player and player:is_player() then
			vb.render_all_cells()
			vb.update_hud(player)
			local meta = player:get_meta()
			if meta:get_int("voxel_boroughs_welcome_seen") == 0 then
				meta:set_int("voxel_boroughs_welcome_seen", 1)
				vb.show_welcome(player)
			end
		end
	end)
end)

local last_action_us = {}

function vb.apply_city_command(player_name, action, cx, cz)
	local player = core.get_player_by_name(player_name)
	if not player or not core.check_player_privs(player_name, {interact = true}) then
		return false, "permission_denied"
	end

	local now = core.get_us_time()
	if now - (last_action_us[player_name] or 0) < 80000 then
		return false, "rate_limited"
	end
	last_action_us[player_name] = now

	local ok, result = sim.apply_command(vb.state, action, {cx = cx, cz = cz})
	if not ok then
		return false, result
	end
	vb.dirty = true
	vb.render_cell_by_key(result)
	vb.update_all_huds()
	if vb.protocol then
		vb.protocol.broadcast_delta("cell", {
			key = result,
			cell = vb.state.cells[result],
			funds = vb.state.funds,
			state_hash = sim.state_hash(vb.state),
		})
	end
	return true, result
end

function vb.use_build_tool(player, pointed_thing, action)
	if not player or not player:is_player() or not pointed_thing or pointed_thing.type ~= "node" then
		return
	end
	local pos = pointed_thing.under
	local cx = math.floor(pos.x / sim.CELL_SIZE)
	local cz = math.floor(pos.z / sim.CELL_SIZE)
	local ok, reason = vb.apply_city_command(player:get_player_name(), action, cx, cz)
	if not ok and reason ~= "rate_limited" then
		local messages = {
			invalid_cell = "That location is not a valid zoning cell.",
			district_not_annexed = "Annex this district before building here.",
			unknown_action = "That build tool is not supported.",
			cell_empty = "There is nothing to bulldoze in that cell.",
			cell_occupied = "Bulldoze the existing cell first.",
			insufficient_funds = "The city cannot afford that project.",
			permission_denied = "You do not have permission to build.",
		}
		core.chat_send_player(player:get_player_name(), messages[reason] or ("Build rejected: " .. tostring(reason)))
	end
end

