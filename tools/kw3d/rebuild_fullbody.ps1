param([string]$Godot = "")
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
if (-not $Godot) {
    $Godot = "C:\Program Files (x86)\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) { throw "Pass -Godot with the installed Godot executable path." }
python (Join-Path $PSScriptRoot "prepare_fullbody.py")
if ($LASTEXITCODE -ne 0) { throw "Source validation failed." }
& $Godot --headless --path $Root --script res://tools/kw3d/bake_fullbody.gd
if ($LASTEXITCODE -ne 0) { throw "Model bake failed." }
& $Godot --headless --path $Root --script res://tools/kw3d/bake_editor_preview.gd -- --kw-qa
if ($LASTEXITCODE -ne 0) { throw "Preview bake failed." }
Write-Output "Ready: scenes/prototypes/kw_3d_prototype.tscn (F6)"
