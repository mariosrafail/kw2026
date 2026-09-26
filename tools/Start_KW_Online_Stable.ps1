$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root
$compose = "docker-compose.kw3d-lan.yml"
$stableDomain = "justifier-exclusive-riches.ngrok-free.dev"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$ngrok = (Get-Command ngrok -ErrorAction SilentlyContinue).Source
if (-not $ngrok) {
    $ngrok = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter ngrok.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ngrok -or -not (Test-Path $ngrok)) { throw "ngrok is not installed." }

$config = Join-Path $env:LOCALAPPDATA "ngrok\ngrok.yml"
if (-not (Test-Path $config)) {
    throw "NGROK_AUTH_REQUIRED: open https://dashboard.ngrok.com/get-started/your-authtoken and run the shown 'ngrok config add-authtoken ...' command once."
}

Write-Host "[KW] Waiting for Docker..."
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    $dockerDesktop = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktop) {
        Write-Host "[KW] Starting Docker Desktop..."
        Start-Process -FilePath $dockerDesktop | Out-Null
    }
}
$dockerReady = $false
for ($i=0; $i -lt 60; $i++) {
    & docker info *> $null
    if ($LASTEXITCODE -eq 0) { $dockerReady = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $dockerReady) { throw "Docker did not become ready within two minutes." }

Write-Host "[KW] Starting Docker authority + portal..."
docker compose -f $compose up -d
if ($LASTEXITCODE -ne 0) { throw "KW Docker stack failed." }

# Direct ENet/UDP gameplay path. ngrok remains only for updater/config files.
$udpPort = 18886
$udpMapper = Join-Path $root "tools\kw3d\ensure_udp_mapping.py"
$python = (Get-Command python -ErrorAction Stop).Source
try {
    & $python $udpMapper
    if ($LASTEXITCODE -ne 0) { throw "UDP mapper exited with code $LASTEXITCODE" }
} catch {
    Write-Warning "Could not create direct UDP mapping: $($_.Exception.Message)"
}
$udpCfgPath = Join-Path $root "updates_site\kw\online_config.json"
$udpCfg = Get-Content $udpCfgPath -Raw | ConvertFrom-Json
$publicIp = [string]$udpCfg.game_udp_host
$lanIp = [string]$udpCfg.game_lan_host
if ([string]::IsNullOrWhiteSpace($publicIp)) { $publicIp = "85.74.190.165" }
if ([string]::IsNullOrWhiteSpace($lanIp)) { $lanIp = "192.168.1.154" }

# The router grants a 24-hour lease. Renew it every 6 hours while this PC is logged in.
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*ensure_udp_mapping.py*--watch*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Process -FilePath $python -ArgumentList @($udpMapper,"--watch","21600") -WindowStyle Hidden | Out-Null
Write-Host ("[KW] Direct gameplay: UDP {0}:{1} -> {2}:{1}" -f $publicIp,$udpPort,$lanIp)

Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force
$logDir = Join-Path $root "tmp\kw3d\ngrok"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logPath = Join-Path $logDir "ngrok.log"
Remove-Item $logPath -Force -ErrorAction SilentlyContinue
Write-Host "[KW] Starting stable ngrok endpoint..."
$proc = Start-Process -FilePath $ngrok -ArgumentList @("http","8082","--domain=$stableDomain","--log=$logPath","--log-format=json") -WindowStyle Hidden -PassThru

$publicBaseUrl = ""
for ($i=0; $i -lt 60; $i++) {
    try {
        $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2
        $candidate = $tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1
        if ($candidate -and $candidate.public_url) {
            $publicBaseUrl = [string]$candidate.public_url
            break
        }
    } catch {}
    if ($proc.HasExited) {
        $details = if (Test-Path $logPath) { Get-Content $logPath -Raw } else { "" }
        throw "ngrok exited before creating an endpoint. $details"
    }
    Start-Sleep -Milliseconds 500
}
if ([string]::IsNullOrWhiteSpace($publicBaseUrl)) { throw "ngrok endpoint did not become ready." }
$expectedBaseUrl = "https://$stableDomain"
if ($publicBaseUrl.TrimEnd("/") -ne $expectedBaseUrl) {
    throw "ngrok returned unexpected endpoint '$publicBaseUrl'; expected '$expectedBaseUrl'."
}
$wss = "wss://$stableDomain/game"
Write-Host "[KW] Stable public endpoint: $publicBaseUrl"
$projectPath = Join-Path $root "project.godot"
$project = [System.IO.File]::ReadAllText($projectPath,[System.Text.Encoding]::UTF8)
$project = [regex]::Replace($project,'public_portal_url="[^"]*"','public_portal_url="' + $publicBaseUrl + '"')
$project = [regex]::Replace($project,'public_ws_url="[^"]*"','public_ws_url="' + $wss + '"')
$project = [regex]::Replace($project,'public_udp_host="[^"]*"','public_udp_host="' + $publicIp + '"')
$project = [regex]::Replace($project,'public_udp_port=[0-9]+','public_udp_port=' + $udpPort)
$project = [regex]::Replace($project,'public_lan_host="[^"]*"','public_lan_host="' + $lanIp + '"')
[System.IO.File]::WriteAllText($projectPath, $project, $utf8NoBom)

$versionText = Get-Content (Join-Path $root "scripts\main.gd") -Raw
$versionMatch = [regex]::Match($versionText,'CLIENT_VERSION := "([^"]+)"')
$version = if($versionMatch.Success){$versionMatch.Groups[1].Value}else{"dev"}
$onlineJson = [ordered]@{
    portal_url=$publicBaseUrl
    game_ws_url=$wss
    game_transport="enet_udp"
    game_udp_host=$publicIp
    game_udp_port=$udpPort
    game_lan_host=$lanIp
    mode="direct_udp_gameplay"
    version=$version
    updated=(Get-Date).ToString("o")
} | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $root "updates_site\kw\online_config.json"), $onlineJson, $utf8NoBom)

try {
    $response=Invoke-WebRequest -UseBasicParsing -Uri ($publicBaseUrl+"/") -TimeoutSec 12
    if($response.StatusCode -ne 200){throw "HTTP $($response.StatusCode)"}
} catch { throw "Stable endpoint health-check failed: $($_.Exception.Message)" }

Write-Host ""
Write-Host "KW STABLE ONLINE READY"
Write-Host "Portal/files: $publicBaseUrl"
Write-Host ("Game UDP:     {0}:{1}" -f $publicIp,$udpPort)
Write-Host ("LAN UDP:      {0}:{1}" -f $lanIp,$udpPort)
Write-Host "ngrok PID:    $($proc.Id)"
