#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

source_root="${VOXEL_BOROUGHS_SOURCE_ROOT:-/home/neonx/src/voxel-boroughs}"
build_root="${VOXEL_BOROUGHS_BUILD_ROOT:-/home/neonx/builds/voxel-boroughs}"
source_sha="${1:-$(git -C "$source_root" rev-parse HEAD)}"
native_build="$build_root/native-arm64"
service=voxel-boroughs-dev.service
service_was_active=false

restore_service() {
	if $service_was_active && ! systemctl --user is-active --quiet "$service"; then
		systemctl --user start "$service"
		for _ in $(seq 1 20); do
			if systemctl --user is-active --quiet "$service" &&
				ss -Hlunp 'sport = :30001' | grep -q '192\.168\.0\.24:30001'; then
				return 0
			fi
			sleep 1
		done
		printf 'Failed to restore %s after build tests\n' "$service" >&2
		return 1
	fi
}

on_exit() {
	local status=$?
	trap - EXIT
	restore_service || status=1
	exit "$status"
}
trap on_exit EXIT

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

if systemctl --user is-active --quiet "$service"; then
	service_was_active=true
	ss -Hlunp 'sport = :30001' | grep -q '192\.168\.0\.24:30001' || {
		printf '%s is active but does not own the expected private endpoint\n' "$service" >&2
		exit 1
	}
	systemctl --user stop "$service"
elif ss -Hlun 'sport = :30001' | grep -q .; then
	printf 'UDP port 30001 is owned by another process\n' >&2
	exit 1
fi
test -z "$(ss -Hlun 'sport = :30001')"
nice -n 10 ionice -c2 -n7 timeout 300s "$source_root/bin/voxel-boroughs" --run-unittests
restore_service
service_was_active=false
find "$source_root/games/voxel_boroughs" "$source_root/clientmods/voxel_boroughs_bridge" \
	-name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p
lua5.1 "$source_root/games/voxel_boroughs/mods/voxel_boroughs/tests/test_simulation.lua"

if ss -Hlun 'sport = :30002' | grep -q .; then
	printf 'UDP port 30002 is already in use\n' >&2
	exit 1
fi
(cd "$source_root" && nice -n 10 ionice -c2 -n7 ./util/test_voxel_boroughs_headless.sh)
"$source_root/ops/pi/package-native-arm64.sh" "$source_sha"
trap - EXIT
