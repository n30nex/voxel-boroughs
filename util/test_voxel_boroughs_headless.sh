#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="${VOXEL_BOROUGHS_SERVER:-$repo_root/bin/voxel-boroughs-server}"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/voxel-boroughs-integration.XXXXXX")"
world="$test_root/world"
seed_config="$test_root/seed.conf"
verify_config="$test_root/verify.conf"
seed_log="$test_root/seed.log"
verify_log="$test_root/verify.log"

cleanup() {
	case "$test_root" in
		"${TMPDIR:-/tmp}"/voxel-boroughs-integration.*) rm -rf -- "$test_root" ;;
		*) printf 'Refusing to remove unexpected test directory: %s\n' "$test_root" >&2 ;;
	esac
}
trap cleanup EXIT

test -x "$binary"
mkdir -p "$world"

write_config() {
	local destination="$1"
	local phase="$2"
	cat >"$destination" <<EOF
bind_address = 127.0.0.1
port = 30002
server_announce = false
max_users = 1
fixed_map_seed = 424242
voxel_boroughs_integration_test = true
voxel_boroughs_integration_phase = $phase
EOF
}

write_config "$seed_config" seed
write_config "$verify_config" verify

run_phase() {
	local config="$1"
	local log="$2"
	timeout 90s "$binary" --world "$world" --gameid voxel_boroughs \
		--config "$config" --logfile "$log"
	if grep -q 'VB_INTEGRATION_FAIL' "$log"; then
		grep 'VB_INTEGRATION_FAIL' "$log" >&2
		return 1
	fi
}

run_phase "$seed_config" "$seed_log"
seed_line="$(grep 'VB_INTEGRATION_PASS phase=seed' "$seed_log" | tail -n1)"
test -n "$seed_line"

run_phase "$verify_config" "$verify_log"
verify_line="$(grep 'VB_INTEGRATION_PASS phase=verify' "$verify_log" | tail -n1)"
test -n "$verify_line"

state="$(sed -n 's/.* state=\([^ ]*\).*/\1/p' <<<"$seed_line")"
layout="$(sed -n 's/.* layout=\([^ ]*\).*/\1/p' <<<"$seed_line")"
grep -q "state=$state layout=$layout" <<<"$verify_line"

printf 'Voxel Boroughs headless integration passed: state=%s layout=%s\n' "$state" "$layout"
