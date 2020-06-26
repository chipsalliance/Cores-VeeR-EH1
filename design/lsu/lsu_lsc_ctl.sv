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
// Function: LSU control
// Comments:
//
//
// DC1 -> DC2 -> DC3 -> DC4 (Commit)
//
//********************************************************************************
module lsu_lsc_ctl
   import swerv_types::*;
(
   input logic         rst_l,
   input logic         clk,

   // clocks per pipe
   input logic        lsu_c1_dc4_clk,
   input logic        lsu_c1_dc5_clk,
   input logic        lsu_c2_dc4_clk,
   input logic        lsu_c2_dc5_clk,
   // freez clocks per pipe
   input logic        lsu_freeze_c1_dc1_clken,
   input logic        lsu_freeze_c1_dc2_clken,
   input logic        lsu_freeze_c1_dc2_clk,
   input logic        lsu_freeze_c1_dc3_clken,
   input logic        lsu_freeze_c1_dc3_clk,
   input logic        lsu_freeze_c2_dc1_clk,
   input logic        lsu_freeze_c2_dc2_clk,
   input logic        lsu_freeze_c2_dc3_clk,
   input logic        lsu_freeze_c2_dc1_clken,
   input logic        lsu_freeze_c2_dc2_clken,
   input logic        lsu_freeze_c2_dc3_clken,

   input logic        lsu_store_c1_dc1_clken,
   input logic        lsu_store_c1_dc2_clken,
   input logic        lsu_store_c1_dc3_clken,
   input logic        lsu_store_c1_dc4_clk,
   input logic        lsu_store_c1_dc5_clk,

   input logic [31:0] i0_result_e4_eff,
   input logic [31:0] i1_result_e4_eff,

   input logic [31:0] i0_result_e2,

   input logic         ld_bus_error_dc3,
   input logic [31:0]  ld_bus_error_addr_dc3,
   input logic         lsu_single_ecc_error_dc3,
   input logic         lsu_single_ecc_error_dc5,
   input logic         lsu_double_ecc_error_dc3,
   input logic         lsu_freeze_dc3,

   input logic         lsu_i0_valid_dc3,
   input logic         flush_dc2_up,
   input logic         flush_dc3,
   input logic         flush_dc4,
   input logic         flush_dc5,

   input logic [31:0]  exu_lsu_rs1_d, // address
   input logic [31:0]  exu_lsu_rs2_d, // store data

   input lsu_pkt_t     lsu_p,         // lsu control packet
   input logic [11:0]  dec_lsu_offset_d,

   input  logic [31:0] picm_mask_data_dc3,
   input  logic [31:0] lsu_ld_data_dc3,
   input  logic [31:0] lsu_ld_data_corr_dc3,
   input  logic [31:0]  bus_read_data_dc3,
   output logic [31:0] lsu_result_dc3,
   output logic [31:0] lsu_result_corr_dc4,   // This is the ECC corrected data going to RF
   // lsu address down the pipe
   output logic [31:0] lsu_addr_dc1,
   output logic [31:0] lsu_addr_dc2,
   output logic [31:0] lsu_addr_dc3,
   output logic [31:0] lsu_addr_dc4,
   output logic [31:0] lsu_addr_dc5,
   // lsu address down the pipe - needed to check unaligned
   output logic [31:0] end_addr_dc1,
   output logic [31:0] end_addr_dc2,
   output logic [31:0] end_addr_dc3,
   output logic [31:0] end_addr_dc4,
   output logic [31:0] end_addr_dc5,
   // store data down the pipe
   output logic [63:0] store_data_dc2,
   output logic [63:0] store_data_dc3,
   output logic [31:0] store_data_dc4,
   output logic [31:0] store_data_dc5,

   input  logic [31:0]    dec_tlu_mrac_ff,
   output logic           lsu_exc_dc2,
   output lsu_error_pkt_t lsu_error_pkt_dc3,
   output logic           lsu_single_ecc_error_incr,    // Increment the counter for Single ECC error
   output logic           lsu_freeze_external_ints_dc3,
   output logic           is_sideeffects_dc2,
   output logic           is_sideeffects_dc3,
   output logic           lsu_commit_dc5,
   // address in dccm/pic/external per pipe stage
   output logic        addr_in_dccm_dc1,
   output logic        addr_in_dccm_dc2,
   output logic        addr_in_dccm_dc3,
   output logic        addr_in_pic_dc1,
   output logic        addr_in_pic_dc2,
   output logic        addr_in_pic_dc3,
   output logic        addr_external_dc2,
   output logic        addr_external_dc3,
   output logic        addr_external_dc4,
   output logic        addr_external_dc5,

   // DMA slave
   input logic        dma_dccm_req,
   input logic [31:0] dma_mem_addr,
   input logic [2:0]  dma_mem_sz,
   input logic        dma_mem_write,
   input logic [63:0] dma_mem_wdata,

   // Store buffer related signals
   output lsu_pkt_t    lsu_pkt_dc1,
   output lsu_pkt_t    lsu_pkt_dc2,
   output lsu_pkt_t    lsu_pkt_dc3,
   output lsu_pkt_t    lsu_pkt_dc4,
   output lsu_pkt_t    lsu_pkt_dc5,

   input  logic        scan_mode

   );

`include "global.h"

   logic [31:0]        full_addr_dc1;
   logic [31:0]        full_end_addr_dc1;
   logic [31:0]        lsu_rs1_d;
   logic [11:0]        lsu_offset_d;
   logic [31:0]        rs1_dc1;
   logic [11:0]        offset_dc1;
   logic [12:0]        end_addr_offset_dc1;
   logic [31:0]        lsu_ld_datafn_dc3;
   logic [31:0]        lsu_ld_datafn_corr_dc3;
   logic [31:0]        lsu_result_corr_dc3;
   logic [2:0]         addr_offset_dc1;

   logic [63:0]        dma_mem_wdata_shifted;
   logic               addr_external_dc1;
   logic               access_fault_dc1, misaligned_fault_dc1;
   logic               access_fault_dc2, misaligned_fault_dc2;
   logic               access_fault_dc3, misaligned_fault_dc3;

   logic [63:0]        store_data_d;
   logic [63:0]        store_data_dc1;
   logic [63:0]        store_data_pre_dc2;
   logic [63:0]        store_data_pre_dc3;
   logic [63:0]        store_data_dc2_in;

   logic [31:0]        rs1_dc1_raw;

   lsu_pkt_t           dma_pkt_d;
   lsu_pkt_t           lsu_pkt_dc1_in, lsu_pkt_dc2_in, lsu_pkt_dc3_in, lsu_pkt_dc4_in, lsu_pkt_dc5_in;

   // Premux the rs1/offset for dma
   assign lsu_rs1_d[31:0] = dma_dccm_req ? dma_mem_addr[31:0] : exu_lsu_rs1_d[31:0];
   assign lsu_offset_d[11:0] = dec_lsu_offset_d[11:0] & ~{12{dma_dccm_req}};

   rvdffe #(32) rs1ff (.*, .din(lsu_rs1_d[31:0]), .dout(rs1_dc1_raw[31:0]), .en(lsu_freeze_c1_dc1_clken));
   rvdffe #(12) offsetff (.*, .din(lsu_offset_d[11:0]), .dout(offset_dc1[11:0]), .en(lsu_freeze_c1_dc1_clken));

   assign rs1_dc1[31:0] = (lsu_pkt_dc1.load_ldst_bypass_c1) ? lsu_result_dc3[31:0] : rs1_dc1_raw[31:0];


   // generate the ls address
   // need to refine this is memory is only 128KB
   rvlsadder   lsadder  (.rs1(rs1_dc1[31:0]),
                       .offset(offset_dc1[11:0]),
                       .dout(full_addr_dc1[31:0])
                       );

   // Module to generate the memory map of the address
   lsu_addrcheck addrcheck (
              .start_addr_dc1(full_addr_dc1[31:0]),
              .end_addr_dc1(full_end_addr_dc1[31:0]),
              .*
  );

   // Calculate start/end address for load/store
   assign addr_offset_dc1[2:0]      = ({3{lsu_pkt_dc1.half}} & 3'b01) | ({3{lsu_pkt_dc1.word}} & 3'b11) | ({3{lsu_pkt_dc1.dword}} & 3'b111);
   assign end_addr_offset_dc1[12:0] = {offset_dc1[11],offset_dc1[11:0]} + {9'b0,addr_offset_dc1[2:0]};
   assign full_end_addr_dc1[31:0]   = rs1_dc1[31:0] + {{19{end_addr_offset_dc1[12]}},end_addr_offset_dc1[12:0]};
   assign end_addr_dc1[31:0]        = full_end_addr_dc1[31:0];
   assign lsu_exc_dc2               = access_fault_dc2 | misaligned_fault_dc2;
   assign lsu_freeze_external_ints_dc3 = lsu_freeze_dc3 & is_sideeffects_dc3;

   // Increment the single bit ecc counter
   assign lsu_single_ecc_error_incr = lsu_single_ecc_error_dc5 & (lsu_commit_dc5 | lsu_pkt_dc5.dma);

   // Generate exception packet
   assign lsu_error_pkt_dc3.exc_valid = (access_fault_dc3 | misaligned_fault_dc3 | ld_bus_error_dc3 | lsu_double_ecc_error_dc3) & lsu_pkt_dc3.valid & ~lsu_pkt_dc3.dma & ~flush_dc3;
   assign lsu_error_pkt_dc3.single_ecc_error = lsu_single_ecc_error_dc3 & ~(access_fault_dc3 | misaligned_fault_dc3 | lsu_double_ecc_error_dc3);
   assign lsu_error_pkt_dc3.inst_type = lsu_pkt_dc3.store;
   assign lsu_error_pkt_dc3.dma_valid = lsu_pkt_dc3.dma;
   assign lsu_error_pkt_dc3.inst_pipe = ~lsu_i0_valid_dc3;
   assign lsu_error_pkt_dc3.exc_type  = ~misaligned_fault_dc3;
   // assign lsu_error_pkt_dc3.addr[31:0] = (access_fault_dc3 | misaligned_fault_dc3) ? lsu_addr_dc3[31:0] : ld_bus_error_addr_dc3[31:0];
   assign lsu_error_pkt_dc3.addr[31:0] = lsu_addr_dc3[31:0];


   //Create DMA packet
   assign dma_pkt_d.valid   = dma_dccm_req;
   assign dma_pkt_d.dma     = 1'b1;
   assign dma_pkt_d.unsign  = '0;
   assign dma_pkt_d.store   = dma_mem_write;
   assign dma_pkt_d.load    = ~dma_mem_write;
   assign dma_pkt_d.by      = (dma_mem_sz[2:0] == 3'b0);
   assign dma_pkt_d.half    = (dma_mem_sz[2:0] == 3'b1);
   assign dma_pkt_d.word    = (dma_mem_sz[2:0] == 3'b10);
   assign dma_pkt_d.dword   = (dma_mem_sz[2:0] == 3'b11);
   assign dma_pkt_d.load_ldst_bypass_c1  = '0;
   assign dma_pkt_d.store_data_bypass_c1 = '0;
   assign dma_pkt_d.store_data_bypass_c2 = '0;
   assign dma_pkt_d.store_data_bypass_i0_e2_c2 = '0;
   assign dma_pkt_d.store_data_bypass_e4_c1 = '0;
   assign dma_pkt_d.store_data_bypass_e4_c2 = '0;
   assign dma_pkt_d.store_data_bypass_e4_c3 = '0;

   always_comb begin
      lsu_pkt_dc1_in = dma_dccm_req ? dma_pkt_d : lsu_p;
      lsu_pkt_dc2_in = lsu_pkt_dc1;
      lsu_pkt_dc3_in = lsu_pkt_dc2;
      lsu_pkt_dc4_in = lsu_pkt_dc3;
      lsu_pkt_dc5_in = lsu_pkt_dc4;

      lsu_pkt_dc1_in.valid = (lsu_p.valid & ~flush_dc2_up) | dma_dccm_req;
      lsu_pkt_dc2_in.valid = lsu_pkt_dc1.valid & ~(flush_dc2_up & ~lsu_pkt_dc1.dma);
      lsu_pkt_dc3_in.valid = lsu_pkt_dc2.valid & ~(flush_dc2_up & ~lsu_pkt_dc2.dma);
      lsu_pkt_dc4_in.valid = lsu_pkt_dc3.valid & ~(flush_dc3 & ~lsu_pkt_dc3.dma) & ~lsu_freeze_dc3;
      lsu_pkt_dc5_in.valid = lsu_pkt_dc4.valid & ~(flush_dc4 & ~lsu_pkt_dc4.dma);
   end

   // C2 clock for valid and C1 for other bits of packet
   rvdff #(1) lsu_pkt_vlddc4ff (.*, .din(lsu_pkt_dc4_in.valid), .dout(lsu_pkt_dc4.valid), .clk(lsu_c2_dc4_clk));
   rvdff #(1) lsu_pkt_vlddc5ff (.*, .din(lsu_pkt_dc5_in.valid), .dout(lsu_pkt_dc5.valid), .clk(lsu_c2_dc5_clk));

   rvdffe #($bits(lsu_pkt_t)-1) lsu_pkt_dc1ff (.*, .din(lsu_pkt_dc1_in[$bits(lsu_pkt_t)-1:1]), .dout(lsu_pkt_dc1[$bits(lsu_pkt_t)-1:1]), .en(lsu_freeze_c1_dc1_clken));
   rvdffe #($bits(lsu_pkt_t)-1) lsu_pkt_dc2ff (.*, .din(lsu_pkt_dc2_in[$bits(lsu_pkt_t)-1:1]), .dout(lsu_pkt_dc2[$bits(lsu_pkt_t)-1:1]), .en(lsu_freeze_c1_dc2_clken));
   rvdffe #($bits(lsu_pkt_t)-1) lsu_pkt_dc3ff (.*, .din(lsu_pkt_dc3_in[$bits(lsu_pkt_t)-1:1]), .dout(lsu_pkt_dc3[$bits(lsu_pkt_t)-1:1]), .en(lsu_freeze_c1_dc3_clken));
   rvdff #($bits(lsu_pkt_t)-1) lsu_pkt_dc4ff (.*, .din(lsu_pkt_dc4_in[$bits(lsu_pkt_t)-1:1]), .dout(lsu_pkt_dc4[$bits(lsu_pkt_t)-1:1]), .clk(lsu_c1_dc4_clk));
   rvdff #($bits(lsu_pkt_t)-1) lsu_pkt_dc5ff (.*, .din(lsu_pkt_dc5_in[$bits(lsu_pkt_t)-1:1]), .dout(lsu_pkt_dc5[$bits(lsu_pkt_t)-1:1]), .clk(lsu_c1_dc5_clk));

   assign lsu_ld_datafn_dc3[31:0] = addr_external_dc3 ? bus_read_data_dc3[31:0] : lsu_ld_data_dc3[31:0];
   assign lsu_ld_datafn_corr_dc3[31:0] = addr_external_dc3 ? bus_read_data_dc3[31:0] : lsu_ld_data_corr_dc3[31:0];

   // this result must look at prior stores and merge them in
   assign lsu_result_dc3[31:0] = ({32{ lsu_pkt_dc3.unsign & lsu_pkt_dc3.by  }} & {24'b0,lsu_ld_datafn_dc3[7:0]}) |
                                 ({32{ lsu_pkt_dc3.unsign & lsu_pkt_dc3.half}} & {16'b0,lsu_ld_datafn_dc3[15:0]}) |
                                 ({32{~lsu_pkt_dc3.unsign & lsu_pkt_dc3.by  }} & {{24{  lsu_ld_datafn_dc3[7]}}, lsu_ld_datafn_dc3[7:0]}) |
                                 ({32{~lsu_pkt_dc3.unsign & lsu_pkt_dc3.half}} & {{16{  lsu_ld_datafn_dc3[15]}},lsu_ld_datafn_dc3[15:0]}) |
                                 ({32{lsu_pkt_dc3.word}} &                       lsu_ld_datafn_dc3[31:0]);

   assign lsu_result_corr_dc3[31:0] = ({32{ lsu_pkt_dc3.unsign & lsu_pkt_dc3.by  }} & {24'b0,lsu_ld_datafn_corr_dc3[7:0]}) |
                                      ({32{ lsu_pkt_dc3.unsign & lsu_pkt_dc3.half}} & {16'b0,lsu_ld_datafn_corr_dc3[15:0]}) |
                                      ({32{~lsu_pkt_dc3.unsign & lsu_pkt_dc3.by  }} & {{24{  lsu_ld_datafn_corr_dc3[7]}}, lsu_ld_datafn_corr_dc3[7:0]}) |
                                      ({32{~lsu_pkt_dc3.unsign & lsu_pkt_dc3.half}} & {{16{  lsu_ld_datafn_corr_dc3[15]}},lsu_ld_datafn_corr_dc3[15:0]}) |
                                      ({32{lsu_pkt_dc3.word}} &                       lsu_ld_datafn_corr_dc3[31:0]);


   // absence load/store all 0's
   assign lsu_addr_dc1[31:0] = full_addr_dc1[31:0];

   // Interrupt as a flush source allows the WB to occur
   assign lsu_commit_dc5 = lsu_pkt_dc5.valid & (lsu_pkt_dc5.store | lsu_pkt_dc5.load) & ~flush_dc5 & ~lsu_pkt_dc5.dma;

   assign dma_mem_wdata_shifted[63:0] = dma_mem_wdata[63:0] >> {dma_mem_addr[2:0], 3'b000};   // Shift the dma data to lower bits to make it consistent to lsu stores
   assign store_data_d[63:0] = dma_dccm_req ? dma_mem_wdata_shifted[63:0] : {32'b0,exu_lsu_rs2_d[31:0]};

   assign store_data_dc2_in[63:32] = store_data_dc1[63:32];
   assign store_data_dc2_in[31:0] = (lsu_pkt_dc1.store_data_bypass_c1) ? lsu_result_dc3[31:0] :
                                    (lsu_pkt_dc1.store_data_bypass_e4_c1[1]) ? i1_result_e4_eff[31:0] :
                                    (lsu_pkt_dc1.store_data_bypass_e4_c1[0]) ? i0_result_e4_eff[31:0] : store_data_dc1[31:0];

   assign store_data_dc2[63:32] = store_data_pre_dc2[63:32];
   assign store_data_dc2[31:0] = (lsu_pkt_dc2.store_data_bypass_i0_e2_c2) ? i0_result_e2[31:0]     :
                                 (lsu_pkt_dc2.store_data_bypass_c2)       ? lsu_result_dc3[31:0]   :
                                 (lsu_pkt_dc2.store_data_bypass_e4_c2[1]) ? i1_result_e4_eff[31:0] :
                                 (lsu_pkt_dc2.store_data_bypass_e4_c2[0]) ? i0_result_e4_eff[31:0] : store_data_pre_dc2[31:0];

   assign store_data_dc3[63:32] = store_data_pre_dc3[63:32];
   assign store_data_dc3[31:0] = (picm_mask_data_dc3[31:0] | {32{~addr_in_pic_dc3}}) &
                                 ((lsu_pkt_dc3.store_data_bypass_e4_c3[1]) ? i1_result_e4_eff[31:0] :
                                  (lsu_pkt_dc3.store_data_bypass_e4_c3[0]) ? i0_result_e4_eff[31:0] : store_data_pre_dc3[31:0]);

   rvdff #(32) lsu_result_corr_dc4ff (.*, .din(lsu_result_corr_dc3[31:0]), .dout(lsu_result_corr_dc4[31:0]), .clk(lsu_c1_dc4_clk));

   rvdffe #(64) sddc1ff (.*, .din(store_data_d[63:0]),  .dout(store_data_dc1[63:0]), .en(lsu_store_c1_dc1_clken));
   rvdffe #(64) sddc2ff (.*, .din(store_data_dc2_in[63:0]), .dout(store_data_pre_dc2[63:0]), .en(lsu_store_c1_dc2_clken));
   rvdffe #(64) sddc3ff (.*, .din(store_data_dc2[63:0]), .dout(store_data_pre_dc3[63:0]), .en(~lsu_freeze_dc3 & lsu_store_c1_dc3_clken) );

   rvdff #(32) sddc4ff (.*, .din(store_data_dc3[31:0]), .dout(store_data_dc4[31:0]), .clk(lsu_store_c1_dc4_clk));
   rvdff #(32) sddc5ff (.*, .din(store_data_dc4[31:0]), .dout(store_data_dc5[31:0]), .clk(lsu_store_c1_dc5_clk));

   rvdffe #(32) sadc2ff (.*, .din(lsu_addr_dc1[31:0]), .dout(lsu_addr_dc2[31:0]), .en(lsu_freeze_c1_dc2_clken));
   rvdffe #(32) sadc3ff (.*, .din(lsu_addr_dc2[31:0]), .dout(lsu_addr_dc3[31:0]), .en(lsu_freeze_c1_dc3_clken));
   rvdff #(32) sadc4ff (.*, .din(lsu_addr_dc3[31:0]), .dout(lsu_addr_dc4[31:0]), .clk(lsu_c1_dc4_clk));
   rvdff #(32) sadc5ff (.*, .din(lsu_addr_dc4[31:0]), .dout(lsu_addr_dc5[31:0]), .clk(lsu_c1_dc5_clk));

   rvdffe #(32) end_addr_dc2ff (.*, .din(end_addr_dc1[31:0]), .dout(end_addr_dc2[31:0]), .en(lsu_freeze_c1_dc2_clken));
   rvdffe #(32) end_addr_dc3ff (.*, .din(end_addr_dc2[31:0]), .dout(end_addr_dc3[31:0]), .en(lsu_freeze_c1_dc3_clken));
   rvdff #(32) end_addr_dc4ff (.*, .din(end_addr_dc3[31:0]), .dout(end_addr_dc4[31:0]), .clk(lsu_c1_dc4_clk));
   rvdff #(32) end_addr_dc5ff (.*, .din(end_addr_dc4[31:0]), .dout(end_addr_dc5[31:0]), .clk(lsu_c1_dc5_clk));

   rvdff_fpga #(1) addr_in_dccm_dc2ff     (.din(addr_in_dccm_dc1),     .dout(addr_in_dccm_dc2),     .clk(lsu_freeze_c1_dc2_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc2_clken), .*);
   rvdff_fpga #(1) addr_in_dccm_dc3ff     (.din(addr_in_dccm_dc2),     .dout(addr_in_dccm_dc3),     .clk(lsu_freeze_c1_dc3_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc3_clken), .*);
   rvdff_fpga #(1) addr_in_pic_dc2ff      (.din(addr_in_pic_dc1),      .dout(addr_in_pic_dc2),      .clk(lsu_freeze_c1_dc2_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc2_clken), .*);
   rvdff_fpga #(1) addr_in_pic_dc3ff      (.din(addr_in_pic_dc2),      .dout(addr_in_pic_dc3),      .clk(lsu_freeze_c1_dc3_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc3_clken), .*);
   rvdff_fpga #(1) access_fault_dc2ff     (.din(access_fault_dc1),     .dout(access_fault_dc2),     .clk(lsu_freeze_c1_dc2_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc2_clken), .*);
   rvdff_fpga #(1) access_fault_dc3ff     (.din(access_fault_dc2),     .dout(access_fault_dc3),     .clk(lsu_freeze_c1_dc3_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc3_clken), .*);
   rvdff_fpga #(1) addr_external_dc2ff    (.din(addr_external_dc1),    .dout(addr_external_dc2),    .clk(lsu_freeze_c1_dc2_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc2_clken), .*);
   rvdff_fpga #(1) addr_external_dc3ff    (.din(addr_external_dc2),    .dout(addr_external_dc3),    .clk(lsu_freeze_c1_dc3_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc3_clken), .*);
   rvdff_fpga #(1) misaligned_fault_dc2ff (.din(misaligned_fault_dc1), .dout(misaligned_fault_dc2), .clk(lsu_freeze_c1_dc2_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc2_clken), .*);
   rvdff_fpga #(1) misaligned_fault_dc3ff (.din(misaligned_fault_dc2), .dout(misaligned_fault_dc3), .clk(lsu_freeze_c1_dc3_clk), .rawclk(clk), .clken(lsu_freeze_c1_dc3_clken), .*);
   rvdff_fpga #(1) lsu_pkt_vlddc1ff       (.din(lsu_pkt_dc1_in.valid), .dout(lsu_pkt_dc1.valid),    .clk(lsu_freeze_c2_dc1_clk), .rawclk(clk), .clken(lsu_freeze_c2_dc1_clken), .*);
   rvdff_fpga #(1) lsu_pkt_vlddc2ff       (.din(lsu_pkt_dc2_in.valid), .dout(lsu_pkt_dc2.valid),    .clk(lsu_freeze_c2_dc2_clk), .rawclk(clk), .clken(lsu_freeze_c2_dc2_clken), .*);
   rvdff_fpga #(1) lsu_pkt_vlddc3ff       (.din(lsu_pkt_dc3_in.valid), .dout(lsu_pkt_dc3.valid),    .clk(lsu_freeze_c2_dc3_clk), .rawclk(clk), .clken(lsu_freeze_c2_dc3_clken), .*);

   rvdff #(1) addr_external_dc4ff(.din(addr_external_dc3), .dout(addr_external_dc4), .clk(lsu_c1_dc4_clk), .*);
   rvdff #(1) addr_external_dc5ff(.din(addr_external_dc4), .dout(addr_external_dc5), .clk(lsu_c1_dc5_clk), .*);


endmodule
