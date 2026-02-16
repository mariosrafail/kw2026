param(
    [string]$Preset = "Windows Desktop",
    [string]$Output = "build/kw.exe",
    [string]$GodotExe = ""
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
        "$env:ProgramFiles\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe",
        "$env:ProgramFiles\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64_console.exe",
        "$env:ProgramFiles\Godot_v4.4-stable_win64.exe\Godot_v4.4-stable_win64.exe",
        "$env:ProgramFiles\Godot_v4.4-stable_win64.exe\Godot_v4.4-stable_win64_console.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.3-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.3-stable_win64_console.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.4-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.4-stable_win64_console.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
        "$env:ProgramFiles\Godot\Godot_v4.3-stable_win64.exe",
        "$env:ProgramFiles\Godot\Godot.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.3-stable_win64.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.3-stable_win64_console.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.4-stable_win64.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.4-stable_win64_console.exe",
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

$godotExe = if (-not [string]::IsNullOrWhiteSpace($GodotExe)) { $GodotExe } else { Find-GodotExecutable }
if (-not $godotExe) {
    throw "Godot executable not found. Set GODOT_EXE env var to your Godot .exe path."
}
if (-not (Test-Path $godotExe)) {
    throw "Provided Godot executable not found: $godotExe"
}

$outputDir = Split-Path -Parent $Output
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Output "[export] Using Godot: $godotExe"
Write-Output "[export] Preset: $Preset"
Write-Output "[export] Output: $Output"
Write-Output "[export] Starting..."

& $godotExe --headless --verbose --path $projectRoot --export-release $Preset $Output
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Output "[export] Completed."
