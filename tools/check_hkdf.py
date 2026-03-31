#!/usr/bin/env python3
"""
HKDFチェック: gen_debug.txt を解析して、短いprovided_secret_lenでHKDFが未適用ならエラーにします。
出力: JSON（summary, matches, issues）を stdout に出力。非0終了コードは問題あり。
"""
import sys
import re
import json
from pathlib import Path

def analyze(text):
    lines = text.splitlines()
    matches = []
    # 同一行にあるケースを最優先で検出
    pattern_inline = re.compile(r"provided_secret_len=(\d+).*?hkdf_applied=(True|False)", re.IGNORECASE)
    for i, line in enumerate(lines):
        m = pattern_inline.search(line)
        if m:
            matches.append({
                'line': i+1,
                'provided_secret_len': int(m.group(1)),
                'hkdf_applied': True if m.group(2).lower() == 'true' else False,
                'raw': line.strip()
            })
    # スライディングウィンドウで近傍にまたがるケースを検出
    if not matches:
        for i in range(len(lines)):
            window = "\n".join(lines[max(0, i-1):min(len(lines), i+2)])
            m_len = re.search(r"provided_secret_len=(\d+)", window, re.IGNORECASE)
            m_hk = re.search(r"hkdf_applied=(True|False)", window, re.IGNORECASE)
            if m_len and m_hk:
                matches.append({
                    'line': i+1,
                    'provided_secret_len': int(m_len.group(1)),
                    'hkdf_applied': True if m_hk.group(1).lower() == 'true' else False,
                    'raw': window
                })
    issues = []
    for m in matches:
        if m['provided_secret_len'] < 32 and not m['hkdf_applied']:
            issues.append({
                'issue': 'short_secret_without_hkdf',
                'detail': m,
                'message': 'provided_secret_len < 32 and hkdf_applied is False'
            })
    return {'matches': matches, 'issues': issues}


def main():
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'no input file'}))
        sys.exit(2)
    p = Path(sys.argv[1])
    if not p.exists():
        print(json.dumps({'error': 'file not found', 'file': str(p)}))
        sys.exit(3)
    text = p.read_text(encoding='utf-8', errors='replace')
    res = analyze(text)
    print(json.dumps(res, ensure_ascii=False, indent=2))
    if res['issues']:
        sys.exit(1)
    sys.exit(0)

if __name__ == '__main__':
    main()
