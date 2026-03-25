発行側 (JWT issuer) 移行ガイド

目的
- サーバ側で短いシークレットに対するローカル HMAC フォールバックを削除したため、発行側を 32 バイト鍵または HKDF 派生に移行する手順を示します。

推奨方針（選択肢）
- 推奨 A（最も簡単・安全）: 発行側で 32 バイト以上の秘密鍵を利用する。
- 推奨 B（互換性が高い）: 発行側で HKDF-SHA256 により `info = "hs256-derivation"` を使って 32 バイト鍵を派生してから HS256 で署名する。

移行手順（短いシークレットを使っている場合）
1. 発行スクリプト/サービスを更新して、以下の HKDF 関数を適用する（Python 例）。

```python
import hmac, hashlib

def hkdf_extract(salt: bytes, ikm: bytes) -> bytes:
    return hmac.new(salt, ikm, hashlib.sha256).digest()

def hkdf_expand(prk: bytes, info: bytes, out_len: int) -> bytes:
    okm = b''
    t = b''
    i = 1
    while len(okm) < out_len:
        t = hmac.new(prk, t + info + bytes([i]), hashlib.sha256).digest()
        okm += t
        i += 1
    return okm[:out_len]

secret_bytes = secret.encode()  # 既存のシークレット
if len(secret_bytes) < 32:
    final_secret = hkdf_expand(hkdf_extract(b"", secret_bytes), b"hs256-derivation", 32)
else:
    final_secret = secret_bytes
```

2. この `final_secret` を使って HS256 署名してください（PyJWT などでは `key=final_secret`）。

3. 発行側と検証側の `info` 値は固定で `hs256-derivation` にしてください（既存の `Auth.hs` と互換）。

検証とデプロイ
- テスト環境で短いシークレット（例: `dev-secret`）を使い、上記の派生を行ったトークンがサーバで検証できることを確認します。
- 発行側が更新できたら、本番では短い生シークレットを使わず、Vault などで長い鍵を配布してください。

例: コマンドラインでのトークン生成（リポジトリ内スクリプト）
- `python gen_jwt_cli.py dev-secret`  — 短いシークレットを渡して派生済みトークンを生成
- `python gen_jwt_cli.py <32_byte_secret>` — 32 バイト秘密で直接署名

CI / デプロイの具体例

1) GitHub Actions（テスト実行前にトークンを生成してテストに渡す例）

```yaml
name: CI
on: [push, pull_request]
jobs:
    test:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v3
            - uses: actions/setup-python@v4
                with:
                    python-version: '3.x'
            - name: Install Python deps
                run: pip install pyjwt
            - name: Generate JWT for tests
                env:
                    JWT_SECRET: ${{ secrets.JWT_SECRET }}
                run: |
                    python elm-haskell/gen_jwt_cli.py "$JWT_SECRET" > token.txt
            - name: Run Haskell tests
                run: |
                    cat token.txt
                    cd elm-haskell/haskell-server
                    stack test
```

2) Docker / docker-compose

- Dockerfile 内で `JWT_SECRET` を埋め込むことは避け、環境変数で渡すか、Kubernetes Secret / Docker Swarm secret を利用してください。

例（docker run）:

```sh
docker run -e JWT_SECRET="${JWT_SECRET}" myapp:latest
```

例（docker-compose.yml）:

```yaml
services:
    tetris-server:
        image: myapp:latest
        environment:
            - JWT_SECRET=${JWT_SECRET}
```

3) Kubernetes

- シークレットを作成して Pod の環境変数としてマウントします。生の短いシークレットを本番に置かないでください。例:

```sh
kubectl create secret generic jwt-secret --from-literal=JWT_SECRET="$(openssl rand -hex 32)"
```

Deployment の env 参照例:

```yaml
env:
    - name: JWT_SECRET
        valueFrom:
            secretKeyRef:
                name: jwt-secret
                key: JWT_SECRET
```

補足
- CI では `JWT_SECRET` を GitHub Secrets / GitLab CI Variables に安全に保存してください。
- テスト用にトークンを生成するスクリプトはリポジトリに含めてあります（`gen_jwt_cli.py`）。本番用の発行は Vault 等で長い鍵を管理してください。

追加支援
- リポジトリの `gen_jwt.py` / `gen_jwt_cli.py` は既に HKDF 派生を実装済みです。必要なら他言語ライブラリ（Node, Go, Java）向けの例パッチを作成します。

問題発生時の確認ポイント
- 発行側と検証側で同じ `info` 値を使っているか
- トークンのヘッダ `alg` が `HS256` であるか
- `kid` を使う場合、サーバの `JWT_SECRETS` と一致しているか

ファイル: `gen_jwt_cli.py` と `gen_jwt.py` を参照してください。

お問い合わせ: 移行作業を進める実運用サービス名や CI の例を教えていただければ、具体的なコマンドと差分パッチを作成します。
