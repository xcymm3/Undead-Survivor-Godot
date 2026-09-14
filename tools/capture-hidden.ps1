param([string]$Godot = "", [switch]$AllowGraphics, [switch]$HomeOnly, [switch]$VisualQuality)
$ErrorActionPreference = 'Stop'
if (-not $AllowGraphics) {
    throw 'GPU capture is disabled by default because graphical startup may flash. Use validate-headless.ps1 for background checks. Pass -AllowGraphics only for an explicitly requested visual inspection.'
}
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $Godot) { $Godot = Join-Path $projectRoot '.runtime\Godot_v4.5.2-stable_win64.exe' }
$Godot = (Resolve-Path -LiteralPath $Godot).Path
Add-Type -AssemblyName System.Windows.Forms
$hiddenParent = New-Object System.Windows.Forms.Form
$hiddenParent.ShowInTaskbar = $false
$hiddenParent.Width = 1440
$hiddenParent.Height = 900
# Creating a handle does not display the form. Godot is a child of this invisible window.
$windowId = $hiddenParent.Handle.ToInt64()
$stdout = Join-Path $projectRoot 'capture.log'
$stderr = Join-Path $projectRoot 'capture-errors.log'
$arguments = @('--path', ('"' + $projectRoot + '"'), '--wid', $windowId, '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tools/capture.gd', '--', '--silent', '--capture')
if ($HomeOnly) { $arguments += "--home-only" }
if ($VisualQuality) {
    $arguments = $arguments | ForEach-Object { if ($_ -eq 'res://tools/capture.gd') { 'res://tools/visual-quality.gd' } else { $_ } }
    $arguments += '--automation'
}
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $process.Handle # Retain the handle so Windows PowerShell can read ExitCode after exit.
try {
    $deadline = [DateTime]::UtcNow.AddSeconds($(if ($VisualQuality) { 180 } else { 55 }))
    while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
        $process.Refresh()
    }
    if (-not $process.HasExited) { Stop-Process -Id $process.Id; throw 'Offscreen capture exceeded its time limit.' }
    $process.WaitForExit()
    Get-Content -Encoding utf8 -LiteralPath $stdout
    Get-Content -Encoding utf8 -LiteralPath $stderr
    if ($process.ExitCode -ne 0 -or (Get-Content -Raw -Encoding utf8 $stderr) -match '(?m)^(SCRIPT ERROR|ERROR):') { throw "Native capture failed (exit $($process.ExitCode)); inspect capture-errors.log." }
} finally { $hiddenParent.Dispose() }
