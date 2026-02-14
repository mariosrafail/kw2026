param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$PublicBaseUrl
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

Ensure-File "build/kw.exe"
Ensure-File "build/kw.pck"

$updateDir = Join-Path $projectRoot "updates_site/kw"
New-Item -ItemType Directory -Path $updateDir -Force | Out-Null

$exeTarget = Join-Path $updateDir "kw.exe"
$pckTarget = Join-Path $updateDir "kw.pck"
$zipTarget = Join-Path $updateDir "kw_update.zip"
$manifestTarget = Join-Path $updateDir "update_manifest.json"

Copy-Item "build/kw.exe" $exeTarget -Force
Copy-Item "build/kw.pck" $pckTarget -Force

if (Test-Path $zipTarget) {
    Remove-Item $zipTarget -Force
}
Compress-Archive -Path @($exeTarget, $pckTarget) -DestinationPath $zipTarget -CompressionLevel Optimal

$normalizedBaseUrl = $PublicBaseUrl.TrimEnd("/")
$manifest = @{
    version = $Version
    package_url = "$normalizedBaseUrl/kw/kw_update.zip"
    exe_url = "$normalizedBaseUrl/kw/kw.exe"
    pck_url = "$normalizedBaseUrl/kw/kw.pck"
}

$manifest | ConvertTo-Json | Set-Content -Path $manifestTarget -Encoding UTF8

Write-Host "Published update files:"
Write-Host "  $exeTarget"
Write-Host "  $pckTarget"
Write-Host "  $zipTarget"
Write-Host "  $manifestTarget"
Write-Host ""
Write-Host "Manifest URL:"
Write-Host "  $normalizedBaseUrl/kw/update_manifest.json"
