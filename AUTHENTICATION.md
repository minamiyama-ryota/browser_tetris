# 認証（HS256） — 変更点と注意事項

このリポジトリでは、Python 側で作成した HS256 トークンが Haskell 側で確実に検証できるよう、秘密鍵の正規化とデバッグの扱いを統一しました（PR: `ci/unify-auth-debug`）。主な点は以下の通りです。

- 秘密鍵の判定: テキスト文字列が Base64URL 表現（パディングなしを含む）であるかを「ラウンドトリップ」チェックで判定し、該当する場合はデコードしてバイト列として扱います。
- HKDF 派生: 提供されたシークレットが 32 バイト未満の場合、HKDF-SHA256（info = "hs256-derivation"）で 32 バイトに拡張します。これにより Python 側（PyJWT）と Haskell 側で同じ署名鍵を得ます。
- デバッグ制御: 検証/診断ログは環境変数 `DEBUG_VERIFY` または `AUTH_DEBUG` を有効にしたときのみ出力されます（CI ではデバッグ用に一時的に有効化）。すべての機密データが平文で出力されないよう注意しています。
- CI の診断: CI で生成される `gen_debug.txt`、`verify_debug.txt` をアップロードして、`final_secret_sha256` や計算署名とトークン署名の一致を確認できるようにしました。

関連ファイル:

- `haskell-server/src/Auth.hs` — Base64URL 判定 (`tryB64urlDecode`)、HKDF (`hkdfExtract`/`hkdfExpand`)、およびデバッグ出力の追加。
- `haskell-server/tests/TestHKDF.hs` — HKDF / Base64 のユニットテストを追加。
- `verify_token.py`（ルート / `elm-haskell/`）— Python 側の最小検証ツール（CI で `DEBUG_VERIFY=1` のときに詳細出力）。

ローカルでの再現手順:

```bash
# 1) トークン生成（Python）
python gen_jwt_cli.py "$JWT_SECRET" > token.txt

# 2) Python での簡易検証（デバッグ）
DEBUG_VERIFY=1 python verify_token.py "$JWT_SECRET" token.txt

# 3) Haskell 側テスト
cd haskell-server
stack test --no-terminal --coverage
```

注意:
- CI にデバッグ出力を残す設定は診断目的の一時措置です。マージ後は不要なデバッグをオフにしてください。
- 本実装では、文字列として渡されたシークレットが本当に Base64URL かを厳密に判定するため、偽陽性を避けるラウンドトリップチェックを行っています。

問題や追加テストの要望があれば指示してください。PR をレビューしてマージしてよい場合は合図ください。
