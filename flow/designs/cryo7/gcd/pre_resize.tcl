# cryo7 knob hook: leakage cap for resizer cell swaps (default 4x)
if { [info exists ::env(SIZING_LEAKAGE_LIMIT)] && $::env(SIZING_LEAKAGE_LIMIT) != "" } {
  log_cmd set_opt_config -sizing_leakage_limit $::env(SIZING_LEAKAGE_LIMIT)
}
