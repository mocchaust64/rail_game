# Visual Polish Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take Flow Factory from a flat, washed-out render with props clipping through
gameplay actors to a production-presentable mobile look, without adding meshes,
dependencies or downloaded assets.

**Architecture:** Six independent changes over five existing files plus two new files.
The only change carrying real logic is prop clearance, which becomes a pure static
filter in its own file with data in JSON, mirrored by a Python test in the style the
project already uses for the routing contract. Everything else is configuration of the
renderer, lights, materials, camera and HUD, gated on screenshots of the running app.

**Tech Stack:** Godot 4.7 (GDScript, Mobile renderer), Python 3 for the mirror tests.

**Source spec:** `docs/superpowers/specs/2026-09-09-visual-polish-design.md`

---

## Preconditions and deviations

**This directory is not a git repository.** Every "commit" step in the standard task
shape is therefore replaced by a verification checkpoint. This is a real risk: there is
no rollback if a task goes wrong. Before starting, either run `git init` and make a
baseline commit, or accept that recovery means re-editing by hand.

**Plan detail level.** Code is given in full for the clearance filter, its data file and
its test, because that is the logic worth specifying precisely. The lighting, material,
camera and HUD tasks specify exact files, exact symbols, exact target values and exact
verification, but not every line of styling code, because those are tuned against the
screenshot gate rather than derived on paper.

---

## File structure

| File | Status | Responsibility |
|---|---|---|
| `levels/prop_layout.json` | create | Decoration layout as data: mesh kind, position, rotation, scale |
| `gameplay/prop_placement.gd` | create | Pure static clearance filter. No scene knowledge. |
| `tests/test_prop_clearance.py` | create | Python mirror asserting clearance across all ten levels |
| `gameplay/visual_factory.gd` | modify | Consume the filter; palette and rim material |
| `game/game_controller.gd` | modify | Renderer-side lighting, environment, camera, tap radius |
| `ui/hud.gd` | modify | Font, contrast, safe area, anchor-based layout |
| `project.godot` | modify | Renderer selection |
| `scripts/verify_project.py` | modify | Require the new data file |
| `CHANGELOG.md`, `docs/QA_REPORT.md` | modify | Record what changed and what is still unverified |

`gameplay/visual_factory.gd` is already 394 lines. Prop clearance goes in a new file
rather than growing it further.

---

## Task 1: Prop clearance filter

Root cause being fixed: prop positions are hardcoded globals while receiver and source
positions come from per-level JSON, so level 3 places a receiver on top of a pallet.

**Files:**
- Create: `levels/prop_layout.json`
- Create: `gameplay/prop_placement.gd`
- Create: `tests/test_prop_clearance.py`

- [ ] **Step 1: Extract the current layout to data**

Transcribe the existing hardcoded props from `gameplay/visual_factory.gd:294-345` into
`levels/prop_layout.json`. Positions are `[x, y, z]` in world units and must match the
current source exactly, so that this step alone changes nothing on screen.

```json
{
  "clearance_radius": 1.8,
  "props": [
    {"mesh": "loaded_pallet", "pos": [-3.65, -0.12, -5.42], "rot_y": 0.12,  "scale": 0.215},
    {"mesh": "loaded_pallet", "pos": [3.66,  -0.12, 5.42],  "rot_y": 3.2216, "scale": 0.195},
    {"mesh": "pallet",        "pos": [3.72,  -0.12, -5.48], "rot_y": -0.08, "scale": 0.205},
    {"mesh": "pallet",        "pos": [-3.72, -0.12, 5.48],  "rot_y": 3.2416, "scale": 0.205},
    {"mesh": "barrel",        "pos": [-3.78, 0.33, -4.35],  "rot_y": 0.0,   "scale": 0.82},
    {"mesh": "barrel",        "pos": [-3.18, 0.33, -4.55],  "rot_y": 0.0,   "scale": 0.82},
    {"mesh": "barrel",        "pos": [3.75,  0.33, 4.22],   "rot_y": 0.0,   "scale": 0.82},
    {"mesh": "barrel",        "pos": [3.18,  0.33, 4.47],   "rot_y": 0.0,   "scale": 0.82}
  ]
}
```

`rot_y` values 3.2216 and 3.2416 are `PI + 0.08` and `PI + 0.10` evaluated, matching
the source they replace.

- [ ] **Step 2: Write the failing test**

Create `tests/test_prop_clearance.py`. It mirrors the GDScript filter in Python, the
same way `tests/simulate_route_contract.py` already mirrors the routing contract.

```python
import json
import math
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
LEVELS = ROOT / "levels"
LAYOUT = LEVELS / "prop_layout.json"
BLOCKING_TYPES = {"receiver", "source"}


def load_layout():
    return json.loads(LAYOUT.read_text())


def load_levels():
    return [json.loads(p.read_text()) for p in sorted(LEVELS.glob("level_*.json"))]


def occupied_points(level):
    return [
        (n["pos"][0], n["pos"][1])
        for n in level["nodes"]
        if n["type"] in BLOCKING_TYPES
    ]


def surviving_props(layout, occupied):
    radius = layout["clearance_radius"]
    kept = []
    for prop in layout["props"]:
        x, _y, z = prop["pos"]
        if any(math.hypot(x - ox, z - oz) < radius for ox, oz in occupied):
            continue
        kept.append(prop)
    return kept


class PropClearanceTests(unittest.TestCase):
    def test_no_prop_overlaps_a_gameplay_actor_on_any_level(self):
        layout = load_layout()
        radius = layout["clearance_radius"]
        for level in load_levels():
            occupied = occupied_points(level)
            for prop in surviving_props(layout, occupied):
                x, _y, z = prop["pos"]
                for ox, oz in occupied:
                    self.assertGreaterEqual(
                        math.hypot(x - ox, z - oz),
                        radius,
                        "level %d: %s at %s overlaps actor at (%s, %s)"
                        % (level["id"], prop["mesh"], prop["pos"], ox, oz),
                    )

    def test_at_least_one_level_actually_drops_a_prop(self):
        # Guards against the filter silently becoming a no-op.
        layout = load_layout()
        dropped = [
            len(layout["props"]) - len(surviving_props(layout, occupied_points(level)))
            for level in load_levels()
        ]
        self.assertGreater(sum(dropped), 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the test and watch it fail**

Run: `python3 -m unittest tests.test_prop_clearance -v`

Expected on a first run: failure, because `levels/prop_layout.json` does not exist yet
if step 1 was skipped, or because `test_at_least_one_level_actually_drops_a_prop` proves
the overlap exists in the shipped data. Do not proceed until a failure is observed and
understood. A passing first run means the test is not measuring anything.

- [ ] **Step 4: Write the GDScript filter**

Create `gameplay/prop_placement.gd`. It is pure: no scene access, no node creation.

```gdscript
class_name PropPlacement
extends RefCounted

const LAYOUT_PATH := "res://levels/prop_layout.json"

static func load_layout() -> Dictionary:
    var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
    if file == null:
        push_error("prop layout missing: %s" % LAYOUT_PATH)
        return {"clearance_radius": 0.0, "props": []}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("prop layout is not a JSON object")
        return {"clearance_radius": 0.0, "props": []}
    return parsed as Dictionary

# Returns the props that clear every occupied point by at least radius.
# occupied is an Array of Vector2 in world XZ.
static func filter_props(props: Array, occupied: Array, radius: float) -> Array:
    var kept: Array = []
    for entry in props:
        var prop := entry as Dictionary
        var pos: Array = prop["pos"]
        var flat := Vector2(float(pos[0]), float(pos[2]))
        var blocked := false
        for point in occupied:
            if flat.distance_to(point as Vector2) < radius:
                blocked = true
                break
        if not blocked:
            kept.append(prop)
    return kept
```

- [ ] **Step 5: Run the test and watch it pass**

Run: `python3 -m unittest tests.test_prop_clearance -v`
Expected: both tests PASS.

- [ ] **Step 6: Checkpoint**

Run the full existing suite so this task did not break anything:

```bash
python3 scripts/verify_project.py
python3 -m unittest tests.test_levels -v
python3 tests/simulate_route_contract.py
```

---

## Task 2: Wire the filter into decoration

**Files:**
- Modify: `gameplay/visual_factory.gd:286-345`
- Modify: `scripts/verify_project.py`

- [ ] **Step 1: Change the decoration signature**

The decoration function currently takes only `parent`. It must also receive the level's
occupied XZ points, so that it can filter. Find its caller in
`game/game_controller.gd` and pass the receiver and source positions already parsed from
level JSON. Do not recompute them from the scene tree.

- [ ] **Step 2: Replace the hardcoded prop blocks**

Delete the three hardcoded blocks (loaded pallets, bare pallets, barrels) and build them
from `PropPlacement.load_layout()` filtered through `PropPlacement.filter_props()`. Map
the `mesh` string to the existing `KAYKIT_LOADED_PALLET`, `KAYKIT_PALLET` and
`KAYKIT_BARREL` preloads. Keep the custom tanks and safety barriers as they are; they sit
at the board edge and are not implicated.

- [ ] **Step 3: Register the data file**

Add `levels/prop_layout.json` to the required-files list in `scripts/verify_project.py`
so a missing layout fails fast instead of silently producing an undecorated scene.

- [ ] **Step 4: Verify in the running app**

Launch the app, reach level 3, screenshot. The white mass overlapping the yellow
receiver must be gone. This is the defect that motivated the task, so this is the check
that matters.

- [ ] **Step 5: Checkpoint**

`godot --headless --path . --quit-after 30` must print no ERROR or SCRIPT ERROR lines.

---

## Task 3: Renderer

**Files:**
- Modify: `project.godot:49-51`

- [ ] **Step 1: Switch the renderer**

Set both `renderer/rendering_method` and `renderer/rendering_method.mobile` to `mobile`.
Leave `anti_aliasing/quality/msaa_3d` at its current value for now; MSAA is retuned in
Task 5 once the lighting is settled.

- [ ] **Step 2: Verify the app still launches**

Launch and screenshot. Expect the scene to look different and possibly worse at this
point, because the lighting is still tuned for Compatibility. That is expected; do not
tune lights here.

- [ ] **Step 3: Checkpoint**

Headless run clean.

---

## Task 4: Lighting and environment

**Files:**
- Modify: `game/game_controller.gd:52-76`

- [ ] **Step 1: Hoist the tuning values**

Introduce named constants at the top of the setup for key light energy, key light
euler angles, ambient energy, shadow bias and shadow normal bias. These are physical-feel
values that will need retuning on a device; they must not stay buried as literals.

- [ ] **Step 2: Replace the flat background with a sky**

Change `Environment.background_mode` from `BG_COLOR` to `BG_SKY` with a
`ProceduralSkyMaterial`, and set `ambient_light_source` to the sky. This gives ambient a
vertical gradient instead of one flat value on every surface.

- [ ] **Step 3: Rebalance key light against ambient**

Drop ambient energy from `0.82` toward `0.42` and raise key light energy to compensate.
Enable soft shadows on the key light. Tune `shadow_bias` and `shadow_normal_bias` to the
board scale, roughly 9.2 by 14.1 units; engine defaults assume a larger world and will
produce either acne or floating shadows here.

- [ ] **Step 4: Add the bounce light**

Add a low-energy warm light from the front-lower quadrant, shadows disabled, so shadowed
faces do not read as flat grey.

- [ ] **Step 5: Remove the fake cargo shadow**

`gameplay/item_actor.gd:37-47` builds a flat grey cylinder as a stand-in shadow. With
real shadows it double-draws and reads wrong. Delete it and let the shadow map handle
cargo. Confirm on screen that cargo still reads as grounded.

- [ ] **Step 6: Verify**

Screenshot. Shadows must be visible under belts, machines and cargo. Compare against the
before screenshot.

---

## Task 5: Materials and palette

**Files:**
- Modify: `gameplay/visual_factory.gd:4-16` and `gameplay/visual_factory.gd:24`
- Modify: `project.godot:51`

- [ ] **Step 1: Separate floor from machines**

`FLOOR_COLOR` is `#DDE8EC`, the floor inset is `#EAF1F4`, `MACHINE_BODY` is `#F7F9FB`.
Darken and warm the floor and inset so the near-white machines have something to sit
against. Do not touch `RED`, `BLUE` or `YELLOW`: they are gameplay-critical and the
README claims colour-plus-shape distinguishability.

- [ ] **Step 2: Add rim to the shared material**

Extend the `material()` factory with a rim term and include it in the cache key so
variants do not collide. Rim is cheap on the Mobile renderer and recovers the silhouette
definition that the absent SSAO would otherwise provide.

- [ ] **Step 3: Retune MSAA**

With lighting settled, set `anti_aliasing/quality/msaa_3d` to 2x. The scene is built from
hard-edged primitives, so edge quality is visible, but 4x is not worth the mobile cost.

- [ ] **Step 4: Verify**

Screenshot and compare.

---

## Task 6: Camera and tap radius

These ship together. Changing the projection without changing the hit test silently
degrades input on distant junctions.

**Files:**
- Modify: `game/game_controller.gd:44-50` and `game/game_controller.gd:453-460`

- [ ] **Step 1: Switch to mild perspective**

Replace `PROJECTION_ORTHOGONAL` with a perspective camera at roughly 30 degrees field of
view, repositioned so the board fills the same portion of the frame as before. Verify the
whole board is still visible on the tallest and shortest supported aspect ratios.

- [ ] **Step 2: Scale the tap radius per junction**

`TAP_RADIUS_PX` is a fixed 118 pixels at `game_controller.gd:7`, correct only under
orthographic projection where every junction projects at the same scale. Measure each
junction's on-screen scale by unprojecting a second point at a fixed world offset from
the junction, then scale the radius by the ratio to a reference scale.

- [ ] **Step 3: Verify near and far junctions both respond**

Launch level 3, which has junctions at differing depths. Tap the nearest and the farthest
junction. Read `[analytics] junction_tap` lines from the app log and confirm both
junction ids appear. A missing id means the hit radius collapsed at that depth.

This end-to-end check replaces a unit test here deliberately: the arithmetic is a single
scale factor, and what can actually break is the projection wiring, which only a real tap
exercises.

---

## Task 7: HUD

**Files:**
- Modify: `ui/hud.gd`

- [ ] **Step 1: Give the UI a real typeface**

`assets/` contains branding and audio only, so every label currently renders in Godot's
built-in default face. Build one `SystemFont` with a bold weight and an ordered family
fallback, and apply it at the theme level rather than per control. This adds no files and
resolves to Roboto on Android and the system UI face on desktop.

- [ ] **Step 2: Raise HUD contrast**

Panel fills such as `#F7FAFCEB` are near-white on a near-white 3D scene. Darken the fills
and give the panels real elevation shadows via the existing `_panel_style` helper at
`ui/hud.gd:415`, so the HUD sits above the world rather than dissolving into it.

- [ ] **Step 3: Honour the display safe area**

Nothing in the project reads `DisplayServer.get_display_safe_area()`. Inset the top and
bottom HUD regions by the reported safe area so the top row clears a notch. On desktop
the safe area equals the window, so this is a no-op there and must be confirmed as such.

- [ ] **Step 4: Replace hardcoded pixel positions with anchors**

Positions such as `position = Vector2(-236, 108)` at `ui/hud.gd:205` assume one viewport
size. Convert the NEXT panel, the tutorial banner and the overlay to anchor presets with
offsets so the layout survives varying aspect ratios.

- [ ] **Step 5: Verify at two aspect ratios**

Screenshot at the default window size and at a tall narrow size. No clipping, no
overlap, no element off screen.

---

## Task 8: Record and final verification

**Files:**
- Modify: `CHANGELOG.md`, `docs/QA_REPORT.md`

- [ ] **Step 1: Add a 0.3.1 changelog entry**

Record the four parse-error fixes that made the build launch at all, and the six changes
from this plan.

- [ ] **Step 2: Update the QA report**

`docs/QA_REPORT.md:57-58` lists "actual in-engine 3D render inspection" and "final
scale/occlusion of CC0 props in the live camera" as unverified. Both are now verified;
move them. Add the new unverified item: frame rate on low-end Android after the renderer
change, which cannot be measured in this environment.

- [ ] **Step 3: Full verification run**

```bash
godot --headless --path . --quit-after 30
python3 scripts/verify_project.py
python3 -m unittest tests.test_levels tests.test_prop_clearance -v
python3 tests/simulate_route_contract.py
```

All must pass with no ERROR or SCRIPT ERROR lines.

- [ ] **Step 4: Before and after screenshots**

Capture the same level from the running app and present both. This is the gate the whole
plan exists to pass.
