# Risk Register

Scale: Likelihood L (1–5), Impact I (1–5), Exposure E=L×I. Owner: project lead. Review each milestone.

| ID | Risk | L | I | E | Mitigation / trigger | Status |
|---|---|---|---|---|---|---|
| RSK-01 | CDC defect in async FIFO (silent data corruption under metastability) | 2 | 5 | 10 | Proven Gray-pointer architecture (ADR-002); formal pointer-coherence proofs; 2FF ASYNC_REG sync; CDC doc; never multi-bit binary crossings | Open — gated to Phase 3 |
| RSK-02 | Over-generalized common code causes regression risk across IPs ("abstraction tax") | 3 | 4 | 12 | Rule §4: abstraction only after ≥2 concrete uses; keep cores self-contained | Active constraint |
| RSK-03 | BRAM inference failure → accidental LUTRAM blow-up at depth 4096×128 | 3 | 4 | 12 | fifo_mem abstraction w/ explicit sync-read port; Vivado utilization check per config matrix; fail loudly on resource regression vs recorded baseline | Mitigation planned Phase 2 |
| RSK-04 | Formal proof scope overclaimed (BMC-only passed off as proof) | 3 | 4 | 12 | Report exact mode/depth/engine; induction where feasible; unproven properties marked OPEN in milestone reports | Standing rule |
| RSK-05 | Sim tool divergence (iverilog vs xsim vs verilator semantics, e.g. `$fatal`/SVA support gaps) | 4 | 2 | 8 | Restrict testbench language subset; primary sim iverilog -g2012; xsim smoke for release; lint via verilator | Active constraint |
| RSK-06 | Timing miss >100 MHz on deep FIFOs due to occupancy compare chain | 3 | 3 | 9 | Count-based flags registered early; OUTPUT_REGISTER option; measure WNS per config in matrix | Watch |
| RSK-07 | Non-power-of-two depth corner bugs (wrap logic) | 3 | 4 | 12 | Single count-based architecture (no modulo pointers); dedicated wrap tests incl. DEPTH=2..17 sweep; formal bounds property | Mitigation designed in |
| RSK-08 | Scope explosion: 12 IPs × docs × configs exceeds session capacity | 4 | 4 | 16 | Strict phase gating, DoD per IP, milestone STOP reviews; configuration matrix kept representative not exhaustive | Standing rule |
| RSK-09 | Data loss of project work (user-critical requirement) | 2 | 5 | 10 | Standalone git repo, commit at every milestone artifact; reports/logs committed as evidence | **Mitigated** (repo initialized) |
| RSK-10 | Silent data loss in width-conversion residuals | 3 | 5 | 15 | ADR-004 mandates explicit flush/commit semantics; spec-level example (3×8→32) must be defined before RTL; assertion: no byte disappears without observable event | Gated to Phase 4 |
| RSK-11 | Jitter buffer becomes "renamed FIFO" without real time-awareness | 2 | 4 | 8 | Mandate requires theory/requirements/architecture docs before RTL (Phase 12 gate) | Gated to Phase 12 |
| RSK-12 | Vendor lock-in via Xilinx primitives leaking into generic RTL | 2 | 3 | 6 | Primitives allowed only behind optional impl layers with measured benefit; lint check: generic rtl/ free of vendor attributes except ASYNC_REG on synchronizers | Standing rule |

Escalation policy: any E≥12 risk materializing during a phase halts the phase and updates this register before proceeding.
