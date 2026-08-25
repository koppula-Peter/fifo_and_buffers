# Synchronous FIFO — Verification Plan

## 1. Strategy

Independent reference model + scoreboard (never derived from DUT outputs), directed corner
tests, constrained-random regression, bound SVA assertions, SBY formal (BMC+k-induction),
Vivado qualification. Tools: iverilog -g2012 (primary sim), verilator lint, yowasp-sby+z3.

## 2. Environment

```text
tb/common/fifo_ref_model.sv    behavioral queue (push/pop/flush, policy-aware)
tb/common/fifo_scoreboard.sv   compares DUT pops/pushes vs model; tracks invariants
tb/common/fifo_coverage.sv     functional coverage bins; prints COVER REPORT
tb/sync_fifo/tb_sync_fifo.sv   top: config sweep via plusargs (+MODE=directed|random|throughput...)
formal/sync_fifo/sync_fifo_props.sv      bindable assertions
formal/sync_fifo/sync_fifo_formal.sv     formal wrapper w/ shadow model
```

Reference model semantics mirror the SPEC (not RTL): queue of accepted pushes; pop returns
front; policies applied on full/empty; simultaneous corners per spec §5.

## 3. Directed tests (t_*)

| Test | Covers | Requirement |
|---|---|---|
| t_reset_basic / t_reset_midstream | CC-07, reset table | FUNC-011, COM-004 |
| t_single_wr_rd | basic datapath | FUNC-002 |
| t_fill_drain_full_empty | occupancy walk 0..DEPTH..0 | FUNC-003 |
| t_overflow / t_underflow (+policy matrix) | CC-01/02, both policies each side | FUNC-005 |
| t_simultaneous (full/mid/empty) | CC-03/04/05 | FUNC-006 |
| t_wrap (pow2 & non-pow2, repeated wraps ≥4×DEPTH ops) | CC-06/10 | FUNC-007 |
| t_thresholds | almost flags incl. exact boundary counts | FUNC-004 |
| t_fwft | show-ahead semantics, empty→first-word latency=1 | FUNC-008 |
| t_latency | timing tables spec §8 for OUTREG×FWFT grid | FUNC-009 |
| t_throughput | sustained 1+1/cycle with simultaneous streaming N=4·DEPTH | PERF-001/FUNC-001 |
| t_stats_sticky | counters saturate, sticky set/clear, CC-11 | FUNC-010 |
| t_debug_parity | dbg ptrs == internal refs (via hierarchical ref in TB only) | COM-007 |
| t_param_neg | illegal parameter elaboration failures caught via deferred compile runs | COM-002 |

## 4. Randomized verification

Constrained-random driver: wr_en prob p∈[0.3,0.7] swept, rd_en independent, data from
LFSR+counter mix (uniqueness detectable), bursts (1..8) with random gaps, occasional error_clear,
random resets (rare, mid-stream), DEPTH∈{2,3,15,16,17,64}, FWFT/OUTREG/policies cross-product
sampled. Seeds: default 1, plus {2,3} mandatory; failing seeds pinned to regressions/.
Pass = scoreboard clean + no assertion fires + final drain matches model exactly.

## 5. Assertions (bind, simulation+formal shared)

| Assertion | Property |
|---|---|
| a_reset_state | rst ⇒ next cycle count==0 && empty && !full |
| a_flag_count | full == (count==DEPTH); empty == (count==0) |
| a_bounds | count ≤ DEPTH always |
| a_reject_full | OVF_REJECT: full && wr_en ⇒ count unchanged && !do_push |
| a_reject_empty | rd_en && empty ⇒ count unchanged |
| a_simul_semantics | full&&both ⇒ pop accepted, push not; empty&&both inverse |
| a_order_pop | popped word equals oldest accepted-not-yet-popped (shadow queue check inside props for formal; TB uses scoreboard) |
| a_fwft_valid | FWFT: !empty ⇒ rd_data_valid |
| a_no_x_ctl | !\$isunknown({full,empty,count}) after reset release |
| a_event_corr | overflow_event ⇔ (wr_en && grant-blocked-or-overwrite) etc. |

## 6. Formal verification (SymbiYosys)

Harness `sync_fifo_formal.sv`: unconstrained wr_en/rd_en/data; shadow golden queue;
assumptions only reset-protocol related.

Properties:
- **f_no_loss_dup**: every accepted push appears exactly once in accepted-pop sequence until replay-free retirement.
- **f_order**: accepted-pop sequence == accepted-push sequence (queue equality).
- **f_flags**: full/empty ↔ count extremes.
- **f_bounds**: count ≤ DEPTH; pointers < DEPTH.
- **f_reject**: rejected ops never mutate state.
Modes: bmc depth 20; prove (k-induction) for bounds+flags+reject; order/no-loss via BMC20 +
induction where solver converges — engine smtbmc z3 (boolector fallback). Results logged with
exact mode/depth/engine; anything unproven listed OPEN (RSK-04 rule).

## 7. Coverage

Functional bins (fifo_coverage.sv): occupancy {0,1,mid,DEPTH−1,DEPTH}, wrap events, simul-rw
corners, ovf/unf per policy, thresholds crossing ±, FWFT first-word-after-empty, OUTREG modes,
DEPTH classes, backpressure streaks, reset-midstream, stats saturation, error_clear races.
Report printed at end (`COVER: name hit/total`), gate: 100% or documented waiver.

Code coverage: no collector in OSS toolchain → formally waived this milestone; documented in
COVERAGE section of milestone report (GAP-02/G-02 constraint).

## 8. Vivado qualification

OOC synth + impl per configuration C1..C8 (IMPLEMENTATION_PLAN §matrix), 10 ns clock,
report_utilization + report_timing_summary captured; acceptance: WNS≥0 all configs; BRAM/LUTRAM
inference as predicted by AUTO resolution (C5/C6/C8 must be BRAM36/18, C2/C7 LUTRAM).

## 9. Exit checklist mapping

See REQUIREMENTS_TRACEABILITY_MATRIX.md sync rows; milestone report consolidates evidence paths.
