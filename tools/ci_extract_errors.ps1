param(
  [string]$log = "tools\\ci_run_031cd70.log",
  [int]$max = 200
)

if (-Not (Test-Path $log)) {
  Write-Output 'log_not_found'
  exit 2
}

$matches = Select-String -Path $log -Pattern 'error|failed|FAIL|Exception|Traceback' -SimpleMatch
if ($null -eq $matches -or $matches.Count -eq 0) {
  Write-Output '[]'
  exit 0
}

$lines = $matches | Select-Object -First $max | ForEach-Object { $_.Line.Trim() }
$lines | ConvertTo-Json -Compress
exit 0
