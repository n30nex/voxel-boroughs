-- SPDX-License-Identifier: MIT

local vb = voxel_boroughs
local game_root = vb.root:match("^(.*)[/\\]mods[/\\]voxel_boroughs$")
local packs_root = game_root .. "/data_packs"
local id_pattern = "^[a-z0-9_]+:[a-z0-9_./-]+$"
local allowed_extensions = {json = true, mts = true, png = true, ogg = true, wav = true}

local function read_file(path)
	local file, error_message = io.open(path, "rb")
	if not file then
		return nil, error_message
	end
	local value = file:read("*a")
	file:close()
	return value
end

local function validate_files(path)
	for _, file_name in ipairs(core.get_dir_list(path, false)) do
		local extension = file_name:match("%.([^.]+)$")
		if not extension or not allowed_extensions[extension:lower()] then
			return false, "executable or unsupported file: " .. file_name
		end
	end
	for _, directory in ipairs(core.get_dir_list(path, true)) do
		local ok, error_message = validate_files(path .. "/" .. directory)
		if not ok then
			return false, error_message
		end
	end
	return true
end

local function validate_pack(pack)
	if type(pack) ~= "table" or pack.schema ~= 1 or type(pack.id) ~= "string"
			or not pack.id:match(id_pattern) or type(pack.title) ~= "string"
			or type(pack.version) ~= "string" then
		return false, "invalid required metadata"
	end
	for _, class in ipairs({"buildings", "policies", "services", "challenges"}) do
		if pack[class] ~= nil and type(pack[class]) ~= "table" then
			return false, class .. " must be an array"
		end
		for _, entry in ipairs(pack[class] or {}) do
			if type(entry) ~= "table" or type(entry.id) ~= "string"
					or not entry.id:match(id_pattern) or type(entry.title) ~= "string" then
				return false, "invalid " .. class .. " entry"
			end
		end
	end
	return true
end

function vb.load_data_packs()
	local result = {packs = {}, content = {}, aliases = {}}
	for _, directory in ipairs(core.get_dir_list(packs_root, true)) do
		local path = packs_root .. "/" .. directory
		local files_ok, files_error = validate_files(path)
		local json, read_error = read_file(path .. "/pack.json")
		local pack, parse_error
		if json then
			pack, parse_error = core.parse_json(json, nil, true)
		end
		local valid, validation_error = validate_pack(pack)
		if not files_ok or not json or not valid then
			error(("data pack %s rejected: %s"):format(directory,
				files_error or read_error or parse_error or validation_error))
		end
		if result.packs[pack.id] then
			error("duplicate data pack id: " .. pack.id)
		end
		result.packs[pack.id] = pack
		for _, class in ipairs({"buildings", "policies", "services", "challenges"}) do
			for _, entry in ipairs(pack[class] or {}) do
				if result.content[entry.id] then
					error("duplicate data content id: " .. entry.id)
				end
				entry.class = class
				entry.pack = pack.id
				result.content[entry.id] = entry
			end
		end
		for old_id, new_id in pairs(pack.aliases or {}) do
			if not old_id:match(id_pattern) or not new_id:match(id_pattern) then
				error("invalid content alias in data pack: " .. pack.id)
			end
			result.aliases[old_id] = new_id
		end
	end
	return result
end

vb.data_packs = vb.load_data_packs()

