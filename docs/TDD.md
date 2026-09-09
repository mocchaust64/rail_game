# Flow Factory — Technical Design Document V1.1

## Product goal

Prove one question before expanding scope: **is switching routes to resolve a moving stream of cargo easy to understand, satisfying, and deep enough to support a global mobile puzzle game?**

The MVP deliberately excludes ads, IAP, backend, login, economy and a full level editor. Service boundaries are kept small so those systems can be added later without coupling them to gameplay.

## Locked gameplay contract

1. Cargo moves automatically.
2. The only gameplay input is tapping a junction.
3. Every junction has exactly two distinct outputs.
4. A tap changes logical junction state immediately; the visual turn lasts ~145 ms.
5. One tap during the turn is retained; further taps collapse into that one queued toggle.
6. Route choice is committed when cargo reaches a node and starts the next segment. Later switch changes never redirect that cargo mid-segment.
7. Correct receiver -> cargo is delivered.
8. Wrong receiver -> cargo enters the waiting buffer.
9. Buffered cargo returns to its original source after the level-defined delay and gets first claim on a clear source slot.
10. If the buffer is already at capacity when another wrong item arrives -> immediate fail state.
11. Win requires the spawn queue, active cargo list and waiting buffer all to be empty.
12. Retry clears level runtime and rebuilds the level without restarting the app.
13. In multi-source levels, each source shows its own next pending cargo to preserve planning rather than reaction speed.

## Why routing is deterministic

Conveyor belts are presentation. Game logic is a directed graph:

- `source` / `normal`: one `next`
- `junction`: `out_a`, `out_b`, state 0/1
- `receiver`: terminal

Each cargo actor stores its committed `from_id`, `to_id`, interpolation progress, speed and original source. Physics bodies never decide routes.

This removes device-dependent collisions, track deadlocks and most timing race conditions.

## Runtime state machine

`BOOT -> LEVEL_LOADING -> PLAYING -> PAUSED | COMPLETED | FAILED`

Only `GameController` owns the game state.

## Cargo state

`SPAWNING -> TRAVELING -> DELIVERING | BUFFERING -> DEAD`

Buffered cargo is represented as deterministic data after its visual actor exits; a fresh actor is spawned when the buffer entry returns to the source.

## Data format

MVP levels are JSON and validated before use.

Key fields:

- `id`, `title`
- `item_speed`
- `spawn_interval`
- `buffer_capacity`
- `buffer_return_delay`
- `nodes[]`
- `spawns[]`

The validator checks IDs, node references, two distinct junction outputs, supported cargo kinds, receiver reachability and graph cycles.

## Fairness rules

- Returning buffered cargo is processed before new scheduled cargo each physics tick.
- A source cannot spawn while a recent item is still too close to its launch point.
- Upcoming global cargo is shown in the HUD.
- Each source also previews its next pending cargo.
- Difficulty comes from ordering and routing decisions, not sudden speed spikes.

## UX / readability

- portrait fixed orthographic camera
- no camera controls
- cargo uses shape + color coding
- active junction branch has a clear pointer
- first-time tutorial uses a pulsing switch cue
- receiver badges match cargo silhouettes
- waiting capacity is always visible
- wrong routing has explicit receiver rejection + buffer feedback

## Art direction

**Clean Toy Factory**: rounded low-detail 3D, muted board/environment, saturated gameplay pieces, simple materials, readable silhouettes, restrained effects.

All runtime art is bundled locally: gameplay-critical art is project-authored and a small set of audited CC0-derived environment props is included under `assets/vendor/`. There are no runtime network art dependencies. Any larger production-art expansion should wait until gameplay validation.

## Performance posture

- Compatibility renderer
- shared material cache
- deterministic lightweight mesh actors
- no physics-driven cargo
- no real-time reflections/volumetrics/heavy post-processing
- no external SDKs in the hot path

## Future gates — explicitly out of MVP

Only after the first device/player test passes:

1. 30–50 level content pass + editor tooling
2. real analytics adapter
3. marketability creative test
4. rewarded-ad adapter
5. IAP adapter
6. progression/economy
7. remote tuning/live operations
