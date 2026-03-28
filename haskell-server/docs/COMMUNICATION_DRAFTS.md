# 発行者向け通知テンプレート / Issuer Notification Drafts

## 日本語 — メールテンプレート
件名: 【重要】JWT 発行方式の変更について（HS256 鍵派生の導入）

本文:
お世話になっております。

この度、`elm-haskell` リポジトリ内の認証検証ロジックを強化しました。短い共有シークレット（32 バイト未満）を用途に使っている場合、サーバ側では一貫性と安全性を保つために HKDF-SHA256 による 32 バイト鍵派生（info="hs256-derivation"）を適用してトークンを検証します。

影響:
- 発行側で短いシークレットを用いる場合、現在のトークンは検証に失敗する可能性があります。

対応方法（すぐにできる手順）:
1. 発行コードでトークン署名前に以下の処理を行い、`final_secret` を得てから HS256 署名してください。

   - Python 例（参考）：`python elm-haskell/gen_jwt_cli.py "$JWT_SECRET" > token.txt`

   - Node.js 例（参考）：`node examples/gen_jwt_node.js "$JWT_SECRET"`

2. CI では `JWT_SECRET` を Secret に保存し、テスト実行前にサンプルトークンを生成して検証してください。参照: `.github/workflows/ci.yml`。

推奨:
- 可能なら Vault 等で 32 バイト以上のランダム鍵を配布してください。HKDF は互換性維持のための手段です。

お問い合わせ:
- この変更について問題があれば本リポジトリの Issue にご連絡ください。


## 日本語 — Slack 短文（例）
FYI: JWT 検証強化を行い、短いシークレット使用時は HKDF(SHA256, info="hs256-derivation") で 32B 派生する必要があります。詳しくはリポジトリの docs を参照してください。


## English — Email template
Subject: [Action Required] JWT issuer update — HS256 key derivation

Body:
Hello,

We updated the JWT verification logic in the `elm-haskell` repository to strengthen HS256 verification. When a shared secret shorter than 32 bytes is used, the server now derives a 32-byte key via HKDF-SHA256 (info="hs256-derivation") before verification.

Impact:
- Tokens issued without this derivation may fail verification.

Remediation (quick steps):
1. On the issuer side, derive `final_secret` via HKDF-SHA256 using `info = "hs256-derivation"` when the raw secret is shorter than 32 bytes, and use `final_secret` for HS256 signing.

   - Python example: `python elm-haskell/gen_jwt_cli.py "$JWT_SECRET" > token.txt`
   - Node.js example: `node examples/gen_jwt_node.js "$JWT_SECRET"`

2. In CI, store `JWT_SECRET` as a secret and generate a sample token before running tests. See `.github/workflows/ci.yml` for reference.

Recommendation:
- Prefer distributing 32-byte (or longer) random keys via Vault or similar; HKDF is a compatibility mechanism.

Contact:
- If you encounter problems, please open an Issue in the repository.


## English — Slack short message
FYI: JWT verification tightened — if your issuer uses secrets <32B, derive a 32-byte key via HKDF-SHA256 (info="hs256-derivation") before HS256 signing. See repo docs.
