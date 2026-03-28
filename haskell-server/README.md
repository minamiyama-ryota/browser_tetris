Haskell サーバ（簡易手順）

前提: Stack がインストールされていること

簡易セットアップ:
1. `stack setup`
2. `cd haskell-server`
3. `stack build`
4. `stack exec tetris-server-exe` でサーバを起動（WebSocket ポート 8000）

このサーバは最小の WebSocket エコーサーバです。Elm 側とメッセージ仕様（JSON 形式のコマンド）を決めて通信を進めます。

セキュリティと JWT に関する注意
- 本リポジトリのサーバ実装では、以前あった短いシークレットに対するローカル HMAC フォールバックを削除しました。
- 本番では `JWT_SECRETS_VAULT_PATH` で Vault から鍵を取得するか、各発行者が 32 バイト以上の鍵または HKDF-SHA256 による鍵派生を用いるようにしてください。詳細は [docs/JWT_SECRETS_VAULT.md](docs/JWT_SECRETS_VAULT.md) を参照してください。