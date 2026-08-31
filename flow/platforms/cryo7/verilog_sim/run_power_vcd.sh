#!/usr/bin/env bash
# Gate-level activity simulation + VCD-annotated power report for a finished
# cryo7 run. Simulates 6_final.v with liberty-derived behavioral models
# (self-checking testbench), then reports power with default vs VCD activity.
#
# Usage: run_power_vcd.sh <results_dir> <temp:10K|300K> <clk_ps> [tb.sv] [out.rpt]
# e.g.:  run_power_vcd.sh results/cryo7/gcd/300K 300K 320
# Run from flow/. Writes <results_dir>/power_vcd.rpt unless out.rpt given.
set -euo pipefail

RESULTS=$1
TEMP=$2
CLK_PS=$3
TB=${4:-designs/cryo7/gcd/tb_gcd.sv}
OUT=${5:-$RESULTS/power_vcd.rpt}

PLATFORM=platforms/cryo7
MODELS=$PLATFORM/verilog_sim/gen_cryo7_stdcells_sim.v
OPENROAD=${OPENROAD_EXE:-../tools/install/OpenROAD/bin/openroad}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$MODELS" ]; then
  python3 $PLATFORM/verilog_sim/gen_sim_models.py "$MODELS" \
    "$PLATFORM/gen/0.7V_${TEMP}_maxtran.lib"
fi

# -fno-inline keeps every cell instance as a VCD scope so read_vcd can
# annotate each instance pin; without it Verilator inlines the behavioral
# cell models and most pins never appear in the VCD.
verilator --binary --timing --trace -fno-inline -Wno-fatal -j "$(nproc)" \
  --top-module tb -GCLK_PS="$CLK_PS" --Mdir "$WORK/obj_dir" -o tb_sim \
  "$TB" "$RESULTS/6_final.v" "$MODELS" >"$WORK/verilator.log" 2>&1 \
  || { cat "$WORK/verilator.log"; exit 1; }

"$WORK/obj_dir/tb_sim" +vcd="$WORK/activity.vcd"

ODB_FILE=$RESULTS/6_final.odb \
SDC_FILE=$RESULTS/6_final.sdc \
SPEF_FILE=$RESULTS/6_final.spef \
VCD_FILE=$WORK/activity.vcd \
LIB_FILES="$PLATFORM/gen/0.7V_${TEMP}_maxtran.lib ${EXTRA_LIBS:-}" \
  "$OPENROAD" -exit -no_splash $PLATFORM/power_vcd.tcl | tee "$OUT"
echo "power report: $OUT"
