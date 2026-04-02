# browser_tetris
テトリス

## HS256 secret normalization (CI/unify-auth-debug)

このリポジトリでは、Python 側で生成した HS256 トークンを Haskell 側で確実に検証できるよう、秘密鍵の正規化ルールを統一しています。

- 仕様: テキストのシークレットを受け取った場合、まず Base64URL としてデコードできるか（再エンコードが元の unpadded 文字列と一致するか）を確認します。
- デコードに成功し、得られたバイト列が 32 バイト未満の場合は HKDF-SHA256(info="hs256-derivation") で 32 バイトに派生します。
- 文字列が Base64URL でない場合は生のバイト列として使用します（HKDF は適用しません）。

ローカルでの検証手順:

1. トークン生成（Python）:
```bash
python gen_jwt_cli.py "$JWT_SECRET" > token.txt
```
2. Haskell 側で検証:
```bash
cd haskell-server
stack test    # または debug-verify 実行
```

CI ではデバッグ用に `gen_debug.txt` / `verify_debug.txt` を出力してアーティファクトとしてアップロードします。問題が発生した場合はこれらのログを確認してください。

リリース:

- v0.1.1 — Unify HS256 secret normalization, HKDF derivation, tests and CI improvements.
- リリースページ: https://github.com/minamiyama-ryota/browser_tetris/releases/tag/v0.1.1

