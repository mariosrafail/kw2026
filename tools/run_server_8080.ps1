param(
    [int]$Port = 8080,
    [string]$BindHost = "0.0.0.0",
    [switch]$TailLog
)

$ErrorActionPreference = "Stop"

$project = Split-Path -Parent $PSScriptRoot
$godot = "C:\Program Files\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64_console.exe"
if (!(Test-Path $godot)) {
    throw "Godot console exe not found at: $godot"
}

$udp = Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
if ($udp) {
    $ownerPid = [int]$udp.OwningProcess
    $proc = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
    $name = if ($proc) { $proc.ProcessName } else { "PID $ownerPid" }
    throw "UDP port $Port is already in use by $name. Close it (often Docker Desktop / com.docker.backend) and retry."
}

$log = Join-Path $project "server_headless_$Port.log"
$args = @(
    "--headless",
    "--log-file", $log,
    "--path", $project,
    "--",
    "--mode=server",
    "--host=$BindHost",
    "--port=$Port"
)

$p = Start-Process -FilePath $godot -ArgumentList $args -WorkingDirectory $project -PassThru
"Started headless server PID $($p.Id) on $BindHost`:$Port"
"Log: $log"

Start-Sleep -Milliseconds 900
if (Test-Path $log) {
    Get-Content $log -Tail 80
}

if ($TailLog) {
    Get-Content $log -Wait
}
