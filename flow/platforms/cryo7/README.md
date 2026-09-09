# cryo7: ORFS platform for cryogenic ASAP7

`cryo7` runs the complete OpenROAD flow (synthesis through sign-off) on the
ASAP7 physical stack timed with cryogenic standard-cell characterizations.
The LEF/GDS/RC/PDN/DRC data are ASAP7's own (symlinked from `../asap7`); only
the liberty views are exchanged. A 10 K and a 300 K run therefore differ in
nothing but the cell characterization. This branch is the flow side of the
paper *Right Knobs, Wrong Defaults: Configuring an Open-Source RTL-to-GDS Flow for
Cryogenic CMOS* (DATE 2027 submission).

## Prerequisite: a cryogenic library

The cryogenic standard-cell library used in the paper is **not open source**
and is not part of this repository. To run the platform, point
`CRYO_LIB_DIR` at your own cryogenic characterization of the ASAP7 cells,
laid out as

```
<CRYO_LIB_DIR>/0.7V_10K.lib
<CRYO_LIB_DIR>/0.7V_300K.lib
<CRYO_LIB_DIR>/iso-Ioff-libs/iso_off_{10K,77K,300K}_0.7V.lib
```

or adapt the file names in `config.mk`. `gen_lib.py` derives the liberty the
flow actually reads (adds the default operating condition, the
max-transition limit, the clock-gate attributes on the ICG cells, and the
TIEHI/TIELO cells from `cryo7_tie_R.lib`) into `gen/` at build time; nothing
derived from the library is committed.

## Variables

| Variable | Values | Meaning |
|---|---|---|
| `CRYO_TEMP` | `10K` (default), `300K`, `iso10K`, `iso77K`, `iso300K` | which characterization to time with; root-level (constant design Vth) and `iso*` (iso-Ioff) libraries are different characterizations, do not mix them in one comparison |
| `CRYO_LIB_DIR` | path | library checkout, see above |
| `CRYO_VT` | `RVT` (default), `ALL` | `ALL` adds pseudo-cryogenic LVT/SLVT liberties built by `gen_pseudo_vt.py` from the RVT library scaled by room-temperature ASAP7 flavor ratios: a sensitivity projection, not characterized silicon |
| `ABC_EXE`, `ABC_SCRIPT` | path | run an external ABC binary / script as the technology mapper (used for the dynamic-power-aware mapper of `cda-tum/abc`, branch `power_read_in_avg`, with `scripts/abc_power.script`) |
| `PRE_RESIZE_TCL` | path | hook used by the designs to set the resizer's leakage cap (`set_opt_config -sizing_leakage_limit`) |

## Designs

`flow/designs/cryo7/{gcd,uart,aes,ibex}`: clocks 310 ps, 270 ps, 380 ps,
1 ns (SDCs in ns, the library's time unit). Each design ships a self-checking
gate-level testbench (`tb_*.sv`): random operands (gcd), serial loopback with
idle gaps (uart), FIPS-197 known-answer vectors plus random bursts (aes), a
hand-assembled RV32I loop verified by its store stream and followed by an
idle tail (ibex).

```
cd flow
make DESIGN_CONFIG=designs/cryo7/gcd/config.mk CRYO_TEMP=300K FLOW_VARIANT=300K ADDER_MAP_FILE=
```

`ADDER_MAP_FILE=` disables the ASAP7 adder techmap, whose half-adder arcs are
slow under this library.

## Calibrated power

`verilog_sim/run_power_vcd.sh` simulates the final routed netlist with
behavioral cell models generated from the liberty (`gen_sim_models.py`),
runs the design's testbench, and reports power twice, with the default
activity model and with the recorded per-pin activity:

```
cd flow
./platforms/cryo7/verilog_sim/run_power_vcd.sh results/cryo7/gcd/300K 300K 310 designs/cryo7/gcd/tb_gcd.sv
```

## Results

`experiments/knob_sweeps/` holds the archived measurements behind every
number in the paper (sweep tables, per-run metrics, calibrated power reports)
and `scripts/verify_paper_numbers.py`, which recomputes the paper's tables
from them.
