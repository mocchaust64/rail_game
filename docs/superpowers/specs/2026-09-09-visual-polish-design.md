# Flow Factory — Visual Polish Pass (v0.3.1)

Date: 2026-09-09
Status: approved
Scope: rendering, lighting, materials, prop placement, camera, HUD/UI

## Problem

`docs/QA_REPORT.md` lists two items as never verified:

- actual in-engine 3D render inspection
- final scale/occlusion of CC0 props in the live camera

Both are now confirmed broken by running the app. The build also failed to
launch at all until four Variant-inference parse errors were fixed in
`item_actor.gd`, `cargo_icon.gd`, `visual_factory.gd` and
`level_validator.gd`. With the app running, the render reads as unfinished
for six distinct reasons, listed below with root causes.

## Non-goals

- No Blender, no new meshes, no remodelling of gameplay actors. The gameplay
  shapes are procedural primitives and that is correct for the "clean toy
  factory" art direction. Modelling is not what makes the render look bad.
- No new runtime dependencies, plugins, or downloaded assets. The MVP's
  "no external runtime asset downloads" property is preserved.
- No gameplay/ruleset changes. The routing contract in `docs/TDD.md` is
  untouched.

## Design

### 1. Renderer

`project.godot` moves `renderer/rendering_method` and
`renderer/rendering_method.mobile` from `gl_compatibility` to `mobile`.

Rationale: Compatibility caps the achievable lighting quality. Mobile
provides real-time soft directional shadows and glow while remaining a
mobile-class pipeline, which matters because `export_presets.cfg` targets
Android.

Accepted limitation: the Mobile renderer has no SSAO, SSIL, SDFGI, or
volumetric fog. Contact darkening therefore comes from the shadow map, not
from a screen-space effect.

Risk: older or low-end Android GPUs may lose frames. Untestable here; must be
measured on a physical device before release. Recorded in QA_REPORT.

### 2. Lighting and environment

File: `game/game_controller.gd`, scene setup (currently lines 52-76).

- Background changes from a flat `BG_COLOR` to a procedural sky, so ambient
  light acquires vertical falloff instead of lighting every surface equally.
- Ambient energy drops from `0.82` to approximately `0.42`. At the current
  value the ambient term washes out any shadow the key light casts.
- Key light gains soft shadows, with `shadow_bias` and `shadow_normal_bias`
  tuned to the scene scale. The board is roughly 9.2 by 14.1 units, so the
  defaults, which assume a larger world, produce acne or peter-panning.
- A low-energy warm bounce light is added from the front-lower quadrant to
  keep shadowed faces from reading as flat grey.
- Filmic tonemapping is kept. Mild glow is enabled for the emissive accents
  already present on junction hints and receiver caps.

Calibration note: shadow bias and light angle are physical-feel values. They
are left as named constants at the top of the setup function so they can be
retuned without re-deriving the whole lighting rig.

### 3. Materials and palette

File: `gameplay/visual_factory.gd`.

The floor inset is `#EAF1F4` and the machine body is `#F7F9FB`. That is about
a three percent luminance difference, so machines visually merge into the
floor regardless of lighting.

- Floor and board colors move darker and warmer to create separation under
  the near-white machines.
- The shared `material()` factory gains a rim term. Rim lighting is cheap on
  the Mobile renderer and recovers silhouette definition that the absent SSAO
  would otherwise have provided.
- The three cargo colors (`RED`, `BLUE`, `YELLOW`) are unchanged. They are
  gameplay-critical, already distinguishable by both hue and shape, and
  changing them would invalidate the colorblind-safety property claimed in
  the README.

### 4. Prop placement

File: `gameplay/visual_factory.gd`, decoration block (currently lines 286-345).

Root cause: prop positions are hardcoded global constants, for example the
loaded pallet at `Vector3(3.66, -0.12, 5.42)`, while receiver and source
positions come from per-level data in `levels/`.

Measured, not estimated: the regression check counts 125 clearance violations
across all ten levels, not the single level this section originally named. Both
right-side barrels overlap a receiver on every level; the visible white mass
next to the yellow receiver is one of them. The first version of the check
reported only 3 violations because it matched props by node name, and Godot
discards duplicate node names on `add_child`, so seven of the eight vendor
props were invisible to it.

Fix: the decoration step accepts the level's occupied XZ points and skips any
prop whose centre falls within 1.8 world units of one. That radius is derived
from the geometry: the receiver body is a 1.55-unit box, giving a 0.775 half
extent, plus roughly 0.5 for the largest prop half extent, plus margin. It is
declared as a named constant so it can be retuned. This is a single guard in the
shared decoration function rather than per-prop special cases, so it holds for
all ten levels and for any level added later.

Prop tint is additionally muted so the dressing reads as background.

### 5. Camera

File: `game/game_controller.gd` (currently lines 44-50).

The camera moves from orthographic to a mild perspective projection, field of
view approximately 30 degrees.

This turned out to be **required, not cosmetic**. Directional shadows do not
render at all with an orthographic camera in this Godot build. Shadows were
enabled in code and every light setting verified correct at runtime, yet no
shadow appeared under either the Mobile or the Forward+ renderer; they appear
immediately when the projection becomes perspective. So section 2 depends on
this section, and the two cannot be shipped separately.

Required companion change: junction hit-testing at `game_controller.gd:456`
compares against a fixed `TAP_RADIUS_PX` of 118. Under orthographic projection
every junction projects at the same scale, so one radius is correct. Under
perspective, distant junctions shrink on screen while the hit radius would
not, making far junctions feel oversized to tap and near ones undersized. The
radius is therefore scaled per junction by measuring the on-screen size of a
fixed world-space offset.

Without this companion change the camera switch would silently degrade input
accuracy, which is why the two are specified as one unit of work.

### 6. HUD and UI

File: `ui/hud.gd`.

Three separate defects.

**No font asset.** `assets/` contains branding and audio only. Every label
renders in Godot's built-in default face. This is the most visible
unprofessional signal in the UI. Fix: a `SystemFont` resource with a bold
weight and an ordered family fallback. This adds no files, keeps the
no-external-assets property, and resolves to Roboto on Android and to the
system UI face on desktop.

**Insufficient contrast.** HUD panels are near-white with alpha, for example
`#F7FAFCEB`, sitting on a near-white 3D scene. The HUD does not separate from
the world. Fix: darker panel fills and real elevation shadows.

**No safe-area handling.** Nothing in the project reads
`DisplayServer.get_display_safe_area()`, and HUD elements use hardcoded pixel
offsets such as `position = Vector2(-236, 108)` at `hud.gd:205`. On a notched
device the top row collides with the cutout. Fix: inset the top and bottom
regions by the reported safe area, and replace hardcoded positions with anchor
offsets so the layout survives varying aspect ratios.

## Verification

Every item must pass before the work is called done.

1. `godot --headless --path . --quit-after 30` produces no ERROR or
   SCRIPT ERROR lines.
2. `python3 scripts/verify_project.py` passes.
3. `python3 -m unittest tests/test_levels.py` passes.
4. `python3 tests/simulate_route_contract.py` passes.
5. A new prop-clearance check asserts that no decoration prop is placed within
   1.8 world units of any receiver or source, across all ten levels. This is
   the automated guard for defect 4, which no existing test covers. It is
   written before the fix and must fail first.
6. A tap-radius check asserting the tolerance converts correctly per junction.
7. Before and after screenshots of the running app at the same level, captured
   from the real window, showing the change.

Items 1 through 6 are automated. Item 7 is the human judgement gate.

Not verifiable here: synthesised clicks do not reach the Godot window on this
machine, so no interaction can be driven from outside the app. Tap behaviour is
covered by the arithmetic check instead of an end-to-end tap.

## Deviations from this spec during implementation

- The clearance filter stayed in `visual_factory.gd` instead of moving to its
  own `prop_placement.gd`. It is ten lines used in one place; a separate file
  would have been structure without a reader.
- `levels/prop_layout.json` was not created. It existed only so a Python mirror
  test could read the layout, and the check that was actually written measures
  the real scene the engine builds, which is stronger. The layout stayed in
  GDScript as a named constant.
- A sky-based ambient source was specified and then reverted. It blew the render
  out to white; a colour ambient with the energy dropped achieves the intended
  separation without that risk.

## Open risk

Frame rate on low-end Android after the renderer change is unmeasured and
unmeasurable in this environment. It must be checked on a physical device
before shipping. The renderer change and the perspective camera both add cost.
