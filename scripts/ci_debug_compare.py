#!/usr/bin/env python3
import os, re, json, sys

root = os.getcwd()
files = []
for dirpath, dirnames, filenames in os.walk(root):
    for fn in filenames:
        if fn.startswith('ci_run_') and fn.endswith('_debug.txt'):
            files.append(os.path.join(dirpath, fn))
files.sort()

if not files:
    print(json.dumps({'error':'no debug files found','root':root}))
    sys.exit(0)

all_out = []
summary_counts = {'files':0,'groups':0,'mismatch_final':0,'mismatch_sig':0}

# helper regexes
re_sign_hex = re.compile(r'signing-input \(hex\)=([0-9a-fA-F]+)(?:\s+len=(\d+))?')
re_sign_utf8 = re.compile(r'signing-input \(utf8\)=(.*)')
re_provided = re.compile(r'(?:(?:provided_secret_len|secret_len)\s*=\s*(\d+))(?:.*?hkdf_applied\s*=\s*(True|False))?.*?final_secret_sha256\s*=\s*([0-9a-fA-F]+)')
re_provided_simple = re.compile(r'final_secret_sha256\s*=\s*([0-9a-fA-F]+)')
re_token_sig = re.compile(r'token sig \(base64url\)=([A-Za-z0-9_-]+)\s+sig\(hex\)=([0-9a-fA-F]+)')
re_computed_sig_full = re.compile(r'computed sig \(base64url\)=([A-Za-z0-9_-]+)\s+sig\(hex\)=([0-9a-fA-F]+)')
re_computed_sig_short = re.compile(r'computed signature\s*=\s*([A-Za-z0-9_-]+)')
re_auth_computed = re.compile(r'Auth debug: computed sig=?\s*=?([A-Za-z0-9_\-]+)')
re_jwk_secret = re.compile(r'jwk secret\(hex\)=\s*([0-9a-fA-F]+)')
re_secret_derived = re.compile(r'deriving|derived|secret too short|\(derived\)', re.IGNORECASE)

for fp in files:
    summary_counts['files'] += 1
    try:
        with open(fp, encoding='utf-8') as f:
            lines = [ln.rstrip('\n') for ln in f]
    except Exception as e:
        all_out.append({'file':fp,'error':str(e)})
        continue
    groups = []
    # primary pass: find signing-input (hex)
    for i, ln in enumerate(lines):
        m = re_sign_hex.search(ln)
        if not m:
            continue
        signing_hex = m.group(1).lower()
        signing_len = int(m.group(2)) if m.group(2) else None
        entry = {'file':fp,'line_index':i,'signing_hex':signing_hex,'signing_len':signing_len,'signing_utf8':None,'provided':[],'token_sig_b64':None,'token_sig_hex':None,'computed_sig_b64':None,'computed_sig_hex':None,'auth_debug_lines':[], 'jwk_secret_hex':[] }
        for j in range(max(0,i-12), min(len(lines), i+12)):
            l = lines[j]
            # collect Auth debug lines
            if 'Auth debug' in l or l.strip().startswith('DEBUG:'):
                entry['auth_debug_lines'].append(l)
            um = re_sign_utf8.search(l)
            if um:
                entry['signing_utf8'] = um.group(1)
            pm = re_provided.search(l)
            if pm:
                provided_len = int(pm.group(1)) if pm.group(1) else None
                hkdf_applied = (pm.group(2)=='True') if pm.group(2) else None
                final_sha = pm.group(3).lower()
                entry['provided'].append({'side': 'unknown','provided_len':provided_len,'hkdf_applied':hkdf_applied,'final_secret_sha256':final_sha,'line':j,'raw':l})
            else:
                # try simple final_secret_sha256 capture
                p2 = re_provided_simple.search(l)
                if p2:
                    entry['provided'].append({'side':'unknown','provided_len':None,'hkdf_applied':None,'final_secret_sha256':p2.group(1).lower(),'line':j,'raw':l})
            tm = re_token_sig.search(l)
            if tm:
                entry['token_sig_b64']=tm.group(1)
                entry['token_sig_hex']=tm.group(2).lower()
            cm = re_computed_sig_full.search(l)
            if cm:
                entry['computed_sig_b64']=cm.group(1)
                entry['computed_sig_hex']=cm.group(2).lower()
            cm2 = re_computed_sig_short.search(l)
            if cm2 and not entry['computed_sig_b64']:
                entry['computed_sig_b64']=cm2.group(1)
            ac = re_auth_computed.search(l)
            if ac and not entry['computed_sig_b64']:
                entry['computed_sig_b64']=ac.group(1)
            jm = re_jwk_secret.search(l)
            if jm:
                entry['jwk_secret_hex'].append(jm.group(1).lower())
            if re_secret_derived.search(l):
                entry.setdefault('derived_notes', []).append(l)
            # mark side (generate/verify) from surrounding line text
            if 'Generate JWT' in l:
                for p in entry['provided']:
                    p['side']='generate'
            if 'Verify token' in l or 'Verify token (simple' in l or 'Auth debug' in l:
                for p in entry['provided']:
                    if p['side']=='unknown':
                        p['side']='verify'
        groups.append(entry)
    # fallback pass: find token sig lines if no signing-input groups
    if not groups:
        for i, ln in enumerate(lines):
            tm = re_token_sig.search(ln)
            if not tm:
                continue
            entry = {'file':fp,'line_index':i,'signing_hex':None,'signing_len':None,'signing_utf8':None,'provided':[],'token_sig_b64':tm.group(1),'token_sig_hex':tm.group(2).lower(),'computed_sig_b64':None,'computed_sig_hex':None,'auth_debug_lines':[], 'jwk_secret_hex':[] }
            for j in range(max(0,i-12), min(len(lines), i+12)):
                l = lines[j]
                if 'Auth debug' in l or l.strip().startswith('DEBUG:'):
                    entry['auth_debug_lines'].append(l)
                pm = re_provided.search(l)
                if pm:
                    provided_len = int(pm.group(1)) if pm.group(1) else None
                    hkdf_applied = (pm.group(2)=='True') if pm.group(2) else None
                    final_sha = pm.group(3).lower()
                    entry['provided'].append({'side': 'unknown','provided_len':provided_len,'hkdf_applied':hkdf_applied,'final_secret_sha256':final_sha,'line':j,'raw':l})
                else:
                    p2 = re_provided_simple.search(l)
                    if p2:
                        entry['provided'].append({'side':'unknown','provided_len':None,'hkdf_applied':None,'final_secret_sha256':p2.group(1).lower(),'line':j,'raw':l})
                cm = re_computed_sig_full.search(l)
                if cm:
                    entry['computed_sig_b64']=cm.group(1)
                    entry['computed_sig_hex']=cm.group(2).lower()
                cm2 = re_computed_sig_short.search(l)
                if cm2 and not entry['computed_sig_b64']:
                    entry['computed_sig_b64']=cm2.group(1)
                ac = re_auth_computed.search(l)
                if ac and not entry['computed_sig_b64']:
                    entry['computed_sig_b64']=ac.group(1)
                jm = re_jwk_secret.search(l)
                if jm:
                    entry['jwk_secret_hex'].append(jm.group(1).lower())
            groups.append(entry)
    # summarize file groups
    file_summary = []
    for g in groups:
        final_set = set(p['final_secret_sha256'] for p in g['provided'] if p.get('final_secret_sha256'))
        match_final = (len(final_set) == 1 and len(final_set) > 0)
        computed_matches_token = None
        if g.get('computed_sig_b64') and g.get('token_sig_b64'):
            computed_matches_token = (g['computed_sig_b64'] == g['token_sig_b64'])
        mismatch_final = not match_final
        mismatch_sig = (computed_matches_token is False)
        if mismatch_final:
            summary_counts['mismatch_final'] += 1
        if mismatch_sig:
            summary_counts['mismatch_sig'] += 1
        summary_counts['groups'] += 1
        file_summary.append({'signing_hex':g.get('signing_hex'),'token_sig_b64':g.get('token_sig_b64'),'computed_sig_b64':g.get('computed_sig_b64'),'provided':g.get('provided'),'jwk_secret_hex':g.get('jwk_secret_hex'),'match_final':match_final,'computed_matches_token':computed_matches_token,'derived_notes':g.get('derived_notes',[]),'auth_debug_lines':g.get('auth_debug_lines',[])})
    all_out.append({'file':fp,'groups':file_summary})

# print concise summary and full JSON
short = {'files': summary_counts['files'],'groups': summary_counts['groups'],'mismatch_final': summary_counts['mismatch_final'],'mismatch_sig': summary_counts['mismatch_sig'],'files_analyzed':[os.path.relpath(f,root) for f in files]}
print('SUMMARY:')
print(json.dumps(short, indent=2))
print('\nDETAILS JSON:')
print(json.dumps(all_out, indent=2))
