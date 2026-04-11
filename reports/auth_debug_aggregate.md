# auth-debug 集計レポート

日付: 2026-04-09

ソース: [downloads-aggregate/auth_debug_summary.csv](downloads-aggregate/auth_debug_summary.csv)

概要:
- 処理済ラン数: 7
- `verify_debug` が出力されているラン: 1 （24133893372）
- `verify_debug` が無いラン: 24029780042, 24029687804, 24002412662, 24001681104, 24001606899, 23946515377
- HKDF 適用（`hkdf_applied=True`）のラン: 0
- 一意の `final_secret_sha256`: 1（a5f1ef4ad9347f4a735c51cc338be8525d285ec332428a264b2e8b063c9f3e66）
- 署名不一致の検出: 0（各ランで生成側の計算署名はトークン内署名と一致、`verify_debug` があるランでも `match = True`）

ラン詳細（要約）:

- 24133893372 — `hkdf_applied=False`, `match=True`（`verify_debug` あり）
- 24029780042 — `hkdf_applied=False`, `verify_debug` なし
- 24029687804 — `hkdf_applied=False`, `verify_debug` なし
- 24002412662 — `hkdf_applied=False`, `verify_debug` なし
- 24001681104 — `hkdf_applied=False`, `verify_debug` なし
- 24001606899 — `hkdf_applied=False`, `verify_debug` なし
- 23946515377 — `hkdf_applied=False`, `verify_debug` なし

所見:
- 解析したランでは署名の一致に問題は見つかりませんでした。生成側（`gen_debug.txt`）と検証側（`verify_debug.txt`）で計算された署名が一致しています。
- ほとんどのランで `verify_debug.txt` が出力されておらず、検証側の詳細ログが取得できていません（`DEBUG_VERIFY` がデフォルト無効になっているため）。
- 全ランで同じ `final_secret_sha256` が使われており、同一の（導出後の）秘密が継続利用されていることを示しています。

推奨アクション:
1. 代表的な数回分（例: 過去7回のうち3回）を `debug_verify=1` で再実行し、`verify_debug.txt` を収集してより広範な検証を行う。
2. CI における検証失敗（`match != True`）をアラート/失敗条件に含める短いチェックを追加する（任意で `debug_verify` をオンにしたときに有効化）。
3. `hkdf_applied` の変化や `final_secret_sha256` の差分を検出する監視スクリプトを定期実行する（`tools/aggregate_auth_debug.py` を利用可）。
4. 本集計CSV（`downloads-aggregate/auth_debug_summary.csv`）を Issue #13 に添付・追記して関係者へ共有する。

ファイル: 集計CSV と生データ
- CSV: [downloads-aggregate/auth_debug_summary.csv](downloads-aggregate/auth_debug_summary.csv)
- 各ランの生データ: `downloads-aggregate/<run-id>/raw/` に保存済み
