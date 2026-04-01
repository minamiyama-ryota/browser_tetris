#!/usr/bin/env python3
"""
Scan repository for gen_debug.txt files, run tools/parse_gen_debug.py on each,
save per-file reports under tools/ci_artifacts/, and produce an aggregate JSON.
"""
import sys
import subprocess
import json
from pathlib import Path
import hashlib

ROOT = Path('.').resolve()
OUT_DIR = ROOT / 'tools' / 'ci_artifacts'
OUT_DIR.mkdir(parents=True, exist_ok=True)

# find gen_debug files
gen_files = sorted(ROOT.rglob('gen_debug.txt'))
reports = []

for gf in gen_files:
    try:
        proc = subprocess.run([sys.executable, str(ROOT / 'tools' / 'parse_gen_debug.py'), str(gf)], capture_output=True, text=True, timeout=30)
    except Exception as e:
        rep = {'file': str(gf), 'error': repr(e)}
        reports.append(rep)
        continue
    if proc.returncode != 0:
        # try to capture stdout/stderr
        rep = {'file': str(gf), 'error': proc.stderr.strip() or proc.stdout.strip()}
    else:
        try:
            rep = json.loads(proc.stdout)
        except Exception:
            rep = {'file': str(gf), 'error': 'failed to parse JSON output', 'raw': proc.stdout[:200]}
        rep['file'] = str(gf)
    slug = hashlib.sha1(str(gf).encode('utf-8')).hexdigest()[:8]
    out_file = OUT_DIR / f'report_{slug}.json'
    out_file.write_text(json.dumps(rep, ensure_ascii=False, indent=2), encoding='utf-8')
    reports.append(rep)

# aggregate
from collections import Counter
pattern_counts = Counter()
severity_counts = Counter()
files_with_errors = 0
for r in reports:
    findings = r.get('findings') or []
    if r.get('has_error'):
        files_with_errors += 1
    for f in findings:
        pattern_counts[f.get('pattern')] += 1
        severity_counts[f.get('severity', 'info')] += 1

aggregate = {
    'files_scanned': len(reports),
    'files_with_errors': files_with_errors,
    'total_findings': sum(pattern_counts.values()),
    'pattern_counts': dict(pattern_counts.most_common()),
    'severity_counts': dict(severity_counts),
}

agg_out = OUT_DIR / 'aggregate_gen_debug_summary.json'
agg_out.write_text(json.dumps({'aggregate': aggregate, 'reports': [ {'file': r.get('file'), 'summary': r.get('summary'), 'has_error': r.get('has_error', False)} for r in reports ]}, ensure_ascii=False, indent=2), encoding='utf-8')

print(json.dumps(aggregate, ensure_ascii=False, indent=2))
