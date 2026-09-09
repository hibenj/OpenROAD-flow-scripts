#!/usr/bin/env python3
"""Recompute the numbers in the paper's tables from the raw archived results.

Run from experiments/orfs_cryo7_knob_sweeps/results/:
    python3 ../scripts/verify_paper_numbers.py

Sources: power_vcd/*.rpt (calibrated report_power output, default vs VCD
activity), sweep*.txt (collected sweep tables), metrics_json/*.json (ORFS
6_report metrics). Every printed value should match the corresponding paper
table cell to the rounding shown there.
"""
import json


def _sections(path):
    text = open(path).read()
    if "VCD activity" in text:
        default, cal = text.split("VCD activity", 1)
    else:
        default, cal = text, text
    return default, cal


def _total(block, group="Total"):
    line = [l for l in block.splitlines() if l.startswith(group)][-1].split()
    return float(line[4]) * 1e6  # W -> uW


def calibrated(name):
    return _total(_sections(f"power_vcd/{name}.rpt")[1])


def clock_tree(name):
    return _total(_sections(f"power_vcd/{name}.rpt")[1], "Clock")


def default_activity(name):
    return _total(_sections(f"power_vcd/{name}.rpt")[0])


def metrics(name):
    d = json.load(open(f"metrics_json/{name}.json"))
    return (d["finish__timing__setup__ws"] * 1e3,
            d["finish__design__instance__area"],
            d["finish__power__leakage__total"] * 1e9,
            d["finish__power__internal__total"] * 1e3)


print("== Table I: baselines, total power [uW] (default activity / calibrated)")
for d in ["gcd_300K", "gcd_10K", "uart_300K", "uart_10K",
          "aes_300K", "aes_10K", "ibex_300K", "ibex_10K"]:
    print(f"  {d:10s} default {default_activity(d):8.0f}  calibrated {calibrated(d):8.0f}")

print("== Table II: gate sizing at 320 ps, calibrated total [uW], default vs full cell set")
for T in ["10K", "300K"]:
    a = calibrated(f"gcd_s4_{T}_P320_DUdef")
    b = calibrated(f"gcd_s4_{T}_P320_DUall")
    print(f"  {T:4s}: {a:.0f} -> {b:.0f}  ({(b / a - 1) * 100:+.1f}%)")
print("   (WNS/area/internal per clock: sweep4_dont_use_cells.txt;"
      " utilization sweep: sweep5_core_utilization.txt)")

print("== Table III: mapping, calibrated total [uW], delay script -> power-aware mapper")
for cs in ["du", "all"]:
    for T in ["300K", "10K"]:
        a = calibrated(f"gcd_ysyn_{cs}_{T}")
        b = calibrated(f"gcd_pmap_{cs}_{T}")
        print(f"  {'default' if cs == 'du' else 'full':7s} {T:4s}: {a:.0f} -> {b:.0f} ({(b / a - 1) * 100:+.1f}%)")

print("== Table IV: clock gating, calibrated total / clock tree [uW]")
for d in ["uart_300K", "uart_icg_300K", "uart_10K", "uart_icg_10K",
          "ibex_300K", "ibex_icg_300K", "ibex_10K", "ibex_icg_10K"]:
    print(f"  {d:14s} total {calibrated(d):8.0f}  clock {clock_tree(d):8.0f}")

print("== Table V: leakage cap, WNS [ps], tight (1x) vs none (1000x), recover_power off")
rows = [l.split() for l in
        open("sweep2_3_corrected_flow_leakcap_recover_fmax.txt").read().splitlines()[1:] if l.strip()]
for T in ["10K", "300K"]:
    for cap in ["1", "1000"]:
        vals = {r[1]: r[4] for r in rows if r[0] == T and r[3] == "0" and r[2] == cap}
        print(f"  {T:4s} cap {cap:>4s}: " + "  ".join(f"{k}:{v:>7s}" for k, v in vals.items()))

print("== Table VI: iso-Ioff, WNS [ps] / area [um2] / leakage [nW] / internal [mW]")
for f in ["cryo7_gcd_iso300K", "cryo7_gcd_iso77K", "cryo7_gcd_iso10K"]:
    w, a, l, i = metrics(f)
    print(f"  {f:20s} {w:+6.1f}  {a:5.1f}  {l:9.0f}  {i:.2f}")

print("== Table VII: Vt projection, WNS [ps] / area [um2] / leakage [nW] / calibrated [uW]")
for f, rpt in [("cryo7_gcd_vtRVT_P310", "gcd_vtRVT_P310"), ("cryo7_gcd_vtALL_P310", "gcd_vtALL_P310"),
               ("cryo7_gcd_vtRVT_P260", None), ("cryo7_gcd_vtALL_P260", "gcd_vtALL_P260")]:
    w, a, l, _ = metrics(f)
    c = f"{calibrated(rpt):.0f}" if rpt else "--"
    print(f"  {f:22s} {w:+6.1f}  {a:5.1f}  {l:5.1f}  {c}")
