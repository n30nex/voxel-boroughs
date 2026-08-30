#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

source_root="${VOXEL_BOROUGHS_SOURCE_ROOT:-/home/neonx/src/voxel-boroughs}"
build_root="${VOXEL_BOROUGHS_BUILD_ROOT:-/home/neonx/builds/voxel-boroughs}"
source_sha="${1:-$(git -C "$source_root" rev-parse HEAD)}"
short_sha="${source_sha:0:12}"
release_dir="$build_root/releases/$source_sha"
artifact_dir="$build_root/artifacts/$source_sha"
evidence_dir="$artifact_dir/graphical-smoke-arm64"
work_dir="$(mktemp -d "$build_root/graphical-smoke-$short_sha.XXXXXX")"
partial_dir="$evidence_dir.partial"
runtime_dir="$work_dir/runtime"
profile_dir="$work_dir/profile"
config_file="$work_dir/client.conf"
compositor_pid=""
client_pid=""

fail() {
	printf 'Voxel Boroughs ARM64 graphical smoke failed: %s\n' "$*" >&2
	exit 1
}

stop_pid() {
	local pid="$1"
	local signal="${2:-INT}"
	local waited=0
	test -n "$pid" || return 0
	if kill -0 "$pid" 2>/dev/null; then
		kill -s "$signal" "$pid" 2>/dev/null || true
		while kill -0 "$pid" 2>/dev/null && test "$waited" -lt 20; do
			sleep 1
			waited=$((waited + 1))
		done
		if kill -0 "$pid" 2>/dev/null; then
			kill -TERM "$pid" 2>/dev/null || true
			for _ in $(seq 1 5); do
				kill -0 "$pid" 2>/dev/null || break
				sleep 1
			done
			if kill -0 "$pid" 2>/dev/null; then
				kill -KILL "$pid" 2>/dev/null || true
			fi
			wait "$pid" 2>/dev/null || true
			return 1
		fi
	fi
	wait "$pid" 2>/dev/null || true
}

cleanup() {
	stop_pid "$client_pid" INT || true
	stop_pid "$compositor_pid" TERM || true
	case "$partial_dir" in
		"$artifact_dir"/graphical-smoke-arm64.partial)
			test ! -e "$partial_dir" || rm -rf -- "$partial_dir"
			;;
		*) printf 'Refusing to remove unexpected partial evidence path: %s\n' "$partial_dir" >&2 ;;
	esac
	case "$work_dir" in
		"$build_root"/graphical-smoke-*) rm -rf -- "$work_dir" ;;
		*) printf 'Refusing to remove unexpected smoke directory: %s\n' "$work_dir" >&2 ;;
	esac
}
trap cleanup EXIT

"$source_root/ops/pi/preflight.sh" "$source_sha"
test -x "$release_dir/bin/voxel-boroughs" || fail "release client is missing"
test -d "$artifact_dir" || fail "artifact directory is missing"
test ! -e "$evidence_dir" || fail "evidence already exists at $evidence_dir"
test ! -e "$partial_dir" || fail "partial evidence already exists at $partial_dir"
systemctl --user is-active --quiet voxel-boroughs-dev.service || fail "development server is not active"
ss -Hlunp 'sport = :30001' | grep -q '192\.168\.0\.24:30001' ||
	fail "development server is not bound to the private LAN address"
command -v labwc >/dev/null || fail "labwc is missing"
command -v grim >/dev/null || fail "grim is missing"
command -v wlr-randr >/dev/null || fail "wlr-randr is missing"
command -v wtype >/dev/null || fail "wtype is missing"

mkdir -p "$runtime_dir" "$profile_dir" "$partial_dir"
chmod 0700 "$runtime_dir" "$profile_dir"
install -m 0600 "$source_root/ops/pi/voxel-boroughs-client-smoke.conf" "$config_file"

export XDG_RUNTIME_DIR="$runtime_dir"
export XDG_CONFIG_HOME="$work_dir/config"
export XDG_CACHE_HOME="$work_dir/cache"
export XDG_DATA_HOME="$work_dir/data"
export WLR_BACKENDS=headless
export WLR_HEADLESS_OUTPUTS=1
export WLR_LIBINPUT_NO_DEVICES=1
export SDL_VIDEODRIVER=wayland
export VOXEL_BOROUGHS_USER_PATH="$profile_dir"

labwc -C "$work_dir/labwc" >"$partial_dir/labwc.log" 2>&1 &
compositor_pid=$!
for _ in $(seq 1 20); do
	test -S "$runtime_dir/wayland-0" && break
	kill -0 "$compositor_pid" 2>/dev/null || fail "headless compositor exited during startup"
	sleep 1
done
test -S "$runtime_dir/wayland-0" || fail "headless Wayland socket was not created"
export WAYLAND_DISPLAY=wayland-0

output_name="$(wlr-randr | awk '/^[^[:space:]]/ {print $1; exit}')"
test -n "$output_name" || fail "headless output was not discovered"
wlr-randr --output "$output_name" --custom-mode 1920x1080@60Hz
wlr-randr >"$partial_dir/output.txt"
grep -q '1920x1080 px (current)' "$partial_dir/output.txt" || fail "output is not 1920x1080"

"$release_dir/bin/voxel-boroughs" \
	--config "$config_file" \
	--logfile "$partial_dir/menu.log" >"$partial_dir/menu.stdout.log" 2>&1 &
client_pid=$!
sleep 8
kill -0 "$client_pid" 2>/dev/null || fail "menu client exited before capture"
grim "$partial_dir/menu-before.png"
wtype -k Down
sleep 1
grim "$partial_dir/menu-after.png"
cmp -s "$partial_dir/menu-before.png" "$partial_dir/menu-after.png" &&
	fail "menu did not visibly respond to keyboard input"
stop_pid "$client_pid" INT || fail "menu client did not exit cleanly after SIGINT"
client_pid=""

"$release_dir/bin/voxel-boroughs" \
	--config "$config_file" \
	--logfile "$partial_dir/world.log" \
	--go --address 192.168.0.24 --port 30001 --name VBSmoke --password '' \
	>"$partial_dir/world.stdout.log" 2>&1 &
client_pid=$!

joined=false
for _ in $(seq 1 40); do
	if grep -Eq 'joined game|Client connected|Access denied|Connection timed out' "$partial_dir/world.log" 2>/dev/null; then
		grep -Eq 'joined game|Client connected' "$partial_dir/world.log" && joined=true
		break
	fi
	kill -0 "$client_pid" 2>/dev/null || fail "world client exited before connecting"
	sleep 1
done
if ! $joined; then
	journalctl --user-unit voxel-boroughs-dev.service --since '-90 seconds' --no-pager \
		-o cat | grep -q 'VBSmoke.*joins game' || fail "client did not join the development server"
fi

sleep 8
kill -0 "$client_pid" 2>/dev/null || fail "world client exited before capture"
grim "$partial_dir/world-before.png"
wtype -P w
sleep 2
wtype -p w
sleep 1
grim "$partial_dir/world-after.png"
cmp -s "$partial_dir/world-before.png" "$partial_dir/world-after.png" &&
	fail "world did not visibly respond to camera input"
cmp -s "$partial_dir/menu-after.png" "$partial_dir/world-after.png" &&
	fail "world capture is identical to the menu"

stop_pid "$client_pid" INT || fail "world client did not exit cleanly after SIGINT"
client_pid=""
grep -Eqi 'fatal error|segmentation fault' "$partial_dir/world.log" &&
	fail "world log contains a fatal error"

for image in menu-before.png menu-after.png world-before.png world-after.png; do
	file "$partial_dir/$image" | grep -q '1920 x 1080' || fail "$image is not 1920x1080"
done

menu_sha="$(sha256sum "$partial_dir/menu-after.png" | awk '{print $1}')"
world_sha="$(sha256sum "$partial_dir/world-after.png" | awk '{print $1}')"
cat >"$partial_dir/evidence.json" <<EOF
{
  "project": "Voxel Boroughs",
  "gate": "linux-arm64-headless-wayland-1080p",
  "source_sha": "$source_sha",
  "resolution": "1920x1080",
  "server": "192.168.0.24:30001/udp",
  "menu_interaction": true,
  "world_join": true,
  "camera_interaction": true,
  "clean_client_exit": true,
  "menu_screenshot_sha256": "$menu_sha",
  "world_screenshot_sha256": "$world_sha"
}
EOF

stop_pid "$compositor_pid" TERM || fail "headless compositor did not exit cleanly"
compositor_pid=""
mv "$partial_dir" "$evidence_dir"
trap - EXIT
case "$work_dir" in
	"$build_root"/graphical-smoke-*) rm -rf -- "$work_dir" ;;
	*) fail "unexpected smoke directory $work_dir" ;;
esac

printf 'Voxel Boroughs ARM64 graphical smoke passed: sha=%s evidence=%s\n' \
	"$source_sha" "$evidence_dir"
