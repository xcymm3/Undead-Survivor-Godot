$ErrorActionPreference = 'Stop'
$labWorkspace = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $labWorkspace
$labOutput = Join-Path $labWorkspace 'artifacts/cpu-improvements-night'
New-Item -ItemType Directory -Path $labOutput -Force | Out-Null
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CpuLabPower {
    [DllImport("kernel32.dll")]
    public static extern UInt32 SetThreadExecutionState(UInt32 flags);
}
'@
$labAwake = [CpuLabPower]::SetThreadExecutionState([uint32]2147483649)
$labChild = $null
try {
    $labNode = (Get-Command node).Source
    $labChild = Start-Process -FilePath $labNode -ArgumentList @('tools/run-cpu-improvements.mjs') -WorkingDirectory $labWorkspace -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $labOutput 'console.log') -RedirectStandardError (Join-Path $labOutput 'console-error.log')
    @{ launcherPid=$PID; cliPid=$labChild.Id; temporarySystemAwake=($labAwake -ne 0); startedAt=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $labOutput 'launcher.json') -Encoding utf8
    Write-Output "CLI started: PID=$($labChild.Id); temporary system-awake request=$($labAwake -ne 0)"
    while (-not $labChild.WaitForExit(1000)) { }
    Write-Output "CLI exited: $($labChild.ExitCode)"
    exit $labChild.ExitCode
} finally {
    [void][CpuLabPower]::SetThreadExecutionState([uint32]2147483648)
}
