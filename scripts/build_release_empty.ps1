# Release APK without demo events/schedules/booking samples.
# Obfuscates Dart and writes symbols to build/debug-info (keep that folder to decode crash stacks).
# Output: build/app/outputs/flutter-apk/almanac-release-empty.apk

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Building release APK (empty start)..." -ForegroundColor Cyan

flutter pub get
flutter test
flutter build apk `
  --release `
  --obfuscate `
  --split-debug-info=build/debug-info `
  --dart-define=SEED_DEMO_DATA=false

$source = "build/app/outputs/flutter-apk/app-release.apk"
$target = "build/app/outputs/flutter-apk/almanac-release-empty.apk"

if (-not (Test-Path $source)) {
  throw "APK not found: $source"
}

Copy-Item -Force $source $target
Write-Host ""
Write-Host "Done: $target" -ForegroundColor Green
Write-Host "Install: adb install -r `"$((Resolve-Path $target).Path)`""
