# Dependency Map

## RTL dependency graph (target architecture)

```text
                        ┌────────────────────────────┐
                        │ fifo_pkg (types/params/    │
                        │ validation helpers)        │
                        └──────────┬─────────────────┘
                                   │
                     ┌─────────────┴──────────────┐
                     │ fifo_mem  (memory          │
                     │ abstraction REG/LUTRAM/    │
                     │ BRAM/AUTO)                 │
                     └─────────────┬──────────────┘
                                   │
        ┌──────────────────────────┼───────────────────────────┐
        │                          │                           │
┌───────▼────────┐       ┌─────────▼─────────┐       ┌─────────▼────────┐
│ sync_fifo      │       │ async_fifo (Gray  │       │ stream_if defs   │
│ (reference     │◄──────│ CDC core, 2FF     │       │ (sop/eop/keep/   │
│ core)          │ reuse │ sync, safe flags) │       │ user records)    │
└───────┬────────┘ flags └─────────┬─────────┘       └─────────┬────────┘
        │                          │                           │
        │                    ┌─────▼──────┐                    │
        │                    │ dual_clock │                    │
        │                    │ (=async    │                    │
        │                    │  core+API) │                    │
        │                    └────────────┘                    │
        ▼                                                      ▼
┌───────────────────────────────────────────────────────────────────────┐
│ Derived datapath IPs — each reuses fifo_mem + control patterns        │
│ width_conv_fifo · packet_fifo · frame_fifo · priority_fifo ·          │
│ multi_queue_fifo · circular_buffer · elastic_buffer(→async core) ·    │
│ replay_buffer · jitter_buffer                                         │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                     ┌─────────────┴─────────────┐
                     │ wrappers: axi4s_adapter,  │
                     │ axi4lite_regs, irq_ctrl   │
                     └─────────────┬─────────────┘
                                   │
                          zc702 demo top + sw drivers
```

## Build/verification dependencies

| Layer | Depends on | Notes |
|---|---|---|
| `rtl/common/fifo_pkg.sv` | nothing | compiled first everywhere |
| `rtl/common/fifo_mem.sv` | fifo_pkg | memory abstraction; no vendor primitives |
| `tb/common/*` | fifo_pkg | ref models, scoreboard, coverage helpers |
| unit TBs | DUT + tb/common | iverilog `-g2012` |
| assertions (`*_props.sv`) | DUT ports only | bind-based, tool-neutral SVA subset |
| formal harness | DUT + props + shadow model | yowasp-sby → z3/boolector |
| Vivado scripts | rtl tree | OOC per configuration |

## Milestone dependency order (hard)

1 → 2 → {3,4} → 5 → 6 → {7,8} → {9,10,11,12} → 13(AXI/sw) → 14(ZC702) → 15(release).
No milestone starts until its predecessor's DoD checklist is green (mandate §50).

## Cross-project dependencies

None. This IP is vendor- and sibling-independent by design; it must not instantiate or
`include anything from RNG/pcie/reset/etc.
