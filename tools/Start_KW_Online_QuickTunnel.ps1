param(
    [switch]$Rebuild
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root
$compose = "docker-compose.kw3d-lan.yml"

Write-Host "[KW] Starting 3D online stack..."
if ($Rebuild) {
    docker compose -f $compose up -d --build
} else {
    docker compose -f $compose up -d
}
if ($LASTEXITCODE -ne 0) { throw "KW online Docker stack failed." }

$network = (docker inspect kw_lan_portal --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}').Trim()
if ([string]::IsNullOrWhiteSpace($network)) { throw "Could not determine KW portal Docker network." }

$exists = $null -ne (docker ps -a --filter "name=^kw_cloudflared$" --format "{{.Names}}" | Select-Object -First 1)
$recreate = $true
if ($exists) {
    $command = (docker inspect kw_cloudflared --format '{{json .Config.Cmd}}')
    $networks = (docker inspect kw_cloudflared --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')
    if ($command -match 'kw_lan_portal:80' -and $networks -match [regex]::Escape($network)) {
        $recreate = $false
    }
}if ($recreate) {
    if ($exists) { docker rm -f kw_cloudflared | Out-Null }
    docker run -d --name kw_cloudflared --restart unless-stopped --network $network cloudflare/cloudflared:latest tunnel --no-autoupdate --url http://kw_lan_portal:80 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not start Cloudflare quick tunnel." }
} else {
    docker start kw_cloudflared 2>$null | Out-Null
}

$startedAt = (docker inspect kw_cloudflared --format '{{.State.StartedAt}}').Trim()
$publicBaseUrl = ""
for ($i = 0; $i -lt 60; $i++) {
    $logs = (& cmd.exe /d /s /c "docker logs --since $startedAt kw_cloudflared 2>&1") | Out-String
    $match = [regex]::Match($logs, 'https://[a-z0-9-]+\.trycloudflare\.com')
    if ($match.Success) {
        $publicBaseUrl = $match.Value
        break
    }
    Start-Sleep -Milliseconds 500
}
if ([string]::IsNullOrWhiteSpace($publicBaseUrl)) {
    throw "Cloudflare tunnel started but no public hostname was reported."
}
$wss = ($publicBaseUrl -replace '^https://','wss://') + "/game"
Write-Host "[KW] Active tunnel: $publicBaseUrl"
$projectPath = Join-Path $root "project.godot"
$project = Get-Content $projectPath -Raw
$project = [regex]::Replace($project, 'public_portal_url="[^"]*"', 'public_portal_url="' + $publicBaseUrl + '"')
$project = [regex]::Replace($project, 'public_ws_url="[^"]*"', 'public_ws_url="' + $wss + '"')
Set-Content $projectPath $project -Encoding UTF8 -NoNewline

$main = Get-Content (Join-Path $root "scripts/main.gd") -Raw
$versionMatch = [regex]::Match($main, 'CLIENT_VERSION := "([^"]+)"')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "dev" }
$config = [ordered]@{
    portal_url = $publicBaseUrl
    game_ws_url = $wss
    mode = "temporary_quick_tunnel"
    version = $version
    updated = (Get-Date).ToString("o")
}
$config | ConvertTo-Json | Set-Content (Join-Path $root "updates_site/kw/online_config.json") -Encoding UTF8

try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri ($publicBaseUrl + "/") -TimeoutSec 12
    if ($response.StatusCode -ne 200) { throw "Unexpected HTTP status $($response.StatusCode)" }
} catch {
    throw "Tunnel hostname was created but portal health-check failed: $($_.Exception.Message)"
}
Write-Host ""
Write-Host "KW ONLINE READY"
Write-Host "Portal: $publicBaseUrl"
Write-Host "Game:   $wss"
Write-Host "Docker network: $network"
Write-Host "The local 3D client reads updates_site/kw/online_config.json at connection time."
