# Changelog

## 0.3.1

Build fixes

- fixed four parse errors that stopped the project from launching at all:
  `:=` inferring a type from a Variant value, which Godot 4.4 and later treat
  as an error, in `item_actor.gd`, `cargo_icon.gd`, `visual_factory.gd` and
  `level_validator.gd`

Render

- moved from the Compatibility renderer to Mobile
- switched the camera from orthographic to a 30 degree perspective; directional
  shadows do not render under an orthographic camera in this engine build, so
  this is what makes shadows work rather than only adding depth
- rebuilt the lighting rig behind named constants: ambient dropped from 0.82 to
  0.55, key light raised, soft shadows enabled, warm bounce light added
- darkened the floor so the near-white machines separate from it
- removed the hand-drawn shadow disc under cargo, real shadows replace it

Decoration

- fixed decoration props clipping through receivers and sources on all ten
  levels, 125 clearance violations before the fix
- moved the prop layout into the outer side lanes and back corners, bands that
  clear every actor position on every level
- props are now filtered against the level's own actor positions at build time,
  so a future level drops a prop instead of clipping through it

Interface

- the HUD now uses the platform UI typeface instead of Godot's built-in default
- panels separate from the light 3D scene by elevation rather than fill
- the HUD respects the display safe area, so the top row clears a notch

Input

- junction tap tolerance is defined in board units and converted per junction;
  a fixed pixel radius was only correct under the orthographic camera

Checks

- added `tests/prop_clearance_check.gd` and `tests/tap_radius_check.tscn` to
  the standard Godot check

## 0.3.0-mvp

- integrated curated CC0 low-poly environment geometry derived/re-exported from KayKit Prototype Bits public source
- added pallets, loaded pallets and faceted factory barrels around non-interactive board edges
- unified all vendor geometry under Flow Factory materials/palette to avoid asset-pack mismatch
- retained original gameplay-critical models for cargo, switches, receivers, sources and buffer
- added per-file source/license provenance under `assets/vendor/kaykit_prototype_bits/`
- added vendor asset preview and stricter vendor-asset verification
- no runtime asset downloads; clone/extract remains self-contained

## 0.2.0-mvp

- production-like self-contained Clean Toy Factory visual pass
- original icon/splash and bundled SFX/ambience
- 10 validated levels
- deterministic graph routing and committed branch decisions
- recoverable waiting buffer with fairness ordering
- source-clearance spawning guard
- per-source next cargo previews for multi-source planning
- global next-four cargo preview
- pause/settings/debug level navigation
- versioned local save and local analytics abstraction
- stricter level validator and source/data verification scripts
- Android export preset included for downstream device testing
