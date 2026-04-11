#!/usr/bin/env python3
"""
check_csv_diff.py — CSV diff checker for auth_debug_summary.

Compares two CSV files (previous and current) and reports row-level
differences.  Exits with a non-zero status when diffs are found and
AUTH_DEBUG_DIFF_FAIL is set to a truthy value.

Usage:
    python tools/check_csv_diff.py --prev <old.csv> --curr <new.csv>

Exit codes:
    0  no differences, or FAIL mode disabled
    1  differences found and AUTH_DEBUG_DIFF_FAIL is enabled
    2  usage / file error
"""

import argparse
import csv
import os
import sys
from pathlib import Path


def _read_rows(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def _is_fail_enabled() -> bool:
    # Default '1' matches the AUTH_DEBUG_DIFF_FAIL default in
    # .github/workflows/aggregate-auth-debug.yml — keep them in sync.
    val = os.environ.get("AUTH_DEBUG_DIFF_FAIL", "1").strip().lower()
    return val not in ("0", "false", "no", "off", "")


def _diff_rows(
    prev_rows: list[dict], curr_rows: list[dict]
) -> tuple[list[dict], list[dict], list[tuple[dict, dict]]]:
    """Return (added, removed, changed) tuples."""

    # Prefer 'run_id' as the natural key; fall back to the first column.
    _KEY_FIELD = "run_id"

    def _key(row: dict) -> str:
        if _KEY_FIELD in row:
            return row[_KEY_FIELD]
        return next(iter(row.values()), "")

    prev_by_key = {_key(r): r for r in prev_rows}
    curr_by_key = {_key(r): r for r in curr_rows}

    added = [curr_by_key[k] for k in curr_by_key if k not in prev_by_key]
    removed = [prev_by_key[k] for k in prev_by_key if k not in curr_by_key]
    changed = [
        (prev_by_key[k], curr_by_key[k])
        for k in prev_by_key
        if k in curr_by_key and prev_by_key[k] != curr_by_key[k]
    ]
    return added, removed, changed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Compare two auth_debug_summary CSV files and report differences."
    )
    parser.add_argument("--prev", required=True, help="Path to the previous CSV file.")
    parser.add_argument("--curr", required=True, help="Path to the current CSV file.")
    args = parser.parse_args(argv)

    prev_path = Path(args.prev)
    curr_path = Path(args.curr)

    for p in (prev_path, curr_path):
        if not p.exists():
            print(f"ERROR: file not found: {p}", file=sys.stderr)
            return 2

    try:
        prev_rows = _read_rows(prev_path)
        curr_rows = _read_rows(curr_path)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR reading CSV: {exc}", file=sys.stderr)
        return 2

    added, removed, changed = _diff_rows(prev_rows, curr_rows)

    if not (added or removed or changed):
        print("check_csv_diff: no differences found.")
        return 0

    print(f"check_csv_diff: {len(added)} added, {len(removed)} removed, {len(changed)} changed row(s).")

    if added:
        print("\n--- Added rows ---")
        for row in added:
            print(" +", row)

    if removed:
        print("\n--- Removed rows ---")
        for row in removed:
            print(" -", row)

    if changed:
        print("\n--- Changed rows ---")
        for prev_row, curr_row in changed:
            print("  prev:", prev_row)
            print("  curr:", curr_row)

    if _is_fail_enabled():
        print(
            "\nFAIL: CSV diff detected and AUTH_DEBUG_DIFF_FAIL is enabled. "
            "Review the changes above. To opt-out, set the AUTH_DEBUG_DIFF_FAIL "
            "repository secret to '0' or 'false'.",
            file=sys.stderr,
        )
        return 1

    print("\nINFO: CSV diff detected but AUTH_DEBUG_DIFF_FAIL is disabled — continuing.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
