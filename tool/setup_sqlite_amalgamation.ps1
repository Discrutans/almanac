# Fetches SQLite amalgamation from sqlite.org (not GitHub).
# Run once before the first offline build.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root 'third_party\sqlite3'
$version = '3450100'
$zipUrl = "https://www.sqlite.org/2024/sqlite-amalgamation-$version.zip"
$zipPath = Join-Path $dest 'sqlite.zip'

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "Downloading SQLite $version from sqlite.org ..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

Expand-Archive -Path $zipPath -DestinationPath $dest -Force
$inner = Join-Path $dest "sqlite-amalgamation-$version"
Move-Item -Force (Join-Path $inner 'sqlite3.c') (Join-Path $dest 'sqlite3.c')
Move-Item -Force (Join-Path $inner 'sqlite3.h') (Join-Path $dest 'sqlite3.h')
Remove-Item -Recurse -Force $inner, $zipPath

Write-Host "Done: $dest\sqlite3.c"
