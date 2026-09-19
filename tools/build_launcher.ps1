param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$Output = "build/launcher"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

$dotnet = (Get-Command dotnet -ErrorAction SilentlyContinue).Source
if (-not $dotnet) {
    $portableDotnet = Join-Path $env:USERPROFILE ".dotnet\dotnet.exe"
    if (Test-Path $portableDotnet) {
        $dotnet = $portableDotnet
    }
}
if (-not $dotnet) {
    throw ".NET SDK not found. Install .NET 8 SDK to build launcher."
}

$sdk = & $dotnet --list-sdks
if (-not $sdk) {
    throw ".NET SDK not found. Install .NET 8 SDK to build launcher."
}

$outputPath = Join-Path $projectRoot $Output
if (Test-Path $outputPath) {
    Remove-Item -Recurse -Force $outputPath
}

& $dotnet publish launcher/KwLauncher.csproj `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:PublishSingleFile=false `
    -o $Output
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

Write-Host "Launcher build completed to $Output"
