通信プロトコル（JSON） — Elm ↔ Haskell

目的: Elm クライアントと Haskell サーバ間で対戦とゲーム状態を同期する簡易仕様。

クライアント→サーバ (ClientMessage)
- join
  - {"type":"join","name":"playerName"}
  - サーバへ参加を通知。返答で対戦相手が見つかると `match_start` が来る。

- input
  - {"type":"input","action":"left"}
  - プレイヤーの操作（left/right/rotate/dropなど）を送る。サーバは相手へ `opponent_input` として転送する。

- ping
  - {"type":"ping"}
  - 接続保守用。

- state_request
  - {"type":"state_request"}
  - サーバに現在の試合状態を要求する。

サーバ→クライアント (ServerMessage)
- match_start
  - {"type":"match_start","opponent":"名前またはID"}
  - 対戦開始通知。クライアントはこれでゲーム開始準備をする。

- opponent_input
  - {"type":"opponent_input","action":"left"}
  - 相手の操作を通知。

- state_update
  - {"type":"state_update","state":{...}}
  - サーバ側の簡易ゲーム状態（スコアなど）を送る。

- error
  - {"type":"error","message":"..."}

設計上の注意
- メッセージはすべて JSON 文字列で送受信する。
- サーバはクライアントを待機キューに入れ、2人揃い次第ペアを作って `match_start` を送る。
- ゲームの権限（当面）: クライアントは描画とローカル処理を行い、サーバは対戦同期（操作の中継）とスコア管理を担当する。
- 将来的に AI をサーバで動かす場合は、同じプロトコルで `ai_action` を送れるよう拡張する。

例 (対戦開始)
- C -> S: {"type":"join","name":"Alice"}
- C -> S: {"type":"join","name":"Bob"}
- S -> Alice: {"type":"match_start","opponent":"Bob"}
- S -> Bob: {"type":"match_start","opponent":"Alice"}

例 (操作転送)
- Alice -> S: {"type":"input","action":"left"}
- S -> Bob: {"type":"opponent_input","action":"left"}

以上。質問があればどうぞ。