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
// Function: Top level file for load store unit
// Comments:
//
//
// DC1 -> DC2 -> DC3 -> DC4 (Commit)
//
//********************************************************************************

module lsu
   import swerv_types::*;
(

   input logic [31:0]                      i0_result_e4_eff, // I0 e4 result for e4 -> dc3 store forwarding
   input logic [31:0]                      i1_result_e4_eff, // I1 e4 result for e4 -> dc3 store forwarding
   input logic [31:0]                      i0_result_e2,     // I0 e2 result for e2 -> dc2 store forwarding

   input logic                             flush_final_e3,    // I0/I1 flush in e3
   input logic                             i0_flush_final_e3, // I0 flush in e3
   input logic                             dec_tlu_flush_lower_wb,    // I0/I1 writeback flush. This is used to flush the old packets only
   input logic                             dec_tlu_i0_kill_writeb_wb, // I0 is flushed, don't writeback any results to arch state
   input logic                             dec_tlu_i1_kill_writeb_wb, // I1 is flushed, don't writeback any results to arch state
   input logic                             dec_tlu_cancel_e4,         // cancel the bus load in dc4 and reset the freeze

   // chicken signals
   input logic                             dec_tlu_non_blocking_disable,    // disable the non block
   input logic                             dec_tlu_wb_coalescing_disable,   // disable the write buffer coalesce
   input logic                             dec_tlu_ld_miss_byp_wb_disable,  // disable the miss bypass in the write buffer
   input logic                             dec_tlu_sideeffect_posted_disable,  // disable posted writes to sideeffect addr to the bus
   input logic                             dec_tlu_core_ecc_disable,        // disable the generation of the ecc

   input logic [31:0]                      exu_lsu_rs1_d,      // address rs operand
   input logic [31:0]                      exu_lsu_rs2_d,      // store data
   input logic [11:0]                      dec_lsu_offset_d,   // address offset operand

   input                                   lsu_pkt_t lsu_p,     // lsu control packet
   input logic                             dec_i0_lsu_decode_d, // lsu is in i0
   input logic [31:0]                      dec_tlu_mrac_ff,     // CSR for memory region control

   output logic [31:0]                     lsu_result_dc3,      // lsu load data
   output logic                            lsu_single_ecc_error_incr,     // Increment the counter for Single ECC error
   output logic [31:0]                     lsu_result_corr_dc4, // This is the ECC corrected data going to RF
   output logic                            lsu_freeze_dc3,      // lsu freeze due to load to external
   output logic                            lsu_load_stall_any, // This is for blocking loads in the decode
   output logic                            lsu_store_stall_any, // This is for blocking stores in the decode
   output logic                            lsu_load_ecc_stbuf_full_dc3, // Load with ecc error can't allocate to stbuf
   output logic                            lsu_idle_any,        // lsu buffers are empty and no instruction in the pipeline
   output logic                            lsu_halt_idle_any,   // This is used to enter halt mode. Exclude DMA

   output lsu_error_pkt_t                  lsu_error_pkt_dc3,             // lsu exception packet
   output logic                            lsu_freeze_external_ints_dc3,  // freeze due to sideeffects loads need to suppress external interrupt
   output logic                            lsu_imprecise_error_load_any,  // bus load imprecise error
   output logic                            lsu_imprecise_error_store_any, // bus store imprecise error
   output logic [31:0]                     lsu_imprecise_error_addr_any,  // bus store imprecise error address

   // Non-blocking loads
   input  logic                                 dec_nonblock_load_freeze_dc2,   //
   output logic                                 lsu_nonblock_load_valid_dc3,    // there is an external load -> put in the cam
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_tag_dc3,      // the tag of the external non block load
   output logic                                 lsu_nonblock_load_inv_dc5,      // invalidate signal for the cam entry for non block loads
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_inv_tag_dc5,  // tag of the enrty which needs to be invalidated
   output logic                                 lsu_nonblock_load_data_valid,   // the non block is valid - sending information back to the cam
   output logic                                 lsu_nonblock_load_data_error,   // non block load has an error
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_data_tag,     // the tag of the non block load sending the data/error
   output logic [31:0]                          lsu_nonblock_load_data,         // Data of the non block load

   output logic                            lsu_pmu_misaligned_dc3,         // PMU : misaligned
   output logic                            lsu_pmu_bus_trxn,               // PMU : bus transaction
   output logic                            lsu_pmu_bus_misaligned,         // PMU : misaligned access going to the bus
   output logic                            lsu_pmu_bus_error,              // PMU : bus sending error back
   output logic                            lsu_pmu_bus_busy,               // PMU : bus is not ready

   // Trigger signals
   input                                   trigger_pkt_t [3:0] trigger_pkt_any, // Trigger info from the decode
   output logic [3:0]                      lsu_trigger_match_dc3,               // lsu trigger hit (one bit per trigger)

   // DCCM ports
   output logic                            dccm_wren,       // DCCM write enable
   output logic                            dccm_rden,       // DCCM read enable
   output logic [`RV_DCCM_BITS-1:0]        dccm_wr_addr,    // DCCM write address (write can happen to one bank only)
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_lo, // DCCM read address low bank
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_hi, // DCCM read address hi bank (hi and low same if aligned read)
   output logic [`RV_DCCM_FDATA_WIDTH-1:0] dccm_wr_data,    // DCCM write data (this is always aligned)

   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo, // DCCM read data low bank
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi, // DCCM read data hi bank

   // PIC ports
   output logic                            picm_wren,    // PIC memory write enable
   output logic                            picm_rden,    // PIC memory read enable
   output logic                            picm_mken,    // Need to read the mask for stores to determine which bits to write/forward
   output logic [31:0]                     picm_addr,    // PIC memory address
   output logic [31:0]                     picm_wr_data, // PIC memory write data
   input logic [31:0]                      picm_rd_data, // PIC memory read/mask data

   // AXI Write Channels
   output logic                            lsu_axi_awvalid,
   input  logic                            lsu_axi_awready,
   output logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_awid,
   output logic [31:0]                     lsu_axi_awaddr,
   output logic [3:0]                      lsu_axi_awregion,
   output logic [7:0]                      lsu_axi_awlen,
   output logic [2:0]                      lsu_axi_awsize,
   output logic [1:0]                      lsu_axi_awburst,
   output logic                            lsu_axi_awlock,
   output logic [3:0]                      lsu_axi_awcache,
   output logic [2:0]                      lsu_axi_awprot,
   output logic [3:0]                      lsu_axi_awqos,

   output logic                            lsu_axi_wvalid,
   input  logic                            lsu_axi_wready,
   output logic [63:0]                     lsu_axi_wdata,
   output logic [7:0]                      lsu_axi_wstrb,
   output logic                            lsu_axi_wlast,

   input  logic                            lsu_axi_bvalid,
   output logic                            lsu_axi_bready,
   input  logic [1:0]                      lsu_axi_bresp,
   input  logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_bid,

   // AXI Read Channels
   output logic                            lsu_axi_arvalid,
   input  logic                            lsu_axi_arready,
   output logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_arid,
   output logic [31:0]                     lsu_axi_araddr,
   output logic [3:0]                      lsu_axi_arregion,
   output logic [7:0]                      lsu_axi_arlen,
   output logic [2:0]                      lsu_axi_arsize,
   output logic [1:0]                      lsu_axi_arburst,
   output logic                            lsu_axi_arlock,
   output logic [3:0]                      lsu_axi_arcache,
   output logic [2:0]                      lsu_axi_arprot,
   output logic [3:0]                      lsu_axi_arqos,

   input  logic                            lsu_axi_rvalid,
   output logic                            lsu_axi_rready,
   input  logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_rid,
   input  logic [63:0]                     lsu_axi_rdata,
   input  logic [1:0]                      lsu_axi_rresp,
   input  logic                            lsu_axi_rlast,

   input logic                             lsu_bus_clk_en,    // external drives a clock_en to control bus ratio

   // DMA slave
   input logic                             dma_dccm_req,       // DMA read/write to dccm
   input logic [31:0]                      dma_mem_addr,       // DMA address
   input logic [2:0]                       dma_mem_sz,         // DMA access size
   input logic                             dma_mem_write,      // DMA access is a write
   input logic [63:0]                      dma_mem_wdata,      // DMA write data

   output logic                            dccm_dma_rvalid,     // lsu data valid for DMA dccm read
   output logic                            dccm_dma_ecc_error,  // DMA load had ecc error
   output logic [63:0]                     dccm_dma_rdata,      // lsu data for DMA dccm read
   output logic                            dccm_ready,          // lsu ready for DMA access

   input logic                             clk_override,        // Disable clock gating
   input logic                             scan_mode,           // scan
   input logic                             clk,
   input logic                             free_clk,
   input logic                             rst_l

   );


`include "global.h"

   logic        lsu_dccm_rden_dc3;
   logic [63:0] store_data_dc2;
   logic [63:0] store_data_dc3;
   logic [31:0] store_data_dc4;
   logic [31:0] store_data_dc5;
   logic [31:0] store_ecc_datafn_hi_dc3;
   logic [31:0] store_ecc_datafn_lo_dc3;

   logic        single_ecc_error_hi_dc3, single_ecc_error_lo_dc3;
   logic        lsu_single_ecc_error_dc3, lsu_single_ecc_error_dc4, lsu_single_ecc_error_dc5;
   logic        lsu_double_ecc_error_dc3;

   logic [31:0] dccm_data_hi_dc3;
   logic [31:0] dccm_data_lo_dc3;
   logic [6:0]  dccm_data_ecc_hi_dc3;
   logic [6:0]  dccm_data_ecc_lo_dc3;

   logic [31:0] lsu_ld_data_dc3;
   logic [31:0] lsu_ld_data_corr_dc3;
   logic [31:0] picm_mask_data_dc3;

   logic [31:0] lsu_addr_dc1, lsu_addr_dc2, lsu_addr_dc3, lsu_addr_dc4, lsu_addr_dc5;
   logic [31:0] end_addr_dc1, end_addr_dc2, end_addr_dc3, end_addr_dc4, end_addr_dc5;

   lsu_pkt_t    lsu_pkt_dc1, lsu_pkt_dc2, lsu_pkt_dc3, lsu_pkt_dc4, lsu_pkt_dc5;
   logic        lsu_i0_valid_dc1, lsu_i0_valid_dc2, lsu_i0_valid_dc3, lsu_i0_valid_dc4, lsu_i0_valid_dc5;

   // Store Buffer signals
   logic        isldst_dc1, dccm_ldst_dc2, dccm_ldst_dc3;
   logic        store_stbuf_reqvld_dc3;
   logic        load_stbuf_reqvld_dc3;
   logic        ldst_stbuf_reqvld_dc3;
   logic        lsu_commit_dc5;
   logic        lsu_exc_dc2;

   logic        addr_in_dccm_dc1, addr_in_dccm_dc2, addr_in_dccm_dc3;
   logic        addr_in_pic_dc1, addr_in_pic_dc2, addr_in_pic_dc3;
   logic        addr_external_dc2, addr_external_dc3, addr_external_dc4, addr_external_dc5;

   logic                       stbuf_reqvld_any;
   logic                       stbuf_reqvld_flushed_any;
   logic                       stbuf_addr_in_pic_any;
   logic [DCCM_BYTE_WIDTH-1:0] stbuf_byteen_any;
   logic [LSU_SB_BITS-1:0]     stbuf_addr_any;
   logic [DCCM_DATA_WIDTH-1:0] stbuf_data_any;
   logic [(DCCM_FDATA_WIDTH-DCCM_DATA_WIDTH-1):0] stbuf_ecc_any;

   logic                       lsu_cmpen_dc2;
   logic [DCCM_DATA_WIDTH-1:0] stbuf_fwddata_hi_dc3;
   logic [DCCM_DATA_WIDTH-1:0] stbuf_fwddata_lo_dc3;
   logic [DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_hi_dc3;
   logic [DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_lo_dc3;

   logic        lsu_stbuf_commit_any;
   logic        lsu_stbuf_empty_any;
   logic        lsu_stbuf_nodma_empty_any;   // Store Buffer is empty except dma writes
   logic        lsu_stbuf_full_any;

    // Bus signals
   logic        lsu_busreq_dc5;
   logic        lsu_bus_buffer_pend_any;
   logic        lsu_bus_buffer_empty_any;
   logic        lsu_bus_buffer_full_any;
   logic        lsu_busreq_dc2;
   logic [31:0] bus_read_data_dc3;
   logic        ld_bus_error_dc3;
   logic [31:0] ld_bus_error_addr_dc3;

   logic        flush_dc2_up, flush_dc3, flush_dc4, flush_dc5, flush_prior_dc5;
   logic        is_sideeffects_dc2, is_sideeffects_dc3;
   logic        ldst_nodma_dc1todc3;


   // Clocks
   logic        lsu_c1_dc3_clk, lsu_c1_dc4_clk, lsu_c1_dc5_clk;
   logic        lsu_c2_dc3_clk, lsu_c2_dc4_clk, lsu_c2_dc5_clk;
   logic        lsu_freeze_c1_dc2_clk, lsu_freeze_c1_dc3_clk;
   logic        lsu_freeze_c1_dc1_clken, lsu_freeze_c1_dc2_clken, lsu_freeze_c1_dc3_clken;
   logic        lsu_freeze_c2_dc1_clken, lsu_freeze_c2_dc2_clken, lsu_freeze_c2_dc3_clken, lsu_freeze_c2_dc4_clken;
   logic        lsu_store_c1_dc1_clken, lsu_store_c1_dc2_clken, lsu_store_c1_dc3_clken, lsu_store_c1_dc4_clk, lsu_store_c1_dc5_clk;

   logic        lsu_freeze_c2_dc1_clk, lsu_freeze_c2_dc2_clk, lsu_freeze_c2_dc3_clk, lsu_freeze_c2_dc4_clk;
   logic        lsu_stbuf_c1_clk;
   logic        lsu_bus_ibuf_c1_clk, lsu_bus_obuf_c1_clk, lsu_bus_buf_c1_clk;
   logic        lsu_dccm_c1_dc3_clk, lsu_dccm_c1_dc3_clken, lsu_pic_c1_dc3_clken;
   logic        lsu_busm_clk;
   logic        lsu_free_c2_clk;


   lsu_lsc_ctl lsu_lsc_ctl(.*);

   // block stores in decode  - for either bus or stbuf reasons
   assign lsu_store_stall_any = lsu_stbuf_full_any | lsu_bus_buffer_full_any;
   assign lsu_load_stall_any  = lsu_bus_buffer_full_any;

   // Ready to accept dma trxns
   // There can't be any inpipe forwarding from non-dma packet to dma packet since they can be flushed so we can't have ld/st in dc3-dc5 when dma is in dc2
   assign ldst_nodma_dc1todc3 = (lsu_pkt_dc1.valid & ~lsu_pkt_dc1.dma) | (lsu_pkt_dc2.valid & ~lsu_pkt_dc2.dma) | (lsu_pkt_dc3.valid & ~lsu_pkt_dc3.dma);
   assign dccm_ready = ~(lsu_p.valid | lsu_stbuf_full_any | lsu_freeze_dc3 | ldst_nodma_dc1todc3);

   // Generate per cycle flush signals
   assign flush_dc2_up = flush_final_e3 | i0_flush_final_e3 | dec_tlu_flush_lower_wb;
   assign flush_dc3    = (flush_final_e3 & i0_flush_final_e3) | dec_tlu_flush_lower_wb;
   assign flush_dc4    = dec_tlu_flush_lower_wb;
   assign flush_dc5    = (dec_tlu_i0_kill_writeb_wb | (dec_tlu_i1_kill_writeb_wb & ~lsu_i0_valid_dc5));
   assign flush_prior_dc5 = dec_tlu_i0_kill_writeb_wb & ~lsu_i0_valid_dc5;    // Flush is due to i0 instruction and ld/st is in i1

   // lsu idle
   assign lsu_idle_any = ~(lsu_pkt_dc1.valid | lsu_pkt_dc2.valid | lsu_pkt_dc3.valid | lsu_pkt_dc4.valid | lsu_pkt_dc5.valid) &
                         lsu_bus_buffer_empty_any & lsu_stbuf_empty_any;

   // lsu halt idle. This is used for entering the halt mode
   // Indicates non-idle if there is a instruction valid in dc1-dc5 or read/write buffers are non-empty since they can come with error
   // Need to make sure bus trxns are done and there are no non-dma writes in store buffer
   assign lsu_halt_idle_any = ~((lsu_pkt_dc1.valid & ~lsu_pkt_dc1.dma) |
                                (lsu_pkt_dc2.valid & ~lsu_pkt_dc2.dma) |
                                (lsu_pkt_dc3.valid & ~lsu_pkt_dc3.dma) |
                                (lsu_pkt_dc4.valid & ~lsu_pkt_dc4.dma) |
                                (lsu_pkt_dc5.valid & ~lsu_pkt_dc5.dma)) &
                               lsu_bus_buffer_empty_any & lsu_stbuf_nodma_empty_any;

   // Instantiate the store buffer
   //assign ldst_stbuf_reqvld_dc3  = store_stbuf_reqvld_dc3 | load_stbuf_reqvld_dc3;
   assign store_stbuf_reqvld_dc3 = lsu_pkt_dc3.valid & lsu_pkt_dc3.store & (addr_in_dccm_dc3 | addr_in_pic_dc3) & (~flush_dc3 | lsu_pkt_dc3.dma) & ~lsu_freeze_dc3;
   assign load_stbuf_reqvld_dc3  = lsu_pkt_dc3.valid & lsu_pkt_dc3.load  & (addr_in_dccm_dc3 | addr_in_pic_dc3) & lsu_single_ecc_error_dc3 & (~flush_dc3 | lsu_pkt_dc3.dma) & ~lsu_freeze_dc3;

   // These go to store buffer to detect full
   assign isldst_dc1 = lsu_pkt_dc1.valid & (lsu_pkt_dc1.load | lsu_pkt_dc1.store);
   assign dccm_ldst_dc2 = lsu_pkt_dc2.valid & (lsu_pkt_dc2.load | lsu_pkt_dc2.store) & (addr_in_dccm_dc2 | addr_in_pic_dc2);
   assign dccm_ldst_dc3 = lsu_pkt_dc3.valid & (lsu_pkt_dc3.load | lsu_pkt_dc3.store) & (addr_in_dccm_dc3 | addr_in_pic_dc3);

   // Disable Forwarding for now
   assign lsu_cmpen_dc2 = lsu_pkt_dc2.valid & (lsu_pkt_dc2.load | lsu_pkt_dc2.store) & (addr_in_dccm_dc2 | addr_in_pic_dc2);

   // Bus signals
   assign lsu_busreq_dc2 = lsu_pkt_dc2.valid & (lsu_pkt_dc2.load | lsu_pkt_dc2.store) & addr_external_dc2 & ~flush_dc2_up & ~lsu_exc_dc2;

   // PMU signals
   assign lsu_pmu_misaligned_dc3 = lsu_pkt_dc3.valid & ((lsu_pkt_dc3.half & lsu_addr_dc3[0]) | (lsu_pkt_dc3.word & (|lsu_addr_dc3[1:0])));


   lsu_dccm_ctl dccm_ctl (
      .lsu_addr_dc1(lsu_addr_dc1[31:0]),
      .end_addr_dc1(end_addr_dc1[DCCM_BITS-1:0]),
      .lsu_addr_dc3(lsu_addr_dc3[DCCM_BITS-1:0]),
      .*
   );

   lsu_stbuf stbuf(
      .lsu_addr_dc1(lsu_addr_dc1[LSU_SB_BITS-1:0]),
      .end_addr_dc1(end_addr_dc1[LSU_SB_BITS-1:0]),
      .lsu_addr_dc2(lsu_addr_dc2[LSU_SB_BITS-1:0]),
      .end_addr_dc2(end_addr_dc2[LSU_SB_BITS-1:0]),
      .lsu_addr_dc3(lsu_addr_dc3[LSU_SB_BITS-1:0]),
      .end_addr_dc3(end_addr_dc3[LSU_SB_BITS-1:0]),
      .*

   );

   lsu_ecc ecc (
      .lsu_addr_dc3(lsu_addr_dc3[DCCM_BITS-1:0]),
      .end_addr_dc3(end_addr_dc3[DCCM_BITS-1:0]),
      .*
   );

   lsu_trigger trigger (
      .store_data_dc3(store_data_dc3[31:0]),
      .*
   );

   // Clk domain
   lsu_clkdomain clkdomain (.*);

   // Bus interface
   lsu_bus_intf bus_intf (.*);

   //Flops
   //rvdffs #(1) lsu_i0_valid_dc1ff (.*, .din(dec_i0_lsu_decode_d), .dout(lsu_i0_valid_dc1), .en(~lsu_freeze_dc3));
   rvdff_fpga #(1) lsu_i0_valid_dc1ff    (.*, .din(dec_i0_lsu_decode_d), .dout(lsu_i0_valid_dc1), .clk(lsu_freeze_c2_dc1_clk), .clken(lsu_freeze_c2_dc1_clken), .rawclk(clk));
   rvdff_fpga #(1) lsu_i0_valid_dc2ff    (.*, .din(lsu_i0_valid_dc1),    .dout(lsu_i0_valid_dc2), .clk(lsu_freeze_c2_dc2_clk), .clken(lsu_freeze_c2_dc2_clken), .rawclk(clk));
   rvdff_fpga #(1) lsu_i0_valid_dc3ff    (.*, .din(lsu_i0_valid_dc2),    .dout(lsu_i0_valid_dc3), .clk(lsu_freeze_c2_dc3_clk), .clken(lsu_freeze_c2_dc3_clken), .rawclk(clk));
   rvdff_fpga #(1) lsu_i0_valid_dc4ff    (.*, .din(lsu_i0_valid_dc3),    .dout(lsu_i0_valid_dc4), .clk(lsu_freeze_c2_dc4_clk), .clken(lsu_freeze_c2_dc4_clken), .rawclk(clk));

   rvdff #(1) lsu_i0_valid_dc5ff    (.*, .din(lsu_i0_valid_dc4),    .dout(lsu_i0_valid_dc5), .clk(lsu_c2_dc5_clk));
   rvdff #(1) lsu_single_ecc_err_dc4(.*, .din(lsu_single_ecc_error_dc3), .dout(lsu_single_ecc_error_dc4), .clk(lsu_c2_dc4_clk));
   rvdff #(1) lsu_single_ecc_err_dc5(.*, .din(lsu_single_ecc_error_dc4), .dout(lsu_single_ecc_error_dc5), .clk(lsu_c2_dc5_clk));

`ifdef ASSERT_ON
   logic [8:0] store_data_bypass_sel;
   assign store_data_bypass_sel[8:0] =  {lsu_p.store_data_bypass_c1,
                                    lsu_p.store_data_bypass_c2,
                                    lsu_p.store_data_bypass_i0_e2_c2,
                                    lsu_p.store_data_bypass_e4_c1[1:0],
                                    lsu_p.store_data_bypass_e4_c2[1:0],
                                    lsu_p.store_data_bypass_e4_c3[1:0]};
   assert_store_data_bypass_onehot: assert #0 ($onehot0(store_data_bypass_sel[8:0]));

   assert_picm_rden_and_wren:   assert #0 ($onehot0({(picm_rden | picm_mken),picm_wren}));
   assert_picm_rden_and_dccmen: assert #0 ($onehot0({(picm_rden | picm_mken),dccm_rden}));
   assert_picm_wren_and_dccmen: assert #0 ($onehot0({picm_wren,   dccm_wren}));

   //assert_no_exceptions: assert #0 (lsu_exc_pkt_dc3.exc_valid == 1'b0);
   property exception_no_lsu_flush;
      @(posedge clk)  disable iff(~rst_l) lsu_error_pkt_dc3.exc_valid |-> ##[1:2] (flush_dc4 | flush_dc5);
   endproperty
   assert_exception_no_lsu_flush: assert property (exception_no_lsu_flush) else
      $display("No flush within 2 cycles of exception");
`endif

endmodule // lsu
