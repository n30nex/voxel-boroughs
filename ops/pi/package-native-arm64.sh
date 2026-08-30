#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

source_root="${VOXEL_BOROUGHS_SOURCE_ROOT:-/home/neonx/src/voxel-boroughs}"
build_root="${VOXEL_BOROUGHS_BUILD_ROOT:-/home/neonx/builds/voxel-boroughs}"
native_build="$build_root/native-arm64"
source_sha="${1:-$(git -C "$source_root" rev-parse HEAD)}"
short_sha="${source_sha:0:12}"
artifact_dir="$build_root/artifacts/$source_sha"
release_dir="$build_root/releases/$source_sha"
artifact_name="voxel-boroughs-0.0.1-dev-linux-arm64-$short_sha.tar.gz"
stage="$(mktemp -d "$build_root/package-$short_sha.XXXXXX")"
artifact_complete=false

cleanup() {
	case "$stage" in
		"$build_root"/package-*) rm -rf -- "$stage" ;;
		*) printf 'Refusing to remove unexpected package directory: %s\n' "$stage" >&2 ;;
	esac
	if ! $artifact_complete && test -e "$artifact_dir"; then
		case "$artifact_dir" in
			"$build_root"/artifacts/"$source_sha") rm -rf -- "$artifact_dir" ;;
			*) printf 'Refusing to remove unexpected artifact directory: %s\n' "$artifact_dir" >&2 ;;
		esac
	fi
}
trap cleanup EXIT

"$source_root/ops/pi/preflight.sh" "$source_sha"
test -x "$source_root/bin/voxel-boroughs" 
test -x "$source_root/bin/voxel-boroughs-server"
test ! -e "$release_dir"
test ! -e "$artifact_dir"
mkdir -p "$artifact_dir"

cmake --install "$native_build" --prefix "$stage" --strip >"$artifact_dir/install.log"
test -x "$stage/bin/voxel-boroughs"
test -x "$stage/bin/voxel-boroughs-server"

(cd "$stage" && tar --sort=name --mtime="@$(git -C "$source_root" show -s --format=%ct "$source_sha")" \
	--owner=0 --group=0 --numeric-owner -cf - .) |
	gzip -n >"$artifact_dir/$artifact_name.partial"
mv "$artifact_dir/$artifact_name.partial" "$artifact_dir/$artifact_name"
sha256="$(sha256sum "$artifact_dir/$artifact_name" | awk '{print $1}')"
printf '%s  %s\n' "$sha256" "$artifact_name" >"$artifact_dir/SHA256SUMS"
ldd "$stage/bin/voxel-boroughs" >"$artifact_dir/voxel-boroughs.ldd.txt"
ldd "$stage/bin/voxel-boroughs-server" >"$artifact_dir/voxel-boroughs-server.ldd.txt"

cat >"$artifact_dir/manifest.json" <<EOF
{
  "project": "Voxel Boroughs",
  "version": "0.0.1-dev",
  "artifact_kind": "linux-arm64-native",
  "artifact": "$artifact_name",
  "sha256": "$sha256",
  "source_sha": "$source_sha",
  "luanti_base_version": "5.17.0",
  "build_host": "neopi5",
  "architecture": "aarch64",
  "container_digests": [],
  "source_date_epoch": $(git -C "$source_root" show -s --format=%ct "$source_sha")
}
EOF

mkdir -p "$(dirname "$release_dir")"
mv "$stage" "$release_dir"
artifact_complete=true
trap - EXIT
printf 'Packaged %s (%s)\n' "$artifact_dir/$artifact_name" "$sha256"
