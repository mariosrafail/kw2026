param(
    [string]$PublicBaseUrl = "https://justifier-exclusive-riches.ngrok-free.dev",
    [string]$PublicUdpHost = "85.74.190.165",
    [int]$PublicUdpPort = 18886,
    [string]$LanUdpHost = "192.168.1.154"
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

$uri = [Uri]$PublicBaseUrl
$wss = "wss://$($uri.Host)/game"

# Keep the exported client and web metadata aligned with the active public tunnel.
$project = Get-Content "project.godot" -Raw
$project = [regex]::Replace($project, 'public_portal_url="[^"]*"', 'public_portal_url="' + $PublicBaseUrl + '"')
$project = [regex]::Replace($project, 'public_ws_url="[^"]*"', 'public_ws_url="' + $wss + '"')
$project = [regex]::Replace($project, 'public_udp_host="[^"]*"', 'public_udp_host="' + $PublicUdpHost + '"')
$project = [regex]::Replace($project, 'public_udp_port=[0-9]+', 'public_udp_port=' + $PublicUdpPort)
$project = [regex]::Replace($project, 'public_lan_host="[^"]*"', 'public_lan_host="' + $LanUdpHost + '"')
Set-Content "project.godot" $project -Encoding UTF8 -NoNewline

@{
    portal_url = $PublicBaseUrl
    game_ws_url = $wss
    game_transport = "enet_udp"
    game_udp_host = $PublicUdpHost
    game_udp_port = $PublicUdpPort
    game_lan_host = $LanUdpHost
    mode = "direct_udp_gameplay"
    version = $version
    updated = (Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content "updates_site/kw/online_config.json" -Encoding UTF8

Write-Host "[KW] Ensuring Docker online stack is running..."
docker compose -f "docker-compose.kw3d-lan.yml" up -d --build
if ($LASTEXITCODE -ne 0) { throw "Docker stack failed." }

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
if ($LASTEXITCODE -ne 0) { throw "Update publishing failed." }

if (Test-Path "build/updater/KWUpdater.exe") {
    Copy-Item "build/updater/KWUpdater.exe" "updates_site/kw/KWUpdater.exe" -Force
}

docker restart kw_3d_duel_server | Out-Null
docker restart kw_3d_duel_ws | Out-Null

Write-Host ""
Write-Host "KW ONLINE PUBLISHED"
Write-Host "Version: $version"
Write-Host "Portal:  $PublicBaseUrl/"
Write-Host "Game:    $wss"
Write-Host "LAN:     192.168.1.154:18886"
