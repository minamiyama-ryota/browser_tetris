import jwt, time, hmac, hashlib

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

payload = {"sub":"testuser","exp": int(time.time()) + 3600}
secret = b"dev-secret"
final_secret = hkdf_expand(hkdf_extract(b"", secret), b"hs256-derivation", 32) if len(secret) < 32 else secret
token = jwt.encode(payload, final_secret, algorithm="HS256")
print(token if isinstance(token, str) else token.decode())