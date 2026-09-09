# Changelog

## Unreleased — reference-video visual pass

Composition

- warm full-bleed play surface replaces the floating white prototype board
- closer perspective camera auto-frames each level from gameplay anchors
- receiver rows are aligned on levels 3–8 and 10 while spawn order/topology stay unchanged
- source preview is now a physical three-slot feeder lane instead of a floating icon

Track presentation

- `gameplay/track_geometry.gd` builds deterministic sampled Bézier paths from the existing graph
- `gameplay/track_visuals.gd` renders those curves with MultiMesh layers so curved belts do not explode node count on mobile
- cargo samples the same arc-length path the renderer draws, so it cannot cut across a visual curve
- junction arrows use the outgoing curve tangent rather than pointing directly at the receiver

Art and HUD

- glossy ball cargo and saturated red/blue/yellow destination machines replace the muted CC0 gameplay pieces
- compact mechanical junctions, warmer palette, metal rails, dark rubber belts and corner scenery move the look toward the supplied reference video
- HUD chrome is stripped back: loose upcoming balls, circular sand-coloured buffer sockets, smaller top controls and icon-only tutorial cue

Feel

- cargo rolls along the current curve tangent
- spawn uses a short toy-like squash/pop; receiver delivery reads as the ball being swallowed rather than evaporating upward

Checks

- added `tests/track_geometry_check.tscn` for endpoints, Y-split tangents, arc-length sampling and straight fallback
- standard Godot QA now runs the track geometry check
- source verifier requires the shared track geometry/renderer files so they cannot be removed as apparent dead code

## 0.3.2

Art is data

- colours moved out of visual_factory.gd into `assets/palette/toy_factory.tres`,
  so the look can be changed without touching code
- CC0 gameplay models for cargo and source machines, with the packs' texture
  atlases; gameplay surfaces had no texture at all before

Structure

- `game/scene_rig.gd` owns camera, lights, environment and shake
- `game/level_builder.gd` owns reading, validating and building a level
- game_controller.gd drops from 635 to 509 lines and no longer touches either

Feel

- trauma-based screen shake, a short hitstop on impact, particle bursts on
  delivery and rejection, and music ducking

Reach

- English and Vietnamese translations, no hardcoded user-facing text
- reduced motion, large text and a slower line as saved settings

Robustness

- save keeps a validated backup and recovers from a corrupt file
- analytics appends instead of rewriting its whole history every eight events
- pooled audio voices on SFX and Music buses
- pooled cargo nodes

Checks

- twelve automated checks, up from three; the state machine is covered for the
  first time, which is what made the split safe

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
