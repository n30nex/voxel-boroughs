-- SPDX-License-Identifier: MIT

local vb = voxel_boroughs
local sim = vb.simulation
local protocol = {
	name = "voxel_boroughs:ui:v1",
	version = 1,
	sequence = 0,
	last_command_us = {},
}
vb.protocol = protocol

local channel = core.mod_channel_join(protocol.name)

local function send(message_type, payload, target)
	if not channel or not channel:is_writeable() then
		return false
	end
	protocol.sequence = protocol.sequence + 1
	local encoded = core.write_json({
		v = protocol.version,
		seq = protocol.sequence,
		type = message_type,
		payload = payload or {},
		target = target or "",
	})
	if not encoded then
		return false
	end
	channel:send_all(encoded)
	return true
end

local function snapshot()
	local state = vb.state
	return {
		day = state.day,
		speed = state.speed,
		funds = state.funds,
		last_balance = state.last_balance,
		population = state.population,
		jobs = state.jobs,
		demand = state.demand,
		annexed = state.annexed,
		state_hash = sim.state_hash(state),
	}
end

function protocol.send_snapshot(target)
	return send("snapshot", snapshot(), target)
end

function protocol.broadcast_delta(delta_type, payload)
	payload = payload or {}
	payload.delta_type = delta_type
	payload.day = vb.state.day
	payload.state_hash = payload.state_hash or sim.state_hash(vb.state)
	return send("delta", payload)
end

local function reject(sender, id, reason)
	return send("error", {id = id, reason = reason}, sender)
end

local function valid_command(command)
	return type(command) == "table"
		and command.v == protocol.version
		and type(command.id) == "string"
		and #command.id > 0 and #command.id <= 64
		and type(command.action) == "string"
		and #command.action > 0 and #command.action <= 32
		and (command.args == nil or type(command.args) == "table")
end

core.register_on_modchannel_message(function(channel_name, sender, message)
	if channel_name ~= protocol.name or sender == "" or type(message) ~= "string" or #message > 8192 then
		return
	end
	local command = core.parse_json(message, nil, true)
	if not valid_command(command) then
		reject(sender, "", "malformed_command")
		return
	end

	local now = core.get_us_time()
	if now - (protocol.last_command_us[sender] or 0) < 50000 then
		reject(sender, command.id, "rate_limited")
		return
	end
	protocol.last_command_us[sender] = now

	if not core.check_player_privs(sender, {interact = true}) then
		reject(sender, command.id, "permission_denied")
		return
	end

	local args = command.args or {}
	if command.action == "hello" or command.action == "status" then
		protocol.send_snapshot(sender)
	elseif command.action == "build" then
		local allowed = {
			road = true, power = true, water = true,
			zone_r = true, zone_c = true, zone_i = true, bulldoze = true,
		}
		if not allowed[args.tool] then
			reject(sender, command.id, "unknown_tool")
			return
		end
		local ok, result = vb.apply_city_command(sender, args.tool, tonumber(args.cx), tonumber(args.cz))
		if not ok then
			reject(sender, command.id, result)
		else
			send("ack", {id = command.id, cell = result}, sender)
		end
	elseif command.action == "speed" then
		if not core.check_player_privs(sender, {server = true}) then
			reject(sender, command.id, "permission_denied")
			return
		end
		local ok, reason = sim.set_speed(vb.state, args.speed)
		if not ok then
			reject(sender, command.id, reason)
		else
			vb.dirty = true
			vb.update_all_huds()
			protocol.broadcast_delta("speed", {speed = vb.state.speed})
			send("ack", {id = command.id}, sender)
		end
	elseif command.action == "save" then
		if not core.check_player_privs(sender, {server = true}) then
			reject(sender, command.id, "permission_denied")
			return
		end
		local ok, result = vb.save_now()
		if ok then
			send("ack", {id = command.id, state_hash = result}, sender)
		else
			reject(sender, command.id, result)
		end
	else
		reject(sender, command.id, "unknown_action")
	end
end)

core.register_on_leaveplayer(function(player)
	protocol.last_command_us[player:get_player_name()] = nil
end)

