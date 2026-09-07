param([switch]$Steam, [switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if ($Steam) {
    & (Join-Path $PSScriptRoot 'setup-runtime.ps1') -Steam | Out-Null
    $engine = Join-Path $projectRoot '.runtime\steam\godotsteam.45.editor.windows64.exe'
    $consoleEngine = Join-Path $projectRoot '.runtime\steam\godotsteam.45.editor.windows64.console.exe'
} elseif ($env:GODOT_BINARY -and (Test-Path -LiteralPath $env:GODOT_BINARY)) {
    $engine = (Resolve-Path -LiteralPath $env:GODOT_BINARY).Path
    $consoleEngine = $engine
} else {
    & (Join-Path $PSScriptRoot 'setup-runtime.ps1') | Out-Null
    $engine = Join-Path $projectRoot '.runtime\Godot_v4.5.2-stable_win64.exe'
    $consoleEngine = Join-Path $projectRoot '.runtime\Godot_v4.5.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.godot\imported')) -or $Steam) {
    & $consoleEngine --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed.' }
}
$arguments = @('--path', ('"' + $projectRoot + '"'))
if ($Editor) { $arguments += '--editor' }
if ($Steam) { $env:SteamAppId = '480'; $env:SteamGameId = '480' }
# This script is explicitly launched by the player to open the game/editor.
Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $projectRoot
