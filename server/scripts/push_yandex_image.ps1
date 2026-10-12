# Push Docker image to Yandex Container Registry.
# Usage: .\scripts\push_yandex_image.ps1 -RegistryId crpXXXXXXXX -Tag latest

param(
    [Parameter(Mandatory = $true)]
    [string]$RegistryId,
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$image = "cr.yandex/$RegistryId/almanac-api:$Tag"

if (-not (Get-Command yc -ErrorAction SilentlyContinue)) {
    Write-Host "Install Yandex Cloud CLI: https://cloud.yandex.ru/docs/cli/quickstart" -ForegroundColor Yellow
    exit 1
}

yc container registry configure-docker
docker build -t $image .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
docker push $image
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Pushed $image" -ForegroundColor Green
Write-Host "Deploy on VM: docker pull $image && docker run ... (see deploy/yandex-docker.md)"
