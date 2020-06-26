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
// Function: DCCM for LSU pipe
// Comments: Single ported memory
//
//
// DC1 -> DC2 -> DC3 -> DC4 (Commit)
//
// //********************************************************************************

module lsu_dccm_ctl
   import swerv_types::*;
(
   input logic                             lsu_freeze_c2_dc2_clk,     // clocks
   input logic                             lsu_freeze_c2_dc3_clk,
   input logic                             lsu_freeze_c2_dc2_clken,     // clocks
   input logic                             lsu_freeze_c2_dc3_clken,
   input logic                             lsu_dccm_c1_dc3_clk,
   input logic                             lsu_dccm_c1_dc3_clken,
   input logic                             lsu_pic_c1_dc3_clken,

   input logic                             rst_l,
   input logic                             clk,
   input logic                             lsu_freeze_dc3,            // freze

   input                                   lsu_pkt_t lsu_pkt_dc3,     // lsu packets
   input                                   lsu_pkt_t lsu_pkt_dc1,
   input logic                             addr_in_dccm_dc1,          // address maps to dccm
   input logic                             addr_in_pic_dc1,           // address maps to pic
   input logic                             addr_in_pic_dc3,           // address maps to pic
   input logic [31:0]                      lsu_addr_dc1,              // starting byte address for loads
   input logic [`RV_DCCM_BITS-1:0]         end_addr_dc1,              // last address used to calculate unaligned
   input logic [`RV_DCCM_BITS-1:0]         lsu_addr_dc3,              // starting byte address for loads

   input logic                             stbuf_reqvld_any,          // write enable
   input logic                             stbuf_addr_in_pic_any,     // stbuf is going to pic
   input logic [`RV_LSU_SB_BITS-1:0]       stbuf_addr_any,            // stbuf address (aligned)

   input logic [`RV_DCCM_DATA_WIDTH-1:0]   stbuf_data_any,            // the read out from stbuf
   input logic [`RV_DCCM_ECC_WIDTH-1:0]    stbuf_ecc_any,             // the encoded data with ECC bits
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   stbuf_fwddata_hi_dc3,      // stbuf fowarding to load
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   stbuf_fwddata_lo_dc3,      // stbuf fowarding to load
   input logic [`RV_DCCM_BYTE_WIDTH-1:0]   stbuf_fwdbyteen_hi_dc3,    // stbuf fowarding to load
   input logic [`RV_DCCM_BYTE_WIDTH-1:0]   stbuf_fwdbyteen_lo_dc3,    // stbuf fowarding to load

   input logic                             lsu_double_ecc_error_dc3,  // lsu has a DED
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   store_ecc_datafn_hi_dc3,   // store data
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   store_ecc_datafn_lo_dc3,   // store data

   output logic [`RV_DCCM_DATA_WIDTH-1:0]  dccm_data_hi_dc3,          // data from the dccm
   output logic [`RV_DCCM_DATA_WIDTH-1:0]  dccm_data_lo_dc3,          // data from the dccm
   output logic [`RV_DCCM_ECC_WIDTH-1:0]   dccm_data_ecc_hi_dc3,      // data from the dccm + ecc
   output logic [`RV_DCCM_ECC_WIDTH-1:0]   dccm_data_ecc_lo_dc3,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]  lsu_ld_data_dc3,           // right justified, ie load byte will have data at 7:0
   output logic [`RV_DCCM_DATA_WIDTH-1:0]  lsu_ld_data_corr_dc3,      // right justified, ie load byte will have data at 7:0
   output logic [31:0]                     picm_mask_data_dc3,        // pic data to stbuf
   output logic                            lsu_stbuf_commit_any,      // stbuf wins the dccm port or is to pic
   output logic                            lsu_dccm_rden_dc3,         // dccm read

   output logic                            dccm_dma_rvalid,           // dccm serviving the dma load
   output logic                            dccm_dma_ecc_error,        // DMA load had ecc error
   output logic [63:0]                     dccm_dma_rdata,            // dccm data to dma request

   // DCCM ports
   output logic                            dccm_wren,                // dccm interface -- write
   output logic                            dccm_rden,                // dccm interface -- write
   output logic [`RV_DCCM_BITS-1:0]        dccm_wr_addr,             // dccm interface -- wr addr
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_lo,          // dccm interface -- read address for lo bank
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_hi,          // dccm interface -- read address for hi bank
   output logic [`RV_DCCM_FDATA_WIDTH-1:0] dccm_wr_data,             // dccm write data

   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo,          // dccm read data back from the dccm
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi,          // dccm read data back from the dccm

   // PIC ports
   output logic                            picm_wren,          // write to pic
   output logic                            picm_rden,          // read to pick
   output logic                            picm_mken,          // write to pic need a mask
   output logic [31:0]                     picm_addr,          // address for pic access - shared between reads and write
   output logic [31:0]                     picm_wr_data,       // write data
   input logic [31:0]                      picm_rd_data,       // read data

   input logic                             scan_mode           // scan mode
);

`include "global.h"

   `ifdef RV_DCCM_ENABLE
      localparam DCCM_ENABLE = 1'b1;
   `else
      localparam DCCM_ENABLE = 1'b0;
   `endif

   localparam DCCM_WIDTH_BITS = $clog2(DCCM_BYTE_WIDTH);
   localparam PIC_BITS        =`RV_PIC_BITS;

   logic                        lsu_dccm_rden_dc1, lsu_dccm_rden_dc2;
   logic [DCCM_DATA_WIDTH-1:0]  dccm_data_hi_dc2, dccm_data_lo_dc2;
   logic [DCCM_ECC_WIDTH-1:0]   dccm_data_ecc_hi_dc2, dccm_data_ecc_lo_dc2;
   logic [63:0]  dccm_dout_dc3, dccm_corr_dout_dc3;
   logic [63:0]  stbuf_fwddata_dc3;
   logic [7:0]   stbuf_fwdbyteen_dc3;
   logic [63:0]  lsu_rdata_dc3, lsu_rdata_corr_dc3;
   logic [63:0]  picm_rd_data_dc3;
   logic [31:0]  picm_rd_data_lo_dc3;
   logic [63:32] lsu_ld_data_dc3_nc, lsu_ld_data_corr_dc3_nc;

   assign dccm_dma_rvalid      = lsu_pkt_dc3.valid & lsu_pkt_dc3.load & lsu_pkt_dc3.dma;
   assign dccm_dma_ecc_error   = lsu_double_ecc_error_dc3;
   assign dccm_dma_rdata[63:0] = lsu_pkt_dc3.dword ? lsu_rdata_corr_dc3[63:0] : {2{lsu_rdata_corr_dc3[31:0]}}; // Need to replicate the data for non-dw access since ecc correction is done only in lower word


   assign {lsu_ld_data_dc3_nc[63:32],      lsu_ld_data_dc3[31:0]}      = lsu_rdata_dc3[63:0] >> 8*lsu_addr_dc3[1:0];
   assign {lsu_ld_data_corr_dc3_nc[63:32], lsu_ld_data_corr_dc3[31:0]} = lsu_rdata_corr_dc3[63:0] >> 8*lsu_addr_dc3[1:0];

   assign dccm_dout_dc3[63:0] = {dccm_data_hi_dc3[DCCM_DATA_WIDTH-1:0], dccm_data_lo_dc3[DCCM_DATA_WIDTH-1:0]};
   assign dccm_corr_dout_dc3[63:0] = {store_ecc_datafn_hi_dc3[DCCM_DATA_WIDTH-1:0], store_ecc_datafn_lo_dc3[DCCM_DATA_WIDTH-1:0]};
   assign stbuf_fwddata_dc3[63:0] = {stbuf_fwddata_hi_dc3[DCCM_DATA_WIDTH-1:0], stbuf_fwddata_lo_dc3[DCCM_DATA_WIDTH-1:0]};
   assign stbuf_fwdbyteen_dc3[7:0] = {stbuf_fwdbyteen_hi_dc3[DCCM_BYTE_WIDTH-1:0], stbuf_fwdbyteen_lo_dc3[DCCM_BYTE_WIDTH-1:0]};

   for (genvar i=0; i<8; i++) begin: GenLoop
      assign lsu_rdata_dc3[(8*i)+7:8*i]      = stbuf_fwdbyteen_dc3[i] ? stbuf_fwddata_dc3[(8*i)+7:8*i] :
                                                                        (addr_in_pic_dc3 ? picm_rd_data_dc3[(8*i)+7:8*i] :  dccm_dout_dc3[(8*i)+7:8*i]);
      assign lsu_rdata_corr_dc3[(8*i)+7:8*i] = stbuf_fwdbyteen_dc3[i] ? stbuf_fwddata_dc3[(8*i)+7:8*i] :
                                                                        (addr_in_pic_dc3 ? picm_rd_data_dc3[(8*i)+7:8*i] :  dccm_corr_dout_dc3[(8*i)+7:8*i]);
   end

   assign lsu_stbuf_commit_any = stbuf_reqvld_any & ~lsu_freeze_dc3 & (
                                 (~(lsu_dccm_rden_dc1 | picm_rden | picm_mken)) |
                                 ((picm_rden | picm_mken) & ~stbuf_addr_in_pic_any) |
                                 (lsu_dccm_rden_dc1 & (stbuf_addr_in_pic_any | (~((stbuf_addr_any[DCCM_WIDTH_BITS+:DCCM_BANK_BITS] == lsu_addr_dc1[DCCM_WIDTH_BITS+:DCCM_BANK_BITS]) |
                                                                                  (stbuf_addr_any[DCCM_WIDTH_BITS+:DCCM_BANK_BITS] == end_addr_dc1[DCCM_WIDTH_BITS+:DCCM_BANK_BITS]))))));

   // No need to read for aligned word/dword stores since ECC will come by new data completely
   assign lsu_dccm_rden_dc1 = lsu_pkt_dc1.valid & (lsu_pkt_dc1.load | (lsu_pkt_dc1.store & (~(lsu_pkt_dc1.word | lsu_pkt_dc1.dword) | (lsu_addr_dc1[1:0] != 2'b0)))) & addr_in_dccm_dc1;

   // DCCM inputs
   assign dccm_wren = lsu_stbuf_commit_any & ~stbuf_addr_in_pic_any;
   assign dccm_rden = lsu_dccm_rden_dc1 & addr_in_dccm_dc1;
   assign dccm_wr_addr[DCCM_BITS-1:0] = stbuf_addr_any[DCCM_BITS-1:0];
   assign dccm_rd_addr_lo[DCCM_BITS-1:0] = lsu_addr_dc1[DCCM_BITS-1:0];
   assign dccm_rd_addr_hi[DCCM_BITS-1:0] = end_addr_dc1[DCCM_BITS-1:0];
   assign dccm_wr_data[DCCM_FDATA_WIDTH-1:0] = {stbuf_ecc_any[DCCM_ECC_WIDTH-1:0],stbuf_data_any[DCCM_DATA_WIDTH-1:0]};

   // DCCM outputs
   assign dccm_data_lo_dc2[DCCM_DATA_WIDTH-1:0] = dccm_rd_data_lo[DCCM_DATA_WIDTH-1:0];
   assign dccm_data_hi_dc2[DCCM_DATA_WIDTH-1:0] = dccm_rd_data_hi[DCCM_DATA_WIDTH-1:0];

   assign dccm_data_ecc_lo_dc2[DCCM_ECC_WIDTH-1:0] = dccm_rd_data_lo[DCCM_FDATA_WIDTH-1:DCCM_DATA_WIDTH];
   assign dccm_data_ecc_hi_dc2[DCCM_ECC_WIDTH-1:0] = dccm_rd_data_hi[DCCM_FDATA_WIDTH-1:DCCM_DATA_WIDTH];

   // PIC signals. PIC ignores the lower 2 bits of address since PIC memory registers are 32-bits
   assign picm_wren = lsu_stbuf_commit_any & stbuf_addr_in_pic_any;
   assign picm_rden = lsu_pkt_dc1.valid & lsu_pkt_dc1.load & addr_in_pic_dc1;
   assign picm_mken = lsu_pkt_dc1.valid & lsu_pkt_dc1.store & addr_in_pic_dc1;  // Get the mask for stores
   assign picm_addr[31:0] = (picm_rden | picm_mken) ? (`RV_PIC_BASE_ADDR | {17'b0,lsu_addr_dc1[14:0]}) : (`RV_PIC_BASE_ADDR | {{32-PIC_BITS{1'b0}},stbuf_addr_any[`RV_PIC_BITS-1:0]});
   //assign picm_addr[31:0] = (picm_rden | picm_mken) ? {`RV_PIC_REGION,`RV_PIC_OFFSET,3'b0,lsu_addr_dc1[14:0]} : {`RV_PIC_REGION,`RV_PIC_OFFSET,{18-PIC_BITS{1'b0}},stbuf_addr_any[`RV_PIC_BITS-1:0]};
   assign picm_wr_data[31:0] = stbuf_data_any[31:0];


   // Flops
   assign picm_mask_data_dc3[31:0] = picm_rd_data_lo_dc3[31:0];
   assign picm_rd_data_dc3[63:0] = {picm_rd_data_lo_dc3[31:0], picm_rd_data_lo_dc3[31:0]} ;
   rvdffe #(32) picm_data_ff (.*, .din(picm_rd_data[31:0]), .dout(picm_rd_data_lo_dc3[31:0]), .en(lsu_pic_c1_dc3_clken));
   if (DCCM_ENABLE == 1) begin: Gen_dccm_enable

      rvdff_fpga #(1) dccm_rden_dc2ff (.*, .din(lsu_dccm_rden_dc1), .dout(lsu_dccm_rden_dc2), .clk(lsu_freeze_c2_dc2_clk), .clken(lsu_freeze_c2_dc2_clken), .rawclk(clk));
      rvdff_fpga #(1) dccm_rden_dc3ff (.*, .din(lsu_dccm_rden_dc2), .dout(lsu_dccm_rden_dc3), .clk(lsu_freeze_c2_dc3_clk), .clken(lsu_freeze_c2_dc3_clken), .rawclk(clk));

      rvdff_fpga #(DCCM_DATA_WIDTH) dccm_data_hi_ff    (.*, .din(dccm_data_hi_dc2[DCCM_DATA_WIDTH-1:0]),    .dout(dccm_data_hi_dc3[DCCM_DATA_WIDTH-1:0]),    .clk(lsu_dccm_c1_dc3_clk), .clken(lsu_dccm_c1_dc3_clken), .rawclk(clk));
      rvdff_fpga #(DCCM_DATA_WIDTH) dccm_data_lo_ff    (.*, .din(dccm_data_lo_dc2[DCCM_DATA_WIDTH-1:0]),    .dout(dccm_data_lo_dc3[DCCM_DATA_WIDTH-1:0]),    .clk(lsu_dccm_c1_dc3_clk), .clken(lsu_dccm_c1_dc3_clken), .rawclk(clk));
      rvdff_fpga #(DCCM_ECC_WIDTH) dccm_data_ecc_hi_ff (.*, .din(dccm_data_ecc_hi_dc2[DCCM_ECC_WIDTH-1:0]), .dout(dccm_data_ecc_hi_dc3[DCCM_ECC_WIDTH-1:0]), .clk(lsu_dccm_c1_dc3_clk), .clken(lsu_dccm_c1_dc3_clken), .rawclk(clk));
      rvdff_fpga #(DCCM_ECC_WIDTH) dccm_data_ecc_lo_ff (.*, .din(dccm_data_ecc_lo_dc2[DCCM_ECC_WIDTH-1:0]), .dout(dccm_data_ecc_lo_dc3[DCCM_ECC_WIDTH-1:0]), .clk(lsu_dccm_c1_dc3_clk), .clken(lsu_dccm_c1_dc3_clken), .rawclk(clk));

   end else begin: Gen_dccm_disable
      assign lsu_dccm_rden_dc2 = '0;
      assign lsu_dccm_rden_dc3 = '0;
      assign dccm_data_hi_dc3[DCCM_DATA_WIDTH-1:0] = '0;
      assign dccm_data_lo_dc3[DCCM_DATA_WIDTH-1:0] = '0;
      assign dccm_data_ecc_hi_dc3[DCCM_ECC_WIDTH-1:0] = '0;
      assign dccm_data_ecc_lo_dc3[DCCM_ECC_WIDTH-1:0] = '0;
   end

endmodule
