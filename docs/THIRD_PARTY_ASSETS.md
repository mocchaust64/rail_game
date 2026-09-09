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

## v0.3.2 — CC0 gameplay geometry

Gameplay pieces are no longer procedural primitives only. The following models
ship in the repository and are used for cargo and source machines.

| File | Pack | Author | Licence | Used for |
|---|---|---|---|---|
| `kaykit_prototype_bits/gltf/Barrel_A.gltf` | KayKit Prototype Bits 1.0 | Kay Lousberg | CC0 1.0 | red cargo |
| `kaykit_prototype_bits/gltf/Coin_A.gltf` | KayKit Prototype Bits 1.0 | Kay Lousberg | CC0 1.0 | yellow cargo |
| `kaykit_space_base_bits/gltf/containers_C.gltf` | KayKit Space Base Bits 1.0 | Kay Lousberg | CC0 1.0 | blue cargo |
| `kaykit_space_base_bits/gltf/basemodule_A.gltf` | KayKit Space Base Bits 1.0 | Kay Lousberg | CC0 1.0 | source machine |
| `*_texture.png` | both packs | Kay Lousberg | CC0 1.0 | shared texture atlas per pack |

Source: https://github.com/KayKit-Game-Assets — full pack licences are kept
alongside the models. CC0 requires no attribution; it is recorded here anyway so
provenance stays auditable.

### Why receivers are still custom geometry

Each cargo colour has to be unmistakable, and every candidate receiver model
carries its own baked colours. Tinting multiplies rather than replaces, so a
blue model tinted yellow renders green. The three cargo models above were picked
because their own atlas colours already are the gameplay colours, which is why
they need no tint. No candidate could do the same job for a receiver that must
be able to read as any of the three, so the receiver body stays procedural.
