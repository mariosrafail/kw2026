param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$PublicBaseUrl,
    [string]$LinuxBin = "build/linux/kw.x86_64",
    [string]$LinuxPck = "build/linux/kw.pck"
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
Write-Output "[publish-linux] Project root: $projectRoot"

Ensure-File $LinuxBin
Ensure-File $LinuxPck
Write-Output "[publish-linux] Found Linux build files"

$updateDir = Join-Path $projectRoot "updates_site/kw"
New-Item -ItemType Directory -Path $updateDir -Force | Out-Null

$binTarget = Join-Path $updateDir "kw.x86_64"
$pckTarget = Join-Path $updateDir "kw_linux.pck"
$zipTarget = Join-Path $updateDir "kw_update_linux.zip"
$manifestTarget = Join-Path $updateDir "update_manifest_linux.json"

Copy-Item $LinuxBin $binTarget -Force
Copy-Item $LinuxPck $pckTarget -Force

if (Test-Path $zipTarget) {
    Remove-Item $zipTarget -Force
}
Compress-Archive -Path @($binTarget, $pckTarget) -DestinationPath $zipTarget -CompressionLevel Optimal

$normalizedBaseUrl = $PublicBaseUrl.TrimEnd("/")
$manifest = @{
    version = $Version
    linux_package_url = "$normalizedBaseUrl/kw/kw_update_linux.zip"
    linux_bin_url = "$normalizedBaseUrl/kw/kw.x86_64"
    linux_pck_url = "$normalizedBaseUrl/kw/kw_linux.pck"
}

$manifest | ConvertTo-Json | Set-Content -Path $manifestTarget -Encoding UTF8

Write-Output "[publish-linux] Published update files:"
Write-Output "  $binTarget"
Write-Output "  $pckTarget"
Write-Output "  $zipTarget"
Write-Output "  $manifestTarget"
Write-Output ""
Write-Output "[publish-linux] Manifest URL:"
Write-Output "  $normalizedBaseUrl/kw/update_manifest_linux.json"
