-- SPDX-License-Identifier: MIT

local vb = voxel_boroughs
local sim = vb.simulation
local huds = {}

local function speed_label(speed)
	return speed == 0 and "PAUSED" or (tostring(speed) .. "x")
end

local function summary_text()
	local state = vb.state
	return ("VOXEL BOROUGHS  |  Day %d  %s\n$%d  (%+d/day)  |  Population %d  |  Jobs %d\nDemand  R %+d   C %+d   I %+d")
		:format(state.day, speed_label(state.speed), math.floor(state.funds), state.last_balance or 0,
			state.population, state.jobs, state.demand.r, state.demand.c, state.demand.i)
end

function vb.ensure_hud(player)
	local name = player:get_player_name()
	if huds[name] then
		return
	end
	huds[name] = {
		summary = player:hud_add({
			type = "text",
			position = {x = 0.02, y = 0.03},
			offset = {x = 0, y = 0},
			alignment = {x = 1, y = 1},
			scale = {x = 100, y = 100},
			number = 0xF4F1E8,
			text = summary_text(),
			style = 1,
		}),
		hint = player:hud_add({
			type = "text",
			position = {x = 0.5, y = 0.92},
			offset = {x = 0, y = 0},
			alignment = {x = 0, y = -1},
			number = 0xE9E2CF,
			text = "1–8 choose tool  •  Left-click builds  •  Right-drag orbits  •  Wheel zooms  •  WASD/edge pans",
		}),
	}
end

function vb.update_hud(player)
	if not player or not player:is_player() then
		return
	end
	vb.ensure_hud(player)
	player:hud_change(huds[player:get_player_name()].summary, "text", summary_text())
end

function vb.update_all_huds()
	for _, player in ipairs(core.get_connected_players()) do
		vb.update_hud(player)
	end
end

core.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
end)

local function demand_bar(value, color, y)
	local width = math.max(0.05, math.abs(value) / 100 * 4.4)
	local x = value >= 0 and 6.8 or (6.8 - width)
	return ("box[%0.2f,%0.2f;%0.2f,0.38;%s]"):format(x, y, width, color)
end

local function inspector_text(pointed_thing)
	if not pointed_thing or pointed_thing.type ~= "node" then
		return "Select a voxel cell with City Hall to inspect it."
	end
	local pos = pointed_thing.under
	local cx = math.floor(pos.x / sim.CELL_SIZE)
	local cz = math.floor(pos.z / sim.CELL_SIZE)
	local cell = vb.state.cells[sim.cell_key(cx, cz)]
	if not cell then
		return ("Cell %d, %d — undeveloped land"):format(cx, cz)
	end
	local service = sim.is_serviced(vb.state, cell) and "road + power + water" or "missing network service"
	return ("Cell %d, %d — %s, stage %d, %s"):format(cx, cz, cell.kind, cell.stage or 0, service)
end

local function dashboard_formspec(pointed_thing, welcome)
	local state = vb.state
	local title = welcome and "Welcome to your first borough" or "City Hall"
	return table.concat({
		"formspec_version[7]",
		"size[14,8.2]",
		"bgcolor[#182127E8;true]",
		"style_type[label;font_size=18;textcolor=#F4F1E8]",
		"style_type[button;border=false;bgcolor=#344B58;bgcolor_hovered=#446777;textcolor=#FFFFFF]",
		("label[0.6,0.55;%s]"):format(core.formspec_escape(title)),
		("label[0.6,1.25;Day %d     Treasury: $%d     Daily balance: %+d]")
			:format(state.day, math.floor(state.funds), state.last_balance or 0),
		("label[0.6,1.85;Population: %d     Jobs: %d     State: %s]")
			:format(state.population, state.jobs, core.formspec_escape(sim.state_hash(state))),
		"label[0.6,2.6;Residential demand]",
		demand_bar(state.demand.r, "#59B783", 2.62),
		"label[0.6,3.25;Commercial demand]",
		demand_bar(state.demand.c, "#5C9BD1", 3.27),
		"label[0.6,3.9;Industrial demand]",
		demand_bar(state.demand.i, "#D6A64E", 3.92),
		"box[6.76,2.55;0.08,1.85;#EDE8DA]",
		("textarea[0.6,4.75;12.8,1.0;;; %s]"):format(core.formspec_escape(inspector_text(pointed_thing))),
		"label[0.6,6.15;Simulation speed]",
		"button[3.1,5.9;1.4,0.65;speed_0;Pause]",
		"button[4.65,5.9;1.2,0.65;speed_1;1×]",
		"button[6.0,5.9;1.2,0.65;speed_2;2×]",
		"button[7.35,5.9;1.2,0.65;speed_4;4×]",
		"button[9.2,5.9;1.8,0.65;save;Save city]",
		"button_exit[11.2,5.9;2.0,0.65;close;Return]",
		"label[0.6,7.35;Build a road beside a zone and supply one power plant and water tower to unlock growth.]",
	})
end

function vb.show_dashboard(player, pointed_thing)
	if player and player:is_player() then
		core.show_formspec(player:get_player_name(), "voxel_boroughs:dashboard",
			dashboard_formspec(pointed_thing, false))
	end
end

function vb.show_welcome(player)
	core.show_formspec(player:get_player_name(), "voxel_boroughs:dashboard",
		dashboard_formspec(nil, true))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "voxel_boroughs:dashboard" then
		return false
	end
	for _, speed in ipairs({0, 1, 2, 4}) do
		if fields["speed_" .. speed] then
			sim.set_speed(vb.state, speed)
			vb.dirty = true
			vb.update_all_huds()
			if vb.protocol then
				vb.protocol.broadcast_delta("speed", {speed = speed})
			end
		end
	end
	if fields.save then
		local ok, result = vb.save_now()
		core.chat_send_player(player:get_player_name(), ok and ("City saved: " .. result)
			or ("Save failed: " .. tostring(result)))
	end
	if not fields.quit and not fields.close then
		vb.show_dashboard(player)
	end
	return true
end)

