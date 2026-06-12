param(
    [switch]$SkipBuild,
    [switch]$SkipUpload
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = $PSScriptRoot }
$ProjectRoot = Split-Path -Parent $ScriptDir
$SrcDir = Join-Path $ProjectRoot "src"
$ReleaseDir = Join-Path $SrcDir "build\windows\x64\runner\Release"
$InstallerDir = Join-Path $SrcDir "build\windows\installer"
$InnoSetupDir = Join-Path $ProjectRoot "packaging\inno-setup"

$VersionLine = Select-String "^version:" (Join-Path $SrcDir "pubspec.yaml") | Select-Object -First 1
$Version = $VersionLine.Line -replace 'version: ' -replace '\+.*'
$Tag = "v$Version"

Write-Host "=== WHPH Windows Release v$Version ===" -ForegroundColor Cyan

if (-not $SkipBuild) {
    Write-Host "`n[1/5] Initializing submodules..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    git submodule update --init --force packages/acore-flutter packages/acore-scripts
    Pop-Location

    Write-Host "[2/5] Running drift code generation..." -ForegroundColor Yellow
    Push-Location $SrcDir
    fvm flutter pub run build_runner build --delete-conflicting-outputs
    Pop-Location

    Write-Host "[3/5] Building Windows release..." -ForegroundColor Yellow
    Push-Location $SrcDir
    fvm flutter build windows --release
    Pop-Location
} else {
    Write-Host "[1-3/5] Skipped (--SkipBuild)" -ForegroundColor Gray
}

Write-Host "[4/5] Packaging artifacts..." -ForegroundColor Yellow

$PortableZip = Join-Path $ProjectRoot "whph-v$Version-windows-portable.zip"
if (Test-Path $PortableZip) { Remove-Item $PortableZip -Force }
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $PortableZip -Force
Write-Host "  Created: $PortableZip" -ForegroundColor Green

if (-not (Test-Path $InstallerDir)) { New-Item -ItemType Directory -Path $InstallerDir -Force | Out-Null }
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (Join-Path $InnoSetupDir "installer.iss") *>$null

$SetupExe = Join-Path $InstallerDir "whph-setup.exe"
$SetupDest = Join-Path $ProjectRoot "whph-v$Version-windows-setup.exe"
Copy-Item $SetupExe $SetupDest -Force
Write-Host "  Created: $SetupDest" -ForegroundColor Green

if (-not $SkipUpload) {
    Write-Host "[5/5] Uploading to GitHub release $Tag..." -ForegroundColor Yellow

    $existing = gh release view $Tag --json tagName --jq '.tagName' 2>$null
    if (-not $existing) {
        Write-Host "  Release $Tag does not exist, creating..." -ForegroundColor Yellow
        gh release create $Tag --title $Tag --generate-notes
    }

    gh release upload $Tag $PortableZip $SetupDest --clobber
    Write-Host "  Uploaded to: https://github.com/ahmet-cetinkaya/whph/releases/tag/$Tag" -ForegroundColor Green
} else {
    Write-Host "[5/5] Skipped (--SkipUpload)" -ForegroundColor Gray
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
