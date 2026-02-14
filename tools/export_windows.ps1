param(
    [string]$Preset = "Windows Desktop",
    [string]$Output = "build/kw.exe"
)

$ErrorActionPreference = "Stop"

function Find-GodotExecutable {
    $commandCandidates = @("godot", "godot4", "godot.exe", "godot4.exe")
    foreach ($name in $commandCandidates) {
        try {
            $cmd = Get-Command $name -ErrorAction Stop
            if ($cmd -and (Test-Path $cmd.Source)) {
                return $cmd.Source
            }
        } catch {
        }
    }

    $pathCandidates = @(
        $env:GODOT_EXE,
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.3-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
        "$env:ProgramFiles\Godot\Godot_v4.3-stable_win64.exe",
        "$env:ProgramFiles\Godot\Godot.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.3-stable_win64.exe",
        "$env:USERPROFILE\Desktop\Godot_v4.3-stable_win64.exe"
    )

    foreach ($candidate in $pathCandidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

if (-not (Test-Path "export_presets.cfg")) {
    throw "Missing export_presets.cfg in '$projectRoot'."
}

$godotExe = Find-GodotExecutable
if (-not $godotExe) {
    throw "Godot executable not found. Set GODOT_EXE env var to your Godot .exe path."
}

$outputDir = Split-Path -Parent $Output
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Host "Using Godot: $godotExe"
Write-Host "Export preset: $Preset"
Write-Host "Output: $Output"

& $godotExe --headless --path $projectRoot --export-release $Preset $Output
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Export completed."
