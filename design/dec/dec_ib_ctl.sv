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

module dec_ib_ctl
   import swerv_types::*;
(
   input logic   free_clk,                    // free clk
   input logic   active_clk,                  // active clk if not halt / pause

   input logic                 dbg_cmd_valid,  // valid dbg cmd

   input logic                 dbg_cmd_write,  // dbg cmd is write
   input logic [1:0]           dbg_cmd_type,   // dbg type
   input logic [1:0]           dbg_cmd_size,   // 00 - 1B, 01 - 2B, 10 - 4B, 11 - reserved
   input logic [31:0]          dbg_cmd_addr,   // expand to 31:0

   input logic exu_flush_final,                // all flush sources: primary/secondary alu's, trap

   input logic          dec_ib0_valid_eff_d,   // effective valid taking decode into account
   input logic          dec_ib1_valid_eff_d,

   input br_pkt_t i0_brp,                      // i0 branch packet from aligner
   input br_pkt_t i1_brp,

   input logic   ifu_i0_pc4,                   // i0 is 4B inst else 2B
   input logic   ifu_i1_pc4,

   input logic   ifu_i0_valid,                 // i0 valid from ifu
   input logic   ifu_i1_valid,

   input logic   ifu_i0_icaf,                  // i0 instruction access fault
   input logic   ifu_i1_icaf,
   input logic   ifu_i0_icaf_second,               // i0 has access fault on second 2B of 4B inst
   input logic   ifu_i1_icaf_second,
   input logic   ifu_i0_perr,                  // i0 instruction parity error
   input logic   ifu_i1_perr,
   input logic   ifu_i0_sbecc,                 // i0 single-bit error
   input logic   ifu_i1_sbecc,
   input logic   ifu_i0_dbecc,                 // i0 double-bit error
   input logic   ifu_i1_dbecc,

   input logic [31:0]  ifu_i0_instr,           // i0 instruction from the aligner
   input logic [31:0]  ifu_i1_instr,

   input logic [31:1]  ifu_i0_pc,              // i0 pc from the aligner
   input logic [31:1] ifu_i1_pc,

   input logic   dec_i0_decode_d,              // i0 decode
   input logic   dec_i1_decode_d,


   input logic   rst_l,                        // test stuff
   input logic   clk,


   output logic dec_ib3_valid_d,               // ib3 valid
   output logic dec_ib2_valid_d,               // ib2 valid
   output logic dec_ib1_valid_d,               // ib1 valid
   output logic dec_ib0_valid_d,               // ib0 valid


   output logic [31:0] dec_i0_instr_d,         // i0 inst at decode
   output logic [31:0] dec_i1_instr_d,         // i1 inst at decode

   output logic [31:1] dec_i0_pc_d,            // i0 pc at decode
   output logic [31:1] dec_i1_pc_d,

   output logic dec_i0_pc4_d,                  // i0 is 4B inst else 2B
   output logic dec_i1_pc4_d,

   output br_pkt_t dec_i0_brp,                 // i0 branch packet at decode
   output br_pkt_t dec_i1_brp,

   output logic dec_i0_icaf_d,                 // i0 instruction access fault at decode
   output logic dec_i1_icaf_d,
   output logic dec_i0_icaf_second_d,              // i0 instruction access fault on second 2B of 4B inst
   output logic dec_i0_perr_d,                 // i0 instruction parity error at decode
   output logic dec_i1_perr_d,
   output logic dec_i0_sbecc_d,                // i0 single-bit error at decode
   output logic dec_i1_sbecc_d,
   output logic dec_i0_dbecc_d,                // i0 double-bit error at decode
   output logic dec_i1_dbecc_d,
   output logic dec_debug_wdata_rs1_d,         // put debug write data onto rs1 source: machine is halted

   output logic dec_debug_fence_d,             // debug fence inst

   input logic [15:0] ifu_i0_cinst,            // 16b compressed inst from aligner
   input logic [15:0] ifu_i1_cinst,

   output logic [15:0] dec_i0_cinst_d,         // 16b compress inst at decode
   output logic [15:0] dec_i1_cinst_d,

   input  logic scan_mode

   );

`include "global.h"

   logic         flush_final;

   logic [3:0]   ibval_in, ibval;

   logic [31:0]  ib3_in, ib2_in, ib1_in, ib0_in;
   logic [31:0]  ib3, ib2, ib1, ib0;

   logic [36:0]  pc3_in, pc2_in, pc1_in, pc0_in;
   logic [36:0]  pc3, pc2, pc1, pc0;

   logic [15:0]  cinst3_in, cinst2_in, cinst1_in, cinst0_in;
   logic [15:0]  cinst3, cinst2, cinst1, cinst0;

   logic         write_i1_ib3, write_i0_ib3;
   logic         write_i1_ib2, write_i0_ib2;
   logic         write_i1_ib1, write_i0_ib1;
   logic         write_i0_ib0;

   logic         shift2, shift1, shift0;

   logic         shift_ib1_ib0, shift_ib2_ib1, shift_ib3_ib2;
   logic         shift_ib2_ib0;
   logic         shift_ib3_ib1;


   logic         ifu_i0_val, ifu_i1_val;
   logic         debug_valid;
   logic [4:0]   dreg;
   logic [11:0]  dcsr;
   logic [31:0]  ib0_debug_in;

//   logic                     debug_read_mem;
//   logic                     debug_write_mem;
   logic         debug_read;
   logic         debug_write;
   logic         debug_read_gpr;
   logic         debug_write_gpr;
   logic         debug_read_csr;
   logic         debug_write_csr;



   rvdff #(1) flush_upperff (.*, .clk(free_clk), .din(exu_flush_final), .dout(flush_final));

   logic [3:0]   ibvalid;

   logic [3:0]   i0_wen;
   logic [3:1]   i1_wen;
   logic [3:0]   shift_ibval;
   logic [3:0]   ibwrite;

   assign ibvalid[3:0] = ibval[3:0] | i0_wen[3:0] | {i1_wen[3:1],1'b0};

   assign ibval_in[3:0] = (({4{shift0}} & ibvalid[3:0]) |
                           ({4{shift1}} & {1'b0, ibvalid[3:1]}) |
                           ({4{shift2}} & {2'b0, ibvalid[3:2]})) & ~{4{flush_final}};

   rvdff #(4) ibvalff (.*, .clk(active_clk), .din(ibval_in[3:0]), .dout(ibval[3:0]));

// only valid if there is room
   if (DEC_INSTBUF_DEPTH==4) begin
      assign ifu_i0_val = ifu_i0_valid & ~ibval[3] & ~flush_final;
      assign ifu_i1_val = ifu_i1_valid & ~ibval[2] & ~flush_final;
   end
   else begin
      assign ifu_i0_val = ifu_i0_valid & (~dec_ib0_valid_eff_d | ~dec_ib1_valid_eff_d) & ~flush_final;
      assign ifu_i1_val = ifu_i1_valid & (~dec_ib0_valid_eff_d & ~dec_ib1_valid_eff_d) & ~flush_final;
   end


   assign i0_wen[0] = ~ibval[0]             & (ifu_i0_val | debug_valid);
   assign i0_wen[1] =  ibval[0] & ~ibval[1] & ifu_i0_val;
   assign i0_wen[2] =  ibval[1] & ~ibval[2] & ifu_i0_val;
   assign i0_wen[3] =  ibval[2] & ~ibval[3] & ifu_i0_val;

   assign i1_wen[1] = ~ibval[0]             & ifu_i1_val;
   assign i1_wen[2] =  ibval[0] & ~ibval[1] & ifu_i1_val;
   assign i1_wen[3] =  ibval[1] & ~ibval[2] & ifu_i1_val;


   // start trace

   if (DEC_INSTBUF_DEPTH==4) begin
      assign cinst3_in[15:0] = ({16{write_i0_ib3}} & ifu_i0_cinst[15:0]) |
                               ({16{write_i1_ib3}} & ifu_i1_cinst[15:0]);

      rvdffe #(16) cinst3ff (.*, .en(ibwrite[3]), .din(cinst3_in[15:0]), .dout(cinst3[15:0]));

      assign cinst2_in[15:0] = ({16{write_i0_ib2}} & ifu_i0_cinst[15:0]) |
                               ({16{write_i1_ib2}} & ifu_i1_cinst[15:0]) |
                               ({16{shift_ib3_ib2}} & cinst3[15:0]);

      rvdffe #(16) cinst2ff (.*, .en(ibwrite[2]), .din(cinst2_in[15:0]), .dout(cinst2[15:0]));
   end // if (DEC_INSTBUF_DEPTH==4)
   else begin
      assign cinst3 = '0;
      assign cinst2 = '0;
   end

   assign cinst1_in[15:0] = ({16{write_i0_ib1}} & ifu_i0_cinst[15:0]) |
                            ({16{write_i1_ib1}} & ifu_i1_cinst[15:0]) |
                            ({16{shift_ib2_ib1}} & cinst2[15:0]) |
                            ({16{shift_ib3_ib1}} & cinst3[15:0]);

   rvdffe #(16) cinst1ff (.*, .en(ibwrite[1]), .din(cinst1_in[15:0]), .dout(cinst1[15:0]));


   assign cinst0_in[15:0] = ({16{write_i0_ib0}} & ifu_i0_cinst[15:0]) |
                            ({16{shift_ib1_ib0}} & cinst1[15:0]) |
                            ({16{shift_ib2_ib0}} & cinst2[15:0]);

   rvdffe #(16) cinst0ff (.*, .en(ibwrite[0]), .din(cinst0_in[15:0]), .dout(cinst0[15:0]));

   assign dec_i0_cinst_d[15:0] = cinst0[15:0];

   assign dec_i1_cinst_d[15:0] = cinst1[15:0];

   // end trace


   // pc tracking


   assign ibwrite[3:0] = {  write_i0_ib3 | write_i1_ib3,
                            write_i0_ib2 | write_i1_ib2 | shift_ib3_ib2,
                            write_i0_ib1 | write_i1_ib1 | shift_ib2_ib1 | shift_ib3_ib1,
                            write_i0_ib0 | shift_ib1_ib0 | shift_ib2_ib0
                            };

   logic [36:0]  ifu_i1_pcdata, ifu_i0_pcdata;

   assign ifu_i1_pcdata[36:0] = { ifu_i1_icaf_second, ifu_i1_dbecc, ifu_i1_sbecc, ifu_i1_perr, ifu_i1_icaf,
                                  ifu_i1_pc[31:1], ifu_i1_pc4 };
   assign ifu_i0_pcdata[36:0] = { ifu_i0_icaf_second, ifu_i0_dbecc, ifu_i0_sbecc, ifu_i0_perr, ifu_i0_icaf,
                                  ifu_i0_pc[31:1], ifu_i0_pc4 };

   if (DEC_INSTBUF_DEPTH==4) begin
      assign pc3_in[36:0] = ({37{write_i0_ib3}} & ifu_i0_pcdata[36:0]) |
                            ({37{write_i1_ib3}} & ifu_i1_pcdata[36:0]);

      rvdffe #(37) pc3ff (.*, .en(ibwrite[3]), .din(pc3_in[36:0]), .dout(pc3[36:0]));

      assign pc2_in[36:0] = ({37{write_i0_ib2}} & ifu_i0_pcdata[36:0]) |
                            ({37{write_i1_ib2}} & ifu_i1_pcdata[36:0]) |
                            ({37{shift_ib3_ib2}} & pc3[36:0]);

      rvdffe #(37) pc2ff (.*, .en(ibwrite[2]), .din(pc2_in[36:0]), .dout(pc2[36:0]));
   end // if (DEC_INSTBUF_DEPTH==4)
   else begin
      assign pc3 = '0;
      assign pc2 = '0;
   end

   assign pc1_in[36:0] = ({37{write_i0_ib1}} & ifu_i0_pcdata[36:0]) |
                         ({37{write_i1_ib1}} & ifu_i1_pcdata[36:0]) |
                         ({37{shift_ib2_ib1}} & pc2[36:0]) |
                         ({37{shift_ib3_ib1}} & pc3[36:0]);

   rvdffe #(37) pc1ff (.*, .en(ibwrite[1]), .din(pc1_in[36:0]), .dout(pc1[36:0]));


   assign pc0_in[36:0] = ({37{write_i0_ib0}} & ifu_i0_pcdata[36:0]) |
                         ({37{shift_ib1_ib0}} & pc1[36:0]) |
                         ({37{shift_ib2_ib0}} & pc2[36:0]);

   rvdffe #(37) pc0ff (.*, .en(ibwrite[0]), .din(pc0_in[36:0]), .dout(pc0[36:0]));

   assign dec_i0_icaf_second_d = pc0[36];   // icaf's can only decode as i0

   assign dec_i1_dbecc_d = pc1[35];
   assign dec_i0_dbecc_d = pc0[35];

   assign dec_i1_sbecc_d = pc1[34];
   assign dec_i0_sbecc_d = pc0[34];

   assign dec_i1_perr_d = pc1[33];
   assign dec_i0_perr_d = pc0[33];

   assign dec_i1_icaf_d = pc1[32];
   assign dec_i0_icaf_d = pc0[32];

   assign dec_i1_pc_d[31:1] = pc1[31:1];
   assign dec_i0_pc_d[31:1] = pc0[31:1];

   assign dec_i1_pc4_d = pc1[0];
   assign dec_i0_pc4_d = pc0[0];

   // branch prediction

   logic [$bits(br_pkt_t)-1:0] bp3_in,bp3,bp2_in,bp2,bp1_in,bp1,bp0_in,bp0;

   if (DEC_INSTBUF_DEPTH==4) begin
      assign bp3_in = ({$bits(br_pkt_t){write_i0_ib3}} & i0_brp) |
                      ({$bits(br_pkt_t){write_i1_ib3}} & i1_brp);

      rvdffe #($bits(br_pkt_t)) bp3ff (.*, .en(ibwrite[3]), .din(bp3_in), .dout(bp3));

      assign bp2_in = ({$bits(br_pkt_t){write_i0_ib2}} & i0_brp) |
                      ({$bits(br_pkt_t){write_i1_ib2}} & i1_brp) |
                      ({$bits(br_pkt_t){shift_ib3_ib2}} & bp3);

      rvdffe #($bits(br_pkt_t)) bp2ff (.*, .en(ibwrite[2]), .din(bp2_in), .dout(bp2));
   end // if (DEC_INSTBUF_DEPTH==4)
   else begin
      assign bp3 = '0;
      assign bp2 = '0;
   end

   assign bp1_in = ({$bits(br_pkt_t){write_i0_ib1}} & i0_brp) |
                   ({$bits(br_pkt_t){write_i1_ib1}} & i1_brp) |
                   ({$bits(br_pkt_t){shift_ib2_ib1}} & bp2) |
                   ({$bits(br_pkt_t){shift_ib3_ib1}} & bp3);

   rvdffe #($bits(br_pkt_t)) bp1ff (.*, .en(ibwrite[1]), .din(bp1_in), .dout(bp1));



   assign bp0_in = ({$bits(br_pkt_t){write_i0_ib0}} & i0_brp) |
                   ({$bits(br_pkt_t){shift_ib1_ib0}} & bp1) |
                   ({$bits(br_pkt_t){shift_ib2_ib0}} & bp2);

   rvdffe #($bits(br_pkt_t)) bp0ff (.*, .en(ibwrite[0]), .din(bp0_in), .dout(bp0));

   // instruction buffers

   if (DEC_INSTBUF_DEPTH==4) begin
      assign ib3_in[31:0] = ({32{write_i0_ib3}} & ifu_i0_instr[31:0]) |
                            ({32{write_i1_ib3}} & ifu_i1_instr[31:0]);

      rvdffe #(32) ib3ff (.*, .en(ibwrite[3]), .din(ib3_in[31:0]), .dout(ib3[31:0]));

      assign ib2_in[31:0] = ({32{write_i0_ib2}} & ifu_i0_instr[31:0]) |
                            ({32{write_i1_ib2}} & ifu_i1_instr[31:0]) |
                            ({32{shift_ib3_ib2}} & ib3[31:0]);

      rvdffe #(32) ib2ff (.*, .en(ibwrite[2]), .din(ib2_in[31:0]), .dout(ib2[31:0]));
   end // if (DEC_INSTBUF_DEPTH==4)
   else begin
      assign ib3 = '0;
      assign ib2 = '0;
   end

   assign ib1_in[31:0] = ({32{write_i0_ib1}} & ifu_i0_instr[31:0]) |
                         ({32{write_i1_ib1}} & ifu_i1_instr[31:0]) |
                         ({32{shift_ib2_ib1}} & ib2[31:0]) |
                         ({32{shift_ib3_ib1}} & ib3[31:0]);

   rvdffe #(32) ib1ff (.*, .en(ibwrite[1]), .din(ib1_in[31:0]), .dout(ib1[31:0]));


// GPR accesses

// put reg to read on rs1
// read ->   or %x0,  %reg,%x0      {000000000000,reg[4:0],110000000110011}

// put write date on rs1
// write ->  or %reg, %x0, %x0      {00000000000000000110,reg[4:0],0110011}


// CSR accesses
// csr is of form rd, csr, rs1

// read  -> csrrs %x0, %csr, %x0     {csr[11:0],00000010000001110011}

// put write data on rs1
// write -> csrrw %x0, %csr, %x0     {csr[11:0],00000001000001110011}

// abstract memory command not done here
   assign debug_valid = dbg_cmd_valid & (dbg_cmd_type[1:0] != 2'h2);


   assign debug_read  = debug_valid & ~dbg_cmd_write;
   assign debug_write = debug_valid &  dbg_cmd_write;

   assign debug_read_gpr  = debug_read  & (dbg_cmd_type[1:0]==2'h0);
   assign debug_write_gpr = debug_write & (dbg_cmd_type[1:0]==2'h0);
   assign debug_read_csr  = debug_read  & (dbg_cmd_type[1:0]==2'h1);
   assign debug_write_csr = debug_write & (dbg_cmd_type[1:0]==2'h1);

   assign dreg[4:0]  = dbg_cmd_addr[4:0];
   assign dcsr[11:0] = dbg_cmd_addr[11:0];


   assign ib0_debug_in[31:0] = ({32{debug_read_gpr}}  & {12'b000000000000,dreg[4:0],15'b110000000110011}) |
                               ({32{debug_write_gpr}} & {20'b00000000000000000110,dreg[4:0],7'b0110011}) |
                               ({32{debug_read_csr}}  & {dcsr[11:0],20'b00000010000001110011}) |
                               ({32{debug_write_csr}} & {dcsr[11:0],20'b00000001000001110011});


   // machine is in halted state, pipe empty, write will always happen next cycle
   rvdff #(1) debug_wdata_rs1ff (.*, .clk(free_clk), .din(debug_write_gpr | debug_write_csr), .dout(dec_debug_wdata_rs1_d));


   // special fence csr for use only in debug mode

   logic                       debug_fence_in;

   assign debug_fence_in = debug_write_csr & (dcsr[11:0] == 12'h7c4);

   rvdff #(1) debug_fence_ff (.*,  .clk(free_clk), .din(debug_fence_in),  .dout(dec_debug_fence_d));


   assign ib0_in[31:0] = ({32{write_i0_ib0}} & ((debug_valid) ? ib0_debug_in[31:0] : ifu_i0_instr[31:0])) |
                         ({32{shift_ib1_ib0}} & ib1[31:0]) |
                         ({32{shift_ib2_ib0}} & ib2[31:0]);

   rvdffe #(32) ib0ff (.*, .en(ibwrite[0]), .din(ib0_in[31:0]), .dout(ib0[31:0]));

   assign dec_ib3_valid_d = ibval[3];
   assign dec_ib2_valid_d = ibval[2];
   assign dec_ib1_valid_d = ibval[1];
   assign dec_ib0_valid_d = ibval[0];

   assign dec_i0_instr_d[31:0] = ib0[31:0];

   assign dec_i1_instr_d[31:0] = ib1[31:0];

   assign dec_i0_brp = bp0;
   assign dec_i1_brp = bp1;


   assign shift1 = dec_i0_decode_d & ~dec_i1_decode_d;

   assign shift2 = dec_i0_decode_d & dec_i1_decode_d;

   assign shift0 = ~dec_i0_decode_d;


   // compute shifted ib valids to determine where to write
   assign shift_ibval[3:0] = ({4{shift1}} & {1'b0, ibval[3:1] }) |
                             ({4{shift2}} & {2'b0, ibval[3:2]}) |
                             ({4{shift0}} & ibval[3:0]);

   assign write_i0_ib0 = ~shift_ibval[0]                & (ifu_i0_val | debug_valid);
   assign write_i0_ib1 =  shift_ibval[0] & ~shift_ibval[1] & ifu_i0_val;
   assign write_i0_ib2 =  shift_ibval[1] & ~shift_ibval[2] & ifu_i0_val;
   assign write_i0_ib3 =  shift_ibval[2] & ~shift_ibval[3] & ifu_i0_val;

   assign write_i1_ib1 = ~shift_ibval[0]                & ifu_i1_val;
   assign write_i1_ib2 =  shift_ibval[0] & ~shift_ibval[1] & ifu_i1_val;
   assign write_i1_ib3 =  shift_ibval[1] & ~shift_ibval[2] & ifu_i1_val;


   assign shift_ib1_ib0 = shift1 & ibval[1];
   assign shift_ib2_ib1 = shift1 & ibval[2];
   assign shift_ib3_ib2 = shift1 & ibval[3];

   assign shift_ib2_ib0 = shift2 & ibval[2];
   assign shift_ib3_ib1 = shift2 & ibval[3];



endmodule
