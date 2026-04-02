param(
  [int]$TimeoutMinutes = 30,
  [int]$PollInterval = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Fail([string]$msg) {
  Write-Error $msg
  exit 2
}

try {
  $sha = (git rev-parse --verify HEAD).Trim()
} catch {
  Fail 'git rev-parse HEAD failed'
}

Write-Host "HEAD: $sha"

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$run = $null
while ((Get-Date) -lt $deadline) {
  try {
    $listJson = gh run list --limit 50 --json databaseId,headSha,status,conclusion,createdAt 2>$null
  } catch {
    Write-Host "gh run list failed: $_; retrying in $PollInterval seconds"
    Start-Sleep -Seconds $PollInterval
    continue
  }
  if (-not $listJson) {
    Write-Host "gh run list returned empty; retrying in $PollInterval seconds"
    Start-Sleep -Seconds $PollInterval
    continue
  }
  try {
    $list = $listJson | ConvertFrom-Json
  } catch {
    Write-Host "Failed to parse gh run list JSON; retrying in $PollInterval seconds"
    Start-Sleep -Seconds $PollInterval
    continue
  }

  $run = $list | Where-Object { $_.headSha -eq $sha } | Select-Object -First 1
  if (-not $run) {
    Write-Host "no_run_found_for_sha; retrying in $PollInterval seconds"
    Start-Sleep -Seconds $PollInterval
    continue
  }

  Write-Host "Found run: id=$($run.databaseId) status=$($run.status) conclusion=$($run.conclusion) createdAt=$($run.createdAt)"
  if ($run.status -eq 'completed') { break }
  Write-Host "run not completed yet; sleeping $PollInterval seconds"
  Start-Sleep -Seconds $PollInterval
}

if (-not $run) { Fail 'timed_out_no_run' }

$id = $run.databaseId
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$outDir = Join-Path $scriptRoot 'ci_artifacts'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

Write-Host "Downloading artifacts/logs for run $id to $outDir"
try {
  gh run download $id --dir $outDir 2>&1 | Write-Host
} catch {
  Write-Warning "gh run download failed: $_"
}

try {
  gh run view $id --log > (Join-Path $outDir "run_${id}_log.txt") 2>&1
} catch {
  Write-Warning "gh run view --log failed: $_"
}

try {
  gh run view $id --json status,conclusion,createdAt | ConvertFrom-Json | ConvertTo-Json -Compress > (Join-Path $outDir "run_${id}_info.json")
} catch {
  Write-Warning "gh run view --json failed: $_"
}

Write-Host 'done'
exit 0
