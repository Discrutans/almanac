# Запуск API с YandexDB (Windows / dev против облачной БД).
# Требуется: pip install -r requirements.txt, server/.env.yandex, secrets/sa-key.json

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$envFile = ".\.env.yandex"
if (-not (Test-Path $envFile)) {
    Copy-Item ".\deploy\.env.yandex.example" $envFile
    Write-Host "Создан .env.yandex — откройте файл и подставьте ALMANAC_YDB_DATABASE из консоли Yandex Cloud." -ForegroundColor Yellow
    Write-Host "Путь: $((Resolve-Path $envFile).Path)"
    exit 1
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $pair = $_ -split '=', 2
    if ($pair.Count -eq 2) {
        $name = $pair[0].Trim()
        $value = $pair[1].Trim()
        Set-Item -Path "env:$name" -Value $value
    }
}

$keyPath = (Resolve-Path ".\secrets\sa-key.json").Path
if (-not (Test-Path $keyPath)) {
    Write-Host "Положите JSON-ключ SA в server\secrets\sa-key.json" -ForegroundColor Yellow
    exit 1
}
$env:ALMANAC_YDB_SERVICE_ACCOUNT_KEY_FILE = $keyPath

if ($env:ALMANAC_YDB_DATABASE -match 'xxxxxxxx') {
    Write-Host "В .env.yandex замените ALMANAC_YDB_DATABASE на путь из карточки YDB (не xxxxxxxx)." -ForegroundColor Yellow
    exit 1
}

$env:PYTHONPATH = (Get-Location).Path
if (-not $env:ALMANAC_PORT) { $env:ALMANAC_PORT = "8080" }

$portInUse = Get-NetTCPConnection -LocalPort $env:ALMANAC_PORT -State Listen -ErrorAction SilentlyContinue
if ($portInUse) {
    $ownerPid = ($portInUse | Select-Object -First 1).OwningProcess
    $proc = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
    $name = if ($proc) { $proc.ProcessName } else { "unknown" }
    Write-Host "Порт $($env:ALMANAC_PORT) занят (PID $ownerPid, $name)." -ForegroundColor Yellow
    Write-Host "Остановите старый сервер (run_sqlite.ps1 / uvicorn) — Ctrl+C в том терминале — и запустите снова."
    exit 1
}

Write-Host "Applying YDB schema (if not yet applied)..."
python scripts/apply_ydb_schema.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Starting API on http://localhost:$($env:ALMANAC_PORT)"
python -m uvicorn almanac.main:app --host 0.0.0.0 --port $env:ALMANAC_PORT
