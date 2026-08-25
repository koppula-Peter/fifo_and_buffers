# FIFO / Buffer IP Family Architecture

## 1. Family overview and positioning

Twelve IPs sharing one control/data philosophy, one memory abstraction, one verification
methodology. The family is organized as **two cores + nine derivatives + wrappers**:

```text
Tier 0  infrastructure   : fifo_pkg, fifo_mem, stream types, TB framework
Tier 1  reference cores  : sync_fifo (single clock), async_fifo (dual clock CDC)
Tier 2  datapath variants: width_conv, packet, frame, priority, multi_queue,
                           circular, elastic, replay, jitter
Tier 3  integration      : axi4s wrappers, axi4lite regs+IRQ, ZC702 demo, SW
```

## 2. Unifying architectural principles

| Principle | Statement | Consequence |
|---|---|---|
| P1 Count-based control | Occupancy counter is the single source of truth for full/empty/almost/level in all single-clock cores; pointers are addresses only | Any DEPTH≥2 (non-pow2 clean), one comparator chain, trivial watermark logic |
| P2 Pre-cycle operation semantics | Push/pop grants evaluated against state at cycle start | Deterministic corner behavior (full+both strobes ⇒ pop wins; empty ⇒ push wins) |
| P3 Memory behind abstraction | All storage through `fifo_mem` (REG/LUTRAM/BRAM/AUTO inference) | Portability; Vivado-verified inference |
| P4 Errors observable, never silent | Illegal ops rejected + pulsed/sticky events + counters | §25 compliance |
| P5 CDC isolated to async core | Gray-pointer dual-clock core is the only crossing structure in the family; elastic/dual-clock reuse it | One verified CDC pattern, reviewed once |
| P6 Native-first, AXI-wrapped later | Cores expose native interfaces; AXI4-Stream/Lite live only in `rtl/wrappers` | No AXI contamination of cores (§13 phase rule) |
| P7 Verification parity | Every core ships with: directed TB, randomized TB, bound SVA, SBY formal where feasible | DoD enforcement |

## 3. Reusable foundational blocks

| Block | File (target) | First used by | Reuse count gate (§4) |
|---|---|---|---|
| Package: types, versioning, clog2 helpers, param checks | rtl/common/fifo_pkg.sv | all | immediate |
| Memory abstraction | rtl/common/fifo_mem.sv | sync_fifo → all storage users | immediate (justified by pcie/rng precedent + this IP) |
| Sync FIFO core | rtl/sync_fifo/sync_fifo.sv | width_conv (per-side), packet/frame payload stage candidates | ≥2 uses before promoting patterns into common code |
| Async CDC core | rtl/async_fifo/async_fifo_core.sv | dual_clock, elastic | Phase 3 |
| Threshold/watermark generator | promoted to common after 2nd user | sync_fifo first | deferred |
| Descriptor FIFO | TBD at packet phase | packet/frame/multi-queue | deferred per §4 |
| Arbiter | TBD at priority phase | priority/multi-queue | deferred |

**Deliberate anti-pattern guard:** no block moves to `rtl/common/` until two independent
consumers exist or the consumer is the family-wide package/memory layer itself.

## 4. Interface doctrine

- Native write port: `wr_en/wr_data/full/(almost_full)` — native read port: `rd_en/rd_data/empty/(almost_empty)` (+count, events).
- FWFT is a mode of the read port (data visible before pop), not a different interface.
- Stream-capable derivatives additionally expose canonical stream record (valid/ready + sop/eop/keep/user) from `fifo_pkg`.
- AXI4-Stream adapters map: valid↔TVALID, ready↔TREADY, eop↔TLAST, keep↔TKEEP, user↔TUSER. Flags never masquerade as handshakes.
- Register-mapped derivatives get a uniform register frame (VERSION/CAP/CTRL/STAT/IRQ…) documented in docs/registers/REGISTER_MAP.md at Phase 13.

## 5. Clock/reset doctrine (family)

- Single-clock cores: synchronous active-high reset default (`RESET_SYNC_ACTIVE_HIGH=1` option for active-low legacy integration). Async-reset variant provided only where an asynchronous fabric reset must be honored (`ASYNC_RESET=1` adds input synchronizer-free async assert/sync deassert usage note).
- Dual-clock cores: independent domain resets with documented crossing rules; reset deassert synchronized per-domain; memory contents unspecified after reset.
- No RAM-content dependence for logical correctness anywhere in the family.

## 6. Per-IP architecture sketches (frozen progressively at phase gates)

| IP | Core idea | Key reuse |
|---|---|---|
| sync_fifo | count-based control + fifo_mem + FWFT outreg | Tier-1 reference |
| async_fifo | binary→Gray ptrs, 2FF sync both ways, conservative flags | own core |
| dual_clock | async core + API/status profile (ADR pending doc distinction) | async core |
| width_conv | narrow↔wide shift/assemble stages around qualified FIFOs | sync_fifo ×2 |
| packet | payload mem + metadata FIFO + commit pointer; store-and-forward default | descriptor pattern |
| frame | data RAM + frame descriptor ring; atomic frame commit | descriptor pattern |
| priority | N independent queues + strict/WRR arbiter | queue slice = sync_fifo variant |
| multi_queue | shared RAM + free-list descriptors (ADR-005 trade study) | descriptor + arbiter |
| circular | ring w/o pop semantics; trigger freeze; pre/post capture windows | fifo_mem |
| elastic | dual-clock core + occupancy-target slip/correction telemetry | async core |
| replay | ring + seq numbers; commit/ack/replay pointer triple | fifo_mem |
| jitter | playout-delay scheduler over timestamped packets; policy engine | packet-ish storage + timers |

Detailed specs written per phase; nothing here is RTL-committed ahead of its spec.
