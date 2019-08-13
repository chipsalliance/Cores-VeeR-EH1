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
// Function: Top level SWERV core file to control the debug mode
// Comments: Responsible to put the rest of the core in quiesce mode, 
//           Send the commands/address. sends WrData and Recieve read Data.
//           And then Resume the core to do the normal mode   
// Author  : 
//********************************************************************************
module dbg (
   // outputs to the core for command and data interface
   output logic [31:0]                 dbg_cmd_addr,
   output logic [31:0]                 dbg_cmd_wrdata,
   output logic                        dbg_cmd_valid,
   output logic                        dbg_cmd_write, // 1: write command, 0: read_command
   output logic [1:0]                  dbg_cmd_type, // 0:gpr 1:csr 2: memory 
   output logic [1:0]                  dbg_cmd_size, // size of the abstract mem access debug command
   output logic                        dbg_core_rst_l, // core reset from dm
    
   // inputs back from the core/dec
   input logic [31:0]                  core_dbg_rddata,
   input logic                         core_dbg_cmd_done, // This will be treated like a valid signal
   input logic                         core_dbg_cmd_fail, // Exception during command run

   // Signals to dma to get a bubble
   output logic                        dbg_dma_bubble,   // Debug needs a bubble to send a valid
   input  logic                        dma_dbg_ready,    // DMA is ready to accept debug request
   
   // interface with the rest of the core to halt/resume handshaking
   output logic                        dbg_halt_req, // This is a pulse
   output logic                        dbg_resume_req, // Debug sends a resume requests. Pulse
   input  logic                        dec_tlu_debug_mode,        // Core is in debug mode
   input  logic                        dec_tlu_dbg_halted, // The core has finished the queiscing sequence. Core is halted now                         
   input  logic                        dec_tlu_mpc_halted_only,   // Only halted due to MPC
   input  logic                        dec_tlu_resume_ack, // core sends back an ack for the resume (pulse)
   
   // inputs from the JTAG
   input logic                         dmi_reg_en, // read or write
   input logic [6:0]                   dmi_reg_addr, // address of DM register
   input logic                         dmi_reg_wr_en, // write instruction
   input logic [31:0]                  dmi_reg_wdata, // write data
   // output 
   output logic [31:0]                 dmi_reg_rdata, // read data
//   output logic                        dmi_reg_ack, 

   // AXI signals               
   // AXI Write Channels
   output logic                        sb_axi_awvalid,
   input  logic                        sb_axi_awready,
   output logic [`RV_SB_BUS_TAG-1:0]   sb_axi_awid,
   output logic [31:0]                 sb_axi_awaddr,
   output logic [3:0]                  sb_axi_awregion,
   output logic [7:0]                  sb_axi_awlen,
   output logic [2:0]                  sb_axi_awsize,
   output logic [1:0]                  sb_axi_awburst,
   output logic                        sb_axi_awlock,
   output logic [3:0]                  sb_axi_awcache,
   output logic [2:0]                  sb_axi_awprot,
   output logic [3:0]                  sb_axi_awqos,
                                     
   output logic                        sb_axi_wvalid,                                       
   input  logic                        sb_axi_wready,
   output logic [63:0]                 sb_axi_wdata,
   output logic [7:0]                  sb_axi_wstrb,
   output logic                        sb_axi_wlast,
                                     
   input  logic                        sb_axi_bvalid,
   output logic                        sb_axi_bready,
   input  logic [1:0]                  sb_axi_bresp,
   input  logic [`RV_SB_BUS_TAG-1:0]   sb_axi_bid,
                                     
   // AXI Read Channels              
   output logic                        sb_axi_arvalid,
   input  logic                        sb_axi_arready,
   output logic [`RV_SB_BUS_TAG-1:0]   sb_axi_arid,
   output logic [31:0]                 sb_axi_araddr,
   output logic [3:0]                  sb_axi_arregion,
   output logic [7:0]                  sb_axi_arlen,
   output logic [2:0]                  sb_axi_arsize,
   output logic [1:0]                  sb_axi_arburst,
   output logic                        sb_axi_arlock,
   output logic [3:0]                  sb_axi_arcache,
   output logic [2:0]                  sb_axi_arprot,
   output logic [3:0]                  sb_axi_arqos,
                                     
   input  logic                        sb_axi_rvalid,
   output logic                        sb_axi_rready,
   input  logic [`RV_SB_BUS_TAG-1:0]   sb_axi_rid,
   input  logic [63:0]                 sb_axi_rdata,
   input  logic [1:0]                  sb_axi_rresp,
   input  logic                        sb_axi_rlast,
                                          
   input logic                         dbg_bus_clk_en,
            
   // general inputs   
   input logic                         clk,
   input logic                         free_clk,
   input logic                         rst_l,
   input logic                         clk_override,
   input logic                         scan_mode
);

`include "global.h"
   
   typedef enum logic [2:0] {IDLE=3'b000, HALTING=3'b001, HALTED=3'b010, CMD_START=3'b011, CMD_WAIT=3'b100, CMD_DONE=3'b101, RESUMING=3'b110} state_t;
   typedef enum logic [3:0] {SBIDLE=4'h0, WAIT_RD=4'h1, WAIT_WR=4'h2, CMD_RD=4'h3, CMD_WR=4'h4, CMD_WR_ADDR=4'h5, CMD_WR_DATA=4'h6, RSP_RD=4'h7, RSP_WR=4'h8, DONE=4'h9} sb_state_t;
   
   state_t       dbg_state;       
   state_t       dbg_nxtstate;
   logic         dbg_state_en;
   // these are the registers that the debug module implements
   logic [31:0]  dmstatus_reg;        // [26:24]-dmerr, [17:16]-resume ack, [9:8]-halted, [3:0]-version
   logic [31:0]  dmcontrol_reg;       // dmcontrol register has only 6 bits implemented. 31: haltreq, 30: resumereq, 29: haltreset, 28: ackhavereset, 1: ndmreset, 0: dmactive.
   logic [31:0]  command_reg;                  
   logic [31:0]  abstractcs_reg;      // bits implemted are [12] - busy and [10:8]= command error
   logic [31:0]  haltsum0_reg;
   logic [31:0]  data0_reg;
   logic [31:0]  data1_reg;

   // data 0  
   logic [31:0]  data0_din;
   logic         data0_reg_wren, data0_reg_wren0, data0_reg_wren1; 
   // data 1  
   logic [31:0]  data1_din;
   logic         data1_reg_wren, data1_reg_wren0, data1_reg_wren1;
   // abstractcs
   logic         abstractcs_busy_wren;
   logic         abstractcs_busy_din;
   logic [2:0]   abstractcs_error_din;
   logic         abstractcs_error_sel0, abstractcs_error_sel1, abstractcs_error_sel2, abstractcs_error_sel3, abstractcs_error_sel4, abstractcs_error_sel5;
   logic         abstractcs_error_selor;
   // dmstatus
   //logic         dmstatus_wren;
   logic         dmstatus_dmerr_wren;
   logic         dmstatus_resumeack_wren;
   logic         dmstatus_resumeack_din;
   logic         dmstatus_havereset_wren;
   logic         dmstatus_havereset_rst;
   logic         dmstatus_resumeack;
   logic         dmstatus_halted;
   logic         dmstatus_havereset;

   // dmcontrol
   logic         dmcontrol_wren, dmcontrol_wren_Q;
   // command
   logic         command_wren;
   // needed to send the read data back for dmi reads
   logic  [31:0] dmi_reg_rdata_din;
   
   sb_state_t    sb_state;
   sb_state_t    sb_nxtstate;
   logic         sb_state_en;

   //System bus section
   logic              sbcs_wren; 
   logic              sbcs_sbbusy_wren;
   logic              sbcs_sbbusy_din;
   logic              sbcs_sbbusyerror_wren;
   logic              sbcs_sbbusyerror_din;
   
   logic              sbcs_sberror_wren;
   logic [2:0]        sbcs_sberror_din;
   logic              sbcs_unaligned;
   logic              sbcs_illegal_size;
   
   // data
   logic              sbdata0_reg_wren0;
   logic              sbdata0_reg_wren1; 
   logic              sbdata0_reg_wren;
   logic [31:0]       sbdata0_din;
 
   logic              sbdata1_reg_wren0;
   logic              sbdata1_reg_wren1; 
   logic              sbdata1_reg_wren;
   logic [31:0]       sbdata1_din;
    
   logic              sbaddress0_reg_wren0;
   logic              sbaddress0_reg_wren1;
   logic              sbaddress0_reg_wren;
   logic [31:0]       sbaddress0_reg_din;
   logic [3:0]        sbaddress0_incr;
   logic              sbreadonaddr_access;
   logic              sbreadondata_access;
   logic              sbdata0wr_access;
   
   logic              sb_axi_awvalid_q, sb_axi_awready_q;
   logic              sb_axi_wvalid_q, sb_axi_wready_q;
   logic              sb_axi_arvalid_q, sb_axi_arready_q;
   logic              sb_axi_bvalid_q, sb_axi_bready_q;
   logic              sb_axi_rvalid_q, sb_axi_rready_q;
   logic [1:0]        sb_axi_bresp_q, sb_axi_rresp_q;
   logic [63:0]       sb_axi_rdata_q;
   
    logic [63:0]             sb_bus_rdata;

   //registers
   logic [31:0]       sbcs_reg;
   logic [31:0]       sbaddress0_reg;
   logic [31:0]       sbdata0_reg;
   logic [31:0]       sbdata1_reg;
     
   logic              dbg_dm_rst_l;

   //clken
   logic              dbg_free_clken;
   logic              dbg_free_clk;
   
   logic              sb_free_clken;
   logic              sb_free_clk;
   
   logic              bus_clken;
   logic              bus_clk;
   
   // clocking
   // used for the abstract commands. 
   assign dbg_free_clken  = dmi_reg_en | (dbg_state != IDLE) | dbg_state_en | dec_tlu_dbg_halted | clk_override;
   
   // used for the system bus
   assign sb_free_clken = dmi_reg_en | sb_state_en | (sb_state != SBIDLE) | clk_override;
   assign bus_clken = (sb_axi_awvalid | sb_axi_wvalid | sb_axi_arvalid | sb_axi_bvalid | sb_axi_rvalid | clk_override) & dbg_bus_clk_en;

   rvoclkhdr dbg_free_cgc     (.en(dbg_free_clken), .l1clk(dbg_free_clk), .*);
   rvoclkhdr sb_free_cgc     (.en(sb_free_clken), .l1clk(sb_free_clk), .*);
   rvclkhdr bus_cgc (.en(bus_clken), .l1clk(bus_clk), .*);
   
   // end clocking section  
   
   // Reset logic
   assign dbg_dm_rst_l = rst_l & (dmcontrol_reg[0] | scan_mode);
   assign dbg_core_rst_l = ~dmcontrol_reg[1]; 
   
   // system bus register
   // sbcs[31:29], sbcs - [22]:sbbusyerror, [21]: sbbusy, [20]:sbreadonaddr, [19:17]:sbaccess, [16]:sbautoincrement, [15]:sbreadondata, [14:12]:sberror, sbsize=32, 128=0, 64/32/16/8 are legal
   assign        sbcs_reg[31:29] = 3'b1;
   assign        sbcs_reg[28:23] = '0;
   assign        sbcs_reg[11:5]  = 7'h20;
   assign        sbcs_reg[4:0]   = 5'b01111;   
   assign        sbcs_wren = (dmi_reg_addr ==  7'h38) & dmi_reg_en & dmi_reg_wr_en & (sb_state == SBIDLE); // & (sbcs_reg[14:12] == 3'b000);
   assign        sbcs_sbbusyerror_wren = (sbcs_wren & dmi_reg_wdata[22]) |
                                         ((sb_state != SBIDLE) & dmi_reg_en & ((dmi_reg_addr == 7'h39) | (dmi_reg_addr == 7'h3c) | (dmi_reg_addr == 7'h3d)));
   assign        sbcs_sbbusyerror_din = ~(sbcs_wren & dmi_reg_wdata[22]);   // Clear when writing one
      
   rvdffs #(1) sbcs_sbbusyerror_reg  (.din(sbcs_sbbusyerror_din),  .dout(sbcs_reg[22]),    .en(sbcs_sbbusyerror_wren), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk));
   rvdffs #(1) sbcs_sbbusy_reg       (.din(sbcs_sbbusy_din),       .dout(sbcs_reg[21]),    .en(sbcs_sbbusy_wren),      .rst_l(dbg_dm_rst_l), .clk(sb_free_clk));
   rvdffs #(1) sbcs_sbreadonaddr_reg (.din(dmi_reg_wdata[20]),     .dout(sbcs_reg[20]),    .en(sbcs_wren),             .rst_l(dbg_dm_rst_l), .clk(sb_free_clk));
   rvdffs #(5) sbcs_misc_reg         (.din(dmi_reg_wdata[19:15]),  .dout(sbcs_reg[19:15]), .en(sbcs_wren),             .rst_l(dbg_dm_rst_l), .clk(sb_free_clk));
   rvdffs #(3) sbcs_error_reg        (.din(sbcs_sberror_din[2:0]), .dout(sbcs_reg[14:12]), .en(sbcs_sberror_wren),     .rst_l(dbg_dm_rst_l), .clk(sb_free_clk));
   
   assign sbcs_unaligned =    ((sbcs_reg[19:17] == 3'b001) &  sbaddress0_reg[0]) |  
                              ((sbcs_reg[19:17] == 3'b010) &  (|sbaddress0_reg[1:0])) |  
                              ((sbcs_reg[19:17] == 3'b011) &  (|sbaddress0_reg[2:0]));

   assign sbcs_illegal_size = sbcs_reg[19];    // Anything bigger than 64 bits is illegal

   assign sbaddress0_incr[3:0] = ({4{(sbcs_reg[19:17] == 3'b000)}} &  4'b0001) |
                                 ({4{(sbcs_reg[19:17] == 3'b001)}} &  4'b0010) |
                                 ({4{(sbcs_reg[19:17] == 3'b010)}} &  4'b0100) |
                                 ({4{(sbcs_reg[19:17] == 3'b100)}} &  4'b1000);
 
   // sbdata     
   //assign        sbdata0_reg_wren0   = dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 32'h3c);
   assign        sbdata0_reg_wren0   = dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h3c);   // write data only when single read is 0
   assign        sbdata0_reg_wren1   = (sb_state == RSP_RD) & sb_state_en & ~sbcs_sberror_wren;  
   assign        sbdata0_reg_wren    = sbdata0_reg_wren0 | sbdata0_reg_wren1;
  
   assign        sbdata1_reg_wren0   = dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h3d);   // write data only when single read is 0;
   assign        sbdata1_reg_wren1   = (sb_state == RSP_RD) & sb_state_en & ~sbcs_sberror_wren;  
   assign        sbdata1_reg_wren    = sbdata1_reg_wren0 | sbdata1_reg_wren1;
   
   assign        sbdata0_din[31:0]   = ({32{sbdata0_reg_wren0}} & dmi_reg_wdata[31:0]) |
                                       ({32{sbdata0_reg_wren1}} & sb_bus_rdata[31:0]);
   assign        sbdata1_din[31:0]   = ({32{sbdata1_reg_wren0}} & dmi_reg_wdata[31:0]) |
                                       ({32{sbdata1_reg_wren1}} & sb_bus_rdata[63:32]);
 
   rvdffe #(32)    dbg_sbdata0_reg    (.*, .din(sbdata0_din[31:0]), .dout(sbdata0_reg[31:0]), .en(sbdata0_reg_wren), .rst_l(dbg_dm_rst_l));
   rvdffe #(32)    dbg_sbdata1_reg    (.*, .din(sbdata1_din[31:0]), .dout(sbdata1_reg[31:0]), .en(sbdata1_reg_wren), .rst_l(dbg_dm_rst_l));
    
    // sbaddress
   assign        sbaddress0_reg_wren0   = dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h39);
   assign        sbaddress0_reg_wren    = sbaddress0_reg_wren0 | sbaddress0_reg_wren1;
   assign        sbaddress0_reg_din[31:0]= ({32{sbaddress0_reg_wren0}} & dmi_reg_wdata[31:0]) |
                                           ({32{sbaddress0_reg_wren1}} & (sbaddress0_reg[31:0] + {28'b0,sbaddress0_incr[3:0]}));    
   rvdffe #(32)    dbg_sbaddress0_reg    (.*, .din(sbaddress0_reg_din[31:0]), .dout(sbaddress0_reg[31:0]), .en(sbaddress0_reg_wren), .rst_l(dbg_dm_rst_l));
   
   assign sbreadonaddr_access = dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h39) & sbcs_reg[20];   // if readonaddr is set the next command will start upon writing of addr0
   assign sbreadondata_access = dmi_reg_en & ~dmi_reg_wr_en & (dmi_reg_addr == 7'h3c) & sbcs_reg[15];  // if readondata is set the next command will start upon reading of data0
   assign sbdata0wr_access  = dmi_reg_en &  dmi_reg_wr_en & (dmi_reg_addr == 7'h3c);                   // write to sbdata0 will start write command to system bus  

   // memory mapped registers
   // dmcontrol register has only 6 bits implemented. 31: haltreq, 30: resumereq, 29: haltreset, 28: ackhavereset, 1: ndmreset, 0: dmactive.
   // rest all the bits are zeroed out
   // dmactive flop is reset based on core rst_l, all other flops use dm_rst_l
   assign dmcontrol_wren      = (dmi_reg_addr ==  7'h10) & dmi_reg_en & dmi_reg_wr_en;
   assign dmcontrol_reg[27:2] = '0;
   rvdffs #(5) dmcontrolff (.din({dmi_reg_wdata[31:28],dmi_reg_wdata[1]}), .dout({dmcontrol_reg[31:28], dmcontrol_reg[1]}), .en(dmcontrol_wren), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   rvdffs #(1) dmcontrol_dmactive_ff (.din(dmi_reg_wdata[0]), .dout(dmcontrol_reg[0]), .en(dmcontrol_wren), .rst_l(rst_l), .clk(dbg_free_clk));
   rvdff  #(1) dmcontrol_wrenff(.din(dmcontrol_wren), .dout(dmcontrol_wren_Q), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   
   // dmstatus register bits that are implemented
   // [19:18]-havereset,[17:16]-resume ack, [9:8]-halted, [3:0]-version
   // rest all the bits are zeroed out
   //assign dmstatus_wren       = (dmi_reg_addr ==  32'h11) & dmi_reg_en;
   assign dmstatus_reg[31:20] = '0;
   assign dmstatus_reg[19:18] = {2{dmstatus_havereset}};
   assign dmstatus_reg[15:10] = '0;
   assign dmstatus_reg[7]     = '1;
   assign dmstatus_reg[6:4]   = '0;
   assign dmstatus_reg[17:16] = {2{dmstatus_resumeack}};
   assign dmstatus_reg[9:8]   = {2{dmstatus_halted}};
   assign dmstatus_reg[3:0]   = 4'h2;

   assign dmstatus_resumeack_wren = ((dbg_state == RESUMING) & dec_tlu_resume_ack) | (dmstatus_resumeack & ~dmcontrol_reg[30]);
   assign dmstatus_resumeack_din  = (dbg_state == RESUMING) & dec_tlu_resume_ack;

   assign dmstatus_havereset_wren = (dmi_reg_addr == 7'h10) & dmi_reg_wdata[1] & dmi_reg_en & dmi_reg_wr_en;
   assign dmstatus_havereset_rst  = (dmi_reg_addr == 7'h10) & dmi_reg_wdata[28] & dmi_reg_en & dmi_reg_wr_en;
   
   rvdffs  #(1) dmstatus_resumeack_reg (.din(dmstatus_resumeack_din), .dout(dmstatus_resumeack), .en(dmstatus_resumeack_wren), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   rvdff   #(1) dmstatus_halted_reg    (.din(dec_tlu_dbg_halted & ~dec_tlu_mpc_halted_only),     .dout(dmstatus_halted), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   rvdffsc #(1) dmstatus_havereset_reg (.din(1'b1), .dout(dmstatus_havereset), .en(dmstatus_havereset_wren), .clear(dmstatus_havereset_rst), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   
   // haltsum0 register
   assign haltsum0_reg[31:1] = '0;
   assign haltsum0_reg[0]    = dmstatus_halted;

   // abstractcs register
   // bits implemted are [12] - busy and [10:8]= command error
   assign        abstractcs_reg[31:13] = '0;
   assign        abstractcs_reg[11]    = '0;
   assign        abstractcs_reg[7:4]   = '0;
   assign        abstractcs_reg[3:0]   = 4'h2;    // One data register
   assign        abstractcs_error_sel0 = abstractcs_reg[12] & dmi_reg_en & ((dmi_reg_wr_en & ( (dmi_reg_addr == 7'h16) | (dmi_reg_addr == 7'h17))) |  (dmi_reg_addr == 7'h4));  
   assign        abstractcs_error_sel1 = dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h17) & ~((dmi_reg_wdata[31:24] == 8'b0) | (dmi_reg_wdata[31:24] == 8'h2));
   assign        abstractcs_error_sel2 = core_dbg_cmd_done & core_dbg_cmd_fail;
   assign        abstractcs_error_sel3 = dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h17) & (dbg_state != HALTED);
   assign        abstractcs_error_sel4 = (dmi_reg_addr ==  7'h17) & dmi_reg_en & dmi_reg_wr_en & 
                                         ( ((dmi_reg_wdata[22:20] == 3'b001) &  data1_reg[0]) |  
                                           ((dmi_reg_wdata[22:20] == 3'b010) &  (|data1_reg[1:0])) |  
                                           dmi_reg_wdata[22] | (dmi_reg_wdata[22:20] == 3'b011)
                                           );
   
   assign        abstractcs_error_sel5 = (dmi_reg_addr ==  7'h16) & dmi_reg_en & dmi_reg_wr_en;
                           
   assign        abstractcs_error_selor = abstractcs_error_sel0 | abstractcs_error_sel1 | abstractcs_error_sel2 | abstractcs_error_sel3 | abstractcs_error_sel4 | abstractcs_error_sel5;
   
   assign        abstractcs_error_din[2:0]  = ({3{abstractcs_error_sel0}} & 3'b001) |       // writing command or abstractcs while a command was executing. Or accessing data0 
                                              ({3{abstractcs_error_sel1}} & 3'b010) |       // writing a non-zero command to cmd field of command
                                              ({3{abstractcs_error_sel2}} & 3'b011) |       // exception while running command
                                              ({3{abstractcs_error_sel3}} & 3'b100) |       // writing a comnand when not in the halted state
                                              ({3{abstractcs_error_sel4}} & 3'b111) |       // unaligned abstract memory command
                                              ({3{abstractcs_error_sel5}} & ~dmi_reg_wdata[10:8] & abstractcs_reg[10:8]) |        // W1C
                                              ({3{~abstractcs_error_selor}} & abstractcs_reg[10:8]);                              // hold
   
   rvdffs #(1) dmabstractcs_busy_reg  (.din(abstractcs_busy_din), .dout(abstractcs_reg[12]), .en(abstractcs_busy_wren), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   rvdff  #(3) dmabstractcs_error_reg (.din(abstractcs_error_din[2:0]), .dout(abstractcs_reg[10:8]), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   
   
   // command register - implemented all the bits in this register
   // command[16] = 1: write, 0: read
   assign     command_wren = (dmi_reg_addr ==  7'h17) & dmi_reg_en & dmi_reg_wr_en & (dbg_state == HALTED);
   rvdffe #(32) dmcommand_reg (.*, .din(dmi_reg_wdata[31:0]), .dout(command_reg[31:0]), .en(command_wren), .rst_l(dbg_dm_rst_l));
   
   // data0 reg
   assign data0_reg_wren0   = (dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h4) & (dbg_state == HALTED));
   assign data0_reg_wren1   = core_dbg_cmd_done & (dbg_state == CMD_WAIT) & ~command_reg[16];
   assign data0_reg_wren    = data0_reg_wren0 | data0_reg_wren1;

   assign data0_din[31:0]   = ({32{data0_reg_wren0}} & dmi_reg_wdata[31:0]) |
                                     ({32{data0_reg_wren1}} & core_dbg_rddata[31:0]);
   
   rvdffe #(32) dbg_data0_reg (.*, .din(data0_din[31:0]), .dout(data0_reg[31:0]), .en(data0_reg_wren), .rst_l(dbg_dm_rst_l));

   // data 1 
   assign data1_reg_wren0   = (dmi_reg_en & dmi_reg_wr_en & (dmi_reg_addr == 7'h5) & (dbg_state == HALTED));
   assign data1_reg_wren1   = 1'b0;   // core_dbg_cmd_done & (dbg_state == CMD_WAIT) & ~command_reg[16];
   assign data1_reg_wren    = data1_reg_wren0 | data1_reg_wren1;
          
   assign data1_din[31:0]   = ({32{data1_reg_wren0}} & dmi_reg_wdata[31:0]);
                              //({32{data0_reg_wren1}} & core_dbg_rddata[31:0]);
     
   rvdffe #(32)    dbg_data1_reg    (.*, .din(data1_din[31:0]), .dout(data1_reg[31:0]), .en(data1_reg_wren), .rst_l(dbg_dm_rst_l));


   // FSM to control the debug mode entry, command send/recieve, and Resume flow.
   always_comb begin
      dbg_nxtstate            = IDLE;
      dbg_state_en            = 1'b0;
      abstractcs_busy_wren    = 1'b0;
      abstractcs_busy_din     = 1'b0;
      dbg_halt_req            = dmcontrol_wren_Q & dmcontrol_reg[31];         // single pulse output to the core
      dbg_resume_req          = 1'b0;         // single pulse output to the core
      
       case (dbg_state)
            IDLE: begin
                     dbg_nxtstate         = (dmstatus_reg[9] | dec_tlu_mpc_halted_only) ? HALTED : HALTING;         // initiate the halt command to the core
                     dbg_state_en         = ((dmcontrol_reg[31] & ~dec_tlu_debug_mode) | dmstatus_reg[9] | dec_tlu_mpc_halted_only) & ~dmcontrol_reg[1];      // when the jtag writes the halt bit in the DM register, OR when the status indicates Halted 
                     dbg_halt_req         = dmcontrol_reg[31];                          // Removed debug mode qualification during MPC changes
                     //dbg_halt_req         = dmcontrol_reg[31] & ~dec_tlu_debug_mode;                          // only when jtag has written the halt_req bit in the control
            end
            HALTING : begin
                     dbg_nxtstate         = HALTED;                                        // Goto HALTED once the core sends an ACK
                     dbg_state_en         = dmstatus_reg[9];                               // core indicates halted
            end
            HALTED: begin
                     // wait for halted to go away before send to resume. Else start of new command
                     dbg_nxtstate         = (dmstatus_reg[9] & ~dmcontrol_reg[1]) ? ((dmcontrol_reg[30] & ~dmcontrol_reg[31]) ? RESUMING : CMD_START) : 
                                                                                    (dmcontrol_reg[31] ? HALTING : IDLE);       // This is MPC halted case
                     //dbg_nxtstate         = dmcontrol_reg[1] ? IDLE : (dmcontrol_reg[30] & ~dmcontrol_reg[31]) ? RESUMING : CMD_START; // wait for halted to go away before send to resume. Else start of new command
                     dbg_state_en         = (dmstatus_reg[9] & dmcontrol_reg[30] & ~dmcontrol_reg[31] & dmcontrol_wren_Q) | command_wren | dmcontrol_reg[1] | ~(dmstatus_reg[9] | dec_tlu_mpc_halted_only);
                     abstractcs_busy_wren = dbg_state_en & (dbg_nxtstate == CMD_START);                      // write busy when a new command was written by jtag
                     abstractcs_busy_din  = 1'b1;                                                            
                     dbg_resume_req       = dbg_state_en & (dbg_nxtstate == RESUMING);                       // single cycle pulse to core if resuming 
            end
            CMD_START: begin
                     dbg_nxtstate         = (|abstractcs_reg[10:8]) ? CMD_DONE : CMD_WAIT;                   // new command sent to the core                   
                     dbg_state_en         = dbg_cmd_valid | (|abstractcs_reg[10:8]);                               
            end 
            CMD_WAIT: begin
                     dbg_nxtstate         = CMD_DONE;                                           
                     dbg_state_en         = core_dbg_cmd_done;                   // go to done state for one cycle after completing current command
            end
            CMD_DONE: begin
                     dbg_nxtstate         = HALTED;                          
                     dbg_state_en         = 1'b1;
                     abstractcs_busy_wren = dbg_state_en;                    // remove the busy bit from the abstracts ( bit 12 )
                     abstractcs_busy_din  = 1'b0;
            end
            RESUMING : begin
                     dbg_nxtstate            = IDLE;                         
                     dbg_state_en            = dmstatus_reg[17];             // resume ack has been updated in the dmstatus register
           end
           default : begin
                     dbg_nxtstate            = IDLE;
                     dbg_state_en            = 1'b0;
                     abstractcs_busy_wren    = 1'b0;
                     abstractcs_busy_din     = 1'b0;
                     dbg_halt_req            = 1'b0;         // single pulse output to the core
                     dbg_resume_req          = 1'b0;         // single pulse output to the core
          end
         endcase
   end // always_comb begin

   assign dmi_reg_rdata_din[31:0] = ({32{dmi_reg_addr == 7'h4}}  & data0_reg[31:0])      |
                                    ({32{dmi_reg_addr == 7'h5}}  & data1_reg[31:0])      |
                                    ({32{dmi_reg_addr == 7'h10}} & dmcontrol_reg[31:0])  | 
                                    ({32{dmi_reg_addr == 7'h11}} & dmstatus_reg[31:0])   |
                                    ({32{dmi_reg_addr == 7'h16}} & abstractcs_reg[31:0]) |   
                                    ({32{dmi_reg_addr == 7'h17}} & command_reg[31:0])    |
                                    ({32{dmi_reg_addr == 7'h40}} & haltsum0_reg[31:0])   |
                                    ({32{dmi_reg_addr == 7'h38}} & sbcs_reg[31:0])       |
                                    ({32{dmi_reg_addr == 7'h39}} & sbaddress0_reg[31:0]) | 
                                    ({32{dmi_reg_addr == 7'h3c}} & sbdata0_reg[31:0])    |  
                                    ({32{dmi_reg_addr == 7'h3d}} & sbdata1_reg[31:0]);
  
 
   rvdffs #($bits(state_t)) dbg_state_reg    (.din(dbg_nxtstate), .dout({dbg_state}), .en(dbg_state_en), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
   // Ack will use the power on reset only otherwise there won't be any ack until dmactive is 1
//   rvdff  #(1)              dmi_ack_reg      (.din(dmi_reg_en), .dout(dmi_reg_ack), .rst_l(rst_l), .clk(free_clk));
   rvdffs  #(32) dmi_rddata_reg(.din(dmi_reg_rdata_din), .dout(dmi_reg_rdata), .en(dmi_reg_en), .rst_l(dbg_dm_rst_l), .clk(dbg_free_clk));
 
   // interface for the core
   assign        dbg_cmd_addr[31:0]    = (command_reg[31:24] == 8'h2) ? {data1_reg[31:2],2'b0}  : {20'b0, command_reg[11:0]};  // Only word addresses for abstract memory
   assign        dbg_cmd_wrdata[31:0]  = data0_reg[31:0];
   assign        dbg_cmd_valid         = (dbg_state == CMD_START) & ~(|abstractcs_reg[10:8]) & dma_dbg_ready;        
   assign        dbg_cmd_write         = command_reg[16];
   assign        dbg_cmd_type[1:0]     = (command_reg[31:24] == 8'h2) ? 2'b10 : {1'b0, (command_reg[15:12] == 4'b0)};
   assign        dbg_cmd_size[1:0]     = command_reg[21:20];

   // Ask DMA to stop taking bus trxns since debug request is done
   assign        dbg_dma_bubble        = ((dbg_state == CMD_START) & ~(|abstractcs_reg[10:8])) | (dbg_state == CMD_WAIT);
      
  // system bus FSM
  always_comb begin
      sb_nxtstate            = SBIDLE;
      sb_state_en            = 1'b0;
      sbcs_sbbusy_wren       = 1'b0;
      sbcs_sbbusy_din        = 1'b0;
      sbcs_sberror_wren      = 1'b0;
      sbcs_sberror_din[2:0]  = 3'b0;
      sbaddress0_reg_wren1   = 1'b0;    
      case (sb_state)
            SBIDLE: begin
                     sb_nxtstate            = sbdata0wr_access ? WAIT_WR : WAIT_RD;
                     sb_state_en            = sbdata0wr_access | sbreadondata_access | sbreadonaddr_access;
                     sbcs_sbbusy_wren       = sb_state_en;                                                 // set the single read bit if it is a singlread command
                     sbcs_sbbusy_din        = 1'b1;
                     sbcs_sberror_wren      = sbcs_wren & (|dmi_reg_wdata[14:12]);                                            // write to clear the error bits
                     sbcs_sberror_din[2:0]  = ~dmi_reg_wdata[14:12] & sbcs_reg[14:12];
            end               
            WAIT_RD: begin
                     sb_nxtstate           = (sbcs_unaligned | sbcs_illegal_size) ? DONE : CMD_RD;
                     sb_state_en           = dbg_bus_clk_en | sbcs_unaligned | sbcs_illegal_size;
                     sbcs_sberror_wren     = sbcs_unaligned | sbcs_illegal_size;
                     sbcs_sberror_din[2:0] = sbcs_unaligned ? 3'b011 : 3'b100;
            end
            WAIT_WR: begin
                     sb_nxtstate           = (sbcs_unaligned | sbcs_illegal_size) ? DONE : CMD_WR;
                     sb_state_en           = dbg_bus_clk_en | sbcs_unaligned | sbcs_illegal_size;
                     sbcs_sberror_wren     = sbcs_unaligned | sbcs_illegal_size;
                     sbcs_sberror_din[2:0] = sbcs_unaligned ? 3'b011 : 3'b100;
            end
            CMD_RD : begin            
                     sb_nxtstate           = RSP_RD; 
                     sb_state_en           = sb_axi_arvalid_q & sb_axi_arready_q & dbg_bus_clk_en;
            end               
            CMD_WR : begin            
                     sb_nxtstate           = (sb_axi_awready_q & sb_axi_wready_q) ? RSP_WR : (sb_axi_awready_q ? CMD_WR_DATA : CMD_WR_ADDR); 
                     sb_state_en           = ((sb_axi_awvalid_q & sb_axi_awready_q) | (sb_axi_wvalid_q & sb_axi_wready_q)) & dbg_bus_clk_en;
            end               
            CMD_WR_ADDR : begin       
                     sb_nxtstate           = RSP_WR; 
                     sb_state_en           = sb_axi_awvalid_q & sb_axi_awready_q & dbg_bus_clk_en;
            end               
            CMD_WR_DATA : begin       
                     sb_nxtstate           = RSP_WR; 
                     sb_state_en           = sb_axi_wvalid_q & sb_axi_wready_q & dbg_bus_clk_en;
            end               
            RSP_RD: begin             
                     sb_nxtstate           = DONE;
                     sb_state_en           = sb_axi_rvalid_q & sb_axi_rready_q & dbg_bus_clk_en;
                     sbcs_sberror_wren     = sb_state_en & sb_axi_rresp_q[1];
                     sbcs_sberror_din[2:0] = 3'b010;
            end               
            RSP_WR: begin             
                     sb_nxtstate           = DONE;
                     sb_state_en           = sb_axi_bvalid_q & sb_axi_bready_q & dbg_bus_clk_en;
                     sbcs_sberror_wren     = sb_state_en & sb_axi_bresp_q[1];
                     sbcs_sberror_din[2:0] = 3'b010;
            end               
            DONE: begin       
                     sb_nxtstate            = SBIDLE;
                     sb_state_en            = 1'b1;
                     sbcs_sbbusy_wren       = 1'b1;                           // reset the single read
                     sbcs_sbbusy_din        = 1'b0;
                     sbaddress0_reg_wren1   = sbcs_reg[16];                   // auto increment was set. Update to new address after completing the current command            
            end
            default : begin 
                     sb_nxtstate            = SBIDLE;
                     sb_state_en            = 1'b0;
                     sbcs_sbbusy_wren       = 1'b0;
                     sbcs_sbbusy_din        = 1'b0;
                     sbcs_sberror_wren      = 1'b0;
                     sbcs_sberror_din[2:0]  = 3'b0;
                     sbaddress0_reg_wren1   = 1'b0; 
           end   
         endcase
   end // always_comb begin
   
   rvdffs #($bits(sb_state_t)) sb_state_reg (.din(sb_nxtstate), .dout({sb_state}), .en(sb_state_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk));
   
   //rvdff #(.WIDTH(1)) bus_clken_ff (.din(dbg_bus_clk_en), .dout(dbg_bus_clk_en_q),  .rst_l(dbg_dm_rst_l), .clk(dbg_sb_c2_free_clk), .*);

   rvdffs #(.WIDTH(1)) axi_awvalid_ff (.din(sb_axi_awvalid), .dout(sb_axi_awvalid_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdffs #(.WIDTH(1)) axi_awready_ff (.din(sb_axi_awready), .dout(sb_axi_awready_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdffs #(.WIDTH(1)) axi_wvalid_ff (.din(sb_axi_wvalid), .dout(sb_axi_wvalid_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdffs #(.WIDTH(1)) axi_wready_ff (.din(sb_axi_wready), .dout(sb_axi_wready_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdffs #(.WIDTH(1)) axi_arvalid_ff (.din(sb_axi_arvalid), .dout(sb_axi_arvalid_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdffs #(.WIDTH(1)) axi_arready_ff (.din(sb_axi_arready), .dout(sb_axi_arready_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);

   rvdffs #(.WIDTH(1)) axi_bvalid_ff (.din(sb_axi_bvalid), .dout(sb_axi_bvalid_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdffs #(.WIDTH(1)) axi_bready_ff (.din(sb_axi_bready), .dout(sb_axi_bready_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdff  #(.WIDTH(2)) axi_bresp_ff (.din(sb_axi_bresp[1:0]), .dout(sb_axi_bresp_q[1:0]), .rst_l(dbg_dm_rst_l), .clk(bus_clk), .*);
   rvdffs #(.WIDTH(1)) axi_rvalid_ff (.din(sb_axi_rvalid), .dout(sb_axi_rvalid_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdffs #(.WIDTH(1)) axi_rready_ff (.din(sb_axi_rready), .dout(sb_axi_rready_q), .en(dbg_bus_clk_en), .rst_l(dbg_dm_rst_l), .clk(sb_free_clk), .*);
   rvdff  #(.WIDTH(2)) axi_rresp_ff (.din(sb_axi_rresp[1:0]), .dout(sb_axi_rresp_q[1:0]), .rst_l(dbg_dm_rst_l), .clk(bus_clk), .*);
   rvdffe  #(.WIDTH(64)) axi_rdata_ff (.din(sb_axi_rdata[63:0]), .dout(sb_axi_rdata_q[63:0]), .rst_l(dbg_dm_rst_l), .en(bus_clken), .*);

   // AXI Request signals
   assign sb_axi_awvalid              = ((sb_state == CMD_WR) | (sb_state == CMD_WR_ADDR)) & ~(sb_axi_awvalid_q & sb_axi_awready_q);
   assign sb_axi_awaddr[31:0]         = sbaddress0_reg[31:0];
   assign sb_axi_awid[SB_BUS_TAG-1:0] = '0;
   assign sb_axi_awsize[2:0]          = sbcs_reg[19:17];
   assign sb_axi_awprot[2:0]          = '0;
   assign sb_axi_awcache[3:0]         = 4'b1111;
   assign sb_axi_awregion[3:0]        = sbaddress0_reg[31:28];
   assign sb_axi_awlen[7:0]           = '0;
   assign sb_axi_awburst[1:0]         = 2'b01;
   assign sb_axi_awqos[3:0]           = '0;
   assign sb_axi_awlock               = '0;
   
   assign sb_axi_wvalid       = ((sb_state == CMD_WR) | (sb_state == CMD_WR_DATA)) & ~(sb_axi_wvalid_q & sb_axi_wready_q);
   assign sb_axi_wdata[63:0]  = ({64{(sbcs_reg[19:17] == 3'h0)}} & {8{sbdata0_reg[7:0]}}) |
                                ({64{(sbcs_reg[19:17] == 3'h1)}} & {4{sbdata0_reg[15:0]}}) |
                                ({64{(sbcs_reg[19:17] == 3'h2)}} & {2{sbdata0_reg[31:0]}}) |
                                ({64{(sbcs_reg[19:17] == 3'h3)}} & {sbdata1_reg[31:0],sbdata0_reg[31:0]});
   assign sb_axi_wstrb[7:0]   = ({8{(sbcs_reg[19:17] == 3'h0)}} & (8'h1 << sbaddress0_reg[2:0])) |
                                ({8{(sbcs_reg[19:17] == 3'h1)}} & (8'h3 << {sbaddress0_reg[2:1],1'b0})) |
                                ({8{(sbcs_reg[19:17] == 3'h2)}} & (8'hf << {sbaddress0_reg[2],2'b0})) |
                                ({8{(sbcs_reg[19:17] == 3'h3)}} & 8'hff);
   assign sb_axi_wlast        = '1;

   assign sb_axi_arvalid              = (sb_state == CMD_RD) & ~(sb_axi_arvalid_q & sb_axi_arready_q);
   assign sb_axi_araddr[31:0]         = {sbaddress0_reg[31:3],3'b0};
   assign sb_axi_arid[SB_BUS_TAG-1:0] = '0;
   assign sb_axi_arsize[2:0]          = 3'b011;
   assign sb_axi_arprot[2:0]          = '0;
   assign sb_axi_arcache[3:0]         = 4'b0;
   assign sb_axi_arregion[3:0]        = sbaddress0_reg[31:28];
   assign sb_axi_arlen[7:0]           = '0;
   assign sb_axi_arburst[1:0]         = 2'b01;
   assign sb_axi_arqos[3:0]           = '0;
   assign sb_axi_arlock               = '0;

   // AXI Response signals
   assign sb_axi_bready = 1'b1;

   assign sb_axi_rready = 1'b1;
   assign sb_bus_rdata[63:0] = ({64{sbcs_reg[19:17] == 3'h0}} & ((sb_axi_rdata_q[63:0] >> 8*sbaddress0_reg[2:0]) & 64'hff))       |
                               ({64{sbcs_reg[19:17] == 3'h1}} & ((sb_axi_rdata_q[63:0] >> 16*sbaddress0_reg[2:1]) & 64'hffff))    |
                               ({64{sbcs_reg[19:17] == 3'h2}} & ((sb_axi_rdata_q[63:0] >> 32*sbaddress0_reg[2]) & 64'hffff_ffff)) |
                               ({64{sbcs_reg[19:17] == 3'h3}} & sb_axi_rdata_q[63:0]);
   
`ifdef ASSERT_ON
// assertion.  
//  when the resume_ack is asserted then the dec_tlu_dbg_halted should be 0  
   dm_check_resume_and_halted: assert property (@(posedge clk)  disable iff(~rst_l) (~dec_tlu_resume_ack | ~dec_tlu_dbg_halted));
`endif
endmodule
