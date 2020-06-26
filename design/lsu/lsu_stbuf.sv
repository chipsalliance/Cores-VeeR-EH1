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
// $Id$
//
//
// Owner:
// Function: Store Buffer
// Comments: Dual writes and single drain
//
//
// DC1 -> DC2 -> DC3 -> DC4 (Commit)
//
// //********************************************************************************


module lsu_stbuf
   import swerv_types::*;
(
   input logic        clk,                                // core clock
   input logic        rst_l,                              // reset

   input logic        lsu_freeze_c2_dc2_clk,              // freeze clock
   input logic        lsu_freeze_c2_dc3_clk,              // freeze clock
   input logic        lsu_freeze_c1_dc2_clk,              // freeze clock
   input logic        lsu_freeze_c1_dc3_clk,              // freeze clock

   input logic        lsu_freeze_c2_dc2_clken,
   input logic        lsu_freeze_c2_dc3_clken,
   input logic        lsu_freeze_c1_dc2_clken,
   input logic        lsu_freeze_c1_dc3_clken,

   input logic        lsu_c1_dc4_clk,                     // lsu pipe clock
   input logic        lsu_c1_dc5_clk,                     // lsu pipe clock
   input logic        lsu_c2_dc4_clk,                     // lsu pipe clock
   input logic        lsu_c2_dc5_clk,                     // lsu pipe clock
   input logic        lsu_stbuf_c1_clk,                   // stbuf clock
   input logic        lsu_free_c2_clk,                    // free clk

   // Store Buffer input
   input logic        load_stbuf_reqvld_dc3,             // core instruction goes to stbuf
   input logic        store_stbuf_reqvld_dc3,             // core instruction goes to stbuf
   //input logic        ldst_stbuf_reqvld_dc3,
   input logic        addr_in_pic_dc2,                    // address is in pic
   input logic        addr_in_pic_dc3,                    // address is in pic
   input logic        addr_in_dccm_dc2,                    // address is in pic
   input logic        addr_in_dccm_dc3,                    // address is in pic
   input logic [`RV_DCCM_DATA_WIDTH-1:0] store_ecc_datafn_hi_dc3,   // data to write
   input logic [`RV_DCCM_DATA_WIDTH-1:0] store_ecc_datafn_lo_dc3,   // data to write

   input logic        isldst_dc1,                         // instruction in dc1 is lsu
   input logic        dccm_ldst_dc2,                         // instruction in dc2 is lsu
   input logic        dccm_ldst_dc3,                         // instruction in dc3 is lsu

   input logic        single_ecc_error_hi_dc3,            // single ecc error in hi bank
   input logic        single_ecc_error_lo_dc3,            // single ecc error in lo bank
   input logic        lsu_single_ecc_error_dc5,           // single_ecc_error in either bank staged to the dc5 - needed for the load repairs
   input logic        lsu_commit_dc5,                     // lsu commits
   input logic        lsu_freeze_dc3,                     // lsu freeze
   input logic        flush_prior_dc5,                    // Flush is due to i0 and ld/st is in i1

   // Store Buffer output
   output logic                  stbuf_reqvld_any,         // stbuf is draining
   output logic                  stbuf_reqvld_flushed_any, // Top entry is flushed
   output logic                  stbuf_addr_in_pic_any,    // address maps to pic
   output logic [`RV_DCCM_BYTE_WIDTH-1:0] stbuf_byteen_any, // which bytes are active
   output logic [`RV_LSU_SB_BITS-1:0]  stbuf_addr_any,        // address
   output logic [`RV_DCCM_DATA_WIDTH-1:0] stbuf_data_any,   // stbuf data

   input  logic       lsu_stbuf_commit_any,                 // pop the stbuf as it commite
   output logic       lsu_stbuf_full_any,                   // stbuf is full
   output logic       lsu_stbuf_empty_any,                  // stbuf is empty
   output logic       lsu_stbuf_nodma_empty_any,            // stbuf is empty except dma
   output logic       lsu_load_ecc_stbuf_full_dc3,          // Load with ecc error can't allocate to stbuf

   input logic [`RV_LSU_SB_BITS-1:0] lsu_addr_dc1,            // lsu address
   input logic [`RV_LSU_SB_BITS-1:0] lsu_addr_dc2,
   input logic [`RV_LSU_SB_BITS-1:0] lsu_addr_dc3,

   input logic [`RV_LSU_SB_BITS-1:0] end_addr_dc1,            // lsu end addrress - needed to check unaligned
   input logic [`RV_LSU_SB_BITS-1:0] end_addr_dc2,
   input logic [`RV_LSU_SB_BITS-1:0] end_addr_dc3,

   // Forwarding signals
   input logic        lsu_cmpen_dc2,                       // needed for forwarding stbuf - load
   input lsu_pkt_t    lsu_pkt_dc2,
   input lsu_pkt_t    lsu_pkt_dc3,
   input lsu_pkt_t    lsu_pkt_dc5,

   output logic [`RV_DCCM_DATA_WIDTH-1:0] stbuf_fwddata_hi_dc3,     // stbuf data
   output logic [`RV_DCCM_DATA_WIDTH-1:0] stbuf_fwddata_lo_dc3,
   output logic [`RV_DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_hi_dc3,
   output logic [`RV_DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_lo_dc3,

   input  logic       scan_mode

);

`include "global.h"

   localparam DEPTH = LSU_STBUF_DEPTH;
   localparam DATA_WIDTH = DCCM_DATA_WIDTH;
   localparam BYTE_WIDTH = DCCM_BYTE_WIDTH;
   localparam DEPTH_LOG2 = $clog2(DEPTH);

   logic [DEPTH-1:0]       stbuf_data_vld;
   logic [DEPTH-1:0]       stbuf_drain_vld;
   logic [DEPTH-1:0]       stbuf_flush_vld;
   logic [DEPTH-1:0]       stbuf_addr_in_pic;
   logic [DEPTH-1:0]       stbuf_dma;
   logic [DEPTH-1:0][LSU_SB_BITS-1:0] stbuf_addr;
   logic [DEPTH-1:0][BYTE_WIDTH-1:0]  stbuf_byteen;
   logic [DEPTH-1:0][DATA_WIDTH-1:0] stbuf_data;

   logic [DEPTH-1:0]       sel_lo;
   logic [DEPTH-1:0]       stbuf_wr_en;
   logic [DEPTH-1:0]       stbuf_data_en;
   logic [DEPTH-1:0]       stbuf_drain_or_flush_en;
   logic [DEPTH-1:0]       stbuf_flush_en;
   logic [DEPTH-1:0]       stbuf_drain_en;
   logic [DEPTH-1:0]       stbuf_reset;
   logic [DEPTH-1:0][LSU_SB_BITS-1:0] stbuf_addrin;
   logic [DEPTH-1:0][DATA_WIDTH-1:0] stbuf_datain;
   logic [DEPTH-1:0][BYTE_WIDTH-1:0]  stbuf_byteenin;

   logic [7:0]             ldst_byteen_dc3;
   logic [7:0]             store_byteen_ext_dc3;
   logic [BYTE_WIDTH-1:0]  store_byteen_hi_dc3;
   logic [BYTE_WIDTH-1:0]  store_byteen_lo_dc3;

   logic                   ldst_stbuf_reqvld_dc3;
   logic                   dual_ecc_error_dc3;
   logic                   dual_stbuf_write_dc3;

   logic                   WrPtrEn, RdPtrEn;
   logic [DEPTH_LOG2-1:0]  WrPtr, RdPtr;
   logic [DEPTH_LOG2-1:0]  NxtWrPtr, NxtRdPtr;
   logic [DEPTH_LOG2-1:0]  WrPtrPlus1, WrPtrPlus1_dc5, WrPtrPlus2, RdPtrPlus1;
   logic [DEPTH_LOG2-1:0]  WrPtr_dc3, WrPtr_dc4, WrPtr_dc5;
   logic                   ldst_dual_dc1, ldst_dual_dc2, ldst_dual_dc3, ldst_dual_dc4, ldst_dual_dc5;
   logic                   ldst_stbuf_reqvld_dc4, ldst_stbuf_reqvld_dc5;
   logic                   dual_stbuf_write_dc4, dual_stbuf_write_dc5;

   logic [3:0]             stbuf_numvld_any, stbuf_specvld_any;
   logic [1:0]             stbuf_specvld_dc1, stbuf_specvld_dc2, stbuf_specvld_dc3;
   logic                   stbuf_oneavl_any, stbuf_twoavl_any;

   logic                   cmpen_hi_dc2, cmpen_lo_dc2, jit_in_same_region;

   logic [LSU_SB_BITS-1:$clog2(BYTE_WIDTH)]  cmpaddr_hi_dc2, cmpaddr_lo_dc2;

   logic                   stbuf_ldmatch_hi_hi, stbuf_ldmatch_hi_lo;
   logic                   stbuf_ldmatch_lo_hi, stbuf_ldmatch_lo_lo;
   logic [BYTE_WIDTH-1:0]  stbuf_fwdbyteen_hi_hi, stbuf_fwdbyteen_hi_lo;
   logic [BYTE_WIDTH-1:0]  stbuf_fwdbyteen_lo_hi, stbuf_fwdbyteen_lo_lo;
   logic [DATA_WIDTH-1:0]  stbuf_fwddata_hi_hi, stbuf_fwddata_hi_lo;
   logic [DATA_WIDTH-1:0]  stbuf_fwddata_lo_hi, stbuf_fwddata_lo_lo;

   logic [DEPTH-1:0]                 stbuf_ldmatch_hi, stbuf_ldmatch_lo;
   logic [DEPTH-1:0][BYTE_WIDTH-1:0] stbuf_fwdbyteenvec_hi, stbuf_fwdbyteenvec_lo;
   logic [DEPTH-1:0][DATA_WIDTH-1:0] stbuf_fwddatavec_hi, stbuf_fwddatavec_lo;
   logic [DATA_WIDTH-1:0]            stbuf_fwddata_hi_dc2, stbuf_fwddata_lo_dc2;
   logic [DATA_WIDTH-1:0]            stbuf_fwddata_hi_fn_dc2, stbuf_fwddata_lo_fn_dc2;
   logic [BYTE_WIDTH-1:0]            stbuf_fwdbyteen_hi_dc2, stbuf_fwdbyteen_lo_dc2;
   logic [BYTE_WIDTH-1:0]            stbuf_fwdbyteen_hi_fn_dc2, stbuf_fwdbyteen_lo_fn_dc2;
   logic                             stbuf_load_repair_dc5;
   //----------------------------------------
   // Logic starts here
   //----------------------------------------
   // Create high/low byte enables
   assign ldst_byteen_dc3[7:0] = ({8{lsu_pkt_dc3.by}}   & 8'b0000_0001) |
                                 ({8{lsu_pkt_dc3.half}} & 8'b0000_0011) |
                                 ({8{lsu_pkt_dc3.word}} & 8'b0000_1111) |
                                 ({8{lsu_pkt_dc3.dword}} & 8'b1111_1111);
   assign store_byteen_ext_dc3[7:0] = ldst_byteen_dc3[7:0] << lsu_addr_dc3[1:0];
   assign store_byteen_hi_dc3[BYTE_WIDTH-1:0] = store_byteen_ext_dc3[7:4];
   assign store_byteen_lo_dc3[BYTE_WIDTH-1:0] = store_byteen_ext_dc3[3:0];

   assign RdPtrPlus1[DEPTH_LOG2-1:0] = RdPtr[DEPTH_LOG2-1:0] + 1'b1;
   assign WrPtrPlus1[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0] + 1'b1;
   assign WrPtrPlus2[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0] + 2'b10;
   assign WrPtrPlus1_dc5[DEPTH_LOG2-1:0] = WrPtr_dc5[DEPTH_LOG2-1:0] + 1'b1;

   // ecc error on both hi/lo
   assign ldst_dual_dc1      = (lsu_addr_dc1[2] != end_addr_dc1[2]);
   assign dual_ecc_error_dc3 = (single_ecc_error_hi_dc3 & single_ecc_error_lo_dc3);
   assign dual_stbuf_write_dc3   = ldst_dual_dc3 & (store_stbuf_reqvld_dc3 | dual_ecc_error_dc3);
   assign ldst_stbuf_reqvld_dc3  = store_stbuf_reqvld_dc3 |
                                   (load_stbuf_reqvld_dc3 & (dual_ecc_error_dc3 ? stbuf_twoavl_any : stbuf_oneavl_any));   // Don't correct ecc if not enough entries. Load will be flushed and come back again
   assign stbuf_load_repair_dc5 = lsu_single_ecc_error_dc5 & (lsu_pkt_dc5.valid & lsu_pkt_dc5.load & ~flush_prior_dc5);

   // Store Buffer instantiation
   for (genvar i=0; i<DEPTH; i++) begin: GenStBuf
      assign stbuf_wr_en[i] = ldst_stbuf_reqvld_dc3 & ((i == WrPtr[DEPTH_LOG2-1:0]) |
                                                       (i == WrPtrPlus1[DEPTH_LOG2-1:0] & dual_stbuf_write_dc3));
      assign stbuf_data_en[i] = stbuf_wr_en[i];
      assign stbuf_drain_or_flush_en[i] = ldst_stbuf_reqvld_dc5 & ~lsu_pkt_dc5.dma & ((i == WrPtr_dc5[DEPTH_LOG2-1:0]) |
                                                                                      (i == WrPtrPlus1_dc5[DEPTH_LOG2-1:0] & dual_stbuf_write_dc5));
      assign stbuf_drain_en[i] = (stbuf_drain_or_flush_en[i] & lsu_commit_dc5) | (stbuf_wr_en[i] & lsu_pkt_dc3.dma);
      assign stbuf_flush_en[i] = stbuf_drain_or_flush_en[i] & ~lsu_commit_dc5;
      assign stbuf_reset[i] = (lsu_stbuf_commit_any | stbuf_reqvld_flushed_any) & (i == RdPtr[DEPTH_LOG2-1:0]);

      // Mux select for start/end address
      assign sel_lo[i] = (~ldst_dual_dc3 | (store_stbuf_reqvld_dc3 | single_ecc_error_lo_dc3)) & (i == WrPtr[DEPTH_LOG2-1:0]);
      assign stbuf_addrin[i][LSU_SB_BITS-1:0]  = sel_lo[i] ? lsu_addr_dc3[LSU_SB_BITS-1:0] : end_addr_dc3[LSU_SB_BITS-1:0];
      assign stbuf_byteenin[i][BYTE_WIDTH-1:0] = sel_lo[i] ? store_byteen_lo_dc3[BYTE_WIDTH-1:0] : store_byteen_hi_dc3[BYTE_WIDTH-1:0];
      assign stbuf_datain[i][DATA_WIDTH-1:0]  = sel_lo[i] ? store_ecc_datafn_lo_dc3[DATA_WIDTH-1:0] : store_ecc_datafn_hi_dc3[DATA_WIDTH-1:0];

      rvdffsc #(.WIDTH(1)) stbuf_data_vldff (.din(1'b1), .dout(stbuf_data_vld[i]), .en(stbuf_wr_en[i]), .clear(stbuf_reset[i]), .clk(lsu_stbuf_c1_clk), .*);
      rvdffsc #(.WIDTH(1)) stbuf_drain_vldff (.din(1'b1), .dout(stbuf_drain_vld[i]), .en(stbuf_drain_en[i]), .clear(stbuf_reset[i]), .clk(lsu_free_c2_clk), .*);
      rvdffsc #(.WIDTH(1)) stbuf_flush_vldff (.din(1'b1), .dout(stbuf_flush_vld[i]), .en(stbuf_flush_en[i]), .clear(stbuf_reset[i]), .clk(lsu_free_c2_clk), .*);
      rvdffs #(.WIDTH(1)) stbuf_dma_picff (.din(lsu_pkt_dc3.dma), .dout(stbuf_dma[i]), .en(stbuf_wr_en[i]), .clk(lsu_stbuf_c1_clk), .*);
      rvdffs #(.WIDTH(1)) stbuf_addr_in_picff (.din(addr_in_pic_dc3), .dout(stbuf_addr_in_pic[i]), .en(stbuf_wr_en[i]), .clk(lsu_stbuf_c1_clk), .*);
      rvdffe #(.WIDTH(LSU_SB_BITS)) stbuf_addrff (.din(stbuf_addrin[i][LSU_SB_BITS-1:0]), .dout(stbuf_addr[i][LSU_SB_BITS-1:0]), .en(stbuf_wr_en[i]), .*);
      rvdffs #(.WIDTH(BYTE_WIDTH)) stbuf_byteenff (.din(stbuf_byteenin[i][BYTE_WIDTH-1:0]), .dout(stbuf_byteen[i][BYTE_WIDTH-1:0]), .en(stbuf_wr_en[i]), .clk(lsu_stbuf_c1_clk), .*);
      rvdffe #(.WIDTH(DATA_WIDTH)) stbuf_dataff (.din(stbuf_datain[i][DATA_WIDTH-1:0]), .dout(stbuf_data[i][DATA_WIDTH-1:0]), .en(stbuf_data_en[i]), .*);

   end

   // WrPtr flops to dc5
   assign WrPtr_dc3[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0];
   rvdff #(.WIDTH(DEPTH_LOG2)) WrPtr_dc4ff (.din(WrPtr_dc3[DEPTH_LOG2-1:0]), .dout(WrPtr_dc4[DEPTH_LOG2-1:0]), .clk(lsu_c1_dc4_clk), .*);
   rvdff #(.WIDTH(DEPTH_LOG2)) WrPtr_dc5ff (.din(WrPtr_dc4[DEPTH_LOG2-1:0]), .dout(WrPtr_dc5[DEPTH_LOG2-1:0]), .clk(lsu_c1_dc5_clk), .*);

   rvdff_fpga #(.WIDTH(1)) ldst_dual_dc2ff (.din(ldst_dual_dc1), .dout(ldst_dual_dc2), .clk(lsu_freeze_c1_dc2_clk), .clken(lsu_freeze_c1_dc2_clken), .rawclk(clk), .*);
   rvdff_fpga #(.WIDTH(1)) ldst_dual_dc3ff (.din(ldst_dual_dc2), .dout(ldst_dual_dc3), .clk(lsu_freeze_c1_dc3_clk), .clken(lsu_freeze_c1_dc3_clken), .rawclk(clk), .*);
   rvdff_fpga #(.WIDTH(BYTE_WIDTH)) stbuf_fwdbyteen_hi_dc3ff (.din(stbuf_fwdbyteen_hi_fn_dc2[BYTE_WIDTH-1:0]), .dout(stbuf_fwdbyteen_hi_dc3[BYTE_WIDTH-1:0]), .clk(lsu_freeze_c1_dc3_clk), .clken(lsu_freeze_c1_dc3_clken), .rawclk(clk), .*);
   rvdff_fpga #(.WIDTH(BYTE_WIDTH)) stbuf_fwdbyteen_lo_dc3ff (.din(stbuf_fwdbyteen_lo_fn_dc2[BYTE_WIDTH-1:0]), .dout(stbuf_fwdbyteen_lo_dc3[BYTE_WIDTH-1:0]), .clk(lsu_freeze_c1_dc3_clk), .clken(lsu_freeze_c1_dc3_clken), .rawclk(clk), .*);

   rvdff #(.WIDTH(1)) ldst_dual_dc4ff (.din(ldst_dual_dc3), .dout(ldst_dual_dc4), .clk(lsu_c1_dc4_clk), .*);
   rvdff #(.WIDTH(1)) ldst_dual_dc5ff (.din(ldst_dual_dc4), .dout(ldst_dual_dc5), .clk(lsu_c1_dc5_clk), .*);

   rvdff #(.WIDTH(1)) dual_stbuf_write_dc4ff (.din(dual_stbuf_write_dc3), .dout(dual_stbuf_write_dc4), .clk(lsu_c1_dc4_clk), .*);
   rvdff #(.WIDTH(1)) dual_stbuf_write_dc5ff (.din(dual_stbuf_write_dc4), .dout(dual_stbuf_write_dc5), .clk(lsu_c1_dc5_clk), .*);
   rvdff #(.WIDTH(1)) ldst_reqvld_dc4ff (.din(ldst_stbuf_reqvld_dc3), .dout(ldst_stbuf_reqvld_dc4), .clk(lsu_c2_dc4_clk), .*);
   rvdff #(.WIDTH(1)) ldst_reqvld_dc5ff (.din(ldst_stbuf_reqvld_dc4), .dout(ldst_stbuf_reqvld_dc5), .clk(lsu_c2_dc5_clk), .*);

   // Store Buffer drain logic
   assign stbuf_reqvld_flushed_any = stbuf_flush_vld[RdPtr];
   assign stbuf_reqvld_any = stbuf_drain_vld[RdPtr];
   assign stbuf_addr_in_pic_any = stbuf_addr_in_pic[RdPtr];
   assign stbuf_addr_any[LSU_SB_BITS-1:0] = stbuf_addr[RdPtr][LSU_SB_BITS-1:0];
   assign stbuf_byteen_any[BYTE_WIDTH-1:0] = stbuf_byteen[RdPtr][BYTE_WIDTH-1:0];    // Not needed as we always write all the bytes
   assign stbuf_data_any[DATA_WIDTH-1:0] = stbuf_data[RdPtr][DATA_WIDTH-1:0];

   // Update the RdPtr/WrPtr logic
   // Need to revert the WrPtr for flush cases. Also revert the pipe WrPtrs

   assign WrPtrEn = ldst_stbuf_reqvld_dc3;
   assign NxtWrPtr[DEPTH_LOG2-1:0] = (ldst_stbuf_reqvld_dc3 & dual_stbuf_write_dc3) ? WrPtrPlus2[DEPTH_LOG2-1:0] : WrPtrPlus1[DEPTH_LOG2-1:0];
   assign RdPtrEn = lsu_stbuf_commit_any | stbuf_reqvld_flushed_any;
   assign NxtRdPtr[DEPTH_LOG2-1:0] = RdPtrPlus1[DEPTH_LOG2-1:0];


   always_comb begin
      //stbuf_numvld_any[3:0] =  {3'b0,isldst_dc3} << ldst_dual_dc3;  // Use isldst_dc3 for timing reason
      stbuf_numvld_any[3:0] = '0;
      for (int i=0; i<DEPTH; i++) begin
         stbuf_numvld_any[3:0] += {3'b0, stbuf_data_vld[i]};
      end
   end

   assign stbuf_specvld_dc1[1:0] = {1'b0,isldst_dc1} << (isldst_dc1 & ldst_dual_dc1);    // Gate dual with isldst to avoid X propagation
   assign stbuf_specvld_dc2[1:0] = {1'b0,dccm_ldst_dc2} << (dccm_ldst_dc2 & ldst_dual_dc2);
   assign stbuf_specvld_dc3[1:0] = {1'b0,dccm_ldst_dc3} << (dccm_ldst_dc3 & ldst_dual_dc3);
   assign stbuf_specvld_any[3:0] = stbuf_numvld_any[3:0] +  {2'b0, stbuf_specvld_dc1[1:0]} + {2'b0, stbuf_specvld_dc2[1:0]} + {2'b0, stbuf_specvld_dc3[1:0]};

   assign lsu_stbuf_full_any = (stbuf_specvld_any[3:0] > (DEPTH - 2));
   assign lsu_stbuf_empty_any = (stbuf_numvld_any[3:0] == 4'b0);
   assign lsu_stbuf_nodma_empty_any = ~(|(stbuf_data_vld[DEPTH-1:0] & ~stbuf_dma[DEPTH-1:0]));
   assign lsu_load_ecc_stbuf_full_dc3 = load_stbuf_reqvld_dc3 & ~ldst_stbuf_reqvld_dc3;

   assign stbuf_oneavl_any = (stbuf_numvld_any[3:0] < DEPTH);
   assign stbuf_twoavl_any = (stbuf_numvld_any[3:0] < (DEPTH - 1));

   // Load forwarding logic
   assign cmpen_hi_dc2 = lsu_cmpen_dc2 & ldst_dual_dc2;
   assign cmpaddr_hi_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] = end_addr_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)];

   assign cmpen_lo_dc2 = lsu_cmpen_dc2;
   assign cmpaddr_lo_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] = lsu_addr_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)];
   assign jit_in_same_region = (addr_in_pic_dc2 & addr_in_pic_dc3) | (addr_in_dccm_dc2 & addr_in_dccm_dc3);

   // JIT forwarding
   assign stbuf_ldmatch_hi_hi = (end_addr_dc3[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] == cmpaddr_hi_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)]) & ~(cmpen_hi_dc2 & lsu_pkt_dc2.dma & ~lsu_pkt_dc3.dma) & jit_in_same_region;
   assign stbuf_ldmatch_hi_lo = (lsu_addr_dc3[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] == cmpaddr_hi_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)]) & ~(cmpen_hi_dc2 & lsu_pkt_dc2.dma & ~lsu_pkt_dc3.dma) & jit_in_same_region;
   assign stbuf_ldmatch_lo_hi = (end_addr_dc3[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] == cmpaddr_lo_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)]) & ~(cmpen_lo_dc2 & lsu_pkt_dc2.dma & ~lsu_pkt_dc3.dma) & jit_in_same_region;
   assign stbuf_ldmatch_lo_lo = (lsu_addr_dc3[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] == cmpaddr_lo_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)]) & ~(cmpen_lo_dc2 & lsu_pkt_dc2.dma & ~lsu_pkt_dc3.dma) & jit_in_same_region;

   for (genvar i=0; i<BYTE_WIDTH; i++) begin
      assign stbuf_fwdbyteen_hi_hi[i] = stbuf_ldmatch_hi_hi & store_byteen_hi_dc3[i] & ldst_stbuf_reqvld_dc3 & dual_stbuf_write_dc3;
      assign stbuf_fwdbyteen_hi_lo[i] = stbuf_ldmatch_hi_lo & store_byteen_lo_dc3[i] & ldst_stbuf_reqvld_dc3;
      assign stbuf_fwdbyteen_lo_hi[i] = stbuf_ldmatch_lo_hi & store_byteen_hi_dc3[i] & ldst_stbuf_reqvld_dc3 & dual_stbuf_write_dc3;
      assign stbuf_fwdbyteen_lo_lo[i] = stbuf_ldmatch_lo_lo & store_byteen_lo_dc3[i] & ldst_stbuf_reqvld_dc3;

      assign stbuf_fwddata_hi_hi[(8*i)+7:(8*i)] = {8{stbuf_fwdbyteen_hi_hi[i]}} & store_ecc_datafn_hi_dc3[(8*i)+7:(8*i)];
      assign stbuf_fwddata_hi_lo[(8*i)+7:(8*i)] = {8{stbuf_fwdbyteen_hi_lo[i]}} & store_ecc_datafn_lo_dc3[(8*i)+7:(8*i)];
      assign stbuf_fwddata_lo_hi[(8*i)+7:(8*i)] = {8{stbuf_fwdbyteen_lo_hi[i]}} & store_ecc_datafn_hi_dc3[(8*i)+7:(8*i)];
      assign stbuf_fwddata_lo_lo[(8*i)+7:(8*i)] = {8{stbuf_fwdbyteen_lo_lo[i]}} & store_ecc_datafn_lo_dc3[(8*i)+7:(8*i)];
   end


   always_comb begin: GenLdFwd
      stbuf_fwdbyteen_hi_dc2[BYTE_WIDTH-1:0]   = '0;
      stbuf_fwdbyteen_lo_dc2[BYTE_WIDTH-1:0]   = '0;
      for (int i=0; i<DEPTH; i++) begin
         stbuf_ldmatch_hi[i] = (stbuf_addr[i][LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] == cmpaddr_hi_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)]) &
                               (stbuf_drain_vld[i] | ~lsu_pkt_dc2.dma) & ~stbuf_flush_vld[i] & ((stbuf_addr_in_pic[i] & addr_in_pic_dc2) | (~stbuf_addr_in_pic[i] & addr_in_dccm_dc2));
         stbuf_ldmatch_lo[i] = (stbuf_addr[i][LSU_SB_BITS-1:$clog2(BYTE_WIDTH)] == cmpaddr_lo_dc2[LSU_SB_BITS-1:$clog2(BYTE_WIDTH)]) &
                               (stbuf_drain_vld[i] | ~lsu_pkt_dc2.dma) & ~stbuf_flush_vld[i] & ((stbuf_addr_in_pic[i] & addr_in_pic_dc2) | (~stbuf_addr_in_pic[i] & addr_in_dccm_dc2));

         for (int j=0; j<BYTE_WIDTH; j++) begin
            stbuf_fwdbyteenvec_hi[i][j] = stbuf_ldmatch_hi[i] & stbuf_byteen[i][j] & stbuf_data_vld[i];
            stbuf_fwdbyteen_hi_dc2[j] |= stbuf_fwdbyteenvec_hi[i][j];

            stbuf_fwdbyteenvec_lo[i][j] = stbuf_ldmatch_lo[i] & stbuf_byteen[i][j] & stbuf_data_vld[i];
            stbuf_fwdbyteen_lo_dc2[j] |= stbuf_fwdbyteenvec_lo[i][j];
         end
      end
   end // block: GenLdFwd

   for (genvar i=0; i<DEPTH; i++) begin
      for (genvar j=0; j<BYTE_WIDTH; j++) begin
         assign stbuf_fwddatavec_hi[i][(8*j)+7:(8*j)] = {8{stbuf_fwdbyteenvec_hi[i][j]}} & stbuf_data[i][(8*j)+7:(8*j)];
         assign stbuf_fwddatavec_lo[i][(8*j)+7:(8*j)] = {8{stbuf_fwdbyteenvec_lo[i][j]}} & stbuf_data[i][(8*j)+7:(8*j)];
      end
   end

   always_comb begin
      stbuf_fwddata_hi_dc2[DATA_WIDTH-1:0] = '0;
      stbuf_fwddata_lo_dc2[DATA_WIDTH-1:0] = '0;
      for (int i=0; i<DEPTH; i++) begin
         // Byte0
         if (stbuf_fwdbyteenvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][0]) begin
            stbuf_fwddata_hi_dc2[7:0] = stbuf_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][7:0];
         end
         if (stbuf_fwdbyteenvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][0]) begin
            stbuf_fwddata_lo_dc2[7:0] = stbuf_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][7:0];
         end

         // Byte1
         if (stbuf_fwdbyteenvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][1]) begin
            stbuf_fwddata_hi_dc2[15:8] = stbuf_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][15:8];
         end
         if (stbuf_fwdbyteenvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][1]) begin
            stbuf_fwddata_lo_dc2[15:8] = stbuf_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][15:8];
         end

         // Byte2
         if (stbuf_fwdbyteenvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][2]) begin
            stbuf_fwddata_hi_dc2[23:16] = stbuf_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][23:16];
         end
         if (stbuf_fwdbyteenvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][2]) begin
            stbuf_fwddata_lo_dc2[23:16] = stbuf_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][23:16];
         end

         // Byte3
         if (stbuf_fwdbyteenvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][3]) begin
            stbuf_fwddata_hi_dc2[31:24] = stbuf_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][31:24];
         end
         if (stbuf_fwdbyteenvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][3]) begin
            stbuf_fwddata_lo_dc2[31:24] = stbuf_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][31:24];
         end
      end
   end

   for (genvar i=0; i<BYTE_WIDTH; i++) begin
      assign stbuf_fwdbyteen_hi_fn_dc2[i] = stbuf_fwdbyteen_hi_hi[i] | stbuf_fwdbyteen_hi_lo[i] | stbuf_fwdbyteen_hi_dc2[i];
      assign stbuf_fwdbyteen_lo_fn_dc2[i] = stbuf_fwdbyteen_lo_hi[i] | stbuf_fwdbyteen_lo_lo[i] | stbuf_fwdbyteen_lo_dc2[i];

      assign stbuf_fwddata_hi_fn_dc2[(8*i)+7:(8*i)] = (stbuf_fwdbyteen_hi_hi[i] | stbuf_fwdbyteen_hi_lo[i]) ?
                                                                         (stbuf_fwddata_hi_hi[(8*i)+7:(8*i)] | stbuf_fwddata_hi_lo[(8*i)+7:(8*i)]) :
                                                                         stbuf_fwddata_hi_dc2[(8*i)+7:(8*i)];
      assign stbuf_fwddata_lo_fn_dc2[(8*i)+7:(8*i)] = (stbuf_fwdbyteen_lo_hi[i] | stbuf_fwdbyteen_lo_lo[i]) ?
                                                                         (stbuf_fwddata_lo_hi[(8*i)+7:(8*i)] | stbuf_fwddata_lo_lo[(8*i)+7:(8*i)]) :
                                                                         stbuf_fwddata_lo_dc2[(8*i)+7:(8*i)];
   end

   // Flops
   rvdffs #(.WIDTH(DEPTH_LOG2)) WrPtrff (.din(NxtWrPtr[DEPTH_LOG2-1:0]), .dout(WrPtr[DEPTH_LOG2-1:0]), .en(WrPtrEn), .clk(lsu_stbuf_c1_clk), .*);
   rvdffs #(.WIDTH(DEPTH_LOG2)) RdPtrff (.din(NxtRdPtr[DEPTH_LOG2-1:0]), .dout(RdPtr[DEPTH_LOG2-1:0]), .en(RdPtrEn), .clk(lsu_stbuf_c1_clk), .*);


   rvdffe #(.WIDTH(DATA_WIDTH)) stbuf_fwddata_hi_dc3ff (.din(stbuf_fwddata_hi_fn_dc2[DATA_WIDTH-1:0]), .dout(stbuf_fwddata_hi_dc3[DATA_WIDTH-1:0]), .en(lsu_freeze_c1_dc3_clken), .*);
   rvdffe #(.WIDTH(DATA_WIDTH)) stbuf_fwddata_lo_dc3ff (.din(stbuf_fwddata_lo_fn_dc2[DATA_WIDTH-1:0]), .dout(stbuf_fwddata_lo_dc3[DATA_WIDTH-1:0]), .en(lsu_freeze_c1_dc3_clken), .*);

`ifdef ASSERT_ON

   assert_drainorflushvld_notvld: assert #0 (~(|((stbuf_drain_vld[DEPTH-1:0] | stbuf_flush_vld[DEPTH-1:0]) & ~stbuf_data_vld[DEPTH-1:0])));
   assert_drainAndflushvld:       assert #0 (~(|(stbuf_drain_vld[DEPTH-1:0] & stbuf_flush_vld[DEPTH-1:0])));
   assert_stbufempty:             assert #0 (~lsu_stbuf_empty_any | lsu_stbuf_nodma_empty_any);

   property ldecc_stbuffull_commit;
      @(posedge clk)  disable iff(~rst_l) (load_stbuf_reqvld_dc3 & lsu_load_ecc_stbuf_full_dc3) |-> ##2 (lsu_commit_dc5 == 1'b0);
   endproperty
   assert_ldecc_stbuffull_commit: assert property (ldecc_stbuffull_commit) else
      $display("load with ecc error committed with store buffer full");
`endif

endmodule

