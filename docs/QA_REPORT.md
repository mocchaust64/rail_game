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
- Cargo silhouettes are weaker from directly above than they were. The previous
  primitives read as circle, square and triangle from the top; the CC0 barrel
  and coin both read as circles, so the three kinds now lean more on colour.
  Colour plus the drum cluster still separates them, but this is a regression in
  the shape channel and matters for a colourblind player.

## Render comparison

`docs/render_before_v030.png` and `docs/render_after_v031.png` are the same
level captured from the running window before and after the v0.3.1 pass.
