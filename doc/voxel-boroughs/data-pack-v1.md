# Data-pack schema v1

Data packs are declarative content only. A pack may contain JSON metadata, Luanti `.mts` schematics, PNG textures, and OGG/WAV sounds. Executable Lua is rejected.

Each directory contains a `pack.json` conforming to `games/voxel_boroughs/data_packs/schema-v1.json`. Pack and content IDs are immutable, lowercase namespaced identifiers. Duplicate IDs fail the pack load. Renames use an alias from an old ID to a current ID.

Schema v1 can declare buildings, policies, services, and challenges. The pre-alpha loader validates and indexes this metadata; subsequent milestones connect every declared content class to gameplay. A stable third-party Lua API is intentionally deferred until after 1.0.

