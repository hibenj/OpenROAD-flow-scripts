import json,glob,re,collections
rows=[]
for f in sorted(glob.glob('logs/asap7/gcd/mvt_*/6_report.json')):
    v=f.split('/')[3]; m=re.match(r'mvt_(\w)_P(\d+)',v); d=json.load(open(f))
    g=lambda k:d.get('finish__'+k)
    vt=collections.Counter(re.findall(r'_ASAP7_75t_(R|L|SL)\b',open(f'results/asap7/gcd/{v}/6_final.v').read()))
    rows.append((m[1],int(m[2]),g('timing__setup__ws'),g('timing__setup__tns'),g('power__leakage__total')*1e6,g('power__internal__total')*1e3,
        g('power__total')*1e3,g('design__instance__area'),vt['R'],vt['L'],vt['SL']))
rows.sort(key=lambda r:(r[0],r[1]))
print(f"{'cfg':>3} {'clk':>4} {'WNS ps':>8} {'TNS ps':>8} {'leak uW':>8} {'int mW':>8} {'tot mW':>8} {'area':>7} {'RVT':>4} {'LVT':>4} {'SLVT':>4}")
for r in rows: print(f"{r[0]:>3} {r[1]:>4} {r[2]:>8.1f} {r[3]:>8.1f} {r[4]:>8.2f} {r[5]:>8.3f} {r[6]:>8.3f} {r[7]:>7.2f} {r[8]:>4} {r[9]:>4} {r[10]:>4}")
