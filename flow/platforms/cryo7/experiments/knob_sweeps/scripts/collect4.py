import json,glob,re
rows=[]
for f in sorted(glob.glob('logs/cryo7/gcd/s4*/6_report.json')):
    v=f.split('/')[3]; m=re.match(r's4(u40)?_(\w+?)_P(\d+)_DU(\w+)',v); d=json.load(open(f))
    g=lambda k:d.get('finish__'+k)
    rows.append((m[2],int(m[3]),m[4],'40' if m[1] else '65',g('timing__setup__ws')*1e3,g('timing__setup__tns')*1e3,
        g('power__leakage__total'),g('power__internal__total')*1e3,g('design__instance__area'),g('design__instance__count')))
rows.sort(key=lambda r:(r[0]!='10K',r[1],r[2]!='def',r[3]))
print(f"{'T':>5} {'clk':>4} {'DU':>4} {'util':>4} {'WNS ps':>8} {'TNS ps':>8} {'leak':>10} {'int mW':>8} {'area um2':>9} {'inst':>5}")
for r in rows:
    leak=f"{r[6]*1e9:.2f} nW" if r[6]<1e-6 else f"{r[6]*1e6:.2f} uW"
    print(f"{r[0]:>5} {r[1]:>4} {r[2]:>4} {r[3]:>4} {r[4]:>8.1f} {r[5]:>8.1f} {leak:>10} {r[7]:>8.3f} {r[8]:>9.2f} {r[9]:>5}")
