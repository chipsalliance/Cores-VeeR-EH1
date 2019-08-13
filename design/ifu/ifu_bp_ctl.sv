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
// Function: Branch predictor
// Comments: 
//           
//
//  Bank3 : Bank2 : Bank1 : Bank0
//  FA  C       8       4       0
//********************************************************************************

module ifu_bp_ctl
   import swerv_types::*;
(
                    
   input logic clk,
   input logic active_clk,
   input logic clk_override,
   input logic rst_l,

   input logic ic_hit_f2,      // Icache hit, enables F2 address capture

   input logic [31:1] ifc_fetch_addr_f1, // look up btb address
   input logic [31:1] ifc_fetch_addr_f2, // to tgt calc
   input logic ifc_fetch_req_f1,  // F1 valid
   input logic ifc_fetch_req_f2,  // F2 valid

   input br_tlu_pkt_t dec_tlu_br0_wb_pkt, // BP commit update packet, includes errors
   input br_tlu_pkt_t dec_tlu_br1_wb_pkt, // BP commit update packet, includes errors
   
   input logic dec_tlu_flush_lower_wb, // used to move EX4 RS to EX1 and F
   input logic dec_tlu_flush_leak_one_wb, // don't hit for leak one fetches

   input logic dec_tlu_bpred_disable, // disable all branch prediction          
 
   input logic        exu_i0_br_ret_e4, // EX4 ret stack update
   input logic        exu_i1_br_ret_e4, // EX4 ret stack update
   input logic        exu_i0_br_call_e4, // EX4 ret stack update
   input logic        exu_i1_br_call_e4, // EX4 ret stack update

   input predict_pkt_t  exu_mp_pkt, // mispredict packet
   
   input rets_pkt_t exu_rets_e1_pkt, // EX1 rets packet
   input rets_pkt_t exu_rets_e4_pkt, // EX4 rets packet

`ifdef REAL_COMM_RS
   input logic [31:1] exu_i0_pc_e1, // Used for RS computation
   input logic [31:1] exu_i1_pc_e1, // Used for RS computation
   input logic [31:1] dec_tlu_i0_pc_e4,  // Used for RS computation
   input logic [31:1] dec_tlu_i1_pc_e4,  // Used for RS computation
`endif

   input logic [`RV_BHT_GHR_RANGE] exu_mp_eghr, // execute ghr (for patching fghr)

   input logic exu_flush_final, // all flushes
   input logic exu_flush_upper_e2, // flush upper, either i0 or i1, cp EX1 RS to F RS
   
   output logic ifu_bp_kill_next_f2, // kill next fetch, taken target found
   output logic [31:1] ifu_bp_btb_target_f2, //  predicted target PC
   output logic [7:1] ifu_bp_inst_mask_f2, // tell ic which valids to kill because of a taken branch, right justified

   output logic [`RV_BHT_GHR_RANGE] ifu_bp_fghr_f2, // fetch ghr

`ifdef RV_BTB_48
   output logic [7:0][1:0] ifu_bp_way_f2, // way
`else
   output logic [7:0] ifu_bp_way_f2, // way
`endif
   output logic [7:0] ifu_bp_ret_f2, // predicted ret
   output logic [7:0] ifu_bp_hist1_f2, // history counters for all 4 potential branches, bit 1, right justified
   output logic [7:0] ifu_bp_hist0_f2, // history counters for all 4 potential branches, bit 0, right justified
   output logic [11:0] ifu_bp_poffset_f2, // predicted target
   output logic [7:0] ifu_bp_pc4_f2, // pc4 indication, right justified
   output logic [7:0] ifu_bp_valid_f2, // branch valid, right justified

   input  logic       scan_mode
   );

`define TAG 16+`RV_BTB_BTAG_SIZE:17

   localparam PC4=4;
   localparam BOFF=3;
   localparam CALL=2;
   localparam RET=1;
   localparam BV=0;

   localparam LRU_SIZE=`RV_BTB_ARRAY_DEPTH;
   localparam NUM_BHT_LOOP = (`RV_BHT_ARRAY_DEPTH > 16 ) ? 16 : `RV_BHT_ARRAY_DEPTH;
   localparam NUM_BHT_LOOP_INNER_HI =  (`RV_BHT_ARRAY_DEPTH > 16 ) ?`RV_BHT_ADDR_LO+3 : `RV_BHT_ADDR_HI;
   localparam NUM_BHT_LOOP_OUTER_LO =  (`RV_BHT_ARRAY_DEPTH > 16 ) ?`RV_BHT_ADDR_LO+4 : `RV_BHT_ADDR_LO;
   localparam BHT_NO_ADDR_MATCH  = ( `RV_BHT_ARRAY_DEPTH <= 16 );
   
   logic exu_mp_valid_write;
   logic exu_mp_ataken;
   logic exu_mp_valid; // conditional branch mispredict
   logic exu_mp_boffset; // branch offsett
   logic exu_mp_pc4; // branch is a 4B inst
   logic exu_mp_call; // branch is a call inst
   logic exu_mp_ret; // branch is a ret inst
   logic exu_mp_ja; // branch is a jump always
   logic [1:0] exu_mp_hist; // new history
   logic [11:0] exu_mp_tgt; // target offset
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_mp_addr; // BTB/BHT address
   logic [1:0]                             exu_mp_bank; // write bank; based on branch PC[3:2]
   logic [`RV_BTB_BTAG_SIZE-1:0]           exu_mp_btag; // branch tag
   logic [`RV_BHT_GHR_RANGE]               exu_mp_fghr; // original fetch ghr (for bht update)
   logic                                   dec_tlu_br0_v_wb; // WB stage history update
   logic [1:0]                             dec_tlu_br0_hist_wb; // new history
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] dec_tlu_br0_addr_wb; // addr
   logic [1:0]                             dec_tlu_br0_bank_wb; // write bank; based on branch PC[3:2]
   logic                                   dec_tlu_br0_error_wb; // error; invalidate bank
   logic                                   dec_tlu_br0_start_error_wb; // error; invalidate all 4 banks in fg
   logic [`RV_BHT_GHR_RANGE]               dec_tlu_br0_fghr_wb;
   
   logic                                   dec_tlu_br1_v_wb; // WB stage history update
   logic [1:0]                             dec_tlu_br1_hist_wb; // new history
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] dec_tlu_br1_addr_wb; // addr
   logic [1:0]                             dec_tlu_br1_bank_wb; // write bank; based on branch PC[3:2]
   logic                                   dec_tlu_br1_error_wb; // error
   logic                                   dec_tlu_br1_start_error_wb; // error; invalidate all 4 banks in fg
   logic [`RV_BHT_GHR_RANGE]               dec_tlu_br1_fghr_wb;

   logic [3:0]        use_mp_way;
   logic [`RV_RET_STACK_SIZE-1:0][31:1] rets_out, rets_in, e1_rets_out, e1_rets_in, e4_rets_out, e4_rets_in;
   logic [`RV_RET_STACK_SIZE-1:0]       rsenable;
   

   logic [11:0]       btb_rd_tgt_f2;
   logic              btb_rd_pc4_f2, btb_rd_boffset_f2,  btb_rd_call_f2, btb_rd_ret_f2;
   logic [3:1]        bp_total_branch_offset_f2;

   logic [31:1]       bp_btb_target_adder_f2;
   logic [31:1]       bp_rs_call_target_f2;
   logic              rs_push, rs_pop, rs_hold;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] btb_rd_addr_f1, btb_wr_addr, btb_rd_addr_f2;
   logic [`RV_BTB_BTAG_SIZE-1:0] btb_wr_tag, fetch_rd_tag_f1, fetch_rd_tag_f2;
   logic [16+`RV_BTB_BTAG_SIZE:0]        btb_wr_data;
   logic [3:0]         btb_wr_en_way0, btb_wr_en_way1;

   
   logic               dec_tlu_error_wb, dec_tlu_all_banks_error_wb, btb_valid, dec_tlu_br0_middle_wb, dec_tlu_br1_middle_wb;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]        btb_error_addr_wb;
   logic [1:0]         dec_tlu_error_bank_wb;
   logic branch_error_collision_f1, fetch_mp_collision_f1, fetch_mp_collision_f2;

   logic [6:0] fgmask_f2;
   logic [3:0] branch_error_bank_conflict_f1, branch_error_bank_conflict_f2;
   logic [`RV_BHT_GHR_RANGE] merged_ghr, fghr_ns, fghr;
   logic [3:0] num_valids;
   logic [LRU_SIZE-1:0] btb_lru_b0_f, btb_lru_b0_hold, btb_lru_b0_ns, btb_lru_b1_f, btb_lru_b1_hold, btb_lru_b1_ns, 
                        btb_lru_b2_f, btb_lru_b2_hold, btb_lru_b2_ns, btb_lru_b3_f, btb_lru_b3_hold, btb_lru_b3_ns, 
                        fetch_wrindex_dec, fetch_wrlru_b0, fetch_wrlru_b1, fetch_wrlru_b2, fetch_wrlru_b3,
                        mp_wrindex_dec, mp_wrlru_b0, mp_wrlru_b1, mp_wrlru_b2, mp_wrlru_b3;
   logic [3:0]          btb_lru_rd_f2, mp_bank_decoded, mp_bank_decoded_f, lru_update_valid_f2; 
   logic [3:0] tag_match_way0_f2, tag_match_way1_f2;
   logic [7:0] way_raw, bht_dir_f2, btb_sel_f2, wayhit_f2;
   logic [7:0] btb_sel_mask_f2, bht_valid_f2, bht_force_taken_f2;

   logic leak_one_f1, leak_one_f2, ifc_fetch_req_f2_raw;

   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank0_rd_data_way0_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank1_rd_data_way0_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank2_rd_data_way0_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank3_rd_data_way0_out ;
                                                 
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank0_rd_data_way1_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank1_rd_data_way1_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank2_rd_data_way1_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank3_rd_data_way1_out ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way0_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way0_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way0_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way0_f2_in ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way1_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way1_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way1_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way1_f2_in ;

   
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way0_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way0_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way0_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way0_f2 ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way1_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way1_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way1_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way1_f2 ;

   logic                                         final_h;
   logic                                         btb_fg_crossing_f2;
   logic                                         rs_correct;
   logic                                         middle_of_bank;

`ifdef RV_BTB_48
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way2_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way2_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way2_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way2_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way2_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way2_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way2_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way2_f2 ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank0_rd_data_way2_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank1_rd_data_way2_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank2_rd_data_way2_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank3_rd_data_way2_out ;
   logic [3:0]                                   btb_wr_en_way2, tag_match_way2_f2, fetch_lru_bank_hit_f2;
   logic [7:0]                                   tag_match_way2_expanded_f2;

   logic [1:0] exu_mp_way, exu_mp_way_f, dec_tlu_br0_way_wb, dec_tlu_br1_way_wb, dec_tlu_way_wb, dec_tlu_way_wb_f; 

`else // !`ifdef RV_BTB_48
   logic exu_mp_way, exu_mp_way_f, dec_tlu_br0_way_wb, dec_tlu_br1_way_wb, dec_tlu_way_wb, dec_tlu_way_wb_f; 

`endif
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0e_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1e_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2e_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3e_rd_data_f2 ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0o_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1o_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2o_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3o_rd_data_f2 ;

   logic [7:0] tag_match_way0_expanded_f2, tag_match_way1_expanded_f2;


    logic [1:0]                                  bht_bank0_rd_data_f2 ;              
    logic [1:0]                                  bht_bank1_rd_data_f2 ;              
    logic [1:0]                                  bht_bank2_rd_data_f2 ;              
    logic [1:0]                                  bht_bank3_rd_data_f2 ;              
    logic [1:0]                                  bht_bank4_rd_data_f2 ;              
    logic [1:0]                                  bht_bank5_rd_data_f2 ;              
    logic [1:0]                                  bht_bank6_rd_data_f2 ;              
    logic [1:0]                                  bht_bank7_rd_data_f2 ;              
   
   assign exu_mp_valid = exu_mp_pkt.misp & ~leak_one_f2; // conditional branch mispredict
   assign exu_mp_boffset = exu_mp_pkt.boffset;  // branch offset
   assign exu_mp_pc4 = exu_mp_pkt.pc4;  // branch is a 4B inst
   assign exu_mp_call = exu_mp_pkt.pcall;  // branch is a call inst
   assign exu_mp_ret = exu_mp_pkt.pret;  // branch is a ret inst
   assign exu_mp_ja = exu_mp_pkt.pja;  // branch is a jump always
   assign exu_mp_way = exu_mp_pkt.way;  // repl way
   assign exu_mp_hist[1:0] = exu_mp_pkt.hist[1:0];  // new history
   assign exu_mp_tgt[11:0]  = exu_mp_pkt.toffset[11:0] ;  // target offset
   assign exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]  = exu_mp_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ;  // BTB/BHT address
   assign exu_mp_bank[1:0]  = exu_mp_pkt.bank[1:0] ;  // write bank = exu_mp_pkt.;  based on branch PC[3:2]
   assign exu_mp_btag[`RV_BTB_BTAG_SIZE-1:0]  = exu_mp_pkt.btag[`RV_BTB_BTAG_SIZE-1:0] ;  // branch tag
   assign exu_mp_fghr[`RV_BHT_GHR_RANGE]  = exu_mp_pkt.fghr[`RV_BHT_GHR_RANGE] ;  // original fetch ghr (for bht update)
   assign exu_mp_ataken = exu_mp_pkt.ataken;
   
   assign dec_tlu_br0_v_wb = dec_tlu_br0_wb_pkt.valid; 
   assign dec_tlu_br0_hist_wb[1:0]  = dec_tlu_br0_wb_pkt.hist[1:0];
   assign dec_tlu_br0_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = dec_tlu_br0_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign dec_tlu_br0_bank_wb[1:0]  = dec_tlu_br0_wb_pkt.bank[1:0];
   assign dec_tlu_br0_error_wb = dec_tlu_br0_wb_pkt.br_error;
   assign dec_tlu_br0_middle_wb = dec_tlu_br0_wb_pkt.middle;
   assign dec_tlu_br0_way_wb = dec_tlu_br0_wb_pkt.way;
   assign dec_tlu_br0_start_error_wb = dec_tlu_br0_wb_pkt.br_start_error;
   assign dec_tlu_br0_fghr_wb[`RV_BHT_GHR_RANGE] = dec_tlu_br0_wb_pkt.fghr[`RV_BHT_GHR_RANGE];

   assign dec_tlu_br1_v_wb = dec_tlu_br1_wb_pkt.valid; 
   assign dec_tlu_br1_hist_wb[1:0]  = dec_tlu_br1_wb_pkt.hist[1:0];
   assign dec_tlu_br1_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = dec_tlu_br1_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign dec_tlu_br1_bank_wb[1:0]  = dec_tlu_br1_wb_pkt.bank[1:0];
   assign dec_tlu_br1_middle_wb = dec_tlu_br1_wb_pkt.middle;
   assign dec_tlu_br1_error_wb = dec_tlu_br1_wb_pkt.br_error;
   assign dec_tlu_br1_way_wb = dec_tlu_br1_wb_pkt.way;
   assign dec_tlu_br1_start_error_wb = dec_tlu_br1_wb_pkt.br_start_error;
   assign  dec_tlu_br1_fghr_wb[`RV_BHT_GHR_RANGE] = dec_tlu_br1_wb_pkt.fghr[`RV_BHT_GHR_RANGE];



   // ----------------------------------------------------------------------
   // READ
   // ----------------------------------------------------------------------


   // hash the incoming fetch PC, first guess at hashing algorithm
   rvbtb_addr_hash f1hash(.pc(ifc_fetch_addr_f1[31:1]), .hash(btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash f2hash(.pc(ifc_fetch_addr_f2[31:1]), .hash(btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));

   
   // based on the fetch group offset(PC[3:2]) and direction bits, findfirst from fetchPC
   // this sel is zero/onehot
   // Put the table below in a file and run espresso to generate the btb_sel_f2 and btb_vmask_raw_f2 equations
   // espresso -oeqntott -eeat <file> | addassign
//
// .i 11
// .o 15
// .ilb ifc_fetch_addr_f2[3] ifc_fetch_addr_f2[2] ifc_fetch_addr_f2[1] bht_dir_f2[7] bht_dir_f2[6] bht_dir_f2[5] bht_dir_f2[4] bht_dir_f2[3] bht_dir_f2[2] bht_dir_f2[1] bht_dir_f2[0]
// .ob btb_sel_f2[7] btb_sel_f2[6] btb_sel_f2[5] btb_sel_f2[4] btb_sel_f2[3] btb_sel_f2[2] btb_sel_f2[1] btb_sel_f2[0] btb_vmask_raw_f2[7] btb_vmask_raw_f2[6] btb_vmask_raw_f2[5] btb_vmask_raw_f2[4] btb_vmask_raw_f2[3] btb_vmask_raw_f2[2] btb_vmask_raw_f2[1] 
// .type fr
// ##faddress[3:1] dir[7:0] sel[7:0] mask[7:1]
// 000             -------1 00000001 0000000
// 000             ------10 00000010 0000001
// 000             -----100 00000100 0000010
// 000             ----1000 00001000 0000100 
// 000             ---10000 00010000 0001000
// 000             --100000 00100000 0010000
// 000             -1000000 01000000 0100000
// 000             10000000 10000000 1000000
//                 
// 001             ------1- 00000010 0000000
// 001             -----10- 00000100 0000001
// 001             ----100- 00001000 0000010
// 001             ---1000- 00010000 0000100
// 001             --10000- 00100000 0001000
// 001             -100000- 01000000 0010000
// 001             1000000- 10000000 0110000
//                 
// 010             -----1-- 00000100 0000000
// 010             ----10-- 00001000 0000001
// 010             ---100-- 00010000 0000010
// 010             --1000-- 00100000 0000100
// 010             -10000-- 01000000 0001000
// 010             100000-- 10000000 0010000
//                 
// 011             ----1--- 00001000 0000000
// 011             ---10--- 00010000 0000001
// 011             --100--- 00100000 0000010
// 011             -1000--- 01000000 0000100
// 011             10000--- 10000000 0001000
//                 
// 100             ---1---- 00010000 0000000
// 100             --10---- 00100000 0000001
// 100             -100---- 01000000 0000010
// 100             1000---- 10000000 0000100
//                 
// 101             --1----- 00100000 0000000
// 101             -10----- 01000000 0000001
// 101             100----- 10000000 0000010
//                                       
// 110             -1------ 01000000 0000000
// 110             10------ 10000000 0000001
//                                       
// 111             1------- 10000000 0000000



assign btb_sel_f2[7] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]
     & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5]) | (ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]) | (
    ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]);
assign btb_sel_f2[6] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3]) | (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5]) | (ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[6]);
assign btb_sel_f2[5] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4]) | (ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[5]);
assign btb_sel_f2[4] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3]) | (ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[4]);
assign btb_sel_f2[3] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]
     & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[3] & ~bht_dir_f2[2]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[3]);
assign btb_sel_f2[2] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[2] & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[2]);
assign btb_sel_f2[1] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[1]);
assign btb_sel_f2[0] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[0]);



   // vmask[0] is always 1
logic [7:0] btb_vmask_raw_f2;
assign btb_vmask_raw_f2[7] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]);
assign btb_vmask_raw_f2[6] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]);
assign btb_vmask_raw_f2[5] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]
     & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1] & ~bht_dir_f2[0]);
assign btb_vmask_raw_f2[4] = (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3]) | (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[6]
     & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1]);
assign btb_vmask_raw_f2[3] = (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]);
assign btb_vmask_raw_f2[2] = (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]);
assign btb_vmask_raw_f2[1] = (ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]) | (ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[6]
     & ~bht_dir_f2[5]) | (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[1] & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[4]
     & ~bht_dir_f2[3]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[2] & ~bht_dir_f2[1]);

   // end of espresso generated equations

   
   logic[7:1] btb_vmask_f2;
   assign btb_vmask_f2[7:1] = {btb_vmask_raw_f2[7],
                              |btb_vmask_raw_f2[7:6],
                              |btb_vmask_raw_f2[7:5],
                              |btb_vmask_raw_f2[7:4],
                              |btb_vmask_raw_f2[7:3],
                              |btb_vmask_raw_f2[7:2],
                              |btb_vmask_raw_f2[7:1]};
                              

   // Errors colliding with fetches must kill the btb/bht hit.

   assign branch_error_collision_f1 = dec_tlu_error_wb & (btb_error_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]);
   assign branch_error_bank_conflict_f1[3:0] = {4{branch_error_collision_f1}} & (decode2_4(dec_tlu_error_bank_wb[1:0]) | {4{dec_tlu_all_banks_error_wb}});
   
   assign fetch_mp_collision_f1 = ( (exu_mp_btag[`RV_BTB_BTAG_SIZE-1:0] == fetch_rd_tag_f1[`RV_BTB_BTAG_SIZE-1:0]) & 
                                    exu_mp_valid & ifc_fetch_req_f1 & 
                                    (exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO])
                                    );
   // set on leak one, hold until next flush without leak one
   assign leak_one_f1 = (dec_tlu_flush_leak_one_wb & dec_tlu_flush_lower_wb) | (leak_one_f2 & ~dec_tlu_flush_lower_wb);

`ifdef RV_BTB_48
   rvdff #(15) coll_ff (.*, .clk(active_clk),
`else
   rvdff #(13) coll_ff (.*, .clk(active_clk), 
`endif
                         .din({branch_error_bank_conflict_f1[3:0], fetch_mp_collision_f1, mp_bank_decoded[3:0], exu_mp_way, dec_tlu_way_wb, leak_one_f1, ifc_fetch_req_f1}), 
                        .dout({branch_error_bank_conflict_f2[3:0], fetch_mp_collision_f2, mp_bank_decoded_f[3:0], exu_mp_way_f, dec_tlu_way_wb_f, leak_one_f2, ifc_fetch_req_f2_raw}));
`ifdef RV_BTB_48
   
   // 2 -way SA, figure out the way hit and mux accordingly
   assign tag_match_way0_f2[3:0] = {btb_bank3_rd_data_way0_f2[BV] & (btb_bank3_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank2_rd_data_way0_f2[BV] & (btb_bank2_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank1_rd_data_way0_f2[BV] & (btb_bank1_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank0_rd_data_way0_f2[BV] & (btb_bank0_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0])} & 
                                   ~({4{dec_tlu_way_wb_f==2'b0}} & branch_error_bank_conflict_f2[3:0]) & {4{ifc_fetch_req_f2_raw & ~leak_one_f2}};
   
   assign tag_match_way1_f2[3:0] = {btb_bank3_rd_data_way1_f2[BV] & (btb_bank3_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank2_rd_data_way1_f2[BV] & (btb_bank2_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank1_rd_data_way1_f2[BV] & (btb_bank1_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank0_rd_data_way1_f2[BV] & (btb_bank0_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0])} & 
                                   ~({4{dec_tlu_way_wb_f[0]}} & branch_error_bank_conflict_f2[3:0]) & {4{ifc_fetch_req_f2_raw & ~leak_one_f2}};

   assign tag_match_way2_f2[3:0] = {btb_bank3_rd_data_way2_f2[BV] & (btb_bank3_rd_data_way2_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank2_rd_data_way2_f2[BV] & (btb_bank2_rd_data_way2_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank1_rd_data_way2_f2[BV] & (btb_bank1_rd_data_way2_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank0_rd_data_way2_f2[BV] & (btb_bank0_rd_data_way2_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0])} & 
                                   ~({4{dec_tlu_way_wb_f[1]}} & branch_error_bank_conflict_f2[3:0]) & {4{ifc_fetch_req_f2_raw & ~leak_one_f2}};

`else   
   // 2 -way SA, figure out the way hit and mux accordingly
   assign tag_match_way0_f2[3:0] = {btb_bank3_rd_data_way0_f2[BV] & (btb_bank3_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank2_rd_data_way0_f2[BV] & (btb_bank2_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank1_rd_data_way0_f2[BV] & (btb_bank1_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank0_rd_data_way0_f2[BV] & (btb_bank0_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0])} & 
                                   ~({4{~dec_tlu_way_wb_f}} & branch_error_bank_conflict_f2[3:0]) & {4{ifc_fetch_req_f2_raw & ~leak_one_f2}};
   
   assign tag_match_way1_f2[3:0] = {btb_bank3_rd_data_way1_f2[BV] & (btb_bank3_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank2_rd_data_way1_f2[BV] & (btb_bank2_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank1_rd_data_way1_f2[BV] & (btb_bank1_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank0_rd_data_way1_f2[BV] & (btb_bank0_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0])} & 
                                   ~({4{dec_tlu_way_wb_f}} & branch_error_bank_conflict_f2[3:0]) & {4{ifc_fetch_req_f2_raw & ~leak_one_f2}};

`endif
   
   // Both ways could hit, use the offset bit to reorder
   
   assign tag_match_way0_expanded_f2[7:0] = {tag_match_way0_f2[3] &  (btb_bank3_rd_data_way0_f2[BOFF] ^ btb_bank3_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[3] & ~(btb_bank3_rd_data_way0_f2[BOFF] ^ btb_bank3_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[2] &  (btb_bank2_rd_data_way0_f2[BOFF] ^ btb_bank2_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[2] & ~(btb_bank2_rd_data_way0_f2[BOFF] ^ btb_bank2_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[1] &  (btb_bank1_rd_data_way0_f2[BOFF] ^ btb_bank1_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[1] & ~(btb_bank1_rd_data_way0_f2[BOFF] ^ btb_bank1_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[0] &  (btb_bank0_rd_data_way0_f2[BOFF] ^ btb_bank0_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[0] & ~(btb_bank0_rd_data_way0_f2[BOFF] ^ btb_bank0_rd_data_way0_f2[PC4])};
   
   assign tag_match_way1_expanded_f2[7:0] = {tag_match_way1_f2[3] &  (btb_bank3_rd_data_way1_f2[BOFF] ^ btb_bank3_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[3] & ~(btb_bank3_rd_data_way1_f2[BOFF] ^ btb_bank3_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[2] &  (btb_bank2_rd_data_way1_f2[BOFF] ^ btb_bank2_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[2] & ~(btb_bank2_rd_data_way1_f2[BOFF] ^ btb_bank2_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[1] &  (btb_bank1_rd_data_way1_f2[BOFF] ^ btb_bank1_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[1] & ~(btb_bank1_rd_data_way1_f2[BOFF] ^ btb_bank1_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[0] &  (btb_bank0_rd_data_way1_f2[BOFF] ^ btb_bank0_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[0] & ~(btb_bank0_rd_data_way1_f2[BOFF] ^ btb_bank0_rd_data_way1_f2[PC4])};

`ifdef RV_BTB_48
   assign tag_match_way2_expanded_f2[7:0] = {tag_match_way2_f2[3] &  (btb_bank3_rd_data_way2_f2[BOFF] ^ btb_bank3_rd_data_way2_f2[PC4]),
                                             tag_match_way2_f2[3] & ~(btb_bank3_rd_data_way2_f2[BOFF] ^ btb_bank3_rd_data_way2_f2[PC4]),
                                             tag_match_way2_f2[2] &  (btb_bank2_rd_data_way2_f2[BOFF] ^ btb_bank2_rd_data_way2_f2[PC4]),
                                             tag_match_way2_f2[2] & ~(btb_bank2_rd_data_way2_f2[BOFF] ^ btb_bank2_rd_data_way2_f2[PC4]),
                                             tag_match_way2_f2[1] &  (btb_bank1_rd_data_way2_f2[BOFF] ^ btb_bank1_rd_data_way2_f2[PC4]),
                                             tag_match_way2_f2[1] & ~(btb_bank1_rd_data_way2_f2[BOFF] ^ btb_bank1_rd_data_way2_f2[PC4]),
                                             tag_match_way2_f2[0] &  (btb_bank0_rd_data_way2_f2[BOFF] ^ btb_bank0_rd_data_way2_f2[PC4]),
                                             tag_match_way2_f2[0] & ~(btb_bank0_rd_data_way2_f2[BOFF] ^ btb_bank0_rd_data_way2_f2[PC4])};

   assign wayhit_f2[7:0] = tag_match_way0_expanded_f2[7:0] | tag_match_way1_expanded_f2[7:0] | tag_match_way2_expanded_f2[7:0];

   assign btb_bank3o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[7]}} & btb_bank3_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[7]}} & btb_bank3_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[7]}} & btb_bank3_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank3e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[6]}} & btb_bank3_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[6]}} & btb_bank3_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[6]}} & btb_bank3_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank2o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[5]}} & btb_bank2_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[5]}} & btb_bank2_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[5]}} & btb_bank2_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank2e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[4]}} & btb_bank2_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[4]}} & btb_bank2_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[4]}} & btb_bank2_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank1o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[3]}} & btb_bank1_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[3]}} & btb_bank1_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[3]}} & btb_bank1_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank1e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[2]}} & btb_bank1_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[2]}} & btb_bank1_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[2]}} & btb_bank1_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank0o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[1]}} & btb_bank0_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[1]}} & btb_bank0_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[1]}} & btb_bank0_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank0e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[0]}} & btb_bank0_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[0]}} & btb_bank0_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way2_expanded_f2[0]}} & btb_bank0_rd_data_way2_f2[16+`RV_BTB_BTAG_SIZE:0]) );


`else // !`ifdef RV_BTB_48

   assign wayhit_f2[7:0] = tag_match_way0_expanded_f2[7:0] | tag_match_way1_expanded_f2[7:0];
   assign btb_bank3o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[7]}} & btb_bank3_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[7]}} & btb_bank3_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank3e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[6]}} & btb_bank3_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[6]}} & btb_bank3_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank2o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[5]}} & btb_bank2_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[5]}} & btb_bank2_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank2e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[4]}} & btb_bank2_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[4]}} & btb_bank2_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank1o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[3]}} & btb_bank1_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[3]}} & btb_bank1_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank1e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[2]}} & btb_bank1_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[2]}} & btb_bank1_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank0o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[1]}} & btb_bank0_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[1]}} & btb_bank0_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank0e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[0]}} & btb_bank0_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[0]}} & btb_bank0_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );

`endif



   // --------------------------------------------------------------------------------
   // --------------------------------------------------------------------------------
   // update lru
   // mp

   assign mp_bank_decoded[3:0] = decode2_4(exu_mp_bank[1:0]);
   // create a onehot lru write vector
   assign mp_wrindex_dec[LRU_SIZE-1:0] = {{LRU_SIZE-1{1'b0}},1'b1} <<  exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
 
   // fetch
   assign fetch_wrindex_dec[LRU_SIZE-1:0] = {{LRU_SIZE-1{1'b0}},1'b1} <<  btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   assign mp_wrlru_b0[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[0] & exu_mp_valid}};
   assign mp_wrlru_b1[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[1] & exu_mp_valid}};
   assign mp_wrlru_b2[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[2] & exu_mp_valid}};
   assign mp_wrlru_b3[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[3] & exu_mp_valid}};

   genvar     j, i;


`ifdef BTB_ROUND_ROBIN
   assign fetch_wrlru_b0[LRU_SIZE-1:0] = {LRU_SIZE-1{1'b0}};
   assign fetch_wrlru_b1[LRU_SIZE-1:0] = {LRU_SIZE-1{1'b0}};
   assign fetch_wrlru_b2[LRU_SIZE-1:0] = {LRU_SIZE-1{1'b0}};
   assign fetch_wrlru_b3[LRU_SIZE-1:0] = {LRU_SIZE-1{1'b0}};

   assign lru_update_valid_f2[3:0] = 4'b0;

`else

   assign lru_update_valid_f2[3:0] = {((bht_valid_f2[6] & btb_sel_mask_f2[6]) | (bht_valid_f2[7] & btb_sel_mask_f2[7])) & ifc_fetch_req_f2 & ~leak_one_f2,
                                      ((bht_valid_f2[4] & btb_sel_mask_f2[4]) | (bht_valid_f2[5] & btb_sel_mask_f2[5])) & ifc_fetch_req_f2 & ~leak_one_f2,
                                      ((bht_valid_f2[2] & btb_sel_mask_f2[2]) | (bht_valid_f2[3] & btb_sel_mask_f2[3])) & ifc_fetch_req_f2 & ~leak_one_f2,
                                      ((bht_valid_f2[0] & btb_sel_mask_f2[0]) | (bht_valid_f2[1] & btb_sel_mask_f2[1])) & ifc_fetch_req_f2 & ~leak_one_f2};

   assign fetch_wrlru_b0[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] & 
                                         {LRU_SIZE{lru_update_valid_f2[0]}};
   assign fetch_wrlru_b1[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] & 
                                         {LRU_SIZE{lru_update_valid_f2[1]}};
   assign fetch_wrlru_b2[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] & 
                                         {LRU_SIZE{lru_update_valid_f2[2]}};
   assign fetch_wrlru_b3[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] & 
                                         {LRU_SIZE{lru_update_valid_f2[3]}};

`endif
   
   assign btb_lru_b0_hold[LRU_SIZE-1:0] = ~mp_wrlru_b0[LRU_SIZE-1:0] & ~fetch_wrlru_b0[LRU_SIZE-1:0];
   assign btb_lru_b1_hold[LRU_SIZE-1:0] = ~mp_wrlru_b1[LRU_SIZE-1:0] & ~fetch_wrlru_b1[LRU_SIZE-1:0];
   assign btb_lru_b2_hold[LRU_SIZE-1:0] = ~mp_wrlru_b2[LRU_SIZE-1:0] & ~fetch_wrlru_b2[LRU_SIZE-1:0];
   assign btb_lru_b3_hold[LRU_SIZE-1:0] = ~mp_wrlru_b3[LRU_SIZE-1:0] & ~fetch_wrlru_b3[LRU_SIZE-1:0];

   // Forward the mp lru information to the fetch, avoids multiple way hits later
   assign use_mp_way[3:0] = {4{fetch_mp_collision_f2}} & mp_bank_decoded_f[3:0];




`ifdef RV_BTB_48
   logic [3:0][3:0] [2:0] lru_bank_wr_data ;
   logic [3:0][3:0]       lru_bank_sel ;
   logic [3:0] [1:0]      hitway_enc;
   logic [3:0] [2:0]      fetch_new_lru;
   logic [2:0]            lru_bank0_rd_data_f2_in, lru_bank1_rd_data_f2_in, lru_bank2_rd_data_f2_in, lru_bank3_rd_data_f2_in;
   logic [2:0]            lru_bank0_rd_data_f2, lru_bank1_rd_data_f2, lru_bank2_rd_data_f2, lru_bank3_rd_data_f2;
   logic [1:0]            lru_bank0_next_way, lru_bank1_next_way, lru_bank2_next_way, lru_bank3_next_way,
                          fetch_replway_bank0_enc, fetch_replway_bank1_enc, fetch_replway_bank2_enc, fetch_replway_bank3_enc,
                          fetch_replway_bank4_enc, fetch_replway_bank5_enc, fetch_replway_bank6_enc, fetch_replway_bank7_enc;
   logic [3:0][3:0] [2:0] lru_bank_rd_data_out;
   
//   // could have 2 ways hit for case where same bank, different offset hit. Update LRU accordingly
logic [3:0] two_hits;
   assign two_hits[3:0] = (tag_match_way0_f2[3:0] & tag_match_way1_f2[3:0]) |
                          (tag_match_way0_f2[3:0] & tag_match_way2_f2[3:0]) |
                          (tag_match_way1_f2[3:0] & tag_match_way2_f2[3:0]) ;

  logic [2:0] mp_new_lru;
  assign mp_new_lru[2:0] = newlru(lru_bank_rd_data_out[exu_mp_bank[1:0]][exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]], exu_mp_way[1:0]);


   assign fetch_lru_bank_hit_f2[3:0] = lru_update_valid_f2[3:0] & (tag_match_way0_f2[3:0] | tag_match_way1_f2[3:0] | tag_match_way2_f2[3:0]);

   // banks
   for ( i=0; i<4; i++) begin : LRUBANKS    
      // only 4 indices here
      // encode the hit way in case the fetch hits
      assign hitway_enc[i] = tag_match_way1_f2[i] ? 2'b01 : tag_match_way2_f2[i] ? 2'b10 : 'b0;
      // update the lru assuming a hit
      assign fetch_new_lru[i] = newlru(lru_bank_rd_data_out[i][btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]], hitway_enc[i][1:0]);

      // index
      for (j=0 ; j<4 ; j++) begin : LRUFLOPS
         
         // mux the write data
         assign lru_bank_wr_data[i][j]  = (exu_mp_valid & mp_bank_decoded[i]) ? mp_new_lru[2:0] : fetch_lru_bank_hit_f2[i] ? fetch_new_lru[i] : 'b0;
         
         // bank enable if there was a fetch hit or a mispredict
         // simul mp and fetch, mp has priority
         assign lru_bank_sel[i][j] = (~exu_mp_valid & fetch_lru_bank_hit_f2[i] & (btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j)) |
                                     ( exu_mp_valid & mp_bank_decoded[i]    & (exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j));
         
         
         rvdffs #(3) lru_bank (.*,  
                               .clk        (active_clk),
                               .en         (lru_bank_sel[i][j]),
                               .din        (lru_bank_wr_data[i][j]),
                               .dout       (lru_bank_rd_data_out[i][j]));
         
      end // block: LRUFLOPS
   end // block: LRUBANKS

always_comb begin : LRU_rd_mux 
     lru_bank0_rd_data_f2_in[2:0] = '0 ; 
     lru_bank1_rd_data_f2_in[2:0] = '0 ; 
     lru_bank2_rd_data_f2_in[2:0] = '0 ; 
     lru_bank3_rd_data_f2_in[2:0] = '0 ;
     for (int j=0; j<4; j++) begin
       if (btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) begin  
         lru_bank0_rd_data_f2_in[2:0] = lru_bank_rd_data_out[0][j];
         lru_bank1_rd_data_f2_in[2:0] = lru_bank_rd_data_out[1][j];
         lru_bank2_rd_data_f2_in[2:0] = lru_bank_rd_data_out[2][j];
         lru_bank3_rd_data_f2_in[2:0] = lru_bank_rd_data_out[3][j];
       end
     end
end // block: LRU_rd_mux
                                         

   rvdffe #(12) lru_dataoutf (.*, .en         (ifc_fetch_req_f1),
                                 .din        ({lru_bank0_rd_data_f2_in[2:0],
                                               lru_bank1_rd_data_f2_in[2:0],
                                               lru_bank2_rd_data_f2_in[2:0],
                                               lru_bank3_rd_data_f2_in[2:0]
                                               }),
                                 .dout       ({lru_bank0_rd_data_f2   [2:0],
                                               lru_bank1_rd_data_f2   [2:0],
                                               lru_bank2_rd_data_f2   [2:0],
                                               lru_bank3_rd_data_f2   [2:0]
                                               }));

   // Create the replacement way to send down the pipe. First is hitway, then consider invalid ways first, then lru way
   assign lru_bank0_next_way[1:0] = use_mp_way[0] ? exu_mp_way_f[1:0] : lru2way(lru_bank0_rd_data_f2[2:0], {btb_bank0_rd_data_way2_f2[BV],btb_bank0_rd_data_way1_f2[BV],btb_bank0_rd_data_way0_f2[BV]});
   assign lru_bank1_next_way[1:0] = use_mp_way[1] ? exu_mp_way_f[1:0] : lru2way(lru_bank1_rd_data_f2[2:0], {btb_bank1_rd_data_way2_f2[BV],btb_bank1_rd_data_way1_f2[BV],btb_bank1_rd_data_way0_f2[BV]});
   assign lru_bank2_next_way[1:0] = use_mp_way[2] ? exu_mp_way_f[1:0] : lru2way(lru_bank2_rd_data_f2[2:0], {btb_bank2_rd_data_way2_f2[BV],btb_bank2_rd_data_way1_f2[BV],btb_bank2_rd_data_way0_f2[BV]});
   assign lru_bank3_next_way[1:0] = use_mp_way[3] ? exu_mp_way_f[1:0] : lru2way(lru_bank3_rd_data_f2[2:0], {btb_bank3_rd_data_way2_f2[BV],btb_bank3_rd_data_way1_f2[BV],btb_bank3_rd_data_way0_f2[BV]});

   assign fetch_replway_bank0_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[0]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[0] & ~tag_match_way0_expanded_f2[0]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[0] & ~tag_match_way1_expanded_f2[0] & ~tag_match_way0_expanded_f2[0]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[0] & ~tag_match_way1_expanded_f2[0] & ~tag_match_way0_expanded_f2[0]}} & lru_bank0_next_way[1:0]));
   assign fetch_replway_bank1_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[1]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[1] & ~tag_match_way0_expanded_f2[1]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[1] & ~tag_match_way1_expanded_f2[1] & ~tag_match_way0_expanded_f2[1]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[1] & ~tag_match_way1_expanded_f2[1] & ~tag_match_way0_expanded_f2[1]}} & lru_bank0_next_way[1:0]));
   assign fetch_replway_bank2_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[2]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[2] & ~tag_match_way0_expanded_f2[2]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[2] & ~tag_match_way1_expanded_f2[2] & ~tag_match_way0_expanded_f2[2]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[2] & ~tag_match_way1_expanded_f2[2] & ~tag_match_way0_expanded_f2[2]}} & lru_bank1_next_way[1:0]));
   assign fetch_replway_bank3_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[3]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[3] & ~tag_match_way0_expanded_f2[3]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[3] & ~tag_match_way1_expanded_f2[3] & ~tag_match_way0_expanded_f2[3]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[3] & ~tag_match_way1_expanded_f2[3] & ~tag_match_way0_expanded_f2[3]}} & lru_bank1_next_way[1:0]));
   assign fetch_replway_bank4_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[4]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[4] & ~tag_match_way0_expanded_f2[4]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[4] & ~tag_match_way1_expanded_f2[4] & ~tag_match_way0_expanded_f2[4]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[4] & ~tag_match_way1_expanded_f2[4] & ~tag_match_way0_expanded_f2[4]}} & lru_bank2_next_way[1:0]));
   assign fetch_replway_bank5_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[5]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[5] & ~tag_match_way0_expanded_f2[5]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[5] & ~tag_match_way1_expanded_f2[5] & ~tag_match_way0_expanded_f2[5]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[5] & ~tag_match_way1_expanded_f2[5] & ~tag_match_way0_expanded_f2[5]}} & lru_bank2_next_way[1:0]));
   assign fetch_replway_bank6_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[6]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[6] & ~tag_match_way0_expanded_f2[6]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[6] & ~tag_match_way1_expanded_f2[6] & ~tag_match_way0_expanded_f2[6]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[6] & ~tag_match_way1_expanded_f2[6] & ~tag_match_way0_expanded_f2[6]}} & lru_bank3_next_way[1:0]));
   assign fetch_replway_bank7_enc[1:0] = ( ({2{tag_match_way0_expanded_f2[7]}} & 2'b00) |
                                           ({2{tag_match_way1_expanded_f2[7] & ~tag_match_way0_expanded_f2[7]}} & 2'b01) |
                                           ({2{tag_match_way2_expanded_f2[7] & ~tag_match_way1_expanded_f2[7] & ~tag_match_way0_expanded_f2[7]}} & 2'b10) |
                                           ({2{~tag_match_way2_expanded_f2[7] & ~tag_match_way1_expanded_f2[7] & ~tag_match_way0_expanded_f2[7]}} & lru_bank3_next_way[1:0]));

`else


   
   assign btb_lru_b0_ns[LRU_SIZE-1:0] = ( (btb_lru_b0_hold[LRU_SIZE-1:0] & btb_lru_b0_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b0[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b0[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[0]}}) );
  
   assign btb_lru_b1_ns[LRU_SIZE-1:0] = ( (btb_lru_b1_hold[LRU_SIZE-1:0] & btb_lru_b1_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b1[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b1[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[1]}}) );
  
   assign btb_lru_b2_ns[LRU_SIZE-1:0] = ( (btb_lru_b2_hold[LRU_SIZE-1:0] & btb_lru_b2_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b2[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b2[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[2]}}) );
  
   assign btb_lru_b3_ns[LRU_SIZE-1:0] = ( (btb_lru_b3_hold[LRU_SIZE-1:0] & btb_lru_b3_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b3[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b3[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[3]}}) );

   assign btb_lru_rd_f2[0] = use_mp_way[0] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b0_f[LRU_SIZE-1:0]);
   assign btb_lru_rd_f2[1] = use_mp_way[1] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b1_f[LRU_SIZE-1:0]);
   assign btb_lru_rd_f2[2] = use_mp_way[2] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b2_f[LRU_SIZE-1:0]);
   assign btb_lru_rd_f2[3] = use_mp_way[3] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b3_f[LRU_SIZE-1:0]);

   assign way_raw[7:0] =  tag_match_way1_expanded_f2[7:0] | (~wayhit_f2[7:0] & {{2{btb_lru_rd_f2[3]}}, {2{btb_lru_rd_f2[2]}}, {2{btb_lru_rd_f2[1]}}, {2{btb_lru_rd_f2[0]}}});

   rvdffe #(LRU_SIZE*4) btb_lru_ff (.*, .en(ifc_fetch_req_f2 | exu_mp_valid), 
                                   .din({btb_lru_b0_ns[(LRU_SIZE)-1:0],
                                         btb_lru_b1_ns[(LRU_SIZE)-1:0],
                                         btb_lru_b2_ns[(LRU_SIZE)-1:0],
                                         btb_lru_b3_ns[(LRU_SIZE)-1:0]}), 
                                   .dout({btb_lru_b0_f[(LRU_SIZE)-1:0],
                                          btb_lru_b1_f[(LRU_SIZE)-1:0],
                                          btb_lru_b2_f[(LRU_SIZE)-1:0],
                                          btb_lru_b3_f[(LRU_SIZE)-1:0]}));
`endif // !`ifdef RV_BTB_48
   

   // --------------------------------------------------------------------------------
   // --------------------------------------------------------------------------------
   
   // mux out critical hit bank for pc computation
   // This is only useful for the first taken branch in the fetch group
   logic [16:1] btb_sel_data_f2;
   assign {
           btb_rd_tgt_f2[11:0], 
           btb_rd_pc4_f2, 
           btb_rd_boffset_f2,
           btb_rd_call_f2,
           btb_rd_ret_f2} = btb_sel_data_f2[16:1];

   assign btb_sel_data_f2[16:1] = ( ({16{btb_sel_f2[7]}} & btb_bank3o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[6]}} & btb_bank3e_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[5]}} & btb_bank2o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[4]}} & btb_bank2e_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[3]}} & btb_bank1o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[2]}} & btb_bank1e_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[1]}} & btb_bank0o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[0]}} & btb_bank0e_rd_data_f2[16:1]) );


   logic [7:0] bp_valid_f2, bp_hist1_f2;
   
   // a valid taken target needs to kill the next fetch as we compute the target address
   assign ifu_bp_kill_next_f2 = |(bp_valid_f2[7:0] & bp_hist1_f2[7:0]) & ifc_fetch_req_f2 & ~leak_one_f2 & ~dec_tlu_bpred_disable;
   

   // Don't put calls/rets/ja in the predictor, force the bht taken instead
   assign bht_force_taken_f2[7:0] = {(btb_bank3o_rd_data_f2[CALL] | btb_bank3o_rd_data_f2[RET]),
                                     (btb_bank3e_rd_data_f2[CALL] | btb_bank3e_rd_data_f2[RET]),
                                     (btb_bank2o_rd_data_f2[CALL] | btb_bank2o_rd_data_f2[RET]),
                                     (btb_bank2e_rd_data_f2[CALL] | btb_bank2e_rd_data_f2[RET]),
                                     (btb_bank1o_rd_data_f2[CALL] | btb_bank1o_rd_data_f2[RET]),
                                     (btb_bank1e_rd_data_f2[CALL] | btb_bank1e_rd_data_f2[RET]),
                                     (btb_bank0o_rd_data_f2[CALL] | btb_bank0o_rd_data_f2[RET]),
                                     (btb_bank0e_rd_data_f2[CALL] | btb_bank0e_rd_data_f2[RET])};
   

   // taken and valid, otherwise, branch errors must clear the bht
   assign bht_valid_f2[7:0] = wayhit_f2[7:0];

   assign bht_dir_f2[7:0] = {(bht_force_taken_f2[7] | bht_bank7_rd_data_f2[1]) & bht_valid_f2[7], 
                             (bht_force_taken_f2[6] | bht_bank6_rd_data_f2[1]) & bht_valid_f2[6], 
                             (bht_force_taken_f2[5] | bht_bank5_rd_data_f2[1]) & bht_valid_f2[5], 
                             (bht_force_taken_f2[4] | bht_bank4_rd_data_f2[1]) & bht_valid_f2[4], 
                             (bht_force_taken_f2[3] | bht_bank3_rd_data_f2[1]) & bht_valid_f2[3], 
                             (bht_force_taken_f2[2] | bht_bank2_rd_data_f2[1]) & bht_valid_f2[2], 
                             (bht_force_taken_f2[1] | bht_bank1_rd_data_f2[1]) & bht_valid_f2[1],
                             (bht_force_taken_f2[0] | bht_bank0_rd_data_f2[1]) & bht_valid_f2[0]};
   
   // final inst_valid_mask.
   // vmask[7] is a 0, vmask[0] is a 1, initially
   // (assumes pc2 with boffset 0)
   //
   logic       minus1, plus1;
   
   assign plus1 = ( (~btb_rd_pc4_f2 &   btb_rd_boffset_f2 &  ~ifc_fetch_addr_f2[1]) |
                    ( btb_rd_pc4_f2 &  ~btb_rd_boffset_f2 &  ~ifc_fetch_addr_f2[1]) );
   
   assign minus1 = ( (~btb_rd_pc4_f2 &  ~btb_rd_boffset_f2 &   ifc_fetch_addr_f2[1]) |
                     ( btb_rd_pc4_f2 &   btb_rd_boffset_f2 &   ifc_fetch_addr_f2[1]) );

   assign ifu_bp_inst_mask_f2[7:1] = ( ({7{ ifu_bp_kill_next_f2}} & btb_vmask_f2[7:1]) |
                                       ({7{~ifu_bp_kill_next_f2}} & 7'b1111111) );
 
   logic [7:0] hist0_raw, hist1_raw, pc4_raw, pret_raw;
   

   // Branch prediction info is sent with the 2byte lane associated with the end of the branch.
   // Cases
   //       BANK1         BANK0
   // -------------------------------
   // |      :       |      :       |
   // -------------------------------
   //         <------------>                   : PC4 branch, offset, should be in B1 (indicated on [2])
   //                <------------>            : PC4 branch, no offset, indicate PC4, VALID, HIST on [1]
   //                       <------------>     : PC4 branch, offset, indicate PC4, VALID, HIST on [0]
   //                <------>                  : PC2 branch, offset, indicate VALID, HIST on [1]
   //                       <------>           : PC2 branch, no offset, indicate VALID, HIST on [0]
   // 

    assign hist1_raw[7:0] = bht_force_taken_f2[7:0] | {bht_bank7_rd_data_f2[1],
                                                      bht_bank6_rd_data_f2[1],
                                                      bht_bank5_rd_data_f2[1],
                                                      bht_bank4_rd_data_f2[1],
                                                      bht_bank3_rd_data_f2[1],
                                                      bht_bank2_rd_data_f2[1],
                                                      bht_bank1_rd_data_f2[1],
                                                      bht_bank0_rd_data_f2[1]};
                                                     
   assign hist0_raw[7:0] = {bht_bank7_rd_data_f2[0],
                            bht_bank6_rd_data_f2[0],
                            bht_bank5_rd_data_f2[0],
                            bht_bank4_rd_data_f2[0],
                            bht_bank3_rd_data_f2[0],
                            bht_bank2_rd_data_f2[0],
                            bht_bank1_rd_data_f2[0],
                            bht_bank0_rd_data_f2[0]};
  
 
   assign pc4_raw[7:0] = {wayhit_f2[7] & btb_bank3o_rd_data_f2[PC4], 
                          wayhit_f2[6] & btb_bank3e_rd_data_f2[PC4],
                          wayhit_f2[5] & btb_bank2o_rd_data_f2[PC4], 
                          wayhit_f2[4] & btb_bank2e_rd_data_f2[PC4], 
                          wayhit_f2[3] & btb_bank1o_rd_data_f2[PC4], 
                          wayhit_f2[2] & btb_bank1e_rd_data_f2[PC4], 
                          wayhit_f2[1] & btb_bank0o_rd_data_f2[PC4], 
                          wayhit_f2[0] & btb_bank0e_rd_data_f2[PC4]};

   assign pret_raw[7:0] = {wayhit_f2[3] & ~btb_bank3o_rd_data_f2[CALL] & btb_bank3o_rd_data_f2[RET], 
                           wayhit_f2[3] & ~btb_bank3e_rd_data_f2[CALL] & btb_bank3e_rd_data_f2[RET],
                           wayhit_f2[2] & ~btb_bank2o_rd_data_f2[CALL] & btb_bank2o_rd_data_f2[RET], 
                           wayhit_f2[2] & ~btb_bank2e_rd_data_f2[CALL] & btb_bank2e_rd_data_f2[RET], 
                           wayhit_f2[1] & ~btb_bank1o_rd_data_f2[CALL] & btb_bank1o_rd_data_f2[RET], 
                           wayhit_f2[1] & ~btb_bank1e_rd_data_f2[CALL] & btb_bank1e_rd_data_f2[RET], 
                           wayhit_f2[0] & ~btb_bank0o_rd_data_f2[CALL] & btb_bank0o_rd_data_f2[RET], 
                           wayhit_f2[0] & ~btb_bank0e_rd_data_f2[CALL] & btb_bank0e_rd_data_f2[RET]};
   
   // GHR
   
   // Figure out how many valid branches are in the fetch group
assign fgmask_f2[6] = (~ifc_fetch_addr_f2[1]) | (~ifc_fetch_addr_f2[2]) | (
    ~ifc_fetch_addr_f2[3]);
assign fgmask_f2[5] = (~ifc_fetch_addr_f2[2]) | (~ifc_fetch_addr_f2[3]);
assign fgmask_f2[4] = (~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]) | (
    ~ifc_fetch_addr_f2[3]);
assign fgmask_f2[3] = (~ifc_fetch_addr_f2[3]);
assign fgmask_f2[2] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]);
assign fgmask_f2[1] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]);
assign fgmask_f2[0] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1]);

   assign btb_sel_mask_f2[7:0] = {btb_sel_f2[7], 
                                  |btb_sel_f2[7:6] & fgmask_f2[6], 
                                  |btb_sel_f2[7:5] & fgmask_f2[5], 
                                  |btb_sel_f2[7:4] & fgmask_f2[4], 
                                  |btb_sel_f2[7:3] & fgmask_f2[3], 
                                  |btb_sel_f2[7:2] & fgmask_f2[2], 
                                  |btb_sel_f2[7:1] & fgmask_f2[1], 
                                  |btb_sel_f2[7:0] & fgmask_f2[0]};

  // count the valids with masking based on first taken
   assign num_valids[3:0] = countones(bht_valid_f2[7:0] & btb_sel_mask_f2[7:0]);

   // Note that the following property holds
   // P: prior ghr, H: history bit of last valid branch in line (could be 1 or 0)
   // Num valid branches   What new GHR must be 
   // >=4                  000H
   // 3                    P00H
   // 2                    PP0H
   // 1                    PPPH
   // 0                    PPPP
   
   assign final_h = |(btb_sel_f2[7:0] & bht_dir_f2[7:0]);
   
    assign merged_ghr[`RV_BHT_GHR_RANGE] = ( ({`RV_BHT_GHR_SIZE{num_valids[3:0] >= 4'h4}} & {`RV_BHT_GHR_PAD,  final_h }) | // 000H
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h3}} & {`RV_BHT_GHR_PAD2, final_h}) | // P00H
`ifdef RV_BHT_GHR_SIZE_2                                           
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h2}} & {                            1'b0, final_h}) | // PP0H
`else
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h2}} & {fghr[`RV_BHT_GHR_SIZE-3:0], 1'b0, final_h}) | // PP0H
`endif
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h1}} & {fghr[`RV_BHT_GHR_SIZE-2:0], final_h}) | // PPPH
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h0}} & {fghr[`RV_BHT_GHR_RANGE]}) ); // PPPP

   logic [`RV_BHT_GHR_RANGE] exu_flush_ghr;
   assign exu_flush_ghr[`RV_BHT_GHR_RANGE] = exu_mp_fghr[`RV_BHT_GHR_RANGE];
   
   assign fghr_ns[`RV_BHT_GHR_RANGE] = ( ({`RV_BHT_GHR_SIZE{exu_flush_final}} & exu_flush_ghr[`RV_BHT_GHR_RANGE]) |
                                         ({`RV_BHT_GHR_SIZE{~exu_flush_final & ifc_fetch_req_f2_raw & ~leak_one_f2}} & merged_ghr[`RV_BHT_GHR_RANGE]) |
                                         ({`RV_BHT_GHR_SIZE{~exu_flush_final & ~(ifc_fetch_req_f2_raw & ~leak_one_f2)}} & fghr[`RV_BHT_GHR_RANGE]));

   rvdff #(`RV_BHT_GHR_SIZE) fetchghr (.*, .clk(active_clk), .din(fghr_ns[`RV_BHT_GHR_RANGE]), .dout(fghr[`RV_BHT_GHR_RANGE]));
   assign ifu_bp_fghr_f2[`RV_BHT_GHR_RANGE] = fghr[`RV_BHT_GHR_RANGE];
   

`ifdef RV_BTB_48
   assign ifu_bp_way_f2 = {fetch_replway_bank7_enc[1:0],
                                fetch_replway_bank6_enc[1:0],
                                     fetch_replway_bank5_enc[1:0],
                                     fetch_replway_bank4_enc[1:0],
                                     fetch_replway_bank3_enc[1:0],
                                     fetch_replway_bank2_enc[1:0],
                                     fetch_replway_bank1_enc[1:0],
                                     fetch_replway_bank0_enc[1:0]};

`else
   assign ifu_bp_way_f2[7:0] = way_raw[7:0];
`endif
   assign ifu_bp_hist1_f2[7:0]    = hist1_raw[7:0];
   assign ifu_bp_hist0_f2[7:0]    = hist0_raw[7:0];
   assign ifu_bp_pc4_f2[7:0]     = pc4_raw[7:0];
   assign ifu_bp_valid_f2[7:0]   = wayhit_f2[7:0] & ~{8{dec_tlu_bpred_disable}};
   assign ifu_bp_ret_f2[7:0]     = pret_raw[7:0];


    // Truncate taken and valid, used for detecting a taken branch in the fetch group
    always_comb begin
       casez(ifc_fetch_addr_f2[3:1])
        3'b000 : begin 
           bp_hist1_f2[7:0]    = hist1_raw[7:0];
           bp_valid_f2[7:0]   = wayhit_f2[7:0];
        end
        3'b001 : begin 
           bp_hist1_f2[7:0]    = {1'b0, hist1_raw[7:1]};
           bp_valid_f2[7:0]   = {1'b0, wayhit_f2[7:1]};
        end
        3'b010 : begin 
           bp_hist1_f2[7:0]    = {2'b0, hist1_raw[7:2]};
           bp_valid_f2[7:0]   = {2'b0, wayhit_f2[7:2]};
        end
        3'b011 : begin 
           bp_hist1_f2[7:0]    = {3'b0, hist1_raw[7:3]};
           bp_valid_f2[7:0]   = {3'b0, wayhit_f2[7:3]};
        end
        3'b100 : begin 
           bp_hist1_f2[7:0]    = {4'b0, hist1_raw[7:4]};
           bp_valid_f2[7:0]   = {4'b0, wayhit_f2[7:4]};
        end
        3'b101 : begin 
           bp_hist1_f2[7:0]    = {5'b0, hist1_raw[7:5]};
           bp_valid_f2[7:0]   = {5'b0, wayhit_f2[7:5]};
        end
        3'b110 : begin 
           bp_hist1_f2[7:0]    = {6'b0, hist1_raw[7:6]};
           bp_valid_f2[7:0]   = {6'b0, wayhit_f2[7:6]};
           end
        3'b111 : begin 
           bp_hist1_f2[7:0]    = {7'b0, hist1_raw[7]};
           bp_valid_f2[7:0]   = {7'b0, wayhit_f2[7]};
        end
        default: begin
          bp_hist1_f2[7:0] = hist1_raw[7:0];
          bp_valid_f2[7:0] = wayhit_f2[7:0];            
        end   
    endcase // casex (ifc_fetch_addr_f1[3:2])
 
    end
   // compute target
   // Form the fetch group offset based on the btb hit location and the location of the branch within the 4 byte chunk
    assign btb_fg_crossing_f2 = btb_sel_f2[0] & btb_rd_pc4_f2;

   wire [2:0] btb_sel_f2_enc, btb_sel_f2_enc_shift;
   assign btb_sel_f2_enc[2:0] = encode8_3(btb_sel_f2[7:0]);
   assign btb_sel_f2_enc_shift[2:0] = encode8_3({1'b0,btb_sel_f2[7:1]});
   
   assign bp_total_branch_offset_f2[3:1] =  (({3{ btb_rd_pc4_f2}} &  btb_sel_f2_enc_shift[2:0]) |
                                             ({3{~btb_rd_pc4_f2}} &  btb_sel_f2_enc[2:0]) |
                                             ({3{btb_fg_crossing_f2}}));

   
   logic [31:4] adder_pc_in_f2, ifc_fetch_adder_prior;
   rvdffe #(28) faddrf2_ff (.*, .en(ifc_fetch_req_f2 & ~ifu_bp_kill_next_f2 & ic_hit_f2), .din(ifc_fetch_addr_f2[31:4]), .dout(ifc_fetch_adder_prior[31:4]));

   assign ifu_bp_poffset_f2[11:0] = btb_rd_tgt_f2[11:0];

   assign adder_pc_in_f2[31:4] = ( ({28{ btb_fg_crossing_f2}} & ifc_fetch_adder_prior[31:4]) |
                                   ({28{~btb_fg_crossing_f2}} & ifc_fetch_addr_f2[31:4]));
   
   rvbradder predtgt_addr (.pc({adder_pc_in_f2[31:4], bp_total_branch_offset_f2[3:1]}),
                         .offset(btb_rd_tgt_f2[11:0]),
                         .dout(bp_btb_target_adder_f2[31:1])                    
                         );
   // mux in the return stack address here for a predicted return
   assign ifu_bp_btb_target_f2[31:1] = btb_rd_ret_f2 & ~btb_rd_call_f2 ? rets_out[0][31:1] : bp_btb_target_adder_f2[31:1];


   // ----------------------------------------------------------------------
   // Return Stack 
   // ----------------------------------------------------------------------

   rvbradder rs_addr (.pc({adder_pc_in_f2[31:4], bp_total_branch_offset_f2[3:1]}),
                    .offset({10'b0, btb_rd_pc4_f2, ~btb_rd_pc4_f2}),
                    .dout(bp_rs_call_target_f2[31:1])                   
                         );
   
   // Calls/Rets are always taken, so there shouldn't be a push and pop in the same fetch group
   logic rs_overpop_correct, rsoverpop_valid_ns, rsoverpop_valid_f;
   logic [31:1] rsoverpop_ns, rsoverpop_f;
   logic rsunderpop_valid_ns, rsunderpop_valid_f, rs_underpop_correct;
`ifdef RS_COMMIT_EN
   assign rs_overpop_correct = rsoverpop_valid_f & exu_flush_final & ~exu_mp_ret;
   assign rs_underpop_correct = rsunderpop_valid_f & exu_flush_final & ~exu_mp_call;

   assign rsunderpop_valid_ns = (rs_push | (rsunderpop_valid_f & ~(exu_i0_br_call_e4 | exu_i1_br_call_e4))) & ~exu_flush_final;
   assign rsoverpop_valid_ns = (rs_pop | (rsoverpop_valid_f & ~(exu_i0_br_ret_e4 | exu_i1_br_ret_e4))) & ~exu_flush_final;
   assign rsoverpop_ns[31:1] = ( ({31{rs_pop}}  & rets_out[0][31:1]) |
                                 ({31{~rs_pop}} & rsoverpop_f[31:1]) );

   rvdff #(33) retoverpop_ff (.*, .clk(active_clk), .din({rsunderpop_valid_ns, rsoverpop_valid_ns, rsoverpop_ns[31:1]}), .dout({rsunderpop_valid_f, rsoverpop_valid_f, rsoverpop_f[31:1]}));
`else
   assign rs_overpop_correct = 1'b0;
   assign rs_underpop_correct = 1'b0;
   assign rsoverpop_f[31:1]  = 'b0;
`endif // !`ifdef RS_COMMIT_EN

   logic e4_rs_correct;
`ifdef REAL_COMM_RS
   assign rs_correct = exu_flush_upper_e2  & ~e4_rs_correct;
`else
   assign e4_rs_correct = 1'b0;
   assign rs_correct = 1'b0;
`endif
   
   assign rs_push = ((btb_rd_call_f2 & ~btb_rd_ret_f2 & ifu_bp_kill_next_f2) | (rs_overpop_correct & ~rs_underpop_correct)) & ~rs_correct & ~e4_rs_correct;
   assign rs_pop = ((btb_rd_ret_f2 & ~btb_rd_call_f2 & ifu_bp_kill_next_f2) | (rs_underpop_correct & ~rs_overpop_correct)) & ~rs_correct & ~e4_rs_correct;
   assign rs_hold = ~rs_push & ~rs_pop & ~rs_overpop_correct & ~rs_underpop_correct & ~rs_correct & ~e4_rs_correct;


   
   // Fetch based 
   assign rets_in[0][31:1] = ( ({31{rs_overpop_correct & rs_underpop_correct}} & rsoverpop_f[31:1]) |
                               ({31{rs_push & rs_overpop_correct}} & rsoverpop_f[31:1]) |
                               ({31{rs_push & ~rs_overpop_correct}} & bp_rs_call_target_f2[31:1]) |
`ifdef REAL_COMM_RS                            
                               ({31{rs_correct}} & e1_rets_out[0][31:1]) |
                               ({31{e4_rs_correct}} & e4_rets_out[0][31:1]) |
`endif                         
                               ({31{rs_pop}}  & rets_out[1][31:1]) );

   assign rsenable[0] = ~rs_hold;
   
   for (i=0; i<`RV_RET_STACK_SIZE; i++) begin : retstack

      // for the last entry in the stack, we don't have a pop position
      if(i==`RV_RET_STACK_SIZE-1) begin 
`ifdef REAL_COMM_RS                            
         assign rets_in[i][31:1] = ( ({31{rs_push}} & rets_out[i-1][31:1]) |
                                     ({31{rs_correct}} & e1_rets_out[i][31:1]) |
                                     ({31{e4_rs_correct}} & e4_rets_out[i][31:1]) );
`else
         assign rets_in[i][31:1] = rets_out[i-1][31:1];
`endif                         
         assign rsenable[i] = rs_push | rs_correct | e4_rs_correct;
      end
      else if(i>0) begin
`ifdef REAL_COMM_RS                            
        assign rets_in[i][31:1] = ( ({31{rs_push}} & rets_out[i-1][31:1]) |
                                    ({31{rs_pop}}  & rets_out[i+1][31:1]) |
                                    ({31{rs_correct}} & e1_rets_out[i][31:1]) |
                                    ({31{e4_rs_correct}} & e4_rets_out[i][31:1]) );
`else    
        assign rets_in[i][31:1] = ( ({31{rs_push}} & rets_out[i-1][31:1]) |
                                    ({31{rs_pop}}  & rets_out[i+1][31:1]) );
`endif                         
         assign rsenable[i] = rs_push | rs_pop | rs_correct | e4_rs_correct;
      end   
      rvdffe #(31) rets_ff (.*, .en(rsenable[i]), .din(rets_in[i][31:1]), .dout(rets_out[i][31:1]));

   end : retstack
   

`ifdef REAL_COMM_RS
   logic [31:1] e1_rs_call0_target_f2, e1_rs_call1_target_f2, e1_rs_call_target_f2, e4_rs_call0_target_f2, e4_rs_call1_target_f2, e4_rs_call_target_f2;
   logic e1_null, e1_rs_push1, e1_rs_push2, e1_rs_pop1, e1_rs_pop2, e1_rs_hold;
   logic e4_null, e4_rs_push1, e4_rs_push2, e4_rs_pop1, e4_rs_pop2, e4_rs_hold;
   // E1 based 
   assign e4_rs_correct = dec_tlu_flush_lower_wb;
   assign e1_null = exu_rets_e1_pkt.pc0_call & exu_rets_e1_pkt.pc1_ret;
   assign e1_rs_push1 = (exu_rets_e1_pkt.pc0_call ^ exu_rets_e1_pkt.pc1_call) & ~e1_null & ~e4_rs_correct;
   assign e1_rs_push2 = (exu_rets_e1_pkt.pc0_call & exu_rets_e1_pkt.pc1_call) & ~e4_rs_correct;
   assign e1_rs_pop1 = (exu_rets_e1_pkt.pc0_ret ^ exu_rets_e1_pkt.pc1_ret) & ~e4_rs_correct;
   assign e1_rs_pop2 = (exu_rets_e1_pkt.pc0_ret & exu_rets_e1_pkt.pc1_ret) & ~e4_rs_correct;
   assign e1_rs_hold = (~e1_rs_push1 & ~e1_rs_push2 & ~e1_rs_pop1 & ~e1_rs_pop2 & ~e4_rs_correct);

   rvbradder e1_rs_addr0 (.pc({exu_i0_pc_e1[31:1]}),
                        .offset({10'b0, exu_rets_e1_pkt.pc0_pc4, ~exu_rets_e1_pkt.pc0_pc4}),
                        .dout(e1_rs_call0_target_f2[31:1])                      
                        );
   rvbradder e1_rs_addr1 (.pc({exu_i1_pc_e1[31:1]}),
                        .offset({10'b0, exu_rets_e1_pkt.pc1_pc4, ~exu_rets_e1_pkt.pc1_pc4}),
                        .dout(e1_rs_call1_target_f2[31:1])                      
                        );

   assign e1_rs_call_target_f2[31:1] = exu_rets_e1_pkt.pc0_call ? e1_rs_call0_target_f2[31:1] : e1_rs_call1_target_f2[31:1];
   
   assign e1_rets_in[0][31:1] = ( ({31{e1_rs_push1}} & e1_rs_call_target_f2[31:1]) |
                                  ({31{e1_rs_push2}} & e1_rs_call1_target_f2[31:1]) |
                                  ({31{e1_rs_pop1}}  & e1_rets_out[1][31:1]) |
                                  ({31{e1_rs_pop2}}  & e1_rets_out[2][31:1]) |
                                  ({31{e4_rs_correct}}  & e4_rets_out[0][31:1]) |
                                  ({31{e1_rs_hold}}  & e1_rets_out[0][31:1]) );

   assign e1_rets_in[1][31:1] = ( ({31{e1_rs_push1}} & e1_rets_out[0][31:1]) |
                                  ({31{e1_rs_push2}} & e1_rs_call0_target_f2[31:1]) |
                                  ({31{e1_rs_pop1}}  & e1_rets_out[2][31:1]) |
                                  ({31{e1_rs_pop2}}  & e1_rets_out[3][31:1]) |
                                  ({31{e4_rs_correct}}  & e4_rets_out[1][31:1]) |
                                  ({31{e1_rs_hold}}  & e1_rets_out[0][31:1]) );


   for (i=0; i<`RV_RET_STACK_SIZE; i++) begin : e1_retstack

      // for the last entry in the stack, we don't have a pop position
      if(i==`RV_RET_STACK_SIZE-1) 
        assign e1_rets_in[i][31:1] = ( ({31{e1_rs_push1}} & e1_rets_out[i-1][31:1]) |
                                       ({31{e1_rs_push2}} & e1_rets_out[i-2][31:1]) |
                                       ({31{e4_rs_correct}}  & e4_rets_out[i][31:1]) |
                                       ({31{e1_rs_hold}}  & e1_rets_out[i][31:1]) );
      else if(i==`RV_RET_STACK_SIZE-2)
        assign e1_rets_in[i][31:1] = ( ({31{e1_rs_push1}} & e1_rets_out[i-1][31:1]) |
                                       ({31{e1_rs_push2}} & e1_rets_out[i-2][31:1]) |
                                       ({31{e1_rs_pop1}}  & e1_rets_out[i+1][31:1]) |
                                       ({31{e4_rs_correct}} & e4_rets_out[i][31:1]) |
                                       ({31{e1_rs_hold}}  & e1_rets_out[i][31:1]) );
 
      else if(i>1)
        assign e1_rets_in[i][31:1] = ( ({31{e1_rs_push1}} & e1_rets_out[i-1][31:1]) |
                                       ({31{e1_rs_push2}} & e1_rets_out[i-2][31:1]) |
                                       ({31{e1_rs_pop1}}  & e1_rets_out[i+1][31:1]) |
                                       ({31{e1_rs_pop2}}  & e1_rets_out[i+2][31:1]) |
                                       ({31{e4_rs_correct}} & e4_rets_out[i][31:1]) |
                                       ({31{e1_rs_hold}}  & e1_rets_out[i][31:1]) );

      
      rvdff #(31) e1_rets_ff (.*, .din(e1_rets_in[i][31:1]), .dout(e1_rets_out[i][31:1]));

   end : e1_retstack

   // E4 based 
   assign e4_null = exu_rets_e4_pkt.pc0_call & exu_rets_e4_pkt.pc1_ret;
   assign e4_rs_push1 = (exu_rets_e4_pkt.pc0_call ^ exu_rets_e4_pkt.pc1_call) & ~e4_null;
   assign e4_rs_push2 = (exu_rets_e4_pkt.pc0_call & exu_rets_e4_pkt.pc1_call);
   assign e4_rs_pop1 = (exu_rets_e4_pkt.pc0_ret ^ exu_rets_e4_pkt.pc1_ret);
   assign e4_rs_pop2 = (exu_rets_e4_pkt.pc0_ret & exu_rets_e4_pkt.pc1_ret);
   assign e4_rs_hold = (~e4_rs_push1 & ~e4_rs_push2 & ~e4_rs_pop1 & ~e4_rs_pop2);

   rvbradder e4_rs_addr0 (.pc({dec_tlu_i0_pc_e4[31:1]}),
                        .offset({10'b0, exu_rets_e4_pkt.pc0_pc4, ~exu_rets_e4_pkt.pc0_pc4}),
                        .dout(e4_rs_call0_target_f2[31:1])                      
                        );
   rvbradder e4_rs_addr1 (.pc({dec_tlu_i1_pc_e4[31:1]}),
                        .offset({10'b0, exu_rets_e4_pkt.pc1_pc4, ~exu_rets_e4_pkt.pc1_pc4}),
                        .dout(e4_rs_call1_target_f2[31:1])                      
                        );

   assign e4_rs_call_target_f2[31:1] = exu_rets_e4_pkt.pc0_call ? e4_rs_call0_target_f2[31:1] : e4_rs_call1_target_f2[31:1];
   
   assign e4_rets_in[0][31:1] = ( ({31{e4_rs_push1}} & e4_rs_call_target_f2[31:1]) |
                                  ({31{e4_rs_push2}} & e4_rs_call1_target_f2[31:1]) |
                                  ({31{e4_rs_pop1}}  & e4_rets_out[1][31:1]) |
                                  ({31{e4_rs_pop2}}  & e4_rets_out[2][31:1]) |
                                  ({31{e4_rs_hold}}  & e4_rets_out[0][31:1]) );

   assign e4_rets_in[1][31:1] = ( ({31{e4_rs_push1}} & e4_rets_out[0][31:1]) |
                                  ({31{e4_rs_push2}} & e4_rs_call0_target_f2[31:1]) |
                                  ({31{e4_rs_pop1}}  & e4_rets_out[2][31:1]) |
                                  ({31{e4_rs_pop2}}  & e4_rets_out[3][31:1]) |
                                  ({31{e4_rs_hold}}  & e4_rets_out[0][31:1]) );


   for (i=0; i<`RV_RET_STACK_SIZE; i++) begin : e4_retstack

      // for the last entry in the stack, we don't have a pop position
      if(i==`RV_RET_STACK_SIZE-1) 
        assign e4_rets_in[i][31:1] = ( ({31{e4_rs_push1}} & e4_rets_out[i-1][31:1]) |
                                       ({31{e4_rs_push2}} & e4_rets_out[i-2][31:1]) |
                                       ({31{e4_rs_hold}}  & e4_rets_out[i][31:1]) );
      else if(i==`RV_RET_STACK_SIZE-2)
        assign e4_rets_in[i][31:1] = ( ({31{e4_rs_push1}} & e4_rets_out[i-1][31:1]) |
                                       ({31{e4_rs_push2}} & e4_rets_out[i-2][31:1]) |
                                       ({31{e4_rs_pop1}}  & e4_rets_out[i+1][31:1]) |
                                       ({31{e4_rs_hold}}  & e4_rets_out[i][31:1]) );
 
      else if(i>1)
        assign e4_rets_in[i][31:1] = ( ({31{e4_rs_push1}} & e4_rets_out[i-1][31:1]) |
                                       ({31{e4_rs_push2}} & e4_rets_out[i-2][31:1]) |
                                       ({31{e4_rs_pop1}}  & e4_rets_out[i+1][31:1]) |
                                       ({31{e4_rs_pop2}}  & e4_rets_out[i+2][31:1]) |
                                       ({31{e4_rs_hold}}  & e4_rets_out[i][31:1]) );

      
      rvdff #(31) e4_rets_ff (.*, .din(e4_rets_in[i][31:1]), .dout(e4_rets_out[i][31:1]));

   end : e4_retstack

`endif //  `ifdef REAL_COMM_RS
   


   // ----------------------------------------------------------------------
   // WRITE
   // ----------------------------------------------------------------------

   
   assign dec_tlu_error_wb = dec_tlu_br0_start_error_wb | dec_tlu_br0_error_wb | dec_tlu_br1_start_error_wb | dec_tlu_br1_error_wb;
   assign dec_tlu_all_banks_error_wb = dec_tlu_br0_start_error_wb | (~dec_tlu_br0_error_wb & dec_tlu_br1_start_error_wb);

   assign dec_tlu_error_bank_wb[1:0] = (dec_tlu_br0_error_wb | dec_tlu_br0_start_error_wb) ? dec_tlu_br0_bank_wb[1:0] : dec_tlu_br1_bank_wb[1:0];
   assign btb_error_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = (dec_tlu_br0_error_wb | dec_tlu_br0_start_error_wb) ? dec_tlu_br0_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] : dec_tlu_br1_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   assign dec_tlu_way_wb = (dec_tlu_br0_error_wb | dec_tlu_br0_start_error_wb) ? dec_tlu_br0_way_wb : dec_tlu_br1_way_wb;   

   assign btb_valid = exu_mp_valid & ~dec_tlu_error_wb;

   assign btb_wr_tag[`RV_BTB_BTAG_SIZE-1:0] = exu_mp_btag[`RV_BTB_BTAG_SIZE-1:0];
   rvbtb_tag_hash rdtagf1(.hash(fetch_rd_tag_f1[`RV_BTB_BTAG_SIZE-1:0]), .pc({ifc_fetch_addr_f1[31:4], 3'b0}));
   rvdff #(`RV_BTB_BTAG_SIZE) rdtagf (.*, .clk(active_clk), .din({fetch_rd_tag_f1[`RV_BTB_BTAG_SIZE-1:0]}), .dout({fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]}));
   
   assign btb_wr_data[16+`RV_BTB_BTAG_SIZE:0] = {btb_wr_tag[`RV_BTB_BTAG_SIZE-1:0], exu_mp_tgt[11:0], exu_mp_pc4, exu_mp_boffset, exu_mp_call | exu_mp_ja, exu_mp_ret | exu_mp_ja, btb_valid} ;

   assign exu_mp_valid_write = exu_mp_valid & exu_mp_ataken;
`ifdef RV_BTB_48                     

   assign btb_wr_en_way0[3:0] = ( ({4{(exu_mp_way==2'b0) & exu_mp_valid_write & ~dec_tlu_error_wb}} & decode2_4(exu_mp_bank[1:0])) |
                                  ({4{(dec_tlu_way_wb==2'b0) & dec_tlu_error_wb & ~dec_tlu_all_banks_error_wb}} & decode2_4(dec_tlu_error_bank_wb[1:0])) |
                                  ({4{(dec_tlu_way_wb==2'b0) & dec_tlu_all_banks_error_wb}}));
                             
   assign btb_wr_en_way1[3:0] = ( ({4{exu_mp_way[0] & exu_mp_valid_write & ~dec_tlu_error_wb}} & decode2_4(exu_mp_bank[1:0])) |
                                  ({4{dec_tlu_way_wb[0] & dec_tlu_error_wb & ~dec_tlu_all_banks_error_wb}} & decode2_4(dec_tlu_error_bank_wb[1:0])) |
                                  ({4{dec_tlu_way_wb[0] & dec_tlu_all_banks_error_wb}}));
   
   assign btb_wr_en_way2[3:0] = ( ({4{exu_mp_way[1] & exu_mp_valid_write & ~dec_tlu_error_wb}} & decode2_4(exu_mp_bank[1:0])) |
                                  ({4{dec_tlu_way_wb[1] & dec_tlu_error_wb & ~dec_tlu_all_banks_error_wb}} & decode2_4(dec_tlu_error_bank_wb[1:0])) |
                                  ({4{dec_tlu_way_wb[1] & dec_tlu_all_banks_error_wb}}));
`else // !`ifdef RV_BTB_48
   assign btb_wr_en_way0[3:0] = ( ({4{~exu_mp_way & exu_mp_valid_write & ~dec_tlu_error_wb}} & decode2_4(exu_mp_bank[1:0])) |
                                  ({4{~dec_tlu_way_wb & dec_tlu_error_wb & ~dec_tlu_all_banks_error_wb}} & decode2_4(dec_tlu_error_bank_wb[1:0])) |
                                  ({4{~dec_tlu_way_wb & dec_tlu_all_banks_error_wb}}));
                             
   assign btb_wr_en_way1[3:0] = ( ({4{exu_mp_way & exu_mp_valid_write & ~dec_tlu_error_wb}} & decode2_4(exu_mp_bank[1:0])) |
                                  ({4{dec_tlu_way_wb & dec_tlu_error_wb & ~dec_tlu_all_banks_error_wb}} & decode2_4(dec_tlu_error_bank_wb[1:0])) |
                                  ({4{dec_tlu_way_wb & dec_tlu_all_banks_error_wb}}));
   
   
`endif
                             
   assign btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = dec_tlu_error_wb ? btb_error_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] : exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   logic [1:0] bht_wr_data0, bht_wr_data1, bht_wr_data2;
   logic [7:0] bht_wr_en0, bht_wr_en1, bht_wr_en2;

   assign middle_of_bank = exu_mp_pc4 ^ exu_mp_boffset;
   assign bht_wr_en0[7:0] = {8{exu_mp_valid & ~exu_mp_call & ~exu_mp_ret & ~exu_mp_ja}} & decode3_8({exu_mp_bank[1:0], middle_of_bank});
   assign bht_wr_en1[7:0] = {8{dec_tlu_br1_v_wb}} & decode3_8({dec_tlu_br1_bank_wb[1:0], dec_tlu_br1_middle_wb});
   assign bht_wr_en2[7:0] = {8{dec_tlu_br0_v_wb}} & decode3_8({dec_tlu_br0_bank_wb[1:0], dec_tlu_br0_middle_wb});

   // Experiments show this is the best priority scheme for same bank/index writes at the same time. 
   assign bht_wr_data0[1:0] = exu_mp_hist[1:0]; // lowest priority 
   assign bht_wr_data1[1:0] = dec_tlu_br1_hist_wb[1:0];
   assign bht_wr_data2[1:0] = dec_tlu_br0_hist_wb[1:0]; // highest priority 



   logic [`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] bht_rd_addr_f1, bht_wr_addr0, bht_wr_addr1, bht_wr_addr2;

   logic [`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] mp_hashed, br0_hashed_wb, br1_hashed_wb, bht_rd_addr_hashed_f1;
   rvbtb_ghr_hash mpghrhs  (.hashin(exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(exu_mp_eghr[`RV_BHT_GHR_RANGE]), .hash(mp_hashed[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));
   rvbtb_ghr_hash br0ghrhs (.hashin(dec_tlu_br0_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(dec_tlu_br0_fghr_wb[`RV_BHT_GHR_RANGE]), .hash(br0_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));
   rvbtb_ghr_hash br1ghrhs (.hashin(dec_tlu_br1_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(dec_tlu_br1_fghr_wb[`RV_BHT_GHR_RANGE]), .hash(br1_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));
   rvbtb_ghr_hash fghrhs (.hashin(btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(fghr_ns[`RV_BHT_GHR_RANGE]), .hash(bht_rd_addr_hashed_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));

   assign bht_wr_addr0[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = mp_hashed[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];
   assign bht_wr_addr1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = br1_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];
   assign bht_wr_addr2[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = br0_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];
   assign bht_rd_addr_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = bht_rd_addr_hashed_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];

   
   // ----------------------------------------------------------------------
   // Structures. Using FLOPS 
   // ----------------------------------------------------------------------
   // BTB
   // Entry -> tag[`RV_BTB_BTAG_SIZE-1:0], toffset[11:0], pc4, boffset, call, ret, valid
   
    
    for (j=0 ; j<LRU_SIZE ; j++) begin : BTB_FLOPS
      // Way 0
          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way0 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[0])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way0_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way0 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[1])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way0_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way0 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[2])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way0_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way0 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[3])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way0_out[j]));

      // Way 1
          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way1 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[0])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way1_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way1 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[1])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way1_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way1 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[2])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way1_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way1 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[3])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way1_out[j]));
`ifdef RV_BTB_48
      // Way 2
          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way2 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way2[0])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way2_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way2 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way2[1])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way2_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way2 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way2[2])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way2_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way2 (.*,  
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way2[3])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way2_out[j]));
`endif
    end

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way0_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank0_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way0_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank1_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way0_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank2_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way0_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank3_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way1_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank0_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way1_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank1_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way1_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank2_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way1_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank3_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));

`ifdef RV_BTB_48
   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way2_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank0_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way2_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way2_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank1_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way2_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way2_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank2_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way2_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way2_data_out (.*,  
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank3_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way2_f2   [16+`RV_BTB_BTAG_SIZE:0]));
`endif //  `ifdef RV_BTB_48
   
    always_comb begin : BTB_rd_mux 
        btb_bank0_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
        btb_bank1_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
        btb_bank2_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
        btb_bank3_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 

        btb_bank0_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
        btb_bank1_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
        btb_bank2_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
        btb_bank3_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 

`ifdef RV_BTB_48
       btb_bank0_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
       btb_bank1_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
       btb_bank2_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
       btb_bank3_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ; 
`endif
        for (int j=0; j< LRU_SIZE; j++) begin 
          if (btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == (`RV_BTB_ADDR_HI-`RV_BTB_ADDR_LO+1)'(j)) begin 

           btb_bank0_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank0_rd_data_way0_out[j];
           btb_bank1_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank1_rd_data_way0_out[j];
           btb_bank2_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank2_rd_data_way0_out[j];
           btb_bank3_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank3_rd_data_way0_out[j];

           btb_bank0_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank0_rd_data_way1_out[j];
           btb_bank1_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank1_rd_data_way1_out[j];
           btb_bank2_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank2_rd_data_way1_out[j];
           btb_bank3_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank3_rd_data_way1_out[j];

`ifdef RV_BTB_48
           btb_bank0_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank0_rd_data_way2_out[j];
           btb_bank1_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank1_rd_data_way2_out[j];
           btb_bank2_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank2_rd_data_way2_out[j];
           btb_bank3_rd_data_way2_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank3_rd_data_way2_out[j];
`endif
             
          end
        end
    end

   //-----------------------------------------------------------------------------
   // BHT
   // 2 bit Entry -> direction, strength
   // 
   //-----------------------------------------------------------------------------

   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0][NUM_BHT_LOOP-1:0][1:0]      bht_bank_wr_data ;
   logic [7:0] [`RV_BHT_ARRAY_DEPTH-1:0] [1:0]                bht_bank_rd_data_out ;
   logic [1:0]                                                bht_bank0_rd_data_f2_in, bht_bank1_rd_data_f2_in, bht_bank2_rd_data_f2_in, bht_bank3_rd_data_f2_in;    
   logic [1:0]                                                bht_bank4_rd_data_f2_in, bht_bank5_rd_data_f2_in, bht_bank6_rd_data_f2_in, bht_bank7_rd_data_f2_in;    
   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0]                 bht_bank_clken ;
   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0]                 bht_bank_clk   ;
   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0][NUM_BHT_LOOP-1:0]           bht_bank_sel   ;

   for ( i=0; i<8; i++) begin : BANKS    
     for (genvar k=0 ; k < (`RV_BHT_ARRAY_DEPTH)/NUM_BHT_LOOP ; k++) begin : BHT_CLK_GROUP
     assign bht_bank_clken[i][k]  = (bht_wr_en0[i] & ((bht_wr_addr0[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) |  BHT_NO_ADDR_MATCH)) |   
                                    (bht_wr_en1[i] & ((bht_wr_addr1[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) |  BHT_NO_ADDR_MATCH)) |   
                                    (bht_wr_en2[i] & ((bht_wr_addr2[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) |  BHT_NO_ADDR_MATCH));   

     rvclkhdr bht_bank_grp_cgc ( .en(bht_bank_clken[i][k]), .l1clk(bht_bank_clk[i][k]), .* );
 
     for (j=0 ; j<NUM_BHT_LOOP ; j++) begin : BHT_FLOPS
       assign   bht_bank_sel[i][k][j]    = (bht_wr_en0[i] & (bht_wr_addr0[NUM_BHT_LOOP_INNER_HI :`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr0[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) |
                                           (bht_wr_en1[i] & (bht_wr_addr1[NUM_BHT_LOOP_INNER_HI :`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr1[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) |
                                           (bht_wr_en2[i] & (bht_wr_addr2[NUM_BHT_LOOP_INNER_HI :`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr2[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) ;

       assign bht_bank_wr_data[i][k][j]  = (bht_wr_en2[i] & (bht_wr_addr2[NUM_BHT_LOOP_INNER_HI:`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr2[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) ? bht_wr_data2[1:0] :
                                           (bht_wr_en1[i] & (bht_wr_addr1[NUM_BHT_LOOP_INNER_HI:`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr1[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) ? bht_wr_data1[1:0] :
                                                                                                                      bht_wr_data0[1:0]   ; 

          
          rvdffs #(2) bht_bank (.*,  
                    .clk        (bht_bank_clk[i][k]),
                    .en         (bht_bank_sel[i][k][j]),
                    .din        (bht_bank_wr_data[i][k][j]),
                    .dout       (bht_bank_rd_data_out[i][(16*k)+j]));

      end // block: BHT_FLOPS
   end // block: BHT_CLK_GROUP
 end // block: BANKS
                                         
    always_comb begin : BHT_rd_mux 
     bht_bank0_rd_data_f2_in[1:0] = '0 ; 
     bht_bank1_rd_data_f2_in[1:0] = '0 ; 
     bht_bank2_rd_data_f2_in[1:0] = '0 ; 
     bht_bank3_rd_data_f2_in[1:0] = '0 ;
     bht_bank4_rd_data_f2_in[1:0] = '0 ; 
     bht_bank5_rd_data_f2_in[1:0] = '0 ; 
     bht_bank6_rd_data_f2_in[1:0] = '0 ; 
     bht_bank7_rd_data_f2_in[1:0] = '0 ;
     for (int j=0; j< `RV_BHT_ARRAY_DEPTH; j++) begin
       if (bht_rd_addr_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] == (`RV_BHT_ADDR_HI-`RV_BHT_ADDR_LO+1)'(j)) begin  
         bht_bank0_rd_data_f2_in[1:0] = bht_bank_rd_data_out[0][j];
         bht_bank1_rd_data_f2_in[1:0] = bht_bank_rd_data_out[1][j];
         bht_bank2_rd_data_f2_in[1:0] = bht_bank_rd_data_out[2][j];
         bht_bank3_rd_data_f2_in[1:0] = bht_bank_rd_data_out[3][j];
         bht_bank4_rd_data_f2_in[1:0] = bht_bank_rd_data_out[4][j];
         bht_bank5_rd_data_f2_in[1:0] = bht_bank_rd_data_out[5][j];
         bht_bank6_rd_data_f2_in[1:0] = bht_bank_rd_data_out[6][j];
         bht_bank7_rd_data_f2_in[1:0] = bht_bank_rd_data_out[7][j];
       end
      end
    end // block: BHT_rd_mux
                                         
                                        

   rvdffe #(16) bht_dataoutf (.*, .en         (ifc_fetch_req_f1),
                                 .din        ({bht_bank0_rd_data_f2_in[1:0],
                                               bht_bank1_rd_data_f2_in[1:0],
                                               bht_bank2_rd_data_f2_in[1:0],
                                               bht_bank3_rd_data_f2_in[1:0],
                                               bht_bank4_rd_data_f2_in[1:0],
                                               bht_bank5_rd_data_f2_in[1:0],
                                               bht_bank6_rd_data_f2_in[1:0],
                                               bht_bank7_rd_data_f2_in[1:0]
                                               }),
                                 .dout       ({bht_bank0_rd_data_f2   [1:0],
                                               bht_bank1_rd_data_f2   [1:0],
                                               bht_bank2_rd_data_f2   [1:0],
                                               bht_bank3_rd_data_f2   [1:0],
                                               bht_bank4_rd_data_f2   [1:0],
                                               bht_bank5_rd_data_f2   [1:0],
                                               bht_bank6_rd_data_f2   [1:0],
                                               bht_bank7_rd_data_f2   [1:0]
                                               }));


   

     function [2:0] encode8_3;
      input [7:0] in;

      encode8_3[2] = |in[7:4];
      encode8_3[1] = in[7] | in[6] | in[3] | in[2];
      encode8_3[0] = in[7] | in[5] | in[3] | in[1];

   endfunction  
   function [7:0] decode3_8;
      input [2:0] in;
      
      decode3_8[7] =  in[2] &  in[1] &  in[0];
      decode3_8[6] =  in[2] &  in[1] & ~in[0];
      decode3_8[5] =  in[2] & ~in[1] &  in[0];
      decode3_8[4] =  in[2] & ~in[1] & ~in[0];
      decode3_8[3] = ~in[2] &  in[1] &  in[0];
      decode3_8[2] = ~in[2] &  in[1] & ~in[0];
      decode3_8[1] = ~in[2] & ~in[1] &  in[0];
      decode3_8[0] = ~in[2] & ~in[1] & ~in[0];
      
   endfunction  
   function [3:0] decode2_4;
      input [1:0] in;
      
      decode2_4[3] =  in[1] &  in[0];
      decode2_4[2] =  in[1] & ~in[0];
      decode2_4[1] = ~in[1] &  in[0];
      decode2_4[0] = ~in[1] & ~in[0];
      
   endfunction 

   function [3:0] countones;
      input [7:0] valid;

      begin

countones[3:0] = {3'b0, valid[7]} +
                 {3'b0, valid[6]} +                                      
                 {3'b0, valid[5]} +                                      
                 {3'b0, valid[4]} +                                      
                 {3'b0, valid[3]} +                                      
                 {3'b0, valid[2]} +                                      
                 {3'b0, valid[1]} +                                      
                 {3'b0, valid[0]};                                      
      end
   endfunction
   function [2:0] newlru; // updated lru
      input [2:0] lru;// current lru
      input [1:0] used;// hit way
      begin
`ifdef BTB_ROUND_ROBIN
newlru[2] = 1'b0;
newlru[1:0] = (lru[1:0]==2'b10) ? 2'b0 : lru[1:0] + 2'b01;
`else
newlru[2] = (lru[2] & ~used[0]) | (~used[1] & ~used[0]);
newlru[1] = (~used[1] & ~used[0]) | (used[0]);
newlru[0] = (~lru[2] & lru[1] & ~used[1] & ~used[0]) | (~lru[1] & ~lru[0] & used[0]) | (
    ~lru[2] & lru[0] & used[0]) | (lru[0] & ~used[1] & ~used[0]);
`endif
      end
   endfunction //
   
   function [1:0] lru2way; // new repl way taking invalid ways into account
      input [2:0] lru; // current lru
      input [2:0] v; // current way valids
      begin
`ifdef BTB_ROUND_ROBIN
         lru2way[1:0] = lru[1:0];
`else
         lru2way[1] = (~lru[2] & lru[1] & ~lru[0] & v[1] & v[0]) | (lru[2] & lru[0] & v[1] & v[0]) | (~v[2] & v[1] & v[0]);
         lru2way[0] = (lru[2] & ~lru[0] & v[2] & v[0]) | (~v[1] & v[0]);
`endif
      end
   endfunction

endmodule // ifu_bp_ctl

