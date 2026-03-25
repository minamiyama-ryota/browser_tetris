# 実行用: 最小再現をビルドして両方のシークレットで出力を取得します
Set-Location -Path "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)\..\"
cd elm-haskell\haskell-server

Write-Host "Building..."
stack build

Write-Host "Running with short secret (dev-secret)..."
stack exec debug-verify -- dev-secret > debug_dev_secret.txt 2>&1

Write-Host "Running with 32-byte secret..."
stack exec debug-verify -- 01234567890123456789012345678901 > debug_32.txt 2>&1

Write-Host "Done. Outputs: debug_dev_secret.txt, debug_32.txt"
