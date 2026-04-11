## auth-debug ポリシーと自動化提案

### 目的

- HS256 トークン検証デバッグ（`auth-debug` アーティファクト）からの秘密情報漏洩を防ぎつつ、署名整合性の監査を自動化・継続的に実施するための運用方針と自動化案を示す。

### 要件（ポリシー）

- デバッグ出力は `DEBUG_VERIFY` / `AUTH_DEBUG` によって明示的に有効化されたときのみ収集する（デフォルト無効）。
- `auth-debug` アーティファクトの `retention-days` は最小（現在: `7` 日）に抑えること。
- デバッグログにプレーンテキストの秘密（シークレット値そのもの）を残さないこと。必要な場合は部分マスク／要約のみ出力する。
- リポジトリ内にデバッグアーティファクトが残存した場合は直ちに履歴洗浄と `JWT_SECRET` ローテーションを行う（既存の手順に従う）。

### 自動化提案（短期〜中期）

1) 集計ワークフロー（必須）
  - 目的: 定期的に `auth-debug` アーティファクトを集約し、秘匿情報を含まないサマリ（`downloads-aggregate/auth_debug_summary.csv`）を更新する。
  - 実装案: ナイトリーまたは手動トリガで `python tools/aggregate_auth_debug.py --limit 50 --out downloads-aggregate` を実行し、CSV をコミットするか、安全なアーティファクトとして保存する。

2) シークレット検出と対応（必須）
  - `gitleaks` を週次で実行し、秘密が検出されたら自動でチケット作成・`JWT_SECRET` ローテーションをトリガーする（運用手順の一部として）。

3) 転送/公開ガード（推奨）
  - `workflow_dispatch` の `debug_verify` 入力に対しては保守者の承認を必須にする（ブランチ保護や CODEOWNERS を利用）。

4) 検証失敗時の自動通知（推奨）
  - CI の `Assert auth verification` が失敗した場合、自動で Issue を作成または Slack/メールで通知するワークフローを追加する。

5) インシデント対応手順（必須）
  - 秘密が露出した場合: (a) 直ちに `JWT_SECRET` をローテーション、(b) 露出経路の特定と履歴洗浄、(c) 関係者に通知。

### 実装のための最短手順

1. このドキュメントを `docs/auth_debug_policy.md` としてリポジトリに追加（本 PR）。
2. `tools/aggregate_auth_debug.py` を用いた定期ワークフローを作成し、出力 CSV を `downloads-aggregate/` に保存する。コミットする場合は別ブランチ + PR を自動作成するフローにする。
3. `gitleaks` を追加して定期スキャンを有効化する（既存ワークフローと統合）。
4. `debug_verify=1` の有効化を限定し、要求時はレビュアが承認するポリシーを運用する。

### 参考

- 集計ツール: `tools/aggregate_auth_debug.py`
- 最新集計: `downloads-aggregate/auth_debug_summary.csv`

### CSV 差分チェック運用

- 目的: `auth_debug_summary.csv` の予期しない変化を早期検出し、誤動作や秘密漏洩の兆候を通知すること。
- 実行方法: CI ワークフローにて `tools/check_csv_diff.py` を実行します。既定では差分検出時にワークフローは警告のみ出します。
- 除外/失敗挙動: 差分でジョブを失敗させたい場合は、リポジトリの Secrets に `AUTH_DEBUG_DIFF_FAIL=1` を追加してください。値は `1`, `true`, `yes` が有効です（GitHub: Settings → Secrets and variables → Actions → New repository secret）。
- 自動コミットについて: CSV を自動でコミットして PR を作る場合は `PUSH_GIT_TOKEN` を Secrets に設定してください（既存ワークフローが `PUSH_GIT_TOKEN` を参照します）。

トラブルシュート手順（差分検出時）:

1. CI の該当実行を開き、`auth-debug-summary` アーティファクトをダウンロードして `auth_debug_summary.csv` と `auth_debug_summary.prev.csv` を取得するか、リポジトリをチェックアウトして再実行します:

```bash
python tools/aggregate_auth_debug.py --limit 50 --out downloads-aggregate
python tools/check_csv_diff.py downloads-aggregate/auth_debug_summary.csv --prev downloads-aggregate/auth_debug_summary.prev.csv --verbose
```

2. 差分のあった行（追加/削除）について、`downloads-aggregate/<run_id>/raw/` 以下の `gen_debug.txt` / `verify_debug.txt` / `token.txt` を確認し、`final_secret_sha256`、生成シグネチャ、検証ログを照合してください。

3. 署名整合性に疑義がある場合は影響範囲（run_id、対象ブランチ、実行者）を記録し、インシデント対応手順に従って `JWT_SECRET` のローテーションと履歴洗浄を実施してください（上位の「インシデント対応手順」を参照）。

4. 差分が期待される更新（例: 新しい実行ログの追加や意図した修正）であれば、ベースラインの更新（CSV のコミットまたは差分の許容）を行ってください。自動PRを使う場合は `PUSH_GIT_TOKEN` 設定を検討してください。

備考: この差分チェックは早期警告に有効ですが、偽陽性があり得ます。最初は `AUTH_DEBUG_DIFF_FAIL` を設定せず運用して観察期間を設け、期待されるノイズのパターンを把握してから厳格化してください。

---
作成者: 自動作成
