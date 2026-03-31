#!/usr/bin/env python3
import sys, base64, hmac, hashlib

def try_b64url_decode(s: bytes) -> bytes:
    try:
        ss = s.decode('ascii')
    except Exception:
        return s
    pad = (-len(ss)) % 4
    ss_p = ss + ('=' * pad)
    try:
        decoded = base64.urlsafe_b64decode(ss_p)
    except Exception:
        return s
    reenc = base64.urlsafe_b64encode(decoded).decode('ascii').rstrip('=')
    if reenc == ss.rstrip('='):
        return decoded
    return s

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


def compute(secret_str):
    secret_bytes = secret_str.encode()
    secret_bytes = try_b64url_decode(secret_bytes)
    hkdf_applied = len(secret_bytes) < 32
    if hkdf_applied:
        final = hkdf_expand(hkdf_extract(b"", secret_bytes), b"hs256-derivation", 32)
    else:
        final = secret_bytes
    final_sha = hashlib.sha256(final).hexdigest()
    final_hex = final.hex()
    final_b64url = base64.urlsafe_b64encode(final).decode('ascii').rstrip('=')
    print(f"input={secret_str!r} provided_secret_len={len(secret_bytes)} hkdf_applied={hkdf_applied}")
    print(f"final_secret_sha256={final_sha}")
    print(f"final_secret_hex={final_hex}")
    print(f"final_secret_b64url={final_b64url}")
    print("")

if __name__ == '__main__':
    if len(sys.argv) <= 1:
        print("usage: compute_hkdf.py <secret> [<secret> ...]")
        sys.exit(2)
    for s in sys.argv[1:]:
        compute(s)
