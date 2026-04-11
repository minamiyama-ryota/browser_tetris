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

### CSV diff チェックと障害対応

#### 概要

集計ワークフロー（`aggregate-auth-debug.yml`）は、前回実行時の `auth_debug_summary.csv` を
バックアップしてから最新のサマリを生成し、`tools/check_csv_diff.py` を使って差分を検出します。

`AUTH_DEBUG_DIFF_FAIL` 環境変数（デフォルト: `1`）が有効な場合、CSV に差分が検出されると
CI ジョブが **失敗** します。これにより、意図しないサマリの変化を早期に検知できます。

#### diff チェックの動作

| 条件 | 結果 |
|------|------|
| 差分なし | ✅ 正常終了 |
| 差分あり + `AUTH_DEBUG_DIFF_FAIL=1`（デフォルト） | ❌ CI 失敗（要トリアージ） |
| 差分あり + `AUTH_DEBUG_DIFF_FAIL=0` | ⚠️ 警告ログのみ・継続 |

#### トリアージ手順

1. **CI 失敗通知を受けたら:**
   - ワークフロー実行ログの `check_csv_diff` 出力を確認し、追加・削除・変更された行を特定する。
   - 差分が **意図した変更**（例: 新しい CI ラン、テスト変更）であれば手順 2 へ。
   - 差分が **予期しない変更** であれば、秘密情報の漏洩や認証ロジックの変化を調査する。

2. **意図した差分の場合（一時的に diff チェックを無効化）:**
   - リポジトリの **Settings → Secrets → Actions** で `AUTH_DEBUG_DIFF_FAIL` シークレットを
     `0` または `false` に設定してワークフローを再実行する。
   - 差分内容の確認が完了したら、シークレットを削除または `1` に戻す。

3. **恒久的にチェックを無効化したい場合:**
   - ワークフローファイルの `AUTH_DEBUG_DIFF_FAIL` デフォルト値を `'0'` に変更する PR を作成する。
   - 変更理由をレビュー担当者が明示的に承認すること。

#### opt-out 方法

```
# リポジトリシークレットで一時的に無効化（推奨）
AUTH_DEBUG_DIFF_FAIL = 0

# ワークフローファイルで恒久的に無効化（要 PR レビュー）
AUTH_DEBUG_DIFF_FAIL: ${{ secrets.AUTH_DEBUG_DIFF_FAIL || '0' }}
```

### 参考

- 集計ツール: `tools/aggregate_auth_debug.py`
- diff チェッカー: `tools/check_csv_diff.py`
- 最新集計: `downloads-aggregate/auth_debug_summary.csv`

---
作成者: 自動作成
