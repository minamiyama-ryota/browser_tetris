# PUSH_GIT_TOKEN 作成手順

このファイルは、CI から生成した `tools/ci_artifacts/gen_debug_history.csv` をリポジトリの専用ブランチ（`gen-debug-history`）へ自動で push するための Personal Access Token (PAT) の作成と設定手順を説明します。

1) Personal Access Token を作成する
  - GitHub ウェブ UI にログインします。
  - 右上のプロフィール > `Settings` を開きます。
  - 左サイドバーで `Developer settings` を選び、`Personal access tokens` を選択します。
  - `Fine-grained tokens` を使う場合はリポジトリアクセスを限定できますが、簡便さのためここではクラシックトークンを使う手順を示します。
  - **推奨**: 可能であれば **Fine-grained token** を使い、対象リポジトリと必要最小限の権限のみを付与してください。
    - GitHub 上部メニュー > `Settings` > `Developer settings` > `Personal access tokens` > `Fine-grained tokens` > `Generate new token` を選択。
    - `Repository access` で **This repository only** を選び、リポジトリに `minamiyama-ryota/browser_tetris` を指定します。
    - Permissions（権限）は極力絞ります。`gen-debug-history` へファイルを push するだけなら下記で十分です:
      - `Contents` : `Read & write`
    - 有効期限を短めに設定（例: 30 日〜90 日）して、定期的にローテーションしてください。
  - **クラシックトークンを使う場合**は、公開リポジトリなら `public_repo`、非公開なら `repo` を使用しますが、可能な限り Fine-grained token を優先してください。
  - トークンを生成して、表示されるトークン文字列をコピーします（この場でしか表示されません）。

2) リポジトリシークレットへ追加する
  - リポジトリのページに移動し、`Settings` -> `Secrets and variables` -> `Actions` を開きます。
  - `New repository secret` をクリックします。
  - `Name` に `PUSH_GIT_TOKEN` と入力し、値に先ほどコピーしたトークンを貼り付けます。
  - `Add secret` を押して保存します。

3) 注意点
  - `PUSH_GIT_TOKEN` は強力な権限を持ちます。漏洩しないよう厳重に管理してください。
  - ワークフローでは `PUSH_GIT_TOKEN` を使って `gen-debug-history` ブランチへ push します。ブランチ保護ルールがある場合は、その保護を考慮してください（保護されたブランチへは `GITHUB_TOKEN`/PAT でも push が拒否されることがあります）。
  - 無限ループ防止: ワークフローがブランチ push をトリガーしないように、`gen-debug-history` ブランチに対するワークフロートリガーを制限することを推奨します（例: `.github/workflows/**` にトリガー条件を追加する等）。

  5) トークン権限の検証（ローカルで実行）
    - API でリポジトリに対する権限を確認する（トークンを環境変数に入れて実行）：

  ```bash
  # POSIX シェル例
  export PUSH_GIT_TOKEN="<YOUR_TOKEN>"
  curl -s -H "Authorization: token ${PUSH_GIT_TOKEN}" \
    https://api.github.com/repos/minamiyama-ryota/browser_tetris | jq .permissions
  ```

    - 出力例: `{ "pull": true, "push": true, "admin": false }` のように `push: true` があれば push 権限があります。

    - 安全に検証するために、ブランチを汚さない方法としては API 権限確認の後、短命ブランチでのテスト push を行い、確認後にそのブランチを削除してください（慎重に実行してください）。

  6) `gen-debug-history` ブランチ保護の運用案
    - 選択肢 A（簡単）: この用途（単なる履歴保管）であれば **保護を設定しない** ままにしておくのが最も簡単で確実です。現在このリポジトリでは未保護で、CI の push は成功しています。
    - 選択肢 B（安全）: ブランチ保護を有効化したい場合は、以下のいずれかを行ってください:
      - ブランチ保護ルールを作成し、かつ「Restrict who can push」オプションで **CI 用に使うユーザー（PAT を発行したアカウント）を許可する**。これにより該当ユーザーのみが push できます。
      - または、保護ルールで必須ステータスチェック（required status checks）を追加しないか、あるいはワークフローが満たすチェックのみを必須にして、CI の push をブロックしないように調整してください。

    - 注意: Fine-grained token や PAT を使っても、ブランチ保護で対象ユーザーが許可されていないと push が拒否されます。保護を導入する場合は、必ず許可リストに PAT 発行者（または CI の実行主体）を追加してください。

  7) 動作確認
    - シークレットをセットした後、ワークフローを手動で `workflow_dispatch` で実行して `gen-debug-history` に CSV が追加されることを確認してください。

  8) ローテーションと監査
    - PAT の有効期限は短く保ち、必要に応じて定期的にローテーションしてください。
    - シークレットのアクセス履歴は GitHub の監査ログ（Organization の場合）や Actions 実行ログで確認できます。

  ---

  ## 履歴 CSV の永続化戦略（推奨）

  - **当面の方針（推奨）**: 現状のまま `gen-debug-history` ブランチへ継続して追記して運用します。簡単で CI からの自動更新が容易なため、まずはこの方法を継続してください。
  - **保守策**: ブランチのサイズや行数が大きくなってきたら、定期的にアーカイブ（例: 月次で CSV を GitHub Release に添付、または S3 等へエクスポート）するジョブを追加すると良いです。
  - **将来的な移行案**:
    - GitHub Release に保存: `gh release create ...` を使って時点ごとのスナップショットを作る。
    - 外部オブジェクトストレージ (S3 / GCS): CI から直接アップロードし、ブランチは最小履歴のみ保持する。

  例: CI で月次アーカイブを作る psuedo-step

  ```yaml
  # 月次ジョブ（擬似）
  - name: Archive gen_debug history to release
    run: |
      ts=$(date -u +%Y%m%dT%H%M%SZ)
      gh release create gen-debug-history-${ts} tools/ci_artifacts/gen_debug_history.csv --title "gen-debug-history ${ts}"
  ```

  これにより、ブランチは短期的な履歴保管に使い、定期アーカイブで長期保存を別途確保できます。
4) 動作確認
  - 手動でワークフローを `workflow_dispatch` で走らせ、最後に `gen-debug-history` ブランチに `tools/ci_artifacts/gen_debug_history.csv` が更新されていることを確認してください。

以上で PAT の作成と設定手順は完了です。
