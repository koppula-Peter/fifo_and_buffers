# Implementation Plan

Baseline: standalone repo `/home/peter/Desktop/fifo_and_buffers`, phases per mandate §57.
Each phase ends with a milestone report + DoD checklist before proceeding (hard gate).

## Phase schedule and exit criteria

| Phase | Content | Exit evidence | Status |
|---|---|---|---|
| 0 Audit | audit docs, reqs skeleton, plans | docs/audit/* committed | **DONE** |
| 1 Common infra | fifo_pkg, fifo_mem, TB framework, regression script, Makefile | lint+compile PASS, t_common green | **DONE this milestone** |
| 2 Sync FIFO | full DoD: spec→RTL→TB→SVA→formal→Vivado | MILESTONE_SYNC_FIFO_REPORT.md all-PASS | **THIS MILESTONE** |
| 3 Async+Dual-Clock | ADR-002, CDC doc, formal CDC proofs, Vivado CDC review | milestone report | OPEN |
| 4 Width-Conv | ADR-004 residual semantics | milestone report | OPEN |
| 5 Packet | ADR-003 atomic commit | milestone report | OPEN |
| 6 Frame | atomic frames, policies | milestone report | OPEN |
| 7 Priority | arbitration + starvation proof tests | milestone report | OPEN |
| 8 Multi-Queue | ADR-005 trade study then build | milestone report | OPEN |
| 9 Circular | trigger/pre-post capture | milestone report | OPEN |
| 10 Elastic | reuse async core, mismatch telemetry | milestone report | OPEN |
| 11 Replay | ADR-006 seq arithmetic, rollover tests | milestone report | OPEN |
| 12 Jitter | THEORY/REQ/ARCH docs first, then RTL | milestone report | OPEN |
| 13 AXI/SW | axi4s/axi4lite wrappers, regs, IRQ, sw tree | register map + driver docs | OPEN |
| 14 ZC702 | demo design, Vitis tests, ILA | hw validation log | OPEN |
| 15 Release | family regression, traceability closure, release notes | RELEASE_CHECKLIST green | OPEN |

## Milestone 2 (Sync FIFO) work breakdown

1. Spec frozen (docs/specs/SYNC_FIFO_PRODUCT_SPECIFICATION.md) ✔ planned
2. Architecture incl. ADR-001..004 subset applicable (memory abstraction; semantics) ✔ planned
3. RTL: rtl/common/fifo_pkg.sv, rtl/common/fifo_mem.sv, rtl/sync_fifo/sync_fifo.sv
4. TB: tb/common/{fifo_ref_model,fifo_scoreboard,fifo_coverage}.sv + tb/sync_fifo/tb_sync_fifo.sv (directed+random+coverage, seeds reproducible)
5. Assertions: formal/sync_fifo/sync_fifo_props.sv (bind) 
6. Formal: formal/sync_fifo/sync_fifo_formal.sv harness + .sby (BMC depth 20 + k-induction)
7. Lint: verilator --lint-only -Wall gate in run_regression.sh
8. Sim: iverilog -g2012, `RESULT: PASS` protocol, logs → reports/sync_fifo/
9. Vivado: OOC synth+impl matrix on xc7z020clg484-1 (configs C1..C8), reports → reports/sync_fifo/vivado_*/
10. Milestone report + git tag `sync-fifo-m2`

## Configuration matrix (sync FIFO, §37)

| Cfg | DW | DEPTH | MEM | FWFT | OUTREG | Purpose |
|---|---|---|---|---|---|---|
| C1 | 8 | 16 | REG | 0 | 0 | tiny/reg path sanity |
| C2 | 32 | 16 | LUTRAM | 1 | 0 | FWFT lutram |
| C3 | 32 | 256 | BRAM | 0 | 0 | classic bram |
| C4 | 32 | 256 | BRAM | 1 | 1 | FWFT+pipeline timing case |
| C5 | 64 | 1024 | AUTO(→BRAM) | 1 | 0 | inference check |
| C6 | 128 | 4096 | BRAM | 0 | 1 | max resource/timing stress |
| C7 | 32 | 17 | LUTRAM | 1 | 0 | non-pow2 |
| C8 | 64 | 96 | BRAM | 0 | 0 | non-pow2 large |

Async configs (74.25/100 etc.) apply to Phase 3+, not here.

## Regression & seeds

`scripts/run_regression.sh [--quick]`: lint → sims (seeded $random, SEED env override, default 1) → grep RESULT: PASS → optional sby if available. Failing seeds are pinned into regressions/pinned_seeds.txt.

## Risk-triggered reviews during this milestone

RSK-03 (BRAM inference) → checked at step 9 via utilization rpt; RSK-06 (timing chain) → WNS per cfg; RSK-07 (wrap) → depth sweep + formal bounds.
