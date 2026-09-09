# Changelog

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
