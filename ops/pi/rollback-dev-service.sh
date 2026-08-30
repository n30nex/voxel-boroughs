#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

build_root="${VOXEL_BOROUGHS_BUILD_ROOT:-/home/neonx/builds/voxel-boroughs}"
deploy_dir="$build_root/deploy"
current="$deploy_dir/current"
previous="$deploy_dir/previous"

test -L "$current"
test -L "$previous"
current_target="$(readlink -f "$current")"
previous_target="$(readlink -f "$previous")"
case "$current_target" in "$build_root"/releases/*) ;; *) exit 1 ;; esac
case "$previous_target" in "$build_root"/releases/*) ;; *) exit 1 ;; esac

ln -s "$previous_target" "$deploy_dir/current.next"
mv -Tf "$deploy_dir/current.next" "$current"
ln -sfn "$current_target" "$previous"
systemctl --user restart voxel-boroughs-dev.service
systemctl --user is-active --quiet voxel-boroughs-dev.service
ss -Hlunp 'sport = :30001' | grep -q '192\.168\.0\.24:30001'
printf 'Rolled back Voxel Boroughs service to %s\n' "$previous_target"
