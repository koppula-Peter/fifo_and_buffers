// =============================================================================
// fifo_coverage.sv — functional coverage sampler for the sync FIFO milestone
//
// One instance per DUT; bins sampled every non-reset cycle from DUT pins only.
// Aggregated by the TB at report time via hierarchical refs. Bin set mirrors
// SYNC_FIFO_VERIFICATION_PLAN §7 / mandate §34.
//
// Saturation of 32-bit statistics counters is a DOCUMENTED WAIVER (impractical
// cycle count in simulation); sticky/error paths and counter increments are
// verified instead. Recorded in milestone report + coverage section.
// =============================================================================
`ifndef FIFO_COVERAGE_SV
`define FIFO_COVERAGE_SV

`default_nettype none

module fifo_coverage #(
    parameter int    DEPTH = 8,
    parameter int    AFULL = 8,     // resolved threshold (post-sentinel)
    parameter int    AEMPTY = 1,
    parameter string NAME  = "cov"
) (
    input wire logic        clk,
    input wire logic        sample_en,     // !rst
    input wire logic [31:0] count,         // zero-extended DUT count
    input wire logic        wr_busy, rd_busy,          // strobes this cycle
    input wire logic        full, empty,
    input wire logic        almost_full, almost_empty,
    input wire logic        ovf_evt, unf_evt, err_clr,
    input wire logic [31:0] wr_ptr, rd_ptr            // debug taps (wrap detection)
);
    integer occ0=0, occ1=0, occmid=0, occdm1=0, occfull=0;
    integer wrap_w=0, wrap_r=0;
    integer simul_full=0, simul_empty=0, simul_mid=0;
    integer ovf_hits=0, unf_hits=0;
    integer thr_up=0, thr_dn=0;
    integer afull_hits=0, aempty_hits=0;
    integer errclr_race=0;
    integer bp_streak=0, bp_max=0;

    reg [31:0] prev_wptr='0, prev_rptr='0;
    reg [31:0] prev_count='0;
    reg        prev_full=0;

    always_ff @(posedge clk) begin
        if (!sample_en) begin
            prev_wptr <= wr_ptr; prev_rptr <= rd_ptr;
            prev_count <= count; prev_full <= full;
            bp_streak  <= 0;
        end else begin
            // ---- occupancy classes
            if (count == 0)                    occ0++;
            if (count == 1)                    occ1++;
            if (DEPTH > 3 && count == DEPTH/2) occmid++;
            if (DEPTH > 2 && count == DEPTH-1) occdm1++;
            if (count == DEPTH)                occfull++;

            // ---- pointer wraps via debug taps
            if (wr_ptr < prev_wptr) wrap_w++;
            if (rd_ptr < prev_rptr) wrap_r++;

            // ---- simultaneous-op corners evaluated against PRE-cycle state
            if (wr_busy && rd_busy) begin
                if (prev_count == DEPTH)      simul_full++;   // CC-03
                else if (prev_count == 0)     simul_empty++;  // CC-04
                else                          simul_mid++;    // CC-05
            end

            if (ovf_evt) ovf_hits++;
            if (unf_evt) unf_hits++;

            // ---- threshold crossings (post-op count vs pre-op count)
            if (prev_count <  AFULL && count >= AFULL) thr_up++;
            if (prev_count >= AFULL && count <  AFULL) thr_dn++;
            if (almost_full)  afull_hits++;
            if (almost_empty) aempty_hits++;

            // ---- error_clear coincident with fresh event (CC-11)
            if (err_clr && (ovf_evt || unf_evt)) errclr_race++;

            // ---- backpressure streak: writer strobing while full
            if (wr_busy && full) begin
                bp_streak <= bp_streak + 1;
                if (bp_streak + 1 > bp_max) bp_max = bp_streak + 1;
            end else
                bp_streak <= 0;

            prev_wptr <= wr_ptr; prev_rptr <= rd_ptr;
            prev_count <= count; prev_full <= full;
        end
    end

endmodule : fifo_coverage

`default_nettype wire
`endif // FIFO_COVERAGE_SV
