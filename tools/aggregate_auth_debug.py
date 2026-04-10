#!/usr/bin/env python3
"""
Aggregate `auth-debug` artifacts from recent CI runs and summarize results.

Usage:
  python tools/aggregate_auth_debug.py --limit 50 --out downloads-aggregate

Requires: GitHub CLI `gh` (authenticated) available on PATH.

Output:
  <out>/auth_debug_summary.csv
  <out>/<run-id>/raw/... (downloaded artifacts)
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# simple file logger to help debugging in CI-less environments
LOG_PATH = Path(__file__).with_suffix('.log')


def log(msg: str):
    try:
        with LOG_PATH.open('a', encoding='utf-8') as f:
            f.write(msg + '\n')
    except Exception:
        pass


def run_cmd(cmd):
    log(f"CMD: {' '.join(cmd)}")
    try:
        env = os.environ.copy()
        env.pop("GITHUB_TOKEN", None)
        p = subprocess.run(cmd, capture_output=True, text=True, check=True, env=env)
        log(f"OUT: {p.stdout[:10000]}")
        log(f"ERR: {p.stderr[:10000]}")
        return p.stdout
    except subprocess.CalledProcessError as e:
        log(f"ERROR: {' '.join(cmd)} -> {e.stderr.strip()}")
        return None


def list_runs(workflow, limit):
    cmd = ["gh", "run", "list", "--workflow", workflow, "--limit", str(limit), "--json", "databaseId,conclusion,createdAt,headBranch,status,url"]
    out = run_cmd(cmd)
    if not out:
        return []
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        print("Failed to parse gh run list output", file=sys.stderr)
        return []


def download_artifact(run_id, artifact_name, dest_dir):
    dest = Path(dest_dir)
    if dest.exists() and any(dest.iterdir()):
        # assume already downloaded
        return True
    dest.mkdir(parents=True, exist_ok=True)
    cmd = ["gh", "run", "download", str(run_id), "--name", artifact_name, "--dir", str(dest)]
    out = run_cmd(cmd)
    return out is not None


def parse_gen_debug(path: Path):
    res = {}
    if not path.exists():
        return res
    txt = path.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"provided_secret_len=(\d+)", txt)
    if m:
        res["provided_secret_len"] = m.group(1)
    m = re.search(r"hkdf_applied=(True|False)", txt)
    if m:
        res["hkdf_applied"] = m.group(1)
    m = re.search(r"final_secret_sha256=([0-9a-fA-F]+)", txt)
    if m:
        res["final_secret_sha256"] = m.group(1)
    m = re.search(r"token sig \(base64url\)=([A-Za-z0-9_-]+)", txt)
    if m:
        res["gen_token_sig"] = m.group(1)
    m = re.search(r"computed sig \(base64url\)=([A-Za-z0-9_-]+)", txt)
    if m:
        res["gen_computed_sig"] = m.group(1)
    return res


def parse_verify_debug(path: Path):
    res = {}
    if not path.exists():
        return res
    txt = path.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"signature \(from token\) =\s*([A-Za-z0-9_-]+)", txt)
    if m:
        res["token_file_sig"] = m.group(1)
    m = re.search(r"computed signature =\s*([A-Za-z0-9_-]+)", txt)
    if m:
        res["verify_computed_sig"] = m.group(1)
    m = re.search(r"match\s*=\s*(True|False)", txt)
    if m:
        res["match"] = m.group(1)
    return res


def parse_token_txt(path: Path):
    if not path.exists():
        return None
    tok = path.read_text(encoding="utf-8", errors="ignore").strip()
    if not tok:
        return None
    parts = tok.split('.')
    return parts[-1] if len(parts) >= 3 else tok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--workflow", default="ci.yml")
    p.add_argument("--artifact", default="auth-debug")
    p.add_argument("--limit", type=int, default=50)
    p.add_argument("--out", default="downloads-aggregate")
    args = p.parse_args()

    outdir = Path(args.out)
    outdir.mkdir(parents=True, exist_ok=True)

    runs = list_runs(args.workflow, args.limit)
    if not runs:
        print("No runs found or failed to list runs", file=sys.stderr)
        sys.exit(1)

    rows = []
    for r in runs:
        run_id = r.get("databaseId")
        status = r.get("status")
        createdAt = r.get("createdAt")
        headBranch = r.get("headBranch")
        conclusion = r.get("conclusion")
        if status != "completed":
            # skip in-progress runs
            continue
        run_dir = outdir / str(run_id)
        raw_dir = run_dir / "raw"
        if not raw_dir.exists():
            ok = download_artifact(run_id, args.artifact, raw_dir)
            if not ok:
                print(f"warning: could not download artifact for run {run_id}", file=sys.stderr)
        # parse files if present
        gen_debug_path = raw_dir / "gen_debug.txt"
        verify_debug_path = raw_dir / "verify_debug.txt"
        token_txt_path = raw_dir / "token.txt"

        gen = parse_gen_debug(gen_debug_path)
        ver = parse_verify_debug(verify_debug_path)
        tok_sig = parse_token_txt(token_txt_path)

        row = {
            "run_id": run_id,
            "createdAt": createdAt,
            "headBranch": headBranch,
            "conclusion": conclusion,
            "provided_secret_len": gen.get("provided_secret_len", ""),
            "hkdf_applied": gen.get("hkdf_applied", ""),
            "final_secret_sha256": gen.get("final_secret_sha256", ""),
            "gen_token_sig": gen.get("gen_token_sig", ""),
            "gen_computed_sig": gen.get("gen_computed_sig", ""),
            "token_file_sig": ver.get("token_file_sig", tok_sig or ""),
            "verify_computed_sig": ver.get("verify_computed_sig", ""),
            "match": ver.get("match", ""),
            "downloaded": str(raw_dir.exists()),
            "raw_dir": str(raw_dir)
        }
        rows.append(row)

    # write CSV
    csv_path = outdir / "auth_debug_summary.csv"
    with csv_path.open("w", newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=[
            "run_id", "createdAt", "headBranch", "conclusion",
            "provided_secret_len", "hkdf_applied", "final_secret_sha256",
            "gen_token_sig", "gen_computed_sig", "token_file_sig", "verify_computed_sig", "match",
            "downloaded", "raw_dir"
        ])
        writer.writeheader()
        for r in rows:
            writer.writerow(r)

    print(f"Wrote summary: {csv_path}")
    print(f"Processed {len(rows)} completed runs (limit={args.limit})")


if __name__ == '__main__':
    main()
