#!/usr/bin/env python3
import sys, json, time
import jwt, hmac, hashlib

# Usage: gen_jwt_cli.py <secret> [kid]
# Prints a HS256 JWT to stdout using given secret and optional kid header.

def main():
    if len(sys.argv) < 2:
        print('usage: gen_jwt_cli.py <secret> [kid]', file=sys.stderr)
        sys.exit(2)
    secret = sys.argv[1]
    kid = sys.argv[2] if len(sys.argv) > 2 else None
    payload = {"sub": "testuser", "exp": int(time.time()) + 3600}
    headers = {"typ": "JWT", "alg": "HS256"}
    if kid:
        headers['kid'] = kid
    # If secret is shorter than 32 bytes, derive a 32-byte key via HKDF-SHA256
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

    secret_bytes = secret.encode() if isinstance(secret, str) else secret
    if len(secret_bytes) < 32:
        final_secret = hkdf_expand(hkdf_extract(b"", secret_bytes), b"hs256-derivation", 32)
    else:
        final_secret = secret_bytes

    token = jwt.encode(payload, final_secret, algorithm='HS256', headers=headers)
    # pyjwt may return str or bytes
    if isinstance(token, bytes):
        token = token.decode()
    print(token)

if __name__ == '__main__':
    main()
