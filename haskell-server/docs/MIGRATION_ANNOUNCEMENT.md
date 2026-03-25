# JWT 移行のお知らせ

目的
- 本リポジトリで HS256 の検証ロジックを強化しました。短い共有シークレット（32 バイト未満）を受け取る場合、サーバ側では HKDF-SHA256 による 32 バイト鍵派生（info="hs256-derivation"）を行います。

影響範囲
- トークン発行側が既存の短いシークレットを使い続ける場合、検証側と一致させるために発行側でも同じ HKDF 派生を行して下さい。

推奨手順（簡易）
1. 発行側で以下の処理を行い、`final_secret` を得てから HS256 署名してください。

   - Python（既存スクリプトと同様）:

```bash
python elm-haskell/gen_jwt_cli.py "$JWT_SECRET" > token.txt
```

   - Node.js（例）:

```js
// examples/gen_jwt_node.js を参照
node examples/gen_jwt_node.js "$JWT_SECRET"
```

2. CI では `JWT_SECRET` を GitHub/GitLab secrets に保存し、テスト実行前にサンプルトークンを生成して検証してください。リポジトリには参考ワークフローを追加しました: `.github/workflows/ci.yml`。

ロールアウト提案
- ステージング環境でまず発行側を HKDF 化して検証が通ることを確認
- その後、本番発行側を順次切り替え（短時間並行運用が必要な場合は短命の互換トークンを許容する運用窓を用意）

補足
- 可能なら Vault 等で 32 バイト以上のランダム鍵を配布することを推奨します（HKDF は互換性維持のための救済手段です）。

問い合わせ
- 変更に関する質問・問題があればこのリポジトリの Issues に投稿してください。
