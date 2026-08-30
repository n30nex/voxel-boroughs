#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

source_root="${VOXEL_BOROUGHS_SOURCE_ROOT:-/home/neonx/src/voxel-boroughs}"
build_root="${VOXEL_BOROUGHS_BUILD_ROOT:-/home/neonx/builds/voxel-boroughs}"
source_sha="${1:-$(git -C "$source_root" rev-parse HEAD)}"
native_build="$build_root/native-arm64"

"$source_root/ops/pi/preflight.sh" "$source_sha"

nice -n 10 ionice -c2 -n7 cmake -S "$source_root" -B "$native_build" -G Ninja \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DRUN_IN_PLACE=TRUE \
	-DBUILD_CLIENT=TRUE \
	-DBUILD_SERVER=TRUE \
	-DBUILD_UNITTESTS=TRUE \
	-DENABLE_GETTEXT=TRUE \
	-DENABLE_LTO=FALSE
nice -n 10 ionice -c2 -n7 cmake --build "$native_build" --parallel 2

nice -n 10 ionice -c2 -n7 timeout 300s "$source_root/bin/voxel-boroughs" --run-unittests
find "$source_root/games/voxel_boroughs" "$source_root/clientmods/voxel_boroughs_bridge" \
	-name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p
lua5.1 "$source_root/games/voxel_boroughs/mods/voxel_boroughs/tests/test_simulation.lua"

if ss -Hlun 'sport = :30002' | grep -q .; then
	printf 'UDP port 30002 is already in use\n' >&2
	exit 1
fi
(cd "$source_root" && nice -n 10 ionice -c2 -n7 ./util/test_voxel_boroughs_headless.sh)
"$source_root/ops/pi/package-native-arm64.sh" "$source_sha"
