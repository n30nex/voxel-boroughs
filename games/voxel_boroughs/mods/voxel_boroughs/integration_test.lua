-- Voxel Boroughs original game code
-- SPDX-License-Identifier: MIT

if not core.settings:get_bool("voxel_boroughs_integration_test", false) then
	return
end

local vb = voxel_boroughs
local sim = vb.simulation
local storage = core.get_mod_storage()
local phase = core.settings:get("voxel_boroughs_integration_phase") or "seed"

local commands = {
	{"power", -2, 0},
	{"road", -1, 0},
	{"road", 0, 0},
	{"road", 1, 0},
	{"road", 2, 0},
	{"water", 3, 0},
	{"zone_i", -1, 1},
	{"zone_r", 0, 1},
	{"zone_r", 1, 1},
	{"zone_c", 2, 1},
}

local function layout_hash()
	local p1 = {x = -16, y = 0, z = 0}
	local p2 = {x = 31, y = 12, z = 15}
	local vm = VoxelManip(p1, p2)
	local emerged_min, emerged_max = vm:read_from_map(p1, p2)
	local area = VoxelArea:new({MinEdge = emerged_min, MaxEdge = emerged_max})
	local data = vm:get_data()
	local values = {}
	for y = p1.y, p2.y do
		for z = p1.z, p2.z do
			for x = p1.x, p2.x do
				values[#values + 1] = tostring(data[area:index(x, y, z)])
			end
		end
	end
	return sim.hash_string(table.concat(values, ","))
end

local function stop_with_failure(message)
	message = tostring(message):gsub("[\r\n]+", " ")
	core.log("error", ("[voxel_boroughs] VB_INTEGRATION_FAIL phase=%s reason=%s")
		:format(phase, message))
	core.request_shutdown("Voxel Boroughs integration test failed", false, 0)
end

local function seed_world()
	if (vb.state.generation or 0) ~= 0 or next(vb.state.cells) ~= nil then
		error("seed phase requires a fresh world")
	end

	vb.state.speed = 0
	for _, command in ipairs(commands) do
		local ok, reason = sim.apply_command(vb.state, command[1], {
			cx = command[2],
			cz = command[3],
		})
		if not ok then
			error(("command %s at %d,%d rejected: %s")
				:format(command[1], command[2], command[3], tostring(reason)))
		end
	end
	for _ = 1, 40 do
		sim.advance_day(vb.state)
	end
	if vb.state.population < 1 or vb.state.jobs < 1 then
		error("seeded city did not grow residents and jobs")
	end

	vb.render_all_cells()
	local state = sim.state_hash(vb.state)
	local layout = layout_hash()
	local ok, saved = vb.save_now()
	if not ok or saved ~= state then
		error("manual save did not preserve the state hash: " .. tostring(saved))
	end
	storage:set_string("integration_state_hash", state)
	storage:set_string("integration_layout_hash", layout)
	core.log("action", ("[voxel_boroughs] VB_INTEGRATION_PASS phase=seed state=%s layout=%s population=%d jobs=%d generation=%d")
		:format(state, layout, vb.state.population, vb.state.jobs, vb.state.generation or 0))
	core.request_shutdown("Voxel Boroughs seed phase complete", false, 0)
end

local function verify_world()
	local expected_state = storage:get_string("integration_state_hash")
	local expected_layout = storage:get_string("integration_layout_hash")
	if expected_state == "" or expected_layout == "" then
		error("seed phase evidence is missing")
	end
	if (vb.state.generation or 0) < 1 then
		error("versioned save generation was not loaded")
	end

	local state = sim.state_hash(vb.state)
	local layout = layout_hash()
	if state ~= expected_state then
		error(("state hash changed across restart: expected %s, got %s")
			:format(expected_state, state))
	end
	if layout ~= expected_layout then
		error(("voxel layout changed across restart: expected %s, got %s")
			:format(expected_layout, layout))
	end
	core.log("action", ("[voxel_boroughs] VB_INTEGRATION_PASS phase=verify state=%s layout=%s population=%d jobs=%d generation=%d")
		:format(state, layout, vb.state.population, vb.state.jobs, vb.state.generation or 0))
	core.request_shutdown("Voxel Boroughs verify phase complete", false, 0)
end

core.after(0, function()
	local ok, error_message = xpcall(function()
		if phase == "seed" then
			seed_world()
		elseif phase == "verify" then
			verify_world()
		else
			error("unknown integration phase: " .. phase)
		end
	end, debug.traceback)
	if not ok then
		stop_with_failure(error_message)
	end
end)
