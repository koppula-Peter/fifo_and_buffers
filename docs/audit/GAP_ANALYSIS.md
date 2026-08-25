# Gap Analysis

Gap = distance between mandate requirements (§4–§61) and current evidence. Baseline date 2026-08-25.

## G-01 Capability gaps (family-wide)

| ID | Gap | Impact | Closure path | Phase |
|---|---|---|---|---|
| GAP-01 | No common RTL package/memory abstraction exists | Blocks all IPs | Create `fifo_pkg.sv`, `fifo_mem.sv` | 1 (this milestone) |
| GAP-02 | No verification infrastructure (ref model/scoreboard/coverage) | No IP can claim verified | `tb/common/` framework | 1 |
| GAP-03 | No regression harness / Makefile | Results not repeatable | `scripts/run_regression.sh` + Makefile | 1 |
| GAP-04 | No formal environment (.sby + solvers wired) | Foundational blocks unprovable | `formal/*/…sby`, yowasp-sby+z3 | 2+ |
| GAP-05 | No Vivado OOC synth/impl scripts for xc7z020clg484-1 | No timing/resource evidence | `vivado/scripts/build_ooc.tcl` | 2 |
| GAP-06 | Twelve required IPs: all MISSING | Product does not exist | Phased per §57 | 2–12 |
| GAP-07 | AXI4-Stream/Lite wrappers, IRQ, register map absent | No PS integration story | wrappers phase | 13 |
| GAP-08 | No software (bare-metal/Linux) or ZC702 demo | HW validation impossible | sw tree + demo top | 13–14 |

## G-02 Tooling constraints (accepted, documented)

| Constraint | Consequence | Mitigation |
|---|---|---|
| No commercial simulator; no code-coverage collector (line/branch/toggle) in OSS tools used | Code coverage metric unavailable | Functional coverage self-reported by TBs; formal proofs + exhaustive directed tests substitute; documented as known limitation in coverage plan |
| SBY available only as yowasp build | Engine choice limited to smtbmc z3/boolector (+abc if bundled) | BMC + k-induction; document proof scope honestly |
| Verilator lint ≠ full CDC tool | CDC sign-off relies on design discipline + assertions + Vivado report_timing/CDC review | ASYNC_REG attributes, CDC doc per §33, manual review checklist |

## G-03 Knowledge gaps requiring ADRs before RTL

| Topic | ADR | Phase gate |
|---|---|---|
| Memory abstraction & inference strategy | ADR-001 | before sync FIFO RTL |
| Async pointer crossing technique | ADR-002 | before async FIFO |
| Packet atomic commit | ADR-003 | before packet FIFO |
| Width-conversion residual policy | ADR-004 | before width conv |
| Multi-queue architecture (A/B/C) | ADR-005 | before multi-queue |
| Replay sequence arithmetic | ADR-006 | before replay |
| Jitter timestamp architecture | ADR-007 | before jitter |
| AXI wrapper strategy | ADR-008 | before phase 13 |

## G-04 What already satisfies mandate items

| Mandate item | Evidence |
|---|---|
| Toolchain present and version-matched (Vivado 2025.2) | audit §3 |
| Repo skeleton created per §52 | git baseline commit |
| Architectural precedent for count-based control validated in sibling projects | audit §2 |
