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
function automatic logic [31:0] lsu_align;
   input logic [31:0] data0;
   input logic [63:0] data1;
   input logic        data_sel;
   input logic [2:0]  addr;
   input logic [1:0]  size;
   input logic        unsign;

   logic [95:0]       data_int;
   logic [31:0]       data_out;
   logic [2:0]        shift;
   
   shift[2:0]     = data_sel ? {1'b0,addr[1:0]} : addr[2:0];   // This is need since we already save either upper/lower word for dual
   data_int[95:0] = (data_sel ? {data1[63:0], data0[31:0]} : {data0[31:0], data1[63:0]}) >> 8*shift[2:0];
   
   data_out[31:0] = ({32{ unsign & (size == 2'b00)}} & {24'b0,data_int[7:0]}) |
                    ({32{ unsign & (size == 2'b01)}} & {16'b0,data_int[15:0]}) |
                    ({32{~unsign & (size == 2'b00)}} & {{24{data_int[7]}}, data_int[7:0]}) |
                    ({32{~unsign & (size == 2'b01)}} & {{16{data_int[15]}},data_int[15:0]}) |
                    ({32{(size == 2'b10)}} & data_int[31:0]);
   return data_out[31:0]; 
   
endfunction // lsu_bus_read_buffer


module lsu_bus_read_buffer (

   input logic                  lsu_freeze_c2_dc3_clk,
   input logic                  lsu_c2_dc3_clk,                   // per stage clock 
   input logic                  lsu_c2_dc4_clk,                   // per stage clock 
   input logic                  lsu_c2_dc5_clk,                   // per stage clock 
   input logic                  lsu_rdbuf_c1_clk,                 // read_buf clock 
   input logic                  lsu_free_c2_clk,                  // lsu clock 
   input logic                  lsu_busm_clk,                     // bus clock 
   input logic                  clk,                              // core clock
   input logic                  rst_l,                            // reset

   input logic                  lsu_busreq_dc2,                   // ld/st in dc2 to the external
   input                        lsu_pkt_t lsu_pkt_dc2,            // lsu packet in dc2
   input                        lsu_pkt_t lsu_pkt_dc3,            // lsu packet in dc3
   input                        lsu_pkt_t lsu_pkt_dc5,            // lsu packet in dc5
   input logic                  ldst_dual_dc2,                    // packet in dc2 is unaligned
   input logic                  ldst_dual_dc3,                    // packet in dc3 is unaligned
   input logic [31:0]           lsu_addr_dc2,                     // address
   input logic [31:0]           end_addr_dc2,                     // ending address ( to calculate the banks ) 
   input logic [31:0]           lsu_addr_dc3,                     // start address in dc5
   input logic [31:0]           end_addr_dc3,                     // end address in dc5
   input logic                  addr_external_dc2,                // the address is mapping to external
   input logic                  lsu_read_buffer_block_dc2,        // block the read buffer - either because of a partial hit, or chicken bit set
   input logic                  is_sideeffects_dc2,
                            
   input logic                  lsu_freeze_dc3,                   // Final lsu freeze
   input logic                  lsu_commit_dc5,                   // Final qualified commit
   input logic                  lsu_write_buffer_empty_any,       // write buffer is empty
   input logic                  ld_full_hit_dc2,                  // load can get all its byte from a write buffer entry
   input logic                  is_sideeffects_dc3,
   input logic                  flush_dc2_up,                     // flush 
   input logic                  flush_dc3,                        // flush 
   input logic                  flush_dc4,                        // flush
   input logic                  flush_dc5,                        // flush

   output logic                 lsu_read_buffer_empty_any,        // Used for clock enable
   output logic                 write_buffer_block_any,           // Block the write buffer if there are outstanding non-blocking loads
   output logic                 lsu_ldbusreq_dc3,                 // pipe made it down to dc3 and is to external
   output logic                 lsu_ldbusreq_dc5,                 // pipe made it down to dc5 and is to external
   output logic                 ld_hit_rdbuf_hi,                  // load is unaligned and the upper hits
   output logic                 ld_hit_rdbuf_lo,                  // load us unaligned and the lower hits
   output logic [63:0]          ld_fwddata_rdbuf_hi,              // the fwd data 
   output logic [63:0]          ld_fwddata_rdbuf_lo,              // the fwd data
   output logic                 ld_freeze_dc3,                    // need to freeze as the load is to the external
   output logic                 rdbuf_full_freeze_dc3,            // Freeze in dc2 since read buffer is full
   output logic                 ld_bus_error_dc3,                 // Bus returns an precise error 
   output logic [31:0]          ld_bus_error_addr_dc3,            // Address for precise load error
   output logic                 ld_imprecise_bus_error_any,       // Bus returns an imprecise error 
   output logic [31:0]          ld_imprecise_bus_error_addr,
   output logic [31:0]          ld_read_buffer_data_dc3,          // the bus return data

   // Non-blocking loads
   input logic                                 dec_tlu_non_blocking_disable,
   input  logic 	                       dec_nonblock_load_freeze_dc2,
   output logic                                lsu_nonblock_load_valid_dc3,     // there is an external load -> put in the cam
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_dc3,       // the tag of the external non block load
   output logic                                lsu_nonblock_load_inv_dc5,       // invalidate signal for the cam entry for non block loads
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_dc5,   // tag of the enrty which needs to be invalidated
   output logic                                lsu_nonblock_load_data_valid,    // the non block is valid - sending information back to the cam                                               
   output logic                                lsu_nonblock_load_data_error,    // non block load has an error                 
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,      // the tag of the non block load sending the data/error                                             
   output logic [31:0]                         lsu_nonblock_load_data,          // Data of the non block load	

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
                                          
   input logic                          lsu_bus_clk_en,   
   input logic                          lsu_bus_clk_en_q, 
   input logic                          scan_mode                // scan mode

);

`include "global.h"

   // States for entries
   // For Ld: IDLE -> WAIT_COMMIT -> WAIT -> CMD -> RESP -> DONE -> IDLE
   typedef enum logic [2:0] {IDLE=3'b000, WAIT_COMMIT=3'b001, WAIT=3'b010, CMD=3'b011, RESP=3'b100, DONE=3'b101} state_t;
   
   localparam DEPTH     = `RV_LSU_NUM_NBLOAD;
   localparam DEPTH_LOG2 = `RV_LSU_NUM_NBLOAD_WIDTH;

   state_t [DEPTH-1:0]       busfifo_state;
   state_t [DEPTH-1:0]       busfifo_nxtstate;
   logic   [DEPTH-1:0]       busfifo_block;
   logic   [DEPTH-1:0]       busfifo_dual;
   logic   [DEPTH-1:0]       busfifo_nb;
   logic   [DEPTH-1:0]       busfifo_sideeffects;
   logic   [DEPTH-1:0]       busfifo_unsign;
   logic   [DEPTH-1:0][1:0]  busfifo_sz;
   logic   [DEPTH-1:0][1:0]  busfifo_sent;
   logic   [DEPTH-1:0][1:0]  busfifo_resp;
   logic   [DEPTH-1:0][1:0]  busfifo_error;
   logic   [DEPTH-1:0][31:0] busfifo_addr_lo;
   logic   [DEPTH-1:0][31:0] busfifo_addr_hi;
   logic   [DEPTH-1:0][31:0] busfifo_data;

   logic   [DEPTH-1:0]       busfifo_rst;
   logic   [DEPTH-1:0]       busfifo_block_rst;
   logic   [DEPTH-1:0]       busfifo_error_rst;
   logic   [DEPTH-1:0]       busfifo_state_en;
   logic   [DEPTH-1:0]       busfifo_state_bus_en;
   logic   [DEPTH-1:0]       busfifo_wr_en;
   logic   [DEPTH-1:0]       busfifo_cmd_sent;
   logic   [DEPTH-1:0]       busfifo_cmd_resp;
   logic   [DEPTH-1:0][1:0]  busfifo_sent_en;
   logic   [DEPTH-1:0][1:0]  busfifo_resp_en;
   logic   [DEPTH-1:0][1:0]  busfifo_error_en;
   logic   [DEPTH-1:0]       busfifo_data_en;
   logic   [DEPTH-1:0][31:0] busfifo_data_in;

   logic   [31:0]            busfifo_addr_lo_in;
   logic   [31:0]            busfifo_addr_hi_in;
   logic   [1:0]             busfifo_sz_in;
   
   logic                   lsu_ldbusreq_dc2, lsu_ldbusreq_dc4;
   logic                   WrPtrEn;
   logic [DEPTH_LOG2-1:0]  WrPtr, NxtWrPtr, WrPtr_dc3, WrPtr_dc4, WrPtr_dc5;
   logic [DEPTH_LOG2-1:0]  CmdPtr, NxtCmdPtr, CmdPtrQ;
   logic [DEPTH_LOG2-1:0]  FreezePtr;

   logic                   FreezePtrEn;   
   logic                   lsu_nonblock_load_valid_dc4, lsu_nonblock_load_valid_dc5;
   logic                   ld_freeze_en, ld_freeze_rst;
   logic                   rdbuf_full_freeze_en, rdbuf_full_freeze_rst;
   logic                   ld_precise_bus_error;
   logic                   read_buffer_full;
   
   logic [127:32]      ld_read_buffer_data_dc3_nc;

   logic               found0, found1;

   logic               dec_nonblock_load_freeze_dc3;
   logic               lsu_read_buffer_block_dc3;
   //assign dec_nonblock_load_freeze_dc2 = '0;
   
   logic               lsu_axi_arvalid_q, lsu_axi_arready_q;
   logic               lsu_axi_rvalid_q, lsu_axi_rready_q;
   logic [1:0]         lsu_axi_rresp_q;
   logic [LSU_BUS_TAG-1:0] lsu_axi_rid_q;
   logic [63:0]        lsu_axi_rdata_q;

   logic               disable_nonblock_load;
   //logic               lsu_wb_empty_any;
   logic               store_hit_rdbuf_dc2;
   
   assign disable_nonblock_load = dec_tlu_non_blocking_disable;
   
   //assign busfifo_addr_in[0]  = lsu_addr_dc5[31:0];
   //assign busfifo_addr_in[1]  = end_addr_dc5[31:0];
   always_comb begin
      NxtCmdPtr = CmdPtrQ;
      found0 = '0;
      for (int i=0; i<DEPTH; i++) begin
         if (~found0 & (DEPTH > 1)) begin
            NxtCmdPtr += 1'b1;
            if (busfifo_state[NxtCmdPtr] == CMD)  found0 = 1'b1;
         end
      end
   end
   
   assign WrPtrEn = (lsu_ldbusreq_dc3 & lsu_pkt_dc3.valid & lsu_pkt_dc3.load & ~rdbuf_full_freeze_dc3) | (|busfifo_rst[DEPTH-1:0]);
   always_comb begin
      NxtWrPtr = WrPtr;
      found1 = '0;
      for (int i=0; i<DEPTH; i++) begin
         if (~found1 & (DEPTH > 1)) begin
            NxtWrPtr += 1'b1;
            if ((busfifo_state[NxtWrPtr] == IDLE) | ((busfifo_state[NxtWrPtr] == DONE) & busfifo_rst[NxtWrPtr])) found1 = 1'b1;
         end
      end
   end

   always_comb begin
      read_buffer_full = 1'b1;
      for (int i=0; i<DEPTH; i++) begin
         read_buffer_full &= ((busfifo_state[i] != IDLE) | ((busfifo_state[i] == IDLE) & lsu_ldbusreq_dc3 & ~rdbuf_full_freeze_dc3 & (DEPTH_LOG2'(i) == WrPtr)));// (busfifo_state_en[i]));
      end
   end
   
   //assign CmdPtr  = (busfifo_state[CmdPtrQ] != CMD) ? NxtCmdPtr : CmdPtrQ;
   assign CmdPtr  = (((busfifo_state[CmdPtrQ] == CMD) & busfifo_state_bus_en[CmdPtrQ]) | (busfifo_state[CmdPtrQ] != CMD)) ? NxtCmdPtr : CmdPtrQ;
    
   // Don't drive b2b reads for the time being (This is done to keep the signals constant over the entire bus clock)
   //assign lsu_axi_arvalid                 = (busfifo_state[CmdPtr] == CMD) & (~busfifo_block[CmdPtr] | lsu_wb_empty_any) & ~(lsu_axi_arvalid_q & lsu_axi_arready_q);
   //assign lsu_axi_arvalid                 = (busfifo_state[CmdPtr] == CMD) & ~busfifo_block[CmdPtr] & ~(lsu_axi_arvalid_q & lsu_axi_arready_q);
   assign lsu_axi_arvalid                 = (busfifo_state[CmdPtr] == CMD) & ~busfifo_block[CmdPtr] & ~busfifo_state_bus_en[CmdPtr];
   assign lsu_axi_arid[LSU_BUS_TAG-1:0]   = LSU_BUS_TAG'({CmdPtr, (busfifo_sent[CmdPtr][0] | busfifo_sent_en[CmdPtr][0])});
   assign lsu_axi_araddr[31:0]            = busfifo_sideeffects[CmdPtr] ? busfifo_addr_lo[CmdPtr][31:0] :    // side effect loads are always aligned
                                                                          (busfifo_sent[CmdPtr][0] | busfifo_sent_en[CmdPtr][0]) ? {busfifo_addr_hi[CmdPtr][31:3],3'b0} : {busfifo_addr_lo[CmdPtr][31:3],3'b0};
   assign lsu_axi_arsize[2:0]             = busfifo_sideeffects[CmdPtr] ? {1'b0,busfifo_sz[CmdPtr][1:0]} : 3'b011;
   assign lsu_axi_arcache[3:0]            = busfifo_sideeffects[CmdPtr] ? 4'b0 : 4'b1111;
   assign lsu_axi_arprot[2:0]             = 3'b0;       
   assign lsu_axi_arregion[3:0]           = lsu_axi_araddr[31:28];
   assign lsu_axi_arlen[7:0]              = '0;
   assign lsu_axi_arburst[1:0]            = 2'b01;
   assign lsu_axi_arqos[3:0]              = '0;
   assign lsu_axi_arlock                  = '0;
   
   assign lsu_axi_rready                  = 1'b1;

   assign busfifo_addr_lo_in = lsu_addr_dc3[31:0];
   assign busfifo_addr_hi_in = end_addr_dc3[31:0];
   assign busfifo_sz_in      = {lsu_pkt_dc3.word, lsu_pkt_dc3.half};
   
   for (genvar i=0; i<DEPTH; i++) begin

      always_comb begin
         busfifo_wr_en[i]    = '0;
         busfifo_data_in[i]  = '0;
         busfifo_data_en[i]  = '0;
         busfifo_error_en[i] = '0;
         busfifo_nxtstate[i] = IDLE;
         busfifo_state_en[i] = '0;
         busfifo_state_bus_en[i] = '0;
         busfifo_cmd_sent[i] = '0;
         busfifo_cmd_resp[i] = '0;
         busfifo_sent_en[i]  = '0;
         busfifo_resp_en[i]  = '0;
         busfifo_rst[i]      = '0;
         busfifo_block_rst[i] = lsu_write_buffer_empty_any & lsu_bus_clk_en;
         case (busfifo_state[i])
            IDLE: begin
                     busfifo_nxtstate[i] = WAIT_COMMIT;
                     busfifo_state_en[i] = lsu_ldbusreq_dc3 & lsu_pkt_dc3.valid & lsu_pkt_dc3.load & (i == WrPtr) & ~rdbuf_full_freeze_dc3;
                     //busfifo_state_en[i] = (i == 0) ? (lsu_ldbusreq_dc5 & ~flush_dc5) : (lsu_ldbusreq_dc5 & ldst_dual_dc5 & ~flush_dc5);
                     busfifo_wr_en[i] = busfifo_state_en[i];
                     busfifo_data_en[i] = busfifo_state_en[i];   // This is to initialize data to 0
   	    end
            WAIT_COMMIT: begin
                    busfifo_nxtstate[i] = (lsu_ldbusreq_dc5 & (lsu_commit_dc5 | ld_freeze_dc3) & (i == WrPtr_dc5)) ? WAIT : IDLE;
                    busfifo_state_en[i] = lsu_ldbusreq_dc5 & (i == WrPtr_dc5);
            end
            WAIT: begin
                     busfifo_nxtstate[i] = CMD;
                     busfifo_state_en[i] = lsu_bus_clk_en;
            end
            CMD: begin
                     busfifo_nxtstate[i] = RESP;
                     busfifo_cmd_sent[i] = (CmdPtrQ == i) & lsu_axi_arvalid_q & lsu_axi_arready_q;
	             busfifo_cmd_resp[i] = lsu_axi_rready_q & lsu_axi_rvalid_q & (lsu_axi_rid_q[LSU_BUS_TAG-1:1] == (LSU_BUS_TAG-1)'(i));
                     busfifo_sent_en[i]  = {(busfifo_cmd_sent[i] & busfifo_sent[i][0] & busfifo_dual[i]), (busfifo_cmd_sent[i] & ~busfifo_sent[i][0])};
                     busfifo_resp_en[i]  = {(busfifo_cmd_resp[i] & lsu_axi_rid_q[0]),(busfifo_cmd_resp[i] & ~lsu_axi_rid_q[0])};
                     busfifo_state_bus_en[i]  = (busfifo_dual[i] & busfifo_sent_en[i][1]) | (~busfifo_dual[i] & busfifo_sent_en[i][0]);
                     busfifo_state_en[i] = busfifo_state_bus_en[i] & lsu_bus_clk_en;
                     busfifo_data_in[i][31:0] = busfifo_resp_en[i][1] ? lsu_axi_rdata_q[31:0] : lsu_axi_rdata_q[63:32];
                     busfifo_data_en[i]    = busfifo_cmd_resp[i] & lsu_bus_clk_en;
                     busfifo_error_en[i]   = {2{busfifo_data_en[i] & lsu_axi_rresp_q[1]}} & {lsu_axi_rid_q[0], ~lsu_axi_rid_q[0]};
	    end
            RESP: begin
                     busfifo_nxtstate[i] = DONE;
	             busfifo_cmd_resp[i] = lsu_axi_rready_q & lsu_axi_rvalid_q & (lsu_axi_rid_q[LSU_BUS_TAG-1:1] == (LSU_BUS_TAG-1)'(i));
                     busfifo_resp_en[i]  = {(busfifo_cmd_resp[i] & lsu_axi_rid_q[0]), (busfifo_cmd_resp[i] & ~lsu_axi_rid_q[0])};
                     busfifo_state_bus_en[i] = busfifo_cmd_resp[i] & (~busfifo_dual[i] | (&(busfifo_resp[i] | busfifo_resp_en[i])));
                     busfifo_state_en[i] = busfifo_state_bus_en[i] & lsu_bus_clk_en;
	             busfifo_data_en[i]  = busfifo_cmd_resp[i] & lsu_bus_clk_en;
	             busfifo_error_en[i] = {2{busfifo_data_en[i] & lsu_axi_rresp_q[1] & ~(|busfifo_error[i])}} & {lsu_axi_rid_q[0], ~lsu_axi_rid_q[0]};
                     busfifo_data_in[i][31:0] = (busfifo_state_en[i] & ~(|busfifo_error_en[i])) ? lsu_align(busfifo_data[i][31:0],lsu_axi_rdata_q[63:0],busfifo_resp_en[i][1],busfifo_addr_lo[i][2:0],busfifo_sz[i],busfifo_unsign[i]) :
                                                                                                  (busfifo_resp_en[i][1] ? lsu_axi_rdata_q[31:0] : lsu_axi_rdata_q[63:32]);
                 
  	    end
            DONE: begin
                     busfifo_nxtstate[i] = IDLE;
                     busfifo_rst[i]      = lsu_bus_clk_en_q;
                     busfifo_state_en[i] = busfifo_rst[i];
   	    end 
            default : begin
                     busfifo_wr_en[i]    = '0;
                     busfifo_data_in[i]  = '0;
                     busfifo_data_en[i]  = '0;
                     busfifo_error_en[i] = '0;
                     busfifo_nxtstate[i] = IDLE;
                     busfifo_state_en[i] = '0;
                     busfifo_cmd_sent[i] = '0;
                     busfifo_cmd_resp[i] = '0;
                     busfifo_sent_en[i]  = '0;
                     busfifo_resp_en[i]  = '0;
                     busfifo_rst[i]      = '0;
	       end
         endcase
      end

      //rvdffsc #(.WIDTH($bits(state_t))) busfifo_state_ff (.din(busfifo_nxtstate[i]), .dout({busfifo_state[i]}), .sel(busfifo_state_en[i]), .clear(busfifo_rst), .clk(lsu_free_c2_clk), .*);
      rvdffsc #(.WIDTH($bits(state_t))) busfifo_state_ff (.din(busfifo_nxtstate[i]), .dout({busfifo_state[i]}), .en(busfifo_state_en[i]), .clear(busfifo_rst[i]), .clk(lsu_free_c2_clk), .*);
      rvdffsc  #(.WIDTH(1)) busfifo_blockff (.din(lsu_read_buffer_block_dc3), .dout(busfifo_block[i]), .en(busfifo_wr_en[i]), .clear(busfifo_block_rst[i]), .clk(lsu_rdbuf_c1_clk), .*);  // Stall the entry till write buffer is empty
      rvdffs  #(.WIDTH(1)) busfifo_dualff (.din(ldst_dual_dc3), .dout(busfifo_dual[i]), .en(busfifo_wr_en[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffs  #(.WIDTH(1)) busfifo_nbff (.din(lsu_nonblock_load_valid_dc3), .dout(busfifo_nb[i]), .en(busfifo_wr_en[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffs  #(.WIDTH(1)) busfifo_sideeffectsff (.din(is_sideeffects_dc3), .dout(busfifo_sideeffects[i]), .en(busfifo_wr_en[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffs  #(.WIDTH(1)) busfifo_unsignff (.din(lsu_pkt_dc3.unsign), .dout(busfifo_unsign[i]), .en(busfifo_wr_en[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffs  #(.WIDTH(2)) busfifo_szff (.din(busfifo_sz_in[1:0]), .dout(busfifo_sz[i]), .en(busfifo_wr_en[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffsc #(.WIDTH(1)) busfifo_sentloff (.din(1'b1), .dout(busfifo_sent[i][0]), .en(busfifo_sent_en[i][0] & lsu_bus_clk_en), .clear(busfifo_rst[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffsc #(.WIDTH(1)) busfifo_senthiff (.din(1'b1), .dout(busfifo_sent[i][1]), .en(busfifo_sent_en[i][1] & lsu_bus_clk_en), .clear(busfifo_rst[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffsc #(.WIDTH(1)) busfifo_resploff (.din(1'b1), .dout(busfifo_resp[i][0]), .en(busfifo_resp_en[i][0] & lsu_bus_clk_en), .clear(busfifo_rst[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffsc #(.WIDTH(1)) busfifo_resphiff (.din(1'b1), .dout(busfifo_resp[i][1]), .en(busfifo_resp_en[i][1] & lsu_bus_clk_en), .clear(busfifo_rst[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffe #(.WIDTH(32)) busfifo_addrloff (.din(busfifo_addr_lo_in), .dout(busfifo_addr_lo[i]), .en(busfifo_wr_en[i]), .*);
      rvdffe #(.WIDTH(32)) busfifo_addrhiff (.din(busfifo_addr_hi_in), .dout(busfifo_addr_hi[i]), .en(busfifo_wr_en[i]), .*);
      rvdffe #(.WIDTH(32)) busfifo_dataff (.din(busfifo_data_in[i][31:0]), .dout(busfifo_data[i]), .en(busfifo_data_en[i]), .*);
      rvdffsc #(.WIDTH(1)) busfifo_errorloff (.din(1'b1), .dout(busfifo_error[i][0]), .en(busfifo_error_en[i][0]), .clear(busfifo_error_rst[i]), .clk(lsu_rdbuf_c1_clk), .*);
      rvdffsc #(.WIDTH(1)) busfifo_errorhiff (.din(1'b1), .dout(busfifo_error[i][1]), .en(busfifo_error_en[i][1]), .clear(busfifo_error_rst[i]), .clk(lsu_rdbuf_c1_clk), .*);
   end
   
   assign FreezePtrEn  = lsu_ldbusreq_dc3 & ld_freeze_dc3;
   assign ld_freeze_en = addr_external_dc2 & (dec_nonblock_load_freeze_dc2 | disable_nonblock_load | is_sideeffects_dc2) & lsu_busreq_dc2 & lsu_pkt_dc2.load & ~lsu_freeze_dc3 & ~flush_dc2_up & ~ld_full_hit_dc2;
   always_comb begin
      ld_freeze_rst = flush_dc3;
      for (int i=0; i<DEPTH; i++) begin
         ld_freeze_rst |= (busfifo_rst[i] & (DEPTH_LOG2'(i) == FreezePtr) & ~FreezePtrEn & ld_freeze_dc3 & ~rdbuf_full_freeze_dc3);
      end
   end

   assign rdbuf_full_freeze_en = lsu_busreq_dc2 & lsu_pkt_dc2.load & ~flush_dc2_up & ~flush_dc3 & ~lsu_freeze_dc3 & ~ld_full_hit_dc2 &
                                 ((disable_nonblock_load & ~lsu_read_buffer_empty_any) | (~disable_nonblock_load & read_buffer_full));
   assign rdbuf_full_freeze_rst = (|busfifo_rst[DEPTH-1:0]) | flush_dc3;

   assign busfifo_error_rst[DEPTH-1:0]  = busfifo_rst[DEPTH-1:0];
   assign ld_read_buffer_data_dc3[31:0] = busfifo_data[FreezePtr][31:0];
   assign ld_precise_bus_error          = (|busfifo_error[FreezePtr][1:0]) & busfifo_rst[FreezePtr] & lsu_freeze_dc3 & ld_freeze_rst & ~flush_dc3;   // Don't give bus error for interrupts
   assign ld_bus_error_addr_dc3[31:0]   = busfifo_addr_lo[FreezePtr][31:0];

   assign lsu_read_buffer_empty_any = ~(|busfifo_state[DEPTH-1:0]);
   
   assign lsu_ldbusreq_dc2 = lsu_busreq_dc2 & lsu_pkt_dc2.load & ~ld_full_hit_dc2 & ~ld_freeze_dc3;
   
   // Zero out the load forwarding signals since there is no forwarding from read buffer
   assign ld_hit_rdbuf_hi = '0;
   assign ld_hit_rdbuf_lo = '0;
   assign ld_fwddata_rdbuf_hi[63:0] = '0;
   assign ld_fwddata_rdbuf_lo[63:0] = '0;

   // Block the write buffer if store in dc2 matches a load in dc3/readbuf
   always_comb begin
      store_hit_rdbuf_dc2 = lsu_ldbusreq_dc3 & lsu_pkt_dc3.valid & lsu_pkt_dc3.load & 
                            ((lsu_addr_dc2[31:3] == lsu_addr_dc3[31:3]) | 
                             (ldst_dual_dc3 & (lsu_addr_dc2[31:3] == end_addr_dc3[31:3])) |
                             (ldst_dual_dc2 & (end_addr_dc2[31:3] == lsu_addr_dc3[31:3])) |
                             (ldst_dual_dc2 & ldst_dual_dc3 & (end_addr_dc2[31:3] == end_addr_dc3[31:3])));
      for (int i=0; i<DEPTH; i++) begin
         store_hit_rdbuf_dc2 |= ((busfifo_state[i] != IDLE) & (busfifo_state[i] != DONE)) & 
                                ((lsu_addr_dc2[31:3] == busfifo_addr_lo[i][31:3]) | 
                                 (busfifo_dual[i] & (lsu_addr_dc2[31:3] == busfifo_addr_hi[i][31:3])) |
                                 (ldst_dual_dc2 & (end_addr_dc2[31:3] == busfifo_addr_lo[i][31:3])) |
                                 (ldst_dual_dc2 & busfifo_dual[i] & (end_addr_dc2[31:3] == busfifo_addr_hi[i][31:3])));
         
      end
   end
   assign write_buffer_block_any = lsu_busreq_dc2 & lsu_pkt_dc2.valid & lsu_pkt_dc2.store & store_hit_rdbuf_dc2;

   
   // Non blocking ports
   assign lsu_nonblock_load_valid_dc3 = lsu_ldbusreq_dc3 & lsu_pkt_dc3.valid & lsu_pkt_dc3.load & ~flush_dc3 & ~dec_nonblock_load_freeze_dc3 & ~disable_nonblock_load & ~lsu_freeze_dc3 & ~disable_nonblock_load;
   assign lsu_nonblock_load_tag_dc3[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0];
   assign lsu_nonblock_load_inv_dc5 = lsu_nonblock_load_valid_dc5 & ~lsu_commit_dc5;
   assign lsu_nonblock_load_inv_tag_dc5[DEPTH_LOG2-1:0] = WrPtr_dc5[DEPTH_LOG2-1:0];      // dc5 tag needs to be accurate even if there is no invalidate

   always_comb begin
      lsu_nonblock_load_data_valid = '0;
      lsu_nonblock_load_data_error = '0;
      lsu_nonblock_load_data_tag[DEPTH_LOG2-1:0] = '0;
      lsu_nonblock_load_data[31:0] = '0;
      ld_imprecise_bus_error_any = '0;
      ld_imprecise_bus_error_addr[31:0] = '0;
      //write_buffer_block_any = '0;
      for (int i=0; i<DEPTH; i++) begin
          lsu_nonblock_load_data_valid      |= lsu_bus_clk_en_q & (busfifo_state[i] == DONE) & ~disable_nonblock_load & busfifo_nb[i] & ~(|busfifo_error[i]);
          lsu_nonblock_load_data_error      |= lsu_bus_clk_en_q & (busfifo_state[i] == DONE) & ~disable_nonblock_load & (|busfifo_error[i]) & busfifo_nb[i];
          lsu_nonblock_load_data_tag[DEPTH_LOG2-1:0]   |= DEPTH_LOG2'(i) & {DEPTH_LOG2{busfifo_state[i] == DONE}};
          lsu_nonblock_load_data[31:0]      |= busfifo_data[i][31:0] & {32{busfifo_state[i] == DONE}};
          ld_imprecise_bus_error_any        |= lsu_bus_clk_en_q & ~disable_nonblock_load & (busfifo_state[i] == DONE) & (|busfifo_error[i]) & busfifo_nb[i];
          ld_imprecise_bus_error_addr[31:0] |= {32{lsu_bus_clk_en_q & (busfifo_state[i] == DONE) & (|busfifo_error[i]) & busfifo_nb[i]}} & busfifo_addr_lo[i][31:0];
          //write_buffer_block_any            |= ~disable_nonblock_load & (((busfifo_state[i] != IDLE) & (busfifo_state[i] != RESP)) |
          //                                                               ((busfifo_state[i] == IDLE) & lsu_ldbusreq_dc3 & lsu_pkt_dc3.valid & lsu_pkt_dc3.load & ~rdbuf_full_freeze_dc3 & (DEPTH_LOG2'(i) == WrPtr)));
      end
   end
   
   // Don't sent the ld to bus till write buffer is empty
   rvdff #(.WIDTH(1)) read_buffer_blockff (.din(lsu_read_buffer_block_dc2), .dout(lsu_read_buffer_block_dc3), .clk(lsu_freeze_c2_dc3_clk), .*);

   // Pointers should only update when there is flush or ahb clock. We should also come out of freeze on ahb clock
   rvdffsc #(.WIDTH(1)) ld_freezeff (.din(1'b1), .dout(ld_freeze_dc3), .en(ld_freeze_en), .clear(ld_freeze_rst), .clk(lsu_free_c2_clk), .*);
   rvdffsc #(.WIDTH(1)) rdbuf_full_freezeff (.din(1'b1), .dout(rdbuf_full_freeze_dc3), .en(rdbuf_full_freeze_en), .clear(rdbuf_full_freeze_rst), .clk(lsu_free_c2_clk), .*);
   rvdff #(.WIDTH(DEPTH_LOG2)) lsu_CmdPtrff (.din(CmdPtr), .dout(CmdPtrQ), .clk(lsu_busm_clk), .*);
   rvdffs #(.WIDTH(DEPTH_LOG2)) lsu_WrPtrff (.din(NxtWrPtr), .dout(WrPtr), .en(WrPtrEn), .clk(lsu_free_c2_clk), .*);
   rvdffs #(.WIDTH(DEPTH_LOG2)) lsu_FreezePtrff (.din(WrPtr), .dout(FreezePtr), .en(FreezePtrEn), .clk(lsu_free_c2_clk), .*);
   rvdff #(.WIDTH(1)) ld_bus_errorff (.din(ld_precise_bus_error), .dout(ld_bus_error_dc3), .clk(lsu_free_c2_clk), .*);
   
   //rvdff #(.WIDTH(1)) lsu_wb_empty_ff (.din(lsu_write_buffer_empty_any), .dout(lsu_wb_empty_any), .clk(lsu_busm_clk), .*);             // syncing to the bus clock
  
   rvdff #(.WIDTH(1)) axi_arvalid_ff (.din(lsu_axi_arvalid), .dout(lsu_axi_arvalid_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_arready_ff (.din(lsu_axi_arready), .dout(lsu_axi_arready_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_rvalid_ff (.din(lsu_axi_rvalid), .dout(lsu_axi_rvalid_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(1)) axi_rready_ff (.din(lsu_axi_rready), .dout(lsu_axi_rready_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(2)) axi_rresp_ff (.din(lsu_axi_rresp), .dout(lsu_axi_rresp_q), .clk(lsu_busm_clk), .*);
   rvdff #(.WIDTH(LSU_BUS_TAG)) axi_rid_ff (.din(lsu_axi_rid[LSU_BUS_TAG-1:0]), .dout(lsu_axi_rid_q[LSU_BUS_TAG-1:0]), .clk(lsu_busm_clk), .*);
   rvdffe #(.WIDTH(64)) axi_rdata_ff (.din(lsu_axi_rdata[63:0]), .dout(lsu_axi_rdata_q[63:0]), .en(lsu_axi_rvalid & lsu_axi_rready & lsu_bus_clk_en), .*);

   // Fifo flops
   rvdff #(.WIDTH(1)) dec_nonblock_load_freeze_dc3ff (.din(dec_nonblock_load_freeze_dc2), .dout(dec_nonblock_load_freeze_dc3), .clk(lsu_freeze_c2_dc3_clk), .*);
   rvdffs #(.WIDTH(1)) lsu_ldbusreq_dc3ff (.din(lsu_ldbusreq_dc2), .dout(lsu_ldbusreq_dc3), .en(~(rdbuf_full_freeze_dc3 & lsu_freeze_dc3)), .clk(lsu_free_c2_clk), .*);   // ldbusreq_dc3 needs to stay high for rdbuf full freeze since it needs to go to bus once freeze is gone
   rvdff #(.WIDTH(1)) lsu_ldbusreq_dc4ff (.din(lsu_ldbusreq_dc3 & ~(rdbuf_full_freeze_dc3 & lsu_freeze_dc3)), .dout(lsu_ldbusreq_dc4), .clk(lsu_c2_dc4_clk), .*);
   rvdff #(.WIDTH(1)) lsu_ldbusreq_dc5ff (.din(lsu_ldbusreq_dc4), .dout(lsu_ldbusreq_dc5), .clk(lsu_c2_dc5_clk), .*);
   
   rvdff #(.WIDTH(1)) lsu_nonblock_load_valid_dc4ff (.din(lsu_nonblock_load_valid_dc3), .dout(lsu_nonblock_load_valid_dc4), .clk(lsu_c2_dc4_clk), .*);
   rvdff #(.WIDTH(1)) lsu_nonblock_load_valid_dc5ff (.din(lsu_nonblock_load_valid_dc4), .dout(lsu_nonblock_load_valid_dc5), .clk(lsu_c2_dc5_clk), .*);
   
   // WrPtr flops to dc5
   assign WrPtr_dc3[DEPTH_LOG2-1:0] = WrPtr[DEPTH_LOG2-1:0];
   rvdff #(.WIDTH(DEPTH_LOG2)) WrPtr_dc4ff (.din(WrPtr_dc3[DEPTH_LOG2-1:0]), .dout(WrPtr_dc4[DEPTH_LOG2-1:0]), .clk(lsu_c2_dc4_clk), .*);
   rvdff #(.WIDTH(DEPTH_LOG2)) WrPtr_dc5ff (.din(WrPtr_dc4[DEPTH_LOG2-1:0]), .dout(WrPtr_dc5[DEPTH_LOG2-1:0]), .clk(lsu_c2_dc5_clk), .*);

endmodule // lsu_bus_read_buffer
