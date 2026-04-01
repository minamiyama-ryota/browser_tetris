#!/usr/bin/env python3
"""
Append latest aggregate summary to a CSV history for simple trend tracking.
Usage: python tools/append_aggregate_to_history.py [path/to/aggregate_gen_debug_summary.json] [optional: commit-sha]
"""
import sys
import json
from pathlib import Path
from datetime import datetime

in_path = Path(sys.argv[1]) if len(sys.argv) >= 2 else Path('tools/ci_artifacts/aggregate_gen_debug_summary.json')
if not in_path.exists():
    print('input file not found:', in_path)
    sys.exit(2)

# decide whether input is an aggregate JSON or a per-run gen_debug_report
with in_path.open('r', encoding='utf-8') as f:
    data = json.load(f)

agg = {}
if isinstance(data, dict) and 'aggregate' in data:
    agg = data.get('aggregate', {})
else:
    # treat as a single-run gen_debug_report (from parse_gen_debug.py)
    # files_scanned = 1, files_with_errors = 1 if has_error else 0
    files_scanned = 1
    files_with_errors = 1 if data.get('has_error') else 0
    # total_findings: prefer summary.matches if available, else len(findings)
    total_findings = 0
    if isinstance(data.get('summary'), dict) and isinstance(data['summary'].get('matches'), dict):
        total_findings = sum(data['summary']['matches'].values())
    else:
        total_findings = len(data.get('findings') or [])
    agg = {
        'files_scanned': files_scanned,
        'files_with_errors': files_with_errors,
        'total_findings': total_findings
    }

 # write history into the CI artifacts directory so CI steps that expect
 # tools/ci_artifacts/gen_debug_history.csv will find it.
out_csv = Path('tools/ci_artifacts/gen_debug_history.csv')
out_csv.parent.mkdir(parents=True, exist_ok=True)

now = datetime.utcnow().isoformat() + 'Z'
commit = sys.argv[2] if len(sys.argv) >= 3 else ''
line = [now, commit, str(agg.get('files_scanned', 0)), str(agg.get('files_with_errors', 0)), str(agg.get('total_findings', 0))]

header = 'timestamp,commit,files_scanned,files_with_errors,total_findings\n'
if not out_csv.exists():
    out_csv.write_text(header, encoding='utf-8')

with out_csv.open('a', encoding='utf-8') as f:
    f.write(','.join(line) + '\n')

print('Appended history to', out_csv)
