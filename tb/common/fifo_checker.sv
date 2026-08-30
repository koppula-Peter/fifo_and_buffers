// =============================================================================
// fifo_checker.sv — INDEPENDENT behavioral reference model + scoreboard for
// family FIFO verification. Semantics come from the PRODUCT SPECIFICATION,
// never from RTL internals (mandate §30).
//
// One instance monitors one DUT. The TB samples (strobes, registered outputs)
// just before each clock edge and forwards them here; grants are therefore
// evaluated against the same pre-edge state the DUT used.
//
// Model semantics (SPEC §5/§6, ADR-002):
//   m_pop  = rd && (cnt>0)
//   m_push = wr && ( cnt<DEPTH ? 1 : (OVERWRITE ? !m_pop : 0) )
//   OVERWRITE stores INTO the head slot (oldest discarded), count unchanged.
//
// step_std() pipeline alignment: a pop granted at cycle T surfaces as
// rd_data_valid at T+DELAY; retirement is applied FIRST when the valid
// arrives, so subsequent grant evaluation uses the aligned occupancy —
// mirroring the DUT, whose count register already reflects earlier grants.
// =============================================================================
`ifndef FIFO_CHECKER_SV
`define FIFO_CHECKER_SV

`default_nettype none
`include "fifo_pkg.sv"

module fifo_checker #(
    parameter int        DW    = 8,
    parameter int        DEPTH = 8,
    parameter int        OVF   = fifo_pkg::OVF_REJECT,
    parameter int        UNF   = fifo_pkg::UNF_HOLD,
    parameter int        DELAY = 1,   // standard-mode cycles from grant to presentation
    parameter string     NAME  = "chk"
) (
    input wire logic clk,
    input wire logic rst
);
    localparam int CNT_W = $clog2(DEPTH+1);

    logic [DW-1:0] q [DEPTH+8];          // ring: stored + in-flight words
    logic [CNT_W-1:0] rp;                // FWFT-model front index
    logic [CNT_W-1:0] cnt;               // FWFT-model occupancy
    integer           ih, ic, it;        // std-model ring markers (see step_std)
    integer           cnt_int;           // std-model internal occupancy
    integer           inflight;          // granted-but-unpresented words
    integer           errors;
    integer           retires;   // total words retired through the read port
    logic [DELAY-1:0] pend_sh;   // std-mode grant->presentation pipeline mirror

    function automatic void reset_model();
        rp = '0; cnt = '0;         // q contents deliberately uninitialised (matches DUT contract)
        ih = 0; ic = 0; it = 0; cnt_int = 0; inflight = 0;
    endfunction

    localparam int RSIZE = DEPTH + 8;
    function automatic integer idx(input integer i);
        idx = i % RSIZE;           // ring wrap for arbitrarily long runs
    endfunction

    function automatic integer err_count();  return errors; endfunction

    // ------------------------------------------------------------- FWFT flavour
    function automatic void step_fwft(input bit wr, input bit rd,
                                      input logic [DW-1:0] wdata,
                                      input bit vis_valid, input logic [DW-1:0] vis_data,
                                      input bit ovf_evt, input bit unf_evt);
        bit full_now, m_pop, m_push_normal, ovw, m_push, exp_ovf;
        full_now      = (cnt == DEPTH);
        m_pop         = rd && (cnt != 0);
        m_push_normal = wr && !full_now;
        ovw           = wr && full_now && (OVF == fifo_pkg::OVF_OVERWRITE) && !m_pop;
        m_push        = m_push_normal || ovw;
        // SPEC §6: any push onto a full FIFO raises overflow observation
        exp_ovf       = wr && (!m_push || ((OVF == fifo_pkg::OVF_OVERWRITE) && full_now));
        if (ovf_evt !== exp_ovf) begin
            $display("[%0t] %s ERROR: overflow_event=%b expected %b", $time, NAME, ovf_evt, exp_ovf);
            errors++;
        end
        if (unf_evt !== (rd && (cnt == 0))) begin
            $display("[%0t] %s ERROR: underflow_event=%b expected %b", $time, NAME, unf_evt, (rd && (cnt=='0)));
            errors++;
        end
        if (vis_valid !== (cnt != 0)) begin
            $display("[%0t] %s ERROR: fwft rd_data_valid=%b expected %b", $time, NAME, vis_valid, (cnt!=0));
            errors++;
        end
        if (cnt != 0 && vis_data !== q[rp]) begin
            $display("[%0t] %s ERROR: fwft data got %02h expected %02h", $time, NAME, vis_data, q[rp]);
            errors++;
        end
        if (m_push_normal) begin
            q[idx(rp + cnt)] = wdata;
            cnt++;
        end
        if (ovw) begin
            rp = idx(rp + 1);                          // discard oldest
            q[idx(rp + (cnt - 1))] = wdata;            // append newest; cnt unchanged
        end
        if (m_pop) begin
            rp = idx(rp + 1);
            cnt--;
            retires++;
        end
    endfunction

    // -------------------------------------------------------- standard flavour
    function automatic void step_std(input bit wr, input bit rd,
                                     input logic [DW-1:0] wdata,
                                     input bit dut_valid, input logic [DW-1:0] dut_data,
                                     input bit ovf_evt, input bit unf_evt);
        // ---- std-mode model state ------------------------------------------
        // The DUT retires internally at GRANT time but presents DELAY cycles
        // later. Three ring markers mirror that exactly:
        //   ih : next word to be PRESENTED on the port (advances on valid)
        //   ic : oldest STORED (not yet granted) word — pops/overwrites act here
        //   it : append position
        // cnt_int mirrors DUT registered occupancy; inflight == ic - ih.
        bit full_now, m_pop, m_push_normal, ovw, m_push, exp_ovf;
        bit exp_valid = pend_sh[DELAY-1];

        // 1) validity-stream alignment + presentation of earlier grants
        if (dut_valid !== exp_valid) begin
            $display("[%0t] %s ERROR: rd_data_valid=%b expected %b (pipe=%b)", $time, NAME, dut_valid, exp_valid, pend_sh);
            errors++;
        end
        if (exp_valid) begin
            if (dut_data !== q[idx(ih)]) begin
                $display("[%0t] %s ERROR: pop data got %02h expected %02h (ih=%0d cnt=%0d)",
                         $time, NAME, dut_data, q[idx(ih)], ih, cnt_int);
                errors++;
            end
            ih = ih + 1;
            inflight = inflight - 1;
            retires++;
        end

        // 2) grants for this cycle's strobes against internal occupancy
        full_now      = (cnt_int == DEPTH);
        m_pop         = rd && (cnt_int != 0);
        m_push_normal = wr && !full_now;
        ovw           = wr && full_now && (OVF == fifo_pkg::OVF_OVERWRITE) && !m_pop;
        m_push        = m_push_normal || ovw;

        // 3) event correlation (SPEC §6, CC-01/02)
        exp_ovf = wr && (!m_push || ((OVF == fifo_pkg::OVF_OVERWRITE) && full_now));
        if (ovf_evt !== exp_ovf) begin
            $display("[%0t] %s ERROR: overflow_event=%b expected %b", $time, NAME, ovf_evt, exp_ovf);
            errors++;
        end
        if (unf_evt !== (rd && (cnt_int == 0))) begin
            $display("[%0t] %s ERROR: underflow_event=%b expected %b", $time, NAME, unf_evt, (rd && (cnt_int=='0)));
            errors++;
        end

        // 4) apply grants immediately (mirrors registered-state updates)
        if (m_push_normal) begin
            q[idx(it)] = wdata;
            it++;
            cnt_int++;
        end
        if (ovw) begin
            q[idx(it)] = wdata;      // append newest
            it++;
            ic++;                    // discard oldest stored; cnt_int unchanged
        end
        if (m_pop) begin
            ic++;                    // grant: word becomes in-flight
            cnt_int--;
            inflight++;
        end

        // 5) advance grant->presentation pipe
        if (DELAY > 1) pend_sh = {pend_sh[DELAY-2:0], m_pop};
        else           pend_sh = {pend_sh[DELAY-1], m_pop};
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            reset_model();
            pend_sh = '0;
        end
    end

    initial begin errors = 0; retires = 0; reset_model(); pend_sh = '0; end

endmodule : fifo_checker

`default_nettype wire
`endif // FIFO_CHECKER_SV
