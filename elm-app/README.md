Elm アプリケーション（簡易手順）

前提: Node.js と Elm 0.19 がインストールされていること

開発手順（簡易）:
1. プロジェクトルートで Elm を初期化: `elm init` (対話で `yes`)
2. ソースは `src/Main.elm` にあります。
3. ビルド: `elm make src/Main.elm --output=dist/main.js`
4. `dist` を静的ホスティング（`python -m http.server` など）で配信し、ブラウザで開く

将来的に WebSocket を繋ぐ場合は Elm の `WebSocket` モジュールか ports を使って Haskell サーバと通信します。