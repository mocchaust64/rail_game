# Flow Factory — Sorter Economy Vertical Slice

A portrait mobile routing puzzle built with **Godot 4.7.2 stable**.

This branch is intentionally a small, polished vertical slice. It proves the new core loop before the campaign is expanded.

## Core loop

1. **READ** the cargo colours, machines, guide rails and build foundations.
2. **BUILD** a sorter by spending gold.
3. **CONFIGURE** red, blue and yellow across the sorter's three exits.
4. **OPTIMIZE** the network instead of building every available site.
5. Press **RUN**. Setup locks and cargo moves automatically.
6. Win by routing every cargo to the matching machine; stars reward lower spend.

The game is designed to reward planning, not reaction speed.

## Current vertical slice

- **Level 1 — BUILD ONE SORTER:** teaches construction only; the initial lane mapping is already correct.
- **Level 2 — MATCH THE COLORS:** teaches three-lane colour configuration.
- **Level 3 — SPEND SMART:** introduces unnecessary foundations and asks the player to find the cheapest valid network.

`python3 scripts/verify_project.py` exhaustively checks the build/configuration search space for Levels 1–3 and verifies the declared optimal cost.

## Browser preview — no local Godot install

The recommended tester workflow is the GitHub Pages preview.

Every push to `gameplay/sorter-economy-vertical-slice` runs `.github/workflows/web-preview.yml`, which:

1. runs the source-level solver/validator;
2. downloads the pinned official Godot 4.7.2 editor and export templates on the GitHub runner;
3. verifies their SHA-256 checksums;
4. runs the Godot headless test suite;
5. exports the `Web Preview` preset;
6. validates the generated HTML/JS/WASM/PCK bundle;
7. uploads a downloadable build artifact;
8. deploys the same build to GitHub Pages.

The Web preset deliberately disables browser threading so the preview works on normal GitHub Pages without special COOP/COEP response headers. The custom HTML shell keeps the game in a centered **9:16 portrait stage** on desktop and mobile browsers.

### One-time GitHub Pages setting

If Pages has never been enabled for the repository:

`Repository Settings → Pages → Build and deployment → Source → GitHub Actions`

After that, future pushes redeploy automatically. No Godot installation is required on the tester's computer.

See `docs/WEB_PREVIEW.md` for troubleshooting and deployment details.

## Local verification (optional)

If a developer does have Godot installed:

### Windows PowerShell

```powershell
$env:GODOT_BIN="C:\\path\\to\\Godot_v4.7.2-stable_win64.exe"
.\\scripts\\run_godot_check.ps1
```

### macOS / Linux

```bash
GODOT_BIN=/path/to/godot ./scripts/run_godot_check.sh
```

## Product contract

- Gameplay-critical visuals are custom and vendor-free.
- Possible routes are pale guide rails.
- Building a sorter reveals continuous dark active belts.
- Each sorter exposes exactly three colour-assigned exits.
- Setup cannot change after RUN starts.
- Difficulty comes from topology, decoys and budget efficiency, not increasing cargo speed.

The detailed source of truth is `docs/SORTER_ECONOMY_GAMEPLAY.md`.
