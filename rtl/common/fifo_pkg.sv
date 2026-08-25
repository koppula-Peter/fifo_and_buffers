// =============================================================================
// fifo_pkg.sv — family-wide definitions for the FIFO/Buffer IP suite
//
// Contents:
//   * IP version constants                       (FAM-COMMON-008)
//   * Memory-mode / policy constants             (FAM-COMMON-003, FIFO-SYNC-FUNC-005)
//   * AUTO memory-resolution helper              (ADR-001)
//
// Deliberately kept to constants/functions only (no typedefs in ports) so the
// package parses cleanly under iverilog -g2012, Verilator lint and yosys
// read_verilog -sv alike.
//
// Traceability: docs/requirements/REQUIREMENTS.md (FAM-*),
//               docs/specs/SYNC_FIFO_PRODUCT_SPECIFICATION.md §2–§3
// License: Apache-2.0 (project original code)
// =============================================================================

`ifndef FIFO_PKG_SV
`define FIFO_PKG_SV

`default_nettype none

package fifo_pkg;

    // ------------------------------------------------------------------ version
    // Published API constants (FAM-COMMON-008); consumed by software and TBs,
    // not by RTL — hence the scoped lint waiver (reviewed, mandate §46).
    /* verilator lint_off UNUSEDPARAM */
    localparam int unsigned IP_MAJOR = 1;
    localparam int unsigned IP_MINOR = 0;
    localparam int unsigned IP_PATCH = 0;
    localparam int unsigned BUILD_ID = 1;   // bumped per qualified release artifact
    /* verilator lint_on UNUSEDPARAM */

    // ------------------------------------------------------------ memory modes
    localparam int MEM_REG    = 0;  // flip-flop array, asynchronous read
    localparam int MEM_LUTRAM = 1;  // distributed RAM, asynchronous read
    localparam int MEM_BRAM   = 2;  // block RAM, synchronous read
    localparam int MEM_AUTO   = 3;  // resolved at elaboration (see below)

    // ADR-001 AUTO resolution heuristic:
    //   DEPTH <= 8                    -> REG   (trivial sizes; flops cheapest)
    //   bits <= 64 kbit               -> LUTRAM (below useful BRAM granularity)
    //   otherwise                     -> BRAM
    function automatic int resolve_mem_mode(input int mode, input int depth, input int dw);
        case (mode)
            MEM_REG, MEM_LUTRAM, MEM_BRAM: resolve_mem_mode = mode;
            MEM_AUTO: resolve_mem_mode =
                (depth <= 8)          ? MEM_REG    :
                (depth*dw <= 64*1024) ? MEM_LUTRAM :
                                        MEM_BRAM;
            default: resolve_mem_mode = MEM_BRAM; // unreachable after validation
        endcase
    endfunction

    // ------------------------------------------------------- overflow policies
    localparam int OVF_REJECT    = 0;  // drop incoming word on full (default)
    localparam int OVF_OVERWRITE = 1;  // discard oldest, store newest (order caveat, SPEC §10)

    // ------------------------------------------------------- underflow policies
    localparam int UNF_HOLD = 0;       // rd_data holds last value on empty read (default)
    localparam int UNF_ZERO = 1;       // rd_data forced to 0 on empty read

endpackage : fifo_pkg

`endif // FIFO_PKG_SV
