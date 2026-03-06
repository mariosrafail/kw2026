param(
    [int]$Port = 8080,
    [string]$BindHost = "0.0.0.0",
    [switch]$TailLog
)

$ErrorActionPreference = "Stop"

$project = Split-Path -Parent $PSScriptRoot
$godotCandidates = @()
if ($env:GODOT_CONSOLE_EXE) {
    $godotCandidates += $env:GODOT_CONSOLE_EXE
}
$godotCandidates += @(
    "C:\Users\Marios\Godot\Godot_v4.6.1-stable_win64_console.exe",
    "C:\Users\Marios\Godot\Godot_v4.6.1-stable_win64.exe",
    "C:\Program Files\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64_console.exe"
)

$godot = $null
foreach ($candidate in $godotCandidates) {
    if ($candidate -and (Test-Path $candidate)) {
        $godot = $candidate
        break
    }
}
if ($null -eq $godot) {
    throw "Godot console exe not found. Set GODOT_CONSOLE_EXE or install Godot in one of the expected paths: $($godotCandidates -join ', ')"
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
}
if ($null -eq $python) {
    throw "Python is required to run tools/check_rpc_surface.py before server start."
}

$rpcCheck = Join-Path $project "tools\check_rpc_surface.py"
if (!(Test-Path $rpcCheck)) {
    throw "RPC validation script not found at: $rpcCheck"
}

if ($python.Name -eq "py.exe" -or $python.Name -eq "py") {
    & $python.Source -3 $rpcCheck
} else {
    & $python.Source $rpcCheck
}
if ($LASTEXITCODE -ne 0) {
    throw "RPC surface validation failed. Fix the reported mismatches before starting the server."
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
