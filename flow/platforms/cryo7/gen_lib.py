#!/usr/bin/env python3
"""Generate the patched cryo7 liberty from the cda-tum cryogenic library.

Fixes applied to the source liberty (see config.mk for why each matters):
- default_max_transition: absent in the cryo lib; CTS (CTS-0107) reads it
  from liberty only. ASAP7's default of 320 ps (0.320 ns here).
- default_operating_conditions: absent (and no voltage_map/pg_pin), which
  makes OpenSTA resolve the rail voltage to 0.0 V and silently report zero
  switching power. Point it at the lib's own operating_conditions(typical).
- clock-gate attributes on ICG* cells: the cryo lib carries the 19 ASAP7 ICG
  cells but never marks them (`clock_gating_integrated_cell`,
  `clock_gate_{clock,enable,test,out}_pin`), so yosys `clockgate`
  (INFER_CLKGATES) silently infers nothing. Copied from the stock ASAP7 SEQ
  liberty, whose ICG cells these are 1:1.
- TIEHI/TIELO supplement cells spliced in from cryo7_tie_R.lib: one merged
  liberty keeps external ABC mappers working (yosys emits `read_lib -m` for
  a second -liberty file, which older ABC forks do not support).

Usage: gen_lib.py <src.lib> <tie.lib> <out.lib>
"""
import re
import sys

ICG_PIN_ATTRS = {
    'CLK': 'clock_gate_clock_pin : true ;',
    'ENA': 'clock_gate_enable_pin : true ;',
    'SE': 'clock_gate_test_pin : true ;',
    'GCLK': 'clock_gate_out_pin : true ;',
}


def main():
    src, tie, out = sys.argv[1:4]
    lines = open(src).read().splitlines(keepends=True)
    result = []
    in_icg = False
    icg_depth = 0
    for line in lines:
        result.append(line)
        indent = line[:len(line) - len(line.lstrip())]
        m = re.match(r'\s*cell\((\w+)\)\s*\{', line)
        if m:
            in_icg = m.group(1).startswith('ICG')
            icg_depth = line.count('{') - line.count('}')
            if in_icg:
                result.append(indent + '  clock_gating_integrated_cell : latch_posedge_precontrol ;\n')
            continue
        if in_icg:
            icg_depth += line.count('{') - line.count('}')
            if icg_depth <= 0:
                in_icg = False
                continue
            pm = re.match(r'\s*pin\((\w+)\)\s*\{', line)
            if pm and pm.group(1) in ICG_PIN_ATTRS:
                result.append(indent + '  ' + ICG_PIN_ATTRS[pm.group(1)] + '\n')
        if re.match(r'\s*default_leakage_power_density : 0 ;', line):
            result.append(indent + 'default_max_transition : 0.320 ;\n')
            result.append(indent + 'default_operating_conditions : typical ;\n')

    # drop the library's closing brace, splice in the tie cells, close again
    while result and result[-1].strip() != '}':
        result.pop()
    result.pop()
    tie_lines = open(tie).read().splitlines(keepends=True)
    start = next(i for i, l in enumerate(tie_lines) if re.match(r'\s*cell ?\(', l))
    end = len(tie_lines) - 1 - next(i for i, l in enumerate(reversed(tie_lines))
                                    if l.strip() == '}')
    result.extend(tie_lines[start:end])
    result.append('}\n')
    open(out, 'w').writelines(result)


if __name__ == '__main__':
    main()
