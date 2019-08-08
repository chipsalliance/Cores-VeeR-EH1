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
  input              scan_mode,           // scan mode

  // JTAG signals
  input              trst_n,              // JTAG reset
  input              tck,                 // JTAG clock
  input              tms,                 // Test mode select   
  input              tdi,                 // Test Data Input
  output             tdo,                 // Test Data Output           
  output             tdoEnable,           // Test Data Output enable             

  // Processor Signals
  input              core_rst_n,          // Core reset                  
  input              core_clk,            // Core clock                  
  input [31:1]       jtag_id,             // JTAG ID
  input [31:0]       rd_data,             // 32 bit Read data from  Processor                       
  output [31:0]      reg_wr_data,         // 32 bit Write data to Processor                      
  output [6:0]       reg_wr_addr,         // 7 bit reg address to Processor                   
  output             reg_en,              // 1 bit  Read enable to Processor                                    
  output             reg_wr_en,           // 1 bit  Write enable to Processor 
  output             dmi_hard_reset  
);


  


  //Wire Declaration
  wire                     rd_en;
  wire                     wr_en;
  wire                     dmireset;

 
  //jtag_tap instantiation
 rvjtag_tap i_jtag_tap(
   .trst(trst_n),                      // dedicated JTAG TRST (active low) pad signal or asynchronous active low power on reset
   .tck(tck),                          // dedicated JTAG TCK pad signal
   .tms(tms),                          // dedicated JTAG TMS pad signal
   .tdi(tdi),                          // dedicated JTAG TDI pad signal
   .tdo(tdo),                          // dedicated JTAG TDO pad signal
   .tdoEnable(tdoEnable),              // enable for TDO pad
   .wr_data(reg_wr_data),              // 32 bit Write data
   .wr_addr(reg_wr_addr),              // 7 bit Write address
   .rd_en(rd_en),                      // 1 bit  read enable
   .wr_en(wr_en),                      // 1 bit  Write enable
   .rd_data(rd_data),                  // 32 bit Read data
   .rd_status(2'b0),
   .idle(3'h0),                         // no need to wait to sample data
   .dmi_stat(2'b0),                     // no need to wait or error possible
   .version(4'h1),                      // debug spec 0.13 compliant
   .jtag_id(jtag_id),
   .dmi_hard_reset(dmi_hard_reset),
   .dmi_reset(dmireset)
);


  // dmi_jtag_to_core_sync instantiation
  dmi_jtag_to_core_sync i_dmi_jtag_to_core_sync(
    .wr_en(wr_en),                          // 1 bit  Write enable
    .rd_en(rd_en),                          // 1 bit  Read enable

    .rst_n(core_rst_n),
    .clk(core_clk),
    .reg_en(reg_en),                          // 1 bit  Write interface bit
    .reg_wr_en(reg_wr_en)                          // 1 bit  Write enable
  );

endmodule
