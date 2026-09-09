#!/bin/bash
# corrected knob sweep: real pre-CTS repair_timing, last-gasp on, recover_power reachable
cd /home/benjamin/Documents/Repositories/working/OpenROAD-flow-scripts/flow
export PATH=$PWD/../tools/install/OpenROAD/bin:$PWD/../tools/install/yosys/bin:$PATH
T=$1; P=$2; L=$3; R=$4; V=s2_${T}_P${P}_L${L}_R${R}
SDC=$PWD/designs/cryo7/gcd/constraint_$P.sdc
make DESIGN_CONFIG=designs/cryo7/gcd/config.mk CRYO_TEMP=$T FLOW_VARIANT=$V SDC_FILE=$SDC ABC_CLOCK_PERIOD_IN_PS=$P \
  PRE_RESIZE_TCL=$PWD/designs/cryo7/gcd/pre_resize.tcl SIZING_LEAKAGE_LIMIT=$L RECOVER_POWER=$R \
  ENABLE_PLACE_REPAIR_TIMING=1 SKIP_LAST_GASP=0 OPT_POST_GRT_WNS=0 \
  > $5/$V.log 2>&1 && echo "OK $V" || echo "FAIL $V"
