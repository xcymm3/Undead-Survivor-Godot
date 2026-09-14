$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot 'build'
$payloadRoot = Join-Path $buildRoot 'payload'
$version = (Get-Content -Raw -Encoding utf8 (Join-Path $projectRoot 'VERSION')).Trim()
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Windows .NET Framework 4.x compiler is required to build the single EXE.' }
$files = @('Undead-Survivor-Godot.exe', 'steam_api64.dll', 'steam_appid.txt', 'THIRD-PARTY-NOTICES.txt', 'FONT-LICENSE.txt', 'VERSION') | ForEach-Object { Join-Path $payloadRoot $_ }
$payload = Join-Path $buildRoot 'launcher-payload.zip'
Compress-Archive -LiteralPath $files -DestinationPath $payload -Force
$metadata = Join-Path $buildRoot 'launcher-version.cs'
@"
using System.Reflection;
[assembly: AssemblyTitle("Undead Survivor")]
[assembly: AssemblyProduct("Undead Survivor Godot")]
[assembly: AssemblyDescription("Undead Survivor self-extracting Steam launcher")]
[assembly: AssemblyVersion("$version.0")]
[assembly: AssemblyFileVersion("$version.0")]
[assembly: AssemblyInformationalVersion("$version.0")]
"@ | Set-Content -LiteralPath $metadata -Encoding utf8
# Preserve the native game's icon on the downloadable launcher.
Add-Type -AssemblyName System.Drawing
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Join-Path $payloadRoot 'Undead-Survivor-Godot.exe'))
$iconPath = Join-Path $buildRoot 'launcher.ico'
$stream = [System.IO.File]::Create($iconPath)
try { $icon.Save($stream) } finally { $stream.Dispose(); $icon.Dispose() }
$output = Join-Path $buildRoot 'Undead-Survivor-Godot.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ "/out:$output" "/win32icon:$iconPath" /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Windows.Forms.dll "/resource:$payload,game.zip" $metadata (Join-Path $PSScriptRoot 'windows-launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Single EXE launcher compilation failed.' }
Write-Host "Built self-extracting EXE: $output"
