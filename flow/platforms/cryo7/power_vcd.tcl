# Standalone post-route power report with VCD-annotated switching activity.
# Reports power twice: with ORFS's default (static probability) activity and
# with activity read from a gate-level simulation VCD, so the two are directly
# comparable in one log.
#
# Env: ODB_FILE SDC_FILE SPEF_FILE VCD_FILE LIB_FILES [VCD_SCOPE=TOP/tb/dut]
foreach lib [split $env(LIB_FILES)] {
  read_liberty $lib
}
read_db $env(ODB_FILE)
read_sdc $env(SDC_FILE)
read_spef $env(SPEF_FILE)

puts "===== report_power: default activity ====="
report_power

set scope [expr {[info exists env(VCD_SCOPE)] ? $env(VCD_SCOPE) : "TOP/tb/dut"}]
read_vcd -scope $scope $env(VCD_FILE)
puts "===== report_power: VCD activity ($env(VCD_FILE)) ====="
report_power
