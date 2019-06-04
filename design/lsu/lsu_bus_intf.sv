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
// Function: lsu interface with interface queue
// Comments:
//
//********************************************************************************
module lsu_bus_intf (
   input logic                          clk,
   input logic                          rst_l,
   input logic                          scan_mode,
   input logic                          dec_tlu_non_blocking_disable,     // disable non block
   input logic                          dec_tlu_wb_coalescing_disable,    // disable write buffer coalescing
   input logic                          dec_tlu_ld_miss_byp_wb_disable,   // disable ld miss bypass of the write buffer
   
   // various clocks needed for the bus reads and writes
   input logic                          lsu_c1_dc3_clk,       
   input logic                          lsu_c1_dc4_clk,
   input logic                          lsu_c1_dc5_clk,
   input logic                          lsu_c2_dc3_clk,
   input logic                          lsu_c2_dc4_clk,
   input logic                          lsu_c2_dc5_clk,
   input logic                          lsu_freeze_c1_dc2_clk,
   input logic                          lsu_freeze_c1_dc3_clk,
   input logic                          lsu_freeze_c2_dc2_clk,
   input logic                          lsu_freeze_c2_dc3_clk,
   input logic                          lsu_rdbuf_c1_clk,
   input logic                          lsu_wrbuf_c1_clk,
   input logic                          lsu_free_c2_clk,
   input logic                          lsu_busm_clk,
                     
   input logic                          lsu_busreq_dc2,                   // bus request is in dc2
 
   input                                lsu_pkt_t lsu_pkt_dc1,            // lsu packet flowing down the pipe
   input                                lsu_pkt_t lsu_pkt_dc2,            // lsu packet flowing down the pipe
   input                                lsu_pkt_t lsu_pkt_dc3,            // lsu packet flowing down the pipe
   input                                lsu_pkt_t lsu_pkt_dc4,            // lsu packet flowing down the pipe
   input                                lsu_pkt_t lsu_pkt_dc5,            // lsu packet flowing down the pipe

   input logic [31:0]                   lsu_addr_dc1,                     // lsu address flowing down the pipe
   input logic [31:0]                   lsu_addr_dc2,                     // lsu address flowing down the pipe
   input logic [31:0]                   lsu_addr_dc3,                     // lsu address flowing down the pipe
   input logic [31:0]                   lsu_addr_dc4,                     // lsu address flowing down the pipe
   input logic [31:0]                   lsu_addr_dc5,                     // lsu address flowing down the pipe

   input logic [31:0]                   end_addr_dc1,                     // lsu address flowing down the pipe
   input logic [31:0]                   end_addr_dc2,                     // lsu address flowing down the pipe
   input logic [31:0]                   end_addr_dc3,                     // lsu address flowing down the pipe
   input logic [31:0]                   end_addr_dc4,                     // lsu address flowing down the pipe
   input logic [31:0]                   end_addr_dc5,                     // lsu address flowing down the pipe

   input logic                          addr_external_dc2,                // lsu instruction going to external 
   input logic                          addr_external_dc3,                // lsu instruction going to external
   input logic                          addr_external_dc4,                // lsu instruction going to external
   input logic                          addr_external_dc5,                // lsu instruction going to external

   input logic [63:0]                   store_data_dc2,                   // store data flowing down the pipe
   input logic [63:0]                   store_data_dc3,                   // store data flowing down the pipe
   input logic [31:0]                   store_data_dc4,                   // store data flowing down the pipe
   input logic [31:0]                   store_data_dc5,                   // store data flowing down the pipe

   input logic                          lsu_commit_dc5,                   // lsu instruction in dc5 commits
   input logic                          is_sideeffects_dc2,               // lsu attribute is side_effects
   input logic                          is_sideeffects_dc3,               // lsu attribute is side_effects
   input logic                          flush_dc2_up,                     // flush 
   input logic                          flush_dc3,                        // flush
   input logic                          flush_dc4,                        // flush
   input logic                          flush_dc5,                        // flush

   output logic                         lsu_freeze_dc3,                   // load goes to external and asserts freeze
   output logic                         lsu_ldbusreq_dc3,                 // lsu in dc3 has a load bus request
   output logic                         lsu_ldbusreq_dc5,                 // lsu in dc5 has a load bus request
   output logic                         lsu_stbusreq_dc5,                 // lsu in dc5 is a store bus request
   output logic                         lsu_write_buffer_full_any,        // write buffer is full
   output logic                         lsu_write_buffer_empty_any,       // write buffer is empty
   output logic                         lsu_read_buffer_empty_any,        // Used for clock enable
   output logic [31:0]                  bus_read_data_dc3,                // the Dc3 load data

   output logic                         ld_bus_error_dc3,                 // bus error in dc3
   output logic [31:0]                  ld_bus_error_addr_dc3,            // address of the bus error 

   output logic                         lsu_imprecise_error_load_any,     // imprecise load bus error
   output logic                         lsu_imprecise_error_store_any,    // imprecise store bus error
   output logic [31:0]                  lsu_imprecise_error_addr_any,     // address of the imprecise error

   // Non-blocking loads
   input  logic 	                       dec_nonblock_load_freeze_dc2,
   output logic                                lsu_nonblock_load_valid_dc3,     // there is an external load -> put in the cam
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_dc3,       // the tag of the external non block load
   output logic                                lsu_nonblock_load_inv_dc5,       // invalidate signal for the cam entry for non block loads
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_dc5,   // tag of the enrty which needs to be invalidated
   output logic                                lsu_nonblock_load_data_valid,    // the non block is valid - sending information back to the cam                                               
   output logic                                lsu_nonblock_load_data_error,    // non block load has an error                 
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,      // the tag of the non block load sending the data/error                                             
   output logic [31:0]                         lsu_nonblock_load_data,          // Data of the non block load	

   // PMU events
   output logic                         lsu_pmu_bus_trxn,
   output logic                         lsu_pmu_bus_misaligned,
   output logic                         lsu_pmu_bus_error,
   output logic                         lsu_pmu_bus_busy,
                     
   // AXI signals               
   // AXI Write Channels
   output logic                         lsu_axi_awvalid,
   input  logic                         lsu_axi_awready,
   output logic [`RV_LSU_BUS_TAG-1:0]   lsu_axi_awid,
   output logic [31:0]                  lsu_axi_awaddr,
   output logic [3:0]                   lsu_axi_awregion,
   output logic [7:0]                   lsu_axi_awlen,
   output logic [2:0]                   lsu_axi_awsize,
   output logic [1:0]                   lsu_axi_awburst,
   output logic                         lsu_axi_awlock,
   output logic [3:0]                   lsu_axi_awcache,
   output logic [2:0]                   lsu_axi_awprot,
   output logic [3:0]                   lsu_axi_awqos,
                             
   output logic                         lsu_axi_wvalid,                                       
   input  logic                         lsu_axi_wready,
   output logic [63:0]                  lsu_axi_wdata,
   output logic [7:0]                   lsu_axi_wstrb,
   output logic                         lsu_axi_wlast,

   input  logic                         lsu_axi_bvalid,
   output logic                         lsu_axi_bready,
   input  logic [1:0]                   lsu_axi_bresp,
   input  logic [`RV_LSU_BUS_TAG-1:0]   lsu_axi_bid,

   // AXI Read Channels
   output logic                         lsu_axi_arvalid,
   input  logic                         lsu_axi_arready,
   output logic [`RV_LSU_BUS_TAG-1:0]   lsu_axi_arid,
   output logic [31:0]                  lsu_axi_araddr,
   output logic [3:0]                   lsu_axi_arregion,
   output logic [7:0]                   lsu_axi_arlen,
   output logic [2:0]                   lsu_axi_arsize,
   output logic [1:0]                   lsu_axi_arburst,
   output logic                         lsu_axi_arlock,
   output logic [3:0]                   lsu_axi_arcache,
   output logic [2:0]                   lsu_axi_arprot,
   output logic [3:0]                   lsu_axi_arqos,

   input  logic                         lsu_axi_rvalid,
   output logic                         lsu_axi_rready,
   input  logic [`RV_LSU_BUS_TAG-1:0]   lsu_axi_rid,
   input  logic [63:0]                  lsu_axi_rdata,
   input  logic [1:0]                   lsu_axi_rresp,
   input  logic                         lsu_axi_rlast,
                                          
   input logic                          lsu_bus_clk_en

);

`include "global.h"

   logic              rdbuf_full_freeze_dc3;
   logic              ld_freeze_dc3;		     

   logic              store_freeze_dc3;		     

   logic              lsu_bus_clk_en_q;
   logic              write_buffer_block_any;       // Block the write buffer if there are outstanding non-blocking loads
   logic              ldst_dual_dc1, ldst_dual_dc2, ldst_dual_dc3, ldst_dual_dc4, ldst_dual_dc5;
   logic              lsu_read_buffer_block_dc2;
   
   logic [3:0]        ldst_byteen_dc2, ldst_byteen_dc3, ldst_byteen_dc4, ldst_byteen_dc5;
   logic [15:0]       ldst_byteen_ext_dc2, ldst_byteen_ext_dc3, ldst_byteen_ext_dc4, ldst_byteen_ext_dc5;
   logic [7:0] 	      ldst_byteen_hi_dc2, ldst_byteen_hi_dc3, ldst_byteen_hi_dc4, ldst_byteen_hi_dc5;
   logic [7:0] 	      ldst_byteen_lo_dc2, ldst_byteen_lo_dc3, ldst_byteen_lo_dc4, ldst_byteen_lo_dc5;
   logic              is_sideeffects_dc4, is_sideeffects_dc5;

   
   logic [127:0]      store_data_ext_dc3, store_data_ext_dc4, store_data_ext_dc5;
   logic [63:0]       store_data_hi_dc3, store_data_hi_dc4, store_data_hi_dc5;
   logic [63:0]       store_data_lo_dc3, store_data_lo_dc4, store_data_lo_dc5;
   
   logic              ld_addr_dc3hit_lo_lo, ld_addr_dc3hit_hi_lo, ld_addr_dc3hit_lo_hi, ld_addr_dc3hit_hi_hi;
   logic              ld_addr_dc4hit_lo_lo, ld_addr_dc4hit_hi_lo, ld_addr_dc4hit_lo_hi, ld_addr_dc4hit_hi_hi;
   logic              ld_addr_dc5hit_lo_lo, ld_addr_dc5hit_hi_lo, ld_addr_dc5hit_lo_hi, ld_addr_dc5hit_hi_hi;

   logic [7:0] 	      ld_byte_dc3hit_lo_lo, ld_byte_dc3hit_hi_lo, ld_byte_dc3hit_lo_hi, ld_byte_dc3hit_hi_hi;
   logic [7:0] 	      ld_byte_dc4hit_lo_lo, ld_byte_dc4hit_hi_lo, ld_byte_dc4hit_lo_hi, ld_byte_dc4hit_hi_hi;
   logic [7:0] 	      ld_byte_dc5hit_lo_lo, ld_byte_dc5hit_hi_lo, ld_byte_dc5hit_lo_hi, ld_byte_dc5hit_hi_hi;

   logic [7:0] 	      ld_byte_hit_lo, ld_byte_dc3hit_lo, ld_byte_dc4hit_lo, ld_byte_dc5hit_lo;
   logic [7:0] 	      ld_byte_hit_hi, ld_byte_dc3hit_hi, ld_byte_dc4hit_hi, ld_byte_dc5hit_hi;

   logic [63:0]       ld_fwddata_dc3pipe_lo, ld_fwddata_dc4pipe_lo, ld_fwddata_dc5pipe_lo;
   logic [63:0]       ld_fwddata_dc3pipe_hi, ld_fwddata_dc4pipe_hi, ld_fwddata_dc5pipe_hi;

   logic [7:0]        ld_byte_hit_wrbuf_lo, ld_byte_hit_wrbuf_hi;
   logic [63:0]       ld_fwddata_wrbuf_lo, ld_fwddata_wrbuf_hi;
   
   logic              ld_hit_rdbuf_hi, ld_hit_rdbuf_lo;
   logic [63:0]       ld_fwddata_rdbuf_hi, ld_fwddata_rdbuf_lo;

   logic [63:0]       ld_fwddata_lo, ld_fwddata_hi;
   logic [31:0]       ld_fwddata_dc2, ld_fwddata_dc3;
   logic [31:0]       ld_read_buffer_data_dc3;
   
   logic              ld_full_hit_hi_dc2, ld_full_hit_lo_dc2;
   logic              ld_hit_dc2, ld_full_hit_dc2, ld_full_hit_dc3;
   logic              is_aligned_dc5;

   logic              store_bus_error_any;   // Imprecise error
   logic [31:0]       store_bus_error_addr;
   logic              ld_imprecise_bus_error_any;
   logic [31:0]       ld_imprecise_bus_error_addr;
   logic [127:32]     ld_fwddata_dc2_nc;
   
   // PMU signals
   assign lsu_pmu_bus_trxn  = (lsu_axi_awvalid & lsu_axi_awready) | (lsu_axi_arvalid & lsu_axi_arready);
   assign lsu_pmu_bus_misaligned = lsu_busreq_dc2 & ldst_dual_dc2;
   assign lsu_pmu_bus_error = ld_bus_error_dc3 | ld_imprecise_bus_error_any | store_bus_error_any;
   assign lsu_pmu_bus_busy  = (lsu_axi_awvalid & ~lsu_axi_awready) | (lsu_axi_arvalid & ~lsu_axi_arready);

   assign ldst_byteen_dc2[3:0] = ({4{lsu_pkt_dc2.by}}   & 4'b0001) |
                                 ({4{lsu_pkt_dc2.half}} & 4'b0011) |
                                 ({4{lsu_pkt_dc2.word}} & 4'b1111);
   assign ldst_dual_dc1 = (lsu_addr_dc1[3] != end_addr_dc1[3]);
   assign lsu_freeze_dc3 = (rdbuf_full_freeze_dc3 | ld_freeze_dc3 | store_freeze_dc3) & ~(flush_dc4 | flush_dc5);
   
   assign lsu_imprecise_error_load_any       = ld_imprecise_bus_error_any;
   assign lsu_imprecise_error_store_any      = store_bus_error_any & ~ld_imprecise_bus_error_any;
   assign lsu_imprecise_error_addr_any[31:0] = ld_imprecise_bus_error_any ? ld_imprecise_bus_error_addr[31:0] : store_bus_error_addr[31:0];
   //assign ld_bus_error_addr_dc3[31:0]        = last_bus_addr[31:0];
   
   // Determine if the packet is word aligned
   assign is_aligned_dc5  = (lsu_pkt_dc5.word & (lsu_addr_dc5[1:0] == 2'b0)) |
                            (lsu_pkt_dc5.half & (lsu_addr_dc5[0] == 1'b0));

   // Read Buffer
   lsu_bus_read_buffer bus_read_buffer (
      .*
   );

   // Write Buffer
   lsu_bus_write_buffer bus_write_buffer (
      .*
   );
   
   // Create Hi/Lo signals
   assign ldst_byteen_ext_dc2[15:0] = {12'b0,ldst_byteen_dc2[3:0]} << lsu_addr_dc2[2:0];
   assign ldst_byteen_ext_dc3[15:0] = {12'b0,ldst_byteen_dc3[3:0]} << lsu_addr_dc3[2:0];
   assign ldst_byteen_ext_dc4[15:0] = {12'b0,ldst_byteen_dc4[3:0]} << lsu_addr_dc4[2:0];
   assign ldst_byteen_ext_dc5[15:0] = {12'b0,ldst_byteen_dc5[3:0]} << lsu_addr_dc5[2:0];

   assign store_data_ext_dc3[127:0] = {64'b0,store_data_dc3[63:0]} << {lsu_addr_dc3[2:0],3'b0};
   assign store_data_ext_dc4[127:0] = {96'b0,store_data_dc4[31:0]} << {lsu_addr_dc4[2:0],3'b0};
   assign store_data_ext_dc5[127:0] = {96'b0,store_data_dc5[31:0]} << {lsu_addr_dc5[2:0],3'b0};
   
   assign ldst_byteen_hi_dc2[7:0]   = ldst_byteen_ext_dc2[15:8];
   assign ldst_byteen_lo_dc2[7:0]   = ldst_byteen_ext_dc2[7:0];
   assign ldst_byteen_hi_dc3[7:0]   = ldst_byteen_ext_dc3[15:8];
   assign ldst_byteen_lo_dc3[7:0]   = ldst_byteen_ext_dc3[7:0];
   assign ldst_byteen_hi_dc4[7:0]   = ldst_byteen_ext_dc4[15:8];
   assign ldst_byteen_lo_dc4[7:0]   = ldst_byteen_ext_dc4[7:0];
   assign ldst_byteen_hi_dc5[7:0]   = ldst_byteen_ext_dc5[15:8];
   assign ldst_byteen_lo_dc5[7:0]   = ldst_byteen_ext_dc5[7:0];

   assign store_data_hi_dc3[63:0]   = store_data_ext_dc3[127:64];
   assign store_data_lo_dc3[63:0]   = store_data_ext_dc3[63:0];
   assign store_data_hi_dc4[63:0]   = store_data_ext_dc4[127:64];
   assign store_data_lo_dc4[63:0]   = store_data_ext_dc4[63:0];
   assign store_data_hi_dc5[63:0]   = store_data_ext_dc5[127:64];
   assign store_data_lo_dc5[63:0]   = store_data_ext_dc5[63:0];
   
   assign ld_addr_dc3hit_lo_lo = (lsu_addr_dc2[31:3] == lsu_addr_dc3[31:3]) & lsu_pkt_dc3.valid & lsu_pkt_dc3.store & lsu_busreq_dc2;
   assign ld_addr_dc3hit_lo_hi = (end_addr_dc2[31:3] == lsu_addr_dc3[31:3]) & lsu_pkt_dc3.valid & lsu_pkt_dc3.store & lsu_busreq_dc2;
   assign ld_addr_dc3hit_hi_lo = (lsu_addr_dc2[31:3] == end_addr_dc3[31:3]) & lsu_pkt_dc3.valid & lsu_pkt_dc3.store & lsu_busreq_dc2;
   assign ld_addr_dc3hit_hi_hi = (end_addr_dc2[31:3] == end_addr_dc3[31:3]) & lsu_pkt_dc3.valid & lsu_pkt_dc3.store & lsu_busreq_dc2;

   assign ld_addr_dc4hit_lo_lo = (lsu_addr_dc2[31:3] == lsu_addr_dc4[31:3]) & lsu_pkt_dc4.valid & lsu_pkt_dc4.store & lsu_busreq_dc2;
   assign ld_addr_dc4hit_lo_hi = (end_addr_dc2[31:3] == lsu_addr_dc4[31:3]) & lsu_pkt_dc4.valid & lsu_pkt_dc4.store & lsu_busreq_dc2;
   assign ld_addr_dc4hit_hi_lo = (lsu_addr_dc2[31:3] == end_addr_dc4[31:3]) & lsu_pkt_dc4.valid & lsu_pkt_dc4.store & lsu_busreq_dc2;
   assign ld_addr_dc4hit_hi_hi = (end_addr_dc2[31:3] == end_addr_dc4[31:3]) & lsu_pkt_dc4.valid & lsu_pkt_dc4.store & lsu_busreq_dc2;

   assign ld_addr_dc5hit_lo_lo = (lsu_addr_dc2[31:3] == lsu_addr_dc5[31:3]) & lsu_pkt_dc5.valid & lsu_pkt_dc5.store & lsu_busreq_dc2;
   assign ld_addr_dc5hit_lo_hi = (end_addr_dc2[31:3] == lsu_addr_dc5[31:3]) & lsu_pkt_dc5.valid & lsu_pkt_dc5.store & lsu_busreq_dc2;
   assign ld_addr_dc5hit_hi_lo = (lsu_addr_dc2[31:3] == end_addr_dc5[31:3]) & lsu_pkt_dc5.valid & lsu_pkt_dc5.store & lsu_busreq_dc2;
   assign ld_addr_dc5hit_hi_hi = (end_addr_dc2[31:3] == end_addr_dc5[31:3]) & lsu_pkt_dc5.valid & lsu_pkt_dc5.store & lsu_busreq_dc2;

   for (genvar i=0; i<8; i++) begin
      assign ld_byte_dc3hit_lo_lo[i] = ld_addr_dc3hit_lo_lo & ldst_byteen_lo_dc3[i] & ldst_byteen_lo_dc2[i];
      assign ld_byte_dc3hit_lo_hi[i] = ld_addr_dc3hit_lo_hi & ldst_byteen_lo_dc3[i] & ldst_byteen_hi_dc2[i];
      assign ld_byte_dc3hit_hi_lo[i] = ld_addr_dc3hit_hi_lo & ldst_byteen_hi_dc3[i] & ldst_byteen_lo_dc2[i];
      assign ld_byte_dc3hit_hi_hi[i] = ld_addr_dc3hit_hi_hi & ldst_byteen_hi_dc3[i] & ldst_byteen_hi_dc2[i];

      assign ld_byte_dc4hit_lo_lo[i] = ld_addr_dc4hit_lo_lo & ldst_byteen_lo_dc4[i] & ldst_byteen_lo_dc2[i];
      assign ld_byte_dc4hit_lo_hi[i] = ld_addr_dc4hit_lo_hi & ldst_byteen_lo_dc4[i] & ldst_byteen_hi_dc2[i];
      assign ld_byte_dc4hit_hi_lo[i] = ld_addr_dc4hit_hi_lo & ldst_byteen_hi_dc4[i] & ldst_byteen_lo_dc2[i];
      assign ld_byte_dc4hit_hi_hi[i] = ld_addr_dc4hit_hi_hi & ldst_byteen_hi_dc4[i] & ldst_byteen_hi_dc2[i];

      assign ld_byte_dc5hit_lo_lo[i] = ld_addr_dc5hit_lo_lo & ldst_byteen_lo_dc5[i] & ldst_byteen_lo_dc2[i];
      assign ld_byte_dc5hit_lo_hi[i] = ld_addr_dc5hit_lo_hi & ldst_byteen_lo_dc5[i] & ldst_byteen_hi_dc2[i];
      assign ld_byte_dc5hit_hi_lo[i] = ld_addr_dc5hit_hi_lo & ldst_byteen_hi_dc5[i] & ldst_byteen_lo_dc2[i];
      assign ld_byte_dc5hit_hi_hi[i] = ld_addr_dc5hit_hi_hi & ldst_byteen_hi_dc5[i] & ldst_byteen_hi_dc2[i];

      assign ld_byte_hit_lo[i] = ld_byte_dc3hit_lo_lo[i] | ld_byte_dc3hit_hi_lo[i] |
                                 ld_byte_dc4hit_lo_lo[i] | ld_byte_dc4hit_hi_lo[i] |
                                 ld_byte_dc5hit_lo_lo[i] | ld_byte_dc5hit_hi_lo[i] |
                                 ld_byte_hit_wrbuf_lo[i] |
                                 ld_hit_rdbuf_lo;
      assign ld_byte_hit_hi[i] = ld_byte_dc3hit_lo_hi[i] | ld_byte_dc3hit_hi_hi[i] |
                                 ld_byte_dc4hit_lo_hi[i] | ld_byte_dc4hit_hi_hi[i] |
                                 ld_byte_dc5hit_lo_hi[i] | ld_byte_dc5hit_hi_hi[i] |
                                 ld_byte_hit_wrbuf_hi[i] |
                                 ld_hit_rdbuf_hi;

      assign ld_byte_dc3hit_lo[i] = ld_byte_dc3hit_lo_lo[i] | ld_byte_dc3hit_hi_lo[i];
      assign ld_byte_dc4hit_lo[i] = ld_byte_dc4hit_lo_lo[i] | ld_byte_dc4hit_hi_lo[i];
      assign ld_byte_dc5hit_lo[i] = ld_byte_dc5hit_lo_lo[i] | ld_byte_dc5hit_hi_lo[i];

      assign ld_byte_dc3hit_hi[i] = ld_byte_dc3hit_lo_hi[i] | ld_byte_dc3hit_hi_hi[i];
      assign ld_byte_dc4hit_hi[i] = ld_byte_dc4hit_lo_hi[i] | ld_byte_dc4hit_hi_hi[i];
      assign ld_byte_dc5hit_hi[i] = ld_byte_dc5hit_lo_hi[i] | ld_byte_dc5hit_hi_hi[i];

      assign ld_fwddata_dc3pipe_lo[(8*i)+7:(8*i)] = ({8{ld_byte_dc3hit_lo_lo[i]}} & store_data_lo_dc3[(8*i)+7:(8*i)]) |
                                                    ({8{ld_byte_dc3hit_hi_lo[i]}} & store_data_hi_dc3[(8*i)+7:(8*i)]);
      assign ld_fwddata_dc4pipe_lo[(8*i)+7:(8*i)] = ({8{ld_byte_dc4hit_lo_lo[i]}} & store_data_lo_dc4[(8*i)+7:(8*i)]) |
                                                    ({8{ld_byte_dc4hit_hi_lo[i]}} & store_data_hi_dc4[(8*i)+7:(8*i)]);
      assign ld_fwddata_dc5pipe_lo[(8*i)+7:(8*i)] = ({8{ld_byte_dc5hit_lo_lo[i]}} & store_data_lo_dc5[(8*i)+7:(8*i)]) |
                                                    ({8{ld_byte_dc5hit_hi_lo[i]}} & store_data_hi_dc5[(8*i)+7:(8*i)]);

      assign ld_fwddata_dc3pipe_hi[(8*i)+7:(8*i)] = ({8{ld_byte_dc3hit_lo_hi[i]}} & store_data_lo_dc3[(8*i)+7:(8*i)]) |
                                                    ({8{ld_byte_dc3hit_hi_hi[i]}} & store_data_hi_dc3[(8*i)+7:(8*i)]);
      assign ld_fwddata_dc4pipe_hi[(8*i)+7:(8*i)] = ({8{ld_byte_dc4hit_lo_hi[i]}} & store_data_lo_dc4[(8*i)+7:(8*i)]) |
                                                    ({8{ld_byte_dc4hit_hi_hi[i]}} & store_data_hi_dc4[(8*i)+7:(8*i)]);
      assign ld_fwddata_dc5pipe_hi[(8*i)+7:(8*i)] = ({8{ld_byte_dc5hit_lo_hi[i]}} & store_data_lo_dc5[(8*i)+7:(8*i)]) |
                                                    ({8{ld_byte_dc5hit_hi_hi[i]}} & store_data_hi_dc5[(8*i)+7:(8*i)]);

      // Final muxing between dc3/dc4/dc5
      assign ld_fwddata_lo[(8*i)+7:(8*i)] = ld_byte_dc3hit_lo[i]    ? ld_fwddata_dc3pipe_lo[(8*i)+7:(8*i)] :
                                            ld_byte_dc4hit_lo[i]    ? ld_fwddata_dc4pipe_lo[(8*i)+7:(8*i)] :
                                            ld_byte_dc5hit_lo[i]    ? ld_fwddata_dc5pipe_lo[(8*i)+7:(8*i)] :
                                            ld_byte_hit_wrbuf_lo[i] ? ld_fwddata_wrbuf_lo[(8*i)+7:(8*i)] :
                                                                      ld_fwddata_rdbuf_lo[(8*i)+7:(8*i)];
      
      assign ld_fwddata_hi[(8*i)+7:(8*i)] = ld_byte_dc3hit_hi[i]    ? ld_fwddata_dc3pipe_hi[(8*i)+7:(8*i)] :
                                            ld_byte_dc4hit_hi[i]    ? ld_fwddata_dc4pipe_hi[(8*i)+7:(8*i)] :
                                            ld_byte_dc5hit_hi[i]    ? ld_fwddata_dc5pipe_hi[(8*i)+7:(8*i)] :
                                            ld_byte_hit_wrbuf_hi[i] ? ld_fwddata_wrbuf_hi[(8*i)+7:(8*i)] :
                                                                      ld_fwddata_rdbuf_hi[(8*i)+7:(8*i)];

   end

   always_comb begin 
      ld_full_hit_lo_dc2 = 1'b1;
      ld_full_hit_hi_dc2 = 1'b1;
      for (int i=0; i<8; i++) begin
         ld_full_hit_lo_dc2 &= (ld_byte_hit_lo[i] | ~ldst_byteen_lo_dc2[i]);
         ld_full_hit_hi_dc2 &= (ld_byte_hit_hi[i] | ~ldst_byteen_hi_dc2[i]);
      end
   end

   // This will be high if atleast one byte hit the stores in pipe/write buffer (dc3/dc4/dc5/wrbuf)
   assign ld_hit_dc2 = (|ld_byte_hit_lo[7:0]) | (|ld_byte_hit_hi[7:0]);

   // This will be high if all the bytes of load hit the stores in pipe/write buffer (dc3/dc4/dc5/wrbuf)
   assign ld_full_hit_dc2 = ld_full_hit_lo_dc2 & ld_full_hit_hi_dc2 & lsu_busreq_dc2 & lsu_pkt_dc2.load & ~is_sideeffects_dc2;

   // Blocks the loads till write buffer is empty if there is a partial hit
   assign lsu_read_buffer_block_dc2 = (lsu_busreq_dc2 & ld_hit_dc2 & ~ld_full_hit_dc2) | is_sideeffects_dc2 | dec_tlu_ld_miss_byp_wb_disable; // Block the load if not full hit
   //assign lsu_read_buffer_block_dc2 = (lsu_busreq_dc2 & ld_hit_dc2 & ~ld_full_hit_dc2) | is_sideeffects_dc2 | dec_tlu_ld_miss_byp_wb_disable; // Block the load if not full hit

   assign {ld_fwddata_dc2_nc[127:32], ld_fwddata_dc2[31:0]} = {ld_fwddata_hi[63:0], ld_fwddata_lo[63:0]} >> (8*lsu_addr_dc2[2:0]);
   assign bus_read_data_dc3[31:0]                           = ld_full_hit_dc3 ? ld_fwddata_dc3[31:0] : ld_read_buffer_data_dc3[31:0];
	    
   // Fifo flops
   rvdff #(.WIDTH(1)) lsu_full_hit_dc3ff (.din(ld_full_hit_dc2), .dout(ld_full_hit_dc3), .clk(lsu_freeze_c2_dc3_clk), .*);
   rvdff #(.WIDTH(32)) lsu_fwddata_dc3ff (.din(ld_fwddata_dc2[31:0]), .dout(ld_fwddata_dc3[31:0]), .clk(lsu_c1_dc3_clk), .*);

   rvdff #(.WIDTH(1)) clken_ff (.din(lsu_bus_clk_en), .dout(lsu_bus_clk_en_q), .clk(lsu_free_c2_clk), .*);

   rvdff #(.WIDTH(1)) ldst_dual_dc2ff (.din(ldst_dual_dc1), .dout(ldst_dual_dc2), .clk(lsu_freeze_c1_dc2_clk), .*);
   rvdff #(.WIDTH(1)) ldst_dual_dc3ff (.din(ldst_dual_dc2), .dout(ldst_dual_dc3), .clk(lsu_freeze_c1_dc3_clk),  .*);
   rvdff #(.WIDTH(1)) ldst_dual_dc4ff (.din(ldst_dual_dc3), .dout(ldst_dual_dc4), .clk(lsu_c1_dc4_clk), .*);
   rvdff #(.WIDTH(1)) ldst_dual_dc5ff (.din(ldst_dual_dc4), .dout(ldst_dual_dc5), .clk(lsu_c1_dc5_clk), .*);
   rvdff #(.WIDTH(1)) is_sideeffects_dc4ff (.din(is_sideeffects_dc3), .dout(is_sideeffects_dc4), .clk(lsu_c1_dc4_clk), .*);
   rvdff #(.WIDTH(1)) is_sideeffects_dc5ff (.din(is_sideeffects_dc4), .dout(is_sideeffects_dc5), .clk(lsu_c1_dc5_clk), .*);

   rvdff #(4) lsu_byten_dc3ff (.*, .din(ldst_byteen_dc2[3:0]), .dout(ldst_byteen_dc3[3:0]), .clk(lsu_freeze_c1_dc3_clk));
   rvdff #(4) lsu_byten_dc4ff (.*, .din(ldst_byteen_dc3[3:0]), .dout(ldst_byteen_dc4[3:0]), .clk(lsu_c1_dc4_clk));
   rvdff #(4) lsu_byten_dc5ff (.*, .din(ldst_byteen_dc4[3:0]), .dout(ldst_byteen_dc5[3:0]), .clk(lsu_c1_dc5_clk));
 
`ifdef ASSERT_ON
   // Assertion to check ld imprecise error comes with right address
   property lsu_ld_imprecise_error_check;
      @(posedge clk) disable iff (~rst_l) lsu_imprecise_error_load_any |-> (lsu_imprecise_error_addr_any[31:0] == ld_imprecise_bus_error_addr[31:0]);
   endproperty
   assert_ld_imprecise_error_check: assert property (lsu_ld_imprecise_error_check) else
     $display("Wrong imprecise error address when lsu_imprecise_error_load_any asserted");

   // Assertion to check st imprecise error comes with right address
   property lsu_st_imprecise_error_check;
      @(posedge clk) disable iff (~rst_l) lsu_imprecise_error_store_any |-> (lsu_imprecise_error_addr_any[31:0] == store_bus_error_addr[31:0]);
   endproperty
   assert_st_imprecise_error_check: assert property (lsu_st_imprecise_error_check) else
     $display("Wrong imprecise error address when lsu_imprecise_error_store_any asserted");

   // Assertion to check AXI write address is aligned to size
   property lsu_axi_write_trxn_aligned;
     @(posedge lsu_busm_clk) disable iff(~rst_l) lsu_axi_awvalid  |-> ((lsu_axi_awsize[2:0] == 3'h0)                                  |
                                                  ((lsu_axi_awsize[2:0] == 3'h1) & (lsu_axi_awaddr[0] == 1'b0))   |
                                                  ((lsu_axi_awsize[2:0] == 3'h2) & (lsu_axi_awaddr[1:0] == 2'b0)) |
                                                  ((lsu_axi_awsize[2:0] == 3'h3) & (lsu_axi_awaddr[2:0] == 3'b0)));
   endproperty
   assert_lsu_write_trxn_aligned: assert property (lsu_axi_write_trxn_aligned) else 
     $display("Assertion lsu_axi_write_trxn_aligned failed: lsu_axi_awvalid=1'b%b, lsu_axi_awsize=3'h%h, lsu_axi_awaddr=32'h%h",lsu_axi_awvalid, lsu_axi_awsize[2:0], lsu_axi_awaddr[31:0]);
   
   // Assertion to check AXI read address is aligned to size
   property lsu_axi_read_trxn_aligned;
     @(posedge lsu_busm_clk) disable iff(~rst_l) lsu_axi_arvalid  |-> ((lsu_axi_arsize[2:0] == 3'h0)                                  |
                                                  ((lsu_axi_arsize[2:0] == 3'h1) & (lsu_axi_araddr[0] == 1'b0))   |
                                                  ((lsu_axi_arsize[2:0] == 3'h2) & (lsu_axi_araddr[1:0] == 2'b0)) |
                                                  ((lsu_axi_arsize[2:0] == 3'h3) & (lsu_axi_araddr[2:0] == 3'b0)));
   endproperty
   assert_lsu_read_trxn_aligned: assert property (lsu_axi_read_trxn_aligned) else 
     $display("Assertion lsu_axi_read_trxn_aligned failed: lsu_axi_arvalid=1'b%b, lsu_axi_arsize=3'h%h, lsu_axi_araddr=32'h%h",lsu_axi_arvalid, lsu_axi_arsize[2:0], lsu_axi_araddr[31:0]);
   
   // Assertion to check cmd valid stays stable during entire bus clock
   property lsu_axi_awvalid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_awvalid != $past(lsu_axi_awvalid)) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_awvalid_stable: assert property (lsu_axi_awvalid_stable) else
      $display("LSU AXI  awvalid changed in middle of bus clock");

   // Assertion to check cmd tag stays stable during entire bus clock
   property lsu_axi_awid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_awvalid & (lsu_axi_awid[LSU_BUS_TAG-1:0] != $past(lsu_axi_awid[LSU_BUS_TAG-1:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_awid_stable: assert property (lsu_axi_awid_stable) else
      $display("LSU AXI awid changed in middle of bus clock");

   // Assertion to check cmd addr stays stable during entire bus clock
   property lsu_axi_awaddr_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_awvalid & (lsu_axi_awaddr[31:0] != $past(lsu_axi_awaddr[31:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_awaddr_stable: assert property (lsu_axi_awaddr_stable) else
      $display("LSU AXI awaddr changed in middle of bus clock");

   // Assertion to check cmd length stays stable during entire bus clock
   property lsu_axi_awsize_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_awvalid & (lsu_axi_awsize[2:0] != $past(lsu_axi_awsize[2:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_awsize_stable: assert property (lsu_axi_awsize_stable) else
      $display("LSU AXI awsize changed in middle of bus clock");

   // Assertion to check cmd valid stays stable during entire bus clock
   property lsu_axi_wvalid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_wvalid != $past(lsu_axi_wvalid)) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_wvalid_stable: assert property (lsu_axi_wvalid_stable) else
      $display("LSU AXI  wvalid changed in middle of bus clock");

   // Assertion to check cmd wbe stays stable during entire bus clock
   property lsu_axi_wstrb_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_wvalid & (lsu_axi_wstrb[7:0] != $past(lsu_axi_wstrb[7:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_wstrb_stable: assert property (lsu_axi_wstrb_stable) else
      $display("LSU AXI wstrb changed in middle of bus clock");

   // Assertion to check cmd wdata stays stable during entire bus clock
   property lsu_axi_wdata_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_wvalid & (lsu_axi_wdata[63:0] != $past(lsu_axi_wdata[63:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_wdata_stable: assert property (lsu_axi_wdata_stable) else
      $display("LSU AXI wdata changed in middle of bus clock");

   // Assertion to check cmd valid stays stable during entire bus clock
   property lsu_axi_arvalid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_arvalid != $past(lsu_axi_arvalid)) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_arvalid_stable: assert property (lsu_axi_arvalid_stable) else
      $display("LSU AXI  arvalid changed in middle of bus clock");

   // Assertion to check cmd tag stays stable during entire bus clock
   property lsu_axi_arid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_arvalid & (lsu_axi_arid[LSU_BUS_TAG-1:0] != $past(lsu_axi_arid[LSU_BUS_TAG-1:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_arid_stable: assert property (lsu_axi_arid_stable) else
      $display("LSU AXI arid changed in middle of bus clock");

   // Assertion to check cmd addr stays stable during entire bus clock
   property lsu_axi_araddr_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_arvalid & (lsu_axi_araddr[31:0] != $past(lsu_axi_araddr[31:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_araddr_stable: assert property (lsu_axi_araddr_stable) else
      $display("LSU AXI araddr changed in middle of bus clock");

   // Assertion to check cmd length stays stable during entire bus clock
   property lsu_axi_arsize_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_arvalid & (lsu_axi_arsize[2:0] != $past(lsu_axi_arsize[2:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_arsize_stable: assert property (lsu_axi_arsize_stable) else
      $display("LSU AXI arsize changed in middle of bus clock");

   //Assertion to check write rsp valid stays stable during entire bus clock
   property lsu_axi_bvalid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_bvalid != $past(lsu_axi_bvalid)) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_bvalid_stable: assert property (lsu_axi_bvalid_stable) else
      $display("LSU AXI bvalid changed in middle of bus clock");

   //Assertion to check write rsp ready stays stable during entire bus clock
   property lsu_axi_bready_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_bready != $past(lsu_axi_bready)) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_bready_stable: assert property (lsu_axi_bready_stable) else
      $display("LSU AXI bready changed in middle of bus clock");

   //Assertion to check write rsp stays stable during entire bus clock
   property lsu_axi_bresp_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_bvalid & (lsu_axi_bresp[1:0] != $past(lsu_axi_bresp[1:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_bresp_stable: assert property (lsu_axi_bresp_stable) else
      $display("LSU AXI bvalid changed in middle of bus clock");

   // Assertion to check write rsp tag stays stable during entire bus clock
   property lsu_axi_bid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_awvalid & (lsu_axi_bid[LSU_BUS_TAG-1:0] != $past(lsu_axi_bid[LSU_BUS_TAG-1:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_bid_stable: assert property (lsu_axi_bid_stable) else
      $display("LSU AXI bid changed in middle of bus clock");

   //Assertion to check write rsp valid stays stable during entire bus clock
   property lsu_axi_rvalid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_rvalid != $past(lsu_axi_rvalid)) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_rvalid_stable: assert property (lsu_axi_rvalid_stable) else
      $display("LSU AXI bvalid changed in middle of bus clock");

   //Assertion to check write rsp ready stays stable during entire bus clock
   property lsu_axi_rready_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_rready != $past(lsu_axi_rready)) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_rready_stable: assert property (lsu_axi_rready_stable) else
      $display("LSU AXI bready changed in middle of bus clock");

   //Assertion to check write rsp stays stable during entire bus clock
   property lsu_axi_rresp_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_rvalid & (lsu_axi_rresp[1:0] != $past(lsu_axi_rresp[1:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_rresp_stable: assert property (lsu_axi_rresp_stable) else
      $display("LSU AXI bvalid changed in middle of bus clock");

   // Assertion to check write rsp tag stays stable during entire bus clock
   property lsu_axi_rid_stable;
      @(posedge clk) disable iff(~rst_l)  (lsu_axi_awvalid & (lsu_axi_rid[LSU_BUS_TAG-1:0] != $past(lsu_axi_rid[LSU_BUS_TAG-1:0]))) |-> $past(lsu_bus_clk_en);
   endproperty
   assert_lsu_axi_rid_stable: assert property (lsu_axi_rid_stable) else
      $display("LSU AXI bid changed in middle of bus clock");

`endif

endmodule // lsu_bus_intf
