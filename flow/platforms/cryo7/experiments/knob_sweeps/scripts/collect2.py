import json,glob,re,sys
pat=sys.argv[1] if len(sys.argv)>1 else 's2_'
rows=[]
for f in sorted(glob.glob(f'logs/cryo7/gcd/{pat}*/6_report.json')):
    v=f.split('/')[3]; m=re.match(r's2_(\w+?)_P(\d+)_L(\d+)_R(\d+)',v); d=json.load(open(f))
    g=lambda k:d.get('finish__'+k)
    rows.append((m[1],int(m[2]),int(m[3]),int(m[4]),g('timing__setup__ws')*1e3,g('timing__setup__tns')*1e3,
        g('power__leakage__total'),g('power__internal__total')*1e3,g('power__total')*1e3,
        g('design__instance__area'),g('design__instance__count')))
rows.sort(key=lambda r:(r[0]!='10K',r[1],r[2],r[3]))
print(f"{'T':>5} {'clk':>4} {'Llim':>5} {'RP':>3} {'WNS ps':>8} {'TNS ps':>8} {'leak':>10} {'int mW':>8} {'tot mW':>8} {'area um2':>9} {'inst':>5}")
for r in rows:
    leak=f"{r[6]*1e9:.2f} nW" if r[6]<1e-6 else f"{r[6]*1e6:.2f} uW"
    print(f"{r[0]:>5} {r[1]:>4} {r[2]:>5} {r[3]:>3} {r[4]:>8.1f} {r[5]:>8.1f} {leak:>10} {r[7]:>8.3f} {r[8]:>8.3f} {r[9]:>9.2f} {r[10]:>5}")
