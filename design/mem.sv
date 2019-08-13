//********************************************************************************
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

module mem 
   import swerv_types::*;
(
   input logic         clk,
   input logic         rst_l,
   input logic         lsu_freeze_dc3,
   input logic         dccm_clk_override,
   input logic         icm_clk_override,
   input logic         dec_tlu_core_ecc_disable, 
                                            
   //DCCM ports
   input logic         dccm_wren,
   input logic         dccm_rden,
   input logic [`RV_DCCM_BITS-1:0]  dccm_wr_addr,
   input logic [`RV_DCCM_BITS-1:0]  dccm_rd_addr_lo,
   input logic [`RV_DCCM_BITS-1:0]  dccm_rd_addr_hi,
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_wr_data,


   output logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo,
   output logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi,


`ifdef RV_ICCM_ENABLE
   //ICCM ports
   input logic [`RV_ICCM_BITS-1:2]  iccm_rw_addr,
   input logic         iccm_wren,
   input logic         iccm_rden,
   input logic [2:0]   iccm_wr_size,
   input logic [77:0]  iccm_wr_data,
                      
   output logic [155:0] iccm_rd_data,
`endif
   // Icache and Itag Ports
`ifdef RV_ICACHE_ENABLE //temp
   input  logic [31:3]  ic_rw_addr,
   input  logic [3:0]   ic_tag_valid,
   input  logic [3:0]   ic_wr_en,
   input  logic         ic_rd_en,
   input  logic [127:0] ic_premux_data,     // Premux data to be muxed with each way of the Icache. 
   input  logic         ic_sel_premux_data, // Premux data sel 

`ifdef RV_ICACHE_ECC
   input  logic [83:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [41:0]               ic_debug_wr_data,   // Debug wr cache. 
`else 
   input  logic [67:0]               ic_wr_data,         // Data to fill to the Icache. With Parity
   input  logic [33:0]               ic_debug_wr_data,   // Debug wr cache. 
`endif



   input  logic [15:2]               ic_debug_addr,      // Read/Write addresss to the Icache.   
   input  logic                      ic_debug_rd_en,     // Icache debug rd
   input  logic                      ic_debug_wr_en,     // Icache debug wr
   input  logic                      ic_debug_tag_array, // Debug tag array
   input  logic [3:0]                ic_debug_way,       // Debug way. Rd or Wr.

`endif
   
`ifdef RV_ICACHE_ECC
   output logic [167:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   output logic [24:0]               ictag_debug_rd_data,// Debug icache tag. 
`else 
   output logic [135:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With Parity
   output logic [20:0]               ictag_debug_rd_data,// Debug icache tag. 
`endif

   output logic [3:0]   ic_rd_hit,
   output logic         ic_tag_perr,        // Icache Tag parity error

  
   input  logic         scan_mode   
  
);
`include "global.h"
   
 `ifdef RV_DCCM_ENABLE
      localparam DCCM_ENABLE = 1'b1;
   `else
      localparam DCCM_ENABLE = 1'b0;
   `endif

   // DCCM Instantiation
   if (DCCM_ENABLE == 1) begin: Gen_dccm_enable
      lsu_dccm_mem dccm (
         .clk_override(dccm_clk_override),
         .*
      );
   end else begin: Gen_dccm_disable
      assign dccm_rd_data_lo = '0;
      assign dccm_rd_data_hi = '0;
   end
     
`ifdef RV_ICACHE_ENABLE   
   ifu_ic_mem icm  (
      .clk_override(icm_clk_override),
      .*
   );
`else
   assign   ic_rd_hit[3:0] = '0;
   assign   ic_tag_perr    = '0 ;
   assign   ic_rd_data  = '0 ;
   assign   ictag_debug_rd_data  = '0 ;
`endif

`ifdef RV_ICCM_ENABLE
   ifu_iccm_mem iccm (.*,
                  .clk_override(icm_clk_override),
                  .iccm_rw_addr(iccm_rw_addr[`RV_ICCM_BITS-1:2]),
                  .iccm_rd_data(iccm_rd_data[155:0])
                   );
`endif
  
endmodule
