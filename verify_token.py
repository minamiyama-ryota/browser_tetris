import hmac
import hashlib
import base64
import os
import sys

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

def compute_final_secret(secret_bytes: bytes) -> bytes:
	if len(secret_bytes) < 32:
		prk = hkdf_extract(b"", secret_bytes)
		return hkdf_expand(prk, b"hs256-derivation", 32)
	return secret_bytes

def load_token(token_path: str | None) -> str:
	if token_path and os.path.exists(token_path):
		with open(token_path, 'r', encoding='utf-8') as f:
			return f.read().strip()
	# fallback: use environment variable TOK or fail
	tok = os.environ.get('TOK')
	if tok:
		return tok
	raise SystemExit('No token provided via file or TOK env')

def main():
	# args: [script, secret, token_path]
	secret_arg = None
	token_path = None
	if len(sys.argv) >= 2:
		secret_arg = sys.argv[1]
	if len(sys.argv) >= 3:
		token_path = sys.argv[2]

	secret_bytes = secret_arg.encode() if secret_arg else os.environ.get('JWT_SECRET', '').encode()
	if not secret_bytes:
		print('Warning: no JWT secret provided; using empty secret')

	token = load_token(token_path)

	final_secret = compute_final_secret(secret_bytes)

	# Minimal debug info (enabled by setting DEBUG_VERIFY=1)
	if os.environ.get('DEBUG_VERIFY') == '1':
		try:
			ds = hashlib.sha256(final_secret).hexdigest()
		except Exception:
			ds = '<error>'
		print('DEBUG: secret_len=', len(secret_bytes), 'final_secret_sha256=', ds)

	try:
		h1, h2, h3 = token.split('.')
	except Exception:
		print('invalid token format')
		raise SystemExit(1)

	msg = (h1 + '.' + h2).encode('utf-8')
	sig = hmac.new(final_secret, msg, hashlib.sha256).digest()
	sig_b64 = base64.urlsafe_b64encode(sig).decode('utf-8').rstrip('=')

	print('header.payload =', h1 + '.' + h2)
	print('signature (from token) =', h3)
	print('computed signature =', sig_b64)
	print('match =', sig_b64 == h3)
	if sig_b64 != h3:
		print('computed:', sig_b64)
		print('token sig:', h3)
		raise SystemExit(2)

if __name__ == '__main__':
	main()
