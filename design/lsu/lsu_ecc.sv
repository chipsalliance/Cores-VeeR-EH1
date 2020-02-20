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
// Function: Top level file for load store unit
// Comments:
//
//
// DC1 -> DC2 -> DC3 -> DC4 (Commit)
//
//********************************************************************************
module lsu_ecc
   import swerv_types::*;
(

   input logic        lsu_c2_dc4_clk,                      // clocks
   input logic        lsu_c1_dc4_clk,
   input logic        lsu_c1_dc5_clk,
   input logic        clk,
   input logic        rst_l,

   input lsu_pkt_t    lsu_pkt_dc3,                        // packet in dc3
   input logic        lsu_dccm_rden_dc3,                  // dccm rden
   input logic        addr_in_dccm_dc3,                   // address in dccm
   input logic [`RV_DCCM_BITS-1:0]       lsu_addr_dc3,    // start address
   input logic [`RV_DCCM_BITS-1:0]       end_addr_dc3,    // end address
   input logic [63:0]                    store_data_dc3,  // store data
   input logic [`RV_DCCM_DATA_WIDTH-1:0] stbuf_data_any,

   input logic [`RV_DCCM_DATA_WIDTH-1:0] stbuf_fwddata_hi_dc3,  // data forward from the store buffer
   input logic [`RV_DCCM_DATA_WIDTH-1:0] stbuf_fwddata_lo_dc3,  // data forward from the store buffer
   input logic [`RV_DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_hi_dc3,// which bytes from the store buffer are on
   input logic [`RV_DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_lo_dc3,// which bytes from the store buffer are on

   input logic [`RV_DCCM_DATA_WIDTH-1:0] dccm_data_hi_dc3,     // raw data from mem
   input logic [`RV_DCCM_DATA_WIDTH-1:0] dccm_data_lo_dc3,     // raw data from mem
   input logic [`RV_DCCM_ECC_WIDTH-1:0]  dccm_data_ecc_hi_dc3, // ecc read out from mem
   input logic [`RV_DCCM_ECC_WIDTH-1:0]  dccm_data_ecc_lo_dc3, // ecc read out from mem

   input logic                           dec_tlu_core_ecc_disable,  // disables the ecc computation and error flagging

   output logic [`RV_DCCM_DATA_WIDTH-1:0] store_ecc_datafn_hi_dc3,  // final store data either from stbuf or SEC DCCM readout
   output logic [`RV_DCCM_DATA_WIDTH-1:0] store_ecc_datafn_lo_dc3,

   output logic [`RV_DCCM_ECC_WIDTH-1:0] stbuf_ecc_any,
   output logic        single_ecc_error_hi_dc3,                   // sec detected
   output logic        single_ecc_error_lo_dc3,                   // sec detected on lower dccm bank
   output logic        lsu_single_ecc_error_dc3,                  // or of the 2
   output logic        lsu_double_ecc_error_dc3,                  // double error detected

   input logic         scan_mode
 );

`include "global.h"

   `ifdef RV_DCCM_ENABLE
      localparam DCCM_ENABLE = 1'b1;
   `else
      localparam DCCM_ENABLE = 1'b0;
   `endif

   logic [DCCM_DATA_WIDTH-1:0] sec_data_hi_dc3;
   logic [DCCM_DATA_WIDTH-1:0] sec_data_lo_dc3;


   logic        double_ecc_error_hi_dc3, double_ecc_error_lo_dc3;

   logic        ldst_dual_dc3;
   logic        is_ldst_dc3;
   logic        is_ldst_hi_dc3, is_ldst_lo_dc3;
   logic [7:0]  ldst_byteen_dc3;
   logic [7:0]  store_byteen_dc3;
   logic [7:0]  store_byteen_ext_dc3;
   logic [DCCM_BYTE_WIDTH-1:0]  store_byteen_hi_dc3, store_byteen_lo_dc3;

   logic [163:0] store_data_ext_dc3;
   logic [DCCM_DATA_WIDTH-1:0]  store_data_hi_dc3, store_data_lo_dc3;
   logic [6:0]                  ecc_out_hi_nc, ecc_out_lo_nc;


   assign ldst_dual_dc3 = (lsu_addr_dc3[2] != end_addr_dc3[2]);
   assign is_ldst_dc3 = lsu_pkt_dc3.valid & (lsu_pkt_dc3.load | lsu_pkt_dc3.store) & addr_in_dccm_dc3 & lsu_dccm_rden_dc3;
   assign is_ldst_lo_dc3 = is_ldst_dc3 & ~dec_tlu_core_ecc_disable;
   assign is_ldst_hi_dc3 = is_ldst_dc3 & ldst_dual_dc3 & ~dec_tlu_core_ecc_disable;

   assign ldst_byteen_dc3[7:0] = ({8{lsu_pkt_dc3.by}}   & 8'b0000_0001) |
                                 ({8{lsu_pkt_dc3.half}} & 8'b0000_0011) |
                                 ({8{lsu_pkt_dc3.word}} & 8'b0000_1111) |
                                 ({8{lsu_pkt_dc3.dword}} & 8'b1111_1111);
   assign store_byteen_dc3[7:0] = ldst_byteen_dc3[7:0] & {8{lsu_pkt_dc3.store}};

   assign store_byteen_ext_dc3[7:0] = store_byteen_dc3[7:0] << lsu_addr_dc3[1:0];
   assign store_byteen_hi_dc3[DCCM_BYTE_WIDTH-1:0] = store_byteen_ext_dc3[7:4];
   assign store_byteen_lo_dc3[DCCM_BYTE_WIDTH-1:0] = store_byteen_ext_dc3[3:0];

   assign store_data_ext_dc3[63:0] = store_data_dc3[63:0] << {lsu_addr_dc3[1:0], 3'b000};
   assign store_data_hi_dc3[DCCM_DATA_WIDTH-1:0]  = store_data_ext_dc3[63:32];
   assign store_data_lo_dc3[DCCM_DATA_WIDTH-1:0]  = store_data_ext_dc3[31:0];


   // Merge store data and sec data
   // This is used for loads as well for ecc error case. store_byteen will be 0 for loads
   for (genvar i=0; i<DCCM_BYTE_WIDTH; i++) begin
      assign store_ecc_datafn_hi_dc3[(8*i)+7:(8*i)] = store_byteen_hi_dc3[i] ? store_data_hi_dc3[(8*i)+7:(8*i)] :
                                                                               (stbuf_fwdbyteen_hi_dc3[i] ? stbuf_fwddata_hi_dc3[(8*i)+7:(8*i)] : sec_data_hi_dc3[(8*i)+7:(8*i)]);
      assign store_ecc_datafn_lo_dc3[(8*i)+7:(8*i)] = store_byteen_lo_dc3[i] ? store_data_lo_dc3[(8*i)+7:(8*i)] :
                                                                               (stbuf_fwdbyteen_lo_dc3[i] ? stbuf_fwddata_lo_dc3[(8*i)+7:(8*i)] : sec_data_lo_dc3[(8*i)+7:(8*i)]);
   end

   if (DCCM_ENABLE == 1) begin: Gen_dccm_enable
      //Detect/Repair for Hi/Lo
      rvecc_decode lsu_ecc_decode_hi (
         // Inputs
         .en(is_ldst_hi_dc3),
         .sed_ded (1'b0),    // 1 : means only detection
         .din(dccm_data_hi_dc3[DCCM_DATA_WIDTH-1:0]),
         .ecc_in(dccm_data_ecc_hi_dc3[DCCM_ECC_WIDTH-1:0]),
         // Outputs
         .dout(sec_data_hi_dc3[DCCM_DATA_WIDTH-1:0]),
         .ecc_out (ecc_out_hi_nc[6:0]),
         .single_ecc_error(single_ecc_error_hi_dc3),
         .double_ecc_error(double_ecc_error_hi_dc3),
         .*
      );

      rvecc_decode lsu_ecc_decode_lo (
         // Inputs
         .en(is_ldst_lo_dc3),
         .sed_ded (1'b0),    // 1 : means only detection
         .din(dccm_data_lo_dc3[DCCM_DATA_WIDTH-1:0] ),
         .ecc_in(dccm_data_ecc_lo_dc3[DCCM_ECC_WIDTH-1:0]),
         // Outputs
         .dout(sec_data_lo_dc3[DCCM_DATA_WIDTH-1:0]),
         .ecc_out (ecc_out_lo_nc[6:0]),
         .single_ecc_error(single_ecc_error_lo_dc3),
         .double_ecc_error(double_ecc_error_lo_dc3),
         .*
      );

      // Generate the ECC bits for store buffer drain
      rvecc_encode lsu_ecc_encode (
         //Inputs
         .din(stbuf_data_any[DCCM_DATA_WIDTH-1:0]),
         //Outputs
         .ecc_out(stbuf_ecc_any[DCCM_ECC_WIDTH-1:0]),
         .*
      );
   end else begin: Gen_dccm_disable // block: Gen_dccm_enable
      assign sec_data_hi_dc3[DCCM_DATA_WIDTH-1:0] = '0;
      assign sec_data_lo_dc3[DCCM_DATA_WIDTH-1:0] = '0;
      assign single_ecc_error_hi_dc3 = '0;
      assign double_ecc_error_hi_dc3 = '0;
      assign single_ecc_error_lo_dc3 = '0;
      assign double_ecc_error_lo_dc3 = '0;

      assign stbuf_ecc_any[DCCM_ECC_WIDTH-1:0] = '0;
   end

   assign lsu_single_ecc_error_dc3 = single_ecc_error_hi_dc3 | single_ecc_error_lo_dc3;
   assign lsu_double_ecc_error_dc3 = double_ecc_error_hi_dc3 | double_ecc_error_lo_dc3;


`ifdef ASSERT_ON

//   ecc_check: assert property (@(posedge clk) ~(single_ecc_error_lo_dc3 | single_ecc_error_hi_dc3));

`endif

endmodule // lsu_ecc
