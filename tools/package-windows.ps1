$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot 'build'
$version = (Get-Content -Raw -Encoding utf8 (Join-Path $projectRoot 'VERSION')).Trim()
Copy-Item -LiteralPath (Join-Path $buildRoot 'payload/VERSION') -Destination $buildRoot -Force
$packagedVersion = (Get-Content -Raw -Encoding utf8 (Join-Path $buildRoot 'VERSION')).Trim()
$metadata = (Get-Item -LiteralPath (Join-Path $buildRoot 'Undead-Survivor-Godot.exe')).VersionInfo
if ($packagedVersion -ne $version -or $metadata.FileVersion -ne "$version.0" -or $metadata.ProductVersion -ne "$version.0") { throw 'Packaged EXE version does not match VERSION.' }
$files = @((Join-Path $buildRoot 'Undead-Survivor-Godot.exe'), (Join-Path $buildRoot 'VERSION'))
$files += @('THIRD-PARTY-NOTICES.txt', 'FONT-LICENSE.txt') | ForEach-Object { Join-Path $buildRoot "payload/$_" }
$archive = Join-Path $buildRoot 'Undead-Survivor-Godot-Windows-x64.zip'
Compress-Archive -LiteralPath $files -DestinationPath $archive -Force
$hashes = @($archive, (Join-Path $buildRoot 'Undead-Survivor-Godot.exe')) | ForEach-Object {
    "$((Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($_))"
}
Set-Content -LiteralPath (Join-Path $buildRoot 'SHA256SUMS.txt') -Encoding ascii -Value $hashes
