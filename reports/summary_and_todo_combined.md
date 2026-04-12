# 要約と ToDo（まとめ）

- [x] シークレット有効化検討 — `AUTH_DEBUG_DIFF_FAIL` をリポジトリシークレットに設定済み
- [x] 短い検証実行 — ローカルでのスクリプト動作確認を完了
- [x] リモート CI 検証 — ワークフローの再実行と集計の確認を実施
- [ ] シークレット有効化検討 — `AUTH_DEBUG_DIFF_FAIL` をリポジトリシークレットに設定するか検討
- [x] 追加統合テスト作成 — `tests/test_jwt_integration.py` を追加しローカルで合格を確認
- [x] ドキュメント反映確認 — `docs/auth_debug_policy.md` 等を更新
- [ ] 観察期間の監視 — ナイトリー実行等で差分頻度を監視（未完）
 4. `tools/aggregate_auth_debug.py` と `tools/check_csv_diff.py` をデフォルトブランチへ配置済み（`tools/README.md` を追加）。
- [x] main 以外のブランチ削除 — 完了（origin 側の整理）
- [x] 不要なファイル削除 — 完了（該当ファイルを削除）
- [x] 要約/ToDo Markdown 出力 — 本ファイルに出力済み
- [x] ワークフロー修正 PR（既存） — 作成・反映済み（PR #20 等）
- [x] CI に pytest 実行追加 — コミット・PR 作成済み（PR #22）
- [ ] リモート CI 認証設定 — 必要に応じて GH CLI 認証方法を整備
- [x] Elm ビルドとローカル配信確認 — `elm-app/dist/main.js` を生成し配信済み

## 次の優先アクション（推奨）

1. `AUTH_DEBUG_DIFF_FAIL` をリポジトリシークレットに設定するか決定し、必要なら設定する（差分時に CI を失敗させるオプション）。
2. 数日〜1週間の観察期間を設けて差分の頻度を確認し、false positive が多ければ差分判定キーや生成ロジックを調整する。
3. PR https://github.com/smtsgth/browser_tetris/pull/22 （CI: run pytest integration tests）をレビューしてマージし、CI 上で tests が確実に実行されることを確認する。
4. `tools/aggregate_auth_debug.py` と `tools/check_csv_diff.py` を default branch に移すか、ワークフローで確実にチェックアウトされる配置に改善する。
5. 必要なら追加の統合テスト（トークンライフサイクル、複数アルゴリズム等）を CI に組み込む。

## 関連ファイル

- [tools/aggregate_auth_debug.py](tools/aggregate_auth_debug.py)
- [tools/check_csv_diff.py](tools/check_csv_diff.py)
- [tools/remote_rerun_and_wait.ps1](tools/remote_rerun_and_wait.ps1)
- [tools/run_jwt_integration.py](tools/run_jwt_integration.py)
- [tests/test_jwt_integration.py](tests/test_jwt_integration.py)
- [.github/workflows/ci.yml](.github/workflows/ci.yml)
- [elm-app/index.html](elm-app/index.html)
- [elm-app/dist/main.js](elm-app/dist/main.js)
- [downloads-aggregate/auth_debug_summary.csv](downloads-aggregate/auth_debug_summary.csv)

## 参照 PR

- ワークフロー修正 PR（旧）: https://github.com/minamiyama-ryota/browser_tetris/pull/20
- 不要ファイル削除 PR（旧）: https://github.com/minamiyama-ryota/browser_tetris/pull/21
- CI に pytest 追加（本リポジトリ）: https://github.com/smtsgth/browser_tetris/pull/22

---

ファイル: [reports/summary_and_todo_combined.md](reports/summary_and_todo_combined.md)
