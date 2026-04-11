# 要約と ToDo（まとめ）

**作成日**: 2026-04-11

## 要約

- CSV差分検査ツール `tools/check_csv_diff.py` を追加。差分があると exit code 2 を返す実装。
- 集計スクリプト `tools/aggregate_auth_debug.py` を修正し、既存の `auth_debug_summary.csv` を `auth_debug_summary.prev.csv` としてバックアップしてから新しいCSVを書き、差分チェックを呼び出すようにした。
- CI ワークフロー `.github/workflows/aggregate-auth-debug.yml` を更新し、集計後に `tools/check_csv_diff.py` を実行するステップを追加。シークレット `AUTH_DEBUG_DIFF_FAIL` により差分時のジョブ失敗を制御する。
- ドキュメント `docs/auth_debug_policy.md` に「CSV 差分チェック運用」とトリアージ手順を追記。
- ブランチ整理: 主要なリモート/ローカルブランチを `main` に統合し、`main` 以外のブランチを削除した。
- 不要ファイル削除: `artifacts` / `ci-artifacts` / `downloads` をリポジトリから削除し、変更を `origin/main` に push した（コミット済み）。
- 短い検証: `python -m py_compile` と `--help` 出力で `tools/check_csv_diff.py` と `tools/aggregate_auth_debug.py` の構文・ヘルプを確認。ローカルで Python 3.13.12 にて動作確認済み。

## ToDo（現状）

- [x] 短い検証実行 — 完了
- [-] リモートCI検証 — 進行中
- [ ] シークレット有効化 — 未開始 (`AUTH_DEBUG_DIFF_FAIL` 等)
- [ ] 追加統合テスト実行 — 未開始
- [x] ドキュメント反映確認 — 完了
- [ ] 観察期間の監視 — 未開始
- [x] 全ブランチをmainへ統合 — 完了
- [x] main以外のブランチ削除 — 完了
- [x] 不要なファイル削除 — 完了
- [x] 要約/ToDo Markdown出力 — 完了

## 次の優先アクション（推奨）

1. リモートで CI ワークフローを実行して実運用ログを確認する（差分発生時の挙動確認）。
2. 必要なら `AUTH_DEBUG_DIFF_FAIL` をリポジトリのシークレットとして設定して差分時にジョブを失敗させる。
3. 観察期間中に差分が頻繁に出るか確認し、false positive の原因があれば修正する（キー指定や生成ロジックの見直し）。

---

ファイル: [reports/summary_and_todo_combined.md](reports/summary_and_todo_combined.md)
