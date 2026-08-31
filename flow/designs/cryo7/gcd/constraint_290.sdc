# cryo7: SDC in ns (cryo liberty time_unit=1ns); ASAP7 original is 310ps.
current_design gcd

set clk_name core_clock
set clk_port_name clk
set clk_period 0.290
set clk_io_pct 0.2

set clk_port [get_ports $clk_port_name]

create_clock -name $clk_name -period $clk_period $clk_port
set clk_io_name vclk_$clk_name
create_clock -name $clk_io_name -period $clk_period
set_clock_latency 0.036225 [get_clocks $clk_name]
set_clock_latency 0.036225 [get_clocks $clk_io_name]

set non_clock_inputs [all_inputs -no_clocks]

set_input_delay [expr $clk_period * $clk_io_pct] -clock $clk_io_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_io_name [all_outputs]
