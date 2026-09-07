param(
    [Parameter(Mandatory=$true)][string]$Message,
    [Parameter(Mandatory=$true)][string[]]$Files
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if ($Message -notmatch '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert): .*[\u4e00-\u9fff]' -or $Message -match '[。.]$|[\r\n]') {
    throw 'Use a single-line Conventional Commit with a specific Simplified Chinese summary and no final period.'
}
& node tools/automation.mjs --check-report
if ($LASTEXITCODE -ne 0) { throw 'Acceptance gate rejected submission.' }
& git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { throw 'The index already contains staged changes. Review them before using this helper.' }
& git add -- $Files
if ($LASTEXITCODE -ne 0) { throw 'Could not stage the specified files.' }
& git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Staged diff check failed.' }
& git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw 'Commit failed.' }
& git push -u origin HEAD
if ($LASTEXITCODE -ne 0) { throw 'Push failed. Local commit retained; no force-push attempted.' }
