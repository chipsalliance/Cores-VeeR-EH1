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

module dec_gpr_ctl #(parameter GPR_BANKS      = 1,
                               GPR_BANKS_LOG2 = 1)  (
    input logic active_clk,

    input logic [4:0] raddr0,  // logical read addresses
    input logic [4:0] raddr1,
    input logic [4:0] raddr2,
    input logic [4:0] raddr3,

    input logic       rden0,   // read enables
    input logic       rden1,
    input logic       rden2,
    input logic       rden3,

    input logic [4:0] waddr0,  // logical write addresses
    input logic [4:0] waddr1,
    input logic [4:0] waddr2,

    input logic wen0,          // write enables
    input logic wen1,
    input logic wen2,

    input logic [31:0] wd0,    // write data
    input logic [31:0] wd1,
    input logic [31:0] wd2,

    input logic                      wen_bank_id,  // write enable for banks
    input logic [GPR_BANKS_LOG2-1:0] wr_bank_id,   // read enable for banks

    input logic       clk,
    input logic       rst_l,

    output logic [31:0] rd0,  // read data
    output logic [31:0] rd1,
    output logic [31:0] rd2,
    output logic [31:0] rd3,

    input  logic        scan_mode
);

   logic [GPR_BANKS-1:0][31:1] [31:0] gpr_out;     // 31 x 32 bit GPRs
   logic [31:1] [31:0] gpr_in;
   logic [31:1] w0v,w1v,w2v;
   logic [31:1] gpr_wr_en;
   logic [GPR_BANKS-1:0][31:1] gpr_bank_wr_en;
   logic [GPR_BANKS_LOG2-1:0] gpr_bank_id;

   //assign gpr_bank_id[GPR_BANKS_LOG2-1:0] = '0;
   rvdffs #(GPR_BANKS_LOG2) bankid_ff (.*, .clk(active_clk), .en(wen_bank_id), .din(wr_bank_id[GPR_BANKS_LOG2-1:0]), .dout(gpr_bank_id[GPR_BANKS_LOG2-1:0]));

   // GPR Write Enables for power savings
   assign gpr_wr_en[31:1] = (w0v[31:1] | w1v[31:1] | w2v[31:1]);
   for (genvar i=0; i<GPR_BANKS; i++) begin: gpr_banks
      assign gpr_bank_wr_en[i][31:1] = gpr_wr_en[31:1] & {31{gpr_bank_id[GPR_BANKS_LOG2-1:0] == i}};
      for ( genvar j=1; j<32; j++ )  begin : gpr
         rvdffe #(32) gprff (.*, .en(gpr_bank_wr_en[i][j]), .din(gpr_in[j][31:0]), .dout(gpr_out[i][j][31:0]));
      end : gpr
   end: gpr_banks

// the read out
   always_comb begin
      rd0[31:0] = 32'b0;
      rd1[31:0] = 32'b0;
      rd2[31:0] = 32'b0;
      rd3[31:0] = 32'b0;
      w0v[31:1] = 31'b0;
      w1v[31:1] = 31'b0;
      w2v[31:1] = 31'b0;
      gpr_in[31:1] = '0;

      // GPR Read logic
      for (int i=0; i<GPR_BANKS; i++) begin
         for (int j=1; j<32; j++ )  begin
            rd0[31:0] |= ({32{rden0 & (raddr0[4:0]== 5'(j)) & (gpr_bank_id[GPR_BANKS_LOG2-1:0] == 1'(i))}} & gpr_out[i][j][31:0]);
            rd1[31:0] |= ({32{rden1 & (raddr1[4:0]== 5'(j)) & (gpr_bank_id[GPR_BANKS_LOG2-1:0] == 1'(i))}} & gpr_out[i][j][31:0]);
            rd2[31:0] |= ({32{rden2 & (raddr2[4:0]== 5'(j)) & (gpr_bank_id[GPR_BANKS_LOG2-1:0] == 1'(i))}} & gpr_out[i][j][31:0]);
            rd3[31:0] |= ({32{rden3 & (raddr3[4:0]== 5'(j)) & (gpr_bank_id[GPR_BANKS_LOG2-1:0] == 1'(i))}} & gpr_out[i][j][31:0]);
        end
     end

     // GPR Write logic
     for (int j=1; j<32; j++ )  begin
         w0v[j]     = wen0  & (waddr0[4:0]== 5'(j) );
         w1v[j]     = wen1  & (waddr1[4:0]== 5'(j) );
         w2v[j]     = wen2  & (waddr2[4:0]== 5'(j) );
         gpr_in[j]  =    ({32{w0v[j]}} & wd0[31:0]) |
                         ({32{w1v[j]}} & wd1[31:0]) |
                         ({32{w2v[j]}} & wd2[31:0]);
     end
   end // always_comb begin

`ifdef ASSERT_ON
   // asserting that no 2 ports will write to the same gpr simultaneously
   assert_multiple_wen_to_same_gpr: assert #0 (~( ((w0v[31:1] == w1v[31:1]) & wen0 & wen1) | ((w0v[31:1] == w2v[31:1]) & wen0 & wen2) | ((w1v[31:1] == w2v[31:1]) & wen1 & wen2) ) );

`endif

endmodule
