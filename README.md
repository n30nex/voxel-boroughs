# Voxel Boroughs

Voxel Boroughs is an original open-source voxel city builder: shape the land, connect streets and utilities, zone neighbourhoods, and watch an aggregated city simulation turn those plans into a living skyline.

This repository is a branded fork of [Luanti 5.17.0](https://github.com/luanti-org/luanti/releases/tag/5.17.0). It preserves Luanti's full history and keeps `luanti-org/luanti` as the `upstream` remote. Voxel Boroughs is a spiritual successor to classic city builders; it does not contain SimCity code, names, artwork, writing, or proprietary data.

> **Status: pre-alpha development slice.** There is no public binary release yet. `v0.1.0-alpha.1` will only be tagged after Windows x64, Linux x86_64, ARM64 development, save/reload, licensing, and runtime gates pass.

![Voxel Boroughs city blocks](games/voxel_boroughs/background.png)

## What works in the current slice

- A cursor-driven overhead strategy camera with smooth wheel zoom, right-drag orbit, WASD panning, edge panning, and screen-position voxel picking.
- One annexed 32×32-cell district. Each zoning cell is 8×8 one-metre voxels.
- Roads, a power plant, a water tower, low-density residential/commercial/industrial zoning, bulldozing, and a City Hall inspector.
- Deterministic demand, growth, jobs, population, daily taxes, upkeep, pause, 1×, 2×, and 4× simulation speeds.
- Procedural voxel buildings and capped representative traffic; no persistent agent exists for every citizen.
- A server-authoritative `voxel_boroughs:ui:v1` bridge with ordered snapshots/deltas and malformed-command rejection.
- Save schema v1 with compressed district shards, checksums, a commit-last generation pointer, autosave, and fallback to the previous complete generation.

The full service stack, transport depth, terrain tools, mixed-use/office zoning, dormant-district simulation, challenges, disasters, accessibility pass, and mega-city performance work remain milestone work. See [ROADMAP.md](ROADMAP.md).

## Play from source

Voxel Boroughs currently targets Windows x64 and Linux x86_64. Linux ARM64 is an internal development target for Raspberry Pi 5 testing.

Build the inherited Luanti engine normally, with both client and server enabled. The output executables are renamed to `voxel-boroughs` and `voxel-boroughs-server`; the bundled game ID is `voxel_boroughs`.

```sh
cmake -S . -B build -G Ninja \
  -DRUN_IN_PLACE=TRUE \
  -DBUILD_CLIENT=TRUE \
  -DBUILD_SERVER=TRUE \
  -DBUILD_UNITTESTS=TRUE
cmake --build build --parallel 2
./bin/voxel-boroughs
```

Create a world with the **Voxel Boroughs** game in the launcher. The initial district is centred on the world origin.

Controls:

- `1–8`: choose Road, Power, Water, R, C, I, Bulldoze, or City Hall.
- Left-click: apply the selected tool to the cursor's 8×8 cell.
- Right-drag: orbit the camera.
- Mouse wheel: zoom.
- `WASD` or screen edges: pan.
- `/city`: open City Hall; `/vb_hash` prints the deterministic state hash.

For first growth, lay a row of road cells, place a power plant and water tower, then zone R/C/I beside the road.

## Test the deterministic rules

The simulation core is engine-independent Lua 5.1:

```sh
lua games/voxel_boroughs/mods/voxel_boroughs/tests/test_simulation.lua
```

After a run-in-place server build, the headless integration scenario creates a
seeded district, writes a versioned save, restarts the server, and verifies
identical city-state and voxel-layout hashes:

```sh
util/test_voxel_boroughs_headless.sh
```

C++ unit tests include the strategy camera's orbit, zoom bounds, and view-relative control yaw. The project also retains Luanti's upstream unit and integration suites.

## Architecture

- `src/client/`: inherited LGPL engine plus the branded strategy-camera/input shell.
- `games/voxel_boroughs/`: original MIT server-authoritative simulation and CC BY 4.0 media.
- `clientmods/voxel_boroughs_bridge/`: trusted MIT client bridge bundled with this executable.
- `doc/voxel-boroughs/`: protocol, save, and data-pack contracts.
- `data-packs/schema-v1.json`: non-executable content-pack schema.
- `ops/pi/`: guarded Pi build, artifact, and LAN development-service tooling.

On `neopi5`, `ops/pi/build-native-arm64.sh SOURCE_SHA` performs the guarded
two-job native build, all unit and headless checks, and creates a deterministic
checksummed artifact. `ops/pi/install-dev-service.sh SOURCE_SHA` installs that
exact candidate as the private `192.168.0.24:30001/udp` user service; the
separate rollback script swaps back to the prior immutable candidate.

The client presents intent. The Lua server validates permissions, geometry, annexation, funds, and state before applying any outcome. Simulation work is deterministic and queued in small batches so a future 512×512-cell city does not require one Lua agent per resident.

## Upstream and licensing

Inherited Luanti code and modifications remain **LGPL-2.1-or-later** under [COPYING.LESSER](COPYING.LESSER). Original Voxel Boroughs game and simulation code is **MIT**. Original media is **CC BY 4.0**. Existing Luanti media retains its original licenses and attribution in [LICENSE.txt](LICENSE.txt).

See [NOTICE.md](NOTICE.md) and [LICENSES/README.md](LICENSES/README.md) for the exact boundary and attribution. The **Luanti** name and contributor credits remain visible in the in-game credits and notices.

## Contributing

Please keep changes deterministic, server-authoritative, and measurable. New simulation behaviour should include a pure Lua test; camera/input behaviour should include a focused C++ test. Do not add copyrighted assets or text from commercial city-building games.
