param(
    [string]$ReleaseDir = "build/launcher_ubuntu",
    [Parameter(Mandatory = $true)]
    [string]$ManifestUrl,
    [string]$DefaultHost = "127.0.0.1",
    [int]$DefaultPort = 8080
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

$releasePath = Join-Path $projectRoot $ReleaseDir
if (Test-Path $releasePath) {
    Remove-Item -Recurse -Force $releasePath
}
New-Item -ItemType Directory -Path $releasePath | Out-Null

$sourceDir = Join-Path $projectRoot "launcher_ubuntu"
if (-not (Test-Path (Join-Path $sourceDir "kw_launcher.py"))) {
    throw "Missing launcher_ubuntu/kw_launcher.py"
}

Copy-Item (Join-Path $sourceDir "kw_launcher.py") (Join-Path $releasePath "kw_launcher.py") -Force
Copy-Item (Join-Path $sourceDir "run_launcher.sh") (Join-Path $releasePath "run_launcher.sh") -Force

$cfg = @{
    update_manifest_url = $ManifestUrl
    default_host = $DefaultHost
    default_port = $DefaultPort
}
$cfg | ConvertTo-Json | Set-Content -Path (Join-Path $releasePath "launcher_config.json") -Encoding UTF8

# 0.0.0 forces first-run update.
Set-Content -Path (Join-Path $releasePath "game_version.txt") -Value "0.0.0" -NoNewline

$readme = @"
KW Ubuntu Launcher
==================

Run:
  chmod +x run_launcher.sh
  ./run_launcher.sh

Requirements:
  - python3
  - python3-tk (for GUI window)
"@
Set-Content -Path (Join-Path $releasePath "README.txt") -Value $readme -Encoding UTF8

$zipPath = "$releasePath.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path (Join-Path $releasePath "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host ""
Write-Host "Ubuntu launcher package ready:"
Write-Host "Folder: $releasePath"
Write-Host "Zip:    $zipPath"
