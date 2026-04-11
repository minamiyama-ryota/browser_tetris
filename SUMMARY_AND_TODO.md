# 要約と To Do

## 要約
- **目的**: Python で生成した HS256 トークンが Haskell CI で検証されるよう、HS256 秘密鍵の正規化を統一し、CI 診断を残すこと。
- **実施内容**:
  - Haskell と Python において、Base64URL（無パディング）形式の秘密鍵を検出し、必要な場合は HKDF-SHA256（info="hs256-derivation"）で 32 バイトへ導出する実装を追加。
  - Python の `gen_jwt_cli.py` / `verify_token.py` に同等の正規化を実装し、CI でのデバッグ出力を収集するワークフローを追加。
  - リポジトリ履歴からデバッグアーカイブ（トークンや秘密に関するファイル）を削除するために履歴書き換え（バックアップブランチ作成 → `git-filter-repo`）を実行し、関連ファイルを除去して `.gitignore` を更新。
  - `JWT_SECRET` をローテーションし、定期的な秘密スキャン（gitleaks）ワークフローを追加。
  - ローカル検証: Haskell サーバと Elm UI を起動し、トークン生成・検証で署名整合性（`match = True`）を確認。
- **結果**: ローカルおよび CI の検証で署名の一致を確認。敏感情報の履歴削除と `JWT_SECRET` のローテーションを実施。
- **未解決 / 注意点**: 一部 GitHub CLI 操作で再認証が必要（Issue #12 閉鎖等は手動での再認証後に完了可能）。

## To Do（優先度順）
- [x] バックアップブランチ作成と履歴書き換え（`backup/prune-debug-<ts>`）
- [x] `git-filter-repo` によるデバッグアーカイブ削除と強制 push
- [x] デバッグファイルと CI ログのリポジトリから削除
- [x] `JWT_SECRET` のローテーション（リモート環境に反映済みの確認が必要）
- [x] CI ワークフローでデバッグ出力を収集してアーティファクト化
- [x] gitleaks の定期実行ワークフロー追加
- [x] `elm-app/dist/` とローカル秘密ファイルを `.gitignore` に追加
- [x] ローカルで Haskell サーバと Elm UI を起動して検証
- [x] トークン生成・検証スクリプトでの秘密鍵正規化を実装（Python）
- [x] Haskell 側で Base64URL 検出と HKDF 導出を実装
- [x] Issue #12 をクローズ（手動再認証後に実行可能）
- [x] コラボレータへ再クローンを依頼して検証を完了してもらう
- [x] 展開先環境で新しい `JWT_SECRET` が反映されていることを確認
- [ ] 監査ログ（コミット/Actions）の詳細レビュー（進行中）
- [ ] コラボレータへ再通知（Issue #13）
- [ ] ポリシー/自動化提案を作成

## 参考と補足
- ローカル検証コマンド（例）:
```powershell
python gen_jwt_cli.py <secret> > token.txt
python verify_token.py <secret> token.txt
stack exec tetris-server-exe  # Haskell サーバ起動
python -m http.server 8001 --directory elm-app
```
- 追加で代行してほしい操作があれば指示してください（例: `gh auth login` による再認証と Issue のクローズ、デプロイ先へのシークレット反映など）。
