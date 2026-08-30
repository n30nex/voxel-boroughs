-- Voxel Boroughs trusted client bridge
-- SPDX-License-Identifier: MIT

local CHANNEL = "voxel_boroughs:ui:v1"
local VERSION = 1
local channel = core.mod_channel_join(CHANNEL)
local next_id = 0
local last_sequence = 0
local latest_snapshot = nil

local function send(action, args)
	if not channel or not channel:is_writeable() then
		return false
	end
	next_id = next_id + 1
	local message = core.write_json({
		v = VERSION,
		id = tostring(next_id),
		action = action,
		args = args or {},
	})
	if not message then
		return false
	end
	channel:send_all(message)
	return true
end

core.register_on_modchannel_signal(function(channel_name, signal)
	if channel_name == CHANNEL and (signal == 0 or signal == 5) then
		send("hello", {})
	end
end)

core.register_on_modchannel_message(function(channel_name, sender, message)
	if channel_name ~= CHANNEL or sender ~= "" or type(message) ~= "string" then
		return
	end
	local reply = core.parse_json(message, nil, true)
	if type(reply) ~= "table" or reply.v ~= VERSION or type(reply.seq) ~= "number"
			or reply.seq <= last_sequence then
		return
	end
	local local_name = core.localplayer and core.localplayer:get_name() or ""
	if reply.target and reply.target ~= "" and reply.target ~= local_name then
		return
	end
	last_sequence = reply.seq
	if reply.type == "snapshot" then
		latest_snapshot = reply.payload
	elseif reply.type == "delta" and latest_snapshot then
		for key, value in pairs(reply.payload or {}) do
			latest_snapshot[key] = value
		end
	end
end)

_G.voxel_boroughs_bridge = {
	send = send,
	get_snapshot = function()
		return latest_snapshot
	end,
	get_last_sequence = function()
		return last_sequence
	end,
}

