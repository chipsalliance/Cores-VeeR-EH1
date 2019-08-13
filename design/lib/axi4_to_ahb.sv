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
// Owner: 
// Function: AXI4 -> AHB Bridge 
// Comments:
//
//********************************************************************************
module axi4_to_ahb #(parameter TAG  = 1) (

   input                   clk,
   input                   rst_l,
   input                   scan_mode, 
   input                   bus_clk_en,                              
   input                   clk_override,
   
   // AXI signals               
   // AXI Write Channels
   input  logic            axi_awvalid,
   output logic            axi_awready,
   input  logic [TAG-1:0]  axi_awid,
   input  logic [31:0]     axi_awaddr,
   input  logic [2:0]      axi_awsize,
   input  logic [2:0]      axi_awprot,

   input  logic            axi_wvalid,                                       
   output logic            axi_wready,
   input  logic [63:0]     axi_wdata,
   input  logic [7:0]      axi_wstrb,
   input  logic            axi_wlast,

   output logic            axi_bvalid,
   input  logic            axi_bready,
   output logic [1:0]      axi_bresp,
   output logic [TAG-1:0]  axi_bid,

   // AXI Read Channels
   input  logic            axi_arvalid,
   output logic            axi_arready,
   input  logic [TAG-1:0]  axi_arid,
   input  logic [31:0]     axi_araddr,                                     
   input  logic [2:0]      axi_arsize,
   input  logic [2:0]      axi_arprot,

   output logic            axi_rvalid,
   input  logic            axi_rready,
   output logic [TAG-1:0]  axi_rid,
   output logic [63:0]     axi_rdata,
   output logic [1:0]      axi_rresp,
   output logic            axi_rlast,                                     

   // AHB-Lite signals               
   output logic [31:0]     ahb_haddr,       // ahb bus address
   output logic [2:0]      ahb_hburst,      // tied to 0
   output logic            ahb_hmastlock,   // tied to 0
   output logic [3:0]      ahb_hprot,       // tied to 4'b0011
   output logic [2:0]      ahb_hsize,       // size of bus transaction (possible values 0,1,2,3)
   output logic [1:0]      ahb_htrans,      // Transaction type (possible values 0,2 only right now)
   output logic            ahb_hwrite,      // ahb bus write
   output logic [63:0]     ahb_hwdata,      // ahb bus write data

   input logic [63:0]      ahb_hrdata,      // ahb bus read data 
   input logic             ahb_hready,      // slave ready to accept transaction
   input logic             ahb_hresp        // slave response (high indicates erro)

);

   localparam ID   = 1;
   localparam PRTY = 1;
   typedef enum logic [2:0] {IDLE=3'b000, CMD_RD=3'b001, CMD_WR=3'b010, DATA_RD=3'b011, DATA_WR=3'b100, DONE=3'b101, STREAM_RD=3'b110, STREAM_ERR_RD=3'b111} state_t;
   state_t buf_state, buf_nxtstate;

   logic             slave_valid;
   logic             slave_ready;
   logic [TAG-1:0]   slave_tag;
   logic [63:0]      slave_rdata;
   logic [3:0]       slave_opc;

   logic             wrbuf_en, wrbuf_data_en;
   logic             wrbuf_cmd_sent, wrbuf_rst;
   logic             wrbuf_vld;
   logic             wrbuf_data_vld;
   logic [TAG-1:0]   wrbuf_tag;
   logic [2:0]       wrbuf_size;
   logic [31:0]      wrbuf_addr;
   logic [63:0]      wrbuf_data;
   logic [7:0]       wrbuf_byteen;
   
   logic             bus_write_clk_en;
   logic             bus_clk, bus_write_clk;
  
   logic             master_valid;
   logic             master_ready;
   logic [TAG-1:0]   master_tag;
   logic [31:0]      master_addr; 
   logic [63:0]      master_wdata;
   logic [2:0]       master_size;
   logic [2:0]       master_opc;
   
   // Buffer signals (one entry buffer)
   logic [31:0]                buf_addr;
   logic [1:0]                 buf_size;
   logic                       buf_write;
   logic [7:0]                 buf_byteen;
   logic                       buf_aligned;
   logic [63:0]                buf_data;    
   logic [TAG-1:0]             buf_tag;

   //Miscellaneous signals
   logic                       buf_rst;
   logic [TAG-1:0]             buf_tag_in;
   logic [31:0]                buf_addr_in;
   logic [7:0]                 buf_byteen_in;
   logic [63:0]                buf_data_in;
   logic                       buf_write_in;
   logic                       buf_aligned_in;
   logic [2:0]                 buf_size_in;
   
   logic                       buf_state_en;
   logic                       buf_wr_en;
   logic                       buf_data_wr_en;
   logic                       slvbuf_error_en;
   logic                       wr_cmd_vld;
   
   logic                       cmd_done_rst, cmd_done, cmd_doneQ;
   logic                       trxn_done;
   logic [2:0]                 buf_cmd_byte_ptr, buf_cmd_byte_ptrQ, buf_cmd_nxtbyte_ptr;
   logic                       buf_cmd_byte_ptr_en;
   logic                       found;
   
   logic                       slave_valid_pre;
   logic                       ahb_hready_q;
   logic                       ahb_hresp_q;
   logic [1:0]                 ahb_htrans_q;
   logic                       ahb_hwrite_q;
   logic [63:0]                ahb_hrdata_q;


   logic                       slvbuf_write;
   logic                       slvbuf_error;
   logic [TAG-1:0]             slvbuf_tag;

   logic                       slvbuf_error_in;
   logic                       slvbuf_wr_en;
   logic                       bypass_en;     
   logic                       rd_bypass_idle;
   
   logic                       last_addr_en;
   logic [31:0]                last_bus_addr;

   // Clocks
   logic                       buf_clken, slvbuf_clken;
   logic                       ahbm_addr_clken;
   logic                       ahbm_data_clken;

   logic                       buf_clk, slvbuf_clk;
   logic                       ahbm_clk;
   logic                       ahbm_addr_clk;
   logic                       ahbm_data_clk;
 
   // Function to get the length from byte enable
   function automatic logic [1:0] get_write_size;
      input logic [7:0] byteen;
   
      logic [1:0]       size;
   
      size[1:0] = (2'b11 & {2{(byteen[7:0] == 8'hff)}}) |
                  (2'b10 & {2{((byteen[7:0] == 8'hf0) | (byteen[7:0] == 8'h0f))}}) | 
                  (2'b01 & {2{((byteen[7:0] == 8'hc0) | (byteen[7:0] == 8'h30) | (byteen[7:0] == 8'h0c) | (byteen[7:0] == 8'h03))}});
   
      return size[1:0];   
   endfunction // get_write_size
   
   // Function to get the length from byte enable
   function automatic logic [2:0] get_write_addr;
      input logic [7:0] byteen;
   
      logic [2:0]       addr;
   
      addr[2:0] = (3'h0 & {3{((byteen[7:0] == 8'hff) | (byteen[7:0] == 8'h0f) | (byteen[7:0] == 8'h03))}}) |
                  (3'h2 & {3{(byteen[7:0] == 8'h0c)}})                                                     |
                  (3'h4 & {3{((byteen[7:0] == 8'hf0) | (byteen[7:0] == 8'h03))}})                          |
                  (3'h6 & {3{(byteen[7:0] == 8'hc0)}});
   
      return addr[2:0];   
   endfunction // get_write_size

   // Function to get the next byte pointer
   function automatic logic [2:0] get_nxtbyte_ptr (logic [2:0] current_byte_ptr, logic [7:0] byteen, logic get_next);
      logic [2:0] start_ptr;
      logic       found;
      found = '0;
      //get_nxtbyte_ptr[2:0] = current_byte_ptr[2:0];
      start_ptr[2:0] = get_next ? (current_byte_ptr[2:0] + 3'b1) : current_byte_ptr[2:0];
      for (int j=0; j<8; j++) begin
         if (~found) begin
            get_nxtbyte_ptr[2:0] = 3'(j);
            found |= (byteen[j] & (3'(j) >= start_ptr[2:0])) ;
         end          
      end
   endfunction // get_nextbyte_ptr

    
   // Write buffer
   assign wrbuf_en       = axi_awvalid & axi_awready & master_ready;
   assign wrbuf_data_en  = axi_wvalid & axi_wready & master_ready;
   assign wrbuf_cmd_sent = master_valid & master_ready & (master_opc[2:1] == 2'b01);
   assign wrbuf_rst      = wrbuf_cmd_sent & ~wrbuf_en;
  
   assign axi_awready = ~(wrbuf_vld & ~wrbuf_cmd_sent) & master_ready;
   assign axi_wready  = ~(wrbuf_data_vld & ~wrbuf_cmd_sent) & master_ready;
   assign axi_arready = ~(wrbuf_vld & wrbuf_data_vld) & master_ready;   
   assign axi_rlast   = 1'b1;
   
   assign wr_cmd_vld          = (wrbuf_vld & wrbuf_data_vld);
   assign master_valid          = wr_cmd_vld | axi_arvalid;
   assign master_tag[TAG-1:0]   = wr_cmd_vld ? wrbuf_tag[TAG-1:0] : axi_arid[TAG-1:0];
   assign master_opc[2:0]       = wr_cmd_vld ? 3'b011 : 3'b0;
   assign master_addr[31:0]     = wr_cmd_vld ? wrbuf_addr[31:0] : axi_araddr[31:0];
   assign master_size[2:0]    = wr_cmd_vld ? wrbuf_size[2:0] : axi_arsize[2:0];
   assign master_wdata[63:0]    = wrbuf_data[63:0];
 
   // AXI response channel signals
   assign axi_bvalid       = slave_valid & slave_ready & slave_opc[3];
   assign axi_bresp[1:0]   = slave_opc[0] ? 2'b10 : (slave_opc[1] ? 2'b11 : 2'b0); 
   assign axi_bid[TAG-1:0] = slave_tag[TAG-1:0];
   
   assign axi_rvalid       = slave_valid & slave_ready & (slave_opc[3:2] == 2'b0); 
   assign axi_rresp[1:0]   = slave_opc[0] ? 2'b10 : (slave_opc[1] ? 2'b11 : 2'b0); 
   assign axi_rid[TAG-1:0] = slave_tag[TAG-1:0];
   assign axi_rdata[63:0]  = slave_rdata[63:0];   
   assign slave_ready        = axi_bready & axi_rready;
   
   // Clock header logic
   assign bus_write_clk_en = bus_clk_en & ((axi_awvalid & axi_awready) | (axi_wvalid & axi_wready));
   
   rvclkhdr bus_cgc        (.en(bus_clk_en),       .l1clk(bus_clk),       .*);
   rvclkhdr bus_write_cgc  (.en(bus_write_clk_en), .l1clk(bus_write_clk),  .*);


 // FIFO state machine
   always_comb begin
      buf_nxtstate   = IDLE;
      buf_state_en   = 1'b0;
      buf_wr_en      = 1'b0;
      buf_data_wr_en = 1'b0;
      slvbuf_error_in   = 1'b0;
      slvbuf_error_en   = 1'b0;
      buf_write_in   = 1'b0;
      cmd_done       = 1'b0;
      trxn_done      = 1'b0;
      buf_cmd_byte_ptr_en = 1'b0;
      buf_cmd_byte_ptr[2:0] = '0; 
      slave_valid_pre   = 1'b0;  
      master_ready   = 1'b0;
      ahb_htrans[1:0]  = 2'b0;
      slvbuf_wr_en     = 1'b0;
      bypass_en        = 1'b0;
      rd_bypass_idle   = 1'b0;
      
      case (buf_state)
         IDLE: begin
                  master_ready   = 1'b1;
                  buf_write_in = (master_opc[2:1] == 2'b01);
                  buf_nxtstate = buf_write_in ? CMD_WR : CMD_RD;
                  buf_state_en = master_valid & master_ready;
                  buf_wr_en    = buf_state_en;
                  buf_data_wr_en = buf_state_en & (buf_nxtstate == CMD_WR);
                  buf_cmd_byte_ptr_en   = buf_state_en;
                  buf_cmd_byte_ptr[2:0] = buf_write_in ? get_nxtbyte_ptr(3'b0,buf_byteen_in[7:0],1'b0) : master_addr[2:0];
                  bypass_en       = buf_state_en;
                  rd_bypass_idle  = bypass_en & (buf_nxtstate == CMD_RD);
                  ahb_htrans[1:0] = {2{bypass_en}} & 2'b10;
          end
         CMD_RD: begin
                  buf_nxtstate    = (master_valid & (master_opc[2:0] == 3'b000))? STREAM_RD : DATA_RD;  
                  buf_state_en    = ahb_hready_q & (ahb_htrans_q[1:0] != 2'b0) & ~ahb_hwrite_q;
                  cmd_done        = buf_state_en & ~master_valid;                                
                  slvbuf_wr_en    = buf_state_en;
                  master_ready  = buf_state_en & (buf_nxtstate == STREAM_RD);    
                  buf_wr_en       = master_ready;
                  bypass_en       = master_ready & master_valid;
                  buf_cmd_byte_ptr[2:0] = bypass_en ? master_addr[2:0] : buf_addr[2:0];
                  ahb_htrans[1:0] = 2'b10 & {2{~buf_state_en | bypass_en}};
         end
         STREAM_RD: begin
                  master_ready  =  (ahb_hready_q & ~ahb_hresp_q) & ~(master_valid & master_opc[2:1] == 2'b01);
                  buf_wr_en       = (master_valid & master_ready & (master_opc[2:0] == 3'b000)); // update the fifo if we are streaming the read commands
                  buf_nxtstate    = ahb_hresp_q ? STREAM_ERR_RD : (buf_wr_en ? STREAM_RD : DATA_RD);            // assuming that the master accpets the slave response right away. 
                  buf_state_en    = (ahb_hready_q | ahb_hresp_q);
                  buf_data_wr_en  = buf_state_en;
                  slvbuf_error_in = ahb_hresp_q;
                  slvbuf_error_en = buf_state_en;
                  slave_valid_pre  = buf_state_en & ~ahb_hresp_q;             // send a response right away if we are not going through an error response.
                  cmd_done        = buf_state_en & ~master_valid;                     // last one of the stream should not send a htrans
                  bypass_en       = master_ready & master_valid & (buf_nxtstate == STREAM_RD) & buf_state_en;
                  buf_cmd_byte_ptr[2:0] = bypass_en ? master_addr[2:0] : buf_addr[2:0];
                  ahb_htrans[1:0] = 2'b10 & {2{~((buf_nxtstate != STREAM_RD) & buf_state_en)}};
                  slvbuf_wr_en    = buf_wr_en;                                         // shifting the contents from the buf to slv_buf for streaming cases         
         end // case: STREAM_RD
         STREAM_ERR_RD: begin
                  buf_nxtstate = DATA_RD;
                  buf_state_en = ahb_hready_q & (ahb_htrans_q[1:0] != 2'b0) & ~ahb_hwrite_q;
                  slave_valid_pre = buf_state_en;
                  slvbuf_wr_en   = buf_state_en;     // Overwrite slvbuf with buffer
                  buf_cmd_byte_ptr[2:0] = buf_addr[2:0];
                  ahb_htrans[1:0] = 2'b10 & {2{~buf_state_en}};
         end
         DATA_RD: begin
                  buf_nxtstate   = DONE;
                  buf_state_en   = (ahb_hready_q | ahb_hresp_q);
                  buf_data_wr_en = buf_state_en;
                  slvbuf_error_in= ahb_hresp_q;
                  slvbuf_error_en= buf_state_en;
                  slvbuf_wr_en   = buf_state_en;
         end
         CMD_WR: begin
                  buf_nxtstate = DATA_WR;
                  trxn_done    = ahb_hready_q & ahb_hwrite_q & (ahb_htrans_q[1:0] != 2'b0);
                  buf_state_en = trxn_done;
                  buf_cmd_byte_ptr_en = buf_state_en;
                  slvbuf_wr_en    = buf_state_en;
                  buf_cmd_byte_ptr    = trxn_done ? get_nxtbyte_ptr(buf_cmd_byte_ptrQ[2:0],buf_byteen[7:0],1'b1) : buf_cmd_byte_ptrQ;
                  cmd_done            = trxn_done & (buf_aligned | (buf_cmd_byte_ptrQ == 3'b111) | 
                                                     (buf_byteen[get_nxtbyte_ptr(buf_cmd_byte_ptrQ[2:0],buf_byteen[7:0],1'b1)] == 1'b0));
                  ahb_htrans[1:0] = {2{~(cmd_done | cmd_doneQ)}} & 2'b10;
         end
         DATA_WR: begin
                  buf_state_en = (cmd_doneQ & ahb_hready_q) | ahb_hresp_q;
                  master_ready = buf_state_en & ~ahb_hresp_q & slave_ready;   // Ready to accept new command if current command done and no error
                  buf_nxtstate = (ahb_hresp_q | ~slave_ready) ? DONE : 
                                  ((master_valid & master_ready) ? ((master_opc[2:1] == 2'b01) ? CMD_WR : CMD_RD) : IDLE);   
                  slvbuf_error_in = ahb_hresp_q;
                  slvbuf_error_en = buf_state_en;

                  buf_write_in = (master_opc[2:1] == 2'b01);
                  buf_wr_en = buf_state_en & ((buf_nxtstate == CMD_WR) | (buf_nxtstate == CMD_RD));
                  buf_data_wr_en = buf_wr_en;

                  cmd_done     = (ahb_hresp_q | (ahb_hready_q & (ahb_htrans_q[1:0] != 2'b0) & 
                                 ((buf_cmd_byte_ptrQ == 3'b111) | (buf_byteen[get_nxtbyte_ptr(buf_cmd_byte_ptrQ[2:0],buf_byteen[7:0],1'b1)] == 1'b0))));
                  bypass_en       = buf_state_en & buf_write_in & (buf_nxtstate == CMD_WR);   // Only bypass for writes for the time being
                  ahb_htrans[1:0] = {2{(~(cmd_done | cmd_doneQ) | bypass_en)}} & 2'b10;
                  slave_valid_pre  = buf_state_en & (buf_nxtstate != DONE);

                  trxn_done = ahb_hready_q & ahb_hwrite_q & (ahb_htrans_q[1:0] != 2'b0);
                  buf_cmd_byte_ptr_en = trxn_done | bypass_en;
                  buf_cmd_byte_ptr = bypass_en ? get_nxtbyte_ptr(3'b0,buf_byteen_in[7:0],1'b0) : 
                                                 trxn_done ? get_nxtbyte_ptr(buf_cmd_byte_ptrQ[2:0],buf_byteen[7:0],1'b1) : buf_cmd_byte_ptrQ;
            end
         DONE: begin
                  buf_nxtstate = IDLE;
                  buf_state_en = slave_ready;
                  slvbuf_error_en = 1'b1;
                  slave_valid_pre = 1'b1;
         end
      endcase
   end

   assign buf_rst              = 1'b0;
   assign cmd_done_rst         = slave_valid_pre;
   assign buf_addr_in[2:0]     = (buf_aligned_in & (master_opc[2:1] == 2'b01)) ? get_write_addr(wrbuf_byteen[7:0]) : master_addr[2:0]; 
   assign buf_addr_in[31:3]    = master_addr[31:3];
   assign buf_tag_in[TAG-1:0]  = master_tag[TAG-1:0];
   assign buf_byteen_in[7:0]   = wrbuf_byteen[7:0];
   assign buf_data_in[63:0]    = (buf_state == DATA_RD) ? ahb_hrdata_q[63:0] : master_wdata[63:0];
   assign buf_size_in[1:0]     = (buf_aligned_in & (master_size[1:0] == 2'b11) & (master_opc[2:1] == 2'b01)) ? get_write_size(wrbuf_byteen[7:0]) : master_size[1:0];
   assign buf_aligned_in       = (master_opc[2:0] == 3'b0)    |   // reads are always aligned since they are either DW or sideeffects
                                 (master_size[1:0] == 2'b0) |  (master_size[1:0] == 2'b01) | (master_size[1:0] == 2'b10) | // Always aligned for Byte/HW/Word since they can be only for non-idempotent. IFU/SB are always aligned
                                 ((master_size[1:0] == 2'b11) & 
                                  ((wrbuf_byteen[7:0] == 8'h3)  | (wrbuf_byteen[7:0] == 8'hc)   | (wrbuf_byteen[7:0] == 8'h30) | (wrbuf_byteen[7:0] == 8'hc0) | 
                                   (wrbuf_byteen[7:0] == 8'hf)  | (wrbuf_byteen[7:0] == 8'hf0)  | (wrbuf_byteen[7:0] == 8'hff)));
   
   // Generate the ahb signals
   assign ahb_haddr[31:0] = bypass_en ? {master_addr[31:3],buf_cmd_byte_ptr[2:0]}  : {buf_addr[31:3],buf_cmd_byte_ptr[2:0]};
   // assign ahb_hsize[2:0]  = ((buf_state == CMD_RD) | (buf_state == STREAM_RD) | (buf_state == STREAM_ERR_RD) | rd_bypass_idle) ? 3'b011 : 
   //                                                                               bypass_en ? {1'b0, ({2{buf_aligned_in}} & buf_size_in[1:0])} :
   //                                                                                           {1'b0, ({2{buf_aligned}} & buf_size[1:0])};   // Send the full size for aligned trxn
   assign ahb_hsize[2:0]  = bypass_en ? {1'b0, ({2{buf_aligned_in}} & buf_size_in[1:0])} :
                                        {1'b0, ({2{buf_aligned}} & buf_size[1:0])};   // Send the full size for aligned trxn
   assign ahb_hburst[2:0] = 3'b0; 
   assign ahb_hmastlock   = 1'b0;
   assign ahb_hprot[3:0]  = {3'b001,~axi_arprot[2]};
   assign ahb_hwrite      = bypass_en ? (master_opc[2:1] == 2'b01) : buf_write;
   assign ahb_hwdata[63:0] = buf_data[63:0];

   assign slave_valid          = slave_valid_pre;
   assign slave_opc[3:2]       = slvbuf_write ? 2'b11 : 2'b00;
   assign slave_opc[1:0]       = {2{slvbuf_error}} & 2'b10;
   assign slave_rdata[63:0]    = slvbuf_error ? {2{last_bus_addr[31:0]}} : ((buf_state == DONE) ? buf_data[63:0] : ahb_hrdata_q[63:0]);
   assign slave_tag[TAG-1:0]   = slvbuf_tag[TAG-1:0];
   
   assign last_addr_en = (ahb_htrans[1:0] != 2'b0) & ahb_hready & ahb_hwrite ;
  
 
   rvdffsc  #(.WIDTH(1))   wrbuf_vldff     (.din(1'b1), .dout(wrbuf_vld), .en(wrbuf_en), .clear(wrbuf_rst), .clk(bus_clk), .*);
   rvdffsc  #(.WIDTH(1))   wrbuf_data_vldff(.din(1'b1), .dout(wrbuf_data_vld), .en(wrbuf_data_en), .clear(wrbuf_rst), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(TAG)) wrbuf_tagff     (.din(axi_awid[TAG-1:0]), .dout(wrbuf_tag[TAG-1:0]), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(3))   wrbuf_sizeff    (.din(axi_awsize[2:0]), .dout(wrbuf_size[2:0]), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffe   #(.WIDTH(32))  wrbuf_addrff    (.din(axi_awaddr[31:0]), .dout(wrbuf_addr[31:0]), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffe   #(.WIDTH(64))  wrbuf_dataff    (.din(axi_wdata[63:0]), .dout(wrbuf_data[63:0]), .en(wrbuf_data_en), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(8))   wrbuf_byteenff  (.din(axi_wstrb[7:0]), .dout(wrbuf_byteen[7:0]), .en(wrbuf_data_en), .clk(bus_clk), .*);

   rvdffs #(.WIDTH(32))   last_bus_addrff (.din(ahb_haddr[31:0]), .dout(last_bus_addr[31:0]), .en(last_addr_en), .clk(ahbm_clk), .*);
   
   rvdffsc #(.WIDTH($bits(state_t))) buf_state_ff  (.din(buf_nxtstate), .dout({buf_state}), .en(buf_state_en), .clear(buf_rst), .clk(ahbm_clk), .*);
   rvdffs #(.WIDTH(1))               buf_writeff   (.din(buf_write_in), .dout(buf_write), .en(buf_wr_en), .clk(buf_clk), .*);
   rvdffs #(.WIDTH(TAG))             buf_tagff     (.din(buf_tag_in[TAG-1:0]), .dout(buf_tag[TAG-1:0]), .en(buf_wr_en), .clk(buf_clk), .*);
   rvdffe #(.WIDTH(32))              buf_addrff    (.din(buf_addr_in[31:0]), .dout(buf_addr[31:0]), .en(buf_wr_en & bus_clk_en), .*);
   rvdffs #(.WIDTH(2))               buf_sizeff    (.din(buf_size_in[1:0]), .dout(buf_size[1:0]), .en(buf_wr_en), .clk(buf_clk), .*);
   rvdffs #(.WIDTH(1))               buf_alignedff (.din(buf_aligned_in), .dout(buf_aligned), .en(buf_wr_en), .clk(buf_clk), .*);
   rvdffs #(.WIDTH(8))               buf_byteenff  (.din(buf_byteen_in[7:0]), .dout(buf_byteen[7:0]), .en(buf_wr_en), .clk(buf_clk), .*);
   rvdffe #(.WIDTH(64))              buf_dataff    (.din(buf_data_in[63:0]), .dout(buf_data[63:0]), .en(buf_data_wr_en & bus_clk_en), .*);
  
 
   rvdffs #(.WIDTH(1))   slvbuf_writeff        (.din(buf_write), .dout(slvbuf_write), .en(slvbuf_wr_en), .clk(buf_clk), .*);
   rvdffs #(.WIDTH(TAG)) slvbuf_tagff          (.din(buf_tag[TAG-1:0]), .dout(slvbuf_tag[TAG-1:0]), .en(slvbuf_wr_en), .clk(buf_clk), .*);
   rvdffs #(.WIDTH(1))   slvbuf_errorff        (.din(slvbuf_error_in), .dout(slvbuf_error), .en(slvbuf_error_en), .clk(ahbm_clk), .*);
    
   rvdffsc #(.WIDTH(1)) buf_cmd_doneff     (.din(1'b1), .en(cmd_done), .dout(cmd_doneQ), .clear(cmd_done_rst), .clk(ahbm_clk), .*);
   rvdffs #(.WIDTH(3))  buf_cmd_byte_ptrff (.din(buf_cmd_byte_ptr[2:0]), .dout(buf_cmd_byte_ptrQ[2:0]), .en(buf_cmd_byte_ptr_en), .clk(ahbm_clk), .*);

   rvdff #(.WIDTH(1))  hready_ff (.din(ahb_hready), .dout(ahb_hready_q), .clk(ahbm_clk), .*);
   rvdff #(.WIDTH(2))  htrans_ff (.din(ahb_htrans[1:0]), .dout(ahb_htrans_q[1:0]), .clk(ahbm_clk), .*);
   rvdff #(.WIDTH(1))  hwrite_ff (.din(ahb_hwrite), .dout(ahb_hwrite_q), .clk(ahbm_addr_clk), .*);
   rvdff #(.WIDTH(1))  hresp_ff  (.din(ahb_hresp), .dout(ahb_hresp_q), .clk(ahbm_clk), .*);
   rvdff #(.WIDTH(64)) hrdata_ff (.din(ahb_hrdata[63:0]), .dout(ahb_hrdata_q[63:0]),  .clk(ahbm_data_clk), .*);

   // Clock headers
   // clock enables for ahbm addr/data
   assign buf_clken       = bus_clk_en & (buf_wr_en | slvbuf_wr_en | clk_override);
   assign ahbm_addr_clken = bus_clk_en & ((ahb_hready & ahb_htrans[1]) | clk_override);
   assign ahbm_data_clken = bus_clk_en & ((buf_state != IDLE) | clk_override);
   
   rvclkhdr buf_cgc       (.en(buf_clken), .l1clk(buf_clk), .*);
   rvclkhdr ahbm_cgc      (.en(bus_clk_en), .l1clk(ahbm_clk), .*);
   rvclkhdr ahbm_addr_cgc (.en(ahbm_addr_clken), .l1clk(ahbm_addr_clk), .*);
   rvclkhdr ahbm_data_cgc (.en(ahbm_data_clken), .l1clk(ahbm_data_clk), .*);

`ifdef ASSERT_ON
   property ahb_trxn_aligned;
     @(posedge ahbm_clk) ahb_htrans[1]  |-> ((ahb_hsize[2:0] == 3'h0)                              |
                                        ((ahb_hsize[2:0] == 3'h1) & (ahb_haddr[0] == 1'b0))   |
                                        ((ahb_hsize[2:0] == 3'h2) & (ahb_haddr[1:0] == 2'b0)) |
                                        ((ahb_hsize[2:0] == 3'h3) & (ahb_haddr[2:0] == 3'b0)));
   endproperty
   assert_ahb_trxn_aligned: assert property (ahb_trxn_aligned) else 
     $display("Assertion ahb_trxn_aligned failed: ahb_htrans=2'h%h, ahb_hsize=3'h%h, ahb_haddr=32'h%h",ahb_htrans[1:0], ahb_hsize[2:0], ahb_haddr[31:0]);
   
   property ahb_error_protocol;
      @(posedge ahbm_clk) (ahb_hready & ahb_hresp) |-> (~$past(ahb_hready) & $past(ahb_hresp));
   endproperty
   assert_ahb_error_protocol: assert property (ahb_error_protocol) else
      $display("Bus Error with hReady isn't preceded with Bus Error without hready");
`endif
   
endmodule // axi4_to_ahb
