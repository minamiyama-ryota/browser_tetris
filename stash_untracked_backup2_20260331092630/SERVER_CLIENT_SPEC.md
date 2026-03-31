# サーバー / クライアント 詳細仕様

## **Server**
- **言語/実行環境**: Haskell (Stack)。ソースは `haskell-server/` に配置。
- **責務**: 認証（JWT 検証）、ゲームルーム管理、ゲームのオーソリティ（サーバーが状態を決定）、クライアント間ブロードキャスト、ログ保存。
- **認証フロー**: クライアントは接続時に JWT を送る（`Authorization: Bearer <token>` ヘッダ、または最初の `auth` メッセージ）。サーバーは受信トークンを検証して接続を許可/拒否。
- **トークン検証**: HS256 を使用。短いシークレット（32 バイト未満）は HKDF-SHA256(info="hs256-derivation") で 32 バイトに拡張してから HMAC 計算。実装箇所: `haskell-server/src/Auth.hs`、検証ユーティリティ: `elm-haskell/verify_token.py`。
- **ゲーム管理**: 各ルームは独立したゲームループ（固定ティック）を持ち、クライアントは入力（操作）を送る。サーバーが入力を反映し状態を算出・配信。
- **レーテンシ対策**: クライアントはローカル予測（インスタント表示）を行い、サーバーの状態差分が来たら補正（rollback/patch）。
- **データ永続化**: 最低限のイベントログ／ハイスコアを永続化（任意DB）。

## **Authentication (JWT)**
- **期待アルゴリズム**: `HS256`。
- **派生ルール**: `JWT_SECRET` が 32 バイト未満なら HKDF-SHA256(info="hs256-derivation") を用いて 32 バイト鍵を得る。32 バイト以上の場合は先頭 32 バイトを使用する（またはそのまま使う決定を明記）。
- **必須クレーム**: `sub`（ユーザID）、`iss`（issuer）、`iat`、`exp`（短い TTL、例: 5〜15 分）
- **検証**:
  - 署名検証（固定時間比較）
  - `exp` の確認
  - `iss`/`aud` の確認（必要なら）
- **デバッグ出力**: `DEBUG_VERIFY=1` で、`provided_secret_len`、`hkdf_applied`、`final_secret_sha256`（要はダイジェスト）を出力する。ただしシークレットそのものは出力しない。

## **WebSocket API / メッセージ定義**
- **接続**: `wss://<host>/ws`。接続時に `Authorization` ヘッダを送るか、初回メッセージで `auth` を送る。

- **メッセージ共通形式 (JSON)**:
```json
{
  "type": "string",
  "id": "optional-client-msg-id",
  "ts": 1670000000,
  "payload": { }
}
```
- **主要メッセージ**:
  - **auth**: クライアント→サーバー。`{ "type":"auth", "payload": { "token": "..." } }`。
  - **auth_ok / auth_error**: サーバー→クライアント。認証許可/拒否。
  - **join**: ルーム参加。`{ "type":"join", "payload": { "room":"<id>" } }`。
  - **input**: 操作送信（クライアント→サーバー）。`{ "type":"input", "payload": { "action":"left|right|rotate|soft_drop|hard_drop|hold", "tick": 12345 } }`。
  - **state**: サーバー→クライアント。現在のゲーム状態（grid, activePiece, next, hold, scores, lines, level, players）を送る。
  - **event**: 特別イベント（`line_clear`, `game_over`, `player_joined`, `player_left`）
  - **ping/pong**: ラテンシ計測と接続維持

- **順序・信頼性**: クライアントの `input` には `tick` または単調インクリメントの `seq` を付与し、サーバーはそれを元に入力順序を検証。サーバーの `state` が最終的な真（authoritative）。

## **ゲームループ & 同期**
- **サーバー側ティック**: 固定ティック（例: 20Hz）。gravity はレベルに応じてティック数で表現（例: drops per N ticks）。
- **入力処理**: サーバーは受信した `input` を次のティックで適用し、結果状態を全クライアントに配信。
- **補正**: クライアントはローカルで即時反映し、サーバーの `state` を受けて差分を補正（簡潔な patch を適用）。

## **Security**
- **Transport**: 常に TLS（`wss://` / `https://`）。
- **Secrets**: `JWT_SECRET` は環境変数で管理、CI/環境変数に保存。ログに生のシークレットは絶対出さない。
- **Rate limit / Anti-cheat**: 入力頻度制限、突飛なスコア/動作のサーバー側検査。
- **脆弱性対策**: JSON パースでの例外管理、長いメッセージの拒否、接続数制限。

## **Deployment / 環境変数**
- **必須**:
  - `JWT_SECRET` : string
  - `PORT` : サーバー起動ポート
- **デバッグ**:
  - `DEBUG_VERIFY=1` : JWT 検証デバッグ出力
- **参考ファイル**: `haskell-server/stack.yaml`, `elm-haskell/.github/workflows/ci.yml`

## **Client**
- **プラットフォーム**: ブラウザ（`index.html`, `game.js`）。
- **責務**: 描画、入力収集（DAS/ARR）、ローカル予測、サーバー送信、サーバー `state` の受信・適用、UI 表示（next/hold/score/level）、再接続。
- **接続手順**:
  1. JWT を取得（認証済みユーザーの場合サーバー経由でトークンを取得する流れを想定）。
  2. `WebSocket` を `wss://` で開き、`Authorization: Bearer <token>` ヘッダを送るか、初回 `auth` メッセージを送る。
  3. `auth_ok` を受けたら `join` を送る。
- **入力設計**:
  - **即時描画**: 入力を即座にローカルで反映（スムーズな操作感）。
  - **送信**: 各操作は `input` メッセージでサーバーへ送信（`tick`/`seq` を添える）。
  - **補正処理**: サーバーから `state` が来たら、ローカル予測との差分を最小限修正。
- **UI/UX**:
  - next/hold/pause/score/level 表示
  - 接続状態表示と再接続ボタン
  - デバッグモードで `ping`/`latency`、現在の `seq` を表示

## **メッセージ仕様 例**
- **auth (client→server)**
```json
{ "type": "auth", "payload": { "token": "<JWT>" } }
```

- **input (client→server)**
```json
{ "type":"input", "id":"c1", "ts":1670000000, "payload":{ "action":"rotate", "tick":12345 } }
```

- **state (server→client)**
```json
{
  "type":"state",
  "payload":{
    "tick":12346,
    "grid":[ /* 20x10 */ ],
    "active": { "shape":"T", "x":4, "y":0, "rotation":0 },
    "next":["I","J","L"],
    "hold": null,
    "players": [{ "id":"p1","score":100 }]
  }
}
```

## **Testing & デバッグ**
- **ユニット**: `haskell-server` のロジック（回転、衝突、ライン消去）を単体テスト。
- **統合**: `elm-haskell/verify_token.py` と `haskell-server/app/DebugVerify.hs` を用いて JWT の発行・検証フローを CI で検証。
- **CI 注意点**: ワークフローはチェックアウト位置が `/home/runner/work/<repo>/<repo>` になることがあるため、`working-directory` を固定パスに依存させないこと。

## **Appendix: HKDF 例（概念）**
```
# pseudocode
if len(secret) < 32:
  final_key = HKDF-SHA256(secret, info="hs256-derivation", length=32)
else:
  final_key = secret[:32]
# use final_key as HMAC-SHA256 key for HS256
```

---

必要なら、この仕様を `SPEC_server_client.md` としてワークスペースに保存します（保存先: `SERVER_CLIENT_SPEC.md`）。
