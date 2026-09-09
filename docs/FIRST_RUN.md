# First Run — Tester Checklist

## Fastest path

1. Install Godot 4.7.2 stable.
2. Extract/clone the repository.
3. Open `project.godot`.
4. Run the project.
5. Play all 10 levels before changing code or tuning values.

No asset pack, plugin, font, ad SDK or backend is required. The first Godot import will also import the bundled CC0 OBJ environment geometry; this is local and does not access the network.

## What should happen

- The game launches directly into the highest unlocked level.
- Level 1 highlights the first switch and asks for one tap.
- Cargo automatically moves from source machines.
- A source visibly previews its next cargo; this matters on two-source levels.
- Tapping a switch changes its outgoing direction.
- Correct cargo is accepted by the matching receiver.
- Wrong cargo moves to the waiting buffer, then returns to the same source.
- Overflowing a full buffer fails the level.
- Clearing every pending, moving and buffered cargo completes the level.

## Fast debug navigation

In an editor/debug build:

1. Press Pause.
2. Use `DEBUG PREV LEVEL` / `DEBUG NEXT LEVEL`.

These buttons are hidden in non-debug builds.

## Stop and report if you see

- a red parser/script error in Godot Output
- cargo teleporting to a different branch after it already entered one
- a cargo item stuck forever
- a level completing while cargo is still visible/in buffer
- restart leaving old cargo/tweens behind
- a source showing the wrong next-cargo preview
- touch/click selecting a switch far away from the pointer

When reporting, include: Godot version, OS/device, level number, and the full first error from the Output panel. If an OBJ import fails, also include the exact path under `assets/vendor/kaykit_prototype_bits/`.
