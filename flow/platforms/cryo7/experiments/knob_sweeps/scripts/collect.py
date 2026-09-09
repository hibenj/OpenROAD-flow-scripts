import json,glob,os,re
rows=[]
for f in sorted(glob.glob('logs/cryo7/gcd/sw_*/6_report.json')):
    v=f.split('/')[3]; m=re.match(r'sw_(\w+)_L(\d+)_R(\d+)',v); d=json.load(open(f))
    g=lambda k:d.get('finish__'+k)
    rows.append((m[1],int(m[2]),int(m[3]),g('timing__setup__ws')*1e3,g('timing__setup__tns')*1e3,
        g('power__leakage__total'),g('power__internal__total')*1e3,g('power__total')*1e3,
        g('design__instance__area'),g('design__instance__count')))
rows.sort(key=lambda r:(r[0]!='10K',r[1],r[2]))
print(f"{'T':>5} {'Llim':>5} {'RP':>3} {'WNS ps':>8} {'TNS ps':>8} {'leak':>10} {'int mW':>8} {'tot mW':>8} {'area um2':>9} {'inst':>5}")
for r in rows:
    leak=f"{r[5]*1e9:.2f} nW" if r[5]<1e-6 else f"{r[5]*1e6:.2f} uW"
    print(f"{r[0]:>5} {r[1]:>5} {r[2]:>3} {r[3]:>8.1f} {r[4]:>8.1f} {leak:>10} {r[6]:>8.3f} {r[7]:>8.3f} {r[8]:>9.2f} {r[9]:>5}")
