$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'setup-runtime.ps1') -Steam | Out-Null
$engine = Join-Path $projectRoot '.runtime\steam\godotsteam.45.editor.windows64.console.exe'
$buildRoot = Join-Path $projectRoot 'build'
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
& $engine --headless --path $projectRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
& $engine --headless --path $projectRoot --export-release 'Windows Steam x64'
if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
Copy-Item -LiteralPath (Join-Path $projectRoot '.runtime\steam\steam_api64.dll') -Destination $buildRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'steam_appid.txt') -Destination $buildRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\THIRD-PARTY-NOTICES.txt') -Destination $buildRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\fonts\LICENSE.txt') -Destination (Join-Path $buildRoot 'FONT-LICENSE.txt') -Force
Write-Host "Exported to $buildRoot"
