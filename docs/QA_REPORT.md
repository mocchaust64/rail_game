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

## NOT VERIFIED — requires Godot/device runtime

The authoring container still has no Godot executable or Android SDK. Therefore the following are **not claimed as passed**:

- Godot 4.7.2 GDScript parser/import
- Godot OBJ import of bundled vendor geometry
- actual in-engine 3D render inspection
- final scale/occlusion of CC0 props in the live camera
- real touch hit-testing on Android
- viewport/safe-area behavior across physical phones
- audio/haptic device behavior
- APK/AAB export
- real frame-time/thermal profiling

These are release blockers for anything beyond an MVP test. Run `scripts/run_godot_check.*` first on a machine with Godot 4.7.2, then play all 10 levels on a physical Android device.

## Product QA rule

Do **not** add ads, IAP, economy, backend, live events or dozens of extra levels before first-player validation. The v0.3 art pass is intentionally strong enough to judge the real tactile/visual appeal, while remaining small enough to kill or redesign the mechanic without sunk-cost pressure.
