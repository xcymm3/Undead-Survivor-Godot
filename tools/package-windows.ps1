$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot 'build'
$files = @('Undead-Survivor-Godot.exe', 'steam_api64.dll', 'steam_appid.txt', 'THIRD-PARTY-NOTICES.txt', 'FONT-LICENSE.txt') | ForEach-Object { Join-Path $buildRoot $_ }
$archive = Join-Path $buildRoot 'Undead-Survivor-Godot-Windows-x64.zip'
Compress-Archive -LiteralPath $files -DestinationPath $archive -Force
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $buildRoot 'SHA256SUMS.txt') -Encoding ascii -Value "$hash  Undead-Survivor-Godot-Windows-x64.zip"
