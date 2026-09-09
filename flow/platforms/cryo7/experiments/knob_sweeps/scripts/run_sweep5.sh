#!/bin/bash
# CORE_UTILIZATION area-recovery sweep at 320ps
cd /home/benjamin/Documents/Repositories/working/OpenROAD-flow-scripts/flow
export PATH=$PWD/../tools/install/OpenROAD/bin:$PWD/../tools/install/yosys/bin:$PATH
T=$1; U=$2; DU=$3; P=320; V=s5_${T}_U${U}_DU${DU}
EXTRA=(); [ "$DU" = all ] && EXTRA=("DONT_USE_CELLS=SDF* ICG*")
make DESIGN_CONFIG=designs/cryo7/gcd/config.mk CRYO_TEMP=$T FLOW_VARIANT=$V \
  SDC_FILE=$PWD/designs/cryo7/gcd/constraint_$P.sdc ABC_CLOCK_PERIOD_IN_PS=$P \
  PRE_RESIZE_TCL=$PWD/designs/cryo7/gcd/pre_resize.tcl SIZING_LEAKAGE_LIMIT=1000 RECOVER_POWER=0 \
  ENABLE_PLACE_REPAIR_TIMING=1 SKIP_LAST_GASP=0 OPT_POST_GRT_WNS=0 \
  CORE_UTILIZATION=$U PLACE_DENSITY= PLACE_DENSITY_LB_ADDON=0.10 "${EXTRA[@]}" \
  > $4/$V.log 2>&1 && echo "OK $V" || echo "FAIL $V"
