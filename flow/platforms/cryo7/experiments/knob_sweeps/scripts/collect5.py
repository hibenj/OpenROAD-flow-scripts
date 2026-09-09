import json,glob,re
rows=[]
for f in sorted(glob.glob('logs/cryo7/gcd/s5_*/6_report.json')):
    v=f.split('/')[3]; m=re.match(r's5_(\w+?)_U(\d+)_DU(\w+)',v); d=json.load(open(f))
    g=lambda k:d.get('finish__'+k)
    rows.append((m[1],int(m[2]),m[3],g('timing__setup__ws')*1e3,g('timing__setup__tns')*1e3,g('power__internal__total')*1e3,
        g('design__instance__area'),g('design__core__area'),g('design__instance__utilization'),g('route__drc_errors'),g('timing__drv__setup_violation_count')))
rows.sort(key=lambda r:(r[0]!='10K',r[2]!='def',r[1]))
print(f"{'T':>5} {'util':>4} {'DU':>4} {'WNS ps':>8} {'TNS ps':>8} {'int mW':>8} {'inst um2':>9} {'core um2':>9} {'finalUtil':>9} {'DRC':>4} {'viol':>4}")
for r in rows:
    print(f"{r[0]:>5} {r[1]:>4} {r[2]:>4} {r[3]:>8.1f} {r[4]:>8.1f} {r[5]:>8.3f} {r[6]:>9.2f} {r[7]:>9.2f} {r[8]:>9.3f} {str(r[9]):>4} {str(r[10]):>4}")
