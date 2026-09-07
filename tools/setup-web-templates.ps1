$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runtimeRoot = Join-Path $projectRoot '.runtime'
$templateRoot = Join-Path $runtimeRoot 'templates'
if (Test-Path -LiteralPath (Join-Path $templateRoot 'web_nothreads_release.zip')) { exit 0 }
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
$archive = Join-Path $runtimeRoot 'templates.tpz'
$expected = '003aa33743f58fb657717f090fc872ed3975e48d08a6012201a2259970d458a63d4d8a83090585307c23455ebfa4e6e0050e1057761c34863536095e3fcfab6c'
if (-not (Test-Path -LiteralPath $archive)) {
    & curl.exe -fLsS --retry 2 -o $archive 'https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_export_templates.tpz'
    if ($LASTEXITCODE -ne 0) { throw 'Export-template download failed.' }
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash -ne $expected) { throw 'Export-template SHA-512 mismatch.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
    New-Item -ItemType Directory -Force -Path $templateRoot | Out-Null
    foreach ($name in @('web_nothreads_release.zip', 'web_nothreads_debug.zip')) {
        $entry = $zip.GetEntry('templates/' + $name)
        if (-not $entry) { throw "Missing Web template: $name" }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templateRoot $name), $true)
    }
} finally { $zip.Dispose() }
