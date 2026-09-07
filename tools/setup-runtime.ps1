param([switch]$Steam)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runtimeRoot = Join-Path $projectRoot '.runtime'
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
if ($Steam) {
    $url = 'https://github.com/GodotSteam/GodotSteam/releases/download/v4.16/windows64-g45-s162-gs416.zip'
    $expectedHash = '6BF0168D4E27179D445846434216EF1356DA7751CAA6F1F31C5015E77033AD63'
    $archivePath = Join-Path $runtimeRoot 'godotsteam.zip'
    $destination = Join-Path $runtimeRoot 'steam'
    $executable = Join-Path $destination 'godotsteam.45.editor.windows64.exe'
} else {
    $url = 'https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_win64.exe.zip'
    $expectedHash = '3766090865330AB2A0ED33594520394B711C620B1378F9223904FAEEF60F2F14'
    $archivePath = Join-Path $runtimeRoot 'godot.zip'
    $destination = $runtimeRoot
    $executable = Join-Path $destination 'Godot_v4.5.2-stable_win64.exe'
}
if (Test-Path -LiteralPath $executable) { Write-Output $executable; exit 0 }
if (-not (Test-Path -LiteralPath $archivePath)) {
    Write-Host 'Downloading the pinned Godot runtime...'
    & curl.exe --fail --location --retry 2 --output $archivePath $url
    if ($LASTEXITCODE -ne 0) { throw 'Runtime download failed. Re-run this script after checking the network.' }
}
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expectedHash) {
    throw "Runtime checksum mismatch: $archivePath. The archive was not extracted."
}
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Expand-Archive -LiteralPath $archivePath -DestinationPath $destination -Force
if (-not (Test-Path -LiteralPath $executable)) { throw 'The expected executable is missing from the archive.' }
Write-Output $executable
