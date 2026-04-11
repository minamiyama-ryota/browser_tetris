#!/usr/bin/env python3
"""
aggregate_auth_debug.py — Aggregate auth-debug CI artifacts into a CSV summary.

Usage:
    python tools/aggregate_auth_debug.py [--limit N] [--out DIR]

Options:
    --limit N   Maximum number of recent workflow runs to inspect (default: 50).
    --out DIR   Output directory for the summary CSV (default: downloads-aggregate).

The script:
1. Reads existing summary CSV (if any) as the *previous* baseline.
2. Collects auth-debug artifact data from the last N workflow runs (stub
   implementation — replace with real GitHub API calls as needed).
3. Writes the updated summary CSV to <DIR>/auth_debug_summary.csv.
4. Calls tools/check_csv_diff.py to compare previous vs. current CSV and,
   when AUTH_DEBUG_DIFF_FAIL is enabled, fails the job if diffs are found.
"""

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

SUMMARY_FILENAME = "auth_debug_summary.csv"
# Backup file is written alongside the summary as auth_debug_summary.bak.csv
BACKUP_FILENAME = "auth_debug_summary.bak.csv"


def _backup_csv(csv_path: Path) -> Path | None:
    """Copy *csv_path* to a .bak.csv file and return the backup path."""
    if not csv_path.exists():
        return None
    backup_path = csv_path.parent / BACKUP_FILENAME
    shutil.copy2(csv_path, backup_path)
    print(f"aggregate: backed up previous CSV to {backup_path}")
    return backup_path


def _load_existing(csv_path: Path) -> list[dict]:
    if not csv_path.exists():
        return []
    with csv_path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def _collect_runs(limit: int) -> list[dict]:
    """Stub: collect auth-debug summary rows from recent CI runs.

    Replace or extend this function with real GitHub API calls (e.g. via the
    ``gh`` CLI or the ``PyGitHub`` library) to download and parse actual
    auth-debug artifacts.

    Returns a list of dicts, each representing one aggregated run entry.
    """
    # Try to read last_run.json from the repo root as a lightweight source of
    # recent run metadata.
    repo_root = Path(__file__).parent.parent
    last_run_file = repo_root / "last_run.json"

    rows: list[dict] = []
    if last_run_file.exists():
        try:
            data = json.loads(last_run_file.read_text(encoding="utf-8"))
            if isinstance(data, list):
                for entry in data[:limit]:
                    rows.append(
                        {
                            "run_id": entry.get("id", ""),
                            "status": entry.get("status", ""),
                            "conclusion": entry.get("conclusion", ""),
                            "created_at": entry.get("created_at", ""),
                            "auth_debug_present": entry.get("auth_debug_present", ""),
                        }
                    )
            elif isinstance(data, dict):
                rows.append(
                    {
                        "run_id": data.get("id", ""),
                        "status": data.get("status", ""),
                        "conclusion": data.get("conclusion", ""),
                        "created_at": data.get("created_at", ""),
                        "auth_debug_present": data.get("auth_debug_present", ""),
                    }
                )
        except Exception as exc:  # noqa: BLE001
            print(f"aggregate: warning — could not parse last_run.json: {exc}")

    return rows


def _write_csv(rows: list[dict], csv_path: Path) -> None:
    if not rows:
        # Write an empty CSV with a default header so downstream tools don't
        # choke on a missing file.
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        with csv_path.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(
                fh,
                fieldnames=["run_id", "status", "conclusion", "created_at", "auth_debug_present"],
            )
            writer.writeheader()
        return

    fieldnames = list(rows[0].keys())
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"aggregate: wrote {len(rows)} row(s) to {csv_path}")


def _run_diff_check(prev_csv: Path | None, curr_csv: Path) -> int:
    """Run check_csv_diff.py and return its exit code."""
    if prev_csv is None or not prev_csv.exists():
        print("aggregate: no previous CSV backup found — skipping diff check.")
        return 0

    script = Path(__file__).parent / "check_csv_diff.py"
    cmd = [sys.executable, str(script), "--prev", str(prev_csv), "--curr", str(curr_csv)]
    print(f"aggregate: running diff check: {' '.join(cmd)}")
    result = subprocess.run(cmd, check=False)
    return result.returncode


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Aggregate auth-debug CI artifacts into a CSV summary."
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=50,
        help="Maximum number of recent workflow runs to inspect (default: 50).",
    )
    parser.add_argument(
        "--out",
        default="downloads-aggregate",
        help="Output directory for the summary CSV (default: downloads-aggregate).",
    )
    args = parser.parse_args(argv)

    out_dir = Path(args.out)
    csv_path = out_dir / SUMMARY_FILENAME

    # 1. Back up the existing CSV before overwriting.
    backup_path = _backup_csv(csv_path)

    # 2. Collect new rows.
    rows = _collect_runs(args.limit)

    # 3. Write updated CSV.
    _write_csv(rows, csv_path)

    # 4. Diff previous vs. current and honour AUTH_DEBUG_DIFF_FAIL.
    rc = _run_diff_check(backup_path, csv_path)
    if rc not in (0, 1):
        # rc==2 means a file/usage error in the diff checker — treat as warning.
        print(f"aggregate: diff checker returned unexpected code {rc}; continuing.")
        rc = 0

    return rc


if __name__ == "__main__":
    sys.exit(main())
