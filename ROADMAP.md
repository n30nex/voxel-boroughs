# Voxel Boroughs roadmap

This roadmap turns the full design into testable, reviewable releases. It is not a promise that unfinished features already exist.

## M0 — Foundation (current branch)

- Branded Windows/Linux executable and user-data locations.
- Bundled `voxel_boroughs` game and trusted UI protocol bridge.
- Deterministic build metadata, license boundaries, upstream tracking, and Pi guardrails.

## M1 — Playable district slice (`v0.1.0-alpha.1` gate)

- Free-orbit cursor camera, build bar, inspector, demand/budget HUD, and scalable formspec dashboard.
- One 32×32-cell annexed district with roads, power, water, low-density R/C/I, procedural growth, sampled traffic, and save/reload.
- Pure Lua, C++, headless integration, Windows x64, Linux x86_64, and internal ARM64 gates.

## M2 — City depth

- Density tiers, mixed-use, offices, land value, redevelopment, abandonment, loans, trade, approval, policies, and advisors.
- Fire, police, health, education, parks, sewage, waste, pollution, and environmental systems.
- Terrain tools, expanded procedural building kits, overlays, charts, accessibility, and migration fixtures.

## M3 — Mega-city and release depth

- Curves, diagonals, slopes, bridges, tunnels, highways, bus, tram, metro, passenger/freight rail, walking, and cycling.
- Time-sliced transport/service graphs, dormant-district summaries, 512×512 active-cell benchmark, and million-resident fixtures.
- Challenges, optional disasters, localization-ready strings, performance tuning, and a complete solo release.

Co-op remains post-solo-release. The protocol stays server-authoritative so it does not preclude later co-op work.

