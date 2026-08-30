-- Voxel Boroughs original game code
-- SPDX-License-Identifier: MIT

local root = core.get_modpath(core.get_current_modname())
local vb = {
	root = root,
	dirty = false,
	simulation = dofile(root .. "/simulation.lua"),
}
_G.voxel_boroughs = vb

dofile(root .. "/data_packs.lua")
dofile(root .. "/nodes.lua")
dofile(root .. "/storage.lua")

local seed = tonumber(core.get_mapgen_setting("seed")) or 1
vb.state = vb.load_state() or vb.simulation.new(seed)
vb.simulation.recalculate(vb.state)

dofile(root .. "/ui.lua")
dofile(root .. "/world.lua")
dofile(root .. "/traffic.lua")
dofile(root .. "/protocol.lua")
dofile(root .. "/integration_test.lua")

local day_accumulator = 0
local growth_queue = nil
local growth_index = 1
local changed_cells = nil
local autosave_accumulator = 0
local hud_accumulator = 0

local function finish_day()
	vb.simulation.finish_day(vb.state)
	for _, key in ipairs(changed_cells or {}) do
		vb.render_cell_by_key(key)
	end
	growth_queue = nil
	growth_index = 1
	changed_cells = nil
	vb.dirty = true
	vb.update_all_huds()
	vb.spawn_sample_traffic()
	vb.protocol.broadcast_delta("day", {
		day = vb.state.day,
		funds = vb.state.funds,
		last_balance = vb.state.last_balance,
		population = vb.state.population,
		jobs = vb.state.jobs,
		demand = vb.state.demand,
	})
end

local function complete_pending_day()
	if not growth_queue then
		return
	end
	while growth_index <= #growth_queue do
		local key = growth_queue[growth_index]
		growth_index = growth_index + 1
		if vb.simulation.grow_cell(vb.state, key) then
			changed_cells[#changed_cells + 1] = key
		end
	end
	finish_day()
end

function vb.save_now()
	complete_pending_day()
	return vb.save_state()
end

core.register_globalstep(function(dtime)
	local speed = vb.state.speed or 1
	if speed > 0 then
		day_accumulator = day_accumulator + dtime * speed
	end

	if not growth_queue and day_accumulator >= 2 then
		day_accumulator = day_accumulator - 2
		growth_queue = vb.simulation.begin_day(vb.state)
		growth_index = 1
		changed_cells = {}
	end

	if growth_queue then
		local budget = 32
		while budget > 0 and growth_index <= #growth_queue do
			local key = growth_queue[growth_index]
			growth_index = growth_index + 1
			budget = budget - 1
			if vb.simulation.grow_cell(vb.state, key) then
				changed_cells[#changed_cells + 1] = key
			end
		end
		if growth_index > #growth_queue then
			finish_day()
		end
	end

	autosave_accumulator = autosave_accumulator + dtime
	if autosave_accumulator >= 300 and not growth_queue then
		autosave_accumulator = 0
		if vb.dirty then
			local ok, result = vb.save_state()
			if not ok then
				core.log("error", "[voxel_boroughs] autosave failed: " .. tostring(result))
			end
		end
	end

	hud_accumulator = hud_accumulator + dtime
	if hud_accumulator >= 0.25 then
		hud_accumulator = 0
		vb.update_all_huds()
	end
end)

core.register_chatcommand("city", {
	description = "Open the Voxel Boroughs City Hall",
	func = function(name)
		local player = core.get_player_by_name(name)
		if player then
			vb.show_dashboard(player)
			return true
		end
		return false, "Player not found."
	end,
})

core.register_chatcommand("vb_save", {
	description = "Write a complete versioned city snapshot",
	privs = {server = true},
	func = function()
		local ok, result = vb.save_now()
		return ok, ok and ("Saved city state " .. result) or ("Save failed: " .. tostring(result))
	end,
})

core.register_chatcommand("vb_hash", {
	description = "Show the deterministic city state hash",
	func = function()
		return true, vb.simulation.state_hash(vb.state)
	end,
})

core.register_on_shutdown(function()
	local ok, result = vb.save_now()
	if not ok then
		core.log("error", "[voxel_boroughs] shutdown save failed: " .. tostring(result))
	end
end)

core.log("action", ("[voxel_boroughs] loaded schema v%d, generation %d, state %s")
	:format(vb.simulation.SCHEMA_VERSION, vb.state.generation or 0,
		vb.simulation.state_hash(vb.state)))
