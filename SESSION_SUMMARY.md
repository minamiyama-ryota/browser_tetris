# セッション要約と ToDo

作成日: 2026-03-30
# セッション要約と ToDo

作成日: 2026-03-30
ブランチ: ci/unify-auth-debug

## 要約

**要約**

- **目的**: Pythonで生成したHS256トークンがHaskell側でCI上で検証できるよう、HS256秘密鍵の正規化（Base64URLラウンドトリップ判定 + HKDF-SHA256による32バイト派生）を両者で一致させる。
- **Haskell実装**: [haskell-server/src/Auth.hs](haskell-server/src/Auth.hs) に `tryB64urlDecode` を追加、秘密鍵長 < 32 バイト時に `hkdfExtract`/`hkdfExpand` で32バイトに派生、`authDebug` によるデバッグ出力を追加して診断を強化。
- **CIワークフロー**: [.github/workflows/ci.yml](.github/workflows/ci.yml) の Verify ステップを修正して `which python` / ワークスペース一覧等のデバッグを `verify_debug.txt` に出力、stdout/stderr を確実に捕捉して `auth-debug` アーティファクトとしてアップロードするようにした。
- **Python側検証**: [verify_token.py](verify_token.py) / [elm-haskell/verify_token.py](elm-haskell/verify_token.py) は `DEBUG_VERIFY=1` で最小限の診断出力を行い、CIで捕捉されるようになった。
- **テスト追加**: `haskell-server/tests/TestHKDF.hs` を追加し、`tryB64urlDecode` と `hkdfExpand` の基本ケースをユニットテスト化。`Auth` からテスト用に必要なヘルパをエクスポートした。
- **Windows対応**: ローカルの `strip.exe` 権限エラーを回避するための noop shim と `cabal` 設定を適用し、管理者PowerShell実行でローカル `stack test` が成功するように調整した。
- **現状**: ローカル（管理者PowerShell）で `stack test` は成功。CIは `auth-debug` アーティファクトを作成し、`[ci-artifacts/auth-debug/gen_debug.txt](ci-artifacts/auth-debug/gen_debug.txt)` と `[ci-artifacts/auth-debug/verify_debug.txt](ci-artifacts/auth-debug/verify_debug.txt)` に署名比較と `final_secret_sha256` が出力され、計算署名はトークン署名と一致している。PR（ドラフト）は作成済み: https://github.com/minamiyama-ryota/browser_tetris/pull/9

**To Do**

- **CI: capture 安定化**: `verify_debug.txt` の確実な保存を担保するためにワークフローへ `tee` 等を追加し、複数ランで安定してログが得られることを確認する（進行中）。
- **ghcup の strip 一時リネーム**: ローカル環境で残る `strip` 関連の失敗を根本対処するために `ghcup` の `strip` を一時リネームして再試行する（未着手）。
- **ドキュメント更新**: 変更点の短い説明を `README.md` / PR 本文に追記して差分の意図を明確にする（未着手）。
- **PR 最終レビュー & マージ**: CI アーティファクトが安定して期待するログを返すことを確認後、PR をレビュ→マージする（未着手）。

**完了済み（主要）**

- **Auth 構文修正・HKDF実装**: Haskell 側の修正を実装・push。
- **CI: verify 出力捕捉修正**: `verify` ステップを修正し stdout/stderr を `verify_debug.txt` に保存、アーティファクトをアップロード。
- **HKDF/base64 ユニットテスト追加**: `haskell-server/tests/TestHKDF.hs` を追加して基本ケースを検証。
- **ローカルビルド問題対応**: `strip` 関連の回避策を適用し、管理者PowerShellでの `stack test` 成功を確認。

---

必要なら、この要約を別ファイルへ保存したり、PR本文を更新して差分を説明します。次にどれを実行しますか？


- **目的:** Python 側のトークン（`gen_jwt_cli.py`）が Haskell 側で検証できるように統一し、CI を通すこと。
- **現状:** ブランチ `ci/unify-auth-debug` に変更を push 済み。最新のワークフロー実行（ID: 23729294056）は進行中。
- **最近の発見:** 多くのケースで発行側と検証側の `final_secret_sha256` と署名が一致するが、実行 `23725161608` にて Haskell が異なる `final_secret_sha256` を報告（mismatch_final=1）。
- **直近の障害:** `haskell-server/src/Auth.hs` に構文/パースの問題が CI のビルド段階で報告されているため、まずはこの修正が必要。
- **補足:** テストの Python スクリプト呼び出しパスは `haskell-server/tests/TestIntegration.hs` 側で複数候補探索に変更済み。デバッグ比較は `scripts/ci_debug_compare.py` を使用。

## To Do

- [ ] Fix `haskell-server/src/Auth.hs` の構文エラー修正（優先）
- [ ] ローカルで Haskell ビルド (`stack build` / `stack test`) を実行して通す
- [ ] 実行 `23725161608` の `gen_debug.txt` / `verify_debug.txt` を比較・原因特定
- [ ] Python と Haskell の HKDF / Base64 の挙動（padding / re-encoding / info 等）を整合させる
- [ ] 必要な修正を実装して `ci/unify-auth-debug` に push
- [ ] CI を実行して `auth-debug` をダウンロード
- [ ] `scripts/ci_debug_compare.py` でアーティファクトを解析し不一致がないか検証
- [ ] CI が成功することを確認し、再発がないか監視
- [ ] ドキュメント更新と PR の作成（変更点・移行手順の追記）

## 次のアクション

1. `haskell-server/src/Auth.hs` の構文エラー修正に着手する。
2. 修正後、ローカルでビルドとテストを実行して確かめる。
