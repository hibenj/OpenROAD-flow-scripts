> Results archive of the cryo7 knob sweeps. The `platform_cryo7/` and `design_cryo7_*/`
> directories mentioned below are the platform and designs of this branch
> (`flow/platforms/cryo7`, `flow/designs/cryo7`). The cryogenic library itself is not
> included; see `../../README.md`.

# ORFS `cryo7` platform and knob sweeps on gcd (2026-08-27)

Full OpenROAD-flow-scripts (ORFS) runs on the cda-tum cryogenic ASAP7-RVT library
(`standard_cell_libraries/0.7V_{10K,300K}.lib`), testing which flow knobs matter for a
"minimise dynamic power, spend the leakage margin on delay/area" cryo objective.

## Layout
- `platform_cryo7/` — ORFS platform (`flow/platforms/cryo7/`): `config.mk` includes ASAP7's
  config (all physical data symlinked from `../asap7`) and swaps every liberty for the cryo lib
  selected by `CRYO_TEMP` (10K | 300K | iso10K | iso77K | iso300K). `cryo7_tie_R.lib` supplies
  TIEHI/TIELO (the only ASAP7-RVT cells missing from the cryo lib; leakage 0, uncharacterised).
  `setRC.tcl` is ASAP7's converted to the cryo lib units.
- `design_cryo7_gcd/` — ORFS design dir (`flow/designs/cryo7/gcd/`): SDCs in **ns**, per-period
  variants, `pre_resize.tcl` hook (`set_opt_config -sizing_leakage_limit $SIZING_LEAKAGE_LIMIT`).
- `scripts/` — sweep drivers (`run_sweep*.sh`, run via `xargs -P 3 -L1 script < todo`),
  metric collectors (`collect*.py`, run from `flow/`), and `verify_paper_numbers.py`
  (run from `results/`; recomputes every paper-table number from the raw files here).
- `sdc_asap7/` — per-period SDCs (ps) for the stock `asap7/gcd` multi-Vt experiment.
- `results/` — collected tables per sweep, `metrics_json/` (ORFS `6_report.json` of all runs),
  and `power_vcd/` (the calibrated default-vs-VCD `report_power` outputs backing every
  power number labeled "calibrated").
- `status/` — todo lists and OK/FAIL status per sweep.

## Porting gotchas (needed for any cryo-aware flow)
1. Cryo lib units are ns / pF / ohm / uW; ASAP7 is ps / fF / kohm / pW. OpenSTA interprets SDC and
   `set_layer_rc` in the units of the first liberty read, so SDCs must be in ns, `setRC.tcl`
   converted, and `ABC_CLOCK_PERIOD_IN_PS` set explicitly (ORFS derives it from the SDC as ps).
2. The cryo lib has `max_capacitance` but no `max_transition`; CTS reads max slew only from the
   liberty (`cts/src/TechChar.cpp:613-622`, error CTS-0107). `config.mk` auto-generates
   `gen/*_maxtran.lib` adding `default_max_transition : 0.320` (ASAP7's 320 ps).
3. `RECOVER_POWER` is silently skipped unless `OPT_POST_GRT_WNS=0` (`scripts/global_route.tcl:137`).
4. asap7/gcd is a smoketest config: `SKIP_LAST_GASP=1`, and `ENABLE_PLACE_REPAIR_TIMING` defaults
   to 0, so the resizer touches 2-4 cells. All "corrected" sweeps use
   `ENABLE_PLACE_REPAIR_TIMING=1 SKIP_LAST_GASP=0 OPT_POST_GRT_WNS=0`.
5. ASAP7 `DONT_USE_CELLS = *x1p* *xp* SDF* ICG*` excludes all sub-x1 drive strengths "to ease
   congestion" (`platforms/asap7/config.mk:22`).
6. With the relaxed DONT_USE list at tight clocks, `CORE_UTILIZATION=65` overflows in CTS
   (DPL-0038); 40 works. Derived place density >1.0 aborts floorplan (FLW-0024) at util >=80-90.

## Results (see `results/*.txt` for full tables)
Baseline gcd @310 ps: 10K leakage 3.7 nW / internal 1.16 mW / WNS -27 ps;
300K leakage 23.6 uW / internal 1.25 mW / WNS -11 ps. Switching power 0 (no activity supplied yet).

| Knob | Sweep | Result |
|---|---|---|
| `sizing_leakage_limit` 1x..inf | sweep2/3 (clocks 200-400 ps, both T) | no effect (WNS within 3.3 ps at every point except 230 ps/300K, 9 ps; caps >=4 give bit-identical netlists). In a single-Vt lib the cap never binds; default 4x is already unlimited in practice. |
| `RECOVER_POWER` 0/100 | sweep2 @400 ps | -5 ps slack for -0.5% area, -0.7% internal, -1% leakage. `recover_power` never reads leakage (`rsz/src/RecoverPower.cc:245-320`): it downsizes drivers on positive-slack paths. Area/dynamic knob paid in slack. |
| `CLOCK_PERIOD` Fmax | sweep3 | gcd closes ~320 ps at both T; 10K lib ~20-25 ps slower than 300K; leakage 10K 3.7-4.3 nW vs 300K 23-30 uW (+20% for fastest design). |
| `DONT_USE_CELLS` default vs `SDF* ICG*` | sweep4 | **Largest knob.** +11..+42 ps WNS, -1..-10% area, -29..-40% internal, ~-30% leakage over 230-320 ps at both T (area gain grows as the clock relaxes; default set closes at no clock, full set closes 320 ps at both T). Netlist becomes sub-x1 dominated (xp33/xp5/xp67). Temperature-independent: a dynamic-power/area win, not a leakage trade. |
| `CORE_UTILIZATION` 50-90 | sweep5 @320 ps | Default list never closes 320 ps at 10K; relaxed list closes at util 50-70 with core 46.3-46.7 um2 vs 65.6 um2 smallest near-passing default (300K) -> ~29% smaller core at equal timing. Util itself is a weak knob (area flat 50-70%). |
| Vt (ASAP7 RVT/LVT/SLVT @TT, 300K) | sweep6 (stock asap7/gcd) | RVT->SLVT: +155 ps WNS, -14% area, +5% internal for ~80x leakage (0.04 -> 3.4 uW) @320 ps. Cap 4x vs inf identical: synthesis already maps ~75% cells to SLVT (ABC sees all LIB_FILES); ORFS has no synthesis-time Vt control. At 10K the 3.4 uW scales by the measured ~6000x to ~0.5 nW -> trade becomes free (bound: no cryo LVT/SLVT characterisation). |

## Consolidated learnings: the cryo recipe

**Motivation, stated once.** At cryogenic temperatures leakage collapses (~5,500-6,300x measured
here: gcd 6338x, uart 5546x, aes 5524x, ibex 5756x), so the two-objective discipline of a room-temperature low-power flow
- minimise leakage, trading it against area/delay, AND minimise dynamic power - degenerates to
one objective: **minimise dynamic power; skip the leakage knobs entirely.** Every experiment in
this archive slots into that sentence, on one of three sides:

**1. What can be skipped at cryo (the leakage discipline), and what skipping it buys.**
- `sizing_leakage_limit`: already a no-op in a single-Vt library (never binds; leakage, area and
  drive strength are one axis). Skipping costs nothing - but nothing was being paid either.
- Vt restraint: the real 300K leakage discipline is avoiding LVT/SLVT. Dropping it (multi-Vt
  bound, stock ASAP7): **+100-155 ps WNS and -14% area for ~80x leakage** - a real price at
  300K, free at 10K (~80x of nanowatts). This is the largest single "skip it" dividend, and the
  cryo library's RVT-only characterisation is what currently blocks it.
- Device-level restraint: the iso-Ioff libraries lower Vth at cryo until leakage returns to the
  room-temperature budget - "skipping" at characterisation time: **+74/+84 ps at 77K/10K at the
  same clock and leakage budget** vs the constant-Vth libs (which instead give cold = slightly
  slower, leakage -> nW). The two characterisations bracket the design space.
- Power gating / sleep transistors: never needed at cryo. The calibrated leakage share at 300K
  on an idle-heavy workload is ~22% of total (ibex) - exactly the regime where a 300K design
  would add power gating, with all its area/latency/complexity cost. At 10K: ~0%, skip.
- `RECOVER_POWER` is not a leakage knob despite its placement in the flow: it is an
  area/dynamic-power recovery pass paid in slack, still useful at cryo.

**2. What actually minimises dynamic power (and what it delivers, VCD-calibrated).**
- `DONT_USE_CELLS` relaxation (admit sub-x1 drives): the headline flow knob. -18% total power
  calibrated (@320 ps), -1..-10% area, +11..+42 ps WNS over 230-320 ps, at both temperatures.
- `map -d` (dynamic-power-aware mapping): a modest, real win in the flow's DEFAULT
  configuration, honestly bounded by calibration. Three layers: (a) with the default DONT_USE
  list - the condition most users actually run - it wins on power, area and slack
  simultaneously (**-7.8% total calibrated at 300K, -5.4% area**; 10K power-neutral, -6.9%
  area, better slack); (b) with the full cell set the delay script already lands on low-power
  netlists - the dont-use relaxation (-18%) eats most of the headroom map -d was harvesting,
  so the two knobs OVERLAP and are not additive; (c) its cost model is *average* activity per
  cell, so the win shrinks under measured stimulus (empty-set: -8.8% default-activity ->
  -1.6% calibrated at 10K, flips +6% at 300K) - the measured motivation for activity-driven
  mapping (feed the VCD into the mapper). Independent of the percentages: the integration
  validated the PhD-era mapper end-to-end for the first time (finding the silently-discarded
  -D target, the tie-cell crash, the missing -X), and its dynamic-power-only cost function
  (no leakage term) is correct BY CONSTRUCTION for cryo rather than the limitation it would
  be at 300K.
- Clock gating (`INFER_CLKGATES`): honest verdict in four layers. (a) **Unconditional wins:
  area and timing** - on ibex 75 ICGs give -14% area (2879->2470 um2) and timing IMPROVES at
  both temps (300K -7->+7 ps, 10K -60->-20 ps) because extraction removes the enable-mux
  feedback from register data paths; these do not depend on workload. (b) **Power lost on
  every workload we measured**: calibrated on the idle-heavy instruction trace it is +21%/+32%
  total (300K/10K) - the top-level core clock gate (synthesized latch+AND, present in BOTH
  variants) already covers the idle tail, so the 75 fine ICGs' larger clock tree is pure CTS
  overhead; on a ~100-flop uart, 2 ICGs raise clock-tree power +80% at 300K (611 uW -> 1.10 mW, 9->19 clkbufs) and +34% at 10K (601 -> 807 uW), total +37%/+18%. Scale and
  workload shape both matter. (c) **Default activity cannot judge it**: it claimed -92% for
  the same ibex comparison - it models gated clocks as still toggling per enable probability,
  structurally unable to rank gating options; the -92%-vs-+21% contrast is itself a
  methodology finding. (d) **Where it plausibly wins (open)**: large register banks AND a
  partially-idle ACTIVE phase (stalls, unused units) - the regime where per-bank gating beats
  the one top gate; unmeasured here. Paper placement: report both-sided - the area/timing win
  is real and free, the power claim must always name its workload, and no gating number from
  default activity should survive review.
- Activity calibration is not optional: default-activity power is wrong by 2.3x (gcd) to 3.2x
  (aes) to **20x (ibex, idle-heavy)** - the error grows with idle fraction, and default
  activity structurally cannot rank gating options (it models gated clocks as always toggling).

**3. What the tools silently get wrong on the way (the audit).**
Three liberty gaps that degrade silently (zero switching power from missing
default_operating_conditions; clock gating inert without clock_gate_* attributes;
CTS needing max_transition), the asap7 adder techmap forcing HAxp5 (~176 ps/stage here),
RECOVER_POWER skipped unless OPT_POST_GRT_WNS=0, smoketest configs with the resizer
effectively off, ORFS synthesis mapping 42-68% of cells to SLVT (clock-dependent) before the "leakage cap" ever
sees them, and the yosys<->external-ABC handoff bugs (read_lib -m/-X, scl cache not keyed on
the abc binary). A cryo-aware flow needs these fixed before any knob matters; all are patched
in the cryo7 platform / abc fork here.

The one-line recipe: **fix the silent tool gaps, relax the dont-use list, map for dynamic power
under the constrained cell set, calibrate with real activity - and spend the entire leakage
budget on Vt.** The last step is the genuinely cryo-specific one, and the one the current
library cannot yet express (RVT-only); the pseudo multi-Vt projection below estimates what it
would deliver (>=16% Fmax at -11% area for negligible leakage). The gap between today's flow
and a cryo-aware flow is, in the end, a characterisation gap more than an algorithm gap.

## Session 2026-08-31: activity calibration, `map -d` integration, clock gating, scale-out

### Three silent liberty gaps (all "the tool runs fine and reports nothing")
The cryo liberty is missing three declarations, each of which makes a flow feature silently
degrade rather than fail. All are patched by `platform_cryo7/gen_lib.py` (which replaced the
`config.mk` sed pipeline):
1. no `default_max_transition` -> CTS-0107 (known since 08-27);
2. **no `default_operating_conditions` (and no `voltage_map`/`pg_pin`)** -> OpenSTA
   `Power::pgPortVoltage` resolves the rail voltage to 0.0 V and every `report_power` in every
   run to date printed **Switching Power = 0.00 with no warning** (`sta/power/Power.cc:1667-73`);
3. **no `clock_gating_integrated_cell` / `clock_gate_{clock,enable,test,out}_pin` attributes on
   the 10 ICG cells** -> yosys `clockgate` (ORFS `INFER_CLKGATES`) infers nothing, bit-identical
   netlists, no message. Attributes copied 1:1 from the stock ASAP7 SEQ liberty.

### VCD-calibrated power (infrastructure now in the platform)
`gen_sim_models.py` derives Verilator-compatible zero-delay behavioral Verilog for all 202 cells
straight from the liberty (official ASAP7 models use UDPs Verilator rejects); self-checking
testbenches (`tb_gcd.sv` random handshake, `tb_uart.sv` serial loopback with idle gaps) pass
2000 txns / 64 bytes with 0 mismatches on every netlist tried -> validates the generated models.
`run_power_vcd.sh <results_dir> <T> <clk_ps> [tb]` reports default-activity vs `read_vcd`
side by side. Verilator needs `-fno-inline` or it inlines the cell models and only ~30% of pins
appear in the VCD (379 vs 1331+ annotated on gcd).
**Calibration verdict on gcd @310 ps: default activity overestimates total power ~2.3x, and the
clock tree is ~1/3 of true total.** The 08-27 DONT_USE headline survives calibration: -18% total
power at both temperatures (s4 variants, 676->556 uW @10K).

### `map -d` (dynamic-power-aware ABC mapper) inside the full flow
ORFS `cryo7-platform` branch adds `ABC_EXE`/`ABC_SCRIPT` hooks (yosys `abc -exe`) +
`scripts/abc_power.script`; the cda-tum abc `power_read_in_avg` fork builds and runs in the flow.
Integration cost four found bugs: fork asserts on 0-switching tie cells (fixed,
abc commit `a54c76e16`); fork lacks yosys's `read_lib -m` (fixed by merging tie cells into the
one generated liberty) and `read_lib -X` (open: run with empty `DONT_USE_CELLS`); yosys's
liberty->scl cache is not keyed on the abc executable and hands the fork an unreadable .scl
("Wrong version of the SCL file") -> private TMPDIR with a *file* named `yosys-liberty-scl-cache`
forces the liberty fallback. Also: ORFS's asap7 adder techmap (`ADDER_MAP_FILE`) instantiates
HAxp5 whose S-arc is ~176 ps in the cryo lib -> two in series = -0.27 ns WNS; all yosys-path
runs use `ADDER_MAP_FILE=`.
**Result (gcd @310 ps, util 40, empty DONT_USE, vs `abc_speed` same config):** default activity:
10K internal -10.2% / total -8.8%, better WNS, equal area; 300K neutral. **VCD-calibrated the
advantage shrinks: 10K 613->603 uW (-1.6%), 300K 625->662 uW (flips negative)** — the mapper
optimises an average-activity cost model; feeding measured activities into mapping is the
roadmap item this motivates.

### `INFER_CLKGATES` (uart, after liberty fix)
2 ICGs inferred, timing met. Calibrated with realistic idle-gapped stimulus: **gating loses on
uart — clock-tree power +80% at 300K (611 uW -> 1.10 mW, 9 -> 19 clkbufs; at 10K, added 2026-09-08: 601 -> 807 uW, +34%, total 1.20 -> 1.41 mW, +18%)** since CTS builds and
balances each gated subtree; sequential/comb power unchanged. Note default activity can never
show a gating win (it models the gated clock as always toggling). Needs ibex-scale register
banks + idle-heavy workloads; ibex ICG variants queued.

### Scale-out baselines (`ADDER_MAP_FILE=`, default activity)
| design (clk) | T | WNS ps | area um2 | leakage | total |
|---|---|---|---|---|---|
| uart (270 ps) | 300K | +10.3 | 82 | 33.6 uW | 2.92 mW |
| uart | 10K | +4.5 | 82 | 6.1 nW | 2.74 mW (calibrated 1.20 mW, added 2026-09-08) |
| aes (380 ps) | 300K | +0.8 | 1520 | 758 uW | 96.6 mW |
| aes | 10K | -8.5 | 1549 | 137 nW | 93.3 mW |
| ibex (1 ns) | 300K | -7.1 | 2879 | 1.30 mW | 111 mW |
| ibex | 10K | -60.3 | 2896 | 225 nW | 109 mW |

Leakage collapse is ~5,500-6,300x at every size (gcd 6338x, uart 5546x, aes 5524x, ibex 5756x); the 10K lib's delay penalty grows with logic
depth (gcd -16 ps, ibex -53 ps at 1 ns). ibex's `prim_clock_gating` maps to no ICGs in the
baseline (0 in netlist).

### `INFER_CLKGATES` on ibex and `map -d` x DONT_USE (post-backport)
ibex `INFER_CLKGATES`: **75 ICGs inferred; area -14% (2879 -> 2470 um2); timing improves**
(300K -7.1 -> +7.1 ps, meets 1 ns; 10K -60 -> -20 ps) because clock-gate extraction removes the
enable-mux feedback from register D-paths — these wins are workload-independent. The power
story is the opposite of what default activity claims: -92% under default activity, but
**+21%/+32% total (300K/10K) once calibrated** on the instruction-trace workload (see the
calibrated-workloads section) — the top-level core clock gate already covers the idle tail,
so the fine-grained ICG tree is pure CTS overhead there. The honest claim is two-sided:
gating's area/timing benefit is free; its power benefit exists only for workloads with a
partially-idle active phase, and was not reached by any workload measured here.

With `read_lib -X` backported into the abc fork (commit `7b614afa5`), `map -d` composes with
DONT_USE lists. gcd @310 ps, DEFAULT dont-use (`*_du_*` variants), **VCD-calibrated**:
300K 779 -> 718 uW (**-7.8% total**), -5.4% area, better WNS; 10K neutral power, -6.9% area.
Combined with the empty-dont-use runs (where calibrated map -d was neutral/negative): the
power-aware mapper pays off when the cell set is constrained; with every drive strength
available, the delay-oriented script already reaches low-power netlists. The two knobs
overlap rather than add - the dont-use relaxation harvests most of the same headroom - so
map -d's place in the paper is "a modest, real win in the flow's default configuration,
honestly bounded by calibration": validated prior work whose measured limits point at
activity-driven mapping, not a second headline.

### Calibrated workloads for ibex and aes (self-checking testbenches)
`tb_ibex.sv`: behavioral memory serves a hand-assembled RV32I loop (100 ALU+store iterations,
self-checked by the store stream) ending in WFI with a ~1:12 idle tail. The gate-level ibex
executes it 100/100 correct at both temperatures and variants — validating the liberty-derived
models on a 2.5k-cell CPU. (TB gotcha: the generated DFF models apply async set/clear on the
falling edge, so reset must be deasserted at t0 and pulled low after.)
`tb_aes.sv`: FIPS-197 known-answer self-check (10/10 pass) plus random bursts with idle gaps.

**Calibrated verdicts.** Default activity overestimates total power by 2.3x (gcd) / 3.2x (aes)
/ **20x (ibex, idle-heavy)** — the error grows with idle fraction. Fine-grained ICG gating on
ibex is **+21% / +32% total power (300K/10K)** on the idle-heavy workload: the top-level core
clock gate (synthesized latch+AND, present in both variants) already covers the idle tail, so
the 75 ICGs' larger clock tree is pure overhead — their -14% area and timing wins remain.
Calibrated leakage share at 300K on idle-heavy work is ~22% of total vs ~0 at 10K: cryo pays
most exactly for idle-heavy workloads. aes calibrated: 29.9 mW @300K / 28.2 mW @10K.

### iso-Ioff libraries: the "spend the leakage margin" endpoint
gcd @310 ps, util 40, `CRYO_TEMP=iso{300K,77K,10K}` (root-level and iso libs are different
characterisations — never mix): iso300K WNS -13 ps / leakage 23 uW; **iso77K +74 ps / 150 uW;
iso10K +84 ps / 140 uW**. Same flow, same clock — swapping to the iso-leakage characterisation
(Vth lowered at cryo until leakage returns to the room-temperature budget) converts the cold
library from "slightly slower, leakage -> nW" (root libs) to "+25-30% timing headroom at an
unchanged leakage budget". The two characterisations bracket the paper's central trade
end-to-end. Caveat: the iso cold libs synthesize larger, hotter netlists (64 vs 47 um2,
internal power 3.7x), so this is a library-philosophy comparison, not same-netlist.

### Pseudo multi-Vt: the recipe's last step, projected (no cryo LVT/SLVT exists)
Producing a cryogenic LVT/SLVT characterization is out of reach for this paper, so the
"spend the leakage budget on Vt" step is run as a **sensitivity estimate**:
`gen_pseudo_vt.py` builds pseudo-cryo LVT/SLVT liberties from the real cryo RVT lib by applying
per-cell Vt-flavor ratios measured from stock room-temperature ASAP7 TT (SLVT ~100x leakage /
0.67x delay vs RVT; LVT ~10x / ~0.8x). Embedded assumption, to state in the paper: Vt-flavor
ratios are temperature-independent. `CRYO_VT=ALL` runs it (LVT/SLVT LEF/GDS via ASAP7_USE_VT).

Results (gcd @10K, empty dont-use, util 40, `vt{RVT,ALL}_P{310,260}` variants):
**multi-Vt closes 260 ps where RVT-only fails (-35 -> +11 ps), with -11% area, for ~28 nW of
leakage (~10x RVT's 3 nW - both nothing at 10 K) -> a >=16% Fmax projection**, reaching a
frequency single-Vt cannot hit at any power budget. At the relaxed 310 ps clock: -5% area,
+16 ps slack, +4.8% calibrated power. The flow mixes Vt selectively (244 R / 149 L / 41 SL),
unlike the blanket 42-68%-SLVT behavior of the room-temperature experiment. Mixed-Vt netlists pass
the self-checking gate-level sim. This is the flow-level projection that makes the
characterization ask concrete: here is what the flow would do - characterize LVT/SLVT to
confirm it.

## Open work
Workload sweep for gating (a partially-idle active phase is where the 75 ICGs could win); activity-driven mapping (feed VCD activities into `map -d`); backport `read_lib -X`
into the abc fork so map -d composes with DONT_USE lists; SLVT + relaxed DONT_USE combined;
77K (iso-Ioff) as a third temperature. Raw ORFS run dirs live in the ORFS checkout under
`flow/{logs,results,reports}/cryo7/{gcd,uart,aes,ibex}/` (not copied). ORFS-side code is on the
`cryo7-platform` branch of the working ORFS checkout; abc fix on `power_read_in_avg`.
