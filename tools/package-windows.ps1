$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot 'build'
$version = (Get-Content -Raw -Encoding utf8 (Join-Path $projectRoot 'VERSION')).Trim()
$packagedVersion = (Get-Content -Raw -Encoding utf8 (Join-Path $buildRoot 'VERSION')).Trim()
$metadata = (Get-Item -LiteralPath (Join-Path $buildRoot 'Undead-Survivor-Godot.exe')).VersionInfo
if ($packagedVersion -ne $version -or $metadata.FileVersion -ne "$version.0" -or $metadata.ProductVersion -ne "$version.0") { throw 'Packaged EXE version does not match VERSION.' }
$files = @('Undead-Survivor-Godot.exe', 'steam_api64.dll', 'steam_appid.txt', 'THIRD-PARTY-NOTICES.txt', 'FONT-LICENSE.txt', 'VERSION') | ForEach-Object { Join-Path $buildRoot $_ }
$archive = Join-Path $buildRoot 'Undead-Survivor-Godot-Windows-x64.zip'
Compress-Archive -LiteralPath $files -DestinationPath $archive -Force
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $buildRoot 'SHA256SUMS.txt') -Encoding ascii -Value "$hash  Undead-Survivor-Godot-Windows-x64.zip"
