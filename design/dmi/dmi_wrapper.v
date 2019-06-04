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
//                Wrapper module for JTAG_TAP and DMI synchronizer
//
//-------------------------------------------------------------------------------------

module dmi_wrapper(
  // JTAG signals
  input              trst_n,                // JTAG clock
  input              tck,                 // JTAG reset
  input              tms,                 // Test mode select   
  input              tdi,                 // Test Data Input
  output             tdo,                 // Test Data Output           
  output             tdoEnable,           // Test Data Output enable             

  // Processor Signals
  input scan_mode, 
  input              core_rst_n,            // Core clock                  
  input              core_clk,            // Core reset                  
  input [31:0]       rd_data,             // 32 bit Read data from  Processor                       
  input              reg_ack,             // Acknowledgement signal from Processor                     
  output [31:0]      reg_wr_data,         // 32 bit Write data to Processor                      
  output [31:0]      reg_wr_addr,         // 32 bit Write address to Processor                   
  output             reg_en,              // 1 bit  Write interface bit to Processor                                    
  output             reg_wr_en,            // 1 bit  Write enable to Processor 
  output             dmi_hard_reset  
);


  
  parameter DEVICE_ID_VAL = 32'b00000000000000000000000000000001;


  //Wire Declaration
  wire [31:0]              j_wr_data;
  wire [31:0]              j_wr_addr;
  wire                     wr_intf;
  wire                     wr_enab;
  wire [31:0]              j_rd_data;
  wire [1:0]               sts_opcod;
  wire                     dmireset;

   wire [31:0] j_wr_data_OS, j_wr_addr_OS;
   wire tdo_OS, tdoEnable_OS, wr_intf_OS, wr_enab_OS, dmireset_OS, dmi_hard_reset_OS;

   assign j_wr_data[31:0] = j_wr_data_OS;
   assign j_wr_addr[31:0] = j_wr_addr_OS;
   assign tdo = tdo_OS; 
   assign tdoEnable = tdoEnable_OS; 
   assign wr_intf = wr_intf_OS; 
   assign wr_enab = wr_enab_OS;
   assign dmireset = dmireset_OS;
   assign dmi_hard_reset = dmi_hard_reset_OS;
 
 rvjtag_tap #(.DEVICE_ID_VAL(DEVICE_ID_VAL)) i_rvjtag_tap(
   .scan_mode(scan_mode),
   .trst(trst_n),                        // dedicated JTAG TRST (active low) pad signal or asynchronous active low power on reset
   .tck(tck),                          // dedicated JTAG TCK pad signal
   .tms(tms),                          // dedicated JTAG TMS pad signal
   .tdi(tdi),                          // dedicated JTAG TDI pad signal
   .tdo(tdo_OS),                          // dedicated JTAG TDO pad signal
   .tdoEnable(tdoEnable_OS),              // enable for TDO pad
   .wr_data(j_wr_data_OS),                // 32 bit Write data
   .wr_addr(j_wr_addr_OS),                // 32 bit Write address
   .wr_intf(wr_intf_OS),                  // 1 bit  Write interface bit
   .wr_enab(wr_enab_OS),                  // 1 bit  Write enable
   .rd_data(j_rd_data),                // 32 bit Read data
   .rd_status(sts_opcod),                   // 1 bit Read ack
   .idle(3'h0),
   .dmi_stat(sts_opcod),
   .abits(6'h20),
   .version(4'h1),
   .dmi_hard_reset(dmi_hard_reset_OS),
   .dmi_reset(dmireset_OS)
);
   
 
  // dmi_jtag_to_core_sync instantiation
  dmi_jtag_to_core_sync i_dmi_jtag_to_core_sync(
    .trst_n(trst_n),
    .dmireset(dmireset),
    .tck(tck),
    .wr_intf(wr_intf),                          // 1 bit  Write interface bit
    .wr_enab(wr_enab),                          // 1 bit  Write enable
    .j_wr_data(j_wr_data),                      // 32 bit Write data
    .j_wr_addr(j_wr_addr),                      // 32 bit Write address

    .j_rd_data(j_rd_data),                      // 32 bit Read data
    .opcod(sts_opcod),                         // Read ack synhcronized to TCK

    .core_rst_n(core_rst_n),
    .core_clk(core_clk),
    
    .c_rd_data(rd_data),                      // 32 bit Read data
    .c_rd_ack(reg_ack),                        // Read ack from core clock

    .c_wr_data(reg_wr_data),                      // 32 bit Write data
    .c_wr_addr(reg_wr_addr),                      // 32 bit Write address
    .reg_en(reg_en),                          // 1 bit  Write interface bit
    .reg_wr_en(reg_wr_en)                          // 1 bit  Write enable
  );

endmodule
