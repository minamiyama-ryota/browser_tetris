# Unify HS256 secret normalization between Python and Haskell

## Summary
This PR aligns Haskell's HS256 verification with the Python issuer by:
- Adding a round-trip Base64URL decode check (`tryB64urlDecode`) so textual secrets are only decoded when re-encoding matches (same behavior as Python).
- Applying HKDF-SHA256 derivation to produce a 32-byte final secret when the decoded secret is shorter than 32 bytes (info="hs256-derivation").
- Improving diagnostic logs (`provided_secret_len`, `decoded_secret_len`, `hkdf_applied`, `final_secret_sha256`) to help CI debugging.
- Making the test integration robust to repository layout by trying multiple locations for `gen_jwt_cli.py`.

## Changes
- `haskell-server/src/Auth.hs`: add `tryB64urlDecode`, normalize secret handling, add diagnostics.
- `.github/workflows/ci.yml`: upload debug artifacts (`gen_debug.txt`, `verify_debug.txt`), improve stack/install steps and coverage upload.
- `haskell-server/tests/TestIntegration.hs`: lookup multiple candidate paths for `gen_jwt_cli.py`.

## Testing
1. Local: `python elm-haskell/gen_jwt_cli.py "$JWT_SECRET" > token.txt` then run the Haskell `debug-verify` or `stack test` integration.
2. CI: this branch includes workflow changes that upload `auth-debug` artifacts; verify that `gen_debug.txt` and `verify_debug.txt` are produced and show `final_secret_sha256` matching between issuer and verifier.

## Notes
- This PR is created as a draft for review; please review `Auth.hs` carefully as it affects secret handling.
- After approval, merge to `main` and re-run full CI.

