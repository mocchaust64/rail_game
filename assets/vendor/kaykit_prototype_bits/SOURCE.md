# KayKit Prototype Bits — bundled CC0 geometry derivatives

Author: Kay Lousberg / KayKit
Upstream repository: https://github.com/KayKit-Game-Assets/KayKit-Prototype-Bits-1.0
License: CC0 1.0 Universal
Accessed: 2026-09-08

## Bundled files

- `Pallet_Large_CC0_Derived.obj`
  - Source model: `Pallet_Large.obj`
  - Source URL: https://github.com/KayKit-Game-Assets/KayKit-Prototype-Bits-1.0/blob/main/addons/kaykit_prototype_bits/Assets/obj/Pallet_Large.obj
  - Geometry-only derivative reconstructed from the publicly visible CC0 source dimensions/topology. Materials/UVs intentionally removed; Flow Factory supplies its own material.

- `Barrel_A_CC0_Derived.obj`
  - Source model: `Barrel_A.obj`
  - Source URL: https://github.com/KayKit-Game-Assets/KayKit-Prototype-Bits-1.0/blob/main/addons/kaykit_prototype_bits/Assets/obj/Barrel_A.obj
  - Geometry-only low-poly re-author matching the public source's 12-sided proportions/silhouette. Materials/UVs intentionally removed; Flow Factory supplies its own material.

- `Pallet_Loaded_CC0_Derived.obj`
  - Composition derived from `Pallet_Large` plus simple cargo boxes for environmental dressing.

## Why derivatives instead of the upstream archive?

The build sandbox can inspect the public source/license pages but cannot fetch ZIP/binary files directly. To keep this repository clone-and-run, the needed geometry is bundled locally as audited CC0 derivatives rather than introducing a runtime download or undocumented dependency.

These models are environmental dressing only. Gameplay-critical visuals (cargo, junctions, receivers, buffer indicators) remain original Flow Factory assets so the product does not read as an asset flip.
