検出結果の要約:

- 高優先: un_23850996453.log に DEBUG: provided_secret_len=5 hkdf_applied=True final_secret_sha256=<hash> とトークン生成のログが含まれています。JWT 署名鍵 (JWT_SECRET) を直ちにローテーションしてください。

- 中優先: haskell-server/tests/TestMain.hs にテスト用 JWT (goodToken) が含まれます。テスト専用であることを確認し、実トークンでないことを確認してください。

- 低優先: haskell-server/src/Auth.hs やドキュメントに inal_secret_sha256 などのハッシュが残っています。ハッシュ自体は秘匿情報ではありませんが、念のため確認して下さい。

対応済み:
- debug-archive* を履歴から削除済み。バックアップブランチ: ackup/prune-debug-20260402-205627。
- 既に Issue を作成済み: https://github.com/minamiyama-ryota/browser_tetris/issues/12

推奨アクション:
1. JWT_SECRET を直ちにローテーション（古いトークンを無効化）。
2. GitHub Actions の Secrets を更新。
3. 環境に新しい鍵をデプロイし、クライアントを更新。
4. 監査ログで不審なアクセスを確認。

完了したらこのIssueにコメントで報告してください.

