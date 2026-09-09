# Flow Factory MVP — v0.3.0

A self-contained, portrait mobile routing puzzle MVP for **Godot 4.7.2 stable**.

## What you can test immediately

- 10 handcrafted levels
- 3 cargo types identified by **color + shape**
- automatic cargo movement on deterministic routes
- tap-only two-way junction switching
- committed routing: cargo already entering a branch never changes direction mid-segment
- one-deep queued tap while a switch is animating
- limited waiting buffer, recoverable mistakes, and buffer-overflow failure
- buffered cargo returns to its original source so close saves are possible
- global NEXT queue plus a physical next-cargo preview above each source
- first-level no-text tutorial cue
- pause / resume / restart / next level
- local progression save, sound and haptic settings
- local analytics log abstraction
- original bundled SFX + ambience
- original icon + splash screen
- **bundled CC0 low-poly environment geometry** from audited KayKit Prototype Bits source derivatives
- custom Clean Toy Factory materials, gameplay models, effects and UI
- no external runtime asset downloads or plugins required

## Art strategy

The environment now mixes curated CC0 geometry (pallets/barrels/cargo dressing) with original Flow Factory gameplay art. Imported geometry is recolored with the same project materials so the scene feels like one product instead of several unrelated asset packs.

Gameplay-critical assets remain custom: cargo, junctions, receivers, source machines, buffer and feedback. See `docs/THIRD_PARTY_ASSETS.md` for per-source provenance and license details, and `docs/vendor_asset_preview.png` for the bundled CC0 geometry preview.

## Core loop

Cargo moves automatically. Tap a glowing junction to choose which branch the next cargo takes. Match each shape/color to its receiver. Wrong cargo enters the waiting buffer and returns after a short delay. If another wrong cargo arrives while the buffer is full, the level fails.

## Run in Godot

1. Install **Godot 4.7.2 stable**.
2. Open/import `project.godot` from this folder.
3. Press **F6/F5 / Run Project**.
4. Desktop mouse clicks emulate mobile touch.
5. Pause the game in a debug build to reveal **DEBUG PREV/NEXT LEVEL** buttons for fast testing.

For stricter verification, run:

### Windows PowerShell

```powershell
$env:GODOT_BIN="C:\\path\\to\\Godot_v4.7.2-stable_win64.exe"
.\\scripts\\run_godot_check.ps1
```

### macOS / Linux

```bash
GODOT_BIN=/path/to/godot ./scripts/run_godot_check.sh
```

See:

- `docs/FIRST_RUN.md` — fastest tester workflow
- `docs/TDD.md` — locked gameplay/technical contract
- `docs/BUILD.md` — desktop + Android notes
- `docs/QA_REPORT.md` — exactly what has and has not been verified
- `docs/THIRD_PARTY_ASSETS.md` — bundled asset provenance/license manifest

## Scope discipline

This MVP intentionally does **not** contain ads, IAP, login, backend, economy, live events or a full level editor. Those systems do not help answer the current product question: **is routing a moving stream by switching junctions easy to understand, satisfying and deep enough to justify production?**
