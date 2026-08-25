// =============================================================================
// fifo_checker.sv — INDEPENDENT behavioral reference model + scoreboard for
// family FIFO verification. Semantics come from the PRODUCT SPECIFICATION,
// never from RTL internals (mandate §30).
//
// One instance monitors one DUT. The TB drives stimulus and samples the DUT
// interface each cycle, forwarding strobes + observed outputs here.
//
// Model semantics (SPEC §5/§6, ADR-002):
//   m_pop  = rd && (cnt>0)
//   m_push = wr && ( cnt<DEPTH ? 1 : (OVERWRITE ? !m_pop : 0) )
//   OVERWRITE stores INTO the head slot (oldest discarded), count unchanged.
//
// Provides:
//   step_fwft() — show-ahead checking: whenever model says data visible,
//                 compares DUT rd_data; retires on granted pops.
//   step_std()  — registered-read checking: retires words exactly when the
//                 DUT asserts rd_data_valid (delay handled by the DUT's own
//                 valid; the model tracks expected validity independently).
//   err_count() — accumulated mismatches.
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
    parameter string     NAME  = "chk"
) (
    input wire logic clk,
    input wire logic rst
);
    localparam int CNT_W = $clog2(DEPTH+1);

    logic [DW-1:0] q [DEPTH];
    logic [CNT_W-1:0] rp;          // read index (modulo DEPTH arithmetic in TB code)
    logic [CNT_W-1:0] cnt;
    integer           errors;

    function automatic void reset_model();
        rp = '0; cnt = '0;         // q left uninitialised deliberately (matches DUT contract)
    endfunction

    function automatic integer idx(input integer i);
        idx = (i >= DEPTH) ? i - DEPTH : i;    // DEPTH < 2*max index usage => single fold suffices
    endfunction

    function automatic integer err_count();  return errors; endfunction

    // ------------------------------------------------------------- FWFT flavour
    // vis_* = what the DUT presents right now; wr/rd = this-cycle strobes.
    function automatic void step_fwft(input bit wr, input bit rd,
                                      input logic [DW-1:0] wdata,
                                      input bit vis_valid, input logic [DW-1:0] vis_data,
                                      input bit ovf_evt, input bit unf_evt);
        bit m_pop, m_push;
        m_pop  = rd && (cnt != 0);
        m_push = wr && ((cnt != DEPTH) ? 1'b1 :
                        ((OVF == fifo_pkg::OVF_OVERWRITE) ? !m_pop : 1'b0));
        // event correlation (SPEC §6 / CC-01/02)
        if (ovf_evt !== (wr && !m_push)) begin
            $display("[%0t] %s ERROR: overflow_event=%b expected %b", $time, NAME, ovf_evt, (wr && !m_push));
            errors++;
        end
        if (unf_evt !== (rd && (cnt == 0))) begin
            $display("[%0t] %s ERROR: underflow_event=%b expected %b", $time, NAME, unf_evt, (rd && (cnt=='0)));
            errors++;
        end
        // visibility must match occupancy exactly (FUNC-008)
        if (vis_valid !== (cnt != 0)) begin
            $display("[%0t] %s ERROR: fwft valid=%b expected %b", $time, NAME, vis_valid, (cnt!=0));
            errors++;
        end
        if (cnt != 0 && vis_data !== q[rp]) begin
            $display("[%0t] %s ERROR: fwft data got %02h expected %02h", $time, NAME, vis_data, q[rp]);
            errors++;
        end
        // apply model transitions
        if (m_push) begin
            if (cnt == DEPTH) begin           // overwrite oldest in place
                q[rp] = wdata;
            end else begin
                q[idx(rp + cnt)] = wdata;
                cnt++;
            end
        end
        if (m_pop) begin
            rp = idx(rp + 1);
            cnt--;
        end
    endfunction

    // -------------------------------------------------------- standard flavour
    // Retire strictly on DUT rd_data_valid; independently derive the EXPECTED
    // valid stream from model grants (catches extra/missing valids).
    integer pend;   // outstanding granted pops not yet presented
    function automatic void step_std(input bit wr, input bit rd,
                                     input logic [DW-1:0] wdata,
                                     input bit dut_valid, input logic [DW-1:0] dut_data,
                                     input bit ovf_evt, input bit unf_evt);
        bit m_pop, m_push, exp_valid;
        m_pop  = rd && (cnt != 0);
        m_push = wr && ((cnt != DEPTH) ? 1'b1 :
                        ((OVF == fifo_pkg::OVF_OVERWRITE) ? !m_pop : 1'b0));
        exp_valid = (pend > 0);

        if (ovf_evt !== (wr && !m_push)) begin
            $display("[%0t] %s ERROR: overflow_event=%b expected %b", $time, NAME, ovf_evt, (wr && !m_push));
            errors++;
        end
        if (unf_evt !== (rd && (cnt == 0))) begin
            $display("[%0t] %s ERROR: underflow_event=%b expected %b", $time, NAME, unf_evt, (rd && (cnt=='0)));
            errors++;
        end
        if (dut_valid !== exp_valid) begin
            $display("[%0t] %s ERROR: rd_data_valid=%b expected %b (pend=%0d)", $time, NAME, dut_valid, exp_valid, pend);
            errors++;
        end
        if (exp_valid) begin
            if (dut_data !== q[rp]) begin
                $display("[%0t] %s ERROR: pop data got %02h expected %02h (rp=%0d cnt=%0d)",
                         $time, NAME, dut_data, q[rp], rp, cnt);
                errors++;
            end
            rp = idx(rp + 1);
            cnt--;
            pend--;
        end
        if (m_push) begin
            if (cnt == DEPTH && OVF == fifo_pkg::OVF_OVERWRITE) begin
                // overwrite applies only when no pop was simultaneously granted
                q[rp] = wdata;
            end else begin
                q[idx(rp + cnt)] = wdata;
                cnt++;
            end
        end
        if (m_pop) pend++;
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            reset_model();
            pend = 0;
        end
    end

    initial begin errors = 0; reset_model(); pend = 0; end

endmodule : fifo_checker

`default_nettype wire
`endif // FIFO_CHECKER_SV
