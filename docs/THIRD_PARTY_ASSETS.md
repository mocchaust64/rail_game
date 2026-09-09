# Asset & License Manifest

## Bundled third-party / CC0-derived environment geometry

### KayKit — Prototype Bits 1.0

- Author: Kay Lousberg / KayKit
- Upstream repository: https://github.com/KayKit-Game-Assets/KayKit-Prototype-Bits-1.0
- License: Creative Commons Zero (CC0 1.0 Universal)
- Commercial use: allowed
- Attribution: not required, included here as a courtesy
- Accessed: 2026-09-08

Bundled files:

- `assets/vendor/kaykit_prototype_bits/Pallet_Large_CC0_Derived.obj`
- `assets/vendor/kaykit_prototype_bits/Barrel_A_CC0_Derived.obj`
- `assets/vendor/kaykit_prototype_bits/Pallet_Loaded_CC0_Derived.obj`
- `assets/vendor/kaykit_prototype_bits/LICENSE.txt`
- `assets/vendor/kaykit_prototype_bits/SOURCE.md`

The authoring sandbox could inspect the public GitHub source/license but could not fetch ZIP/binary archives directly. The bundled OBJ files are therefore geometry-only audited derivatives/re-exports reconstructed from the public CC0 source geometry/proportions, with UV/material data intentionally removed. Flow Factory supplies its own materials so the environment stays visually coherent and mobile-lightweight.

These models are used **only for environmental dressing** (pallets/barrels/cargo stacks). Gameplay-critical visual language remains original to this project:

- cargo silhouettes
- junction/switch design
- receivers and their badges
- waiting buffer
- source machines
- gameplay feedback/VFX

This prevents the MVP from reading as an asset flip while still benefiting from proven low-poly CC0 environment design.

## Project-authored assets

- Gameplay/environment framework: Godot meshes/materials authored for Flow Factory
- UI icons/shapes: custom procedural drawing
- SFX/ambience: original generated audio in `assets/audio/`
- Branding: original icon/splash in `assets/branding/`

## Approved future art source

### Kenney — Factory Kit 3.0

- Source: https://kenney.nl/assets/factory-kit
- Publisher lists 140 files/models
- License: Creative Commons CC0

Kenney remains an approved option if the product survives first-player validation and a larger environment pass becomes justified. It is **not required** by this MVP and no runtime download is performed.

## Integration rule

Never import a complete pack blindly. Curate a small subset, normalize scale/materials, retain source/license provenance, and preserve Flow Factory's own visual language for anything the player touches or must read quickly.
