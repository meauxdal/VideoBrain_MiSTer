"""Summarize analyze_logic_csv outputs; no RTL expectations are fitted here."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd


def variants(op):
    # Fairchild F3850 Table 3; same independent transcription used by
    # tb_cpu_opcode_timing. Pairs are (ROMC, active PHI periods).
    fixed = {
        0x08: [(7, 6), (11, 6), (0, 4)],
        0x09: [(21, 6), (24, 6), (0, 4)],
        0x0C: [(18, 6), (20, 6), (0, 4)],
        0x0D: [(23, 6), (20, 6), (0, 4)],
        0x16: [(2, 6), (0, 4)], 0x17: [(5, 6), (0, 4)],
        0x1A: [(28, 4), (0, 4)], 0x1B: [(28, 4), (0, 4)],
        0x1D: [(28, 4), (0, 4)], 0x1C: [(4, 4), (0, 4)],
        0x26: [(3, 6), (27, 6), (0, 4)],
        0x27: [(3, 6), (26, 6), (0, 4)],
        0x28: [(3, 6), (13, 4), (12, 6), (20, 6), (0, 4)],
        0x29: [(3, 6), (12, 6), (20, 6), (0, 4)],
        0x2A: [(17, 6), (3, 4), (14, 6), (3, 4), (0, 4)],
        0x2C: [(29, 4), (0, 4)],
    }
    if op in (0x0E, 0x11): return [[(6, 6), (9, 6), (0, 4)]]
    if op in (0x0F, 0x10): return [[(22, 6), (25, 6), (0, 4)]]
    if op in fixed: return [fixed[op]]
    if 0x20 <= op <= 0x25: return [[(3, 6), (0, 4)]]
    if 0x30 <= op <= 0x3E: return [[(0, 6)]]
    if 0x80 <= op <= 0x87 or 0x90 <= op <= 0x9F:
        return [[(28, 4), (3, 4), (0, 4)], [(28, 4), (1, 6), (0, 4)]]
    if 0x88 <= op <= 0x8D: return [[(2, 6), (0, 4)]]
    if op == 0x8E: return [[(10, 6), (0, 4)]]
    if op == 0x8F: return [[(3, 4), (0, 4)], [(1, 6), (0, 4)]]
    if op in (0xA0, 0xA1, 0xB0, 0xB1) or 0xD0 <= op <= 0xDE:
        return [[(28, 4), (0, 4)]]
    if 0xA4 <= op <= 0xAF: return [[(28, 6), (27, 6), (0, 4)]]
    if 0xB4 <= op <= 0xBF: return [[(28, 6), (26, 6), (0, 4)]]
    if (0x2D <= op <= 0x2F or op in (0xA2, 0xA3, 0xB2, 0xB3) or
            op >= 0x30 and op % 16 == 15 and (op < 0x60 or op >= 0xC0)):
        return []
    return [[(0, 4)]]


def stats(values):
    a = np.asarray(values, dtype=float)
    return dict(n=len(a), **({} if not len(a) else {
        "min_us": float(a.min()/1e6), "median_us": float(np.median(a)/1e6),
        "p01_us": float(np.quantile(a, .01)/1e6),
        "p99_us": float(np.quantile(a, .99)/1e6), "max_us": float(a.max()/1e6),
        "modes_us": {f"{k/1e6:.4f}": int(v) for k, v in
                     pd.Series(a).value_counts().head(8).items()}}))


def cumulative_high(events, bit):
    t = events.time_ps.to_numpy()
    high = ((events.state.to_numpy() >> bit) & 1).astype(np.int64)
    integral = np.r_[0, np.cumsum(np.diff(t) * high[:-1])]
    def at(points):
        ix = np.searchsorted(t, points, side="right")-1
        ix = np.maximum(ix, 0)
        return integral[ix] + (points-t[ix])*high[ix]
    return at


def summarize(root):
    result = {}
    for name in ("vbnormalwreset", "vbdiagwreset", "vbnobios1wreset"):
        meta = (root/f"{name}-meta.txt").read_text().splitlines()
        spans = [tuple(map(int, x.split()[1:])) for x in meta if x.startswith("reset_high_ps")]
        h = pd.read_csv(root/f"{name}-hist.csv")
        h = h[(h.channel == 2) & (h.kind == 1) & (h.edge == 0)]
        ordinary = h[h.duration_ps.between(400000, 600000)]
        period = float(np.average(ordinary.duration_ps, weights=ordinary["count"]))
        g = pd.read_csv(root/f"{name}-gaps.csv")
        g = g[(g.channel == 2) & (g.edge == 0)].copy()
        valid = np.zeros(len(g), dtype=bool)
        # Guard 100 us at both ends of each reset-high segment.
        for start, end in spans:
            valid |= (g.start_ps >= start+100000000) & (g.end_ps <= end-100000000)
        g = g[valid].copy()
        events = pd.read_csv(root/f"{name}-events.csv")
        dma_integral = cumulative_high(events, 4)
        # Also reject DMA request activity during the preceding 2 us.
        g["dma_guard_clear"] = (dma_integral(g.end_ps.to_numpy()) ==
                                dma_integral(g.start_ps.to_numpy()-2000000))
        rows = {}
        for mask, label in ((9, "ram_cart_read"), (5, "uv201_read"), (3, "write_region_unknown")):
            a = g[(g.request_codes_seen == mask) & g.dma_guard_clear & (g.dma_levels_seen == 1)]
            rows[label] = stats(a.duration_ps)
            if len(a):
                rows[label]["sunk_clocks_median"] = float(np.median(a.duration_ps)/period-1)
                a.head(12).to_csv(root/f"{name}-{label}-examples.csv", index=False)
        rows["dma_observed"] = stats(g[g.dma_levels_seen != 1].duration_ps)
        rows["unclassified_request_masks"] = {str(k): int(v) for k, v in g.request_codes_seen.value_counts().items()}
        result[name] = {"ordinary_phi_period_ns": period/1000, "reset_high_spans_ps": spans,
                        "guarded_phi_falling_gaps": len(g), "classes": rows}
    c = pd.read_csv(root/"timeshare-cycles.csv")
    fetch = np.flatnonzero(c.romc.to_numpy() == 0)
    mismatches, opcodes, checked, undefined, mismatch_count = [], set(), 0, 0, 0
    seq = list(zip(c.romc.astype(int), c.phi_falls.astype(int)))
    for a, b in zip(fetch[:-1], fetch[1:]):
        op = int(c.iloc[a].data_end)
        expected = variants(op)
        if not expected: undefined += 1; continue
        observed = seq[a+1:b+1]
        checked += 1; opcodes.add(op)
        if observed not in expected:
            mismatch_count += 1
            if len(mismatches)<20: mismatches.append({"cycle": int(a), "opcode": op, "observed": observed})
    # Infer DC0 only after its bytes have been observed on the bus. Never
    # assume a reset value: this capture starts in the middle of execution.
    dc, aux = [None, None], [None, None]  # low, high
    addresses, dc_checks, dc_errors = [], 0, 0
    for row in c.itertuples():
        address = None if None in dc else dc[0] + 256*dc[1]
        addresses.append(-1 if address is None else address)
        r, data = row.romc, row.data_end
        if r in (0x0E, 0x19): dc[0] = data
        elif r in (0x11, 0x16): dc[1] = data
        elif r == 0x1D: dc, aux = aux, dc
        elif r in (0x02, 0x05, 0x0A):
            if address is None: dc = [None, None]
            else:
                delta = (data if data < 128 else data-256) if r == 0x0A else 1
                address = (address+delta) & 65535
                dc = [address & 255, address >> 8]
        elif r in (0x06, 0x09):
            part = dc[1 if r == 0x06 else 0]
            if part is not None:
                dc_checks += 1; dc_errors += int(part != data)
    c["inferred_dc0"] = addresses
    def region(a):
        if a < 0: return "unknown"
        a &= 0x3FFF
        if 0x2800 <= a < 0x3000: a -= 0x2000
        if a < 0x0800: return "res1"
        if a < 0x0C00: return "uv201"
        if a < 0x1000: return "ram"
        if a < 0x2000: return "cart"
        if a < 0x2800: return "res2"
        return "other"
    c["inferred_region"] = [region(a) for a in addresses]
    c.to_csv(root/"timeshare-addressed-cycles.csv", index=False)
    long = c[c.max_phi_gap_ps > 800000]
    result["timeshare"] = {
        "completed_bus_cycles": len(c), "active_period_counts": {str(k): int(v) for k,v in c.phi_falls.value_counts().items()},
        "fetch_data_sample_disagreements": int((c[c.romc == 0].data_end != c[c.romc == 0].data_write_rise).sum()),
        "instructions_checked": checked, "distinct_opcodes": sorted(opcodes),
        "undefined_opcode_fetches": undefined, "mismatch_count": mismatch_count, "first_mismatches": mismatches,
        "dc_readback_checks": dc_checks, "dc_readback_mismatches": dc_errors,
        "inferred_lm_st_regions": {f"{r:02X}_{region}": {
            "cycles": len(v), "paused": stats(v[v.max_phi_gap_ps > 800000].max_phi_gap_ps),
            "excess": stats((v.end_ps-v.start_ps)-v.phi_falls*500000)}
            for (r, region),v in c[c.romc.isin([2,5])].groupby(["romc", "inferred_region"])},
        "paused_cycles_by_romc": {f"{k:02X}": stats(v.max_phi_gap_ps) for k,v in long.groupby("romc")},
        "cycle_excess_by_romc": {f"{k:02X}": stats((v.end_ps-v.start_ps)-v.phi_falls*500000) for k,v in long.groupby("romc")},
    }
    sim = pd.read_csv(root/"simulation.csv")
    result["simulation_same_polarity_gaps"] = {str(k): stats(v.gap_mclk*1e12/14318181) for k,v in sim.groupby("access_case")}
    (root/"summary.json").write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    summarize(parser.parse_args().directory)
