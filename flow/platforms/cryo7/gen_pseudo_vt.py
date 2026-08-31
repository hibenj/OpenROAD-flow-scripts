#!/usr/bin/env python3
"""Generate pseudo-cryogenic LVT/SLVT liberties for the cryo7 platform.

No cryogenic characterization exists for ASAP7's LVT/SLVT flavors (the cda-tum
cryo library is RVT-only), so the multi-Vt "spend the leakage budget on Vt"
experiment can only be run as a SENSITIVITY ESTIMATE. This script builds
pseudo libs from the real cryo RVT lib by applying per-cell Vt-flavor ratios
measured from the stock room-temperature ASAP7 TT NLDM libraries:

    pseudo_cryo_<VT>(cell) = cryo_RVT(cell) * asap7_TT_<VT>(cell) / asap7_TT_RVT(cell)

per quantity: delay/slew/constraint tables, internal power tables, leakage,
input pin caps, max_capacitance. The embedded assumption - Vt-flavor ratios
are temperature-independent - is exactly the assumption to state in the paper;
results from these libs are flow-level projections, not silicon truth.

Usage: gen_pseudo_vt.py <cryo_gen_lib> <asap7_nldm_dir> <VT: L|SL> <out.lib>
(cryo_gen_lib = the gen/0.7V_*_maxtran.lib produced by gen_lib.py)
"""
import gzip
import re
import statistics
import sys


def read_text(path):
    with open(path, 'rb') as f:
        head = f.read(2)
    if head == b'\x1f\x8b':
        return gzip.open(path, 'rt').read()
    return open(path).read()


def cell_blocks(text):
    for m in re.finditer(r'\bcell\s*\(([^)]+)\)\s*\{', text):
        depth, j = 0, m.end() - 1
        while j < len(text):
            if text[j] == '{':
                depth += 1
            elif text[j] == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        yield m.group(1), text[m.start():j + 1]


FLOAT = re.compile(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?')


def table_values(body, headers):
    """All numbers inside values(...) of tables named by any of headers."""
    out = []
    for h in headers:
        for m in re.finditer(r'\b%s\s*\(' % h, body):
            vm = re.compile(r'values\s*\(').search(body, m.end())
            if not vm:
                continue
            end = body.find(');', vm.end())
            out += [float(x) for x in FLOAT.findall(body[vm.end():end])]
    return out


def cell_stats(body):
    delay = table_values(body, ['cell_rise', 'cell_fall'])
    power = table_values(body, ['rise_power', 'fall_power'])
    # stock ASAP7 keeps leakage only in leakage_power(){value:...} groups
    # (VSS entries are 0 - use the positive ones); the cryo lib also has a
    # cell_leakage_power attribute
    leaks = [float(x) for x in
             re.findall(r'\bvalue\s*:\s*"?([\d.eE+-]+)', body)
             if float(x) > 0]
    m = re.search(r'cell_leakage_power\s*:\s*"?([\d.eE+-]+)', body)
    if m and float(m.group(1)) > 0:
        leaks.append(float(m.group(1)))
    caps = [float(x) for x in
            re.findall(r'\bcapacitance\s*:\s*"?([\d.eE+-]+)', body)]
    maxcap = [float(x) for x in
              re.findall(r'max_capacitance\s*:\s*"?([\d.eE+-]+)', body)]
    return {
        'delay': statistics.median(delay) if delay else None,
        'power': statistics.median(map(abs, power)) if power else None,
        'leak': statistics.median(leaks) if leaks else None,
        'cap': statistics.median(caps) if caps else None,
        'maxcap': statistics.median(maxcap) if maxcap else None,
    }


def load_asap7_stats(nldm_dir, tag):
    import glob
    import os
    stats = {}
    for path in glob.glob(os.path.join(nldm_dir, '*_%s_TT_*' % tag)):
        for name, body in cell_blocks(read_text(path)):
            stats[name] = cell_stats(body)
    return stats


DELAY_HEADERS = ('cell_rise', 'cell_fall', 'rise_transition',
                 'fall_transition', 'rise_constraint', 'fall_constraint')
POWER_HEADERS = ('rise_power', 'fall_power')


def scale_cell(body, ratios, vt_suffix):
    out = []
    context = None            # which ratio applies to the next values(...)
    in_leakage_power = False
    for line in body.splitlines(keepends=True):
        cm = re.match(r'(\s*cell\s*\()(\w+?)_R(\)\s*\{.*)$', line, re.S)
        if cm:
            out.append(cm.group(1) + cm.group(2) + '_' + vt_suffix
                       + cm.group(3))
            continue
        h = re.match(r'\s*(\w+)\s*\(', line)
        if h and h.group(1) in DELAY_HEADERS:
            context = 'delay'
        elif h and h.group(1) in POWER_HEADERS:
            context = 'power'
        elif h and h.group(1) == 'leakage_power':
            in_leakage_power = True
        if 'values(' in line and context:
            r = ratios[context]
            line = re.sub(FLOAT, lambda m: '%.6g' % (float(m.group()) * r),
                          line)
        elif re.match(r'\s*cell_leakage_power\s*:', line) or \
                (in_leakage_power and re.match(r'\s*value\s*:', line)):
            line = re.sub(FLOAT, lambda m: '%.6g' % (float(m.group())
                                                     * ratios['leak']), line)
        elif re.match(r'\s*(rise_|fall_)?capacitance(_range)?\s*[:(]', line):
            line = re.sub(FLOAT, lambda m: '%.6g' % (float(m.group())
                                                     * ratios['cap']), line)
        elif re.match(r'\s*max_capacitance\s*:', line):
            line = re.sub(FLOAT, lambda m: '%.6g' % (float(m.group())
                                                     * ratios['maxcap']), line)
        if in_leakage_power and line.strip() == '}':
            in_leakage_power = False
        out.append(line)
    return ''.join(out)


def transform(cryo_text, ratios_for, vt_suffix):
    spans = []
    for m in re.finditer(r'\bcell\s*\(([^)]+)\)\s*\{', cryo_text):
        depth, j = 0, m.end() - 1
        while j < len(cryo_text):
            if cryo_text[j] == '{':
                depth += 1
            elif cryo_text[j] == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        spans.append((m.start(), j + 1, m.group(1)))

    preamble = cryo_text[:spans[0][0]]
    preamble = re.sub(r'(\blibrary\()([^)]+)(\))',
                      r'\1\2_pseudo' + vt_suffix + r'\3', preamble, count=1)
    out = [preamble]
    for start, end, name in spans:
        ratios = ratios_for(name)
        if ratios is None:
            continue          # no stock Vt pair: leave the cell out entirely
        out.append(scale_cell(cryo_text[start:end], ratios, vt_suffix))
        out.append('\n\n')
    out.append(cryo_text[spans[-1][1]:])
    return ''.join(out)


def main():
    cryo_lib, nldm_dir, vt, out_path = sys.argv[1:5]
    assert vt in ('L', 'SL')
    rvt = load_asap7_stats(nldm_dir, 'RVT')
    oth = load_asap7_stats(nldm_dir, 'SLVT' if vt == 'SL' else 'LVT')

    missing = []

    def ratios_for(rvt_name):
        vt_name = rvt_name[:-2] + '_' + vt
        a, b = rvt.get(rvt_name), oth.get(vt_name)
        if not a or not b:
            missing.append(rvt_name)
            return None
        r = {}
        for k in ('delay', 'power', 'leak', 'cap', 'maxcap'):
            r[k] = (b[k] / a[k]) if (a.get(k) and b.get(k)) else 1.0
        return r

    text = read_text(cryo_lib)
    open(out_path, 'w').write(transform(text, ratios_for, vt))
    print('wrote %s%s' % (out_path,
          ('; kept unscaled/unrenamed (no stock pair): ' + ' '.join(missing))
          if missing else ''))


if __name__ == '__main__':
    main()
