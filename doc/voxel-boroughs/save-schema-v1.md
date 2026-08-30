# Save schema v1

The first public alpha freezes schema version `1`.

State is stored in Luanti ModStorage as compressed, base64-encoded JSON:

- `generation:<n>:district:<dx,dz>`: one district shard with immutable cell coordinates, content kind, growth stage, and build/growth days.
- `generation:<n>:manifest`: global finance/time state, annexed district IDs, per-shard checksums, deterministic state hash, and the previous generation.
- `active_generation`: the only commit pointer.

Save order is shards, manifest, read-back verification, then `active_generation`. A crash before the final write leaves the previous generation active. Loading validates schema, shard checksums, and the reconstructed state hash; if validation fails, it tries up to two prior generations.

Derived population, jobs, service capacity, and demand are recalculated after load. Runtime objects such as sampled vehicles and HUD IDs are never persisted.

Ordered migrations will be added as `v1 → v2 → …` functions. Saves newer than the executable must fail closed rather than being partially interpreted. Immutable content IDs and explicit alias tables are required before an ID can be renamed.

