#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

source_root="${VOXEL_BOROUGHS_SOURCE_ROOT:-/home/neonx/src/voxel-boroughs}"
build_root="${VOXEL_BOROUGHS_BUILD_ROOT:-/home/neonx/builds/voxel-boroughs}"
source_sha="${1:?usage: install-dev-service.sh SOURCE_SHA}"
release_dir="$build_root/releases/$source_sha"
deploy_dir="$build_root/deploy"
current="$deploy_dir/current"
previous="$deploy_dir/previous"
unit_dir="$HOME/.config/systemd/user"
old_target=""

switch_current() {
	local target="$1"
	ln -sfn "$target" "$deploy_dir/current.next"
	mv -Tf "$deploy_dir/current.next" "$current"
}

rollback_on_error() {
	if test -n "$old_target"; then
		switch_current "$old_target"
		systemctl --user restart voxel-boroughs-dev.service || true
	else
		systemctl --user stop voxel-boroughs-dev.service || true
	fi
}
trap rollback_on_error ERR

"$source_root/ops/pi/preflight.sh" "$source_sha"
test -d "$release_dir"
test -x "$release_dir/bin/voxel-boroughs-server"
grep -q "\"source_sha\": \"$source_sha\"" "$build_root/artifacts/$source_sha/manifest.json"

mkdir -p "$deploy_dir" "$build_root/runtime" "$build_root/dev-world" "$unit_dir"
if test -e "$previous" && ! test -L "$previous"; then
	printf 'Previous deployment path exists and is not a symlink\n' >&2
	exit 1
fi
if test -L "$current"; then
	old_target="$(readlink -f "$current")"
	case "$old_target" in
		"$build_root"/releases/*) ;;
		*) printf 'Current release points outside the release root\n' >&2; exit 1 ;;
	esac
	ln -sfn "$old_target" "$previous"
elif test -e "$current"; then
	printf 'Current deployment path exists and is not a symlink\n' >&2
	exit 1
fi

port_owner="$(ss -Hlunp 'sport = :30001' || true)"
if test -n "$port_owner" && ! systemctl --user is-active --quiet voxel-boroughs-dev.service; then
	printf 'UDP port 30001 is owned by another process: %s\n' "$port_owner" >&2
	exit 1
fi

install -m 0600 "$source_root/ops/pi/voxel-boroughs-dev.conf" "$build_root/dev.conf"
install -m 0644 "$source_root/ops/pi/voxel-boroughs-dev.service" \
	"$unit_dir/voxel-boroughs-dev.service"
switch_current "$release_dir"
systemctl --user daemon-reload
systemctl --user enable --now voxel-boroughs-dev.service
systemctl --user restart voxel-boroughs-dev.service

for _ in $(seq 1 20); do
	if systemctl --user is-active --quiet voxel-boroughs-dev.service &&
		ss -Hlunp 'sport = :30001' | grep -q '192\.168\.0\.24:30001'; then
		break
	fi
	sleep 1
done
systemctl --user is-active --quiet voxel-boroughs-dev.service
ss -Hlunp 'sport = :30001' | grep -q '192\.168\.0\.24:30001'
grep -q '^server_announce = false$' "$build_root/dev.conf"
test "$(readlink -f "$current")" = "$release_dir"

trap - ERR
printf 'Voxel Boroughs development service active: sha=%s address=192.168.0.24:30001/udp\n' "$source_sha"
