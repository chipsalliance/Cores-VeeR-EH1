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
// Function: lsu to bus interface with interface queue
// Comments:
//
//********************************************************************************

// Function to get the length from byte enable
function automatic logic [1:0] get_wrbuf_size;
   input logic [7:0] byteen;

   logic [1:0]       size;

   if ((|byteen[3:0]) & (|byteen[7:4])) begin
      size[1:0] = 2'b11;
   end else if (|byteen[3:0]) begin
      if ((|byteen[3:2]) & (|byteen[1:0])) begin                                                                                     
         size[1:0] = 2'b10;
      end else begin
         size[1:0] = (|byteen[1:0]) ? ((&byteen[1:0]) ? 2'b01 : 2'b0) : ((&byteen[3:2]) ? 2'b01 : 2'b0);                                 
      end
   end else begin
      if ((|byteen[7:6]) & (|byteen[5:4])) begin                                                                                     
         size[1:0] = 2'b10;
      end else begin
         size[1:0] = (|byteen[5:4]) ? ((&byteen[5:4]) ? 2'b01 : 2'b0) : ((&byteen[7:6]) ? 2'b01 : 2'b0);                                 
      end
   end

   return size[1:0];   
endfunction // if

// Function to get the lower three bits of address
function automatic logic [2:0] get_wrbuf_addr;
   input logic [1:0] size;
   input logic [2:0] curr_addr;

   logic [2:0]       merged_addr;

   merged_addr[2:0] = {((size[1:0] != 2'b11) & curr_addr[2]),   // Gate addr bit 2 if size not DW
                       ((size[1]   != 1'b1) & curr_addr[1]),   // Gate addr bit 1 if size not DW/W
                       ((size[1:0] == 2'b0)  & curr_addr[0])};  // Gate addr bit 0 if size not DW/W/HW

   return merged_addr[2:0];
endfunction


module lsu_bus_write_buffer (
   input logic                          lsu_wrbuf_c1_clk,
   input logic                          lsu_freeze_c2_dc3_clk,
   input logic                          lsu_c2_dc4_clk,
   input logic                          lsu_c2_dc5_clk,
   input logic                          lsu_free_c2_clk,
   input logic                          lsu_busm_clk,
   input logic                          dec_tlu_wb_coalescing_disable,
   input logic                          clk, 
   input logic                          rst_l,

   input logic                          lsu_busreq_dc2,
   input lsu_pkt_t                      lsu_pkt_dc1,
   input lsu_pkt_t                      lsu_pkt_dc2,
   input lsu_pkt_t                      lsu_pkt_dc3,
   input lsu_pkt_t                      lsu_pkt_dc5,
   input logic [31:0]                   lsu_addr_dc2,
   input logic [31:0]                   end_addr_dc2,
   input logic [31:0]                   lsu_addr_dc5,
   input logic [31:0]                   end_addr_dc5,
   input logic [3:0]                    ldst_byteen_dc5,
   input logic [31:0]                   store_data_dc5, // only need lower 32 bits though
   input logic                          is_sideeffects_dc5,
   input logic                          lsu_commit_dc5,
   input logic                          is_aligned_dc5,
   input logic                          lsu_freeze_dc3,
   //input logic                          read_buffer_stall,
   input logic                          write_buffer_block_any,       // Block the write buffer if there are outstanding non-blocking loads
   input logic                          lsu_read_buffer_empty_any,        // Used for clock enable
   input logic                          flush_dc2_up,
   input logic                          flush_dc3,
                             
   input logic                          ldst_dual_dc1,
   input logic                          ldst_dual_dc2,
   input logic                          ldst_dual_dc3,
   input logic                          ldst_dual_dc4,
   input logic                          ldst_dual_dc5,

   input logic [15:0]                   ldst_byteen_ext_dc2,
   input logic [15:0]                   ldst_byteen_ext_dc5,
 
   output logic                         store_freeze_dc3, 
   output logic                         lsu_stbusreq_dc5,
   output logic                         store_bus_error_any,
   output logic [31:0]                  store_bus_error_addr,
   output logic                         lsu_write_buffer_full_any,
   output logic                         lsu_write_buffer_empty_any,
			     
   output logic [7:0]                   ld_byte_hit_wrbuf_lo, ld_byte_hit_wrbuf_hi,
   output logic [63:0]                  ld_fwddata_wrbuf_lo, ld_fwddata_wrbuf_hi,
   
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

   input logic                          lsu_bus_clk_en,
   input logic                          lsu_bus_clk_en_q,
   input logic                          scan_mode

);

`include "global.h"
   
   // States for entries
   // For St: IDLE -> WAIT -> CMD -> RESP -> IDLE
   typedef enum logic [2:0] {IDLE=3'b000, WAIT=3'b001, CMD=3'b010, CMD_ADDR=3'b011, CMD_DATA=3'b100, RESP=3'b101} state_t;

   localparam DEPTH = LSU_WRBUF_DEPTH;
   localparam DEPTH_LOG2 = $clog2(DEPTH);
   localparam WATERMARK = 0;   // Not tested for anything other than 0 (will need fence to drain write buffer if it's non zero)
   
   state_t [DEPTH-1:0]       busfifo_state;
   state_t [DEPTH-1:0]       busfifo_nxtstate;
   logic [DEPTH-1:0]         busfifo_state_en;
   logic [DEPTH-1:0]         busfifo_bus_state_en;

   logic [DEPTH-1:0]         busfifo_wr_en;
   logic [DEPTH-1:0]         busfifo_data_en;
   logic [DEPTH-1:0][31:0]   busfifo_addr;
   logic [DEPTH-1:0][63:0]   busfifo_data;
   logic [DEPTH-1:0][7:0]    busfifo_byteen;
   logic [DEPTH-1:0][1:0]    busfifo_size;
   logic [DEPTH-1:0]         busfifo_sideeffects;
   
   logic [DEPTH-1:0][7:0]    busfifo_byteen_in;
   logic [DEPTH-1:0][1:0]    busfifo_size_in;
   logic [DEPTH-1:0][63:0]   busfifo_data_in;
   logic [DEPTH-1:0][31:0]   busfifo_addr_in;
   logic [DEPTH-1:0][31:0]   busfifo_addr_in_temp;
   //logic [DEPTH-1:0]         store_bus_error_vec;
   
   logic [DEPTH-1:0] 	     store_hitvec_hi_dc5, store_hitvec_lo_dc5;
   logic                     store_merge_hi_dc5, store_merge_lo_dc5, store_merge_all_dc5;
   logic                     store_busreq_hi_dc5, store_busreq_lo_dc5;
   
   logic [127:0]             store_data_ext_dc5;
   logic [63:0]              store_data_hi_dc5, store_data_lo_dc5;
   logic [7:0] 	             ldst_byteen_hi_dc5, ldst_byteen_lo_dc5;
   logic [7:0]               ldst_byteen_mask_lo_dc5;
   
   logic [7:0]             ldst_byteen_hi_dc2, ldst_byteen_lo_dc2;
   logic [DEPTH-1:0]       ld_addr_hitvec_lo, ld_addr_hitvec_hi;
   logic [DEPTH-1:0][7:0]  ld_byte_hitvec_lo, ld_byte_hitvec_hi;
   logic [DEPTH-1:0][63:0] ld_fwddatavec_lo, ld_fwddatavec_hi;

   logic                     lsu_stbusreq_dc2, lsu_stbusreq_dc3, lsu_stbusreq_dc4;

   logic                     CmdPtrEn, WrPtrEn;
   logic [DEPTH_LOG2-1:0]    WrPtr, WrPtrPlus1, WrPtrPlus2, NxtWrPtr;
   logic [DEPTH_LOG2-1:0]    WrPtrLo, WrPtrHi;
   logic [DEPTH_LOG2-1:0]    CmdPtr, CmdPtrQ;
   logic [DEPTH_LOG2-1:0]    RspPtr;

   logic                     found;
   logic [DEPTH-1:0]         wrbuf_avl_any;
   logic [3:0]               wrbuf_numvld_any, wrbuf_numvld_anyQ;
   logic [3:0] 	             wrbuf_specvld_any;
   logic [1:0] 	             wrbuf_specvld_dc1, wrbuf_specvld_dc2, wrbuf_specvld_dc3, wrbuf_specvld_dc4, wrbuf_specvld_dc5;
   
   logic                     store_freeze_en, store_freeze_rst;

   logic                     lsu_axi_awvalid_q, lsu_axi_awready_q;
   logic                     lsu_axi_wvalid_q, lsu_axi_wready_q;
   logic                     lsu_axi_bvalid_q, lsu_axi_bready_q;
   logic [LSU_BUS_TAG-1:0]   lsu_axi_bid_q;
   logic [1:0]               lsu_axi_bresp_q;
   logic [1:0] 		     store_bus_error_lo;
   logic [1:0] 		     store_bus_error_lw;
   logic [1:0] 		     store_bus_error_uw;
   

   //assign store_data_ext_dc5[127:0] = {96'b0, store_data_dc5[31:0]} << {8*lsu_addr_dc5[2:0]};
   assign store_data_ext_dc5[127:0] = {96'b0, store_data_dc5[31:0]} << {lsu_addr_dc5[2:0],3'b0};
   assign store_data_hi_dc5[63:0]   = store_data_ext_dc5[127:64];
   assign store_data_lo_dc5[63:0]   = store_data_ext_dc5[63:0];
   assign ldst_byteen_hi_dc5[7:0]   = ldst_byteen_ext_dc5[15:8];
   assign ldst_byteen_lo_dc5[7:0]   = ldst_byteen_ext_dc5[7:0];

   assign ldst_byteen_mask_lo_dc5[7:0] = 8'hff << lsu_addr_dc5[2:0];

   
   // Hit logic for coalescing
   assign store_merge_hi_dc5 = 1'b0;  //|store_hitvec_hi_dc5[DEPTH-1:0];

   assign store_merge_lo_dc5 = |store_hitvec_lo_dc5[DEPTH-1:0];
   assign store_busreq_hi_dc5 = lsu_stbusreq_dc5 & lsu_commit_dc5 & ldst_dual_dc5;
   assign store_busreq_lo_dc5 = lsu_stbusreq_dc5 & lsu_commit_dc5;
   assign store_merge_all_dc5 = (store_busreq_lo_dc5 & store_merge_lo_dc5) & (~store_busreq_hi_dc5 | store_merge_hi_dc5);
   for (genvar i=0; i<DEPTH; i++) begin
      // Entry shouldn't coalesce if it's draining. Only coalescing no overwrite
      // Coalescing is done only to the last entry and only to top bytes (so done only for lo entry)
      assign store_hitvec_hi_dc5[i] = '0;
      assign store_hitvec_lo_dc5[i] = (lsu_addr_dc5[31:3] == busfifo_addr[i][31:3]) & ~(|(busfifo_byteen[i][7:0] & ldst_byteen_mask_lo_dc5[7:0])) & ~dec_tlu_wb_coalescing_disable & ~is_sideeffects_dc5 &
        			      ((busfifo_state[i] == WAIT)| (busfifo_state[i] == CMD)) & (i != CmdPtr[DEPTH_LOG2-1:0]) & (i != CmdPtrQ[DEPTH_LOG2-1:0]) & lsu_stbusreq_dc5 & lsu_commit_dc5;
   end
   
   // Generate the busfifo inputs
   always_comb begin
      for (int i=0; i<DEPTH; i++) begin
         busfifo_byteen_in[i] = '0;
         busfifo_size_in[i] = '0;
         busfifo_addr_in_temp[i]  = '0;
         busfifo_addr_in[i]  = '0;
	 
         // Non-coalescing case
         if ((DEPTH_LOG2'(i) == WrPtrLo) & ~store_merge_lo_dc5) begin
            busfifo_byteen_in[i][7:0] = ldst_byteen_ext_dc5[7:0];
            busfifo_addr_in_temp[i][31:0]  = lsu_addr_dc5[31:0];
         end else if ((DEPTH_LOG2'(i) == WrPtrHi) & ~store_merge_hi_dc5) begin
            busfifo_byteen_in[i][7:0] = ldst_byteen_ext_dc5[15:8];
            busfifo_addr_in_temp[i][31:0]  = end_addr_dc5[31:0];
         end     

         // Coalescing case
	 if (store_hitvec_hi_dc5[i]) begin
            busfifo_byteen_in[i][7:0] = busfifo_byteen[i][7:0] | ldst_byteen_hi_dc5[7:0];  // Merge existing byteen with coming store
            busfifo_addr_in_temp[i][31:0]  = end_addr_dc5[31:0];                                // Overwrite the address
	 end 
         else if (store_hitvec_lo_dc5[i]) begin
            busfifo_byteen_in[i][7:0] = busfifo_byteen[i][7:0] | ldst_byteen_lo_dc5[7:0];  // Merge existing byteen with coming store
            busfifo_addr_in_temp[i][31:0]  = lsu_addr_dc5[31:0];                                // Overwrite the address 
	 end

         busfifo_size_in[i][1:0]   = get_wrbuf_size(busfifo_byteen_in[i]);
         busfifo_addr_in[i][31:0]  = {busfifo_addr_in_temp[i][31:3], get_wrbuf_addr(busfifo_size_in[i], busfifo_addr_in_temp[i][2:0])};
      end 
   end

   // Generate the busfifo data input for coalescing and non-coalescing
   for (genvar i=0; i<DEPTH; i++) begin
      for (genvar j=0; j<8; j++) begin
         assign busfifo_data_in[i][(8*j)+7:(8*j)] = ((store_hitvec_hi_dc5[i] | (i == WrPtrHi)) & ldst_byteen_hi_dc5[j]) ? store_data_hi_dc5[(8*j)+7:(8*j)] :
						    ((store_hitvec_lo_dc5[i] | (i == WrPtrLo)) & ldst_byteen_lo_dc5[j]) ? store_data_lo_dc5[(8*j)+7:(8*j)] :
                                                                                                                          busfifo_data[i][(8*j)+7:(8*j)];
      end
   end

   // Write Buffer hit logic. Used to block the bus loads behind the writes
   assign ldst_byteen_hi_dc2[7:0]   = ldst_byteen_ext_dc2[15:8];
   assign ldst_byteen_lo_dc2[7:0]   = ldst_byteen_ext_dc2[7:0];
   for (genvar i=0; i<DEPTH; i++) begin
      assign ld_addr_hitvec_lo[i] = (lsu_addr_dc2[31:3] == busfifo_addr[i][31:3]) & (busfifo_state[i] != IDLE) & lsu_busreq_dc2;
      assign ld_addr_hitvec_hi[i] = (end_addr_dc2[31:3] == busfifo_addr[i][31:3]) & (busfifo_state[i] != IDLE) & lsu_busreq_dc2;
      //assign ld_addr_hitvec_lo[i] = (lsu_addr_dc2[31:3] == busfifo_addr[i][31:3]) & ((busfifo_state[i] == WAIT) | (busfifo_state[i] == CMD)) & lsu_busreq_dc2;
      //assign ld_addr_hitvec_hi[i] = (end_addr_dc2[31:3] == busfifo_addr[i][31:3]) & ((busfifo_state[i] == WAIT) | (busfifo_state[i] == CMD)) & lsu_busreq_dc2;
      for (genvar j=0; j<8; j++) begin
         assign ld_byte_hitvec_lo[i][j] = ld_addr_hitvec_lo[i] & busfifo_byteen[i][j] & ldst_byteen_lo_dc2[j];
         assign ld_byte_hitvec_hi[i][j] = ld_addr_hitvec_hi[i] & busfifo_byteen[i][j] & ldst_byteen_hi_dc2[j];

         assign ld_fwddatavec_lo[i][(8*j)+7:(8*j)] = {8{ld_byte_hitvec_lo[i][j]}} & busfifo_data[i][(8*j)+7:(8*j)];
         assign ld_fwddatavec_hi[i][(8*j)+7:(8*j)] = {8{ld_byte_hitvec_hi[i][j]}} & busfifo_data[i][(8*j)+7:(8*j)];
      end
   end

   // Final fwd byte hit
   always_comb begin
      ld_byte_hit_wrbuf_lo[7:0] = '0;
      ld_byte_hit_wrbuf_hi[7:0] = '0;
      for (int i=0; i<DEPTH; i++) begin
         ld_byte_hit_wrbuf_lo[7:0] |= ld_byte_hitvec_lo[i];
         ld_byte_hit_wrbuf_hi[7:0] |= ld_byte_hitvec_hi[i];
      end
   end

   // Final fwd data
   always_comb begin
      ld_fwddata_wrbuf_lo[63:0] = '0;
      ld_fwddata_wrbuf_hi[63:0] = '0;
      for (int i=0; i<DEPTH; i++) begin
         // Byte0
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][0]) begin
            ld_fwddata_wrbuf_hi[7:0] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][7:0];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][0]) begin
            ld_fwddata_wrbuf_lo[7:0] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][7:0];
	 end

         // Byte1
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][1]) begin
            ld_fwddata_wrbuf_hi[15:8] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][15:8];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][1]) begin
            ld_fwddata_wrbuf_lo[15:8] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][15:8];
	 end

         // Byte2
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][2]) begin
            ld_fwddata_wrbuf_hi[23:16] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][23:16];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][2]) begin
            ld_fwddata_wrbuf_lo[23:16] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][23:16];
	 end

         // Byte3
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][3]) begin
            ld_fwddata_wrbuf_hi[31:24] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][31:24];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][3]) begin
            ld_fwddata_wrbuf_lo[31:24] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][31:24];
	 end

         // Byte4
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][4]) begin
            ld_fwddata_wrbuf_hi[39:32] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][39:32];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][4]) begin
            ld_fwddata_wrbuf_lo[39:32] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][39:32];
	 end

         // Byte5
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][5]) begin
            ld_fwddata_wrbuf_hi[47:40] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][47:40];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][5]) begin
            ld_fwddata_wrbuf_lo[47:40] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][47:40];
	 end

         // Byte6
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][6]) begin
            ld_fwddata_wrbuf_hi[55:48] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][55:48];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][6]) begin
            ld_fwddata_wrbuf_lo[55:48] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][55:48];
	 end

         // Byte7
         if (ld_byte_hitvec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][7]) begin
            ld_fwddata_wrbuf_hi[63:56] = ld_fwddatavec_hi[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][63:56];
	 end
         if (ld_byte_hitvec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][7]) begin
            ld_fwddata_wrbuf_lo[63:56] = ld_fwddatavec_lo[DEPTH_LOG2'(WrPtr[DEPTH_LOG2-1:0] + DEPTH_LOG2'(i))][63:56];
	 end

      end
   end
   

   // Update the WrPtr logic
   // Don't update the WrPtr for both hi/lo coalesce since we will not write a new entry only coalesce to existing one
   assign WrPtrEn = (lsu_stbusreq_dc5 & lsu_commit_dc5) & ~store_merge_all_dc5;
   assign NxtWrPtr[DEPTH_LOG2-1:0] = (lsu_stbusreq_dc5 & ldst_dual_dc5 & ~(store_merge_lo_dc5 | store_merge_hi_dc5)) ? WrPtrPlus2[DEPTH_LOG2-1:0] : 
                                                                                                                       WrPtrPlus1[DEPTH_LOG2-1:0];
   assign WrPtrLo[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0];
   assign WrPtrHi[DEPTH_LOG2-1:0] = (store_merge_lo_dc5 | store_merge_hi_dc5) ? WrPtr[DEPTH_LOG2-1:0] : WrPtrPlus1[DEPTH_LOG2-1:0];
   assign WrPtrPlus1[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0] + 1'b1;
   assign WrPtrPlus2[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0] + 2'b10;

   assign CmdPtrEn                = ((busfifo_state[CmdPtrQ] == CMD) | (busfifo_state[CmdPtrQ] == CMD_ADDR) | (busfifo_state[CmdPtrQ] == CMD_DATA)) & busfifo_bus_state_en[CmdPtrQ] & (busfifo_nxtstate[CmdPtrQ] == RESP); 
   assign CmdPtr[DEPTH_LOG2-1:0]  = CmdPtrEn  ? (CmdPtrQ[DEPTH_LOG2-1:0] +  1'b1) : CmdPtrQ[DEPTH_LOG2-1:0];
    
   assign lsu_axi_awvalid                = ((busfifo_state[CmdPtr] == CMD) | (busfifo_state[CmdPtr] == CMD_ADDR)) & ~(busfifo_bus_state_en[CmdPtr] & (busfifo_nxtstate[CmdPtr] == CMD_DATA));
   assign lsu_axi_awid[LSU_BUS_TAG-1:0]  = LSU_BUS_TAG'(CmdPtr);
   assign lsu_axi_awaddr[31:0]           = busfifo_addr[CmdPtr][31:0];
   assign lsu_axi_awsize[2:0]            = {1'b0,busfifo_size[CmdPtr][1:0]};
   assign lsu_axi_awcache[3:0]           = busfifo_sideeffects[CmdPtr] ? 4'b0 : 4'b1111; 
   assign lsu_axi_awprot[2:0]            = 3'b0;            
   assign lsu_axi_awregion[3:0]          = busfifo_addr[CmdPtr][31:28];
   assign lsu_axi_awlen[7:0]             = '0;
   assign lsu_axi_awburst[1:0]           = 2'b01;
   assign lsu_axi_awqos[3:0]             = '0;
   assign lsu_axi_awlock                 = '0;
   
   assign lsu_axi_wvalid                 = ((busfifo_state[CmdPtr] == CMD) | (busfifo_state[CmdPtr] == CMD_DATA)) & ~(busfifo_bus_state_en[CmdPtr] & (busfifo_nxtstate[CmdPtr] == CMD_ADDR));
   assign lsu_axi_wdata[63:0]            = busfifo_data[CmdPtr];
   assign lsu_axi_wstrb[7:0]             = busfifo_byteen[CmdPtr];
   assign lsu_axi_wlast                  = '1;
   
   assign lsu_axi_bready                 = 1'b1;

   // Per entry FSM
   // Incoming bus signals are flopped before using. So, FSM transitions are a cycle late
   // FSM goes from DRAIN -> PEND after first command is sent
   // FSM stays in DRAIN for minimum 2 cycles since FSM looks at flopped bus signals
   // cmd_done/data_done stays high for exactly one cycle and data_pending stays high for the duration of last data sent after last command is sent
   for (genvar i=0; i<DEPTH; i++) begin
      
      always_comb begin
         busfifo_nxtstate[i] = IDLE;
         busfifo_bus_state_en[i] = '0;
	 
         case (busfifo_state[i])
            IDLE: begin
                     busfifo_nxtstate[i] = WAIT;

   	    end
            WAIT: begin
                     busfifo_nxtstate[i] = CMD;
            end
            CMD: begin
                      busfifo_nxtstate[i] = ((lsu_axi_awvalid_q & lsu_axi_awready_q) & (lsu_axi_wvalid_q & lsu_axi_wready_q)) ? RESP : (lsu_axi_awvalid_q & lsu_axi_awready_q) ? CMD_DATA : CMD_ADDR;
                      busfifo_bus_state_en[i] = (CmdPtrQ == i) & ((lsu_axi_awvalid_q & lsu_axi_awready_q) | (lsu_axi_wvalid_q & lsu_axi_wready_q));

   	    end
            CMD_ADDR: begin
                     busfifo_nxtstate[i] = RESP;
                     busfifo_bus_state_en[i] = (CmdPtrQ == i) & lsu_axi_awvalid_q & lsu_axi_awready_q;
             end
            CMD_DATA: begin
                     busfifo_nxtstate[i] = RESP;
                     busfifo_bus_state_en[i] = (CmdPtrQ == i) & lsu_axi_wvalid_q & lsu_axi_wready_q;
             end
            RESP: begin
                     busfifo_nxtstate[i] = IDLE;
                     busfifo_bus_state_en[i] = (lsu_axi_bid_q[LSU_BUS_TAG-1:0] == LSU_BUS_TAG'(i)) & lsu_axi_bvalid_q & lsu_axi_bready_q; 
    	    end
            default: begin
                      busfifo_nxtstate[i] = IDLE;
                      busfifo_bus_state_en[i] = '0;
            end
         endcase
      end

      always_comb begin
         busfifo_wr_en[i] = '0;
	 busfifo_state_en[i]  = '0;
         case (busfifo_state[i])
            IDLE: begin
                     busfifo_state_en[i] = lsu_stbusreq_dc5 & lsu_commit_dc5 & ~store_merge_all_dc5 & (((i == WrPtrLo) & ~store_merge_lo_dc5) | 
                                                                                                       ((i == WrPtrHi) & ldst_dual_dc5 & ~store_merge_hi_dc5));
	             busfifo_wr_en[i] = busfifo_state_en[i];
   	    end
            WAIT: begin
                     busfifo_state_en[i] = lsu_bus_clk_en;
                     busfifo_wr_en[i]    = (store_hitvec_lo_dc5[i] | store_hitvec_hi_dc5[i]);
            end
            CMD: begin
                     busfifo_state_en[i] = busfifo_bus_state_en[i] & lsu_bus_clk_en;
                     busfifo_wr_en[i]    = (store_hitvec_lo_dc5[i] | store_hitvec_hi_dc5[i]);
   	    end
            CMD_ADDR: begin
                     busfifo_state_en[i] = busfifo_bus_state_en[i] & lsu_bus_clk_en;
            end
            CMD_DATA: begin
                     busfifo_state_en[i] = busfifo_bus_state_en[i] & lsu_bus_clk_en;
            end
            RESP: begin
                     busfifo_state_en[i] = busfifo_bus_state_en[i] & lsu_bus_clk_en; 
   	    end
            default: begin
                     busfifo_wr_en[i] = '0;
                     busfifo_state_en[i]  = '0;
            end
         endcase
      end
  
      rvdffs #(.WIDTH(3)) busfifo_state_ff (.din(busfifo_nxtstate[i]), .dout({busfifo_state[i]}), .en(busfifo_state_en[i]), .clk(lsu_free_c2_clk), .*);
      rvdffe #(.WIDTH(32)) busfifo_addrff (.din(busfifo_addr_in[i]), .dout(busfifo_addr[i]), .en(busfifo_wr_en[i]), .*);
      rvdffs #(.WIDTH(8)) busfifo_byteenff (.din(busfifo_byteen_in[i]), .dout(busfifo_byteen[i]), .en(busfifo_wr_en[i]), .clk(lsu_wrbuf_c1_clk), .*);
      rvdffs #(.WIDTH(2)) busfifo_sizeff (.din(busfifo_size_in[i]), .dout(busfifo_size[i]), .en(busfifo_wr_en[i]), .clk(lsu_wrbuf_c1_clk), .*);
      rvdffs #(.WIDTH(1)) busfifo_sideeffectsff (.din(is_sideeffects_dc5), .dout(busfifo_sideeffects[i]), .en(busfifo_wr_en[i]), .clk(lsu_wrbuf_c1_clk), .*);
      rvdffe #(.WIDTH(64)) busfifo_dataff (.din(busfifo_data_in[i]), .dout(busfifo_data[i]), .en(busfifo_wr_en[i]), .*);
   end
   
   // Generate available entries for full checking
   always_comb begin
      wrbuf_avl_any[DEPTH-1:0] = '0;
      found = 0;
      for (int i=0; i<DEPTH; i++) begin
         found |= (busfifo_state[DEPTH_LOG2'(DEPTH_LOG2'(i)+WrPtr)] != IDLE);
         wrbuf_avl_any[DEPTH_LOG2'(DEPTH_LOG2'(i)+WrPtr)] = ~found;
      end 
   end

   // Write buffer full logic
   always_comb begin
      wrbuf_numvld_any[3:0] = '0;
      for (int i=0; i<DEPTH; i++) begin
         //wrbuf_numvld_any[4:0] += {4'b0, (busfifo_state[i] != IDLE)};
         wrbuf_numvld_any[3:0] += {3'b0, ~wrbuf_avl_any[i]};
      end
   end

   assign wrbuf_specvld_dc1[1:0] = {(lsu_pkt_dc1.valid & lsu_pkt_dc1.store), 1'b0};   // always count 2 speculatively. Timing for pointer chasing is showing up otherwise
   assign wrbuf_specvld_dc2[1:0] = {1'b0,lsu_stbusreq_dc2} << ldst_dual_dc2;
   assign wrbuf_specvld_dc3[1:0] = {1'b0,lsu_stbusreq_dc3} << ldst_dual_dc3;
   assign wrbuf_specvld_dc4[1:0] = {1'b0,lsu_stbusreq_dc4} << ldst_dual_dc4;
   assign wrbuf_specvld_dc5[1:0] = {1'b0,lsu_stbusreq_dc5} << ldst_dual_dc5;
   assign wrbuf_specvld_any[3:0] = wrbuf_numvld_any[3:0] +  {2'b0,wrbuf_specvld_dc1[1:0]} + {2'b0,wrbuf_specvld_dc2[1:0]} + {2'b0,wrbuf_specvld_dc3[1:0]} + {2'b0,wrbuf_specvld_dc4[1:0]} + {2'b0,wrbuf_specvld_dc5[1:0]};

   assign lsu_write_buffer_full_any = (wrbuf_specvld_any[3:0] > (DEPTH - 2)) | (busfifo_state[WrPtr] != IDLE);
   assign lsu_write_buffer_empty_any = ~((|busfifo_state[DEPTH-1:0]) | (lsu_stbusreq_dc3 & ~store_freeze_dc3) | lsu_stbusreq_dc4 | lsu_stbusreq_dc5);

   assign store_freeze_en = write_buffer_block_any & lsu_stbusreq_dc2 & ~flush_dc2_up & ~lsu_freeze_dc3;
   assign store_freeze_rst = flush_dc3 | (lsu_read_buffer_empty_any & store_freeze_dc3);
   
   //assign store_freeze_dc3 = 1'b0;
   assign lsu_stbusreq_dc2 = lsu_busreq_dc2 & lsu_pkt_dc2.store;
   //assign store_bus_error_any = |store_bus_error_vec[DEPTH-1:0]; The Error address needs to be re-computed based on the byteens and the address [31:2]
   assign RspPtr[DEPTH_LOG2-1:0]     = DEPTH_LOG2'(lsu_axi_bid_q[LSU_BUS_TAG-1:0]);
   assign store_bus_error_any        = lsu_axi_bvalid_q & lsu_axi_bready_q & lsu_axi_bresp_q[1] & lsu_bus_clk_en_q;
   assign store_bus_error_lw[1:0]    = busfifo_byteen[RspPtr][0] ? busfifo_addr[RspPtr][1:0] :  busfifo_byteen[RspPtr][1] ? 2'b01 : busfifo_byteen[RspPtr][2] ? 2'b10 : 2'b11; 
   assign store_bus_error_uw[1:0]    = busfifo_byteen[RspPtr][4] ? busfifo_addr[RspPtr][1:0] :  busfifo_byteen[RspPtr][5] ? 2'b01 : busfifo_byteen[RspPtr][6] ? 2'b10 : 2'b11;
   assign store_bus_error_lo[1:0]    = |busfifo_byteen[RspPtr][3:0] ? store_bus_error_lw[1:0] : store_bus_error_uw[1:0];   
   assign store_bus_error_addr[31:0] = {busfifo_addr[RspPtr][31:2], store_bus_error_lo[1:0]};
   
   // Fifo flops
   rvdffs #(.WIDTH(DEPTH_LOG2)) WrPtrff (.din(NxtWrPtr[DEPTH_LOG2-1:0]), .dout(WrPtr[DEPTH_LOG2-1:0]), .en(WrPtrEn), .clk(lsu_c2_dc5_clk), .*);
   rvdff #(.WIDTH(DEPTH_LOG2))  lsu_CmdPtrff (.din(CmdPtr[DEPTH_LOG2-1:0]), .dout(CmdPtrQ[DEPTH_LOG2-1:0]), .clk(lsu_busm_clk), .*);

   rvdff #(.WIDTH(1)) axi_awvalid_ff (.din(lsu_axi_awvalid), .dout(lsu_axi_awvalid_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_awready_ff (.din(lsu_axi_awready), .dout(lsu_axi_awready_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_wvalid_ff (.din(lsu_axi_wvalid), .dout(lsu_axi_wvalid_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_wready_ff (.din(lsu_axi_wready), .dout(lsu_axi_wready_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_bvalid_ff (.din(lsu_axi_bvalid), .dout(lsu_axi_bvalid_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_bready_ff (.din(lsu_axi_bready), .dout(lsu_axi_bready_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(2)) axi_bresp_ff (.din(lsu_axi_bresp), .dout(lsu_axi_bresp_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(LSU_BUS_TAG)) axi_bid_ff (.din(lsu_axi_bid), .dout(lsu_axi_bid_q), .clk(lsu_busm_clk), .*);

   rvdffsc #(.WIDTH(1)) store_freeze_dc3ff (.din(1'b1), .dout(store_freeze_dc3), .en(store_freeze_en), .clear(store_freeze_rst), .clk(lsu_free_c2_clk), .*);
   rvdff #(.WIDTH(4)) wrbuf_numvld_anyff (.din(wrbuf_numvld_any[3:0]), .dout(wrbuf_numvld_anyQ[3:0]), .clk(lsu_free_c2_clk), .*);
   rvdff #(.WIDTH(1)) lsu_stbusreq_dc3ff (.din(lsu_stbusreq_dc2), .dout(lsu_stbusreq_dc3), .clk(lsu_freeze_c2_dc3_clk), .*);
   rvdff #(.WIDTH(1)) lsu_stbusreq_dc4ff (.din(lsu_stbusreq_dc3 & ~store_freeze_dc3), .dout(lsu_stbusreq_dc4), .clk(lsu_free_c2_clk), .*);
   rvdff #(.WIDTH(1)) lsu_stbusreq_dc5ff (.din(lsu_stbusreq_dc4), .dout(lsu_stbusreq_dc5), .clk(lsu_free_c2_clk), .*);

`ifdef ASSERT_ON

   property hitvec_when_nomerging;
      @(posedge clk) disable iff(~rst_l) dec_tlu_wb_coalescing_disable |-> ((store_hitvec_lo_dc5[DEPTH-1:0] == 'b0) & (store_hitvec_hi_dc5[DEPTH-1:0] == 'b0));
   endproperty
   assert_hitvec_when_nomerging: assert property (hitvec_when_nomerging);

`endif

endmodule // lsu_bus_write_buffer
