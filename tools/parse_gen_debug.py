#!/usr/bin/env python3
"""
拡張 gen_debug 解析スクリプト

使い方:
  python tools/parse_gen_debug.py path/to/gen_debug.txt [optional: path/to/token.txt]

出力: JSON レポートを標準出力に出力
"""
import sys
import re
import json
from pathlib import Path
from collections import Counter

CONTEXT_LINES = 2

PATTERN_DEFINITIONS = [
    {
        "id": "traceback",
        "regex": re.compile(r"Traceback \(most recent call last\):", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Python traceback detected; inspect subsequent exception lines."
    },
    {
        "id": "python_exception_line",
        "regex": re.compile(r"^(?P<exc>[A-Za-z_][A-Za-z0-9_]*Error|Exception):"),
        "severity": "error",
        "suggestion": "Exception raised in Python code; review stack trace."
    },
    {
        "id": "module_not_found",
        "regex": re.compile(r"ModuleNotFoundError: No module named '?([^']+)'?", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Python module missing; install dependencies (e.g. pip install PyJWT)."
    },
    {
        "id": "pyjwt_missing",
        "regex": re.compile(r"No module named ['\"]?PyJWT['\"]?", re.IGNORECASE),
        "severity": "error",
        "suggestion": "PyJWT not installed. Ensure `pip install PyJWT` in CI."
    },
    {
        "id": "gen_jwt_missing",
        "regex": re.compile(r"gen_jwt_cli\.py not found", re.IGNORECASE),
        "severity": "error",
        "suggestion": "gen_jwt_cli.py missing; verify repository layout."
    },
    {
        "id": "permission_denied",
        "regex": re.compile(r"permission denied", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Permission issue: check runner permissions or file modes."
    },
    {
        "id": "no_such_file",
        "regex": re.compile(r"no such file or directory", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Missing file referenced in logs."
    },
    {
        "id": "command_not_found",
        "regex": re.compile(r"command not found|not recognized as an internal or external command", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Required command missing on runner."
    },
    {
        "id": "hkdf",
        "regex": re.compile(r"hkdf", re.IGNORECASE),
        "severity": "warning",
        "suggestion": "HKDF-related output; verify key derivation parameters."
    },
    {
        "id": "warning",
        "regex": re.compile(r"\bwarning\b", re.IGNORECASE),
        "severity": "warning",
        "suggestion": "Log contains warning text."
    },
    {
        "id": "error_keyword",
        "regex": re.compile(r"\berror\b|\bfatal\b", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Generic error keyword in log."
    },
    {
        "id": "generated_token",
        "regex": re.compile(r"Generated token:|Generated token", re.IGNORECASE),
        "severity": "info",
        "suggestion": "Token printed or expected; verify token file if present."
    },
    {
        "id": "hkdf_detail",
        "regex": re.compile(r"provided_secret_len=(\d+).*?hkdf_applied=(True|False)(?:.*?final_secret_sha256=([0-9a-fA-F]+))?", re.IGNORECASE),
        "severity": "info",
        "suggestion": "HKDF usage detected; check provided secret length and HKDF application."
    },
    {
        "id": "signature_failure",
        "regex": re.compile(r"(Signature verification failed|InvalidSignature|BadSignature|bad signature|signature.*failed|SignatureError)", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Signature verification or JWT verification failed."
    },
    {
        "id": "jwt_decode_error",
        "regex": re.compile(r"(InvalidTokenError|ExpiredSignatureError|DecodeError|InvalidSignatureError|jwt\.exceptions\.[A-Za-z_]+)", re.IGNORECASE),
        "severity": "error",
        "suggestion": "JWT decoding/verification error."
    },
    {
        "id": "bad_token_format",
        "regex": re.compile(r"(Malformed token|token invalid|Token is invalid|token malformed|bad token)", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Token format or content invalid."
    },
    {
        "id": "cli_unknown_json_field",
        "regex": re.compile(r"Unknown JSON field:\s*\"?([^\"\\s]+)\"?", re.IGNORECASE),
        "severity": "warning",
        "suggestion": "CLI returned unknown JSON field; adjust parsing or use REST fallback."
    },
    {
        "id": "auth_header_malformed",
        "regex": re.compile(r"Malformed\s+Authorization\s+header|authorization header is malformed", re.IGNORECASE),
        "severity": "error",
        "suggestion": "Authorization header malformed; ensure token has no extra quotes/newlines."
    },
    {
        "id": "http_unauthorized",
        "regex": re.compile(r"\b401\b|\bUnauthorized\b|authentication failed", re.IGNORECASE),
        "severity": "error",
        "suggestion": "HTTP 401/Unauthorized returned; check credentials and token formatting."
    },
]

def get_context(lines, idx, ctx=CONTEXT_LINES):
    start = max(0, idx-ctx)
    end = min(len(lines), idx+ctx+1)
    return "\n".join(lines[start:end])

def parse_file(path: Path):
    text = path.read_text(encoding='utf-8', errors='replace')
    lines = text.splitlines()
    findings = []
    counts = Counter()

    for i, line in enumerate(lines):
        for pat in PATTERN_DEFINITIONS:
            if pat['regex'].search(line):
                counts[pat['id']] += 1
                findings.append({
                    'pattern': pat['id'],
                    'severity': pat['severity'],
                    'line': i+1,
                    'text': line.strip(),
                    'context': get_context(lines, i),
                    'suggestion': pat.get('suggestion')
                })
                break

    summary = {
        'lines': len(lines),
        'matches': dict(counts)
    }
    has_error = any(f['severity'] == 'error' for f in findings)
    return {
        'has_error': has_error,
        'findings': findings,
        'summary': summary
    }

def check_token_file(path: Path):
    if not path.exists():
        return {'pattern': 'token_missing', 'severity': 'error', 'text': 'token file not found', 'suggestion': 'token.txt is missing'}
    if path.stat().st_size == 0:
        return {'pattern': 'token_empty', 'severity': 'error', 'text': 'token file is empty', 'suggestion': 'token.txt is empty'}
    # small sanity: token should be a single non-empty line
    text = path.read_text(encoding='utf-8', errors='replace').strip()
    if not text:
        return {'pattern': 'token_empty', 'severity': 'error', 'text': 'token file empty after trimming', 'suggestion': 'token.txt is empty'}
    return None

def main():
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'no input file'}))
        sys.exit(2)
    gen_path = Path(sys.argv[1])
    if not gen_path.exists():
        print(json.dumps({'error': 'file not found', 'file': str(gen_path)}))
        sys.exit(3)

    report = parse_file(gen_path)

    # optional token file check
    if len(sys.argv) >= 3:
        token_path = Path(sys.argv[2])
        token_issue = check_token_file(token_path)
        if token_issue:
            report.setdefault('findings', []).append({
                'pattern': token_issue['pattern'],
                'severity': token_issue['severity'],
                'line': None,
                'text': token_issue['text'],
                'context': None,
                'suggestion': token_issue.get('suggestion')
            })
            report['has_error'] = True

    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
