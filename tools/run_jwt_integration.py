#!/usr/bin/env python3
import subprocess
import sys
import os
import json
import base64
import time
import hmac
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# reuse verify_token's compute_final_secret by importing it
import verify_token as vt


def _b64url_no_pad(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')


def make_token(secret_bytes: bytes, payload: dict) -> str:
    final_secret = vt.compute_final_secret(secret_bytes)
    header = {"alg": "HS256", "typ": "JWT"}
    header_b = _b64url_no_pad(json.dumps(header, separators=(',', ':')).encode('utf-8'))
    payload_b = _b64url_no_pad(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
    msg = f"{header_b}.{payload_b}"
    sig = hmac.new(final_secret, msg.encode('utf-8'), hashlib.sha256).digest()
    sig_b64 = _b64url_no_pad(sig)
    return f"{msg}.{sig_b64}"


def run_verify(token: str, secret_str: str) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env['TOK'] = token
    return subprocess.run([sys.executable, str(ROOT / 'verify_token.py'), secret_str], capture_output=True, text=True, env=env)


if __name__ == '__main__':
    # success case
    payload = {"sub": "testuser", "exp": int(time.time()) + 3600}
    token = make_token(b"dev-secret", payload)
    p = run_verify(token, "dev-secret")
    print(p.stdout)
    if p.returncode != 0:
        print('verify failed', p.stderr, file=sys.stderr)
        sys.exit(1)

    # tamper
    parts = token.split('.')
    sig = parts[2]
    tampered_sig = sig[:-1] + (('A' if sig[-1] != 'A' else 'B'))
    tampered_token = parts[0] + '.' + parts[1] + '.' + tampered_sig
    p2 = run_verify(tampered_token, "dev-secret")
    print(p2.stdout)
    if p2.returncode != 2:
        print('tamper test failed', p2.stderr, file=sys.stderr)
        sys.exit(1)

    print('OK')
    sys.exit(0)
