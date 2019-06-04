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
//------------------------------------------------------------------------------------
//
//  Copyright Western Digital, 2019
//  Owner : Anusha Narayanamoorthy
//  Description:  
//                This module Synchronizes the signals between JTAG (TCK) and
//                processor (Core_clk)
//
//-------------------------------------------------------------------------------------

module dmi_jtag_to_core_sync (
   // JTAG signals
   input                       trst_n,                         // JTAG clock
   input                       dmireset,                       // dmi_reset to clear sticky bits
   input                       tck,                            // JTAG reset
   input [31:0]                j_wr_data,                      // 32 bit Write data
   input [31:0]                j_wr_addr,                      // 32 bit Write address
   input                       wr_intf,                        // 1 bit  Write interface bit
   input                       wr_enab,                        // 1 bit  Write enable

   output reg [31:0]           j_rd_data,                      // 32 bit Read data in JTAG clock
   output [1:0]                opcod,                           // 2 bit opcode

   // Processor Signals
   input                       core_rst_n,                     // Core clock
   input                       core_clk,                       // Core reset
   input [31:0]                c_rd_data,                      // 32 bit Read data from Processor
   input                       c_rd_ack,                       // Acknowledgement signal from Processor

   output reg [31:0]           c_wr_data,                      // 32 bit Write data to Processor
   output reg [31:0]           c_wr_addr,                      // 32 bit Write address to Processor
   output                      reg_en,                         // 1 bit  Write interface bit to Processor
   output                      reg_wr_en                       // 1 bit  Write enable to Processor
);

  parameter IDLE = 2'b0;
  parameter FAIL = 2'b10;
  parameter TRANS = 2'b11;

  //Internal Signal Declaration
//  reg                          status;
  reg                          d_reg_en;
  reg  [1:0]                   sig_opcod;
  reg  [1:0]                   state;
  reg  [1:0]                   n_state;
  reg  [1:0]                   sts_opc;
  reg  [1:0]                   reg_opcod;

  
  wire                         c_rd_en;
  wire                         c_wr_en;
   wire 		       j_wr_en, j_rd_en, reg_en_sig, j_status;
   

  //Assign statements
  assign j_wr_en = (wr_intf & wr_enab);

  assign j_rd_en = (wr_intf & (!wr_enab));

  assign reg_en_sig = c_wr_en || c_rd_en;

  assign reg_en = reg_en_sig;

  assign reg_wr_en = c_wr_en;

  assign opcod = reg_opcod;

  //assign status = d_reg_en && (!c_rd_ack);

  //Sync rd_en to core clock
  toggle_sync sync_rd_en(
    .src_rst_n(trst_n),  // Source domain reset
    .src_clk(tck),  // Source clock
    .dst_clk(core_clk),  // Destination clock 
    .dst_rst_n(core_rst_n),  // Destination reset
    .src_enb(j_rd_en),  // Enable signal in Source clock domain
    .dst_enb(c_rd_en)  // Enable signal in destination clock domain
);



  //Sync wr_en to core clock
  toggle_sync sync_wr_enb(
    .src_rst_n(trst_n),  // Source domain reset
    .src_clk(tck),  // Source clock
    .dst_clk(core_clk),  // Destination clock 
    .dst_rst_n(core_rst_n),  // Destination reset
    .src_enb(j_wr_en),  // Enable signal in Source clock domain
    .dst_enb(c_wr_en)  // Enable signal in destination clock domain
);


  // Storing wr_data when wr_enable is available
  always @ (posedge tck or negedge trst_n)
    if(!trst_n)
      c_wr_data <= 32'b0;
    else if (wr_enab)
      c_wr_data <= j_wr_data;
    
  // Storing wr_addr when wr_enab is available
  always @ (posedge tck or negedge trst_n)
    if(!trst_n)
      c_wr_addr <= 32'b0;
    else if (wr_intf)
      c_wr_addr <= j_wr_addr;
    

  // Storing read data when rd_ack is available
  always @ (posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
      j_rd_data <= 32'b0;
    else if(c_rd_ack)
      j_rd_data <= c_rd_data;


  // Delay assignment of Reg_en
  always @ (posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
      d_reg_en <= 1'b0;
    else 
      d_reg_en <= reg_en_sig;
  

  // Sts opcode assignment in core clock domain to sample in tck
  always @ (posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
      sts_opc <= 2'b0;
    else if(d_reg_en && (!c_rd_ack))
      sts_opc <= 2'b10;
    else if(reg_en_sig)
      sts_opc <= 2'b0;


  //Sync status to tck
  toggle_sync sync_status(
    .src_rst_n(core_rst_n),  // Source domain reset
    .src_clk(core_clk),  // Source clock
    .dst_clk(tck),  // Destination clock 
    .dst_rst_n(trst_n),  // Destination reset
    .src_enb(d_reg_en),  // Enable signal in Source clock domain
    .dst_enb(j_status)  // Enable signal in destination clock domain
);



  // State assignment for opcode assignment
  always @ (posedge tck or negedge trst_n)
    if(!trst_n)
      state <= IDLE;
    else
      state <= n_state;

  // Opcod assignment
  always @ (posedge tck or negedge trst_n)
    if(!trst_n)
      reg_opcod <= 2'b0;
    else
      reg_opcod <= sig_opcod;

  

  // State machine for opcode assignment
  always @ (*)
    begin
      case(state)
        IDLE : begin
                 if(wr_intf)
	           begin
                     sig_opcod = 2'b11;
                     n_state = TRANS;
		   end
                 else
		   begin
                     sig_opcod = 2'b0;
          	     n_state = IDLE;
		   end
                end
         FAIL : begin
                 if(dmireset)
	           begin
                     sig_opcod = 2'b0;
           	     n_state = IDLE;
		   end
                 else
		   begin
                     sig_opcod = 2'b10;
          	     n_state = FAIL;
		   end
                end
        TRANS : begin
          	   if(j_status && (sts_opc == 2'b10))
	             begin
                     sig_opcod = 2'b10;
                       n_state = FAIL;
		     end
                   else if (j_status && (sts_opc == 2'b00))
	             begin
                       sig_opcod = 2'b00;
          	       n_state =  IDLE;
		     end
                   else
	             begin
                       sig_opcod = 2'b11;
                       n_state = TRANS;
		     end
                end
        default : begin
                    sig_opcod = opcod;
          	    n_state = state;
                  end
      endcase
  end


endmodule
