#!/bin/bash
# ASAP7 multi-Vt experiment @ TT/300K-ish: CFG A=RVT C=multi cap4 D=multi capInf E=SLVT
cd /home/benjamin/Documents/Repositories/working/OpenROAD-flow-scripts/flow
export PATH=$PWD/../tools/install/OpenROAD/bin:$PWD/../tools/install/yosys/bin:$PATH
C=$1; P=$2; S=$3; V=mvt_${C}_P${P}
case $C in
  A) VT="RVT"; L=4;;
  C) VT="RVT LVT SLVT"; L=4;;
  D) VT="RVT LVT SLVT"; L=1000;;
  E) VT="SLVT"; L=4;;
esac
make DESIGN_CONFIG=designs/asap7/gcd/config.mk FLOW_VARIANT=$V CORNER=TC "ASAP7_USE_VT=$VT" \
  SDC_FILE=$S/sdc7/constraint_$P.sdc ABC_CLOCK_PERIOD_IN_PS=$P \
  PRE_RESIZE_TCL=$PWD/designs/cryo7/gcd/pre_resize.tcl SIZING_LEAKAGE_LIMIT=$L RECOVER_POWER=0 \
  ENABLE_PLACE_REPAIR_TIMING=1 SKIP_LAST_GASP=0 OPT_POST_GRT_WNS=0 \
  > $S/$V.log 2>&1 && echo "OK $V" || echo "FAIL $V"
