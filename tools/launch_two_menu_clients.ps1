param(
    [string]$GodotPath = "godot",
    [string]$ProjectPath = ".",
    [string]$MainScene = "res://scenes/ui/main_menu.tscn"
)

$ErrorActionPreference = "Stop"

$projectFullPath = (Resolve-Path $ProjectPath).Path

Start-Process -FilePath $GodotPath -WorkingDirectory $projectFullPath -ArgumentList @(
    "--path", $projectFullPath,
    $MainScene,
    "--auth-profile=client1"
)

Start-Sleep -Milliseconds 400

Start-Process -FilePath $GodotPath -WorkingDirectory $projectFullPath -ArgumentList @(
    "--path", $projectFullPath,
    $MainScene,
    "--auth-profile=client2"
)
