//********************************************************************************
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
//********************************************************************************

//********************************************************************************
// Function: Instruction aligner
//********************************************************************************
module ifu_aln_ctl
   import swerv_types::*;
(

   input logic        active_clk,

   input logic        iccm_rd_ecc_single_err,         // This fetch has a single ICCM ecc  error.
   input logic [7:0]  iccm_rd_ecc_double_err,         // This fetch has a double ICCM ecc  error.
   input logic        ic_rd_parity_final_err,         // for tag parity errors

   input logic        ifu_icache_fetch_f2,

   input logic [7:0]  ic_access_fault_f2,             // Instruction access fault for the current fetch.
   input logic [`RV_BHT_GHR_RANGE]  ifu_bp_fghr_f2,   // fetch GHR
   input logic [31:1] ifu_bp_btb_target_f2,           //  predicted RET target
   input logic [11:0] ifu_bp_poffset_f2,              // predicted target offset

   input logic [7:0]  ifu_bp_hist0_f2,    // history counters for all 4 potential branches, bit 1, right justified
   input logic [7:0]  ifu_bp_hist1_f2,    // history counters for all 4 potential branches, bit 1, right justified
   input logic [7:0]  ifu_bp_pc4_f2,      // pc4 indication, right justified
`ifdef RV_BTB_48
   input logic [7:0][1:0]  ifu_bp_way_f2, // way indication, right justified
`else
   input logic [7:0]  ifu_bp_way_f2,      // way indication, right justified
`endif
   input logic [7:0]  ifu_bp_valid_f2,    // branch valid, right justified
   input logic [7:0]  ifu_bp_ret_f2,      // predicted ret indication, right justified

   input logic exu_flush_final,           // Flush from the pipeline.

   input logic dec_ib3_valid_d,           // valids for top 2 instruction buffers at decode
   input logic dec_ib2_valid_d,

   input logic dec_ib0_valid_eff_d,       // effective valid taking decode into account
   input logic dec_ib1_valid_eff_d,


   input logic [127:0] ifu_fetch_data,      // fetch data in memory format - not right justified

   input icache_err_pkt_t ic_error_f2,      // based on configuration: either parity or ecc


   input logic [7:0]   ifu_fetch_val,       // valids on a 2B boundary, right justified
   input logic [31:1]  ifu_fetch_pc,        // starting pc of fetch


   input logic   rst_l,
   input logic   clk,
   input logic   dec_tlu_core_ecc_disable,  // disable ecc checking and flagging

   output logic ifu_i0_valid,            // Instruction 0 is valid
   output logic ifu_i1_valid,            // Instruction 1 is valid
   output logic ifu_i0_icaf,             // Instruction 0 has access fault
   output logic ifu_i1_icaf,             // Instruction 1 has access fault
   output logic ifu_i0_icaf_second,      // Instruction 0 has access fault on second 2B of 4B inst
   output logic ifu_i1_icaf_second,      // Instruction 1 has access fault on second 2B of 4B inst
   output logic ifu_i0_perr,             // Instruction 0 has parity error
   output logic ifu_i1_perr,             // Instruction 1 has parity error
   output logic ifu_i0_sbecc,            // Instruction 0 has single bit ecc error
   output logic ifu_i1_sbecc,            // Instruction 1 has single bit ecc error
   output logic ifu_i0_dbecc,            // Instruction 0 has double bit ecc error
   output logic ifu_i1_dbecc,            // Instruction 1 has double bit ecc error
   output logic [31:0] ifu_i0_instr,     // Instruction 0
   output logic [31:0] ifu_i1_instr,     // Instruction 1
   output logic [31:1] ifu_i0_pc,        // Instruction 0 PC
   output logic [31:1] ifu_i1_pc,        // Instruction 1 PC
   output logic ifu_i0_pc4,
   output logic ifu_i1_pc4,

   output logic ifu_fb_consume1,         // Consumed one buffer. To fetch control fetch for buffer mass balance
   output logic ifu_fb_consume2,         // Consumed two buffers.To fetch control fetch for buffer mass balance
   output logic [15:0] ifu_illegal_inst, // Illegal Instruction.

   output br_pkt_t i0_brp,               // Branch packet for I0.
   output br_pkt_t i1_brp,               // Branch packet for I1.

   output logic [1:0] ifu_pmu_instr_aligned,         // number of inst aligned this cycle
   output logic       ifu_pmu_align_stall,           // aligner stalled this cycle

   output logic [16:2] ifu_icache_error_index,   // Icache Error address index
   output logic        ifu_icache_error_val,     // Icache error valid
   output logic        ifu_icache_sb_error_val,

   output logic [15:0] ifu_i0_cinst,                 // 16b compress inst for i0
   output logic [15:0] ifu_i1_cinst,                 // 16b compress inst for i1

   input  logic    scan_mode


   );

`include "global.h"

   logic         ifvalid;
   logic         shift_f1_f0, shift_f2_f0, shift_f2_f1;
   logic         fetch_to_f0, fetch_to_f1, fetch_to_f2;

   logic [7:0]   f2val_in, f2val;
   logic [7:0]   f1val_in, f1val;
   logic [7:0]   f0val_in, f0val;

   logic [7:0]   sf1val, sf0val;

   logic [31:1]  f2pc_in, f2pc;
   logic [31:1]  f1pc_in, f1pc;
   logic [31:1]  f0pc_in, f0pc;
   logic [31:1]  sf1pc, sf0pc;

   logic [63:0]  aligndata;
   logic         first4B, first2B;
   logic         second4B, second2B;

   logic         third4B, third2B;
   logic [31:0]  uncompress0, uncompress1, uncompress2;
   logic         ibuffer_room1_more;
   logic         ibuffer_room2_more;
   logic         i0_shift, i1_shift;
   logic         shift_2B, shift_4B, shift_6B, shift_8B;
   logic         f1_shift_2B, f1_shift_4B, f1_shift_6B;
   logic         f2_valid, sf1_valid, sf0_valid;

   logic [31:0]  ifirst, isecond, ithird;
   logic [31:1]  f0pc_plus1, f0pc_plus2, f0pc_plus3, f0pc_plus4;
   logic [31:1]  f1pc_plus1, f1pc_plus2, f1pc_plus3;
   logic [3:0]   alignval;
   logic [31:1]  firstpc, secondpc, thirdpc, fourthpc;

   logic [11:0]  f1poffset;
   logic [11:0]  f0poffset;
   logic [`RV_BHT_GHR_RANGE]  f1fghr;
   logic [`RV_BHT_GHR_RANGE]  f0fghr;
   logic [7:0]               f1hist1;
   logic [7:0]               f0hist1;
   logic [7:0]               f1hist0;
   logic [7:0]               f0hist0;
   logic [7:0]             f1pc4;
   logic [7:0]             f0pc4;

   logic [7:0]             f1ret;
   logic [7:0]             f0ret;
`ifdef RV_BTB_48
   logic [7:0][1:0]      f1way;
   logic [7:0][1:0]      f0way;
`else
   logic [7:0]             f1way;
   logic [7:0]             f0way;
`endif

   logic [7:0]               f1brend;
   logic [7:0]               f0brend;

   logic [3:0]   alignbrend;
   logic [3:0]   alignpc4;
`ifdef RV_ICACHE_ECC
   logic [19:0]  alignecc;
`else
   logic [3:0]   alignparity;
`endif
   logic [3:0]   alignret;
   logic [3:0]   alignway;
   logic [3:0]   alignhist1;

   logic [3:0]   alignhist0;
   logic [3:1]   alignfromf1;
   logic         i0_ends_f1, i1_ends_f1;
   logic         i0_br_start_error, i1_br_start_error;

   logic [31:1]  f1prett;
   logic [31:1]  f0prett;
   logic [7:0]   f1dbecc;
   logic [7:0]   f0dbecc;
   logic         f1sbecc;
   logic         f0sbecc;
   logic         f1perr;
   logic         f0perr;
   logic         f1icfetch;
   logic         f0icfetch;
   logic [7:0]   f1icaf;
   logic [7:0]   f0icaf;

   logic [3:0]   alignicfetch;
   logic [3:0]   aligntagperr;
   logic [3:0]   aligndataperr;
   logic [3:0]   alignsbecc;
   logic [3:0]   aligndbecc;
   logic [3:0]   alignicaf;
   logic         i0_brp_pc4, i1_brp_pc4;

   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] firstpc_hash, secondpc_hash, thirdpc_hash, fourthpc_hash;

   logic         i0_illegal, i1_illegal;
   logic         shift_illegal;
   logic         first_legal, second_legal, third_legal;
   logic [15:0]  illegal_inst;
   logic         illegal_inst_en;
   logic         illegal_lockout_in, illegal_lockout;

   logic [3:0]   alignfinalperr;

   logic f2_wr_en;

   assign f2_wr_en = fetch_to_f2;

   logic f0_shift_wr_en;

   assign f0_shift_wr_en = (fetch_to_f0 | shift_f2_f0 | shift_f1_f0 | shift_2B | shift_4B | shift_6B | shift_8B);

   logic f1_shift_wr_en;

   assign f1_shift_wr_en = (fetch_to_f1 | shift_f2_f1 | f1_shift_2B | f1_shift_4B | f1_shift_6B);

   logic [1:0] wrptr, wrptr_in;
   logic [1:0] rdptr, rdptr_in;
   logic [2:0] qwen;
   logic [127:0] q2,q1,q0;
   logic [2:0]   first_offset, second_offset;
   logic [2:0]   q2off_eff, q2off_in, q2off;
   logic [2:0]   q1off_eff, q1off_in, q1off;
   logic [2:0]   q0off_eff, q0off_in, q0off;
   logic         f0_shift_2B, f0_shift_4B, f0_shift_6B, f0_shift_8B;

   logic [127:0] q0eff;
   logic [127:0] q0final;
   logic [2:0]   q0ptr;
   logic [7:0]   q0sel;

   logic [127:0] q1eff;
   logic [127:0] q1final;
   logic [2:0]   q1ptr;
   logic [7:0]   q1sel;

   logic [2:0]   qren;

   logic         consume_fb1, consume_fb0;
   logic [3:0]   icaf_eff;

`ifdef RV_ICACHE_ECC
   logic [39:0]          q0ecc, q1ecc, q2ecc;
   logic [39:0]          q0ecceff, q1ecceff;
   logic [39:0]          q0eccfinal, q1eccfinal;
`else
   logic [7:0]   q0parity, q1parity, q2parity;
   logic [7:0]   q0parityeff, q1parityeff;
   logic [7:0]   q0parityfinal, q1parityfinal;
`endif

   // new queue control logic

   assign wrptr_in[1:0] =  (({2{wrptr[1:0]==2'b00 & ifvalid}} & 2'b01) |
                            ({2{wrptr[1:0]==2'b01 & ifvalid}} & 2'b10) |
                            ({2{wrptr[1:0]==2'b10 & ifvalid}} & 2'b00) |
                            ({2{~ifvalid}} & wrptr[1:0])) & ~{2{exu_flush_final}};

   rvdff #(2) wrpff (.*, .clk(active_clk), .din(wrptr_in[1:0]), .dout(wrptr[1:0]));

   assign rdptr_in[1:0] =  (({2{rdptr[1:0]==2'b00 & ifu_fb_consume1}} & 2'b01) |
                            ({2{rdptr[1:0]==2'b01 & ifu_fb_consume1}} & 2'b10) |
                            ({2{rdptr[1:0]==2'b10 & ifu_fb_consume1}} & 2'b00) |
                            ({2{rdptr[1:0]==2'b00 & ifu_fb_consume2}} & 2'b10) |
                            ({2{rdptr[1:0]==2'b01 & ifu_fb_consume2}} & 2'b00) |
                            ({2{rdptr[1:0]==2'b10 & ifu_fb_consume2}} & 2'b01) |
                            ({2{~ifu_fb_consume1&~ifu_fb_consume2}} & rdptr[1:0])) & ~{2{exu_flush_final}};

   rvdff #(2) rdpff (.*, .clk(active_clk), .din(rdptr_in[1:0]), .dout(rdptr[1:0]));

   assign qren[2:0] = { rdptr[1:0]==2'b10,
                        rdptr[1:0]==2'b01,
                        rdptr[1:0]==2'b00
                        };

   assign qwen[2:0] = { wrptr[1:0]==2'b10 & ifvalid,
                        wrptr[1:0]==2'b01 & ifvalid,
                        wrptr[1:0]==2'b00 & ifvalid
                        };


   assign first_offset[2:0]  = {f0_shift_8B,  f0_shift_6B|f0_shift_4B,  f0_shift_6B|f0_shift_2B };

   assign second_offset[2:0] = {1'b0,         f1_shift_6B|f1_shift_4B,  f1_shift_6B|f1_shift_2B };


   assign q2off_eff[2:0] = (rdptr[1:0]==2'd2) ? (q2off[2:0] + first_offset[2:0])  :
                           (rdptr[1:0]==2'd1) ? (q2off[2:0] + second_offset[2:0]) :
                                                 q2off[2:0];

   assign q2off_in[2:0] = (qwen[2]) ? ifu_fetch_pc[3:1] : q2off_eff[2:0];

   rvdff #(3) q2offsetff (.*, .clk(active_clk), .din(q2off_in[2:0]), .dout(q2off[2:0]));

   assign q1off_eff[2:0] = (rdptr[1:0]==2'd1) ? (q1off[2:0] + first_offset[2:0])  :
                           (rdptr[1:0]==2'd0) ? (q1off[2:0] + second_offset[2:0]) :
                                                 q1off[2:0];


   assign q1off_in[2:0] = (qwen[1]) ? ifu_fetch_pc[3:1] : q1off_eff[2:0];

   rvdff #(3) q1offsetff (.*, .clk(active_clk), .din(q1off_in[2:0]), .dout(q1off[2:0]));


   assign q0off_eff[2:0] = (rdptr[1:0]==2'd0) ? (q0off[2:0] + first_offset[2:0])  :
                           (rdptr[1:0]==2'd2) ? (q0off[2:0] + second_offset[2:0]) :
                                                 q0off[2:0];


   assign q0off_in[2:0] = (qwen[0]) ? ifu_fetch_pc[3:1] : q0off_eff[2:0];


   rvdff #(3) q0offsetff (.*, .clk(active_clk), .din(q0off_in[2:0]), .dout(q0off[2:0]));

   assign q0ptr[2:0] = (({3{rdptr[1:0]==2'b00}} & q0off[2:0]) |
                        ({3{rdptr[1:0]==2'b01}} & q1off[2:0]) |
                        ({3{rdptr[1:0]==2'b10}} & q2off[2:0]));

   assign q1ptr[2:0] = (({3{rdptr[1:0]==2'b00}} & q1off[2:0]) |
                        ({3{rdptr[1:0]==2'b01}} & q2off[2:0]) |
                        ({3{rdptr[1:0]==2'b10}} & q0off[2:0]));

   assign q0sel[7:0] = { q0ptr[2:0]==3'b111,
                         q0ptr[2:0]==3'b110,
                         q0ptr[2:0]==3'b101,
                         q0ptr[2:0]==3'b100,
                         q0ptr[2:0]==3'b011,
                         q0ptr[2:0]==3'b010,
                         q0ptr[2:0]==3'b001,
                         q0ptr[2:0]==3'b000
                         };

   assign q1sel[7:0] = { q1ptr[2:0]==3'b111,
                         q1ptr[2:0]==3'b110,
                         q1ptr[2:0]==3'b101,
                         q1ptr[2:0]==3'b100,
                         q1ptr[2:0]==3'b011,
                         q1ptr[2:0]==3'b010,
                         q1ptr[2:0]==3'b001,
                         q1ptr[2:0]==3'b000
                         };

   // end new queue control logic


   // misc data that is associated with each fetch buffer

   localparam MHI   = 45+`RV_BHT_GHR_SIZE;
   localparam MSIZE = 46+`RV_BHT_GHR_SIZE;

   logic [MHI:0] misc_data_in, misc2, misc1, misc0;
   logic [MHI:0] misc1eff, misc0eff;

   assign misc_data_in[MHI:0] = {
                                  iccm_rd_ecc_single_err,
                                  ifu_icache_fetch_f2,
                                  ic_rd_parity_final_err,

                                  ifu_bp_btb_target_f2[31:1],
                                  ifu_bp_poffset_f2[11:0],
                                  ifu_bp_fghr_f2[`RV_BHT_GHR_RANGE]
                                  };

   rvdffe #(MSIZE) misc2ff (.*, .en(qwen[2]), .din(misc_data_in[MHI:0]), .dout(misc2[MHI:0]));
   rvdffe #(MSIZE) misc1ff (.*, .en(qwen[1]), .din(misc_data_in[MHI:0]), .dout(misc1[MHI:0]));
   rvdffe #(MSIZE) misc0ff (.*, .en(qwen[0]), .din(misc_data_in[MHI:0]), .dout(misc0[MHI:0]));


   assign {misc1eff[MHI:0],misc0eff[MHI:0]} = (({MSIZE*2{qren[0]}} & {misc1[MHI:0],misc0[MHI:0]}) |
                                               ({MSIZE*2{qren[1]}} & {misc2[MHI:0],misc1[MHI:0]}) |
                                               ({MSIZE*2{qren[2]}} & {misc0[MHI:0],misc2[MHI:0]}));
   assign {
            f1sbecc,
            f1icfetch,
            f1perr,

            f1prett[31:1],
            f1poffset[11:0],
            f1fghr[`RV_BHT_GHR_RANGE]
            } = misc1eff[MHI:0];

   assign {
            f0sbecc,
            f0icfetch,
            f0perr,

            f0prett[31:1],
            f0poffset[11:0],
            f0fghr[`RV_BHT_GHR_RANGE]
            } = misc0eff[MHI:0];


`ifdef RV_BTB_48
   localparam BRDATA_SIZE=72;
   localparam BRDATA_WIDTH = 9;
`else
   localparam BRDATA_SIZE=64;
   localparam BRDATA_WIDTH = 8;
`endif
   logic [BRDATA_SIZE-1:0] brdata_in, brdata2, brdata1, brdata0;
   logic [BRDATA_SIZE-1:0] brdata1eff, brdata0eff;
   logic [BRDATA_SIZE-1:0] brdata1final, brdata0final;
   assign brdata_in[BRDATA_SIZE-1:0] = {
                              iccm_rd_ecc_double_err[7],ic_access_fault_f2[7],ifu_bp_hist1_f2[7],ifu_bp_hist0_f2[7],ifu_bp_pc4_f2[7],ifu_bp_way_f2[7],ifu_bp_valid_f2[7],ifu_bp_ret_f2[7],
                              iccm_rd_ecc_double_err[6],ic_access_fault_f2[6],ifu_bp_hist1_f2[6],ifu_bp_hist0_f2[6],ifu_bp_pc4_f2[6],ifu_bp_way_f2[6],ifu_bp_valid_f2[6],ifu_bp_ret_f2[6],
                              iccm_rd_ecc_double_err[5],ic_access_fault_f2[5],ifu_bp_hist1_f2[5],ifu_bp_hist0_f2[5],ifu_bp_pc4_f2[5],ifu_bp_way_f2[5],ifu_bp_valid_f2[5],ifu_bp_ret_f2[5],
                              iccm_rd_ecc_double_err[4],ic_access_fault_f2[4],ifu_bp_hist1_f2[4],ifu_bp_hist0_f2[4],ifu_bp_pc4_f2[4],ifu_bp_way_f2[4],ifu_bp_valid_f2[4],ifu_bp_ret_f2[4],
                              iccm_rd_ecc_double_err[3],ic_access_fault_f2[3],ifu_bp_hist1_f2[3],ifu_bp_hist0_f2[3],ifu_bp_pc4_f2[3],ifu_bp_way_f2[3],ifu_bp_valid_f2[3],ifu_bp_ret_f2[3],
                              iccm_rd_ecc_double_err[2],ic_access_fault_f2[2],ifu_bp_hist1_f2[2],ifu_bp_hist0_f2[2],ifu_bp_pc4_f2[2],ifu_bp_way_f2[2],ifu_bp_valid_f2[2],ifu_bp_ret_f2[2],
                              iccm_rd_ecc_double_err[1],ic_access_fault_f2[1],ifu_bp_hist1_f2[1],ifu_bp_hist0_f2[1],ifu_bp_pc4_f2[1],ifu_bp_way_f2[1],ifu_bp_valid_f2[1],ifu_bp_ret_f2[1],
                              iccm_rd_ecc_double_err[0],ic_access_fault_f2[0],ifu_bp_hist1_f2[0],ifu_bp_hist0_f2[0],ifu_bp_pc4_f2[0],ifu_bp_way_f2[0],ifu_bp_valid_f2[0],ifu_bp_ret_f2[0]
                              };
//
   rvdffe #(BRDATA_SIZE) brdata2ff (.*, .en(qwen[2]), .din(brdata_in[BRDATA_SIZE-1:0]), .dout(brdata2[BRDATA_SIZE-1:0]));
   rvdffe #(BRDATA_SIZE) brdata1ff (.*, .en(qwen[1]), .din(brdata_in[BRDATA_SIZE-1:0]), .dout(brdata1[BRDATA_SIZE-1:0]));
   rvdffe #(BRDATA_SIZE) brdata0ff (.*, .en(qwen[0]), .din(brdata_in[BRDATA_SIZE-1:0]), .dout(brdata0[BRDATA_SIZE-1:0]));


   assign {brdata1eff[BRDATA_SIZE-1:0],brdata0eff[BRDATA_SIZE-1:0]} = (({BRDATA_SIZE*2{qren[0]}} & {brdata1[BRDATA_SIZE-1:0],brdata0[BRDATA_SIZE-1:0]}) |
                                                                       ({BRDATA_SIZE*2{qren[1]}} & {brdata2[BRDATA_SIZE-1:0],brdata1[BRDATA_SIZE-1:0]}) |
                                                                       ({BRDATA_SIZE*2{qren[2]}} & {brdata0[BRDATA_SIZE-1:0],brdata2[BRDATA_SIZE-1:0]}));

   assign brdata0final[BRDATA_SIZE-1:0] = (({BRDATA_SIZE{q0sel[0]}} & {            brdata0eff[BRDATA_SIZE-1:0]}) |
                                ({BRDATA_SIZE{q0sel[1]}} & {{1*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:1*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[2]}} & {{2*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:2*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[3]}} & {{3*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:3*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[4]}} & {{4*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:4*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[5]}} & {{5*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:5*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[6]}} & {{6*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:6*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[7]}} & {{7*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:7*BRDATA_WIDTH]}));

   assign brdata1final[BRDATA_SIZE-1:0] = (({BRDATA_SIZE{q1sel[0]}} & {            brdata1eff[BRDATA_SIZE-1:0]}) |
                                ({BRDATA_SIZE{q1sel[1]}} & {{1*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:1*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[2]}} & {{2*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:2*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[3]}} & {{3*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:3*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[4]}} & {{4*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:4*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[5]}} & {{5*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:5*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[6]}} & {{6*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:6*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[7]}} & {{7*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:7*BRDATA_WIDTH]}));

   assign {
            f0dbecc[7],f0icaf[7],f0hist1[7],f0hist0[7],f0pc4[7],f0way[7],f0brend[7],f0ret[7],
            f0dbecc[6],f0icaf[6],f0hist1[6],f0hist0[6],f0pc4[6],f0way[6],f0brend[6],f0ret[6],
            f0dbecc[5],f0icaf[5],f0hist1[5],f0hist0[5],f0pc4[5],f0way[5],f0brend[5],f0ret[5],
            f0dbecc[4],f0icaf[4],f0hist1[4],f0hist0[4],f0pc4[4],f0way[4],f0brend[4],f0ret[4],
            f0dbecc[3],f0icaf[3],f0hist1[3],f0hist0[3],f0pc4[3],f0way[3],f0brend[3],f0ret[3],
            f0dbecc[2],f0icaf[2],f0hist1[2],f0hist0[2],f0pc4[2],f0way[2],f0brend[2],f0ret[2],
            f0dbecc[1],f0icaf[1],f0hist1[1],f0hist0[1],f0pc4[1],f0way[1],f0brend[1],f0ret[1],
            f0dbecc[0],f0icaf[0],f0hist1[0],f0hist0[0],f0pc4[0],f0way[0],f0brend[0],f0ret[0]
            } = brdata0final[BRDATA_SIZE-1:0];

   assign {
            f1dbecc[7],f1icaf[7],f1hist1[7],f1hist0[7],f1pc4[7],f1way[7],f1brend[7],f1ret[7],
            f1dbecc[6],f1icaf[6],f1hist1[6],f1hist0[6],f1pc4[6],f1way[6],f1brend[6],f1ret[6],
            f1dbecc[5],f1icaf[5],f1hist1[5],f1hist0[5],f1pc4[5],f1way[5],f1brend[5],f1ret[5],
            f1dbecc[4],f1icaf[4],f1hist1[4],f1hist0[4],f1pc4[4],f1way[4],f1brend[4],f1ret[4],
            f1dbecc[3],f1icaf[3],f1hist1[3],f1hist0[3],f1pc4[3],f1way[3],f1brend[3],f1ret[3],
            f1dbecc[2],f1icaf[2],f1hist1[2],f1hist0[2],f1pc4[2],f1way[2],f1brend[2],f1ret[2],
            f1dbecc[1],f1icaf[1],f1hist1[1],f1hist0[1],f1pc4[1],f1way[1],f1brend[1],f1ret[1],
            f1dbecc[0],f1icaf[0],f1hist1[0],f1hist0[0],f1pc4[0],f1way[0],f1brend[0],f1ret[0]
            } = brdata1final[BRDATA_SIZE-1:0];


   // possible states of { sf0_valid, sf1_valid, f2_valid }

   // 000 if->f0

   // 100 if->f1

   // 101 illegal

   // 010 f1->f0, if->f1

   // 110 if->f2

   // 001 if->f1, f2->f0

   // 011 f1->f0, f2->f1, if->f2

   // 111 !if, no shift

   assign f2_valid = f2val[0];

   assign sf1_valid = sf1val[0];

   assign sf0_valid = sf0val[0];

   // interface to fetch

   assign consume_fb0 = ~sf0val[0] & f0val[0];

   assign consume_fb1 = ~sf1val[0] & f1val[0];

   assign ifu_fb_consume1 = consume_fb0 & ~consume_fb1 & ~exu_flush_final;

   assign ifu_fb_consume2 = consume_fb0 &  consume_fb1 & ~exu_flush_final;

   assign ifvalid = ifu_fetch_val[0];

   assign shift_f1_f0 =  ~sf0_valid & sf1_valid;

   assign shift_f2_f0 =  ~sf0_valid & ~sf1_valid & f2_valid;

   assign shift_f2_f1 =  ~sf0_valid & sf1_valid & f2_valid;

   assign fetch_to_f0 =  ~sf0_valid & ~sf1_valid & ~f2_valid & ifvalid;

   assign fetch_to_f1 =  (~sf0_valid & ~sf1_valid &  f2_valid & ifvalid)  |
                         (~sf0_valid &  sf1_valid & ~f2_valid & ifvalid)  |
                         ( sf0_valid & ~sf1_valid & ~f2_valid & ifvalid);

   assign fetch_to_f2 =  (~sf0_valid &  sf1_valid &  f2_valid & ifvalid)  |
                         ( sf0_valid &  sf1_valid & ~f2_valid & ifvalid);

   // f0 valid states
   //
   // 11111111
   // 11111110
   // 11111100
   // 11111000
   // 11110000

   // 11100000
   // 11000000
   // 10000000
   // 00000000



   // make this two incrementors with some logic on the lower bits

   assign f0pc_plus1[31:1] = f0pc[31:1] + 31'd1;
   assign f0pc_plus2[31:1] = f0pc[31:1] + 31'd2;
   assign f0pc_plus3[31:1] = f0pc[31:1] + 31'd3;
   assign f0pc_plus4[31:1] = f0pc[31:1] + 31'd4;

   assign f1pc_plus1[31:1] = f1pc[31:1] + 31'd1;
   assign f1pc_plus2[31:1] = f1pc[31:1] + 31'd2;
   assign f1pc_plus3[31:1] = f1pc[31:1] + 31'd3;

   assign f2pc_in[31:1] = ifu_fetch_pc[31:1];

   rvdffe #(31) f2pcff (.*, .en(f2_wr_en), .din(f2pc_in[31:1]), .dout(f2pc[31:1]));

   assign sf1pc[31:1] = ({31{f1_shift_2B}} & (f1pc_plus1[31:1])) |
                        ({31{f1_shift_4B}} & (f1pc_plus2[31:1])) |
                        ({31{f1_shift_6B}} & (f1pc_plus3[31:1])) |
                        ({31{~f1_shift_2B&~f1_shift_4B&~f1_shift_6B}} & f1pc[31:1]);

   assign f1pc_in[31:1] = ({31{fetch_to_f1}} & ifu_fetch_pc[31:1]) |
                          ({31{shift_f2_f1}} & f2pc[31:1]) |
                          ({31{~fetch_to_f1&~shift_f2_f1}} & sf1pc[31:1]);

   rvdffe #(31) f1pcff (.*, .en(f1_shift_wr_en), .din(f1pc_in[31:1]), .dout(f1pc[31:1]));

   assign sf0pc[31:1] = ({31{shift_2B}} & (f0pc_plus1[31:1])) |
                        ({31{shift_4B}} & (f0pc_plus2[31:1])) |
                        ({31{shift_6B}} & (f0pc_plus3[31:1])) |
                        ({31{shift_8B}} & (f0pc_plus4[31:1]));

   assign f0pc_in[31:1] = ({31{fetch_to_f0}} & ifu_fetch_pc[31:1]) |
                          ({31{shift_f2_f0}} & f2pc[31:1]) |
                          ({31{shift_f1_f0}} & sf1pc[31:1]) |
                          ({31{~fetch_to_f0&~shift_f2_f0&~shift_f1_f0}} & sf0pc[31:1]);

   rvdffe #(31) f0pcff (.*, .en(f0_shift_wr_en), .din(f0pc_in[31:1]), .dout(f0pc[31:1]));

   // on flush_final all valids go to 0

   // no clock-gating on the valids

   assign f2val_in[7:0] = (({8{fetch_to_f2}} & ifu_fetch_val[7:0]) |
                           ({8{~fetch_to_f2&~shift_f2_f1&~shift_f2_f0}} & f2val[7:0])) & ~{8{exu_flush_final}};

   rvdff #(8) f2valff (.*, .clk(active_clk), .din(f2val_in[7:0]), .dout(f2val[7:0]));

   assign sf1val[7:0] = ({8{f1_shift_2B}} & {1'b0,f1val[7:1]}) |
                        ({8{f1_shift_4B}} & {2'b0,f1val[7:2]}) |
                        ({8{f1_shift_6B}} & {3'b0,f1val[7:3]}) |
                        ({8{~f1_shift_2B&~f1_shift_4B&~f1_shift_6B}} & f1val[7:0]);

   assign f1val_in[7:0] = (({8{fetch_to_f1}} & ifu_fetch_val[7:0]) |
                           ({8{shift_f2_f1}} & f2val[7:0]) |
                           ({8{~fetch_to_f1&~shift_f2_f1&~shift_f1_f0}} & sf1val[7:0])) & ~{8{exu_flush_final}};

   rvdff #(8) f1valff (.*, .clk(active_clk), .din(f1val_in[7:0]), .dout(f1val[7:0]));


   assign sf0val[7:0] = ({8{shift_2B}} & {1'b0,f0val[7:1]}) |
                        ({8{shift_4B}} & {2'b0,f0val[7:2]}) |
                        ({8{shift_6B}} & {3'b0,f0val[7:3]}) |
                        ({8{shift_8B}} & {4'b0,f0val[7:4]}) |
                        ({8{~shift_2B&~shift_4B&~shift_6B&~shift_8B}} & f0val[7:0]);

   assign f0val_in[7:0] = (({8{fetch_to_f0}} & ifu_fetch_val[7:0]) |
                           ({8{shift_f2_f0}} & f2val[7:0]) |
                           ({8{shift_f1_f0}} & sf1val[7:0]) |
                           ({8{~fetch_to_f0&~shift_f2_f0&~shift_f1_f0}} & sf0val[7:0])) & ~{8{exu_flush_final}};

   rvdff #(8) f0valff (.*, .clk(active_clk), .din(f0val_in[7:0]), .dout(f0val[7:0]));

// parity

`ifdef RV_ICACHE_ECC
   rvdffe #(40) q2eccff (.*, .en(qwen[2]), .din(ic_error_f2.ecc[39:0]), .dout(q2ecc[39:0]));
   rvdffe #(40) q1eccff (.*, .en(qwen[1]), .din(ic_error_f2.ecc[39:0]), .dout(q1ecc[39:0]));
   rvdffe #(40) q0eccff (.*, .en(qwen[0]), .din(ic_error_f2.ecc[39:0]), .dout(q0ecc[39:0]));


   assign {q1ecceff[39:0],q0ecceff[39:0]} = (({80{qren[0]}} & {q1ecc[39:0],q0ecc[39:0]}) |
                                             ({80{qren[1]}} & {q2ecc[39:0],q1ecc[39:0]}) |
                                             ({80{qren[2]}} & {q0ecc[39:0],q2ecc[39:0]}));

   assign q0eccfinal[39:0] =     (({40{q0sel[0]}} & {      q0ecceff[8*5-1:0*5]}) |
                                  ({40{q0sel[1]}} & { 5'b0,q0ecceff[8*5-1:1*5]}) |
                                  ({40{q0sel[2]}} & {10'b0,q0ecceff[8*5-1:2*5]}) |
                                  ({40{q0sel[3]}} & {15'b0,q0ecceff[8*5-1:3*5]}) |
                                  ({40{q0sel[4]}} & {20'b0,q0ecceff[8*5-1:4*5]}) |
                                  ({40{q0sel[5]}} & {25'b0,q0ecceff[8*5-1:5*5]}) |
                                  ({40{q0sel[6]}} & {30'b0,q0ecceff[8*5-1:6*5]}) |
                                  ({40{q0sel[7]}} & {35'b0,q0ecceff[8*5-1:7*5]}));

   assign q1eccfinal[39:0] =     (({40{q1sel[0]}} & {      q1ecceff[8*5-1:0*5]}) |
                                  ({40{q1sel[1]}} & { 5'b0,q1ecceff[8*5-1:1*5]}) |
                                  ({40{q1sel[2]}} & {10'b0,q1ecceff[8*5-1:2*5]}) |
                                  ({40{q1sel[3]}} & {15'b0,q1ecceff[8*5-1:3*5]}) |
                                  ({40{q1sel[4]}} & {20'b0,q1ecceff[8*5-1:4*5]}) |
                                  ({40{q1sel[5]}} & {25'b0,q1ecceff[8*5-1:5*5]}) |
                                  ({40{q1sel[6]}} & {30'b0,q1ecceff[8*5-1:6*5]}) |
                                  ({40{q1sel[7]}} & {35'b0,q1ecceff[8*5-1:7*5]}));

`else
   rvdffe #(8) q2parityff (.*, .en(qwen[2]), .din(ic_error_f2.parity[7:0]), .dout(q2parity[7:0]));
   rvdffe #(8) q1parityff (.*, .en(qwen[1]), .din(ic_error_f2.parity[7:0]), .dout(q1parity[7:0]));
   rvdffe #(8) q0parityff (.*, .en(qwen[0]), .din(ic_error_f2.parity[7:0]), .dout(q0parity[7:0]));


   assign {q1parityeff[7:0],q0parityeff[7:0]} = (({16{qren[0]}} & {q1parity[7:0],q0parity[7:0]}) |
                                                 ({16{qren[1]}} & {q2parity[7:0],q1parity[7:0]}) |
                                                 ({16{qren[2]}} & {q0parity[7:0],q2parity[7:0]}));

   assign q0parityfinal[7:0] =   (({8{q0sel[0]}} & {     q0parityeff[7:0]}) |
                                  ({8{q0sel[1]}} & {1'b0,q0parityeff[7:1]}) |
                                  ({8{q0sel[2]}} & {2'b0,q0parityeff[7:2]}) |
                                  ({8{q0sel[3]}} & {3'b0,q0parityeff[7:3]}) |
                                  ({8{q0sel[4]}} & {4'b0,q0parityeff[7:4]}) |
                                  ({8{q0sel[5]}} & {5'b0,q0parityeff[7:5]}) |
                                  ({8{q0sel[6]}} & {6'b0,q0parityeff[7:6]}) |
                                  ({8{q0sel[7]}} & {7'b0,q0parityeff[7]}));

   assign q1parityfinal[7:0] =   (({8{q1sel[0]}} & {     q1parityeff[7:0]}) |
                                  ({8{q1sel[1]}} & {1'b0,q1parityeff[7:1]}) |
                                  ({8{q1sel[2]}} & {2'b0,q1parityeff[7:2]}) |
                                  ({8{q1sel[3]}} & {3'b0,q1parityeff[7:3]}) |
                                  ({8{q1sel[4]}} & {4'b0,q1parityeff[7:4]}) |
                                  ({8{q1sel[5]}} & {5'b0,q1parityeff[7:5]}) |
                                  ({8{q1sel[6]}} & {6'b0,q1parityeff[7:6]}) |
                                  ({8{q1sel[7]}} & {7'b0,q1parityeff[7]}));
`endif // !`ifdef RV_ICACHE_ECC

   rvdffe #(128) q2ff (.*, .en(qwen[2]), .din(ifu_fetch_data[127:0]), .dout(q2[127:0]));
   rvdffe #(128) q1ff (.*, .en(qwen[1]), .din(ifu_fetch_data[127:0]), .dout(q1[127:0]));
   rvdffe #(128) q0ff (.*, .en(qwen[0]), .din(ifu_fetch_data[127:0]), .dout(q0[127:0]));


   assign {q1eff[127:0],q0eff[127:0]} = (({256{qren[0]}} & {q1[127:0],q0[127:0]}) |
                                         ({256{qren[1]}} & {q2[127:0],q1[127:0]}) |
                                         ({256{qren[2]}} & {q0[127:0],q2[127:0]}));

   assign q0final[127:0] = (({128{q0sel[0]}} & {             q0eff[8*16-1:16*0]}) |
                            ({128{q0sel[1]}} & {{16*1{1'b0}},q0eff[8*16-1:16*1]}) |
                            ({128{q0sel[2]}} & {{16*2{1'b0}},q0eff[8*16-1:16*2]}) |
                            ({128{q0sel[3]}} & {{16*3{1'b0}},q0eff[8*16-1:16*3]}) |
                            ({128{q0sel[4]}} & {{16*4{1'b0}},q0eff[8*16-1:16*4]}) |
                            ({128{q0sel[5]}} & {{16*5{1'b0}},q0eff[8*16-1:16*5]}) |
                            ({128{q0sel[6]}} & {{16*6{1'b0}},q0eff[8*16-1:16*6]}) |
                            ({128{q0sel[7]}} & {{16*7{1'b0}},q0eff[8*16-1:16*7]}));

   assign q1final[127:0] = (({128{q1sel[0]}} & {             q1eff[8*16-1:16*0]}) |
                            ({128{q1sel[1]}} & {{16*1{1'b0}},q1eff[8*16-1:16*1]}) |
                            ({128{q1sel[2]}} & {{16*2{1'b0}},q1eff[8*16-1:16*2]}) |
                            ({128{q1sel[3]}} & {{16*3{1'b0}},q1eff[8*16-1:16*3]}) |
                            ({128{q1sel[4]}} & {{16*4{1'b0}},q1eff[8*16-1:16*4]}) |
                            ({128{q1sel[5]}} & {{16*5{1'b0}},q1eff[8*16-1:16*5]}) |
                            ({128{q1sel[6]}} & {{16*6{1'b0}},q1eff[8*16-1:16*6]}) |
                            ({128{q1sel[7]}} & {{16*7{1'b0}},q1eff[8*16-1:16*7]}));


   assign aligndata[63:0] = ({64{(f0val[3])}} &                  {q0final[4*16-1:0]}) |
                            ({64{(f0val[2]&~f0val[3])}} &        {q1final[1*16-1:0],q0final[3*16-1:0]}) |
                            ({64{(f0val[1]&~f0val[2])}} &        {q1final[2*16-1:0],q0final[2*16-1:0]}) |
                            ({64{(f0val[0]&~f0val[1])}} &        {q1final[3*16-1:0],q0final[1*16-1:0]});

   assign alignval[3:0] =   ({4{(f0val[3])}} &                   4'b1111) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1val[0],3'b111}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1val[1:0],2'b11}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1val[2:0],1'b1});

   assign alignicaf[3:0] =   ({4{(f0val[3])}} &                   f0icaf[3:0]) |
                             ({4{(f0val[2]&~f0val[3])}} &        {f1icaf[0],f0icaf[2:0]}) |
                             ({4{(f0val[1]&~f0val[2])}} &        {f1icaf[1:0],f0icaf[1:0]}) |
                             ({4{(f0val[0]&~f0val[1])}} &        {f1icaf[2:0],f0icaf[0]});

   assign alignsbecc[3:0] =   ({4{(f0val[3])}} &                  {4{f0sbecc}}) |
                              ({4{(f0val[2]&~f0val[3])}} &        {{1{f1sbecc}},{3{f0sbecc}}}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {{2{f1sbecc}},{2{f0sbecc}}}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {{3{f1sbecc}},{1{f0sbecc}}});


   assign aligndbecc[3:0] =   ({4{(f0val[3])}} &                   f0dbecc[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1dbecc[0],f0dbecc[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1dbecc[1:0],f0dbecc[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1dbecc[2:0],f0dbecc[0]});

   // for branch prediction
   assign alignbrend[3:0] =   ({4{(f0val[3])}} &                   f0brend[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1brend[0],f0brend[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1brend[1:0],f0brend[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1brend[2:0],f0brend[0]});

   assign alignpc4[3:0] =   ({4{(f0val[3])}} &                   f0pc4[3:0]) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1pc4[0],f0pc4[2:0]}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1pc4[1:0],f0pc4[1:0]}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1pc4[2:0],f0pc4[0]});

`ifdef RV_ICACHE_ECC
   assign alignecc[19:0] =   ({20{(f0val[3])}} &                                    q0eccfinal[19:0]) |
                             ({20{(f0val[2]&~f0val[3])}} &        {q1eccfinal[4:0], q0eccfinal[14:0]}) |
                             ({20{(f0val[1]&~f0val[2])}} &        {q1eccfinal[9:0], q0eccfinal[9:0]}) |
                             ({20{(f0val[0]&~f0val[1])}} &        {q1eccfinal[14:0],q0eccfinal[4:0]});
`else
   assign alignparity[3:0] =   ({4{(f0val[3])}} &                                      q0parityfinal[3:0]) |
                               ({4{(f0val[2]&~f0val[3])}} &        {q1parityfinal[0],  q0parityfinal[2:0]}) |
                               ({4{(f0val[1]&~f0val[2])}} &        {q1parityfinal[1:0],q0parityfinal[1:0]}) |
                               ({4{(f0val[0]&~f0val[1])}} &        {q1parityfinal[2:0],q0parityfinal[0]});
`endif

   assign aligntagperr[3:0] =   ({4{(f0val[3])}} &                  {4{f0perr}}) |
                                ({4{(f0val[2]&~f0val[3])}} &        {{1{f1perr}},{3{f0perr}}}) |
                                ({4{(f0val[1]&~f0val[2])}} &        {{2{f1perr}},{2{f0perr}}}) |
                                ({4{(f0val[0]&~f0val[1])}} &        {{3{f1perr}},{1{f0perr}}});

   assign alignicfetch[3:0] =   ({4{(f0val[3])}} &                  {4{f0icfetch}}) |
                                ({4{(f0val[2]&~f0val[3])}} &        {{1{f1icfetch}},{3{f0icfetch}}}) |
                                ({4{(f0val[1]&~f0val[2])}} &        {{2{f1icfetch}},{2{f0icfetch}}}) |
                                ({4{(f0val[0]&~f0val[1])}} &        {{3{f1icfetch}},{1{f0icfetch}}});


   assign alignret[3:0] =   ({4{(f0val[3])}} &                   f0ret[3:0]) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1ret[0],f0ret[2:0]}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1ret[1:0],f0ret[1:0]}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1ret[2:0],f0ret[0]});

`ifdef RV_BTB_48

   logic [3:0]             f0way_b0, f0way_b1, alignway_b0, alignway_b1;
   logic [2:0]             f1way_b0, f1way_b1;
   assign f0way_b0[3:0] = {f0way[3][0], f0way[2][0], f0way[1][0], f0way[0][0]};
   assign f0way_b1[3:0] = {f0way[3][1], f0way[2][1], f0way[1][1], f0way[0][1]};
   assign f1way_b0[2:0] = {f1way[2][0], f1way[1][0], f1way[0][0]};
   assign f1way_b1[2:0] = {f1way[2][1], f1way[1][1], f1way[0][1]};

   assign alignway_b0[3:0] =   ({4{(f0val[3])}} &                   f0way_b0[3:0]) |
                               ({4{(f0val[2]&~f0val[3])}} &        {f1way_b0[0],  f0way_b0[2:0]}) |
                               ({4{(f0val[1]&~f0val[2])}} &        {f1way_b0[1:0],f0way_b0[1:0]}) |
                               ({4{(f0val[0]&~f0val[1])}} &        {f1way_b0[2:0],f0way_b0[0]});
   assign alignway_b1[3:0] =   ({4{(f0val[3])}} &                   f0way_b1[3:0]) |
                               ({4{(f0val[2]&~f0val[3])}} &        {f1way_b1[0],  f0way_b1[2:0]}) |
                               ({4{(f0val[1]&~f0val[2])}} &        {f1way_b1[1:0],f0way_b1[1:0]}) |
                               ({4{(f0val[0]&~f0val[1])}} &        {f1way_b1[2:0],f0way_b1[0]});
`else
   assign alignway[3:0] =   ({4{(f0val[3])}} &                   f0way[3:0]) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1way[0],f0way[2:0]}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1way[1:0],f0way[1:0]}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1way[2:0],f0way[0]});
`endif
   assign alignhist1[3:0] =   ({4{(f0val[3])}} &                   f0hist1[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1hist1[0],f0hist1[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1hist1[1:0],f0hist1[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1hist1[2:0],f0hist1[0]});

   assign alignhist0[3:0] =   ({4{(f0val[3])}} &                   f0hist0[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1hist0[0],f0hist0[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1hist0[1:0],f0hist0[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1hist0[2:0],f0hist0[0]});

   assign alignfromf1[3:1] =     ({3{(f0val[3])}} &                   3'b0) |
                                 ({3{(f0val[2]&~f0val[3])}} &        {1'b1,2'b0}) |
                                 ({3{(f0val[1]&~f0val[2])}} &        {2'b11,1'b0}) |
                                 ({3{(f0val[0]&~f0val[1])}} &        {3'b111});


   assign { secondpc[31:1],
            thirdpc[31:1],
            fourthpc[31:1] } =   ({3*31{(f0val[3])}}           & {f0pc_plus1[31:1], f0pc_plus2[31:1], f0pc_plus3[31:1]}) |
                                 ({3*31{(f0val[2]&~f0val[3])}} & {f0pc_plus1[31:1], f0pc_plus2[31:1], f1pc[31:1]}) |
                                 ({3*31{(f0val[1]&~f0val[2])}} & {f0pc_plus1[31:1], f1pc[31:1],       f1pc_plus1[31:1]})   |
                                 ({3*31{(f0val[0]&~f0val[1])}} & {f1pc[31:1],       f1pc_plus1[31:1], f1pc_plus2[31:1]});


   assign ifu_i0_pc[31:1] = f0pc[31:1];

   assign firstpc[31:1] = f0pc[31:1];

   assign ifu_i1_pc[31:1] = (first2B) ? secondpc[31:1] : thirdpc[31:1];


   assign ifu_i0_pc4 = first4B;

   assign ifu_i1_pc4 = (first2B & second4B) |
                       (first4B & third4B);

   // parity checking

`ifdef RV_ICACHE_ECC

   logic [3:0] [31:0] ic_corrected_data_nc;
   logic [3:0] [6:0]  ic_corrected_ecc_nc;
   logic [3:0]        ic_single_ecc_error;
   logic [3:0]        ic_double_ecc_error;
   logic [3:0]        aligneccerr;

  for (genvar i=0; i < 4 ; i++) begin : ic_ecc_error
   rvecc_decode  ecc_decode (
                           .en(~dec_tlu_core_ecc_disable),
                           .sed_ded(1'b1),
                           .din({16'b0, aligndata[16*(i+1)-1: (16*i)]}),
                           //.ecc_in({alignecc[(i*6)+5], 1'b0, alignecc[(i*6)+4:(i*6)]}),
                           .ecc_in({2'b0, alignecc[(i*5)+4:(i*5)]}),
                           .dout(ic_corrected_data_nc[i][31:0]),
                           .ecc_out(ic_corrected_ecc_nc[i][6:0]),
                           .single_ecc_error(ic_single_ecc_error[i]),
                           .double_ecc_error(ic_double_ecc_error[i]));

    // or the sb and db error detects into 1 signal called aligndataperr[i] where i corresponds to 2B position
   assign aligneccerr[i] = ic_single_ecc_error[i] | ic_double_ecc_error[i];
   assign aligndataperr[i] = aligneccerr[i] ;
  end // block: ic_ecc_error

`else // !`ifdef RV_ICACHE_ECC

  for (genvar i=0; i<4 ; i++) begin : ic_par_error
   rveven_paritycheck pchk (
                           .data_in(aligndata[16*(i+1)-1: 16*i]),
                           .parity_in(alignparity[i]),
                           .parity_err(aligndataperr[i])
                           );
  end

 `endif // !`ifdef RV_ICACHE_ECC

   // logic for trace
   assign ifu_i0_cinst[15:0] = aligndata[15:0];
   assign ifu_i1_cinst[15:0] = (first4B) ? aligndata[47:32] : aligndata[31:16];
   // end trace

   // check on 16B boundaries
   //
   assign first4B = aligndata[16*0+1:16*0] == 2'b11;
   assign first2B = ~first4B;

   assign second4B = aligndata[16*1+1:16*1] == 2'b11;
   assign second2B = ~second4B;

   assign third4B = aligndata[16*2+1:16*2] == 2'b11;
   assign third2B = ~third4B;

   assign ifu_i0_valid = ((first4B & alignval[1]) |
                          (first2B & alignval[0])) & ~exu_flush_final;

   assign ifu_i1_valid = ((first4B & third4B & alignval[3])  |
                          (first4B & third2B & alignval[2])  |
                          (first2B & second4B & alignval[2]) |
                          (first2B & second2B & alignval[1])) & ~exu_flush_final;

   // inst access fault on any byte of inst results in access fault for the inst
   assign ifu_i0_icaf = ((first4B & (|alignicaf[1:0])) |
                         (first2B &   alignicaf[0])) & ~exu_flush_final;



   assign icaf_eff[3:0] = alignicaf[3:0] | aligndbecc[3:0];

   assign ifu_i0_icaf_second = first4B & ~icaf_eff[0] & icaf_eff[1];

   assign ifu_i1_icaf = ((first4B & third4B &  (|alignicaf[3:2])) |
                         (first4B & third2B &    alignicaf[2])    |
                         (first2B & second4B & (|alignicaf[2:1])) |
                         (first2B & second2B &   alignicaf[1])) & ~exu_flush_final;

   assign ifu_i1_icaf_second = (first4B & third4B  & ~icaf_eff[2] & icaf_eff[3]) |
                               (first2B & second4B & ~icaf_eff[1] & icaf_eff[2]);

   // inst parity error on any byte of inst results in parity error for the inst


   assign alignfinalperr[3:0] = (aligntagperr[3:0] | aligndataperr[3:0]) & alignicfetch[3:0];

   assign ifu_i0_perr = ((first4B & (|alignfinalperr[1:0])) |
                         (first2B &   alignfinalperr[0])) & ~exu_flush_final;

   assign ifu_i1_perr = ((first4B & third4B &  (|alignfinalperr[3:2])) |
                         (first4B & third2B &    alignfinalperr[2])    |
                         (first2B & second4B & (|alignfinalperr[2:1])) |
                         (first2B & second2B &   alignfinalperr[1])) & ~exu_flush_final;

   assign ifu_i0_sbecc = ((first4B & (|alignsbecc[1:0])) |
                          (first2B &   alignsbecc[0])) & ~exu_flush_final;

   assign ifu_i1_sbecc = ((first4B & third4B &  (|alignsbecc[3:2])) |
                          (first4B & third2B &    alignsbecc[2])    |
                          (first2B & second4B & (|alignsbecc[2:1])) |
                          (first2B & second2B &   alignsbecc[1])) & ~exu_flush_final;

   assign ifu_i0_dbecc = ((first4B & (|aligndbecc[1:0])) |
                          (first2B &   aligndbecc[0])) & ~exu_flush_final;

   assign ifu_i1_dbecc = ((first4B & third4B &  (|aligndbecc[3:2])) |
                          (first4B & third2B &    aligndbecc[2])    |
                          (first2B & second4B & (|aligndbecc[2:1])) |
                          (first2B & second2B &   aligndbecc[1])) & ~exu_flush_final;

   // send index information to the icache on a parity or single-bit ecc error
   // parity error is orthogonal to single-bit ecc error; icache vs iccm

   logic [2:0]  alignicerr;

   assign alignicerr[2:0] = alignfinalperr[2:0] | alignsbecc[2:0];

   assign ifu_icache_error_index[16:2] = (alignicerr[0]) ?  firstpc[16:2] :
                                          (alignicerr[1]) ? secondpc[16:2] :
                                          (alignicerr[2]) ?  thirdpc[16:2] :
                                                            fourthpc[16:2];

   assign ifu_icache_error_val = (i0_shift & ifu_i0_perr) |
                                 (i1_shift & ifu_i1_perr & ~ifu_i0_sbecc);

   assign ifu_icache_sb_error_val = (i0_shift & ifu_i0_sbecc) |
                                    (i1_shift & ifu_i1_sbecc & ~ifu_i0_perr);

`ifdef ASSERT_ON
   assert_ifu_icache_parity_with_sbecc_error:   assert #0 ($onehot0({ifu_icache_error_val,ifu_icache_sb_error_val}));
`endif
   // big endian 4B instructions


   assign ifirst[31:0] =  aligndata[2*16-1:0*16];

   assign isecond[31:0] = aligndata[3*16-1:1*16];

   assign ithird[31:0] =  aligndata[4*16-1:2*16];



   assign ifu_i0_instr[31:0] = ({32{first4B}} & ifirst[31:0]) |
                               ({32{first2B}} & uncompress0[31:0]);


   assign ifu_i1_instr[31:0] = ({32{first4B & third4B}} & ithird[31:0]) |
                               ({32{first4B & third2B}} & uncompress2[31:0]) |
                               ({32{first2B & second4B}} & isecond[31:0]) |
                               ({32{first2B & second2B}} & uncompress1[31:0]);

   // if you detect br does not start on instruction boundary

   rvbtb_addr_hash firsthash(.pc(firstpc[31:1]), .hash(firstpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash secondhash(.pc(secondpc[31:1]), .hash(secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash thirdhash(.pc(thirdpc[31:1]), .hash(thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash fourthhash(.pc(fourthpc[31:1]), .hash(fourthpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));

   logic [`RV_BTB_BTAG_SIZE-1:0] firstbrtag_hash, secondbrtag_hash, thirdbrtag_hash, fourthbrtag_hash;

   rvbtb_tag_hash first_brhash(.pc(firstpc[31:1]), .hash(firstbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));
   rvbtb_tag_hash second_brhash(.pc(secondpc[31:1]), .hash(secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));
   rvbtb_tag_hash third_brhash(.pc(thirdpc[31:1]), .hash(thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));
   rvbtb_tag_hash fourth_brhash(.pc(fourthpc[31:1]), .hash(fourthbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));

   // start_indexing - you want pc to be based on where the end of branch is prediction
   // normal indexing pc based that's incorrect now for pc4 cases it's pc4 + 2

   always_comb begin

      i0_brp = '0;

      i0_br_start_error = (first4B & alignval[1] & alignbrend[0]);

      i0_brp.valid = (first2B & alignbrend[0]) |
                     (first4B & alignbrend[1]) |
                     i0_br_start_error;

      i0_brp_pc4 = (first2B & alignpc4[0]) |
                   (first4B & alignpc4[1]);

      i0_brp.ret = (first2B & alignret[0]) |
                   (first4B & alignret[1]);

`ifdef RV_BTB_48
      i0_brp.way = (first2B | alignbrend[0]) ? {alignway_b1[0], alignway_b0[0]} : {alignway_b1[1], alignway_b0[1]};
`else
      i0_brp.way = (first2B | alignbrend[0]) ? alignway[0] : alignway[1];
`endif
      i0_brp.hist[1] = (first2B & alignhist1[0]) |
                       (first4B & alignhist1[1]);

      i0_brp.hist[0] = (first2B & alignhist0[0]) |
                       (first4B & alignhist0[1]);

      i0_ends_f1 = (first4B & alignfromf1[1]);

      i0_brp.toffset[11:0] = (i0_ends_f1) ? f1poffset[11:0] : f0poffset[11:0];

      i0_brp.fghr[`RV_BHT_GHR_RANGE] = (i0_ends_f1) ? f1fghr[`RV_BHT_GHR_RANGE] : f0fghr[`RV_BHT_GHR_RANGE];

      i0_brp.prett[31:1] = (i0_ends_f1) ? f1prett[31:1] : f0prett[31:1];

      i0_brp.br_start_error = i0_br_start_error;

      i0_brp.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = (first2B | alignbrend[0]) ? firstpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]:
                                                                                  secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

      i0_brp.btag[`RV_BTB_BTAG_SIZE-1:0] = (first2B | alignbrend[0]) ? firstbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]:
                                                                       secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0];

      i0_brp.bank[1:0] = (first2B | alignbrend[0]) ? firstpc[3:2] :
                                                     secondpc[3:2];


      i0_brp.br_error = (i0_brp.valid &  i0_brp_pc4 &  first2B) |
                        (i0_brp.valid & ~i0_brp_pc4 &  first4B);

      i1_brp = '0;

      i1_br_start_error = (first2B & second4B & alignval[2] & alignbrend[1]) |
                          (first4B & third4B  & alignval[3] & alignbrend[2]);

      i1_brp.valid = (first4B & third2B & alignbrend[2]) |
                     (first4B & third4B & alignbrend[3]) |
                     (first2B & second2B & alignbrend[1]) |
                     (first2B & second4B & alignbrend[2]) |
                     i1_br_start_error;

      i1_brp_pc4 = (first4B & third2B & alignpc4[2]) |
                   (first4B & third4B & alignpc4[3]) |
                   (first2B & second2B & alignpc4[1]) |
                   (first2B & second4B & alignpc4[2]);

      i1_brp.ret = (first4B & third2B & alignret[2]) |
                   (first4B & third4B & alignret[3]) |
                   (first2B & second2B & alignret[1]) |
                   (first2B & second4B & alignret[2]);
`ifdef RV_BTB_48
      i1_brp.way = ({2{first4B & third2B                  }} & {alignway_b1[2], alignway_b0[2]} ) |
                   ({2{first4B & third4B &  alignbrend[2] }} & {alignway_b1[2], alignway_b0[2]} ) |
                   ({2{first4B & third4B & ~alignbrend[2] }} & {alignway_b1[3], alignway_b0[3]} ) |
                   ({2{first2B & second2B                 }} & {alignway_b1[1], alignway_b0[1]} ) |
                   ({2{first2B & second4B &  alignbrend[1]}} & {alignway_b1[1], alignway_b0[1]} ) |
                   ({2{first2B & second4B & ~alignbrend[1]}} & {alignway_b1[2], alignway_b0[2]} );
`else
      i1_brp.way = (first4B & third2B                   & alignway[2] ) |
                   (first4B & third4B &  alignbrend[2]  & alignway[2] ) |
                   (first4B & third4B & ~alignbrend[2]  & alignway[3] ) |
                   (first2B & second2B                  & alignway[1] ) |
                   (first2B & second4B &  alignbrend[1] & alignway[1] ) |
                   (first2B & second4B & ~alignbrend[1] & alignway[2] );
`endif
      i1_brp.hist[1] = (first4B & third2B & alignhist1[2]) |
                       (first4B & third4B & alignhist1[3]) |
                       (first2B & second2B & alignhist1[1]) |
                       (first2B & second4B & alignhist1[2]);

      i1_brp.hist[0] = (first4B & third2B & alignhist0[2]) |
                       (first4B & third4B & alignhist0[3]) |
                       (first2B & second2B & alignhist0[1]) |
                       (first2B & second4B & alignhist0[2]);

      i1_ends_f1 = (first4B & third2B & alignfromf1[2]) |
                   (first4B & third4B & alignfromf1[3]) |
                   (first2B & second2B & alignfromf1[1]) |
                   (first2B & second4B & alignfromf1[2]);

      i1_brp.toffset[11:0] = (i1_ends_f1) ? f1poffset[11:0] : f0poffset[11:0];

      i1_brp.fghr[`RV_BHT_GHR_RANGE] = (i1_ends_f1) ? f1fghr[`RV_BHT_GHR_RANGE] : f0fghr[`RV_BHT_GHR_RANGE];

      i1_brp.prett[31:1] = (i1_ends_f1) ? f1prett[31:1] : f0prett[31:1];

      i1_brp.br_start_error = i1_br_start_error;

`define RV_BTB_RANGE  `RV_BTB_ADDR_HI-`RV_BTB_ADDR_LO+1

      i1_brp.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = ({`RV_BTB_RANGE{first4B & third2B }}                  & thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first4B & third4B &  alignbrend[2] }} & thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first4B & third4B & ~alignbrend[2] }} & fourthpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first2B & second2B}}                  & secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first2B & second4B &  alignbrend[1]}} & secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first2B & second4B & ~alignbrend[1]}} & thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] );

      i1_brp.btag[`RV_BTB_BTAG_SIZE-1:0] = ({`RV_BTB_BTAG_SIZE{first4B & third2B }}                  &  thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first4B & third4B &  alignbrend[2] }} &  thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first4B & third4B & ~alignbrend[2] }} & fourthbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first2B & second2B}}                  & secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first2B & second4B &  alignbrend[1]}} & secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first2B & second4B & ~alignbrend[1]}} &  thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] );

      i1_brp.bank[1:0] = ({2{first4B & third2B }}                  & thirdpc[3:2] ) |
                         ({2{first4B & third4B &  alignbrend[2] }} & thirdpc[3:2] ) |
                         ({2{first4B & third4B & ~alignbrend[2] }} & fourthpc[3:2] ) |
                         ({2{first2B & second2B}}                  & secondpc[3:2] ) |
                         ({2{first2B & second4B &  alignbrend[1]}} & secondpc[3:2] ) |
                         ({2{first2B & second4B & ~alignbrend[1]}} & thirdpc[3:2] );

      i1_brp.br_error = (i1_brp.valid &  i1_brp_pc4 & first4B & third2B ) |
                        (i1_brp.valid & ~i1_brp_pc4 & first4B & third4B ) |
                        (i1_brp.valid &  i1_brp_pc4 & first2B & second2B) |
                        (i1_brp.valid & ~i1_brp_pc4 & first2B & second4B);
   end

// figure out 2B illegal insts

   assign i0_illegal = (first2B & ~first_legal);

   assign i1_illegal = (first2B & second2B & ~second_legal) |
                       (first4B & third2B & ~third_legal);

   assign shift_illegal = (i0_shift & i0_illegal) |
                          (i1_shift & i1_illegal);

   assign illegal_inst[15:0] =   (first2B & ~first_legal)             ? aligndata[1*16-1:0*16] :
                                ((first2B & second2B & ~second_legal) ? aligndata[2*16-1:1*16] : aligndata[3*16-1:2*16]);

   assign illegal_inst_en = shift_illegal & ~illegal_lockout;

   rvdffe #(16) illegal_any_ff (.*, .en(illegal_inst_en), .din(illegal_inst[15:0]), .dout(ifu_illegal_inst[15:0]));

   assign illegal_lockout_in = (shift_illegal | illegal_lockout) & ~exu_flush_final;

   rvdff #(1) illegal_lockout_any_ff (.*, .clk(active_clk), .din(illegal_lockout_in), .dout(illegal_lockout));


   // decompress

   ifu_compress_ctl compress0 (.din(aligndata[16*1-1:0*16]), .dout(uncompress0[31:0]), .legal(first_legal)  );

   ifu_compress_ctl compress1 (.din(aligndata[16*2-1:1*16]), .dout(uncompress1[31:0]), .legal(second_legal) );

   ifu_compress_ctl compress2 (.din(aligndata[16*3-1:2*16]), .dout(uncompress2[31:0]), .legal(third_legal)  );



   assign i0_shift = ifu_i0_valid & ibuffer_room1_more;

   assign i1_shift = ifu_i1_valid & ibuffer_room2_more;

   if (DEC_INSTBUF_DEPTH==4) begin
      assign ibuffer_room1_more = ~dec_ib3_valid_d;
      assign ibuffer_room2_more = ~dec_ib2_valid_d;
   end
   else begin
      assign ibuffer_room1_more = ~dec_ib0_valid_eff_d | ~dec_ib1_valid_eff_d;
      assign ibuffer_room2_more = ~dec_ib0_valid_eff_d & ~dec_ib1_valid_eff_d;
   end



   assign ifu_pmu_instr_aligned[1:0] = { i1_shift, i0_shift };

   assign ifu_pmu_align_stall = ifu_i0_valid & ~ibuffer_room1_more;

   // compute how many bytes are being shifted from f0

   // assign shift_0B = ~i0_shift;

   assign shift_2B = i0_shift & ~i1_shift & first2B;


   assign shift_4B = (i0_shift & ~i1_shift & first4B) |
                     (i0_shift &  i1_shift & first2B & second2B);

   assign shift_6B = (i0_shift &  i1_shift & first2B & second4B) |
                     (i0_shift &  i1_shift & first4B & third2B);

   assign shift_8B = i0_shift &  i1_shift & first4B & third4B;

   // exact equations for the queue logic
   assign f0_shift_2B = (shift_2B & f0val[0]) |
                        ((shift_4B | shift_6B | shift_8B) & f0val[0] & ~f0val[1]);

   assign f0_shift_4B = (shift_4B & f0val[1]) |
                        ((shift_6B & shift_8B) & f0val[1] & ~f0val[2]);


   assign f0_shift_6B = (shift_6B & f0val[2]) |
                        (shift_8B & f0val[2] & ~f0val[3]);

   assign f0_shift_8B =  shift_8B & f0val[3];



   // f0 valid states
   //
   // 11111111
   // 11111110
   // 11111100
   // 11111000
   // 11110000

   // 11100000
   // 11000000
   // 10000000
   // 00000000

   // assign f1_shift_0B = shift_0B;

   assign f1_shift_2B = (f0val[2] & ~f0val[3] & shift_8B) |
                        (f0val[1] & ~f0val[2] & shift_6B) |
                        (f0val[0] & ~f0val[1] & shift_4B);

   assign f1_shift_4B = (f0val[1] & ~f0val[2] & shift_8B) |
                        (f0val[0] & ~f0val[1] & shift_6B);

   assign f1_shift_6B = (f0val[0] & ~f0val[1] & shift_8B);



endmodule

