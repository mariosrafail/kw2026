param(
    [string]$ReleaseDir = "build/release",
    [string]$ManifestUrl = "",
    [string]$DefaultHost = "127.0.0.1",
    [int]$DefaultPort = 8080
)

$ErrorActionPreference = "Stop"

function Ensure-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Missing required file: $Path"
    }
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

$releasePath = Join-Path $projectRoot $ReleaseDir
if (Test-Path $releasePath) {
    Remove-Item -Recurse -Force $releasePath
}
New-Item -ItemType Directory -Path $releasePath | Out-Null

$launcherBuildOk = $false
try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_launcher.ps1")
    if ($LASTEXITCODE -eq 0) {
        $launcherBuildOk = $true
    }
} catch {
    Write-Host "Launcher build skipped: $($_.Exception.Message)"
}

$launcherOutput = Join-Path $projectRoot "build/launcher"
if ($launcherBuildOk -and (Test-Path $launcherOutput)) {
    Copy-Item -Path (Join-Path $launcherOutput "*") -Destination $releasePath -Recurse -Force
} elseif (Test-Path $launcherOutput) {
    Copy-Item -Path (Join-Path $launcherOutput "*") -Destination $releasePath -Recurse -Force
} else {
    Write-Host "Warning: launcher output not found. Release will only contain game files."
}

Ensure-File "build/kw.exe"
Ensure-File "build/kw.pck"
Copy-Item "build/kw.exe" (Join-Path $releasePath "kw.exe") -Force
Copy-Item "build/kw.pck" (Join-Path $releasePath "kw.pck") -Force

$mainScript = Get-Content "scripts/main.gd" -Raw
$versionMatch = [regex]::Match($mainScript, 'const CLIENT_VERSION := "([^"]+)"')
$gameVersion = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "0.0.0" }
Set-Content -Path (Join-Path $releasePath "game_version.txt") -Value $gameVersion -NoNewline

$launcherConfigPath = Join-Path $releasePath "launcher_config.json"
$cfg = @{
    update_manifest_url = $ManifestUrl
    default_host = $DefaultHost
    default_port = $DefaultPort
}
$cfg | ConvertTo-Json | Set-Content -Path $launcherConfigPath -Encoding UTF8

$zipPath = "$releasePath.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path (Join-Path $releasePath "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host ""
Write-Host "Release ready:"
Write-Host "Folder: $releasePath"
Write-Host "Zip:    $zipPath"
