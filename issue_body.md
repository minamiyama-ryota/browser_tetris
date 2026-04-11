概要:
リポジトリ内のデバッグアーカイブ (debug-archive*) に JWT トークンや `final_secret_sha256` が含まれていることを確認しました。既に履歴書き換えでこれらのファイルは削除しましたが、念のため下記の対応をお願いします。

影響範囲:
- JWT署名鍵（例: `JWT_SECRET`）のローテーション
- GitHub Actions Secrets の更新
- APIキー／サービスキーのローテーション（該当する場合）

検出例:
- ci_artifacts/auth-debug/token.txt（JWT）
- ci_artifacts/auth-debug/gen_debug.txt / verify_debug.txt
- ci_artifacts/gen-debug-report/*.json

推奨アクション:
1. 直ちに JWT 署名鍵をローテーションし、古いトークンを失効させる（可能なら）。
2. GitHub Actions の `Settings → Secrets` を更新する。
3. 全デプロイ環境で新しい鍵に切替え、クライアントも更新する。
4. 監査ログを確認して不審なアクセスがないか調査する。
5. 回復用ブランチ: `backup/prune-debug-20260402-205627` を作成済み。

備考:
- 履歴書き換えを行ったため、全員がリポジトリを再クローンする必要があります。手順が必要なら追って共有します。

対応完了したらこのIssueで報告してください。
