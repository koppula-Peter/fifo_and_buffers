# Repository Audit — fifo_and_buffers

| | |
|---|---|
| Audit date | 2026-08-25 |
| Auditor | Principal IP Architect (Phase 0) |
| Scope | `IP_dev/fifo_and_buffers/` and monorepo context affecting it |
| Verdict | **GREENFIELD** — target directory contained zero files. No existing work could be damaged. |
| Project home | `/home/peter/Desktop/fifo_and_buffers` (**standalone git repository**, extracted from the `IP_dev` workspace at project owner's request; independent history, zero coupling to sibling projects) |

## 1. Target directory state

`fifo_and_buffers/` was empty at audit time (verified via `find` — no files, only `.`/`..`).
Nothing to preserve, nothing to overwrite. The full repository skeleton is created fresh per
mandate §52 and version-controlled in its own repository.

## 2. Former monorepo context (`/home/peter/Desktop/IP_dev`, reference only)

The directory lives inside a multi-IP workspace ("IP_dev") containing independent IP efforts:

| Sibling | Maturity signal (evidence-based) | Relevance to this project |
|---|---|---|
| `RNG/` | Structured suite: rtl/tb/formal/docs/vivado/sw, regression script, reports; imported as complete subtree (git 580f5c72 lineage) | **Template for repo conventions**: Apache-2.0 headers, `RESULT: PASS` grep protocol, Makefile lint/sim/regression targets |
| `pcie/rtl/common/pcie_sync_fifo.sv` | Count-based single-clock FIFO, any DEPTH ≥ 1, reject-on-full policy, standard read timing, unit TB + bounded formal claimed in header | **Architectural precedent** for count-based control and non-power-of-two depth. Classified FUNCTIONAL BUT UNQUALIFIED *for this library* (scoped to pcie IP; no FWFT/thresholds/stats; verification not re-runnable here) |
| `RNG/rtl/common/rng_fifo_sync.v` | Extended-pointer FWFT sync FIFO, power-of-2 depth only, ovf/unf pulses | Second precedent. Confirms house style: elaboration `$error` checks, extended-pointer wrap-bit technique |
| `reset/` | reset_synchronizer/reset_sequencer with formal props file (`reset_synchronizer_props.sv`) and run_sim.sh | Convention source for formal assertion companion modules + bash regression harness |
| `amba_ip/`, `serdes/`, `space_wire/`, `CCSDS/`, `PQC_HSM/`, `clocking/`, `gpu_dev/` | Independent efforts; gpu_dev has one working `.sby` (bmc depth 12, smtbmc z3) | Confirms SBY invocation convention used by this repo |

## 3. Toolchain inventory (executed during audit)

| Tool | Version / path | Status |
|---|---|---|
| Icarus Verilog | `/usr/bin/iverilog`, `-g2012` | Available |
| Verilator | 5.032 (Debian) | Available → primary linter |
| Yosys | 0.52 (fee39a32) | Available |
| SymbiYosys | `~/.local/bin/yowasp-sby` (wasm build) | Available |
| Solvers | z3, boolector (`/usr/bin`) | Available |
| Vivado | `/home/peter/Desktop/xilinx_tools/2025.2/Vivado/bin/vivado` (+ xsim) | Available, matches mandated 2025.2 |
| python3 | `/usr/bin/python3` | Available |

No commercial simulator/QA tooling present ⇒ code coverage (line/branch/toggle) has **no
supported collector**; functional coverage must be self-reported by testbenches and formal
must carry correctness weight. Recorded in GAP_ANALYSIS and COVERAGE plan.

## 4. Git baseline

- Branch `main`; HEAD `580f5c72`.
- Uncommitted modifications exist in *other* projects (amba_ip, serdes, RNG, reset) — none
  touch `fifo_and_buffers/`. This project proceeds on a clean slate inside those boundaries.

## 5. Conventions adopted from evidence

1. RTL file header = contract: purpose, semantics, parameters, verification refs (rng/pcie style).
2. Elaboration-time parameter validation via `initial $error(...)` (RNG style), plus synthesis-visible guards.
3. Regression pass criterion: literal string `RESULT: PASS` in log (reset/run_sim.sh protocol).
4. Reports land under `reports/<ip>/…`, logs are committed evidence.
5. Formal: `.sby` files under `formal/`, engines `smtbmc z3` / `abc pdr` as available.
6. License: Apache-2.0, project-original code (RNG LICENSE precedent).

## 6. Audit conclusion

Phase 0 proceeds directly to requirements/architecture definition; there is no legacy RTL to
classify beyond the two sibling precedents noted above (both retained untouched in their own
projects). Development order follows mandate §57 phases.
