# Synchronous FIFO — Architecture

## 1. Block diagram

```text
            wr_en  wr_data
              │       │
        ┌─────▼───────▼─────┐      ┌───────────────────────────┐
        │ push/pop grant    │      │ fifo_mem (REG/LUTRAM/     │
        │ (pre-cycle state) │      │ BRAM inference)           │
        └──┬──────────┬─────┘      │  wport: addr,data,en      │
           │          │            │  rport: addr → q (sync rd)│
           ▼          ▼            └────────▲─────────┬────────┘
     wr_addr_q   rd_addr_q                 │         │ mem_q
           │          │                            │
        ┌──▼──────────▼────┐   occupancy   ┌──────▼───────┐
        │ pointer update   │◄──────────────┤ count/flags  │
        └──────────────────┘   counter     │ almost_*,    │
                                           │ peak, events │
                                           └──────┬───────┘
                                                  ▼
                                    FWFT/standard output stage
                                       rd_data, rd_data_valid
```

## 2. Control architecture

- **Occupancy counter** `count_q[CNT_W-1:0]`, CNT_W=$clog2(DEPTH+1): registered; updated as
  `{+1, −1, ±0}` from grants. Single source of truth for full/empty/almost/level (P1).
- **Pointers** `wr_addr_q/rd_addr_q[ADDR_W-1:0]`, ADDR_W=$clog2(DEPTH); wrap via
  `addr = (addr==DEPTH-1) ? 0 : addr+1` — no modulo-2 assumptions ⇒ non-pow2 DEPTH clean.
- **Grants**: `do_push = wr_en && (!full_q || (OVF_OVERWRITE && full_q))`;
  `do_pop = rd_en && !empty_q`. Simultaneous-corner adjustments per spec §5:
  when full&&both ⇒ do_push=0 (REJECT policy); when empty&&both ⇒ do_pop=0.
- **Flags** combinational off `count_q` registers (registered outputs): full/empty/almost_*.
- **Events**: overflow_event = wr_en&&(full per-policy condition); underflow_event =
  rd_en&&empty. Sticky + counters in STAT block.

## 3. Memory abstraction (ADR-001)

`fifo_mem #(DW, ENTRIES, MEM_MODE)`:
- REG: `logic [DW-1:0] mem[ENTRIES]` + async read mux.
- LUTRAM: same array, read-during-write=old-data semantics documented; async read.
- BRAM: sync-read process; `mem_q` register output; read-first semantics.
- AUTO resolves at elaboration (spec §3).

Read/write same-address behavior is irrelevant to correctness because a location is never
read before written in-session and never written while readable-at-same-cycle except the
full+overwrite case where the popped word is the one being replaced — defined as returning
the OLD word on that cycle (read-before-write), matching LUTRAM/BRAM read-first inference.
Documented as normative.

## ADR-001 — FIFO memory abstraction

- Context: family needs portable storage across sizes with Vivado-provable inference.
- Options: (a) vendor primitives behind wrappers; (b) behavioral arrays w/ style params; (c) fixed BRAM-only.
- Decision: **(b)** — single `fifo_mem` with MEM_MODE ∈ {REG,LUTRAM,BRAM,AUTO}; vendor primitives prohibited in generic RTL (may appear later only behind optional impl layer with measured benefit).
- Rationale: portability (§6), OSS-tool simulation parity, Vivado infers reliably from sync-read templates.
- Benefits/disadvantages: portable & provable / relies on inference quality — mitigated by utilization checks per config matrix (RSK-03).
- Verification impact: t_mem_modes exercises all modes; formal runs on REG mode (small) + BRAM mode (structural equivalence by construction).
- Future implications: URAM/ultra-scale additions slot into fifo_mem only.

## ADR-002 — Operation semantics at boundaries (pre-cycle evaluation)

- Context: undefined simultaneous behavior causes integration bugs (§53).
- Options: (a) post-cycle re-evaluation ("swap at full"); (b) pre-cycle conservative; (c) parameterized.
- Decision: **(b)** family rule P2; documented corner table spec §5.
- Rationale: simplest to prove (formal harness needs no mode explosion); matches dominant commercial convention; deterministic.
- Disadvantage: swap-style users must handle full differently — documented.
- Verification impact: CC-03/04/05 directed tests + a_simul_semantics assertion + formal corner cases.

## ADR-003 — Count-based control vs extended pointers

- Context: classic Cummings extended-pointer trick is pow2-only; family requires any depth.
- Decision: occupancy counter + wrap-compare addresses for all single-clock cores.
- Rationale: non-pow2 native, watermark logic trivial, one compare chain (timing §RSK-06 mitigated by registering flags source).
- Disadvantage: counter width adder — negligible at target f.
- Verification impact: bounds property `count ≤ DEPTH` in formal; depth sweep tests.

## ADR-004 — Reset doctrine (single-clock cores)

- Decision: synchronous active-high reset only in M2 core; async variants introduced with CDC phase where required.
- Rationale: no recovery/removal analysis needed; formal-friendly; matches P-family determinism goal.
- Impact: integrators with async-reset fabric must use external reset synchronizer (documented in INTEGRATION guide later; precedent exists in sibling reset IP).

## 4. Output staging

```text
BRAM path :  mem[rd_addr] --clk--> mem_q --(opt outreg)--> rd_data
FWFT path :  rd_data_q holds head; on accepted pop load mem[next_rd_addr]
Standard  :  pop presents fetched word next cycle(s)
```

`rd_data_valid` disambiguates HOLD/ZERO underflow cycles and standard-mode data presence.

## 5. Timing budget @100 MHz (10 ns)

Critical expectation: count update chain (grant→count→flag) ≤ 1 logic level after regs;
memory read path dominated by BRAM clk-to-out ≈ 2.x ns + route; OUTREG option splits
mem_q→out mux for C6 stress case. Verified empirically in Vivado runs (report links in
milestone report).

## 6. Debug/observability

DEBUG_ENABLE exposes dbg_wr_ptr/dbg_rd_ptr (+count always). Purely observability taps;
no functional fan-out; verified by t_debug_parity (outputs equal internal state).
