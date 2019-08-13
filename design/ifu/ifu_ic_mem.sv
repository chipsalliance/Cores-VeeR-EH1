//********************************************************************************
// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or it's affiliates.
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
////////////////////////////////////////////////////
//   ICACHE DATA & TAG MODULE WRAPPER              //
/////////////////////////////////////////////////////
module ifu_ic_mem  
  (
      input logic clk,
      input logic rst_l,
      input logic clk_override,
      input logic dec_tlu_core_ecc_disable, 

      input logic [31:3]  ic_rw_addr,   
      input logic [3:0]   ic_wr_en  ,  // Which way to write
      input logic         ic_rd_en  ,  // Read enable

      input logic [15:2]               ic_debug_addr,      // Read/Write addresss to the Icache.   
      input logic                      ic_debug_rd_en,     // Icache debug rd
      input logic                      ic_debug_wr_en,     // Icache debug wr
      input logic                      ic_debug_tag_array, // Debug tag array
      input logic [3:0]                ic_debug_way,       // Debug way. Rd or Wr.
      input logic [127:0]              ic_premux_data,     // Premux data to be muxed with each way of the Icache. 
      input logic                      ic_sel_premux_data, // Select the pre_muxed data



`ifdef RV_ICACHE_ECC
      input  logic [83:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
      output logic [167:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
      output logic [24:0]               ictag_debug_rd_data,// Debug icache tag. 
      input logic  [41:0]               ic_debug_wr_data,   // Debug wr cache. 
`else 
      input  logic [67:0]               ic_wr_data,         // Data to fill to the Icache. With Parity
      output logic [135:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With Parity
      output logic [20:0]               ictag_debug_rd_data,// Debug icache tag. 
      input logic  [33:0]               ic_debug_wr_data,   // Debug wr cache. 
`endif


      input logic [3:0]   ic_tag_valid,  // Valid from the I$ tag valid outside (in flops). 
      
      output logic [3:0]   ic_rd_hit,   // ic_rd_hit[3:0]
      output logic         ic_tag_perr, // Tag Parity error
      input  logic         scan_mode 
      ) ;

`include "global.h"   
   
   IC_TAG #( .ICACHE_TAG_HIGH(ICACHE_TAG_HIGH) ,
             .ICACHE_TAG_LOW(ICACHE_TAG_LOW) , 
             .ICACHE_TAG_DEPTH(ICACHE_TAG_DEPTH)  
             ) ic_tag_inst
          (
           .*,
           .ic_wr_en     (ic_wr_en[3:0]), 
           .ic_debug_addr(ic_debug_addr[ICACHE_TAG_HIGH-1:2]),
           .ic_rw_addr   (ic_rw_addr[31:3])
           ) ;
   
   IC_DATA #( .ICACHE_TAG_HIGH(ICACHE_TAG_HIGH) ,
              .ICACHE_TAG_LOW(ICACHE_TAG_LOW) , 
              .ICACHE_IC_DEPTH(ICACHE_IC_DEPTH)  
             ) ic_data_inst
          (
           .*,
           .ic_wr_en     (ic_wr_en[3:0]), 
           .ic_debug_addr(ic_debug_addr[ICACHE_TAG_HIGH-1:2]),
           .ic_rw_addr   (ic_rw_addr[ICACHE_TAG_HIGH-1:3])
           ) ;
   
 endmodule


/////////////////////////////////////////////////
////// ICACHE DATA MODULE    ////////////////////
/////////////////////////////////////////////////
module IC_DATA #(parameter ICACHE_TAG_HIGH = 16 ,
                           ICACHE_TAG_LOW=6 , 
                           ICACHE_IC_DEPTH=1024   
                                        ) 
     (
      input logic clk,
      input logic rst_l,
      input logic clk_override,

      input logic [ICACHE_TAG_HIGH-1:3]  ic_rw_addr,
      input logic [3:0]                  ic_wr_en,
      input logic                        ic_rd_en,  // Read enable
`ifdef RV_ICACHE_ECC
      input  logic [83:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
      output logic [167:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
      input  logic [41:0]               ic_debug_wr_data,   // Debug wr cache. 
`else 
      input  logic [67:0]               ic_wr_data,         // Data to fill to the Icache. With Parity
      output logic [135:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With Parity
      input  logic [33:0]               ic_debug_wr_data,   // Debug wr cache. 
`endif


      input logic [ICACHE_TAG_HIGH-1:2]  ic_debug_addr,      // Read/Write addresss to the Icache.   
      input logic                        ic_debug_rd_en,     // Icache debug rd
      input logic                        ic_debug_wr_en,     // Icache debug wr
      input logic                        ic_debug_tag_array, // Debug tag array
      input logic [3:0]                  ic_debug_way,       // Debug way. Rd or Wr.
      input logic [127:0]                ic_premux_data,     // Premux data to be muxed with each way of the Icache. 
      input logic                        ic_sel_premux_data, // Select the pre_muxed data

      input logic [3:0]          ic_rd_hit,
      
      input  logic               scan_mode

      ) ;
   
   logic [5:4]             ic_rw_addr_ff;


   logic [3:0][3:0]       ic_b_sb_wren;    // way, bank

   logic                   ic_debug_sel_sb0 ;
   logic                   ic_debug_sel_sb1 ;
   logic                   ic_debug_sel_sb2 ;
   logic                   ic_debug_sel_sb3 ;

                           
`ifdef RV_ICACHE_ECC
   logic [3:0] [167:0]     bank_set_dout;
   logic [3:0][167:0]      wb_dout ; //
   logic [3:0][41:0]       ic_sb_wr_data;
`else
   logic [3:0] [135:0]     bank_set_dout;
   logic [3:0] [135:0]     wb_dout ; // bank , way , size 
   logic [3:0] [33:0]      ic_sb_wr_data;
`endif
                           
   logic [3:0]              ic_bank_way_clken;    // bank , way
   logic [3:0]             ic_bank_way_clk  ;    // bank , way
   logic                   ic_b_rden;
   logic [3:0]             ic_debug_rd_way_en;   // debug wr_way
   logic [3:0]             ic_debug_rd_way_en_ff;   // debug wr_way
   logic [3:0]             ic_debug_wr_way_en;   // debug wr_way
   logic [ICACHE_TAG_HIGH-1:4]  ic_rw_addr_q;
   
   assign  ic_debug_rd_way_en[3:0] =  {4{ic_debug_rd_en & ~ic_debug_tag_array}} & ic_debug_way[3:0] ;
   assign  ic_debug_wr_way_en[3:0] =  {4{ic_debug_wr_en & ~ic_debug_tag_array}} & ic_debug_way[3:0] ;

   assign  ic_b_sb_wren[0][3:0]  = (ic_wr_en[3:0]           & {4{~ic_rw_addr[3]}} ) |           
                                   (ic_debug_wr_way_en[3:0] & {4{ic_debug_addr[3:2] == 2'b00}}) ;           
   assign  ic_b_sb_wren[1][3:0]  = (ic_wr_en[3:0]           & {4{~ic_rw_addr[3]}} ) |           
                                   (ic_debug_wr_way_en[3:0] & {4{ic_debug_addr[3:2] == 2'b01}}) ;           
   assign  ic_b_sb_wren[2][3:0]  = (ic_wr_en[3:0]           & {4{ic_rw_addr[3]}} ) |           
                                   (ic_debug_wr_way_en[3:0] & {4{ic_debug_addr[3:2] == 2'b10}}) ;           
   assign  ic_b_sb_wren[3][3:0]  = (ic_wr_en[3:0]           & {4{ic_rw_addr[3]}} ) |           
                                   (ic_debug_wr_way_en[3:0] & {4{ic_debug_addr[3:2] == 2'b11}}) ;           

   assign  ic_debug_sel_sb0       =  (ic_debug_addr[3:2] == 2'b00 ) ; 
   assign  ic_debug_sel_sb1       =  (ic_debug_addr[3:2] == 2'b01 ) ; 
   assign  ic_debug_sel_sb2       =  (ic_debug_addr[3:2] == 2'b10 ) ; 
   assign  ic_debug_sel_sb3       =  (ic_debug_addr[3:2] == 2'b11 ) ; 

`ifdef RV_ICACHE_ECC

   assign  ic_sb_wr_data[0][41:0]   =  (ic_debug_sel_sb0 & ic_debug_wr_en) ? {ic_debug_wr_data[41:0]} : 
                                                                             ic_wr_data[41:0] ;
   assign  ic_sb_wr_data[1][41:0]   =  (ic_debug_sel_sb1 & ic_debug_wr_en) ? {ic_debug_wr_data[41:0]} : 
                                                                             ic_wr_data[83:42] ;
   assign  ic_sb_wr_data[2][41:0]   =  (ic_debug_sel_sb2 & ic_debug_wr_en) ? {ic_debug_wr_data[41:0]} : 
                                                                             ic_wr_data[41:0] ;
   assign  ic_sb_wr_data[3][41:0]   =  (ic_debug_sel_sb3 & ic_debug_wr_en) ? {ic_debug_wr_data[41:0]} : 
                                                                             ic_wr_data[83:42] ;
`else 
   assign  ic_sb_wr_data[0][33:0]   =  (ic_debug_sel_sb0 & ic_debug_wr_en) ? ic_debug_wr_data[33:0] : 
                                                                             ic_wr_data[33:0] ;
   assign  ic_sb_wr_data[1][33:0]   =  (ic_debug_sel_sb1 & ic_debug_wr_en) ? ic_debug_wr_data[33:0] : 
                                                                             ic_wr_data[67:34] ;
   assign  ic_sb_wr_data[2][33:0]   =  (ic_debug_sel_sb2 & ic_debug_wr_en) ? ic_debug_wr_data[33:0] : 
                                                                             ic_wr_data[33:0] ;
   assign  ic_sb_wr_data[3][33:0]   =  (ic_debug_sel_sb3 & ic_debug_wr_en) ? ic_debug_wr_data[33:0] : 
                                                                             ic_wr_data[67:34] ;
`endif


// bank read enables

   assign  ic_b_rden       = (ic_rd_en   | ic_debug_rd_en );           
         
   assign  ic_bank_way_clken[3:0]   = ({4{ic_b_rden | clk_override }}) | 
                                      ic_b_sb_wren[0][3:0] |
                                      ic_b_sb_wren[1][3:0] |
                                      ic_b_sb_wren[2][3:0] |
                                      ic_b_sb_wren[3][3:0] ;


 
    assign ic_rw_addr_q[ICACHE_TAG_HIGH-1:4] = (ic_debug_rd_en | ic_debug_wr_en) ?
                                                ic_debug_addr[ICACHE_TAG_HIGH-1:4] : 
                                                ic_rw_addr[ICACHE_TAG_HIGH-1:4] ;

   logic ic_debug_rd_en_ff;

   rvdff #(2) adr_ff (.*, 
                    .din ({ic_rw_addr_q[5:4]}), 
                    .dout({ic_rw_addr_ff[5:4]}));

   rvdff #(5) debug_rd_wy_ff (.*, 
                    .din ({ic_debug_rd_way_en[3:0], ic_debug_rd_en}), 
                    .dout({ic_debug_rd_way_en_ff[3:0], ic_debug_rd_en_ff}));

localparam NUM_WAYS=4 ;
localparam NUM_SUBBANKS=4 ;   


     for (genvar i=0; i<NUM_WAYS; i++) begin: WAYS

        rvoclkhdr bank_way_c1_cgc  ( .en(ic_bank_way_clken[i]), .l1clk(ic_bank_way_clk[i]), .* );

        for (genvar k=0; k<NUM_SUBBANKS; k++) begin: SUBBANKS   // 16B subbank

        `ifdef RV_ICACHE_ECC
         `RV_ICACHE_DATA_CELL  ic_bank_sb_way_data (                                 
                                     .CLK(ic_bank_way_clk[i]),
                                     .WE (ic_b_sb_wren[k][i]),
                                     .D  (ic_sb_wr_data[k][41:0]),
                                     .ADR(ic_rw_addr_q[ICACHE_TAG_HIGH-1:4]),
                                     .Q  (wb_dout[i][(k+1)*42-1:k*42])
                                    );
        `else
         `RV_ICACHE_DATA_CELL  ic_bank_sb_way_data (                                 
                                     .CLK(ic_bank_way_clk[i]),
                                     .WE (ic_b_sb_wren[k][i]),
                                     .D  (ic_sb_wr_data[k][33:0]),
                                     .ADR(ic_rw_addr_q[ICACHE_TAG_HIGH-1:4]),
                                     .Q  (wb_dout[i][(k+1)*34-1:k*34])
                                    );
        `endif
        end // block: SUBBANKS
        
      end  
 

   logic [3:0] ic_rd_hit_q;
   assign ic_rd_hit_q[3:0] = ic_debug_rd_en_ff ? ic_debug_rd_way_en_ff[3:0] : ic_rd_hit[3:0] ;

   // set mux
`ifdef RV_ICACHE_ECC
   logic [167:0] ic_premux_data_ext; 
   logic [3:0] [167:0] wb_dout_way;
   logic [3:0] [167:0] wb_dout_way_with_premux;

   assign ic_premux_data_ext[167:0] =  {10'b0,ic_premux_data[127:96],10'b0,ic_premux_data[95:64] ,10'b0,ic_premux_data[63:32],10'b0,ic_premux_data[31:0]};
   assign wb_dout_way[0][167:0]       = wb_dout[0][167:0];
   assign wb_dout_way[1][167:0]       = wb_dout[1][167:0];
   assign wb_dout_way[2][167:0]       = wb_dout[2][167:0];
   assign wb_dout_way[3][167:0]       = wb_dout[3][167:0];


   assign wb_dout_way_with_premux[0][167:0]  =  ic_sel_premux_data ? ic_premux_data_ext[167:0] : wb_dout_way[0][167:0] ;
   assign wb_dout_way_with_premux[1][167:0]  =  ic_sel_premux_data ? ic_premux_data_ext[167:0] : wb_dout_way[1][167:0] ;
   assign wb_dout_way_with_premux[2][167:0]  =  ic_sel_premux_data ? ic_premux_data_ext[167:0] : wb_dout_way[2][167:0] ;
   assign wb_dout_way_with_premux[3][167:0]  =  ic_sel_premux_data ? ic_premux_data_ext[167:0] : wb_dout_way[3][167:0] ;

   assign ic_rd_data[167:0]       = ({168{ic_rd_hit_q[0] | ic_sel_premux_data}} &  wb_dout_way_with_premux[0][167:0]) |
                                    ({168{ic_rd_hit_q[1] | ic_sel_premux_data}} &  wb_dout_way_with_premux[1][167:0]) |
                                    ({168{ic_rd_hit_q[2] | ic_sel_premux_data}} &  wb_dout_way_with_premux[2][167:0]) |
                                    ({168{ic_rd_hit_q[3] | ic_sel_premux_data}} &  wb_dout_way_with_premux[3][167:0]) ;

`else
   logic       [135:0] ic_premux_data_ext; 
   logic [3:0] [135:0] wb_dout_way;
   logic [3:0] [135:0] wb_dout_way_with_premux;

   assign ic_premux_data_ext[135:0]   = {2'b0,ic_premux_data[127:96],2'b0,ic_premux_data[95:64] ,2'b0,ic_premux_data[63:32],2'b0,ic_premux_data[31:0]};
   assign wb_dout_way[0][135:0]       = wb_dout[0][135:0];
   assign wb_dout_way[1][135:0]       = wb_dout[1][135:0];
   assign wb_dout_way[2][135:0]       = wb_dout[2][135:0];
   assign wb_dout_way[3][135:0]       = wb_dout[3][135:0];
   
   assign wb_dout_way_with_premux[0][135:0]  =  ic_sel_premux_data ? ic_premux_data_ext[135:0] : wb_dout_way[0][135:0] ;
   assign wb_dout_way_with_premux[1][135:0]  =  ic_sel_premux_data ? ic_premux_data_ext[135:0] : wb_dout_way[1][135:0] ;
   assign wb_dout_way_with_premux[2][135:0]  =  ic_sel_premux_data ? ic_premux_data_ext[135:0] : wb_dout_way[2][135:0] ;
   assign wb_dout_way_with_premux[3][135:0]  =  ic_sel_premux_data ? ic_premux_data_ext[135:0] : wb_dout_way[3][135:0] ;

   assign ic_rd_data[135:0]       = ({136{ic_rd_hit_q[0] | ic_sel_premux_data}} &  wb_dout_way_with_premux[0][135:0]) |
                                    ({136{ic_rd_hit_q[1] | ic_sel_premux_data}} &  wb_dout_way_with_premux[1][135:0]) |
                                    ({136{ic_rd_hit_q[2] | ic_sel_premux_data}} &  wb_dout_way_with_premux[2][135:0]) |
                                    ({136{ic_rd_hit_q[3] | ic_sel_premux_data}} &  wb_dout_way_with_premux[3][135:0]) ;

`endif
   
 endmodule


/////////////////////////////////////////////////
////// ICACHE TAG MODULE     ////////////////////
/////////////////////////////////////////////////
module IC_TAG #(parameter ICACHE_TAG_HIGH = 16 ,
                          ICACHE_TAG_LOW=6 , 
                          ICACHE_TAG_DEPTH=1024  
                                        ) 
     (
      input logic clk,
      input logic rst_l,
      input logic clk_override,
      input logic dec_tlu_core_ecc_disable, 

      input logic [31:3]  ic_rw_addr,

      input logic [3:0]   ic_wr_en,  // way
      input logic [3:0]   ic_tag_valid,
      input logic         ic_rd_en,
      
      input logic [ICACHE_TAG_HIGH-1:2]  ic_debug_addr,      // Read/Write addresss to the Icache.   
      input logic                        ic_debug_rd_en,     // Icache debug rd
      input logic                        ic_debug_wr_en,     // Icache debug wr
      input logic                        ic_debug_tag_array, // Debug tag array
      input logic [3:0]                  ic_debug_way,       // Debug way. Rd or Wr.



      
`ifdef RV_ICACHE_ECC
      output logic [24:0]  ictag_debug_rd_data,
      input  logic [41:0]  ic_debug_wr_data,   // Debug wr cache. 
`else
      output logic [20:0]  ictag_debug_rd_data,
      input  logic [33:0]  ic_debug_wr_data,   // Debug wr cache. 
`endif
      output logic [3:0]   ic_rd_hit,
      output logic         ic_tag_perr, 
      input  logic         scan_mode 

      ) ;
   
`ifdef RV_ICACHE_ECC
   logic [3:0] [24:0] ic_tag_data_raw;
   logic [3:0] [37:ICACHE_TAG_HIGH] w_tout;
   logic [24:0] ic_tag_wr_data ;
   logic [3:0] [31:0] ic_tag_corrected_data_unc;
   logic [3:0] [06:0] ic_tag_corrected_ecc_unc;
   logic [3:0]        ic_tag_single_ecc_error;
   logic [3:0]        ic_tag_double_ecc_error;
`else
   logic [3:0] [20:0] ic_tag_data_raw;
   logic [3:0] [32:ICACHE_TAG_HIGH] w_tout;
   logic [20:0] ic_tag_wr_data ;
`endif

   logic [3:0]  ic_tag_way_perr ;
   logic [3:0]  ic_debug_rd_way_en ;
   logic [3:0]  ic_debug_rd_way_en_ff ;

   logic [ICACHE_TAG_HIGH-1:6]  ic_rw_addr_q;
   logic [31:4]         ic_rw_addr_ff;
   logic [3:0]          ic_tag_wren   ; // way
   logic [3:0]          ic_tag_wren_q   ; // way
   logic [3:0]          ic_tag_clk ;
   logic [3:0]          ic_tag_clken ;
   logic [3:0]          ic_debug_wr_way_en;   // debug wr_way

   assign  ic_tag_wren [3:0]  = ic_wr_en[3:0] & {4{ic_rw_addr[5:3] == 3'b111}} ;           
   assign  ic_tag_clken[3:0]  = {4{ic_rd_en | clk_override}} | ic_wr_en[3:0] | ic_debug_wr_way_en[3:0] | ic_debug_rd_way_en[3:0];

   rvdff #(32-ICACHE_TAG_HIGH) adr_ff (.*, 
                    .din ({ic_rw_addr[31:ICACHE_TAG_HIGH]}), 
                    .dout({ic_rw_addr_ff[31:ICACHE_TAG_HIGH]}));

   
   localparam TOP_BITS = 21+ICACHE_TAG_HIGH-33 ;
   localparam NUM_WAYS=4 ;
   // tags 
 


   assign  ic_debug_rd_way_en[3:0] =  {4{ic_debug_rd_en & ic_debug_tag_array}} & ic_debug_way[3:0] ;
   assign  ic_debug_wr_way_en[3:0] =  {4{ic_debug_wr_en & ic_debug_tag_array}} & ic_debug_way[3:0] ;

   assign  ic_tag_wren_q[3:0]  =  ic_tag_wren[3:0]          |           
                                  ic_debug_wr_way_en[3:0]   ;

if (ICACHE_TAG_HIGH == 12) begin: SMALLEST
 `ifdef RV_ICACHE_ECC
     logic [6:0] ic_tag_ecc;
           rvecc_encode  tag_ecc_encode (
                                  .din    ({{ICACHE_TAG_HIGH{1'b0}}, ic_rw_addr[31:ICACHE_TAG_HIGH]}), 
                                  .ecc_out({ ic_tag_ecc[6:0]})); 

   assign  ic_tag_wr_data[24:0] = (ic_debug_wr_en & ic_debug_tag_array) ? 
                                  {ic_debug_wr_data[36:32], ic_debug_wr_data[31:12]} : 
                                  {ic_tag_ecc[4:0], ic_rw_addr[31:ICACHE_TAG_HIGH]} ;
 `else
   logic   ic_tag_parity ; 
           rveven_paritygen #(32-ICACHE_TAG_HIGH) pargen  (.data_in   (ic_rw_addr[31:ICACHE_TAG_HIGH]), 
                                                 .parity_out(ic_tag_parity)); 

   assign  ic_tag_wr_data[20:0] = (ic_debug_wr_en & ic_debug_tag_array) ? 
                                  {ic_debug_wr_data[32], ic_debug_wr_data[31:12]} : 
                                  {ic_tag_parity, ic_rw_addr[31:ICACHE_TAG_HIGH]} ;
 `endif
end else begin: OTHERS
 `ifdef RV_ICACHE_ECC
   logic [6:0] ic_tag_ecc;
           rvecc_encode  tag_ecc_encode (
                                  .din    ({{ICACHE_TAG_HIGH{1'b0}}, ic_rw_addr[31:ICACHE_TAG_HIGH]}), 
                                  .ecc_out({ ic_tag_ecc[6:0]})); 

   assign  ic_tag_wr_data[24:0] = (ic_debug_wr_en & ic_debug_tag_array) ? 
                                  {ic_debug_wr_data[36:32], ic_debug_wr_data[31:12]} : 
                                  {ic_tag_ecc[4:0], {TOP_BITS{1'b0}},ic_rw_addr[31:ICACHE_TAG_HIGH]} ;

 `else
   logic   ic_tag_parity ; 
           rveven_paritygen #(32-ICACHE_TAG_HIGH) pargen  (.data_in   (ic_rw_addr[31:ICACHE_TAG_HIGH]), 
                                                 .parity_out(ic_tag_parity)); 
   assign  ic_tag_wr_data[20:0] = (ic_debug_wr_en & ic_debug_tag_array) ? 
                                  {ic_debug_wr_data[32], ic_debug_wr_data[31:12]} : 
                                  {ic_tag_parity, {TOP_BITS{1'b0}},ic_rw_addr[31:ICACHE_TAG_HIGH]} ;
 `endif
end

    assign ic_rw_addr_q[ICACHE_TAG_HIGH-1:6] = (ic_debug_rd_en | ic_debug_wr_en) ?
                                                ic_debug_addr[ICACHE_TAG_HIGH-1:6] : 
                                                ic_rw_addr[ICACHE_TAG_HIGH-1:6] ;


   rvdff #(4) tag_rd_wy_ff (.*, 
                    .din ({ic_debug_rd_way_en[3:0]}), 
                    .dout({ic_debug_rd_way_en_ff[3:0]}));



     
   for (genvar i=0; i<NUM_WAYS; i++) begin: WAYS
   rvclkhdr ic_tag_c1_cgc  ( .en(ic_tag_clken[i]), .l1clk(ic_tag_clk[i]), .* );
     if (ICACHE_TAG_DEPTH == 64 ) begin : ICACHE_SZ_16
      `ifdef RV_ICACHE_ECC
         ram_64x25  ic_way_tag (
                                     .CLK(ic_tag_clk[i]),
                                     .WE (ic_tag_wren_q[i]),
                                     .D  (ic_tag_wr_data[24:0]),
                                     .ADR(ic_rw_addr_q[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]),
                                     .Q  (ic_tag_data_raw[i][24:0])
                                    );
          

         assign w_tout[i][31:ICACHE_TAG_HIGH] = ic_tag_data_raw[i][31-ICACHE_TAG_HIGH:0] ;
         assign w_tout[i][36:32]              = ic_tag_data_raw[i][24:20] ;

         rvecc_decode  ecc_decode (
                           .en(~dec_tlu_core_ecc_disable), 
                           .sed_ded ( 1'b1 ),    // 1 : means only detection
                           .din({12'b0,ic_tag_data_raw[i][19:0]}),
                           .ecc_in({2'b0, ic_tag_data_raw[i][24:20]}),
                           .dout(ic_tag_corrected_data_unc[i][31:0]),
                           .ecc_out(ic_tag_corrected_ecc_unc[i][6:0]),
                           .single_ecc_error(ic_tag_single_ecc_error[i]),
                           .double_ecc_error(ic_tag_double_ecc_error[i]));

          assign ic_tag_way_perr[i]= ic_tag_single_ecc_error[i] | ic_tag_double_ecc_error[i]  ;
      `else
         ram_64x21  ic_way_tag (
                                     .CLK(ic_tag_clk[i]),
                                     .WE (ic_tag_wren_q[i]),
                                     .D  (ic_tag_wr_data[20:0]),
                                     .ADR(ic_rw_addr_q[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]),
                                     .Q  (ic_tag_data_raw[i][20:0])
                                    );

         assign w_tout[i][31:ICACHE_TAG_HIGH] = ic_tag_data_raw[i][31-ICACHE_TAG_HIGH:0] ;
         assign w_tout[i][32]                 = ic_tag_data_raw[i][20] ;

         rveven_paritycheck #(32-ICACHE_TAG_HIGH) parcheck(.data_in   (w_tout[i][31:ICACHE_TAG_HIGH]), 
                                                   .parity_in (w_tout[i][32]),
                                                   .parity_err(ic_tag_way_perr[i])); 
      `endif

   end // block: ICACHE_SZ_16
   
   else begin : tag_not_64    
    `ifdef RV_ICACHE_ECC
     `RV_ICACHE_TAG_CELL  ic_way_tag (
                                     .CLK(ic_tag_clk[i]),
                                     .WE (ic_tag_wren_q[i]),
                                     .D  (ic_tag_wr_data[24:0]),
                                     .ADR(ic_rw_addr_q[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]),
                                     .Q  (ic_tag_data_raw[i][24:0])
                                    );

         assign w_tout[i][31:ICACHE_TAG_HIGH] = ic_tag_data_raw[i][31-ICACHE_TAG_HIGH:0] ;
         assign w_tout[i][36:32]              = ic_tag_data_raw[i][24:20] ;

         rvecc_decode  ecc_decode (
                           .en(~dec_tlu_core_ecc_disable),
                           .sed_ded ( 1'b1 ), // 1 : if only need detection  
                           .din({12'b0,ic_tag_data_raw[i][19:0]}),
                           .ecc_in({2'b0, ic_tag_data_raw[i][24:20]}),
                           .dout(ic_tag_corrected_data_unc[i][31:0]),
                           .ecc_out(ic_tag_corrected_ecc_unc[i][6:0]),
                           .single_ecc_error(ic_tag_single_ecc_error[i]),
                           .double_ecc_error(ic_tag_double_ecc_error[i]));

          assign ic_tag_way_perr[i]= ic_tag_single_ecc_error[i] | ic_tag_double_ecc_error[i]  ;

     `else
        `RV_ICACHE_TAG_CELL  ic_way_tag (
                                     .CLK(ic_tag_clk[i]),
                                     .WE (ic_tag_wren_q[i]),
                                     .D  (ic_tag_wr_data[20:0]),
                                     .ADR(ic_rw_addr_q[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]),
                                     .Q  ({ic_tag_data_raw[i][20:0]})
                                    );

         assign w_tout[i][31:ICACHE_TAG_HIGH] = ic_tag_data_raw[i][31-ICACHE_TAG_HIGH:0] ;
         assign w_tout[i][32]                 = ic_tag_data_raw[i][20] ;

       rveven_paritycheck #(32-ICACHE_TAG_HIGH) parcheck(.data_in   (w_tout[i][31:ICACHE_TAG_HIGH]), 
                                                   .parity_in (w_tout[i][32]),
                                                   .parity_err(ic_tag_way_perr[i])); 

      `endif
   end // block: tag_not_64
end // block: WAYS
   

`ifdef RV_ICACHE_ECC
   assign ictag_debug_rd_data[24:0] =  ({25{ic_debug_rd_way_en_ff[0]}} &  ic_tag_data_raw[0] ) |
                                       ({25{ic_debug_rd_way_en_ff[1]}} &  ic_tag_data_raw[1] ) |
                                       ({25{ic_debug_rd_way_en_ff[2]}} &  ic_tag_data_raw[2] ) |
                                       ({25{ic_debug_rd_way_en_ff[3]}} &  ic_tag_data_raw[3] ) ;
                                                                          
`else                                                                     
   assign ictag_debug_rd_data[20:0] =  ({21{ic_debug_rd_way_en_ff[0]}} &  ic_tag_data_raw[0] ) |
                                       ({21{ic_debug_rd_way_en_ff[1]}} &  ic_tag_data_raw[1] ) |
                                       ({21{ic_debug_rd_way_en_ff[2]}} &  ic_tag_data_raw[2] ) |
                                       ({21{ic_debug_rd_way_en_ff[3]}} &  ic_tag_data_raw[3] ) ;
             
`endif
   assign ic_rd_hit[0] = (w_tout[0][31:ICACHE_TAG_HIGH] == ic_rw_addr_ff[31:ICACHE_TAG_HIGH]) & ic_tag_valid[0];
   assign ic_rd_hit[1] = (w_tout[1][31:ICACHE_TAG_HIGH] == ic_rw_addr_ff[31:ICACHE_TAG_HIGH]) & ic_tag_valid[1];
   assign ic_rd_hit[2] = (w_tout[2][31:ICACHE_TAG_HIGH] == ic_rw_addr_ff[31:ICACHE_TAG_HIGH]) & ic_tag_valid[2];
   assign ic_rd_hit[3] = (w_tout[3][31:ICACHE_TAG_HIGH] == ic_rw_addr_ff[31:ICACHE_TAG_HIGH]) & ic_tag_valid[3];

   assign  ic_tag_perr  = | (ic_tag_way_perr[3:0] & ic_tag_valid[3:0] ) ;
endmodule



