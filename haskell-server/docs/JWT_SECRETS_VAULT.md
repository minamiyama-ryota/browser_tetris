設計: JWT_SECRETS の安全な取得（Vault 統合案）

目的
- 平文環境変数による秘密の管理をやめ、プロダクション向けに安全な秘密ストア（例: HashiCorp Vault）から取得する設計を提示する。

要件
- 起動時に必要な鍵（kid -> base64url(secret) マップ）を安全に取得する。
- 本番では Vault から取得し、必要に応じて定期的にリロード（キー回転）できる。
- Vault からは最小限の情報（鍵のみ）を取得し、ログには秘密を出力しない。
- 本リポジトリのサーバ実装ではローカル互換のための自動的な HMAC フォールバックを削除しました。プロダクション環境では短い生のシークレットに依存せず、下記のいずれかを遵守してください。
   - 32 バイト以上の生シークレットを配布する（推奨）。
   - トークン発行側と検証側の両方で HKDF-SHA256 による鍵派生（info="hs256-derivation"）を行い、一貫した 32 バイト鍵を使用する。
   - あるいは Vault を用いて安全に長い鍵を管理する。

高レベル設計
1. 設定ソースの優先順位
   - 環境変数 `JWT_SECRETS_VAULT_PATH` が指定されていれば Vault を使用。
   - それ以外は `JWT_SECRETS`（JSON map）または単一の `JWT_SECRET` を使用（互換性保持）。

2. 起動フロー
   - 起動時に Vault クライアントを初期化（VAULT_ADDR, VAULT_TOKEN 等を使用）。
   - 指定されたパスから JSON マップを取得。形式例: `{ "kid1": "base64urlsecret1", "kid2": "base64urlsecret2" }`。
   - 取得した map をアプリ内の読み取り専用キャッシュに保持。
   - オプション: TTL/Watch 機能で周期的に再取得して回転を反映。

3. 実装のポイント（Haskell）
   - 依存: `http-client`, `http-client-tls`, `aeson`。
   - Vault 呼び出しは短時間で失敗する可能性があるのでエラー処理とリトライを設ける。
   - シークレットは `ByteString` で扱い、ログ出力や例外メッセージに含めない。
   - API:
     - `fetchJwtSecretsFromVault :: VaultConfig -> IO (Either String (Map Text ByteString))`
     - `getSecretForKid :: Map Text ByteString -> Text -> Maybe ByteString`

4. 運用上の注意
   - Vault トークンは環境変数かインスタンスロール（クラウドのメタデータ）で供給。
   - アクセス権限は最小化（read-only、特定パスのみ）。
   - ロギングはキーの存在・取得ステータスのみ記録し、値は絶対に記録しない。

サンプル擬似コード（Haskell）

```haskell
-- Vault 呼び出しの概略
fetchJwtSecretsFromVault :: String -> String -> IO (Either String (Map Text BS.ByteString))
fetchJwtSecretsFromVault vaultAddr token = do
  -- HTTP GET to: vaultAddr/v1/secret/data/<path>
  -- parse JSON body: { "data": { "data": { "kid1": "base64url..", ... } } }
  -- decode base64url into ByteString and return Map
```

次のステップ（実行可能アクション）
- この設計に基づき、まずは `fetchJwtSecretsFromVault` の小さな実装（HTTP GET + JSON parse + base64url decode）を作る。
- その後、`Auth.hs`（またはキー選択ロジック）を Vault 経由の取得に差し替え、ローカル開発では `JWT_SECRET` 互換パスを残す。

動作補足: 短いシークレットの自動派生
- サーバ内では HS256 に必要な鍵長（推奨 32 バイト）を満たさない短いシークレットが与えられた場合、自動的に HKDF-SHA256 で 32 バイトの鍵を派生して JWK として利用します。
- ただし本実装では互換性のためのローカル HMAC フォールバックを削除しました。つまりトークンが短い生シークレットで署名されていてサーバ側で派生された鍵による検証に失敗した場合、検証は失敗します。
- 運用者への推奨:
   - 本番では `JWT_SECRETS_VAULT_PATH` 等を利用して長い鍵（32 バイト以上）を配布してください。
   - 既存クライアントを更新できない場合は、トークン発行側（Python/他クライアント）で HKDF-SHA256 による 32 バイト鍵派生を導入してください（info: "hs256-derivation"）。
   - 短期間の互換性対応として一時的にサーバの古いブランチでフォールバックを維持することは可能ですが、本番には展開しないでください。

参考
- HashiCorp Vault HTTP API ドキュメント
- Haskell: `http-client`, `aeson` の使用例
