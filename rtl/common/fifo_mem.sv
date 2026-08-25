// =============================================================================
// fifo_mem.sv — vendor-neutral memory abstraction for the FIFO/Buffer IP family
//
// MODE = MEM_REG    : flip-flop array, asynchronous read (combinational q)
// MODE = MEM_LUTRAM : distributed-RAM style, asynchronous read (q combinational)
// MODE = MEM_BRAM   : synchronous read (q registered at clk edge), read-first
//
// Semantics contract used by all consumers:
//   * write-first-cycle behaviour on (waddr==raddr) collision is READ-FIRST:
//     q never reflects the word being written in the same cycle. Consumers are
//     designed so this case is either impossible or explicitly defined
//     (SYNC_FIFO ARCH §3 / SPEC §4).
//   * q timing depends on MODE: BRAM -> one cycle after raddr; REG/LUTRAM ->
//     same cycle as raddr. Consumers must be generated per mode.
//
// No vendor primitives in this file (ADR-001). Vivado inference verified by
// configuration-matrix runs; see reports/sync_fifo/vivado_*.
//
// Traceability: FAM-COMMON-003, ADR-001, SYNC_FIFO_ARCH §3.
// License: Apache-2.0 (project original code)
// =============================================================================

`default_nettype none
`include "fifo_pkg.sv"

module fifo_mem #(
    parameter int DW      = 32,
    parameter int ENTRIES = 256,
    parameter int MODE    = fifo_pkg::MEM_LUTRAM   // resolved mode only (no AUTO here)
) (
    input  wire         clk,
    input  wire         we,
    input  wire [$clog2(ENTRIES)-1:0] waddr,
    input  wire [DW-1:0]              wdata,
    input  wire [$clog2(ENTRIES)-1:0] raddr,
    output logic [DW-1:0]             q
);
    initial begin
        if (DW < 1)      $error("fifo_mem: DW must be >= 1");
        if (ENTRIES < 1) $error("fifo_mem: ENTRIES must be >= 1");
        if (MODE == fifo_pkg::MEM_AUTO) $error("fifo_mem: resolve MEM_AUTO before instantiation");
    end

    logic [DW-1:0] mem [ENTRIES];

generate
    if (MODE == fifo_pkg::MEM_BRAM) begin : g_bram
        // Synchronous read => BRAM inference (Vivado UG901 template).
        always_ff @(posedge clk) begin
            if (we) mem[waddr] <= wdata;
            q <= mem[raddr];               // read-first: old data on collision
        end
    end else begin : g_async // MEM_REG | MEM_LUTRAM
        always_ff @(posedge clk) begin
            if (we) mem[waddr] <= wdata;
        end
        always_comb q = mem[raddr];
    end
endgenerate

endmodule : fifo_mem

`default_nettype wire
