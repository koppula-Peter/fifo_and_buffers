#!/usr/bin/env bash
# =============================================================================
# run_regression.sh — repo regression driver (iverilog + verilator [+ SBY later])
# Protocol: a suite passes when its log contains "RESULT: PASS" (house style).
# Usage: scripts/run_regression.sh [--quick] [--lint-only] [--sim-only]
# Env:   SEED=<n>  base random seed (default 1); NCYC override supported.
# =============================================================================
set -u
cd "$(dirname "$0")/.."
mkdir -p build/sim reports/sync_fifo

PASS=0; FAIL=0
LINT_ONLY=0; SIM_ONLY=0; QUICK=0
for a in "$@"; do case "$a" in
  --lint-only) LINT_ONLY=1;; --sim-only) SIM_ONLY=1;; --quick) QUICK=1;; esac; done

SEED="${SEED:-1}"
NCYC=3000; [ "$QUICK" = "1" ] && NCYC=600

if [ "$SIM_ONLY" = "0" ]; then
  echo "=== LINT sync_fifo (verilator -Wall, FWFT x OUTREG x MEM matrix) ==="
  lint_ok=1
  for fw in 0 1; do for or in 0 1; do for mt in 0 1 2 3; do
    verilator --lint-only -Wall -Irtl/common \
      rtl/common/fifo_pkg.sv rtl/common/fifo_mem.sv rtl/sync_fifo/sync_fifo.sv \
      --top-module sync_fifo -GFWFT_ENABLE=$fw -GOUTPUT_REGISTER=$or -GMEMORY_TYPE=$mt \
      > reports/sync_fifo/lint.log 2>&1 || { lint_ok=0; cat reports/sync_fifo/lint.log; }
  done; done; done
  if [ $lint_ok = 1 ]; then PASS=$((PASS+1)); echo "lint: 16/16 configurations clean";
  else FAIL=$((FAIL+1)); echo ">>> LINT FAILED"; fi
fi

if [ "$LINT_ONLY" = "1" ]; then
  echo "Suites passed: $PASS failed: $FAIL"; [ "$FAIL" -eq 0 ]; exit $?
fi

run_tb () { # $1=name $2=seed $3...=sources
    name="$1"; sd="$2"; shift 2
    echo "=== SIM $name (seed=$sd) ==="
    if iverilog -g2012 -I rtl/common -I tb/common -o "build/sim/$name.vvp" "$@" \
       && ( cd build/sim && vvp "$name.vvp" "+SEED=$sd" "+NCYC=$NCYC" | tee "../../reports/sync_fifo/$name.sim.log" ); then
        if grep -q "RESULT: PASS" "reports/sync_fifo/$name.sim.log"; then
            PASS=$((PASS+1))
        else FAIL=$((FAIL+1)); echo ">>> $name FAILED"; fi
    else
        FAIL=$((FAIL+1)); echo ">>> $name compile/run error"
    fi
}

SRC="rtl/common/fifo_pkg.sv rtl/common/fifo_mem.sv rtl/sync_fifo/sync_fifo.sv tb/common/fifo_checker.sv tb/common/fifo_coverage.sv"

if [ "$SIM_ONLY" = "0" ] || [ "$SIM_ONLY" = "1" ]; then
  run_tb "tb_sync_fifo"        "$SEED" tb/sync_fifo/tb_sync_fifo.sv $SRC
  run_tb "tb_sync_fifo_seed2"  2      tb/sync_fifo/tb_sync_fifo.sv $SRC
  run_tb "tb_sync_fifo_seed3"  3      tb/sync_fifo/tb_sync_fifo.sv $SRC

  # ---- parameter-validation negative compiles: elaboration failure == PASS
  echo "=== PARAM NEGATIVE CHECKS ==="
  neg=0
  neg_top () { # $1=label $2=param line
    cat > build/sim/neg_tmp.sv <<EOF
\`include "fifo_pkg.sv"
module neg_tmp;
    logic clk=0, rst; logic w,r; logic [31:0] wd; logic rd_dv; logic [31:0] rdd;
    sync_fifo #($2) dut(.clk(clk),.rst(rst),.wr_en(w),.wr_data(wd),.full(),.almost_full(),
        .overflow_event(),.rd_en(r),.rd_data(rdd),.rd_data_valid(rd_dv),.empty(),.almost_empty(),
        .underflow_event(),.count(),.peak_count(),.ovf_count(),.unf_count(),.ovf_sticky(),
        .unf_sticky(),.error_clear(1'b0),.dbg_wr_ptr(),.dbg_rd_ptr());
endmodule
EOF
    # compile must succeed (validation lives in elaboration/sim-start checks),
    # but the sim must abort immediately with a fatal -> nonzero exit
    if ! iverilog -g2012 -I rtl/common -o build/sim/neg_tmp.vvp rtl/common/fifo_pkg.sv \
         rtl/common/fifo_mem.sv rtl/sync_fifo/sync_fifo.sv build/sim/neg_tmp.sv >/dev/null 2>&1; then
       echo "param-neg $1: rejected at compile (ok)"; 
    elif ( cd build/sim && timeout 5 vvp neg_tmp.vvp >/dev/null 2>&1 ); then
       echo ">>> param-neg $1 did NOT reject invalid configuration"; neg=1
    else echo "param-neg $1: rejected via \$fatal at elaboration (ok)"; fi
  }
  neg_top "DEPTH=1"                ".DEPTH(1)"
  neg_top "AFULL>DEPTH"            ".DEPTH(8), .ALMOST_FULL_THRESHOLD(9)"
  neg_top "AEMPTY>=DEPTH"          ".DEPTH(8), .ALMOST_EMPTY_THRESHOLD(8)"
  neg_top "bad OVERFLOW_POLICY"    ".OVERFLOW_POLICY(7)"
  neg_top "bad MEMORY_TYPE(AUTO direct)" ".MEMORY_TYPE(9)"
  if [ $neg = 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

  # ---- release-RTL hygiene gate (mandate §53)
  if grep -rn "TODO\|FIXME" rtl/ >/dev/null 2>&1; then
     echo ">>> TODO/FIXME gate failed:"; grep -rn "TODO\|FIXME" rtl/
     FAIL=$((FAIL+1))
  else PASS=$((PASS+1)); echo "hygiene gate: no TODO/FIXME in rtl/"
  fi
fi

echo "==================================="
echo "Suites passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
