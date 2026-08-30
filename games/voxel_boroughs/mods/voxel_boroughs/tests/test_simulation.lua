-- SPDX-License-Identifier: MIT

local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)[/\\]tests[/\\]")
local simulation = dofile(root .. "/simulation.lua")

local tests = 0
local function check(condition, message)
	tests = tests + 1
	if not condition then
		error("test failed: " .. message, 2)
	end
end

local function build_seed_city(state)
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
	for _, command in ipairs(commands) do
		local ok, reason = simulation.apply_command(state, command[1], {
			cx = command[2], cz = command[3],
		})
		check(ok, command[1] .. " rejected: " .. tostring(reason))
	end
end

local first = simulation.new(424242)
local second = simulation.new(424242)
build_seed_city(first)
build_seed_city(second)

for _ = 1, 40 do
	simulation.advance_day(first)
	simulation.advance_day(second)
end

check(first.population > 0, "residential zones should grow")
check(first.jobs > 0, "commercial or industrial zones should grow")
check(simulation.state_hash(first) == simulation.state_hash(second), "same seed and commands must match")

local before = first.funds
local ok, reason = simulation.apply_command(first, "road", {cx = 32, cz = 0})
check(not ok and reason == "district_not_annexed", "unannexed district must reject building")
check(first.funds == before, "rejected command must not charge funds")

ok, reason = simulation.apply_command(first, "road", {cx = 0.5, cz = 0})
check(not ok and reason == "invalid_cell", "fractional cells must be rejected")

ok = simulation.set_speed(first, 4)
check(ok and first.speed == 4, "4x speed should be accepted")
ok, reason = simulation.set_speed(first, 3)
check(not ok and reason == "invalid_speed", "unsupported speed must be rejected")

local hash_before = simulation.state_hash(first)
simulation.recalculate(first)
check(hash_before == simulation.state_hash(first), "recalculation must be idempotent")

print(("Voxel Boroughs simulation: %d assertions passed; hash=%s")
	:format(tests, simulation.state_hash(first)))

