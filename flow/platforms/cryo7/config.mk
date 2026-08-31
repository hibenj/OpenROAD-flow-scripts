# cryo7: ASAP7 physical platform (LEF/GDS/RC/PDN/DRC unchanged, symlinked from
# ../asap7) timed with the cda-tum cryogenic-CMOS 0.7V ASAP7-RVT libraries.
#
#   CRYO_TEMP     10K (default) | 300K   -> root-level 0.7V_<T>.lib
#                 iso10K | iso77K | iso300K -> iso-Ioff-libs/ (different
#                 characterisation methodology; do not mix with root-level libs)
#   CRYO_LIB_DIR  location of the standard_cell_libraries checkout
#
# The cryo library is a 1:1 cell match with ASAP7 RVT except TIEHI/TIELO,
# supplied by cryo7_tie_R.lib (leakage 0, uncharacterised).
export CRYO_TEMP    ?= 10K
export CRYO_LIB_DIR ?= $(HOME)/Documents/Repositories/cda-tum/cryogenic-cmos/standard_cell_libraries

# CRYO_VT=ALL enables the pseudo multi-Vt SENSITIVITY mode: LVT/SLVT liberties
# synthesized by gen_pseudo_vt.py (cryo RVT scaled by room-temperature ASAP7
# Vt-flavor ratios - a projection, not characterized silicon). Must be decided
# before including asap7_base so the LVT/SLVT LEF/GDS get picked up.
export CRYO_VT ?= RVT
ifeq ($(CRYO_VT),ALL)
  export ASAP7_USE_VT = RVT LVT SLVT
else
  export ASAP7_USE_VT = RVT
endif

include $(PLATFORM_DIR)/asap7_base.mk

export PLATFORM = cryo7

ifeq ($(CRYO_TEMP),iso10K)
  CRYO_LIB = $(CRYO_LIB_DIR)/iso-Ioff-libs/iso_off_10K_0.7V.lib
else ifeq ($(CRYO_TEMP),iso77K)
  CRYO_LIB = $(CRYO_LIB_DIR)/iso-Ioff-libs/iso_off_77K_0.7V.lib
else ifeq ($(CRYO_TEMP),iso300K)
  CRYO_LIB = $(CRYO_LIB_DIR)/iso-Ioff-libs/iso_off_300K_0.7V.lib
else
  CRYO_LIB = $(CRYO_LIB_DIR)/0.7V_$(CRYO_TEMP).lib
endif

# The source liberty needs several fixes before the flow can use it —
# default_max_transition, default_operating_conditions, clock-gate attributes
# on the ICG cells, and the TIEHI/TIELO supplement spliced in. gen_lib.py
# documents each one; use the generated copy everywhere.
CRYO_LIB_SRC := $(CRYO_LIB)
CRYO_LIB     := $(PLATFORM_DIR)/gen/$(notdir $(basename $(CRYO_LIB_SRC)))_maxtran.lib
$(shell mkdir -p $(PLATFORM_DIR)/gen; \
  if [ ! -f $(CRYO_LIB) ] || [ $(CRYO_LIB_SRC) -nt $(CRYO_LIB) ] \
     || [ $(PLATFORM_DIR)/cryo7_tie_R.lib -nt $(CRYO_LIB) ] \
     || [ $(PLATFORM_DIR)/gen_lib.py -nt $(CRYO_LIB) ]; then \
    python3 $(PLATFORM_DIR)/gen_lib.py $(CRYO_LIB_SRC) $(PLATFORM_DIR)/cryo7_tie_R.lib $(CRYO_LIB); fi)

ifeq ($(CRYO_VT),ALL)
  CRYO_PSEUDO_LIBS = $(PLATFORM_DIR)/gen/pseudo_$(notdir $(basename $(CRYO_LIB_SRC)))_maxtran_L.lib \
                     $(PLATFORM_DIR)/gen/pseudo_$(notdir $(basename $(CRYO_LIB_SRC)))_maxtran_SL.lib
  $(shell for vt in L SL; do \
      out=$(PLATFORM_DIR)/gen/pseudo_$(notdir $(basename $(CRYO_LIB_SRC)))_maxtran_$$vt.lib; \
      if [ ! -f $$out ] || [ $(CRYO_LIB) -nt $$out ] || [ $(PLATFORM_DIR)/gen_pseudo_vt.py -nt $$out ]; then \
        python3 $(PLATFORM_DIR)/gen_pseudo_vt.py $(CRYO_LIB) $(PLATFORM_DIR)/../asap7/lib/NLDM $$vt $$out; fi; done)
else
  CRYO_PSEUDO_LIBS =
endif

# Override every liberty the base platform selected (all corners -> one cryo corner).
export LIB_FILES      = $(CRYO_LIB) $(CRYO_PSEUDO_LIBS) $(ADDITIONAL_LIBS) $(WRAP_LIBS) $(WRAPPED_LIBS)
export DFF_LIB_FILE   = $(CRYO_LIB)
export BC_NLDM_LIB_FILES = $(CRYO_LIB) $(CRYO_PSEUDO_LIBS)
export WC_NLDM_LIB_FILES = $(CRYO_LIB) $(CRYO_PSEUDO_LIBS)
export TC_NLDM_LIB_FILES = $(CRYO_LIB) $(CRYO_PSEUDO_LIBS)
export BC_NLDM_DFF_LIB_FILE = $(CRYO_LIB)
export WC_NLDM_DFF_LIB_FILE = $(CRYO_LIB)
export TC_NLDM_DFF_LIB_FILE = $(CRYO_LIB)
export VOLTAGE = 0.7
export TEMPERATURE = $(CRYO_TEMP)
