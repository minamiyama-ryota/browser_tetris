import hmac, hashlib, base64

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImV4cCI6MTc3NDM5OTA3Mn0.oOKIZvknPl148LHN5JzgVLD4c92GcqS9otcVuMHdMW8"
secret = b"dev-secret"

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

# If secret is short, derive final_secret via HKDF-SHA256 (info="hs256-derivation")
final_secret = (hkdf_expand(hkdf_extract(b"", secret), b"hs256-derivation", 32)
				if len(secret) < 32 else secret)

h1, h2, h3 = token.split('.')
print('header.payload =', h1 + '.' + h2)
print('signature (from token) =', h3)

sig = hmac.new(final_secret, (h1 + '.' + h2).encode('utf-8'), hashlib.sha256).digest()
sig_b64 = base64.urlsafe_b64encode(sig).decode('utf-8').rstrip('=')
print('computed signature =', sig_b64)
print('match =', sig_b64 == h3)
