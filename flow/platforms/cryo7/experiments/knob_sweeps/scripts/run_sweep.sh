#!/bin/bash
cd /home/benjamin/Documents/Repositories/working/OpenROAD-flow-scripts/flow
export PATH=$PWD/../tools/install/OpenROAD/bin:$PWD/../tools/install/yosys/bin:$PATH
T=$1; L=$2; R=$3; V=sw_${T}_L${L}_R${R}
make DESIGN_CONFIG=designs/cryo7/gcd/config.mk CRYO_TEMP=$T FLOW_VARIANT=$V \
  PRE_RESIZE_TCL=$PWD/designs/cryo7/gcd/pre_resize.tcl SIZING_LEAKAGE_LIMIT=$L RECOVER_POWER=$R \
  > $4/$V.log 2>&1 && echo "OK $V" || echo "FAIL $V"
