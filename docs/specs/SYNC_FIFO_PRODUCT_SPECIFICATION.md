# Synchronous FIFO — Product Specification

| | |
|---|---|
| IP | `fifo_sync` |
| Version | 1.0.0 (IP_MAJOR=1 IP_MINOR=0 IP_PATCH=0) |
| Status | Frozen for M2 implementation |
| Requirements set | FIFO-SYNC-* in docs/requirements/REQUIREMENTS.md |

## 1. Purpose and supported applications

Single-clock-domain FIFO providing lossless, order-preserving elastic storage between two
processing stages in one clock domain. Intended uses: pipeline decoupling, burst absorption,
CDC-adjacent staging *within* one domain, width-converter stage building blocks, payload
storage inside packet/frame/queue derivatives.

Not intended for: clock-domain crossing (use async_fifo), packet-aware storage (packet_fifo).

## 2. Interface

```systemverilog
module fifo_sync #(
  parameter int DATA_WIDTH             = 32,
  parameter int DEPTH                  = 256,   // >=2, any integer
  parameter bit FWFT_ENABLE            = 1'b0,
  parameter int ALMOST_FULL_THRESHOLD  = DEPTH, // 1..DEPTH
  parameter int ALMOST_EMPTY_THRESHOLD = 1,     // 0..DEPTH-1
  parameter bit OUTPUT_REGISTER        = 1'b0,
  parameter mem_type_e MEMORY_TYPE     = MEM_AUTO,
  parameter overflow_policy_e OVERFLOW_POLICY = OVF_REJECT,
  parameter underflow_policy_e UNDERFLOW_POLICY = UNF_REJECT_HOLD,
  parameter bit STAT_ENABLE            = 1'b1,
  parameter bit DEBUG_ENABLE           = 1'b0
)( ... );
```

Signals (all active-high; `_a` suffix none — single domain):

| Group | Signals | Dir | Description |
|---|---|---|---|
| Clock/reset | `clk`, `rst` | in | synchronous reset, asserted ≥1 cycle |
| Write | `wr_en`, `wr_data[DW-1:0]` | in | push request + payload |
| Write status | `full`, `almost_full`, `overflow_event`, `overflow_sticky` | out | see §6–§8 |
| Read | `rd_en` | in | pop request |
| Read data | `rd_data[DW-1:0]`, `rd_data_valid` | out | semantics per mode, §7 |
| Read status | `empty`, `almost_empty`, `underflow_event`, `underflow_sticky` | out | |
| Level | `count[CNT_W-1:0]`, `peak_count[CNT_W-1:0]` | out | exact occupancy / high-watermark |
| Stats | `ovf_count[31:0]`, `unf_count[31:0]` | out | saturating counters |
| Control | `error_clear` | in | clears sticky flags + peak + counters? — **No:** sticky only; stats cleared only by reset (documented) |
| Debug | `dbg_wr_ptr`, `dbg_rd_ptr` | out | when DEBUG_ENABLE, else 0 |

## 3. Parameters — validation rules

Elaboration `$fatal/$error` if: `DATA_WIDTH<1`; `DEPTH<2`;
`ALMOST_FULL_THRESHOLD<1 || >DEPTH`; `ALMOST_EMPTY_THRESHOLD<0 || >DEPTH-1`;
invalid enum values. MEMORY_TYPE resolution at elaboration:
AUTO ⇒ REG if DEPTH≤8; LUTRAM if DEPTH·DW ≤ 64×1024 bits; else BRAM.
(Justified: below BRAM granularity LUTRAM wins; REG for trivial depths.)

## 4. Memory behavior

Storage via `fifo_mem` abstraction:
- REG: flip-flop array, asynchronous read (combinational rd mux).
- LUTRAM: distributed RAM inference, asynchronous read.
- BRAM: true dual-port style single-clock sync read (`rd_data <= mem[rd_addr]` on clk).
Contents after reset: unspecified (X-safe operation proven by design: no read of a location
not previously written in the current session can be *accepted* because empty gates reads).
This is stated as a formal assumption where relevant.

## 5. Push/pop semantics

| Condition | wr_en effect | rd_en effect |
|---|---|---|
| not full / not empty | accepted | accepted |
| full | per OVERFLOW_POLICY (§6) | accepted |
| empty | accepted | per UNDERFLOW_POLICY (§6) |
| full + both strobes | push REJECTED, pop accepted (net −1) | |
| empty + both strobes | push accepted, pop REJECTED (net +1) | |

**Simultaneous push/pop is evaluated against pre-cycle state.** Rationale: matches Xilinx
FIFO Generator convention, simplest provable semantics, no overwrite hazards. Documented as
the family-wide rule P2.

## 6. Overflow / underflow policies

| Parameter value | Behavior on event | Error signaling |
|---|---|---|
| OVF_REJECT (default) | incoming word dropped; pointers/count unchanged | overflow_event pulse same cycle; overflow_sticky set; ovf_count++ |
| OVF_OVERWRITE_OLDEST | oldest entry discarded, incoming stored (ring advances both ptrs); count stays DEPTH | overflow_event pulse + sticky + count++ (ordering note §10) |
| UNF_REJECT_HOLD (default) | rd_en ignored; rd_data holds last value; pointer unchanged | underflow_event pulse; underflow_sticky; unf_count++ |
| UNF_REJECT_ZERO | rd_en ignored; rd_data forced 0 that cycle (safe-null read aid) | same signals |

Sticky flags clear on `error_clear` pulse (1 cycle). Counters saturate at all-ones.

## 7. Read timing modes

### Standard mode (FWFT_ENABLE=0)
`rd_en && !empty` accepted at edge T ⇒ `count--` visible T+1; `rd_data` valid during T+1
(with OUTPUT_REGISTER=0, data is mem sync-read reg). With OUTPUT_REGISTER=1 add one more
cycle (data valid T+2), improving timing. `rd_data_valid` marks exactly the cycle(s) data is
valid post-pop.

### FWFT mode (FWFT_ENABLE=1)
`rd_data` shows oldest entry whenever `!empty`; `rd_data_valid == !empty`. `rd_en && !empty`
pops at edge T ⇒ next word (or invalid+empty) presented at T+1. First-word latency from
push-on-empty to data-visible = 1 cycle (BRAM/LUTRAM/REG alike — output register always
present in this mode internally).

OUTPUT_REGISTER has no user-visible effect in FWFT mode except timing margin.

## 8. Latency summary

| Path | FWFT=0 OUTREG=0 | FWFT=0 OUTREG=1 | FWFT=1 |
|---|---|---|---|
| push→count reflects | 1 cycle | 1 cycle | 1 cycle |
| accepted pop→data valid | T+1 | T+2 | n/a (already valid) |
| push(on empty)→data visible | 2 | 3 | 1 |

## 9. Occupancy, thresholds

- `count` = exact number of accepted-and-not-yet-popped words (0..DEPTH), combinational from registered counter (registered output).
- `full = (count==DEPTH)` registered; `empty = (count==0)` registered → glitch-free downstream use.
- `almost_full = (count ≥ ALMOST_FULL_THRESHOLD)`; `almost_empty = (count ≤ ALMOST_EMPTY_THRESHOLD)`; combinational off registered count.
- Thresholds are static parameters (dynamic thresholds deferred to register-mapped wrapper phase).

## 10. Ordering guarantees

- OVF_REJECT / default: strict FIFO order of all accepted words.
- OVF_OVERWRITE_OLDEST: order preserved among surviving words; guarantee weakens to "most recent DEPTH accepted words retained". Flagged clearly — integrators must opt in knowingly.

## 11. Reset

Synchronous active-high. Assertion (≥1 cycle): count→0, empty→1, full→0, almost_*→idle values, events/sticky/stats→0, pointers→0, outputs safe. Deassertion: normal synchronous pipeline restart; first push accepted the cycle after rst deasserts. Memory contents unspecified. No X-propagation into control state (all state elements reset).

RESET_STYLE extension (async assert / sync deassert input variant) deferred to async FIFO phase where it is genuinely required.

## 12. Statistics

ovf_count, unf_count: 32-bit saturating. peak_count: CNT_W-bit saturating max of count. Cleared only by reset (deterministic; documented). STAT_ENABLE=0 removes them (power/area).

## 13. Throughput targets

- 1 accepted push/cycle sustained while !full.
- 1 accepted pop/cycle sustained while !empty.
- Simultaneous push+pop sustained indefinitely at any steady occupancy 1..DEPTH−1 (and boundary cases per §5).
Verified by t_throughput (§verification plan).

## 14. Corner-case definitions (normative)

| ID | Case | Required behavior |
|---|---|---|
| CC-01 | write while full | policy table §6; never corrupt existing entries |
| CC-02 | read while empty | policy table; no pointer move; no X on rd_data in sim beyond documented HOLD/ZERO |
| CC-03 | simultaneous rw @ full | pop only |
| CC-04 | simultaneous rw @ empty | push only |
| CC-05 | simultaneous rw @ mid | both; net 0; ordering kept |
| CC-06 | wrap boundary push/pop | correct wrap both pointers independently and together |
| CC-07 | reset during activity | §11; no partial-state leakage |
| CC-08 | threshold crossing same-cycle-as-op | flags reflect post-op registered state; events unaffected |
| CC-09 | DEPTH=2 min config | all above hold |
| CC-10 | non-pow2 DEPTH (e.g. 17) | wrap correctness |
| CC-11 | error_clear while new error pulses | pulse wins; sticky remains set if event coincides |
| CC-12 | backpressure (rd_en gated) | full eventually; then CC-01 |

## 15. Implementation requirements

Vendor-neutral RTL; memory via fifo_mem; ASYNC_REG not needed (single clock); target
xc7z020clg484-1 @100 MHz WNS≥0 for matrix configs C1..C8; resource recorded per config;
BRAM inference verified by utilization report (no unexpected LUTRAM at C5/C6/C8).

## 16. Verification requirements & acceptance criteria

Per SYNC_FIFO_VERIFICATION_PLAN.md. Acceptance = ALL of: lint clean (justified deviations
only); directed suite PASS; randomized suite PASS across ≥3 seeds incl. pinned seeds;
assertions never fire in sim; SBY BMC depth≥20 PASS + k-induction PASS on core properties;
Vivado synth+impl PASS with WNS≥0 on all matrix configs; coverage bins 100% hit or justified
waivers listed in milestone report; traceability matrix updated with evidence paths.
