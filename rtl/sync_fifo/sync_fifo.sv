// =============================================================================
// sync_fifo.sv — single-clock FIFO, reference core of the FIFO/Buffer IP family
//
// Semantics (normative; see docs/specs/SYNC_FIFO_PRODUCT_SPECIFICATION.md):
//   * Strict FIFO ordering of accepted words; no loss/duplication/reordering
//     under any legal stimulus (FIFO-SYNC-FUNC-002).
//   * Occupancy counter is authoritative: full <=> count==DEPTH,
//     empty <=> count==0 (FIFO-SYNC-FUNC-003). Any DEPTH >= 2 including
//     non-power-of-two (FIFO-SYNC-FUNC-007, ADR-003).
//   * Grants evaluated against PRE-CYCLE state (ADR-002 / family rule P2):
//       full    + simultaneous push&pop  -> pop wins, push REJECTED
//       empty   + simultaneous push&pop  -> push wins, pop REJECTED
//   * Policies: OVF_REJECT | OVF_OVERWRITE ; UNF_HOLD | UNF_ZERO.
//     Illegal operations never corrupt stored data and always raise
//     observable events (FAM-COMMON-005).
//   * Modes: FWFT (show-ahead) vs standard registered read; optional extra
//     output pipeline stage OUTPUT_REGISTER (FIFO-SYNC-FUNC-008/009).
//   * Synchronous active-high reset; memory contents unspecified after reset
//     (FIFO-SYNC-FUNC-011, ADR-004).
//
// Latency tables: SPEC §8. Throughput: 1 accepted push/cycle and 1 accepted
// pop/cycle sustained, including indefinite simultaneous push+pop streaming
// (FIFO-SYNC-FUNC-001).
//
// Verification: tb/sync_fifo/tb_sync_fifo.sv (directed/random/coverage),
//               formal/sync_fifo/* (SBY BMC + induction),
//               assertions formal/sync_fifo/sync_fifo_props.sv.
//
// Traceability: REQUIREMENTS.md FIFO-SYNC-* rows.
// License: Apache-2.0 (project original code)
// =============================================================================

`default_nettype none
`include "fifo_pkg.sv"

module sync_fifo #(
    parameter int DATA_WIDTH             = 32,
    parameter int DEPTH                  = 256,
    parameter int FWFT_ENABLE            = 0,     // 1 = show-ahead (first-word fall-through)
    parameter int ALMOST_FULL_THRESHOLD  = -1,    // -1 sentinel => DEPTH
    parameter int ALMOST_EMPTY_THRESHOLD = -1,    // -1 sentinel => 1
    parameter int OUTPUT_REGISTER        = 0,     // extra output pipe stage (standard mode)
    parameter int MEMORY_TYPE            = fifo_pkg::MEM_AUTO,
    parameter int OVERFLOW_POLICY        = fifo_pkg::OVF_REJECT,
    parameter int UNDERFLOW_POLICY       = fifo_pkg::UNF_HOLD,
    parameter int STAT_ENABLE            = 1,
    parameter int DEBUG_ENABLE           = 0,

    // derived — do not override
    parameter int CNT_W  = $clog2(DEPTH + 1),
    parameter int ADDR_W = $clog2(DEPTH)
) (
    input  wire                    clk,
    input  wire                    rst,

    // write port
    input  wire                    wr_en,
    input  wire [DATA_WIDTH-1:0]   wr_data,
    output logic                   full,
    output logic                   almost_full,
    output logic                   overflow_event,   // 1-cycle pulse, same cycle as rejection/overwrite

    // read port
    input  wire                    rd_en,
    output logic [DATA_WIDTH-1:0]  rd_data,
    output logic                   rd_data_valid,
    output logic                   empty,
    output logic                   almost_empty,
    output logic                   underflow_event,  // 1-cycle pulse, same cycle as rejection

    // level / statistics
    output logic [CNT_W-1:0]       count,
    output logic [CNT_W-1:0]       peak_count,
    output logic [31:0]            ovf_count,
    output logic [31:0]            unf_count,
    output logic                   ovf_sticky,       // set until error_clear or reset
    output logic                   unf_sticky,
    input  wire                    error_clear,

    // debug observation (function-inert; FAM-COMMON-007)
    output logic [ADDR_W-1:0]      dbg_wr_ptr,
    output logic [ADDR_W-1:0]      dbg_rd_ptr
);

    // ------------------------------------------------------------- parameters
    localparam int AFULL  = (ALMOST_FULL_THRESHOLD  < 0) ? DEPTH : ALMOST_FULL_THRESHOLD;
    localparam int AEMPTY = (ALMOST_EMPTY_THRESHOLD < 0) ? 1     : ALMOST_EMPTY_THRESHOLD;

    localparam int MEM_MODE = fifo_pkg::resolve_mem_mode(MEMORY_TYPE, DEPTH, DATA_WIDTH);

    // Elaboration-time validation (FAM-COMMON-002).
    initial begin
        if (DATA_WIDTH < 1)                          $error("sync_fifo: DATA_WIDTH must be >= 1");
        if (DEPTH < 2)                               $error("sync_fifo: DEPTH must be >= 2");
        if (AFULL < 1 || AFULL > DEPTH)              $error("sync_fifo: ALMOST_FULL_THRESHOLD out of 1..DEPTH");
        if (AEMPTY < 0 || AEMPTY > DEPTH-1)          $error("sync_fifo: ALMOST_EMPTY_THRESHOLD out of 0..DEPTH-1");
        if (FWFT_ENABLE  != 0 && FWFT_ENABLE  != 1)  $error("sync_fifo: FWFT_ENABLE must be 0/1");
        if (OUTPUT_REGISTER != 0 && OUTPUT_REGISTER != 1) $error("sync_fifo: OUTPUT_REGISTER must be 0/1");
        if (OVERFLOW_POLICY  != fifo_pkg::OVF_REJECT &&
            OVERFLOW_POLICY  != fifo_pkg::OVF_OVERWRITE) $error("sync_fifo: bad OVERFLOW_POLICY");
        if (UNDERFLOW_POLICY != fifo_pkg::UNF_HOLD &&
            UNDERFLOW_POLICY != fifo_pkg::UNF_ZERO)      $error("sync_fifo: bad UNDERFLOW_POLICY");
        if (STAT_ENABLE  != 0 && STAT_ENABLE  != 1)  $error("sync_fifo: STAT_ENABLE must be 0/1");
        if (DEBUG_ENABLE != 0 && DEBUG_ENABLE != 1)  $error("sync_fifo: DEBUG_ENABLE must be 0/1");
    end

    // -------------------------------------------------------------- pointers
    logic [ADDR_W-1:0] wr_addr_q, rd_addr_q;
    logic [CNT_W-1:0]  count_q;

    function automatic logic [ADDR_W-1:0] nxt(input logic [ADDR_W-1:0] a);
        nxt = (a == ADDR_W'(DEPTH-1)) ? '0 : (a + 1'b1);
    endfunction

    // --------------------------------------------------------------- control
    // Pre-cycle grant evaluation (ADR-002). push_granted folds the overflow
    // policy in; the P2 corner rule makes a simultaneous granted pop suppress
    // overwrite so a full+both cycle can never lose two entries.
    wire pop_granted  = rd_en && (count_q != '0);
    wire push_granted = wr_en && (
                          (count_q != CNT_W'(DEPTH))               ? 1'b1 :
                          (OVERFLOW_POLICY == fifo_pkg::OVF_OVERWRITE)
                                                                   ? ~pop_granted :
                                                                     1'b0 );
    wire ovf_event_w  = wr_en && !push_granted;
    wire unf_event_w  = rd_en && (count_q == '0);

    wire count_inc = push_granted && !pop_granted;
    wire count_dec = pop_granted  && !push_granted;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_addr_q <= '0;
            rd_addr_q <= '0;
            count_q   <= '0;
        end else begin
            if (push_granted) wr_addr_q <= nxt(wr_addr_q);
            // OVERWRITE stores into the head slot: read pointer stays put.
            if (pop_granted)  rd_addr_q <= nxt(rd_addr_q);
            if      (count_inc) count_q <= count_q + 1'b1;
            else if (count_dec) count_q <= count_q - 1'b1;
        end
    end

    // ---------------------------------------------------------------- memory
    // Read-port address source depends on mode (ARCH §4):
    //   FWFT     : prefetch pointer (head+1) — enables back-to-back pops.
    //   standard : current read pointer (registered => BRAM-friendly).
    logic [ADDR_W-1:0] prefetch_q;
    wire [ADDR_W-1:0]  raddr = (FWFT_ENABLE != 0) ? prefetch_q : rd_addr_q;

    logic [DATA_WIDTH-1:0] mem_q;
    fifo_mem #(.DW(DATA_WIDTH), .ENTRIES(DEPTH), .MODE(MEM_MODE)) u_mem (
        .clk(clk), .we(push_granted),
        .waddr(wr_addr_q), .wdata(wr_data),
        .raddr(raddr), .q(mem_q)
    );

    // ------------------------------------------------------------ output stage
generate
    if (FWFT_ENABLE != 0) begin : g_fwft
        // Head register with write-forwarding (ARCH §4):
        //   * overwrite            : head := wr_data (oldest discarded in place)
        //   * fill-from-empty push : head := wr_data (forwarded, no RAM read)
        //   * pop with count>1     : head := prefetched next element
        logic [DATA_WIDTH-1:0] head_q;
        wire fill_empty   = push_granted && (count_q == '0);
        // OVERWRITE on full stores into the head slot: replaces oldest in place
        wire overwrite_wr = push_granted && (count_q == CNT_W'(DEPTH));
        wire head_reload  = pop_granted  && (count_q > CNT_W'(1));

        always_ff @(posedge clk) begin
            if (rst)               head_q <= '0;
            else if (overwrite_wr) head_q <= wr_data;
            else if (fill_empty)   head_q <= wr_data;
            else if (head_reload)  head_q <= mem_q;
        end

        // Invariant: prefetch == nxt(head) whenever count>0 (value irrelevant
        // while empty; re-seeded on fill-from-empty).
        always_ff @(posedge clk) begin
            if (rst)               prefetch_q <= ADDR_W'(1);
            else if (fill_empty)   prefetch_q <= nxt(wr_addr_q);
            else if (overwrite_wr) prefetch_q <= nxt(rd_addr_q);
            else if (pop_granted)  prefetch_q <= nxt(nxt(rd_addr_q));
        end

        assign rd_data       = (UNDERFLOW_POLICY == fifo_pkg::UNF_ZERO && count_q == '0)
                               ? '0 : head_q;
        assign rd_data_valid = (count_q != '0);

    end else begin : g_std
        // Standard registered read: uniform latency 1+OUTPUT_REGISTER cycles
        // regardless of MEM_MODE (SPEC §7/§8). BRAM already registers its
        // output inside fifo_mem; async modes capture explicitly here.
        localparam int DELAY = 1 + ((OUTPUT_REGISTER != 0) ? 1 : 0);

        logic [DATA_WIDTH-1:0] cap_q;
        logic [DELAY-1:0]      valid_sh;

        if (MEM_MODE == fifo_pkg::MEM_BRAM) begin : g_cap_bram
            assign cap_q = mem_q;                 // capture happened inside fifo_mem
        end else begin : g_cap_async
            always_ff @(posedge clk) begin
                if (rst) cap_q <= '0;
                else     cap_q <= mem_q;
            end
        end

        logic [DELAY-1:0] valid_nxt;
        always_comb begin
            valid_nxt      = valid_sh << 1;      // zero-fill, no negative part-select
            valid_nxt[0]   = pop_granted;
        end
        always_ff @(posedge clk) begin
            if (rst) valid_sh <= '0;
            else     valid_sh <= valid_nxt;
        end
        assign rd_data_valid = valid_sh[DELAY-1];

        // prefetch path unused in this mode; park it deterministically
        always_comb prefetch_q = '0;

        if (OUTPUT_REGISTER != 0) begin : g_outreg
            logic [DATA_WIDTH-1:0] out_q;
            always_ff @(posedge clk) begin
                if (rst) out_q <= '0;
                else     out_q <= cap_q;
            end
            assign rd_data = (UNDERFLOW_POLICY == fifo_pkg::UNF_ZERO && !valid_sh[DELAY-1])
                             ? '0 : out_q;
        end else begin : g_nooutreg
            assign rd_data = (UNDERFLOW_POLICY == fifo_pkg::UNF_ZERO && !valid_sh[DELAY-1])
                             ? '0 : cap_q;
        end
    end
endgenerate

    // ------------------------------------------------------------------ flags
    assign full         = (count_q == CNT_W'(DEPTH));
    assign empty        = (count_q == '0);
    assign almost_full  = (count_q >= CNT_W'(AFULL));
    assign almost_empty = (count_q <= CNT_W'(AEMPTY));
    assign count        = count_q;

    // ------------------------------------------------------------------- stats
    // Events same-cycle pulses; stickies latch until error_clear/rst; counters
    // saturate; peak tracks maximum post-op occupancy (FIFO-SYNC-FUNC-010).
    assign overflow_event  = ovf_event_w;
    assign underflow_event = unf_event_w;

    logic [31:0] ovf_count_q, unf_count_q;
    logic        ovf_sticky_q, unf_sticky_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            ovf_count_q  <= '0;
            unf_count_q  <= '0;
            ovf_sticky_q <= 1'b0;
            unf_sticky_q <= 1'b0;
        end else begin
            if ((STAT_ENABLE != 0) && ovf_event_w && ovf_count_q != '1)
                ovf_count_q <= ovf_count_q + 1'b1;
            if ((STAT_ENABLE != 0) && unf_event_w && unf_count_q != '1)
                unf_count_q <= unf_count_q + 1'b1;
            // CC-11: an event coinciding with clear keeps its sticky set
            if (ovf_event_w)        ovf_sticky_q <= 1'b1;
            else if (error_clear)   ovf_sticky_q <= 1'b0;
            if (unf_event_w)        unf_sticky_q <= 1'b1;
            else if (error_clear)   unf_sticky_q <= 1'b0;
        end
    end

    assign ovf_count  = (STAT_ENABLE != 0) ? ovf_count_q : '0;
    assign unf_count  = (STAT_ENABLE != 0) ? unf_count_q : '0;
    assign ovf_sticky = ovf_sticky_q;
    assign unf_sticky = unf_sticky_q;

    wire [CNT_W-1:0] count_next =
        count_q + CNT_W'(count_inc ? 1 : 0) - CNT_W'(count_dec ? 1 : 0);

    logic [CNT_W-1:0] peak_q;
    always_ff @(posedge clk) begin
        if (rst)                      peak_q <= '0;
        else if (count_next > peak_q) peak_q <= count_next;
    end
    assign peak_count = peak_q;

    // ------------------------------------------------------------------ debug
    assign dbg_wr_ptr = (DEBUG_ENABLE != 0) ? wr_addr_q : '0;
    assign dbg_rd_ptr = (DEBUG_ENABLE != 0) ? rd_addr_q : '0;

endmodule : sync_fifo

`default_nettype wire
