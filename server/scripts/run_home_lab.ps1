# Almanac home lab: API on this PC + WireGuard helper for MikroTik.
# Opens http://127.0.0.1:8080/lab — enter WAN/DDNS, generate scripts, test.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

if (-not (Test-Path ".\data")) {
    New-Item -ItemType Directory -Path ".\data" | Out-Null
}

function Get-LanIPv4 {
    $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Select-Object -ExpandProperty IPAddress)
    $preferred = $candidates | Where-Object { $_ -like "192.168.*" } | Select-Object -First 1
    if ($preferred) { return $preferred }
    $preferred = $candidates | Where-Object { $_ -like "10.*" } | Select-Object -First 1
    if ($preferred) { return $preferred }
    $preferred = $candidates |
        Where-Object { $_ -notlike "172.17.*" -and $_ -notlike "172.18.*" -and $_ -notlike "172.19.*" } |
        Select-Object -First 1
    if ($preferred) { return $preferred }

    $udp = New-Object System.Net.Sockets.UdpClient
    try {
        $udp.Connect("8.8.8.8", 80)
        return ($udp.Client.LocalEndPoint).Address.ToString()
    } finally {
        $udp.Close()
    }
}

$lanIp = Get-LanIPv4
if (-not $lanIp -or $lanIp.StartsWith("127.")) {
    $lanIp = "127.0.0.1"
}

$env:ALMANAC_DB_BACKEND = "sqlite"
$env:ALMANAC_SQLITE_PATH = ".\data\almanac.db"
$env:ALMANAC_PUBLIC_ORIGIN = "http://${lanIp}:8080"
$env:ALMANAC_HOST = "0.0.0.0"
$env:ALMANAC_PORT = "8080"
$env:ALMANAC_HOME_LAB = "1"
$env:ALMANAC_CORS_ORIGINS = "*"

$python = $null
foreach ($cmd in @("py", "python")) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $python = $cmd
        break
    }
}
if (-not $python) {
    Write-Error "Python не найден. Установите Python 3.11+ и: pip install -r requirements.txt"
}

Write-Host "Almanac API:  http://${lanIp}:8080"
Write-Host "Помощник:     http://127.0.0.1:8080/lab"
Write-Host "Планирование: http://127.0.0.1:8080/lab/plan"
Write-Host "Health:       http://${lanIp}:8080/health"
Write-Host "В Almanac → Ссылки и API → $env:ALMANAC_PUBLIC_ORIGIN"
Write-Host ""

Start-Process -FilePath "powershell" -WindowStyle Hidden -ArgumentList @(
    "-NoProfile",
    "-Command",
    "Start-Sleep -Seconds 2; Start-Process 'http://127.0.0.1:8080/lab'"
)

if ($python -eq "py") {
    py -3 -m uvicorn almanac.main:app --host 0.0.0.0 --port 8080
} else {
    python -m uvicorn almanac.main:app --host 0.0.0.0 --port 8080
}
