param(
    [string]$PublicBaseUrl = "http://192.168.1.154:8082"
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root
$godot = "C:\Program Files (x86)\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $godot)) { throw "Godot 4.7.2 console executable not found." }
$main = Get-Content "scripts/main.gd" -Raw
$m = [regex]::Match($main, 'CLIENT_VERSION := "([^"]+)"')
if (-not $m.Success) { throw "CLIENT_VERSION not found." }
$version = $m.Groups[1].Value
Write-Host "[KW] Exporting $version..."
& $godot --headless --path $root --export-release "Windows Desktop" (Join-Path $root "build/kw.exe")
if ($LASTEXITCODE -ne 0) { throw "Godot export failed." }
$release = Join-Path $root "build/release"
New-Item -ItemType Directory -Force -Path $release | Out-Null
@{
  update_manifest_url = "$PublicBaseUrl/kw/update_manifest.json"
  auth_api_base_url = "http://192.168.1.154:8090"
  default_host = "192.168.1.154"
  default_port = 18886
} | ConvertTo-Json | Set-Content (Join-Path $release "launcher_config.json") -Encoding UTF8
& powershell -ExecutionPolicy Bypass -File (Join-Path $root "tools/publish_update.ps1") -Version $version -PublicBaseUrl $PublicBaseUrl
if ($LASTEXITCODE -ne 0) { throw "Publish update failed." }
Copy-Item "build/updater/KWUpdater.exe" "updates_site/kw/KWUpdater.exe" -Force
docker compose -f "docker-compose.kw3d-lan.yml" up -d
docker restart kw_3d_duel_server | Out-Null
Write-Host ""
Write-Host "KW LAN build published:"
Write-Host "Version: $version"
Write-Host "Portal:  $PublicBaseUrl/"
Write-Host "Server:  192.168.1.154:18886/UDP"
