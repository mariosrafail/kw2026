param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [string]$TargetDir = "updates_site/kw"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Resolve-Path -LiteralPath (Join-Path $projectRoot $SourceDir)
$targetPath = Join-Path $projectRoot $TargetDir

if (-not (Test-Path -LiteralPath $targetPath)) {
    New-Item -ItemType Directory -Path $targetPath | Out-Null
}

$htmlFiles = Get-ChildItem -LiteralPath $sourcePath -File -Filter *.html
if ($htmlFiles.Count -eq 0) {
    throw "No HTML file found in '$sourcePath'. Export Web first."
}

# Copy web runtime files.
$includeExtensions = @("*.html", "*.js", "*.wasm", "*.pck", "*.json", "*.txt", "*.worker.js", "*.worklet.js")
foreach ($pattern in $includeExtensions) {
    Get-ChildItem -LiteralPath $sourcePath -File -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetPath $_.Name) -Force
    }
}

# Ensure root page is index.html for nginx.
$indexPath = Join-Path $targetPath "index.html"
if (-not (Test-Path -LiteralPath $indexPath)) {
    $primaryHtml = $htmlFiles | Select-Object -First 1
    Copy-Item -LiteralPath $primaryHtml.FullName -Destination $indexPath -Force
}

Write-Output "[web-publish] Source: $sourcePath"
Write-Output "[web-publish] Target: $targetPath"
Write-Output "[web-publish] index.html ready: $(Test-Path -LiteralPath $indexPath)"

$required = @(
    "kw.js",
    "kw.wasm",
    "kw.pck",
    "kw.audio.worklet.js",
    "kw.audio.position.worklet.js"
)
foreach ($name in $required) {
    $exists = Test-Path -LiteralPath (Join-Path $targetPath $name)
    Write-Output "[web-publish] file $name present: $exists"
}
