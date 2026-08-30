-- SPDX-License-Identifier: MIT

local vb = voxel_boroughs
local sim = vb.simulation
local storage = core.get_mod_storage()

local function encode(value)
	local json, error_message = core.write_json(value)
	if not json then
		return nil, error_message
	end
	return core.encode_base64(core.compress(json, "deflate", 6)), nil, json
end

local function decode(value)
	local compressed = core.decode_base64(value or "")
	if not compressed then
		return nil, "invalid_base64"
	end
	local ok, json = pcall(core.decompress, compressed, "deflate")
	if not ok then
		return nil, "invalid_compression"
	end
	local parsed, error_message = core.parse_json(json, nil, true)
	return parsed, error_message, json
end

local function district_ids(state)
	local ids = {}
	for id in pairs(state.annexed) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

local function district_cells(state, district_id)
	local cells = {}
	for _, key in ipairs(sim.sorted_cell_keys(state)) do
		local cell = state.cells[key]
		if sim.district_key_for_cell(cell.cx, cell.cz) == district_id then
			cells[#cells + 1] = {
				cx = cell.cx,
				cz = cell.cz,
				kind = cell.kind,
				stage = cell.stage or 0,
				built_day = cell.built_day or 0,
				last_growth_day = cell.last_growth_day or 0,
			}
		end
	end
	return cells
end

function vb.save_state()
	local previous = tonumber(storage:get_string("active_generation")) or 0
	local generation = previous + 1
	local manifest = {
		schema = sim.SCHEMA_VERSION,
		generation = generation,
		previous_generation = previous,
		compression = "deflate+base64",
		state_hash = sim.state_hash(vb.state),
		global = {
			seed = vb.state.seed,
			day = vb.state.day,
			speed = vb.state.speed,
			funds = vb.state.funds,
			tax_rate = vb.state.tax_rate,
			last_balance = vb.state.last_balance,
		},
		annexed = district_ids(vb.state),
		districts = {},
	}

	for _, id in ipairs(manifest.annexed) do
		local shard = {schema = sim.SCHEMA_VERSION, district = id, cells = district_cells(vb.state, id)}
		local encoded, error_message, json = encode(shard)
		if not encoded then
			return false, "district_encode_failed: " .. tostring(error_message)
		end
		local key = ("generation:%d:district:%s"):format(generation, id)
		storage:set_string(key, encoded)
		manifest.districts[#manifest.districts + 1] = {
			id = id,
			key = key,
			checksum = sim.hash_string(json),
		}
	end

	local encoded_manifest, error_message = encode(manifest)
	if not encoded_manifest then
		return false, "manifest_encode_failed: " .. tostring(error_message)
	end
	local manifest_key = ("generation:%d:manifest"):format(generation)
	storage:set_string(manifest_key, encoded_manifest)
	if storage:get_string(manifest_key) ~= encoded_manifest then
		return false, "manifest_verify_failed"
	end

	-- The pointer is committed last. An interrupted write therefore leaves the
	-- previous complete generation active.
	storage:set_string("active_generation", tostring(generation))
	vb.state.generation = generation
	vb.dirty = false
	return true, manifest.state_hash
end

local function load_generation(generation)
	if not generation or generation < 1 then
		return nil, "generation_missing"
	end
	local manifest_key = ("generation:%d:manifest"):format(generation)
	local manifest, error_message = decode(storage:get_string(manifest_key))
	if not manifest then
		return nil, "manifest_invalid: " .. tostring(error_message)
	end
	if manifest.schema ~= sim.SCHEMA_VERSION or manifest.generation ~= generation then
		return nil, "schema_not_supported"
	end

	local global = manifest.global or {}
	local state = sim.new(global.seed)
	state.day = tonumber(global.day) or 0
	state.speed = tonumber(global.speed) or 1
	state.funds = tonumber(global.funds) or 50000
	state.tax_rate = tonumber(global.tax_rate) or 0.09
	state.last_balance = tonumber(global.last_balance) or 0
	state.annexed = {}
	for _, id in ipairs(manifest.annexed or {"0,0"}) do
		state.annexed[id] = true
	end
	if next(state.annexed) == nil then
		state.annexed["0,0"] = true
	end

	for _, descriptor in ipairs(manifest.districts or {}) do
		local shard, shard_error, json = decode(storage:get_string(descriptor.key))
		if not shard or sim.hash_string(json or "") ~= descriptor.checksum then
			return nil, "district_invalid: " .. tostring(shard_error or descriptor.id)
		end
		for _, cell in ipairs(shard.cells or {}) do
			local key = sim.cell_key(cell.cx, cell.cz)
			state.cells[key] = cell
		end
	end
	sim.recalculate(state)
	state.generation = generation
	if sim.state_hash(state) ~= manifest.state_hash then
		return nil, "state_hash_mismatch"
	end
	return state
end

function vb.load_state()
	local active = tonumber(storage:get_string("active_generation")) or 0
	for generation = active, math.max(1, active - 2), -1 do
		local state, error_message = load_generation(generation)
		if state then
			if generation ~= active then
				core.log("warning", ("[voxel_boroughs] recovered save generation %d after generation %d failed")
					:format(generation, active))
				storage:set_string("active_generation", tostring(generation))
			end
			return state
		end
		if active > 0 then
			core.log("warning", ("[voxel_boroughs] save generation %d rejected: %s")
				:format(generation, tostring(error_message)))
		end
	end
	return nil
end

