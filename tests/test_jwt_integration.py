import os
import sys
import subprocess
import json
import base64
import time
import hmac
import hashlib
from pathlib import Path

import verify_token as vt

ROOT = Path(__file__).resolve().parent.parent


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


def test_verify_success():
    payload = {"sub": "testuser", "exp": int(time.time()) + 3600}
    token = make_token(b"dev-secret", payload)
    p = run_verify(token, "dev-secret")
    assert p.returncode == 0, f"verify failed: stdout={p.stdout!r} stderr={p.stderr!r}"
    assert "match = True" in p.stdout


def test_verify_tampered():
    payload = {"sub": "testuser", "exp": int(time.time()) + 3600}
    token = make_token(b"dev-secret", payload)
    parts = token.split('.')
    assert len(parts) == 3
    sig = parts[2]
    if not sig:
        raise AssertionError('empty signature')
    tampered_sig = sig[:-1] + (('A' if sig[-1] != 'A' else 'B'))
    tampered_token = parts[0] + '.' + parts[1] + '.' + tampered_sig
    p = run_verify(tampered_token, "dev-secret")
    assert p.returncode == 2, f"expected exit 2 for tampered token, got {p.returncode}; out={p.stdout!r} err={p.stderr!r}"
