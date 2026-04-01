param(
  [string]$sha,
  [int]$timeoutSeconds = 120,
  [int]$pollInterval = 10
)

$deadline = (Get-Date).AddSeconds($timeoutSeconds)
while((Get-Date) -lt $deadline) {
  try {
    $runs = gh run list --limit 20 --json headSha,status,conclusion,createdAt,url | ConvertFrom-Json
  } catch {
    Write-Output 'gh_failed'
    Start-Sleep -Seconds 5
    continue
  }
  $run = $runs | Where-Object { $_.headSha -eq $sha } | Select-Object -First 1
  if ($null -ne $run) {
    Write-Output ($run | ConvertTo-Json -Compress)
    if ($run.status -eq 'completed') {
      exit 0
    }
  } else {
    Write-Output 'no_run_found'
  }
  Start-Sleep -Seconds $pollInterval
}
exit 3
