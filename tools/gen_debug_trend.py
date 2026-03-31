#!/usr/bin/env python3
"""
Generate a simple HTML trend report (inline SVG) from gen_debug_history.csv
Usage: python tools/gen_debug_trend.py path/to/gen_debug_history.csv out.html
"""
import sys
from pathlib import Path
import html

if len(sys.argv) < 3:
    print('Usage: gen_debug_trend.py input.csv output.html')
    sys.exit(2)

csv_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])

if not csv_path.exists():
    print('CSV not found:', csv_path)
    sys.exit(3)

lines = csv_path.read_text(encoding='utf-8').splitlines()
if len(lines) < 2:
    print('No data in CSV')
    sys.exit(0)

header = lines[0].split(',')
rows = [l.split(',') for l in lines[1:]]
# expected columns: timestamp,commit,files_scanned,files_with_errors,total_findings
timestamps = [r[0] for r in rows]
files_with_errors = [int(r[3]) for r in rows]
total_findings = [int(r[4]) for r in rows]

# build sparkline for total_findings
width = 600
height = 120
pad = 10
n = len(total_findings)
if n == 1:
    xs = [width//2]
else:
    xs = [int(pad + i*(width-2*pad)/(n-1)) for i in range(n)]
maxv = max(total_findings) if total_findings else 1
minv = min(total_findings) if total_findings else 0
rng = maxv - minv if maxv != minv else 1
ys = [int(pad + (height-2*pad)*(1 - (v-minv)/rng)) for v in total_findings]
points = ' '.join(f"{x},{y}" for x,y in zip(xs, ys))

# trend summary
last_total = total_findings[-1]
prev_total = total_findings[-2] if n >= 2 else None
change = (last_total - prev_total) if prev_total is not None else 0

html_content = f'''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>gen_debug Trend</title>
<style>body{{font-family:Arial,sans-serif;margin:16px}} .summary{{margin-bottom:12px}} svg{{border:1px solid #ddd}}</style>
</head>
<body>
<h2>gen_debug Trend</h2>
<div class="summary">
  <div>Last total_findings: <strong>{last_total}</strong></div>
  <div>Change vs previous: <strong>{change:+}</strong></div>
  <div>Files scanned: <strong>{n}</strong></div>
</div>
<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="trend">
  <polyline fill="none" stroke="#2b8cc4" stroke-width="2" points="{points}" />
</svg>
<h3>Recent entries</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr><th>timestamp</th><th>files_scanned</th><th>files_with_errors</th><th>total_findings</th></tr>
'''
for r in rows[-10:]:
    ts = html.escape(r[0])
    fs = html.escape(r[2])
    fwe = html.escape(r[3])
    tf = html.escape(r[4])
    html_content += f'  <tr><td>{ts}</td><td>{fs}</td><td>{fwe}</td><td>{tf}</td></tr>\n'

html_content += '''</table>
</body>
</html>'''

out_path.write_text(html_content, encoding='utf-8')
print('Wrote', out_path)
