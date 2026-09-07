param([string]$Godot = "")
$ErrorActionPreference = 'Stop'
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
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(55)
    while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
        $process.Refresh()
    }
    if (-not $process.HasExited) { Stop-Process -Id $process.Id; throw 'Offscreen capture exceeded 55 seconds.' }
    Get-Content -Encoding utf8 -LiteralPath $stdout
    Get-Content -Encoding utf8 -LiteralPath $stderr
} finally { $hiddenParent.Dispose() }
