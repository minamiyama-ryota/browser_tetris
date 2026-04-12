param(
  [string]$Workflow = 'ci.yml',
  [string]$Ref = 'main',
  [int]$PollSeconds = 15,
  [int]$MaxMinutes = 20
)

Write-Output "gh location: $(try { (Get-Command gh -ErrorAction SilentlyContinue).Source } catch { 'not found' })"
Write-Output "where gh:"
where.exe gh 2>&1 | Write-Output

# Attempt to dispatch the workflow
Write-Output "Dispatching workflow '$Workflow' to ref '$Ref'..."
$dispatchOutput = & gh workflow run $Workflow --ref $Ref 2>&1
Write-Output $dispatchOutput
if ($LASTEXITCODE -ne 0) {
  Write-Output "Dispatch returned non-zero (may be unsupported). Will try rerunning the latest run instead."
  $latestJson = & gh run list --workflow $Workflow --limit 1 --json databaseId,status,conclusion,createdAt 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to list runs: $latestJson"
    exit 1
  }
  try { $latest = $latestJson | ConvertFrom-Json } catch { Write-Error "Failed to parse latest run JSON: $latestJson"; exit 1 }
  if ($latest -is [System.Array]) { $run = $latest[0] } else { $run = $latest }
  Write-Output "Rerunning existing run: $($run.databaseId)"
  & gh run rerun $run.databaseId 2>&1 | Write-Output
  if ($LASTEXITCODE -ne 0) { Write-Error "Failed to rerun latest run"; exit 1 }
} else {
  Write-Output "Dispatch issued (if supported). Waiting briefly for run to appear..."
}

Start-Sleep -Seconds 5

# Find latest run id
$latestJson = & gh run list --workflow $Workflow --limit 1 --json databaseId,status,conclusion,createdAt 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to list runs after dispatch: $latestJson"; exit 1 }
try { $latest = $latestJson | ConvertFrom-Json } catch { Write-Error "Failed to parse latest run JSON: $latestJson"; exit 1 }
if ($latest -is [System.Array]) { $run = $latest[0] } else { $run = $latest }
$runId = $run.databaseId
Write-Output "Monitoring run id: $runId (createdAt: $($run.createdAt))"

$deadline = (Get-Date).AddMinutes($MaxMinutes)
while ((Get-Date) -lt $deadline) {
  $viewJson = & gh run view $runId --json status,conclusion 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Output "gh run view failed: $viewJson"
  } else {
    try { $statusObj = $viewJson | ConvertFrom-Json } catch { Write-Output "Failed to parse run view JSON: $viewJson"; Start-Sleep -Seconds $PollSeconds; continue }
    Write-Output ("Status: {0}; Conclusion: {1}" -f $statusObj.status, $statusObj.conclusion)
    if ($statusObj.status -eq 'completed') {
      Write-Output ("Run {0} completed with conclusion: {1}" -f $runId, $statusObj.conclusion)
      exit 0
    }
  }
  Start-Sleep -Seconds $PollSeconds
}

Write-Error "Timeout waiting for run $runId to complete (waited $MaxMinutes minutes)"
exit 2
