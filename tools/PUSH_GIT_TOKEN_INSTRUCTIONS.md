# PUSH_GIT_TOKEN 作成手順

このファイルは、CI から生成した `tools/ci_artifacts/gen_debug_history.csv` をリポジトリの専用ブランチ（`gen-debug-history`）へ自動で push するための Personal Access Token (PAT) の作成と設定手順を説明します。

1) Personal Access Token を作成する
  - GitHub ウェブ UI にログインします。
  - 右上のプロフィール > `Settings` を開きます。
  - 左サイドバーで `Developer settings` を選び、`Personal access tokens` を選択します。
  - `Fine-grained tokens` を使う場合はリポジトリアクセスを限定できますが、簡便さのためここではクラシックトークンを使う手順を示します。
  - `Generate new token (classic)` を選択し、説明を入力します（例: `ci-push-token`）。
  - 有効期限を設定します（例: 30 日〜90 日など、必要に応じて長めに設定）。
  - スコープは少なくとも `repo`（全リポジトリアクセス）または公開リポジトリのみなら `public_repo` を選択してください。
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

4) 動作確認
  - 手動でワークフローを `workflow_dispatch` で走らせ、最後に `gen-debug-history` ブランチに `tools/ci_artifacts/gen_debug_history.csv` が更新されていることを確認してください。

以上で PAT の作成と設定手順は完了です。
