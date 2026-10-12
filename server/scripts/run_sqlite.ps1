# Run Almanac API locally without Docker (Windows / dev).
# Requires Python 3.11+ and: pip install -r requirements.txt

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

if (-not (Test-Path ".\data")) {
    New-Item -ItemType Directory -Path ".\data" | Out-Null
}

$env:ALMANAC_DB_BACKEND = "sqlite"
$env:ALMANAC_SQLITE_PATH = ".\data\almanac.db"
$env:ALMANAC_PUBLIC_ORIGIN = "http://localhost:8080"
$env:ALMANAC_HOST = "0.0.0.0"
$env:ALMANAC_PORT = "8080"

Write-Host "Starting Almanac API at http://localhost:8080"
Write-Host "Health: curl http://localhost:8080/health"
Write-Host ""

python -m uvicorn almanac.main:app --host 0.0.0.0 --port 8080 --reload
