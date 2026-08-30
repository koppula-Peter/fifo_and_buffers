// =============================================================================
// tb_sync_fifo.sv — unit testbench for sync_fifo (directed + random + coverage)
//
// Configurations under test (SPEC verification plan §2):
//   U1 DW=16 D=8  FWFT=0 OUTREG=0 REJECT/HOLD LUTRAM   (std baseline)
//   U2 DW=8  D=5  FWFT=1 OUTREG=0 REJECT/ZERO REG      (non-pow2, FWFT)
//   U3 DW=16 D=8  FWFT=0 OUTREG=1 OVERWRITE/HOLD REG   (outreg + overwrite)
//   U4 DW=8  D=4  FWFT=1 OUTREG=0 OVERWRITE/ZERO LUTRAM(FWFT overwrite)
//
// Stimulus is shared; each checker independently models its DUT's policy.
// Pass criterion: all checker error counts zero, explicit probes pass,
// mandatory coverage bins hit (waivers documented in milestone report).
// Prints "RESULT: PASS" / "RESULT: FAIL" per repo regression protocol.
//
// Plusargs: +SEED=<n> (default 1)   +NCYC=<n> random cycles (default 3000)
// =============================================================================
`timescale 1ns/1ps
`default_nettype none
`include "fifo_pkg.sv"
`include "fifo_checker.sv"
`include "fifo_coverage.sv"

module tb_sync_fifo;

    localparam int PERIOD = 10;

    reg         clk = 1'b0;
    reg         rst = 1'b1;
    reg         wr_s = 1'b0, rd_s = 1'b0, clr_s = 1'b0;
    reg [15:0]  d_s  = '0;

    always #(PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------------ DUTs
    wire full1, afull1, ovf1, empty1, aempty1, unf1, dv1;
    wire [15:0] rd1; wire [3:0] cnt1, pk1;
    wire [31:0] oc1, uc1; wire os1, us1;
    wire [2:0] dwp1, drp1;
    sync_fifo #(.DATA_WIDTH(16), .DEPTH(8), .FWFT_ENABLE(0), .OUTPUT_REGISTER(0),
                .MEMORY_TYPE(fifo_pkg::MEM_LUTRAM), .DEBUG_ENABLE(1)) u1 (
        .clk(clk), .rst(rst), .wr_en(wr_s), .wr_data(d_s),
        .full(full1), .almost_full(afull1), .overflow_event(ovf1),
        .rd_en(rd_s), .rd_data(rd1), .rd_data_valid(dv1), .empty(empty1), .almost_empty(aempty1),
        .underflow_event(unf1), .count(cnt1), .peak_count(pk1),
        .ovf_count(oc1), .unf_count(uc1), .ovf_sticky(os1), .unf_sticky(us1),
        .error_clear(clr_s), .dbg_wr_ptr(dwp1), .dbg_rd_ptr(drp1));

    wire full2, afull2, ovf2, empty2, aempty2, unf2, dv2;
    wire [7:0] rd2; wire [2:0] cnt2, pk2;
    wire [31:0] oc2, uc2; wire os2, us2;
    wire [2:0] dwp2, drp2;
    sync_fifo #(.DATA_WIDTH(8), .DEPTH(5), .FWFT_ENABLE(1), .MEMORY_TYPE(fifo_pkg::MEM_REG),
                .UNDERFLOW_POLICY(fifo_pkg::UNF_ZERO), .DEBUG_ENABLE(1)) u2 (
        .clk(clk), .rst(rst), .wr_en(wr_s), .wr_data(d_s[7:0]),
        .full(full2), .almost_full(afull2), .overflow_event(ovf2),
        .rd_en(rd_s), .rd_data(rd2), .rd_data_valid(dv2), .empty(empty2), .almost_empty(aempty2),
        .underflow_event(unf2), .count(cnt2), .peak_count(pk2),
        .ovf_count(oc2), .unf_count(uc2), .ovf_sticky(os2), .unf_sticky(us2),
        .error_clear(clr_s), .dbg_wr_ptr(dwp2), .dbg_rd_ptr(drp2));

    wire full3, afull3, ovf3, empty3, aempty3, unf3, dv3;
    wire [15:0] rd3; wire [3:0] cnt3, pk3;
    wire [31:0] oc3, uc3; wire os3, us3;
    wire [2:0] dwp3, drp3;
    sync_fifo #(.DATA_WIDTH(16), .DEPTH(8), .FWFT_ENABLE(0), .OUTPUT_REGISTER(1),
                .OVERFLOW_POLICY(fifo_pkg::OVF_OVERWRITE), .ALMOST_FULL_THRESHOLD(6),
                .ALMOST_EMPTY_THRESHOLD(2), .MEMORY_TYPE(fifo_pkg::MEM_REG), .DEBUG_ENABLE(1)) u3 (
        .clk(clk), .rst(rst), .wr_en(wr_s), .wr_data(d_s),
        .full(full3), .almost_full(afull3), .overflow_event(ovf3),
        .rd_en(rd_s), .rd_data(rd3), .rd_data_valid(dv3), .empty(empty3), .almost_empty(aempty3),
        .underflow_event(unf3), .count(cnt3), .peak_count(pk3),
        .ovf_count(oc3), .unf_count(uc3), .ovf_sticky(os3), .unf_sticky(us3),
        .error_clear(clr_s), .dbg_wr_ptr(dwp3), .dbg_rd_ptr(drp3));

    wire full4, afull4, ovf4, empty4, aempty4, unf4, dv4;
    wire [7:0] rd4; wire [2:0] cnt4, pk4;
    wire [31:0] oc4, uc4; wire os4, us4;
    wire [1:0] dwp4, drp4;
    sync_fifo #(.DATA_WIDTH(8), .DEPTH(4), .FWFT_ENABLE(1),
                .OVERFLOW_POLICY(fifo_pkg::OVF_OVERWRITE),
                .UNDERFLOW_POLICY(fifo_pkg::UNF_ZERO),
                .MEMORY_TYPE(fifo_pkg::MEM_LUTRAM), .DEBUG_ENABLE(1)) u4 (
        .clk(clk), .rst(rst), .wr_en(wr_s), .wr_data(d_s[7:0]),
        .full(full4), .almost_full(afull4), .overflow_event(ovf4),
        .rd_en(rd_s), .rd_data(rd4), .rd_data_valid(dv4), .empty(empty4), .almost_empty(aempty4),
        .underflow_event(unf4), .count(cnt4), .peak_count(pk4),
        .ovf_count(oc4), .unf_count(uc4), .ovf_sticky(os4), .unf_sticky(us4),
        .error_clear(clr_s), .dbg_wr_ptr(dwp4), .dbg_rd_ptr(drp4));

    // -------------------------------------------------------------- checkers
    fifo_checker #(.DW(16), .DEPTH(8), .OVF(fifo_pkg::OVF_REJECT),    .UNF(fifo_pkg::UNF_HOLD), .DELAY(1), .NAME("C1")) c1 (.clk(clk), .rst(rst));
    fifo_checker #(.DW(8),  .DEPTH(5), .OVF(fifo_pkg::OVF_REJECT),    .UNF(fifo_pkg::UNF_ZERO), .NAME("C2")) c2 (.clk(clk), .rst(rst));
    fifo_checker #(.DW(16), .DEPTH(8), .OVF(fifo_pkg::OVF_OVERWRITE), .UNF(fifo_pkg::UNF_HOLD), .DELAY(2), .NAME("C3")) c3 (.clk(clk), .rst(rst));
    fifo_checker #(.DW(8),  .DEPTH(4), .OVF(fifo_pkg::OVF_OVERWRITE), .UNF(fifo_pkg::UNF_ZERO), .NAME("C4")) c4 (.clk(clk), .rst(rst));

    // -------------------------------------------------------------- coverage
    fifo_coverage #(.DEPTH(8), .AFULL(8), .AEMPTY(1), .NAME("V1")) v1 (
        .clk(clk), .sample_en(!rst), .count({28'b0,cnt1}), .wr_busy(wr_s), .rd_busy(rd_s),
        .full(full1), .empty(empty1), .almost_full(afull1), .almost_empty(aempty1),
        .ovf_evt(ovf1), .unf_evt(unf1), .err_clr(clr_s), .wr_ptr({29'b0,dwp1}), .rd_ptr({29'b0,drp1}));
    fifo_coverage #(.DEPTH(5), .AFULL(5), .AEMPTY(1), .NAME("V2")) v2 (
        .clk(clk), .sample_en(!rst), .count({29'b0,cnt2}), .wr_busy(wr_s), .rd_busy(rd_s),
        .full(full2), .empty(empty2), .almost_full(afull2), .almost_empty(aempty2),
        .ovf_evt(ovf2), .unf_evt(unf2), .err_clr(clr_s), .wr_ptr({29'b0,dwp2}), .rd_ptr({29'b0,drp2}));
    fifo_coverage #(.DEPTH(8), .AFULL(6), .AEMPTY(2), .NAME("V3")) v3 (
        .clk(clk), .sample_en(!rst), .count({28'b0,cnt3}), .wr_busy(wr_s), .rd_busy(rd_s),
        .full(full3), .empty(empty3), .almost_full(afull3), .almost_empty(aempty3),
        .ovf_evt(ovf3), .unf_evt(unf3), .err_clr(clr_s), .wr_ptr({29'b0,dwp3}), .rd_ptr({29'b0,drp3}));
    fifo_coverage #(.DEPTH(4), .AFULL(4), .AEMPTY(1), .NAME("V4")) v4 (
        .clk(clk), .sample_en(!rst), .count({29'b0,cnt4}), .wr_busy(wr_s), .rd_busy(rd_s),
        .full(full4), .empty(empty4), .almost_full(afull4), .almost_empty(aempty4),
        .ovf_evt(ovf4), .unf_evt(unf4), .err_clr(clr_s), .wr_ptr({30'b0,dwp4}), .rd_ptr({30'b0,drp4}));

    // ------------------------------------------------------------ TB state
    integer tb_errors = 0;
    integer tv1=0, tv2=0, tv3=0, tv4=0;      // DUT-side presented-word counters
    integer reset_mid_hits = 0;
    integer fwft_lat_ok = 1, lat_u1_ok = 1, lat_u3_ok = 1;

    // one clock cycle: drive strobes for the upcoming edge, sample+check pre-edge
    task automatic cyc(input bit w, input bit r, input logic [15:0] d, input bit clr);
        begin
            wr_s = w; rd_s = r; d_s = d; clr_s = clr;
            #(PERIOD-1);
            // sample & check pre-edge (state@X with strobes@X)
            c1.step_std(w, r, d[15:0], dv1, rd1, ovf1, unf1);
            c3.step_std(w, r, d[15:0], dv3, rd3, ovf3, unf3);
            c2.step_fwft(w, r, d[7:0], dv2, rd2, ovf2, unf2);
            c4.step_fwft(w, r, d[7:0], dv4, rd4, ovf4, unf4);
            if (!rst) begin
                if (dv1) tv1++;
                if (dv3) tv3++;
                if (dv2 && !rd_s) ; // fwft visible words counted on retire below
                if (dv2) tv2++;
                if (dv4) tv4++;
            end
            @(posedge clk); #1;
        end
    endtask

    task automatic do_reset();
        begin
            rst = 1; wr_s = 0; rd_s = 0; clr_s = 0;
            repeat (2) @(posedge clk);
            #1 rst = 0;
            @(posedge clk); #1;
        end
    endtask

    task automatic expect_eq(input integer got, input integer exp, input string what);
        begin
            if (got !== exp) begin
                $display("[%0t] PROBE FAIL: %s got %0d expected %0d", $time, what, got, exp);
                tb_errors++;
            end
        end
    endtask

    integer i, n;
    reg [31:0] lfsr = 32'hACE1_0001;

    function automatic logic [15:0] next_data();
        begin
            lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
            next_data = lfsr[15:8] ^ lfsr[7:0];
        end
    endfunction

    // ============================================================ DIRECTED
    task automatic t_reset_basic;
        begin
            do_reset();
            expect_eq(cnt1, 0, "U1 count after reset");  expect_eq(cnt2, 0, "U2 count");
            expect_eq(cnt3, 0, "U3 count");              expect_eq(cnt4, 0, "U4 count");
            if (empty1 !== 1'b1 || full1 !== 1'b0 || empty2 !== 1'b1 || full2 !== 1'b0 ||
                empty3 !== 1'b1 || full3 !== 1'b0 || empty4 !== 1'b1 || full4 !== 1'b0) begin
                $display("[%0t] PROBE FAIL: flags after reset", $time); tb_errors++;
            end
        end
    endtask

    // pre-edge snapshot with idle strobes: captures registered outputs produced
    // by the PREVIOUS cycle's strobes — same sampling instant the checkers see
    reg snap_dv1, snap_dv3; reg [15:0] snap_rd1, snap_rd3;
    task automatic snap_pre;
        begin
            wr_s = 0; rd_s = 0; clr_s = 0;
            #(PERIOD-1);
            snap_dv1 = dv1; snap_rd1 = rd1;
            snap_dv3 = dv3; snap_rd3 = rd3;
            @(posedge clk); #1;
        end
    endtask

    task automatic t_latency_grid;
        begin
            do_reset();
            // ---- U1 std DELAY=1 : data presented in the cycle after pop strobe
            cyc(1,0,16'hA5,0);
            expect_eq(cnt1,1,"U1 count post-push");
            cyc(0,0,0,0);
            cyc(0,1,0,0);                        // pop strobe @T
            snap_pre();                          // sample state@T+1
            if (snap_dv1 !== 1'b1 || snap_rd1 !== 16'hA5) begin
                $display("PROBE FAIL: U1 DELAY=1 valid/data (@T+1)"); tb_errors++; lat_u1_ok=0;
            end
            snap_pre();                          // @T+2 : single word only
            if (snap_dv1 !== 1'b0) begin $display("PROBE FAIL: U1 valid sticky"); tb_errors++; lat_u1_ok=0; end

            // ---- U3 OUTREG DELAY=2 : data two cycles after pop strobe
            do_reset();
            cyc(1,0,16'h5A,0);
            cyc(0,0,0,0);
            cyc(0,1,0,0);                        // pop strobe @T
            snap_pre();                          // @T+1 : not yet
            if (snap_dv3 !== 1'b0) begin $display("PROBE FAIL: U3 valid early (DELAY=2)"); tb_errors++; lat_u3_ok=0; end
            snap_pre();                          // @T+2 : now
            if (snap_dv3 !== 1'b1 || snap_rd3 !== 16'h5A) begin
                $display("PROBE FAIL: U3 DELAY=2 valid/data"); tb_errors++; lat_u3_ok=0;
            end
            snap_pre();                          // @T+3 : gone
            if (snap_dv3 !== 1'b0) begin $display("PROBE FAIL: U3 valid sticky"); tb_errors++; lat_u3_ok=0; end

            // ---- U2 FWFT: first word visible the cycle AFTER push-on-empty
            do_reset();
            snap_pre();
            if (snap_dv1 !== 1'b0) ;             // sanity only
            cyc(1,0,8'h3C,0);                    // push-on-empty @T
            cyc(0,0,0,0);                        // @T+1: word visible
            if (dv2 !== 1'b1 || rd2 !== 8'h3C) begin
                $display("PROBE FAIL: U2 FWFT first-word latency != 1"); tb_errors++; fwft_lat_ok=0;
            end
            // second word behind it pops through back-to-back
            cyc(1,0,8'hD2,0);                    // push B (cnt=2)
            cyc(0,1,0,0);                        // pop A
            cyc(0,0,0,0);                        // B visible
            if (dv2 !== 1'b1 || rd2 !== 8'hD2) begin $display("PROBE FAIL: U2 FWFT second word"); tb_errors++; fwft_lat_ok=0; end
        end
    endtask

    task automatic t_fill_drain_overflow_underflow;
        reg [15:0] pat;
        begin
            do_reset();
            // fill U1 to FULL
            for (i=0;i<8;i=i+1) cyc(1,0,next_data(),0);
            if (full1 !== 1'b1) begin $display("PROBE FAIL: U1 not full after 8 pushes"); tb_errors++; end
            // overflow attempt (REJECT): event pulses, count unchanged
            cyc(1,0,16'hBAD,0);
            if (cnt1 !== 4'd8 || ovf1 !== 1'b1) begin $display("PROBE FAIL: U1 overflow behaviour"); tb_errors++; end
            // drain all 8 — checker validates order/content incl. that BAD was rejected
            for (i=0;i<8;i=i+1) cyc(0,1,0,0);
            if (empty1 !== 1'b1) begin $display("PROBE FAIL: U1 not empty after drain"); tb_errors++; end
            // underflow (HOLD): event pulses, no pointer move
            cyc(0,1,0,0);
            if (cnt1 !== 4'd0 || unf1 !== 1'b1) begin $display("PROBE FAIL: U1 underflow behaviour"); tb_errors++; end

            // U3 OVERWRITE semantics at full: oldest replaced, count stays DEPTH
            do_reset();
            for (i=0;i<8;i=i+1) cyc(1,0,i[15:0]+1,0);       // stores 1..8
            cyc(1,0,16'h9,0);                               // overwrites oldest (1)
            if (cnt3 !== 4'd8) begin $display("PROBE FAIL: U3 overwrite count"); tb_errors++; end
            for (i=0;i<8;i=i+1) cyc(0,1,0,0);               // drain: expect 2..8,9 order via C3
            if (empty3 !== 1'b1) begin $display("PROBE FAIL: U3 drain"); tb_errors++; end
        end
    endtask

    task automatic t_simultaneous_corners;
        begin
            // CC-03 full + both -> pop wins (net -1)
            do_reset();
            for (i=0;i<8;i=i+1) cyc(1,0,next_data(),0);
            cyc(1,1,next_data(),0);
            expect_eq(cnt1, 7, "CC-03 U1 net -1");
            // CC-04 empty + both -> push wins (net +1)
            do_reset();
            cyc(1,1,16'h77,0);
            expect_eq(cnt1, 1, "CC-04 U1 net +1");
            // CC-05 mid + both sustained (also feeds throughput evidence)
            for (i=0;i<20;i=i+1) cyc(1,1,next_data(),0);
            expect_eq(cnt1, 1, "CC-05 U1 steady occupancy");
        end
    endtask

    task automatic t_wrap;
        begin
            do_reset();
            n = 6*8+3;
            for (i=0;i<n;i=i+1) cyc(1,0,next_data(),0);          // writer-only wraps
            for (i=0;i<n;i=i+1) cyc(0,1,0,0);                    // drain wraps reader too
            // non-pow2 DUTs exercised heavily by random phase as well
        end
    endtask

    task automatic t_thresholds;
        begin
            do_reset();
            // U3: AFULL=6 AEMPTY=2 exact boundary walk
            for (i=0;i<=8;i=i+1) begin
                if (i>0) cyc(1,0,next_data(),0);
                else     cyc(0,0,0,0);
                if (afull3 !== (i>=6)) begin $display("PROBE FAIL: U3 almost_full @%0d", i); tb_errors++; end
                if (aempty3 !== (i<=2)) begin $display("PROBE FAIL: U3 almost_empty @%0d", i); tb_errors++; end
            end
            // defaults: AFULL=DEPTH => almost_full==full ; AEMPTY=1
            if (afull1 !== full1) begin $display("PROBE FAIL: U1 default AFULL"); tb_errors++; end
            if (aempty1 !== (cnt1 <= 1)) begin $display("PROBE FAIL: U1 default AEMPTY"); tb_errors++; end
        end
    endtask

    task automatic t_stats_sticky;
        begin
            do_reset();
            // overflow ×3 on U1 then inspect counters/sticky
            for (i=0;i<8;i=i+1) cyc(1,0,next_data(),0);
            for (i=0;i<3;i=i+1) cyc(1,0,next_data(),0);
            expect_eq(oc1, 3, "U1 ovf_count");
            if (os1 !== 1'b1) begin $display("PROBE FAIL: U1 ovf_sticky"); tb_errors++; end
            cyc(0,0,0,1);                        // clear
            if (os1 !== 1'b0) begin $display("PROBE FAIL: U1 sticky clear"); tb_errors++; end
            // CC-11 race: clear coincident with fresh event keeps sticky set
            cyc(1,0,next_data(),1);
            if (os1 !== 1'b1) begin $display("PROBE FAIL: CC-11 sticky race"); tb_errors++; end
            cyc(0,0,0,1);
            if (os1 !== 1'b0) begin $display("PROBE FAIL: sticky clear 2"); tb_errors++; end
            // underflow counter on U2 (ZERO policy)
            do_reset();
            cyc(0,1,0,0); cyc(0,1,0,0);
            expect_eq(uc2, 2, "U2 unf_count");
            if (dv2 !== 1'b0 || rd2 !== 8'h00) begin $display("PROBE FAIL: U2 ZERO-policy read-while-empty"); tb_errors++; end
        end
    endtask

    task automatic t_throughput;
        integer b1, b2, b3, b4;
        begin
            do_reset();
            // pre-fill to mid so simultaneous streaming is stall-free
            for (i=0;i<4;i=i+1) cyc(1,0,next_data(),0);
            b1=c1.retires; b2=c2.retires; b3=c3.retires; b4=c4.retires;
            n = 32;
            for (i=0;i<n;i=i+1) begin
                cyc(1,1,next_data(),0);
                if (ovf1 || unf1) begin
                    $display("PROBE FAIL: event during throughput streaming"); tb_errors++;
                end
            end
            // sustained 1 accepted pop/cycle on every DUT across the window
            expect_eq(c1.retires-b1, n, "U1 retire rate 1/cycle");
            expect_eq(c2.retires-b2, n, "U2 retire rate 1/cycle");
            expect_eq(c3.retires-b3, n, "U3 retire rate 1/cycle");
            expect_eq(c4.retires-b4, n, "U4 retire rate 1/cycle");
            expect_eq(cnt1, 4, "U1 occupancy constant across stream");
        end
    endtask

    task automatic t_debug_parity;
        begin
            if (dwp1 !== u1.wr_addr_q || drp1 !== u1.rd_addr_q ||
                dwp3 !== u3.wr_addr_q[2:0] || drp3 !== u3.rd_addr_q[2:0]) begin
                $display("PROBE FAIL: debug pointer parity"); tb_errors++;
            end
        end
    endtask

    task automatic t_peak_watermark;
        begin
            do_reset();
            for (i=0;i<8;i=i+1) cyc(1,0,next_data(),0);
            expect_eq(pk1, 8, "U1 peak==DEPTH after fill");
            cyc(0,1,0,0);
            expect_eq(pk1, 8, "U1 peak retains high-watermark");
        end
    endtask

    // ============================================================ RANDOM
    task automatic t_random(input integer ncyc);
        integer k;
        reg [3:0] dice;
        begin
            do_reset();
            for (k=0;k<ncyc;k=k+1) begin
                lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
                dice = lfsr[15:12];
                cyc(lfsr[3] | lfsr[4], lfsr[5] | lfsr[6], next_data(),
                    (dice == 4'd7));                      // occasional error_clear
                if (dice == 4'd15) begin                  // rare mid-stream reset
                    do_reset();
                    reset_mid_hits++;
                end
            end
            // final drain to empty on all DUTs
            repeat (40) cyc(0,1,0,0);
        end
    endtask

    // ============================================================ REPORT
    integer total_err;
    task automatic report_and_finish;
        integer e1,e2,e3,e4;
        integer occ0,occ1b,occmid,occdm1,occfull;
        integer wrap_w,wrap_r,simul_f,simul_e,simul_m;
        integer ovfh,unfh,thru,thrd,afl,aem,race,bpm;
        begin
            e1=c1.err_count(); e2=c2.err_count(); e3=c3.err_count(); e4=c4.err_count();
            $display("CHECKER C1 errors=%0d", e1);
            $display("CHECKER C2 errors=%0d", e2);
            $display("CHECKER C3 errors=%0d", e3);
            $display("CHECKER C4 errors=%0d", e4);

            occ0=v1.occ0+v2.occ0+v3.occ0+v4.occ0;
            occ1b=v1.occ1+v2.occ1+v3.occ1+v4.occ1;
            occmid=v1.occmid+v2.occmid+v3.occmid+v4.occmid;
            occdm1=v1.occdm1+v2.occdm1+v3.occdm1+v4.occdm1;
            occfull=v1.occfull+v2.occfull+v3.occfull+v4.occfull;
            wrap_w=v1.wrap_w+v2.wrap_w+v3.wrap_w+v4.wrap_w;
            wrap_r=v1.wrap_r+v2.wrap_r+v3.wrap_r+v4.wrap_r;
            simul_f=v1.simul_full+v2.simul_full+v3.simul_full+v4.simul_full;
            simul_e=v1.simul_empty+v2.simul_empty+v3.simul_empty+v4.simul_empty;
            simul_m=v1.simul_mid+v2.simul_mid+v3.simul_mid+v4.simul_mid;
            ovfh=v1.ovf_hits+v2.ovf_hits+v3.ovf_hits+v4.ovf_hits;
            unfh=v1.unf_hits+v2.unf_hits+v3.unf_hits+v4.unf_hits;
            thru=v1.thr_up+v2.thr_up+v3.thr_up+v4.thr_up;
            thrd=v1.thr_dn+v2.thr_dn+v3.thr_dn+v4.thr_dn;
            afl=v1.afull_hits+v2.afull_hits+v3.afull_hits+v4.afull_hits;
            aem=v1.aempty_hits+v2.aempty_hits+v3.aempty_hits+v4.aempty_hits;
            race=v1.errclr_race+v2.errclr_race+v3.errclr_race+v4.errclr_race;
            bpm=(v1.bp_max>v2.bp_max)?v1.bp_max:v2.bp_max;
            if (v3.bp_max>bpm) bpm=v3.bp_max;
            if (v4.bp_max>bpm) bpm=v4.bp_max;

            $display("COVER: occ0 %0d", occ0);
            $display("COVER: occ1 %0d", occ1b);
            $display("COVER: occmid %0d", occmid);
            $display("COVER: occdepthm1 %0d", occdm1);
            $display("COVER: occfull %0d", occfull);
            $display("COVER: wrap_write %0d", wrap_w);
            $display("COVER: wrap_read %0d", wrap_r);
            $display("COVER: simul_full %0d", simul_f);
            $display("COVER: simul_empty %0d", simul_e);
            $display("COVER: simul_mid %0d", simul_m);
            $display("COVER: overflow_events %0d", ovfh);
            $display("COVER: underflow_events %0d", unfh);
            $display("COVER: threshold_cross_up %0d", thru);
            $display("COVER: threshold_cross_dn %0d", thrd);
            $display("COVER: almost_full_asserts %0d", afl);
            $display("COVER: almost_empty_asserts %0d", aem);
            $display("COVER: errclear_race %0d", race);
            $display("COVER: bp_max_streak %0d", bpm);
            $display("COVER: reset_midstream %0d", reset_mid_hits);

            total_err = tb_errors + e1 + e2 + e3 + e4;

            // mandatory-bin gate (waivers: 32-bit counter saturation — see report)
            if (occ0==0||occ1b==0||occmid==0||occdm1==0||occfull==0||
                wrap_w==0||wrap_r==0||simul_f==0||simul_e==0||simul_m==0||
                ovfh==0||unfh==0||thru==0||thrd==0||race==0||reset_mid_hits==0||
                bpm < 4) begin
                $display("RESULT: FAIL (coverage bins incomplete)");
            end else if (lat_u1_ok==0 || lat_u3_ok==0 || fwft_lat_ok==0) begin
                $display("RESULT: FAIL (latency grid)");
            end else if (total_err != 0) begin
                $display("RESULT: FAIL (%0d errors)", total_err);
            end else begin
                $display("RESULT: PASS");
            end
            $finish;
        end
    endtask

    // ============================================================ SEQUENCER
    integer seed_set = 1;
    integer ncyc = 3000;
    initial begin
        void'($value$plusargs("SEED=%d", seed_set));
        void'($value$plusargs("NCYC=%d", ncyc));
        lfsr = 32'hACE1_0001 ^ seed_set;
        $display("tb_sync_fifo: SEED=%0d NCYC=%0d", seed_set, ncyc);

        t_reset_basic();
        t_latency_grid();
        t_fill_drain_overflow_underflow();
        t_simultaneous_corners();
        t_wrap();
        t_thresholds();
        t_stats_sticky();
        t_throughput();
        t_peak_watermark();
        t_debug_parity();
        t_random(ncyc);
        t_debug_parity();

        report_and_finish();
    end

endmodule : tb_sync_fifo

`default_nettype wire
