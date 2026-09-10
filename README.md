# Smash MVP — Godot 4.7.2

Playable MVP source for a colorful 3D casual physics puzzle.

## Core loop
- Balls and material blocks are pre-stacked on a tray.
- Materials: Wood / Stone / Ice.
- Ammo: Wood / Stone / Fire + Wild.
- Tap a block with the matching ammo.
- Break the right support and let Godot physics collapse the structure.
- Blocks that hit the ground break into debris and disappear.
- Balls that hit the ground disappear and count toward level completion.
- Clear every ball before ammo runs out.

## Run locally
1. Install Godot 4.7.2 stable.
2. Open `project.godot`.
3. Run the project.
4. Mouse input emulates touch.

## Web preview CI
Pushes to branch `smash-mvp` run `.github/workflows/smash-web.yml`.
The workflow parses the project, exports the single-threaded Web build, and publishes generated files to branch `smash-web`.

## MVP visual strategy
Gameplay uses replaceable primitive meshes first. Swap them for properly licensed low-poly assets without rewriting gameplay logic. Keep one shared toy-like material/lighting direction so third-party geometry still feels like one game.

See `ASSET_SOURCES.md` for the asset sourcing shortlist.
