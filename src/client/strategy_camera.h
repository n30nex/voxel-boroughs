// Voxel Boroughs strategy camera
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "constants.h"
#include "irr_v3d.h"

#include <algorithm>
#include <cmath>

namespace StrategyCamera
{

constexpr f32 MIN_DISTANCE = 30.0f * BS;
constexpr f32 MAX_DISTANCE = 240.0f * BS;

inline v3f orbitPosition(const v3f &focus, f32 yaw_degrees,
		f32 elevation_degrees, f32 distance)
{
	const f32 yaw = yaw_degrees * core::DEGTORAD;
	const f32 elevation = elevation_degrees * core::DEGTORAD;
	const f32 horizontal = std::cos(elevation) * distance;
	return focus + v3f(
		std::sin(yaw) * horizontal,
		std::sin(elevation) * distance,
		std::cos(yaw) * horizontal);
}

inline f32 zoomTarget(f32 current, s32 wheel_steps)
{
	const f32 zoomed = current * std::pow(0.84f, static_cast<f32>(wheel_steps));
	return std::clamp(zoomed, MIN_DISTANCE, MAX_DISTANCE);
}

inline f32 controlYaw(f32 orbit_yaw)
{
	f32 result = std::fmod(orbit_yaw + 180.0f, 360.0f);
	if (result < 0.0f)
		result += 360.0f;
	return result;
}

} // namespace StrategyCamera

