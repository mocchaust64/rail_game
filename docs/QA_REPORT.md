# QA Report — Flow Factory MVP v0.3.0

## PASS — executed in authoring container

### Package integrity

- required project, gameplay, UI, service, branding and audio files present
- bundled CC0 vendor geometry and provenance files present
- no temporary backup source directories in the release tree
- static `res://` preload/load paths resolve
- icon/splash PNG files bundled
- nine SFX/ambience WAV files bundled

### CC0 art integration

- `Pallet_Large_CC0_Derived.obj` passes geometry sanity thresholds
- `Barrel_A_CC0_Derived.obj` passes geometry sanity thresholds
- `Pallet_Loaded_CC0_Derived.obj` passes geometry sanity thresholds
- license manifest contains CC0/KayKit provenance
- source manifest records upstream repository and per-model source URLs
- imported geometry is environment-only; gameplay-critical models remain project-authored
- all vendor meshes use Flow Factory material overrides to keep palette/style coherent

### Level/data validation

- exactly 10 level JSON files
- sequential unique level IDs
- no duplicate/missing graph node IDs
- all graph references resolve
- graphs terminate; no cycles in MVP route graphs
- every spawn kind can reach a matching receiver from its source
- all three cargo shape/color types introduced by level 3
- speed/spawn timing stays inside the deliberately non-reflex MVP guardrails
- buffer capacities pass MVP constraints

### Gameplay-contract mirror tests

- committed-route behavior tested in deterministic Python mirror
- one-deep queued switch-toggle behavior tested
- six automated level-contract tests pass

### UX/code hardening included

- each source previews its next pending cargo in multi-source levels
- global upcoming queue shows next four scheduled cargo items
- source-clearance guard prevents immediate visual cargo stacking
- buffered returns are processed before new spawns for fairness
- runtime level validator checks two distinct junction outputs
- debug level navigation is hidden outside debug builds

## VERIFIED in v0.3.1 on a desktop Godot runtime

Run on Godot 4.7.stable.mono on macOS, Apple M2, Metal, Forward Mobile:

- GDScript parse and import: clean, after fixing four Variant-inference errors
  that previously stopped the project from loading
- OBJ import of the bundled vendor geometry
- in-engine 3D render inspection, by screenshot of the running window
- scale and occlusion of the CC0 props in the live camera: props no longer
  overlap receivers or sources, asserted across all ten levels by
  `tests/prop_clearance_check.gd`
- HUD layout at two aspect ratios, by screenshot

## Reference-video visual branch — source-reviewed, engine verification pending

Branch: `ui/reference-video-pass`

Implemented on this branch:

- warm full-bleed ground and saturated toy palette
- closer camera with per-level graph auto-framing
- shared sampled Bézier edge paths used by both conveyor rendering and cargo movement
- MultiMesh conveyor layers to keep curve smoothness from multiplying scene-node count
- curved-junction pointer tangents
- physical source feeder lane with next-cargo slot
- glossy ball cargo with a small shape glyph retained as a non-colour cue
- level JSON coordinates remain identical to `main`; composition is improved by camera framing and curved presentation paths instead of moving gameplay nodes
- low-chrome HUD with loose upcoming balls and circular waiting-buffer sockets
- `tests/track_geometry_check.tscn` added to the standard Godot check

Source-level review guarantees intentionally preserved:

- level topology, node positions, receiver kinds and spawn order are unchanged
- committed routing still happens by graph node, not by physical collision
- pending junction toggle remains one deep
- buffer rules, return ordering, win/fail conditions and game-state transitions are unchanged
- cargo path endpoint is still the graph node position; curves are presentation between endpoints

Not yet verified for this branch:

- Godot 4.7.2 parse/import of the newly added `TrackGeometry` / `TrackVisuals` scripts
- actual MultiMesh transforms/materials in the Mobile renderer
- all ten levels visually after auto-framing
- touch target feel with the smaller junction art
- frame time on an Android device after the curved-track MultiMesh pass
- safe-area composition with the new minimal HUD on a physical notched phone

Do not merge this visual branch solely from source review. First run
`scripts/run_godot_check.*`, then capture levels 1, 3, 7 and 10 on the same phone
or viewport used for the supplied reference comparison. Those four levels cover
the single split, three-way cascade, dual source and final dual-source layouts.

## NOT VERIFIED — requires a device or a different runtime

- Godot 4.7.2 specifically. The runtime used was 4.7.stable.mono, not the
  pinned 4.7.2 patch release.
- real touch hit-testing on Android. Synthesised clicks do not reach the Godot
  window on the verification machine, so no tap could be driven from outside
  the app. The tap tolerance arithmetic is covered by
  `tests/tap_radius_check.tscn` instead.
- safe-area behaviour on a physical notched phone. The inset code is exercised
  on desktop, where the correct answer is zero, so only the zero case is proven.
- frame rate after the renderer and camera changes. Both the move to the Mobile
  renderer and the perspective camera add cost, and neither was profiled on
  target hardware. This is the largest open risk in the release.
- audio/haptic device behavior
- APK/AAB export
- real frame-time/thermal profiling

These are release blockers for anything beyond an MVP test. Run `scripts/run_godot_check.*` first on a machine with Godot 4.7.2, then play all 10 levels on a physical Android device.

## Product QA rule

Do **not** add ads, IAP, economy, backend, live events or dozens of extra levels before first-player validation. The v0.3 art pass is intentionally strong enough to judge the real tactile/visual appeal, while remaining small enough to kill or redesign the mechanic without sunk-cost pressure.

## v0.3.2 known gaps

- The cargo and buffer rules still live in game_controller.gd. The scene rig and
  level building were extracted because they have clean boundaries; routing,
  buffering and delivery share too much state with the state machine to split
  without a redesign, and a bad split there is worse than none.
- On main/v0.3.2, cargo silhouettes are weaker from directly above than the old
  primitives. The reference-video branch replaces those CC0 gameplay pieces
  with glossy balls plus small white shape glyphs, which mitigates the colour-only
  regression in source design; this still needs visual verification at phone scale.

## Render comparison

`docs/render_before_v030.png` and `docs/render_after_v031.png` are the same
level captured from the running window before and after the v0.3.1 pass.
