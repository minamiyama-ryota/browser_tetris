# CHANGELOG

## Unreleased

- Unify HS256 secret normalization between Python and Haskell
  - Added Base64URL "round-trip" detection: textual secrets that are valid Base64URL are decoded before use.
  - If provided secret is shorter than 32 bytes, derive a 32-byte HS256 key via HKDF-SHA256 (info="hs256-derivation").
  - Haskell: added `tryB64urlDecode`, `hkdfExtract`, `hkdfExpand` and diagnostic logging behind `DEBUG_VERIFY`/`AUTH_DEBUG`.
  - Added unit tests covering HKDF/base64 edge cases (`haskell-server/tests/TestHKDF.hs`).
  - CI: capture both `gen_debug.txt` and `verify_debug.txt` artifacts; stabilized verify logging with `tee` and gated verbose output by default.

## Notes

- Debug logging is gated; enable via workflow input `debug_verify=1` or env `DEBUG_VERIFY=1` for local debugging.
- Temporary debug artifacts were archived to the repository `debug-archive-*` folder.
