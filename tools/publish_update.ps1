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
Write-Output "[publish] Project root: $projectRoot"

Ensure-File "build/kw.exe"
Ensure-File "build/kw.pck"
Write-Output "[publish] Found build/kw.exe and build/kw.pck"

$updateDir = Join-Path $projectRoot "updates_site/kw"
New-Item -ItemType Directory -Path $updateDir -Force | Out-Null

$exeTarget = Join-Path $updateDir "kw.exe"
$pckTarget = Join-Path $updateDir "kw.pck"
$zipTarget = Join-Path $updateDir "kw_update.zip"
$versionTag = ($Version -replace '[^A-Za-z0-9._-]', '_')
$zipVersionedTarget = Join-Path $updateDir ("kw_update_{0}.zip" -f $versionTag)
$manifestTarget = Join-Path $updateDir "update_manifest.json"

Copy-Item "build/kw.exe" $exeTarget -Force
Copy-Item "build/kw.pck" $pckTarget -Force
Write-Output "[publish] Copied game files to updates_site/kw"

if (Test-Path $zipTarget) {
    Remove-Item $zipTarget -Force
}
if (Test-Path $zipVersionedTarget) {
    Remove-Item $zipVersionedTarget -Force
}
Compress-Archive -Path @($exeTarget, $pckTarget) -DestinationPath $zipVersionedTarget -CompressionLevel Optimal
Copy-Item $zipVersionedTarget $zipTarget -Force
Write-Output "[publish] Created $zipVersionedTarget"

$exeSha256 = (Get-FileHash -Path $exeTarget -Algorithm SHA256).Hash.ToLowerInvariant()
$pckSha256 = (Get-FileHash -Path $pckTarget -Algorithm SHA256).Hash.ToLowerInvariant()

$normalizedBaseUrl = $PublicBaseUrl.TrimEnd("/")
$manifest = @{
    version = $Version
    package_url = "$normalizedBaseUrl/kw/kw_update_$versionTag.zip"
    exe_url = "$normalizedBaseUrl/kw/kw.exe"
    pck_url = "$normalizedBaseUrl/kw/kw.pck"
    exe_sha256 = $exeSha256
    pck_sha256 = $pckSha256
    published_at_utc = (Get-Date).ToUniversalTime().ToString("o")
}

$manifest | ConvertTo-Json | Set-Content -Path $manifestTarget -Encoding UTF8

Write-Output "[publish] Published update files:"
Write-Output "  $exeTarget"
Write-Output "  $pckTarget"
Write-Output "  $zipTarget"
Write-Output "  $manifestTarget"
Write-Output ""
Write-Output "[publish] Manifest URL:"
Write-Output "  $normalizedBaseUrl/kw/update_manifest.json"
