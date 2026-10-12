# Сборка и запуск Almanac API в Docker против облачной YandexDB.
# Usage: .\scripts\docker_yandex_up.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$envFile = ".\.env.yandex"
$example = ".\deploy\.env.yandex.example"
$keyPath = ".\secrets\sa-key.json"

if (-not (Test-Path $envFile)) {
    Copy-Item $example $envFile
    Write-Host "Создан .env.yandex — заполните ALMANAC_YDB_DATABASE и ALMANAC_PUBLIC_ORIGIN." -ForegroundColor Yellow
    Write-Host "Путь: $((Resolve-Path $envFile).Path)"
    exit 1
}

if (-not (Test-Path $keyPath)) {
    Write-Host "Положите JSON-ключ сервисного аккаунта в server\secrets\sa-key.json" -ForegroundColor Yellow
    Write-Host "IAM → Сервисные аккаунты → almanac-api → Создать ключ → JSON"
    exit 1
}

$dbLine = Select-String -Path $envFile -Pattern '^ALMANAC_YDB_DATABASE=' | Select-Object -First 1
if ($dbLine -and $dbLine.Line -match 'xxxxxxxx') {
    Write-Host "В .env.yandex замените ALMANAC_YDB_DATABASE на путь из карточки YDB." -ForegroundColor Yellow
    exit 1
}

Write-Host "Building and starting almanac-api (YandexDB)..." -ForegroundColor Cyan
docker compose -f docker-compose.yandex.yml up --build -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$port = if ($env:ALMANAC_PUBLISH_PORT) { $env:ALMANAC_PUBLISH_PORT } else { "8080" }
Write-Host "Waiting for /health on port $port..." -ForegroundColor Cyan

for ($i = 0; $i -lt 30; $i++) {
    try {
        $resp = Invoke-WebRequest "http://localhost:$port/health" -UseBasicParsing -TimeoutSec 3
        if ($resp.StatusCode -eq 200) {
            Write-Host "OK: $($resp.Content)" -ForegroundColor Green
            Write-Host "Server URL for Flutter: http://localhost:$port (or your VM public IP / domain)"
            exit 0
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

Write-Host "Container started but /health not ready — check logs:" -ForegroundColor Yellow
Write-Host "  docker compose -f docker-compose.yandex.yml logs -f almanac-api"
exit 1
