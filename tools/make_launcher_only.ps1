param(
    [string]$ReleaseDir = "build/launcher_only",
    [Parameter(Mandatory = $true)]
    [string]$ManifestUrl,
    [string]$DefaultHost = "64.225.102.179",
    [int]$DefaultPort = 8080,
    [string]$AuthApiBaseUrl = "http://64.225.102.179/auth"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

$releasePath = Join-Path $projectRoot $ReleaseDir
if (Test-Path $releasePath) {
    Remove-Item -Recurse -Force $releasePath
}
New-Item -ItemType Directory -Path $releasePath | Out-Null

& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_launcher.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Launcher build failed."
}

$launcherOutput = Join-Path $projectRoot "build/launcher"
if (-not (Test-Path (Join-Path $launcherOutput "KwLauncher.exe"))) {
    throw "Missing launcher output: build/launcher/KwLauncher.exe"
}

Copy-Item (Join-Path $launcherOutput "KwLauncher.exe") (Join-Path $releasePath "KwLauncher.exe") -Force

$cfg = @{
    update_manifest_url = $ManifestUrl
    auth_api_base_url = $AuthApiBaseUrl
    default_host = $DefaultHost
    default_port = $DefaultPort
}
$cfg | ConvertTo-Json | Set-Content -Path (Join-Path $releasePath "launcher_config.json") -Encoding UTF8

# 0.0.0 forces first-run update.
Set-Content -Path (Join-Path $releasePath "game_version.txt") -Value "0.0.0" -NoNewline

$zipPath = "$releasePath.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path (Join-Path $releasePath "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host ""
Write-Host "Launcher-only package ready:"
Write-Host "Folder: $releasePath"
Write-Host "Zip:    $zipPath"
