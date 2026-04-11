#!/usr/bin/env python3
"""check_csv_diff.py

簡易CSV差分検査ツール。

Usage:
  python tools/check_csv_diff.py --prev previous.csv current.csv

Exit codes:
  0 - 差分なし、または前回ファイルが存在しない（初回）
  2 - 差分あり

出力: 追加された行・削除された行の概要を標準出力に表示。
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from typing import Dict, List, Tuple


def load_csv_rows(path: str) -> Tuple[List[str], List[Dict[str, str]]]:
    with open(path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            return [], []
        rows = [row for row in reader]
        return reader.fieldnames, rows


def row_key(row: Dict[str, str], keys: List[str]) -> Tuple[str, ...]:
    return tuple(row.get(k, "") for k in keys)


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="CSV差分検査ツール")
    parser.add_argument("current", help="現在のCSVファイルパス")
    parser.add_argument("--prev", "-p", help="前回のCSVファイルパス（省略可）", default=None)
    parser.add_argument("--key", "-k", help="差分判定に使うカラム名（カンマ区切り）。省略時は全カラムを使用。", default=None)
    parser.add_argument("--verbose", "-v", action="store_true", help="詳細出力")
    args = parser.parse_args(argv)

    curr_path = args.current
    prev_path = args.prev

    if not os.path.exists(curr_path):
        print(f"ERROR: current file not found: {curr_path}", file=sys.stderr)
        return 3

    if prev_path is None or not os.path.exists(prev_path):
        print("前回ファイルが見つかりません。初回実行と見なします。差分チェックはスキップします。")
        return 0

    curr_headers, curr_rows = load_csv_rows(curr_path)
    prev_headers, prev_rows = load_csv_rows(prev_path)

    if args.key:
        keys = [k.strip() for k in args.key.split(",") if k.strip()]
    else:
        # デフォルトは両方に存在するヘッダの結合順序
        keys = curr_headers if curr_headers else prev_headers

    if not keys:
        print("WARNING: 比較キーが特定できません。ファイルが空の可能性があります。")
        return 0

    prev_set = set(row_key(r, keys) for r in prev_rows)
    curr_set = set(row_key(r, keys) for r in curr_rows)

    added = curr_set - prev_set
    removed = prev_set - curr_set

    if args.verbose:
        print(f"keys: {keys}")
        print(f"prev rows: {len(prev_rows)}, curr rows: {len(curr_rows)}")

    if not added and not removed:
        print("差分は検出されませんでした。")
        return 0

    print("差分が検出されました。")
    print(f"追加: {len(added)} 行, 削除: {len(removed)} 行")

    if args.verbose:
        if added:
            print("-- 追加サンプル --")
            for a in list(added)[:20]:
                print(json.dumps(a, ensure_ascii=False))
        if removed:
            print("-- 削除サンプル --")
            for r in list(removed)[:20]:
                print(json.dumps(r, ensure_ascii=False))

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
