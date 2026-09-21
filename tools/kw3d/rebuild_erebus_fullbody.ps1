param([string]$Godot = "")
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
if (-not $Godot) {
    $Godot = "C:\Program Files (x86)\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) { throw "Pass -Godot with the installed Godot executable path." }
python (Join-Path $PSScriptRoot "build_erebus_fullbody_source.py")
if ($LASTEXITCODE -ne 0) { throw "Erebus source generation failed." }
python (Join-Path $PSScriptRoot "prepare_erebus_fullbody.py")
if ($LASTEXITCODE -ne 0) { throw "Erebus source validation failed." }
& $Godot --headless --path $Root --script res://tools/kw3d/bake_erebus_fullbody.gd
if ($LASTEXITCODE -ne 0) { throw "Erebus model bake failed." }
Write-Output "Ready: scenes/prototypes/characters/erebus_fullbody.tscn"
