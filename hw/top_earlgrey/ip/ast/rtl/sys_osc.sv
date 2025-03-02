// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//############################################################################
// *Name: sys_osc
// *Module Description: System Clock Oscilator
//############################################################################

module sys_osc (
  input vcore_pok_h_i,    // VCORE POK @3.3V
  input sys_en_i,         // System Source Clock Enable
  input sys_jen_i,        // System Source Clock Jitter Enable
  input sys_osc_cal_i,    // System Oscillator Calibrated
`ifdef AST_BYPASS_CLK
  input clk_sys_ext_i,    // FPGA/VERILATOR Clock input
`endif
  output logic sys_clk_o  // System Clock Output
);

`ifndef AST_BYPASS_CLK
`ifndef SYNTHESIS
// Behavioral Model
////////////////////////////////////////
timeunit  1ns / 1ps;
import ast_bhv_pkg::* ;

real CLK_PERIOD;

reg init_start;
initial init_start = 1'b0;

initial begin
  #1; init_start  = 1'b1;
  $display("\nSystem Power-up Clock Frequency: %0d Hz", $rtoi(10**9/CLK_PERIOD));
end

// Enable 5us RC Delay on rise
wire en_osc_re_buf, en_osc_re, sys_jen;
buf #(SYS_EN_RDLY, 0) b0 (en_osc_re_buf, (vcore_pok_h_i && sys_en_i));
assign en_osc_re = en_osc_re_buf && init_start;
assign sys_jen = sys_jen_i && en_osc_re_buf && init_start;

// Clock Oscillator
////////////////////////////////////////
real CalSysClkPeriod, UncSysClkPeriod, SysClkPeriod, jitter;

initial CalSysClkPeriod = $itor( 10000 );                         // 10000ps (100MHz)
initial UncSysClkPeriod = $itor( $urandom_range(40000, 16667) );  // 40000-16667ps (25-60MHz)

assign SysClkPeriod = (sys_osc_cal_i && init_start) ? CalSysClkPeriod : UncSysClkPeriod;
assign CLK_PERIOD = (SysClkPeriod + jitter)/1000;

// Free running oscillator
reg clk_osc;
initial clk_osc = 1'b1;

always begin
  // 0-2000ps is upto +20% Jitter
  jitter = sys_jen ? $itor($urandom_range(2000, 0)) : 0.0;
  #(CLK_PERIOD/2) clk_osc = ~clk_osc;
end

logic en_osc;

// HDL Clock Gate
logic en_clk, clk;

always_latch begin
  if ( !clk_osc ) en_clk <= en_osc;
end

assign clk = clk_osc && en_clk;
`else  // of SYBTHESIS
// SYNTHESIS/LINTER
///////////////////////////////////////
logic en_osc_re;
assign en_osc_re = vcore_pok_h_i && sys_en_i;

logic clk, en_osc;
assign clk = 1'b0;
`endif  // of SYBTHESIS
`else  // of AST_BYPASS_CLK
// VERILATOR/FPGA
///////////////////////////////////////
logic en_osc_re;
assign en_osc_re = vcore_pok_h_i && sys_en_i;

// Clock Oscillator
////////////////////////////////////////
logic clk, en_osc;

prim_clock_gating #(
  .NoFpgaGate ( 1'b1 )
) u_clk_ckgt (
  .clk_i ( clk_sys_ext_i ),
  .en_i ( en_osc ),
  .test_en_i ( 1'b0 ),
  .clk_o ( clk )
);
`endif

logic en_osc_fe;

// Syncronize en_osc to clk FE for glitch free disable
always_ff @( negedge clk, negedge vcore_pok_h_i ) begin
  if ( !vcore_pok_h_i ) begin
    en_osc_fe <= 1'b0;
  end else begin
    en_osc_fe <= en_osc_re;
  end
end

assign en_osc = en_osc_re || en_osc_fe;  // EN -> 1 || EN -> 0

// Clock Output Buffer
////////////////////////////////////////
prim_clock_buf #(
  .NoFpgaBuf ( 1'b1 )
) u_buf (
  .clk_i ( clk ),
  .clk_o ( sys_clk_o )
);


`ifdef SYNTHESIS
/////////////////////////
// Unused Signals
/////////////////////////
logic unused_sigs;
assign unused_sigs = ^{ sys_osc_cal_i, sys_jen_i };
`endif

endmodule : sys_osc
