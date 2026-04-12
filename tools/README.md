# tools ディレクトリについて

このディレクトリには CI および集計で使う補助スクリプトが含まれます。

主なスクリプト:

- `aggregate_auth_debug.py` — GitHub Actions の `auth-debug` アーティファクトを集計して `downloads-aggregate/auth_debug_summary.csv` を生成します。
  使用例: `python tools/aggregate_auth_debug.py --limit 50 --out downloads-aggregate`

- `check_csv_diff.py` — 生成された CSV の差分を簡易チェックします。
  使用例: `python tools/check_csv_diff.py current.csv --prev previous.csv --verbose`

- `run_jwt_integration.py` — ローカルで統合テストやワークフロー再現を助ける補助スクリプト。
- `remote_rerun_and_wait.ps1` — GitHub Actions を再実行して結果を待つ PowerShell ヘルパー。

推奨事項:

- ワークフロー（例: `.github/workflows/aggregate-auth-debug.yml`）は `actions/checkout@v4` を用いてリポジトリをチェックアウトします。夜間集計やワークフローからスクリプトを参照できるよう、これらのスクリプトはデフォルトブランチ（`main`）に常にコミットしておいてください。
- 差分検出で CI を失敗させたい場合はリポジトリシークレット `AUTH_DEBUG_DIFF_FAIL=1` を設定してください（このリポジトリでは既に設定済みです）。

メンテナンス:

- スクリプトを修正した際は `tools/` を含めた PR を作成してください。ワークフローは存在しない場合に既知ブランチや `origin/main` からファイルを復元しようとしますが、確実性のためデフォルトブランチへの配置をおすすめします。
