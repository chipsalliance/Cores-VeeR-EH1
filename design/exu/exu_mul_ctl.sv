// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


module exu_mul_ctl
   import swerv_types::*;
(
   input logic         clk,              // Top level clock
   input logic         active_clk,       // Level 1 active clock
   input logic         clk_override,     // Override clock enables
   input logic         rst_l,            // Reset
   input logic         scan_mode,        // Scan mode

   input logic [31:0]  a,                // A operand
   input logic [31:0]  b,                // B operand

   input logic [31:0]  lsu_result_dc3,   // Load result used in E1 bypass

   input logic         freeze,           // Pipeline freeze

   input mul_pkt_t     mp,               // valid, rs1_sign, rs2_sign, low, load_mul_rs1_bypass_e1, load_mul_rs2_bypass_e1


   output logic [31:0] out               // Result

   );


   logic                valid_e1, valid_e2;
   logic                mul_c1_e1_clken,   mul_c1_e2_clken,   mul_c1_e3_clken;
   logic                exu_mul_c1_e1_clk, exu_mul_c1_e2_clk, exu_mul_c1_e3_clk;

   logic        [31:0]  a_ff_e1, a_e1;
   logic        [31:0]  b_ff_e1, b_e1;
   logic                load_mul_rs1_bypass_e1, load_mul_rs2_bypass_e1;
   logic                rs1_sign_e1, rs1_neg_e1;
   logic                rs2_sign_e1, rs2_neg_e1;
   logic signed [32:0]  a_ff_e2, b_ff_e2;
   logic        [63:0]  prod_e3;
   logic                low_e1, low_e2, low_e3;


   // --------------------------- Clock gating   ----------------------------------

   // C1 clock enables
   assign mul_c1_e1_clken        = (mp.valid | clk_override) & ~freeze;
   assign mul_c1_e2_clken        = (valid_e1 | clk_override) & ~freeze;
   assign mul_c1_e3_clken        = (valid_e2 | clk_override) & ~freeze;

`ifndef RV_FPGA_OPTIMIZE
   // C1 - 1 clock pulse for data
   rvclkhdr exu_mul_c1e1_cgc     (.*, .en(mul_c1_e1_clken),   .l1clk(exu_mul_c1_e1_clk));   // ifndef FPGA_OPTIMIZE
   rvclkhdr exu_mul_c1e2_cgc     (.*, .en(mul_c1_e2_clken),   .l1clk(exu_mul_c1_e2_clk));   // ifndef FPGA_OPTIMIZE
   rvclkhdr exu_mul_c1e3_cgc     (.*, .en(mul_c1_e3_clken),   .l1clk(exu_mul_c1_e3_clk));   // ifndef FPGA_OPTIMIZE
`endif


   // --------------------------- Input flops    ----------------------------------

   rvdffs      #(1)  valid_e1_ff      (.*, .din(mp.valid),                  .dout(valid_e1),               .clk(active_clk),        .en(~freeze));

   rvdff_fpga  #(1)  rs1_sign_e1_ff   (.*, .din(mp.rs1_sign),               .dout(rs1_sign_e1),            .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  rs2_sign_e1_ff   (.*, .din(mp.rs2_sign),               .dout(rs2_sign_e1),            .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  low_e1_ff        (.*, .din(mp.low),                    .dout(low_e1),                 .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  ld_rs1_byp_e1_ff (.*, .din(mp.load_mul_rs1_bypass_e1), .dout(load_mul_rs1_bypass_e1), .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  ld_rs2_byp_e1_ff (.*, .din(mp.load_mul_rs2_bypass_e1), .dout(load_mul_rs2_bypass_e1), .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));

   rvdffe  #(32) a_e1_ff          (.*, .din(a[31:0]),                   .dout(a_ff_e1[31:0]),          .en(mul_c1_e1_clken));
   rvdffe  #(32) b_e1_ff          (.*, .din(b[31:0]),                   .dout(b_ff_e1[31:0]),          .en(mul_c1_e1_clken));



   // --------------------------- E1 Logic Stage ----------------------------------

   assign a_e1[31:0]             = (load_mul_rs1_bypass_e1)  ?  lsu_result_dc3[31:0]  :  a_ff_e1[31:0];
   assign b_e1[31:0]             = (load_mul_rs2_bypass_e1)  ?  lsu_result_dc3[31:0]  :  b_ff_e1[31:0];

   assign rs1_neg_e1             =  rs1_sign_e1 & a_e1[31];
   assign rs2_neg_e1             =  rs2_sign_e1 & b_e1[31];


   rvdffs       #(1)  valid_e2_ff      (.*, .din(valid_e1),                  .dout(valid_e2),          .clk(active_clk),        .en(~freeze));

   rvdff_fpga   #(1)    low_e2_ff      (.*, .din(low_e1),                    .dout(low_e2),            .clk(exu_mul_c1_e2_clk), .clken(mul_c1_e2_clken), .rawclk(clk));

   rvdffe  #(33) a_e2_ff          (.*, .din({rs1_neg_e1, a_e1[31:0]}),  .dout(a_ff_e2[32:0]),          .en(mul_c1_e2_clken));
   rvdffe  #(33) b_e2_ff          (.*, .din({rs2_neg_e1, b_e1[31:0]}),  .dout(b_ff_e2[32:0]),          .en(mul_c1_e2_clken));



   // ---------------------- E2 Logic Stage --------------------------


   logic signed [65:0]  prod_e2;

   assign prod_e2[65:0]          =  a_ff_e2  *  b_ff_e2;

   rvdff_fpga  #(1)    low_e3_ff      (.*, .din(low_e2),                    .dout(low_e3),                 .clk(exu_mul_c1_e3_clk), .clken(mul_c1_e3_clken), .rawclk(clk));

   rvdffe      #(64) prod_e3_ff       (.*, .din(prod_e2[63:0]),             .dout(prod_e3[63:0]),          .en(mul_c1_e3_clken));



   // ----------------------- E3 Logic Stage -------------------------


   assign out[31:0]            = low_e3  ?  prod_e3[31:0]  :  prod_e3[63:32];


endmodule // exu_mul_ctl
