$ErrorActionPreference = "Stop"
$Root = (Resolve-Path "$PSScriptRoot\..").Path
python "$Root\scripts\verify_project.py"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }
try { & $Godot --version | Out-Null } catch {
  Write-Host "Godot not found. Set `$env:GODOT_BIN to your Godot 4.7.2 executable." -ForegroundColor Yellow
  exit 2
}

& $Godot --headless --path $Root --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Godot --headless --path $Root --quit-after 5
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$SceneChecks = @(
  "res://tests/prop_clearance_check.tscn",
  "res://tests/track_geometry_check.tscn",
  "res://tests/track_visuals_check.tscn",
  "res://tests/camera_frame_check.tscn",
  "res://tests/tap_radius_check.tscn",
  "res://tests/save_recovery_check.tscn",
  "res://tests/analytics_check.tscn",
  "res://tests/audio_check.tscn",
  "res://tests/item_pool_check.tscn",
  "res://tests/localisation_check.tscn",
  "res://tests/accessibility_check.tscn",
  "res://tests/screen_shake_check.tscn",
  "res://tests/particles_check.tscn",
  "res://tests/palette_check.tscn"
)

foreach ($Scene in $SceneChecks) {
  & $Godot --headless --path $Root $Scene
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& $Godot --headless --path $Root res://tests/game_flow_check.tscn
exit $LASTEXITCODE
