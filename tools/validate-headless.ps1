param(
    [ValidateSet('Import', 'Runtime', 'Profile', 'NetworkHost', 'NetworkClient', 'BakeWorld', 'NativeComponents', 'BakeDust', 'Maps')]
    [string]$Mode = 'Runtime',
    [string]$Godot = '',
    [switch]$FourPlayers,
    [switch]$VerboseEngine,
    [ValidateSet('', 'outpost', 'dust')][string]$Map = '',
    [ValidateSet('', 'outpost', 'dust')][string]$ExpectMap = '',
    [ValidateRange(10, 600)][int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $Godot) { $Godot = Join-Path $projectRoot '.runtime\Godot_v4.5.2-stable_win64_console.exe' }
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$arguments = @('--headless', '--audio-driver', 'Dummy', '--path', ('"' + $projectRoot + '"'))
if ($VerboseEngine) { $arguments += '--verbose' }
switch ($Mode) {
    'Import' { $arguments += @('--editor', '--import', '--quit') }
    'Runtime' { $arguments += @('--script', 'res://tools/validate-runtime.gd', '--', '--silent') }
    'Profile' { $arguments += @('--script', 'res://tools/profile-simulation.gd', '--', '--silent') }
    'BakeWorld' { $arguments += @('--script', 'res://tools/bake-world.gd', '--', '--silent', '--automation') }
    'BakeDust' { $arguments += @('--script', 'res://tools/bake-dust.gd', '--', '--silent', '--automation') }
    'Maps' { $arguments += @('--script', 'res://tools/validate-maps.gd', '--', '--silent', '--automation') }
    'NativeComponents' { $arguments += @('--script', 'res://tools/validate-native-components.gd', '--', '--silent', '--automation') }
    default {
        $arguments += @('--script', 'res://tools/validate-network.gd', '--', '--silent')
        if ($Mode -eq 'NetworkHost') { $arguments += '--host' }
        if ($FourPlayers) { $arguments += '--four' }
    }
}
if ($Map) { $arguments += ('--map=' + $Map) }
if ($ExpectMap) { $arguments += ('--expect-map=' + $ExpectMap) }
# Headless prevents graphics windows; CreateNoWindow prevents console flashes.
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $Godot
$startInfo.Arguments = $arguments -join ' '
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
$started = $false
try {
    if (-not $process.Start()) { throw 'Could not start headless validation.' }
    $started = $true
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $process.WaitForExit(1000) -and [DateTime]::UtcNow -lt $deadline) { }
    if (-not $process.HasExited) {
        $process.Kill()
        $process.WaitForExit()
        $timeoutLog = Join-Path $projectRoot ('headless-timeout-' + $process.Id + '.log')
        Set-Content -LiteralPath $timeoutLog -Encoding utf8 -Value ($stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult())
        throw "Headless validation exceeded $TimeoutSeconds seconds; see $timeoutLog."
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $logPath = Join-Path $projectRoot ('headless-' + $Mode.ToLowerInvariant() + '-' + $process.Id + '.log')
    Set-Content -LiteralPath $logPath -Encoding utf8 -Value ($stdout + $stderr)
    Write-Output $stdout.TrimEnd()
    if ($stderr) { Write-Output $stderr.TrimEnd() }
    if ($process.ExitCode -ne 0 -or ($stdout + $stderr) -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw "Headless validation failed. See $logPath"
    }
} finally {
    if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose()
}
