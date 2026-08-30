-- Voxel Boroughs original game code
-- SPDX-License-Identifier: MIT

local simulation = {}

simulation.SCHEMA_VERSION = 1
simulation.CELL_SIZE = 8
simulation.DISTRICT_CELLS = 32
simulation.DISTRICT_OFFSET = 16
simulation.COSTS = {
	road = 100,
	power = 2500,
	water = 1500,
	zone_r = 20,
	zone_c = 20,
	zone_i = 20,
	bulldoze = 10,
}

local capacities = {
	zone_r = {16, 48, 96},
	zone_c = {12, 36, 72},
	zone_i = {24, 72, 144},
}

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function integer(value)
	return type(value) == "number" and value == math.floor(value)
end

local function sorted_keys(values)
	local keys = {}
	for key in pairs(values or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

function simulation.cell_key(cx, cz)
	return tostring(cx) .. "," .. tostring(cz)
end

function simulation.parse_cell_key(key)
	local cx, cz = key:match("^(-?%d+),(-?%d+)$")
	return tonumber(cx), tonumber(cz)
end

function simulation.cell_to_district(cx, cz)
	return math.floor((cx + simulation.DISTRICT_OFFSET) / simulation.DISTRICT_CELLS),
		math.floor((cz + simulation.DISTRICT_OFFSET) / simulation.DISTRICT_CELLS)
end

function simulation.district_key_for_cell(cx, cz)
	local dx, dz = simulation.cell_to_district(cx, cz)
	return simulation.cell_key(dx, dz)
end

function simulation.is_annexed(state, cx, cz)
	return state.annexed[simulation.district_key_for_cell(cx, cz)] == true
end

function simulation.new(seed)
	return {
		schema = simulation.SCHEMA_VERSION,
		seed = tonumber(seed) or 1,
		day = 0,
		speed = 1,
		funds = 50000,
		tax_rate = 0.09,
		last_balance = 0,
		population = 0,
		jobs = 0,
		commercial_jobs = 0,
		industrial_jobs = 0,
		power_capacity = 0,
		water_capacity = 0,
		demand = {r = 65, c = 45, i = 50},
		annexed = {["0,0"] = true},
		cells = {},
	}
end

function simulation.recalculate(state)
	local population = 0
	local commercial_jobs = 0
	local industrial_jobs = 0
	local power_capacity = 0
	local water_capacity = 0
	local road_count = 0

	for _, cell in pairs(state.cells) do
		local capacity = capacities[cell.kind]
		if capacity and (cell.stage or 0) > 0 then
			local value = capacity[clamp(cell.stage, 1, #capacity)]
			if cell.kind == "zone_r" then
				population = population + value
			elseif cell.kind == "zone_c" then
				commercial_jobs = commercial_jobs + value
			else
				industrial_jobs = industrial_jobs + value
			end
		elseif cell.kind == "power" then
			power_capacity = power_capacity + 2000
		elseif cell.kind == "water" then
			water_capacity = water_capacity + 2000
		elseif cell.kind == "road" then
			road_count = road_count + 1
		end
	end

	state.population = population
	state.commercial_jobs = commercial_jobs
	state.industrial_jobs = industrial_jobs
	state.jobs = commercial_jobs + industrial_jobs
	state.power_capacity = power_capacity
	state.water_capacity = water_capacity
	state.road_count = road_count

	state.demand = state.demand or {}
	state.demand.r = math.floor(clamp(65 + (state.jobs - population) * 0.12, -100, 100) + 0.5)
	state.demand.c = math.floor(clamp(45 + population * 0.08 - commercial_jobs * 0.3, -100, 100) + 0.5)
	state.demand.i = math.floor(clamp(50 + population * 0.06 - industrial_jobs * 0.22, -100, 100) + 0.5)
	return state
end

local function has_adjacent_road(state, cx, cz)
	local offsets = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	for _, offset in ipairs(offsets) do
		local neighbor = state.cells[simulation.cell_key(cx + offset[1], cz + offset[2])]
		if neighbor and neighbor.kind == "road" then
			return true
		end
	end
	return false
end

function simulation.is_serviced(state, cell)
	local required = state.population + state.jobs + 1
	return has_adjacent_road(state, cell.cx, cell.cz)
		and state.power_capacity >= required
		and state.water_capacity >= required
end

function simulation.apply_command(state, action, args)
	args = args or {}
	local cx = tonumber(args.cx)
	local cz = tonumber(args.cz)
	if not integer(cx) or not integer(cz) then
		return false, "invalid_cell"
	end
	if not simulation.is_annexed(state, cx, cz) then
		return false, "district_not_annexed"
	end
	if simulation.COSTS[action] == nil then
		return false, "unknown_action"
	end

	local key = simulation.cell_key(cx, cz)
	local existing = state.cells[key]
	if action == "bulldoze" then
		if not existing then
			return false, "cell_empty"
		end
	elseif existing then
		return false, "cell_occupied"
	end

	local cost = simulation.COSTS[action]
	if state.funds < cost then
		return false, "insufficient_funds"
	end

	state.funds = state.funds - cost
	if action == "bulldoze" then
		state.cells[key] = nil
	else
		state.cells[key] = {
			cx = cx,
			cz = cz,
			kind = action,
			stage = 0,
			built_day = state.day,
		}
	end
	simulation.recalculate(state)
	return true, key
end

local function growth_score(state, cell)
	local value = state.seed * 17 + state.day * 97 + cell.cx * 131 + cell.cz * 197
	return math.abs(value % 100)
end

function simulation.begin_day(state)
	simulation.recalculate(state)
	state.day = state.day + 1

	local income = math.floor((state.population * 0.35 + state.jobs * 0.22) * state.tax_rate * 10)
	local expenses = (state.road_count or 0) * 2
		+ math.floor(state.power_capacity / 2000) * 35
		+ math.floor(state.water_capacity / 2000) * 25
	state.last_balance = income - expenses
	state.funds = state.funds + state.last_balance

	local queue = {}
	for _, key in ipairs(sorted_keys(state.cells)) do
		local cell = state.cells[key]
		if capacities[cell.kind] then
			queue[#queue + 1] = key
		end
	end
	return queue
end

function simulation.grow_cell(state, key)
	local cell = state.cells[key]
	if not cell or not capacities[cell.kind] then
		return false
	end

	local demand_key = cell.kind:sub(-1)
	local demand = state.demand[demand_key] or 0
	local score = growth_score(state, cell)
	local stage = cell.stage or 0

	if stage < 3 and demand > 0 and simulation.is_serviced(state, cell)
			and score < math.max(6, math.floor(demand / 3)) then
		cell.stage = stage + 1
		cell.last_growth_day = state.day
		return true
	end

	if stage > 0 and demand < -25 and score < math.floor(math.abs(demand) / 8) then
		cell.stage = stage - 1
		cell.last_growth_day = state.day
		return true
	end
	return false
end

function simulation.finish_day(state)
	return simulation.recalculate(state)
end

function simulation.advance_day(state)
	local changed = {}
	for _, key in ipairs(simulation.begin_day(state)) do
		if simulation.grow_cell(state, key) then
			changed[#changed + 1] = key
		end
	end
	simulation.finish_day(state)
	return changed
end

function simulation.set_speed(state, speed)
	speed = tonumber(speed)
	if speed ~= 0 and speed ~= 1 and speed ~= 2 and speed ~= 4 then
		return false, "invalid_speed"
	end
	state.speed = speed
	return true
end

function simulation.canonical(state)
	local parts = {
		tostring(state.schema), tostring(state.seed), tostring(state.day), tostring(state.speed),
		string.format("%.6f", state.funds), string.format("%.6f", state.tax_rate),
		tostring(state.population), tostring(state.jobs), tostring(state.last_balance),
	}
	for _, key in ipairs(sorted_keys(state.annexed)) do
		parts[#parts + 1] = "district:" .. key
	end
	for _, key in ipairs(sorted_keys(state.cells)) do
		local cell = state.cells[key]
		parts[#parts + 1] = table.concat({
			"cell", key, cell.kind, tostring(cell.stage or 0), tostring(cell.built_day or 0),
			tostring(cell.last_growth_day or 0),
		}, ":")
	end
	return table.concat(parts, "|")
end

function simulation.hash_string(value)
	local hash = 5381
	for index = 1, #value do
		hash = (hash * 33 + value:byte(index)) % 4294967291
	end
	return string.format("%08x", hash)
end

function simulation.state_hash(state)
	return simulation.hash_string(simulation.canonical(state))
end

function simulation.sorted_cell_keys(state, kind)
	local keys = {}
	for key, cell in pairs(state.cells) do
		if not kind or cell.kind == kind then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end

return simulation

