<#
.SYNOPSIS
  Rerun the GitHub Actions workflow for a given commit (or HEAD) and fetch logs/artifacts.

USAGE
  ./tools/rerun_ci_and_fetch.ps1 -Sha <commit-sha> -PollInterval 15 -TimeoutMinutes 30

Notes:
  - This script prefers the GitHub CLI (`gh`). Ensure `gh auth status` is configured or
    set `GITHUB_TOKEN` / `GH_TOKEN` environment variable for REST fallback.
  - Artifacts and logs are downloaded to `tools/ci_artifacts/`.
#>

param(
  [string]$Sha = '',
  [int]$PollInterval = 15,
  [int]$TimeoutMinutes = 30
)

Set-StrictMode -Version Latest

function FailIf([string]$msg) {
  Write-Error $msg
  exit 2
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$outDir = Join-Path $scriptRoot 'ci_artifacts'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

if (-not $Sha) {
  try {
    $Sha = (git rev-parse --verify HEAD).Trim()
  } catch {
    FailIf 'No commit SHA supplied and git rev-parse HEAD failed. Provide -Sha explicitly.'
  }
}

Write-Host "Target commit: $Sha"

if (Get-Command gh -ErrorAction SilentlyContinue) {
  Write-Host 'Using gh CLI for rerun and downloads.'

  # find an existing run for this sha
  $runsJson = gh run list --limit 50 --json databaseId,headSha,status,conclusion,createdAt | ConvertFrom-Json
  $orig = $runsJson | Where-Object { $_.headSha -eq $Sha } | Select-Object -First 1
  if (-not $orig) {
    FailIf "No workflow run found for commit $Sha"
  }
  $origId = $orig.databaseId
  Write-Host "Found existing run id $origId (status=$($orig.status) conclusion=$($orig.conclusion)). Triggering rerun..."

  gh run rerun $origId --confirm | Out-Null

  # Wait for a new run to appear (created after now)
  $startTime = Get-Date
  $deadline = $startTime.AddMinutes($TimeoutMinutes)
  $newRun = $null
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $PollInterval
    $recent = gh run list --limit 50 --json databaseId,headSha,status,conclusion,createdAt | ConvertFrom-Json
    $candidates = $recent | Where-Object { $_.headSha -eq $Sha } | Sort-Object {[DateTime]::Parse($_.createdAt)} -Descending
    $newRun = $candidates | Where-Object { $_.databaseId -ne $origId -and [DateTime]::Parse($_.createdAt) -gt $startTime } | Select-Object -First 1
    if ($newRun) { break }
  }
  if (-not $newRun) { FailIf 'Failed to detect rerun run id within timeout' }

  $newId = $newRun.databaseId
  Write-Host "Detected rerun id $newId; waiting for completion..."

  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $PollInterval
    $statusObj = gh run view $newId --json status,conclusion | ConvertFrom-Json
    Write-Host "status=$($statusObj.status) conclusion=$($statusObj.conclusion)"
    if ($statusObj.status -eq 'completed') { break }
  }

  $final = gh run view $newId --json status,conclusion | ConvertFrom-Json
  Write-Host "Run $newId finished: status=$($final.status) conclusion=$($final.conclusion)"

  Write-Host 'Downloading artifacts and logs to' $outDir
  gh run download $newId --dir $outDir --name '*' || Write-Warning 'gh run download returned non-zero (may be no artifacts)'
  gh run view $newId --log > (Join-Path $outDir "run_${newId}_log.txt") 2>&1 || Write-Warning 'Failed to save logs via gh run view'

  Write-Host 'Download complete. See:'
  Write-Host "  $outDir"
  exit 0
}

# Fallback: use GitHub REST API (requires GITHUB_TOKEN or GH_TOKEN env)
$token = $env:GITHUB_TOKEN
if (-not $token) { $token = $env:GH_TOKEN }
if (-not $token) { FailIf 'gh CLI not found and GITHUB_TOKEN/GH_TOKEN not set for REST fallback.' }

$owner = 'minamiyama-ryota'
$repo = 'browser_tetris'
$apiBase = "https://api.github.com/repos/$owner/$repo"
$headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json' }

Write-Host 'Using REST API fallback to trigger rerun.'

# find original run id for commit
$runsResp = Invoke-RestMethod -Uri "$apiBase/actions/runs?head_sha=$Sha&per_page=10" -Headers $headers -Method Get
if (-not $runsResp.workflow_runs -or $runsResp.total_count -eq 0) { FailIf "No workflow run found for commit $Sha via API" }
$origId = $runsResp.workflow_runs[0].id
Write-Host "Found run $origId; POST rerun"
Invoke-RestMethod -Uri "$apiBase/actions/runs/$origId/rerun" -Headers $headers -Method Post

# detect new run created after now
$startTime = Get-Date
$deadline = $startTime.AddMinutes($TimeoutMinutes)
$newId = $null
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds $PollInterval
  $r = Invoke-RestMethod -Uri "$apiBase/actions/runs?head_sha=$Sha&per_page=10" -Headers $headers -Method Get
  $candidates = $r.workflow_runs | Sort-Object {[DateTime]::Parse($_.created_at)} -Descending
  foreach ($c in $candidates) {
    $created = [DateTime]::Parse($c.created_at)
    if ($c.id -ne $origId -and $created -gt $startTime) { $newId = $c.id; break }
  }
  if ($newId) { break }
}
if (-not $newId) { FailIf 'Failed to detect rerun run id via API' }

Write-Host "Detected rerun id $newId; polling until completed..."
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds $PollInterval
  $info = Invoke-RestMethod -Uri "$apiBase/actions/runs/$newId" -Headers $headers -Method Get
  Write-Host "status=$($info.status) conclusion=$($info.conclusion)"
  if ($info.status -eq 'completed') { break }
}

Write-Host 'Downloading logs and artifacts via API'
# logs
$logsUrl = "$apiBase/actions/runs/$newId/logs"
$logsZip = Join-Path $outDir "run_${newId}_logs.zip"
Invoke-WebRequest -Uri $logsUrl -Headers $headers -OutFile $logsZip
try { Expand-Archive -Path $logsZip -DestinationPath (Join-Path $outDir "logs_$newId") -Force } catch { Write-Warning "Failed to expand $logsZip" }

# artifacts
$arts = Invoke-RestMethod -Uri "$apiBase/actions/runs/$newId/artifacts" -Headers $headers -Method Get
if ($arts.total_count -gt 0) {
  foreach ($a in $arts.artifacts) {
    $url = $a.archive_download_url
    $out = Join-Path $outDir "artifact_$($a.id)_$($a.name).zip"
    Invoke-WebRequest -Uri $url -Headers $headers -OutFile $out
    try { Expand-Archive -Path $out -DestinationPath (Join-Path $outDir "artifact_$($a.id)_$($a.name)" ) -Force } catch { Write-Warning "Failed to expand $out" }
  }
} else {
  Write-Host 'No artifacts found.'
}

Write-Host "Done. Artifacts/logs are in $outDir"
exit 0
