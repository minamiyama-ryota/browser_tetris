#!/usr/bin/env python3
"""
簡易 gen_debug 解析スクリプト
使い方: python tools/parse_gen_debug.py path/to/gen_debug.txt
出力: JSON レポートを標準出力に出力
"""
import sys
import re
import json
from pathlib import Path

def parse_gen_debug(text):
    lines = text.splitlines()
    report = {
        "has_error": False,
        "errors": [],
        "warnings": [],
        "summary": {
            "lines": len(lines),
        }
    }

    # 単純なエラーパターン
    error_patterns = [re.compile(p, re.IGNORECASE) for p in [r"error", r"traceback", r"exception"]]
    warning_patterns = [re.compile(p, re.IGNORECASE) for p in [r"warning", r"warn"]]

    for i, line in enumerate(lines, start=1):
        for p in error_patterns:
            if p.search(line):
                report["has_error"] = True
                report["errors"].append({"line": i, "text": line})
                break
        for p in warning_patterns:
            if p.search(line):
                report["warnings"].append({"line": i, "text": line})

    return report


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "no input file"}))
        sys.exit(2)
    p = Path(sys.argv[1])
    if not p.exists():
        print(json.dumps({"error": "file not found", "file": str(p)}))
        sys.exit(3)
    text = p.read_text(encoding='utf-8', errors='replace')
    report = parse_gen_debug(text)
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
