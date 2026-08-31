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

include $(PLATFORM_DIR)/asap7_base.mk

export PLATFORM = cryo7
export ASAP7_USE_VT = RVT

ifeq ($(CRYO_TEMP),iso10K)
  CRYO_LIB = $(CRYO_LIB_DIR)/iso-Ioff-libs/iso_off_10K_0.7V.lib
else ifeq ($(CRYO_TEMP),iso77K)
  CRYO_LIB = $(CRYO_LIB_DIR)/iso-Ioff-libs/iso_off_77K_0.7V.lib
else ifeq ($(CRYO_TEMP),iso300K)
  CRYO_LIB = $(CRYO_LIB_DIR)/iso-Ioff-libs/iso_off_300K_0.7V.lib
else
  CRYO_LIB = $(CRYO_LIB_DIR)/0.7V_$(CRYO_TEMP).lib
endif

# The cryo .lib has max_capacitance but no max_transition; CTS (CTS-0107) needs
# it from the liberty, so use a generated copy with ASAP7's default (320ps).
CRYO_LIB_SRC := $(CRYO_LIB)
CRYO_LIB     := $(PLATFORM_DIR)/gen/$(notdir $(basename $(CRYO_LIB_SRC)))_maxtran.lib
$(shell mkdir -p $(PLATFORM_DIR)/gen; \
  if [ ! -f $(CRYO_LIB) ] || [ $(CRYO_LIB_SRC) -nt $(CRYO_LIB) ]; then \
    sed 's/^\(\s*\)default_leakage_power_density : 0 ;/&\n\1default_max_transition : 0.320 ;/' $(CRYO_LIB_SRC) > $(CRYO_LIB); fi)

# Override every liberty the base platform selected (all corners -> one cryo corner).
export LIB_FILES      = $(CRYO_LIB) $(PLATFORM_DIR)/cryo7_tie_R.lib $(ADDITIONAL_LIBS) $(WRAP_LIBS) $(WRAPPED_LIBS)
export DFF_LIB_FILE   = $(CRYO_LIB)
export BC_NLDM_LIB_FILES = $(CRYO_LIB)
export WC_NLDM_LIB_FILES = $(CRYO_LIB)
export TC_NLDM_LIB_FILES = $(CRYO_LIB)
export BC_NLDM_DFF_LIB_FILE = $(CRYO_LIB)
export WC_NLDM_DFF_LIB_FILE = $(CRYO_LIB)
export TC_NLDM_DFF_LIB_FILE = $(CRYO_LIB)
export VOLTAGE = 0.7
export TEMPERATURE = $(CRYO_TEMP)
