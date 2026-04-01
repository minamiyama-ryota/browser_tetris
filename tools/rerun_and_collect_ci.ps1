Param(
    [Parameter(Mandatory=$true)]
    [long]$oldRun,
    [int]$timeoutMinutes = 60
)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh CLI not found; install and authenticate before running this script."
    exit 2
}

Write-Host "Requesting rerun of run $oldRun"
gh run rerun $oldRun | Write-Host

$head = gh run view $oldRun --json headSha -q .headSha 2>$null
if (-not $head) {
    Write-Host "Warning: could not determine original headSha; continuing to look for new run entries."
}
else {
    Write-Host "Original headSha: $head"
}

$deadline = (Get-Date).AddMinutes($timeoutMinutes)
$newRun = $null

while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    $listJson = gh run list --limit 20 --json runNumber,headSha,status,conclusion 2>$null
    if (-not $listJson) { Write-Host "gh run list returned empty; retrying..."; continue }
    try {
        $runs = $listJson | ConvertFrom-Json
    } catch {
        Write-Host "Failed to parse gh run list JSON; retrying..."; continue
    }
    if ($head) {
        $match = $runs | Where-Object { $_.headSha -eq $head -and $_.runNumber -gt $oldRun } | Sort-Object runNumber -Descending | Select-Object -First 1
    } else {
        $match = $runs | Where-Object { $_.runNumber -gt $oldRun } | Sort-Object runNumber -Descending | Select-Object -First 1
    }
    if ($match) {
        $newRun = $match.runNumber
        Write-Host "Found new run: $newRun (status: $($match.status))"
        break
    }
    Write-Host "Waiting for new run to appear..."
}

if (-not $newRun) {
    Write-Error "Timed out waiting for new run to appear"
    exit 3
}

# Wait for completion
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 10
    $sjson = gh run view $newRun --json status,conclusion 2>$null
    if (-not $sjson) { Write-Host "no status json; retry"; continue }
    $s = $sjson | ConvertFrom-Json
    Write-Host "Run $newRun status: $($s.status) conclusion: $($s.conclusion)"
    if ($s.status -eq 'completed') { break }
}

$logPath = "tools/full_run_${newRun}.log"
Write-Host "Downloading logs to $logPath"
gh run view $newRun --log > $logPath

$artifactDir = "tools/ci_artifacts"
if (-not (Test-Path $artifactDir)) { New-Item -ItemType Directory -Path $artifactDir | Out-Null }
Write-Host "Downloading artifacts to $artifactDir"
gh run download $newRun --dir $artifactDir 2>&1 | Write-Host

Write-Host "Done. New run: $newRun. Logs saved to $logPath; artifacts to $artifactDir"
exit 0
