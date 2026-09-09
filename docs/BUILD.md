# Build & Verification

## Engine pin

Use **Godot 4.7.2 stable**. The project is intentionally pinned for MVP validation; do not move the branch to a 4.8 development build during the test phase.

## Desktop editor run

Open `project.godot` and run the project. Mouse clicks emulate touch.

## Automated source/data checks

```bash
python3 scripts/verify_project.py
python3 -m unittest -v tests/test_levels.py
python3 tests/simulate_route_contract.py
```

## Godot parser/startup check

When a Godot 4.7.2 binary is available:

```bash
GODOT_BIN=/path/to/godot ./scripts/run_godot_check.sh
```

or on Windows:

```powershell
$env:GODOT_BIN="C:\\path\\to\\Godot_v4.7.2-stable_win64.exe"
.\\scripts\\run_godot_check.ps1
```

The scripts run the source verifier first, then Godot headless editor import/parser and a short startup smoke test.

## Android

An Android export preset is included at `export_presets.cfg`.

For a real device build:

1. Install Godot 4.7.2 export templates.
2. Configure Android SDK in Godot Editor Settings.
3. Use **JDK 17**.
4. Open Project > Export > Android.
5. Export a debug APK first and test on a physical portrait phone.
6. Before external release, replace the MVP package ID and configure a proper release keystore.

Target package in this MVP preset: `com.flowfactory.mvp`.

## Device acceptance check

Before adding production features, verify on at least one mid-range Android phone:

- stable portrait layout / no important UI hidden by safe areas
- touch selects only the intended nearby junction
- pause/resume after switching apps
- haptics can be disabled
- audio can be disabled and stays saved
- 10-level run without script/runtime errors
- no visible cargo state desynchronization
- acceptable thermals and stable frame pacing

## Packaging-environment limitation

The container used to author this package does not include a Godot executable or Android SDK, and outbound binary download was unavailable. Therefore engine parsing/rendering and APK export could not be truthfully executed here. Source/data verification was executed; engine/device verification remains the first mandatory test on a machine with Godot installed.
