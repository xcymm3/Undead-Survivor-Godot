param([Parameter(Mandatory=$true)][string]$BaselineProjectPath, [string]$Godot = '')
$ErrorActionPreference = 'Stop'
$currentRoot = Split-Path $PSScriptRoot -Parent
$baselineRoot = (Resolve-Path -LiteralPath $BaselineProjectPath).Path
if ($baselineRoot -eq $currentRoot -or -not (Test-Path -LiteralPath (Join-Path $baselineRoot 'project.godot'))) { throw 'Use a separate baseline Godot project.' }
if (-not $Godot) { $Godot = Join-Path $currentRoot '.runtime/Godot_v4.5.2-stable_win64_console.exe' }
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$baselineArtifacts = Join-Path $baselineRoot 'artifacts'
New-Item -ItemType Directory -Force -Path $baselineArtifacts | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'benchmark-enemy-physics.gd') -Destination (Join-Path $baselineArtifacts 'benchmark-paired.gd')

function Run-PairProcess([string]$ProjectRoot,[string[]]$ExtraArgs,[string]$LogName) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Godot
    $info.Arguments = (@('--headless','--audio-driver','Dummy','--path',('"'+$ProjectRoot+'"'))+$ExtraArgs) -join ' '
    $info.WorkingDirectory = $ProjectRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'Could not start headless benchmark.' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTime]::UtcNow.AddSeconds(600)
        while (-not $process.WaitForExit(1000) -and [DateTime]::UtcNow -lt $deadline) { }
        if (-not $process.HasExited) { throw 'Headless pair benchmark exceeded 600 seconds.' }
        $output = $stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
        Set-Content -LiteralPath (Join-Path $currentRoot ('artifacts/'+$LogName+'.log')) -Encoding utf8 -Value $output
        if ($process.ExitCode -ne 0 -or $output -match '(?m)^(SCRIPT ERROR|ERROR):') { throw "Benchmark failed: $LogName" }
        Write-Output $output.TrimEnd()
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
}
Run-PairProcess $baselineRoot @('--editor','--import','--quit') 'enemy-pair-baseline-import'
$results = @()
foreach ($count in @(50,100,200)) {
    Write-Output "PAIR $count baseline"
    Run-PairProcess $baselineRoot @('--script','res://artifacts/benchmark-paired.gd','--','--automation','--silent','--baseline-physics',"--enemy-count=$count") "enemy-pair-before-$count"
    $beforePath = Join-Path $baselineArtifacts "enemy-physics-native-$count.json"
    Copy-Item -LiteralPath $beforePath -Destination (Join-Path $currentRoot "artifacts/enemy-pair-before-$count.json")
    $before = Get-Content -LiteralPath $beforePath -Encoding utf8 -Raw | ConvertFrom-Json
    Write-Output "PAIR $count optimized"
    Run-PairProcess $currentRoot @('--script','res://tools/benchmark-enemy-physics.gd','--','--automation','--silent',"--enemy-count=$count") "enemy-pair-after-$count"
    $afterPath = Join-Path $currentRoot "artifacts/enemy-physics-native-$count.json"
    $after = Get-Content -LiteralPath $afterPath -Encoding utf8 -Raw | ConvertFrom-Json
    Copy-Item -LiteralPath $afterPath -Destination (Join-Path $currentRoot "artifacts/enemy-pair-after-$count.json")
    if ($before.failures -ne 0 -or $after.failures -ne 0) { throw "Collision validation failed for $count enemies." }
    $results += @{ count=$count; before=$before.cases[0]; after=$after.cases[0] }
}
@{ engine=$after.engine; duration_seconds=20; warmup_seconds=2; baseline_path=$baselineRoot; cases=$results } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $currentRoot 'artifacts/enemy-physics-paired.json') -Encoding utf8
