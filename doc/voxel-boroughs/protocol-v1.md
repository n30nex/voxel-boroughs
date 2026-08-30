# UI protocol v1

Channel: `voxel_boroughs:ui:v1`

The trusted client bridge submits intent. The server owns permissions, geometry, annexation, prices, simulation state, ordering, and all resulting mutations.

Client command:

```json
{"v":1,"id":"17","action":"build","args":{"tool":"road","cx":2,"cz":-1}}
```

- `v` must be exactly `1`.
- `id` is a non-empty client correlation string up to 64 bytes.
- `action` is a string up to 32 bytes.
- `args` must be an object when present.
- Messages over 8 KiB are discarded; commands are rate-limited per sender.

Implemented actions are `hello`, `status`, `build`, `speed`, and `save`. `speed` and `save` require the Luanti `server` privilege. All actions require `interact`.

Server reply:

```json
{"v":1,"seq":42,"type":"delta","target":"","payload":{"delta_type":"day","day":12}}
```

- `seq` is monotonically increasing for the server process. Clients discard duplicate or older replies.
- `type` is `snapshot`, `delta`, `ack`, or `error`.
- `target` is empty for broadcast replies or a player name for a private logical reply. Mod channels broadcast physically, so clients must filter this field.
- `payload` contains the type-specific body and a deterministic `state_hash` on state-bearing messages.

Malformed, unauthorised, unaffordable, out-of-district, occupied, and rate-limited commands do not mutate state.

