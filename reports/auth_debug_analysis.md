# 認証デバッグ解析レポート

日付: 2026-04-08

対象ラン: https://github.com/minamiyama-ryota/browser_tetris/actions/runs/24029780042

取得アーティファクト:
- `downloads/gen_debug.txt` (CI 生成デバッグ)
- `downloads/token.txt` (生成トークン)
- `downloads/verify_debug.txt` (検証デバッグ — このランでは無効)

要約:
- `gen_debug.txt` によれば `provided_secret_len=43`、`hkdf_applied=False`、`final_secret_sha256=a5f1ef4ad9347f4a735c51cc338be8525d285ec332428a264b2e8b063c9f3e66` が記録されています。
- 署名関連: トークンに含まれる署名とローカル計算による署名が一致しています（base64url 表記および hex 表記で一致）。
- `verify_debug.txt` は `DEBUG disabled` であり、検証側の詳細ログはこのランでは出力されていません。

所見:
- この実行では HS256 の署名計算は一致しており、生成側と検証側で署名アルゴリズムの実装差が原因で失敗している痕跡は見当たりません。
- `hkdf_applied=False` のため、当該ランでは秘密鍵の HKDF 導出が行われていません（つまり生成パスは導出を必要としない形式の入力を受け取った、または導出ロジックが未適用でした）。
- 検証側の詳細がないため、最終的な正規化経路（生成→導出→署名、検証→正規化→検証）が完全に確認できていません。

推奨アクション:
1. `DEBUG_VERIFY=1`（workflow input `debug_verify=1`）でワークフローを再実行し、`verify_debug.txt` を収集してください。コマンド例:

```
gh workflow run ci.yml -f debug_verify=1
```

2. 再実行後、該当ランから `auth-debug` アーティファクトをダウンロードして（`gen_debug.txt`, `token.txt`, `verify_debug.txt`）、検証ログに `hkdf_applied` の挙動と最終署名比較を確認します:

```
gh run download <run-id> --name auth-debug --dir ./downloads
```

3. `DEBUG_VERIFY` は引き続きワークフロー入力で制御し、不要な公開を避けてください（現状はデフォルトで無効になっています）。

添付・報告方法（Issue 用テンプレ）:
- 添付: `gen_debug.txt`, `verify_debug.txt`, `token.txt`（必要時）
- 非推奨: 生の `JWT_SECRET` を Issue コメントや公開ログに貼ること

Issue コメント案（コピーして貼付可）:

```
調査報告: CI の `auth-debug` アーティファクトを解析しました。

- 対象ラン: https://github.com/minamiyama-ryota/browser_tetris/actions/runs/24029780042
- 結果: `gen_debug.txt` によると署名は生成側と一致しました（`final_secret_sha256` が記録されています）。検証側ログは当該ランで無効でした。

次の手順として、`debug_verify=1` でワークフローを再実行し、`verify_debug.txt` を取得して検証の詳細（HKDF 適用の有無、署名計算の各中間値）を確認してください。私が再実行とアーティファクト取得を代行可能です。

添付ファイル: gen_debug.txt, token.txt, verify_debug.txt
```

備考: 本レポートはアーティファクト内のハッシュ・署名の照合を元に作成しています。生の秘密（`JWT_SECRET`）は含めていません。
