#!/usr/bin/env python3
import sys, json, time, os
import jwt, hmac, hashlib, base64

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
    # If the provided secret looks like Base64URL (unpadded), decode it to raw bytes.
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
        # verify re-encoding matches original (unpadded)
        reenc = base64.urlsafe_b64encode(decoded).decode('ascii').rstrip('=')
        if reenc == ss.rstrip('='):
            return decoded
        return s

    secret_bytes = try_b64url_decode(secret_bytes)
    if len(secret_bytes) < 32:
        final_secret = hkdf_expand(hkdf_extract(b"", secret_bytes), b"hs256-derivation", 32)
    else:
        final_secret = secret_bytes
    # Minimal debug info (enabled by setting DEBUG_VERIFY=1)
    if os.environ.get('DEBUG_VERIFY') == '1':
        try:
            final_sha = hashlib.sha256(final_secret).hexdigest()
        except Exception:
            final_sha = '<error>'
        print(f'DEBUG: provided_secret_len={len(secret_bytes)} hkdf_applied={len(secret_bytes)<32} final_secret_sha256={final_sha}', file=sys.stderr)

    token = jwt.encode(payload, final_secret, algorithm='HS256', headers=headers)
    # pyjwt may return str or bytes
    if isinstance(token, bytes):
        token = token.decode()
    # Ensure minimal debug output is emitted even when DEBUG_VERIFY is not set.
    # This prints final_secret fingerprint and computed signature (hex) so CI
    # can always collect comparable diagnostics.
    if os.environ.get('DEBUG_VERIFY') != '1':
        try:
            parts = token.split('.')
            if len(parts) == 3:
                signing_input = parts[0] + '.' + parts[1]
                signing_input_bytes = signing_input.encode('utf-8')
                signing_input_hex = signing_input_bytes.hex()
                sig_b64 = parts[2]
                pad = (-len(sig_b64)) % 4
                try:
                    sig_bytes = base64.urlsafe_b64decode(sig_b64 + ('=' * pad))
                    sig_hex = sig_bytes.hex()
                except Exception:
                    sig_hex = '<sig decode error>'
                # compute HMAC over signing input using final_secret
                comp_sig = hmac.new(final_secret, signing_input_bytes, hashlib.sha256).digest()
                comp_sig_b64 = base64.urlsafe_b64encode(comp_sig).decode('ascii').rstrip('=')
                comp_sig_hex = comp_sig.hex()
                try:
                    final_sha = hashlib.sha256(final_secret).hexdigest()
                except Exception:
                    final_sha = '<error>'
                print(f'DEBUG: provided_secret_len={len(secret_bytes)} hkdf_applied={len(secret_bytes)<32} final_secret_sha256={final_sha}', file=sys.stderr)
                print(f'DEBUG: signing-input (utf8)={signing_input}', file=sys.stderr)
                print(f'DEBUG: signing-input (hex)={signing_input_hex} len={len(signing_input_bytes)}', file=sys.stderr)
                print(f'DEBUG: token sig (base64url)={sig_b64} sig(hex)={sig_hex}', file=sys.stderr)
                print(f'DEBUG: computed sig (base64url)={comp_sig_b64} sig(hex)={comp_sig_hex}', file=sys.stderr)
        except Exception as e:
            print('DEBUG: gen_jwt_cli error computing sig:', e, file=sys.stderr)
    # Additional debug: print signing-input and signature details (hex + base64url) to stderr
    if os.environ.get('DEBUG_VERIFY') == '1':
        try:
            parts = token.split('.')
            if len(parts) == 3:
                signing_input = parts[0] + '.' + parts[1]
                signing_input_bytes = signing_input.encode('utf-8')
                signing_input_hex = signing_input_bytes.hex()
                sig_b64 = parts[2]
                pad = (-len(sig_b64)) % 4
                try:
                    sig_bytes = base64.urlsafe_b64decode(sig_b64 + ('=' * pad))
                    sig_hex = sig_bytes.hex()
                except Exception:
                    sig_hex = '<sig decode error>'
                # compute HMAC over signing input using final_secret
                comp_sig = hmac.new(final_secret, signing_input_bytes, hashlib.sha256).digest()
                comp_sig_b64 = base64.urlsafe_b64encode(comp_sig).decode('ascii').rstrip('=')
                comp_sig_hex = comp_sig.hex()
                print(f'DEBUG: signing-input (utf8)={signing_input}', file=sys.stderr)
                print(f'DEBUG: signing-input (hex)={signing_input_hex} len={len(signing_input_bytes)}', file=sys.stderr)
                print(f'DEBUG: token sig (base64url)={sig_b64} sig(hex)={sig_hex}', file=sys.stderr)
                print(f'DEBUG: computed sig (base64url)={comp_sig_b64} sig(hex)={comp_sig_hex}', file=sys.stderr)
        except Exception as e:
            print('DEBUG: gen_jwt_cli error computing sig:', e, file=sys.stderr)
    print(token)

if __name__ == '__main__':
    main()
