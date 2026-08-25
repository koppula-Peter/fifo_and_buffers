# Requirements Traceability Matrix

Direction: Requirement → Architecture → RTL → Assertion → Test → Coverage → Result → Evidence.
Only rows with executable evidence carry PASS/PROVEN; everything else stays OPEN (§49, §53).

## Sync FIFO milestone matrix

| Req ID | Arch § | RTL | Assertions | Tests | Coverage | Sim | Formal | Vivado | Evidence path |
|---|---|---|---|---|---|---|---|---|---|
| FAM-COMMON-001 | SPEC §4 | fifo_pkg.sv, sync_fifo.sv | — | compile gate | — | PASS | — | — | reports/sync_fifo/lint.log |
| FAM-COMMON-002 | SPEC §3 | param checks in modules | — | t_param_neg | c_param_neg | PASS | — | — | tb/sync_fifo/tb_sync_fifo.sv |
| FAM-COMMON-003 | ARCH §3 | fifo_mem.sv | — | t_mem_modes | — | PASS | — | PENDING impl rpt | vivado/ |
| FAM-COMMON-004 | SPEC §9 | sync_fifo reset block | a_reset_state | t_reset_basic, t_reset_midstream | c_reset | PASS | PASS(bmc) | — | reports/sync_fifo/*.log |
| FAM-COMMON-005 | SPEC §6.4 | do_push/do_pop gating | a_reject_full, a_reject_empty | t_overflow, t_underflow | c_illegal | PASS | PROVEN | — | formal/sync_fifo/ |
| FAM-COMMON-006 | SPEC §8 | stats counters | — | t_stats | c_stats | PASS | — | — | reports/sync_fifo/tb_sync_fifo.sim.log |
| FAM-COMMON-007 | SPEC §11 | debug outputs | — | t_debug_parity | — | PASS | — | — | same |
| FAM-COMMON-008 | SPEC §12 | fifo_pkg version consts | — | t_version | — | PASS | — | — | same |
| FIFO-SYNC-FUNC-001 | ARCH §2 | sync_fifo datapath | f_perf (sim) | t_throughput | c_back2back | PASS | — | PENDING timing | sim log |
| FIFO-SYNC-FUNC-002 | ARCH §2 | pointer+mem logic | f_order, f_noloss_dup (SBY) | t_random ×seeds | c_wrap | PASS | PROVEN | — | reports/sync_fifo/formal_*.log |
| FIFO-SYNC-FUNC-003 | ARCH §2 | count logic | a_flag_count, f_flags (SBY) | t_flags_directed | c_occupancy_bins | PASS | PROVEN | — | both logs |
| FIFO-SYNC-FUNC-004 | SPEC §7 | threshold compares | a_almost | t_thresholds | c_thresholds | PASS | — | — | sim log |
| FIFO-SYNC-FUNC-005 | SPEC §6.4 | policy muxes | as above | t_overflow, t_underflow, t_policy_matrix | c_illegal,c_policies | PASS | PROVEN | — | sim+formal |
| FIFO-SYNC-FUNC-006 | SPEC §6.5 | pre-cycle eval logic | a_simul_semantics | t_simultaneous | c_simul | PASS | PROVEN | — | both |
| FIFO-SYNC-FUNC-007 | ARCH §3 | wrap arithmetic | a_ptr_bounds, f_bounds (SBY) | t_depth_sweep 2..17+pow2 | c_depths | PASS | PROVEN | util rpt | sim sweep + formal |
| FIFO-SYNC-FUNC-008 | SPEC §6.2 | FWFT output reg ctrl | a_fwft_valid | t_fwft, t_latency | c_modes | PASS | — | — | sim log |
| FIFO-SYNC-FUNC-009 | SPEC §6.3 | outreg pipeline | — | t_latency | c_outreg | PASS | — | WNS rpt | sim+vivado |
| FIFO-SYNC-FUNC-010 | SPEC §8 | stats/sticky | — | t_stats, t_sticky_clear | c_stats | PASS | — | — | sim log |
| FIFO-SYNC-FUNC-011 | SPEC §9 | reset block | a_reset_state | t_reset_midstream | c_reset_during_activity | PASS | PASS(bmc) | — | both |
| FIFO-SYNC-PERF-001 | ARCH §5 | — | — | — | — | — | — | OPEN → this milestone's Vivado runs | reports/sync_fifo/vivado_* |
| FIFO-SYNC-PERF-002 | ARCH §3 | fifo_mem AUTO | — | — | — | — | — | OPEN → utilization check | same |

## Family-wide rollup

| IP | Reqs frozen | RTL | Verified | Formal | Qualified |
|---|---|---|---|---|---|
| Sync FIFO | YES (this file) | YES | YES | YES (BMC+k-ind) | Vivado pending→done this milestone |
| Other 11 | NO (phase gates) | no | no | no | no |

Maintenance rule: any requirement row edited ⇒ re-run affected tests before status change;
statuses may only advance with committed evidence paths that exist at commit time.
