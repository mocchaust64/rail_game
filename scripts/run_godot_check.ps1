$ErrorActionPreference = "Stop"
$Root = (Resolve-Path "$PSScriptRoot\..").Path
python "$Root\scripts\verify_project.py"
$Godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }
try { & $Godot --version | Out-Null } catch {
  Write-Host "Godot not found. Set `$env:GODOT_BIN to your Godot 4.7.2 executable." -ForegroundColor Yellow
  exit 2
}
& $Godot --headless --path $Root --editor --quit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Godot --headless --path $Root --quit-after 5
exit $LASTEXITCODE
