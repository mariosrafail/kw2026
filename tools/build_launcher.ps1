param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$Output = "build/launcher"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

$sdk = dotnet --list-sdks
if (-not $sdk) {
    throw ".NET SDK not found. Install .NET 8 SDK to build launcher."
}

dotnet publish launcher/KwLauncher.csproj `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:PublishSingleFile=true `
    /p:IncludeNativeLibrariesForSelfExtract=true `
    -o $Output

Write-Host "Launcher build completed to $Output"
