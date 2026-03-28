最小再現手順

- 目的: `jose` の `verifyClaimsAt` が短いシークレットで `JWSInvalidSignature` を返す現象を再現し、署名入力バイト列を比較する。
- 再現用コード: [app/DebugVerify.hs](elm-haskell/haskell-server/app/DebugVerify.hs#L1)

実行手順 (PowerShell):

1. サーバディレクトリへ移動:

   cd elm-haskell\haskell-server

2. ビルドおよび最小再現実行（デフォルトで `debug-verify` 実行ファイルを作成します）:

   stack build
   stack exec debug-verify -- dev-secret > debug_dev_secret.txt 2>&1
   stack exec debug-verify -- 01234567890123456789012345678901 > debug_32.txt 2>&1

生成されるファイル:

- `debug_dev_secret.txt`: 短いシークレット（例: `dev-secret`）での出力。ライブラリ検証失敗とローカルHMACフォールバックが記録されています。
- `debug_32.txt`: 32バイトのシークレットでの出力。`jose` による検証が成功します。

備考:

- 追加で自動化実行したい場合は、同ディレクトリにある `tools\run_minimal_repro.ps1` を実行してください。
