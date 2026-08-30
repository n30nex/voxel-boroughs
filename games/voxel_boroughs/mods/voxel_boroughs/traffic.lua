-- SPDX-License-Identifier: MIT

local vb = voxel_boroughs
local sim = vb.simulation
local vehicles = {}

core.register_entity("voxel_boroughs:sample_vehicle", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "cube",
		visual_size = {x = 0.45, y = 0.25, z = 0.75},
		textures = {
			"blank.png^[noalpha^[colorize:#D85A4B:255",
			"blank.png^[noalpha^[colorize:#D85A4B:255",
			"blank.png^[noalpha^[colorize:#D85A4B:255",
			"blank.png^[noalpha^[colorize:#D85A4B:255",
			"blank.png^[noalpha^[colorize:#D85A4B:255",
			"blank.png^[noalpha^[colorize:#D85A4B:255",
		},
		static_save = false,
	},
	on_activate = function(self)
		self.age = 0
	end,
	on_step = function(self, dtime)
		if not self.start_pos or not self.end_pos then
			self.object:remove()
			return
		end
		self.age = self.age + dtime
		local duration = self.duration or 4
		local progress = math.min(1, self.age / duration)
		self.object:set_pos(vector.add(self.start_pos,
			vector.multiply(vector.subtract(self.end_pos, self.start_pos), progress)))
		if progress >= 1 then
			vehicles[self.object] = nil
			self.object:remove()
		end
	end,
})

local function live_vehicle_count()
	local count = 0
	for object in pairs(vehicles) do
		if object and object:get_pos() then
			count = count + 1
		else
			vehicles[object] = nil
		end
	end
	return count
end

function vb.spawn_sample_traffic()
	if vb.state.population < 1 or live_vehicle_count() >= 24 then
		return
	end
	local roads = sim.sorted_cell_keys(vb.state, "road")
	if #roads < 2 then
		return
	end
	local amount = math.min(3, math.max(1, math.floor(vb.state.population / 100)))
	for index = 1, amount do
		local start_key = roads[((vb.state.day + index - 2) % #roads) + 1]
		local end_key = roads[((vb.state.day + index) % #roads) + 1]
		local sx, sz = sim.parse_cell_key(start_key)
		local ex, ez = sim.parse_cell_key(end_key)
		local start_pos = {x = sx * 8 + 3.5, y = 1.3, z = sz * 8 + 3.5}
		local end_pos = {x = ex * 8 + 3.5, y = 1.3, z = ez * 8 + 3.5}
		local object = core.add_entity(start_pos, "voxel_boroughs:sample_vehicle")
		if object then
			local entity = object:get_luaentity()
			entity.start_pos = start_pos
			entity.end_pos = end_pos
			entity.duration = 3 + index
			vehicles[object] = true
		end
	end
end

