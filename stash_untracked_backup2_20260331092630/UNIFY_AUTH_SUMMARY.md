# HS256 統一: 要約と To Do

## 要約
- **目的**: `elm-haskell/gen_jwt_cli.py` が生成する HS256 トークンを `elm-haskell/haskell-server` の検証ロジックで検証できるよう統一し、CI を通す。
- **実施済み**:
  - `TestIntegration.hs` を修正し `gen_jwt_cli.py` のパス探索を堅牢化（Windows風パス問題対応）。
  - `Auth.hs` の `computeHmacSig` を修正し、秘密鍵が 32B 未満の場合に HKDF-SHA256(info="hs256-derivation") で 32B 鍵を導出するよう統一。
  - `.github/workflows/ci.yml` のマージマーカーを除去し YAML を整備。rebase → push を完了。
  - 修正を `ci/unify-auth-debug-packages` ブランチに push 済み。
- **現状**:
  - GitHub Actions の直近実行: run 78 (failure) / run 77 (failure)。run 78 は head_sha d2676cb…。
  - 新しいラン（最新 push に対応）の結果待ち。CI のログ／アーティファクトからデバッグ行を抽出する必要あり。
- **次の観察点**:
  - 新ランのログから `final_secret_sha256`、`signing-input`、token sig、computed sig を抽出して比較。
  - 不整合が残る場合は HKDF パラメータ、base64url の扱い、signing-input のエンコード差を調査・修正。

## To Do
- [x] Finalize rebase & push — `ci/unify-auth-debug-packages` へ push 完了  
- [x] Monitor CI and fetch logs for pushed commit — CI を監視中（直近 run 78/77 は失敗）  
- [ ] Extract and compare debug lines from new CI — 新ランのログ取得と比較（進行中）  
- [ ] Analyze mismatches and propose fixes — 不整合が残る場合の詳細解析と修正案  
- [ ] Apply fixes and push (if needed) — 必要に応じて実装して push  
- [ ] Validate CI passes — CI 全通の確認

## 参照
- 最新失敗ラン: https://github.com/minamiyama-ryota/browser_tetris/actions/runs/23709813145
- ブランチ: `ci/unify-auth-debug-packages`
