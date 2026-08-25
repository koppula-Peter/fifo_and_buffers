# Requirements Database

Format: one requirement per row in the tables below; machine-parsable fields separated by `|`.
Status vocabulary: OPEN / IMPLEMENTED / VERIFIED (sim) / PROVEN (formal) / QUALIFIED (all evidence incl. Vivado) / N-A.
Traceability columns reference RTL modules, assertions (`a_*`), tests (`t_*`), coverage (`c_*`), reports.
Family-wide requirements use prefix `FAM`; per-IP prefixes follow mandate §3 style.

## 1. Family-wide common requirements (FAM)

| ID | Description | Rationale | Applicability | Config dep | RTL ref | Test ref | Assertion | Coverage | Impl evidence | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| FAM-COMMON-001 | All IPs parameterized: data width, depth, mode controls; no magic numbers in RTL | Reusability | all | — | fifo_pkg.sv | t_common | — | — | lint clean | IMPLEMENTED |
| FAM-COMMON-002 | Invalid parameter combinations fail at elaboration ($error/$fatal), never synthesize silently | §24 | all | — | each module param block | t_param_checks | — | c_param_neg | lint log | IMPLEMENTED |
| FAM-COMMON-003 | Memory abstraction supports REG/LUTRAM/BRAM/AUTO without vendor primitives in generic RTL | §6 portability | memory users | MEMORY_TYPE | rtl/common/fifo_mem.sv | t_mem_modes | — | — | vivado rpt | IMPLEMENTED |
| FAM-COMMON-004 | Deterministic reset: pointers/occupancy/flags/stats defined; memory contents explicitly unspecified | §23 | all | RESET_STYLE | each core reset block | t_reset_* | a_reset_state | c_reset | sim logs | VERIFIED (sync) |
| FAM-COMMON-005 | Illegal operations (write-full, read-empty) never corrupt state; produce observable error events | §25 | all | OVERFLOW/UNDERFLOW policy | cores | t_illegal | a_no_corrupt | c_illegal | sim+formal | VERIFIED (sync) |
| FAM-COMMON-006 | Statistics: saturating overflow/underflow counters + peak occupancy where applicable | §5 observability | most | STAT_ENABLE | cores | t_stats | — | c_stats | sim logs | IMPLEMENTED (sync) |
| FAM-COMMON-007 | Optional debug observation ports (pointers/count/state) that cannot alter function | §48 | all | DEBUG_ENABLE | cores | t_debug_parity | — | — | sim logs | IMPLEMENTED (sync) |
| FAM-COMMON-008 | Version constants IP_MAJOR/MINOR/PATCH exposed via package and registers (where register-mapped) | §47 | all | — | fifo_pkg.sv | t_version | — | — | sim logs | IMPLEMENTED |
| FAM-COMMON-009 | Canonical stream record type (valid/ready/data/sop/eop/keep/user) defined once, reused by wrappers | §19 | stream-capable | — | fifo_pkg.sv | compile-time | — | — | lint | IMPLEMENTED |
| FAM-COMMON-010 | No unexplained TODO/FIXME in released RTL | §53 | all | — | grep gate in regression script | regression gate | — | — | run_regression.sh | VERIFIED |

## 2. Synchronous FIFO (FIFO-SYNC)

| ID | Description | Rationale | Applicability | Config dep | RTL ref | Test ref | Assertion | Coverage | Impl evidence | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| FIFO-SYNC-FUNC-001 | Accepts one push/cycle when not full; one pop/cycle when not empty; sustained simultaneous push+pop indefinitely | §7 throughput | always | — | sync_fifo.sv | t_throughput | a_one_per_cycle | c_back2back | sim log | VERIFIED |
| FIFO-SYNC-FUNC-002 | Strict FIFO ordering of accepted data; no loss/duplication/reordering under any legal stimulus | core guarantee | always | — | sync_fifo.sv | t_random, formal | f_order, f_no_loss_dup | c_wrap | formal PASS | PROVEN |
| FIFO-SYNC-FUNC-003 | exact occupancy count output; full ⟺ count==DEPTH; empty ⟺ count==0 | flag correctness | always | — | sync_fifo.sv | t_flags | a_flag_count | c_occupancy_bins | sim+formal | PROVEN |
| FIFO-SYNC-FUNC-004 | almost_full when count≥AFULL_THRESHOLD; almost_empty when count≤AEMPTY_THRESHOLD; thresholds programmable 1..DEPTH | §5 | always | thresholds | sync_fifo.sv | t_thresholds | a_almost | c_thresholds | sim log | VERIFIED |
| FIFO-SYNC-FUNC-005 | push while full → rejected (state unchanged) + ovf event; pop while empty → rejected + unf event; policies per spec table | §7 explicit semantics | always | OVERFLOW_POLICY/UNDERFLOW_POLICY | sync_fifo.sv | t_overflow t_underflow | a_reject_full a_reject_empty | c_illegal | sim+formal | PROVEN |
| FIFO-SYNC-FUNC-006 | Simultaneous push+pop evaluated against pre-cycle state: FULL ⇒ push rejected/pop accepted; EMPTY ⇒ pop rejected/push accepted | removes ambiguity §7 | always | — | sync_fifo.sv | t_simultaneous | a_simul_semantics | c_simul | sim+formal | PROVEN |
| FIFO-SYNC-FUNC-007 | Non-power-of-two DEPTH≥2 supported with correct wrap | §5 | always | DEPTH | sync_fifo.sv | t_depth_sweep | a_ptr_bounds | c_depths | sim sweep | VERIFIED |
| FIFO-SYNC-FUNC-008 | FWFT mode: oldest entry presented on rdata whenever not empty; pop consumes it; standard mode: data valid 1 cycle after accepted pop | §7 | always | FWFT_ENABLE | sync_fifo.sv | t_fwft t_latency | a_fwft_valid | c_modes | sim log | VERIFIED |
| FIFO-SYNC-FUNC-009 | OUTPUT_REGISTER adds one pipeline stage in standard mode; documented latency delta | timing | std mode | OUTPUT_REGISTER | sync_fifo.sv | t_latency | — | c_outreg | sim+vivado | VERIFIED |
| FIFO-SYNC-FUNC-010 | Saturating stats: ovf_cnt, unf_cnt, peak occupancy; sticky error flags w/ clear input | §5 | STAT_ENABLE | — | sync_fifo.sv | t_stats | — | c_stats | sim log | VERIFIED |
| FIFO-SYNC-FUNC-011 | Reset (sync active-high default): count=0, empty=1, full=0, errors cleared, outputs safe within 1 cycle of rst assertion | §23 | always | — | sync_fifo.sv | t_reset_midstream | a_reset_state | c_reset_during_activity | sim log | VERIFIED |
| FIFO-SYNC-CDC-N/A | Single clock domain only; no CDC structures inside this IP | scope control | — | — | — | — | — | — | design review | NOT APPLICABLE |
| FIFO-SYNC-PERF-001 | Closes ≥100 MHz on xc7z020clg484-1 for representative configs | §56 | synthesis targets | configs matrix | — | — | — | — | vivado WNS reports | QUALIFIED target pending |
| FIFO-SYNC-PERF-002 | BRAM inference verified: AUTO selects BRAM for large configs, no LUTRAM explosion | §6 | MEM=AUTO | size | fifo_mem.sv | — | — | — | vivado util rpt | QUALIFIED target pending |

## 3. Remaining IPs

Requirements for async/dual-clock/width-conv/packet/frame/priority/multi-queue/circular/
elastic/replay/jitter are **frozen at their phase gate** (mandate: requirements precede RTL).
Placeholder skeleton IDs reserved now to stabilize numbering:

`FIFO-ASYNC-*` (CDC-001..: Gray pointer discipline, 2-stage sync, reset strategy),
`FIFO-DCLK-*`, `FIFO-WCONV-*`, `FIFO-PKT-*`, `FIFO-FRM-*`, `FIFO-PRIO-*`, `FIFO-MQ-*`,
`FIFO-CIRC-*`, `FIFO-ELAS-*`, `FIFO-RPLY-*`, `FIFO-JIT-TIME-*`.

Each will be expanded in this file before its phase's RTL is written (DoD gate #1).
