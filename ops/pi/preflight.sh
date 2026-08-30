#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

source_root="${VOXEL_BOROUGHS_SOURCE_ROOT:-/home/neonx/src/voxel-boroughs}"
build_root="${VOXEL_BOROUGHS_BUILD_ROOT:-/home/neonx/builds/voxel-boroughs}"
expected_sha="${1:-$(git -C "$source_root" rev-parse HEAD)}"

fail() {
	printf 'Voxel Boroughs Pi preflight failed: %s\n' "$*" >&2
	exit 1
}

test "$(hostname -s)" = "neopi5" || fail "host is not neopi5"
ip -4 -o addr show scope global | awk '{print $4}' | grep -q '^192\.168\.0\.24/' ||
	fail "192.168.0.24 is not assigned"
test "$(uname -m)" = "aarch64" || fail "host is not ARM64"
test -d "$source_root/.git" || fail "source checkout is missing"
test -d "$build_root" || fail "build root is missing"
test "$(git -C "$source_root" rev-parse HEAD)" = "$expected_sha" || fail "source SHA differs"
test -z "$(git -C "$source_root" status --porcelain)" || fail "source checkout is dirty"

load_one="$(cut -d' ' -f1 /proc/loadavg)"
mem_available="$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"
swap_free="$(awk '/SwapFree/ {print $2}' /proc/meminfo)"
disk_free="$(df --output=avail -k "$build_root" | tail -n1)"
awk -v value="$load_one" 'BEGIN {exit !(value <= 4.0)}' || fail "one-minute load exceeds 4.0"
test "$mem_available" -ge 2097152 || fail "less than 2 GiB memory is available"
test "$swap_free" -ge 262144 || fail "less than 256 MiB swap is free"
test "$disk_free" -ge 10485760 || fail "less than 10 GiB disk is free"

printf 'Voxel Boroughs Pi preflight passed: sha=%s load=%s mem_kib=%s swap_kib=%s disk_kib=%s\n' \
	"$expected_sha" "$load_one" "$mem_available" "$swap_free" "$disk_free"
