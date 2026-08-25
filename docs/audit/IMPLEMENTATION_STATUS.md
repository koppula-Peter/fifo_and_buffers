# Implementation Status Matrix — fifo_and_buffers IP family

Status vocabulary: COMPLETE / FUNCTIONAL BUT UNQUALIFIED (FBU) / PARTIAL / PLACEHOLDER /
BROKEN / UNTESTED / OBSOLETE / **MISSING**. Evidence basis noted per row. Audit date 2026-08-25.

## The twelve required IPs

| # | IP | Reqs | Arch | RTL | Directed Verif | Random Verif | Assertions | Formal | CDC | Coverage | Synthesis | Impl | Timing | SW | Docs | Overall | Major blockers |
|---|----|------|------|-----|----------------|--------------|------------|--------|-----|----------|-----------|------|--------|----|----|---------|----------------|
| 1 | Sync FIFO | MISSING→frozen this milestone | MISSING→defined | **MISSING** (this milestone) | MISSING | MISSING | MISSING | MISSING | N/A | MISSING | MISSING | MISSING | N/A | N/A | MISSING | **NOT STARTED** | All |
| 2 | Async FIFO | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | depends on #1 infra + CDC framework |
| 3 | Dual-Clock FIFO | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | decision pending: reuse async core (expected) |
| 4 | Width-Conv FIFO | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | partial-word semantics to be specified |
| 5 | Packet FIFO | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | commit/rollback architecture TBD |
| 6 | Frame FIFO | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | descriptor architecture TBD |
| 7 | Priority FIFO | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | arbitration policy matrix TBD |
| 8 | Multi-Queue FIFO | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | A/B/C architecture trade study required (ADR) |
| 9 | Circular Buffer | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | trigger/pre-post capture semantics TBD |
| 10 | Elastic Buffer | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | reuse async CDC core expected |
| 11 | Replay Buffer | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | sequence arithmetic ADR required |
| 12 | Jitter Buffer | MISSING | MISSING | MISSING | — | — | — | — | — | — | — | — | — | — | — | NOT STARTED | theory doc mandated before RTL |

## Common infrastructure

| Item | Status | Evidence |
|---|---|---|
| Package/common definitions (`fifo_pkg`) | MISSING → created Phase 1 this milestone | `rtl/common/` |
| Memory abstraction (`fifo_mem_*`) | MISSING → created Phase 1 | `rtl/common/fifo_mem.sv` |
| Stream type defs (sop/eop/keep/user canonical record) | MISSING → created Phase 1 | `rtl/common/fifo_pkg.sv` |
| TB infrastructure (driver/monitor/scoreboard/ref-model) | MISSING → created Phase 1 | `tb/common/` |
| Build/regression framework (scripts/run_regression.sh, Makefile) | MISSING → created Phase 1 | `scripts/` |
| AXI4-Stream wrappers | MISSING (Phase 13) | — |
| AXI4-Lite register block | MISSING (Phase 13) | — |
| Interrupt block | MISSING (Phase 13) | — |
| ZC702 demo design | MISSING (Phase 14) | — |
| Bare-metal driver | MISSING (Phase 13+) | — |
| Linux driver strategy doc | MISSING (Phase 13+) | — |

## Related-but-out-of-scope existing assets (monorepo)

| Asset | Classification | Action |
|---|---|---|
| `pcie/rtl/common/pcie_sync_fifo.sv` (+TB/formal in pcie project) | FUNCTIONAL BUT UNQUALIFIED for this library | Architectural reference only; not imported; pcie keeps ownership |
| `RNG/rtl/common/rng_fifo_sync.v` | FUNCTIONAL BUT UNQUALIFIED for this library | Reference only; FWFT-only, pow-2 depth; stays in RNG |
| gpu_dev `.sby` flow | COMPLETE within its scope | Convention reused |

**Family-wide overall status: 0 of 12 IPs qualified. Baseline established at zero with
precedent-informed conventions.**
