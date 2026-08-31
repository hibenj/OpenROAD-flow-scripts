export PLATFORM               = cryo7

export DESIGN_NICKNAME        = ibex
export DESIGN_NAME            = ibex_core

export VERILOG_FILES = $(sort $(wildcard $(DESIGN_HOME)/src/ibex_sv/*.sv)) \
    $(DESIGN_HOME)/src/ibex_sv/syn/rtl/prim_clock_gating.v

export VERILOG_INCLUDE_DIRS = \
    $(DESIGN_HOME)/src/ibex_sv/vendor/lowrisc_ip/prim/rtl/

export SYNTH_HDL_FRONTEND = slang

export SDC_FILE              = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export CORE_UTILIZATION       =  40
export CORE_ASPECT_RATIO      = 1
export CORE_MARGIN            = 2
export PLACE_DENSITY_LB_ADDON  = 0.20

export ENABLE_DPO = 0

export TNS_END_PERCENT        = 100

# asap7 ibex uses SWAP_ARITH_OPERATORS + OPENROAD_HIERARCHICAL; both are left
# off here so synthesis takes the standard abc path (required for ABC_EXE /
# ABC_SCRIPT mapper experiments).

# cryo lib is in ns; ABC wants ps
export ABC_CLOCK_PERIOD_IN_PS = 1000
