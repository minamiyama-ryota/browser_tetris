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
    print('aggregate file not found:', in_path)
    sys.exit(2)
out_csv = in_path.parent / 'gen_debug_history.csv'

with in_path.open('r', encoding='utf-8') as f:
    data = json.load(f)
    agg = data.get('aggregate', {})

now = datetime.utcnow().isoformat() + 'Z'
commit = sys.argv[2] if len(sys.argv) >= 3 else ''
line = [now, commit, str(agg.get('files_scanned',0)), str(agg.get('files_with_errors',0)), str(agg.get('total_findings',0))]

header = 'timestamp,commit,files_scanned,files_with_errors,total_findings\n'
if not out_csv.exists():
    out_csv.write_text(header + ','.join(line) + '\n', encoding='utf-8')
else:
    out_csv.write_text(out_csv.read_text(encoding='utf-8') + ','.join(line) + '\n', encoding='utf-8')

print('Appended history to', out_csv)
