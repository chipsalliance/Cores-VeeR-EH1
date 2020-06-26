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
// Function: Checks the memory map for the address
// Comments:
//
//********************************************************************************
module lsu_addrcheck
   import swerv_types::*;
(
   input logic         lsu_freeze_c2_dc2_clk,       // clock
   input logic         lsu_freeze_c2_dc3_clk,
   input logic         lsu_freeze_c2_dc2_clken,
   input logic         lsu_freeze_c2_dc3_clken,
   input logic         rst_l,                       // reset
   input logic         clk,

   input logic [31:0]  start_addr_dc1,              // start address for lsu
   input logic [31:0]  end_addr_dc1,                // end address for lsu
   input lsu_pkt_t     lsu_pkt_dc1,                 // packet in dc1
   input logic [31:0]  dec_tlu_mrac_ff,             // CSR read


   output logic        is_sideeffects_dc2,          // is sideffects space
   output logic        is_sideeffects_dc3,
   output logic        addr_in_dccm_dc1,            // address in dccm
   output logic        addr_in_pic_dc1,             // address in pic
   output logic        addr_external_dc1,           // address in external

   output logic        access_fault_dc1,            // access fault
   output logic        misaligned_fault_dc1,        // misaligned

   input  logic        scan_mode
);

`include "global.h"

   localparam DCCM_REGION = `RV_DCCM_REGION;
   localparam PIC_REGION  = `RV_PIC_REGION;
   localparam ICCM_REGION = `RV_ICCM_REGION;

   `ifdef RV_ICCM_ENABLE
      localparam ICCM_ENABLE = 1'b1;
   `else
       localparam ICCM_ENABLE = 1'b0;
   `endif

   `ifdef RV_DCCM_ENABLE
      localparam DCCM_ENABLE = 1'b1;
   `else
       localparam DCCM_ENABLE = 1'b0;
   `endif

   logic        is_sideeffects_dc1, is_aligned_dc1;
   logic        start_addr_in_dccm_dc1, end_addr_in_dccm_dc1;
   logic        start_addr_in_dccm_region_dc1, end_addr_in_dccm_region_dc1;
   logic        start_addr_in_pic_dc1, end_addr_in_pic_dc1;
   logic        start_addr_in_pic_region_dc1, end_addr_in_pic_region_dc1;
   logic [4:0]  csr_idx;
   logic        addr_in_iccm;
   logic        non_dccm_access_ok;

   if (DCCM_ENABLE == 1) begin: Gen_dccm_enable
      // Start address check
      rvrangecheck #(.CCM_SADR(`RV_DCCM_SADR),
                     .CCM_SIZE(`RV_DCCM_SIZE)) start_addr_dccm_rangecheck (
         .addr(start_addr_dc1[31:0]),
         .in_range(start_addr_in_dccm_dc1),
         .in_region(start_addr_in_dccm_region_dc1)
      );

      // End address check
      rvrangecheck #(.CCM_SADR(`RV_DCCM_SADR),
                     .CCM_SIZE(`RV_DCCM_SIZE)) end_addr_dccm_rangecheck (
         .addr(end_addr_dc1[31:0]),
         .in_range(end_addr_in_dccm_dc1),
         .in_region(end_addr_in_dccm_region_dc1)
      );
   end else begin: Gen_dccm_disable // block: Gen_dccm_enable
      assign start_addr_in_dccm_dc1 = '0;
      assign start_addr_in_dccm_region_dc1 = '0;
      assign end_addr_in_dccm_dc1 = '0;
      assign end_addr_in_dccm_region_dc1 = '0;
   end
    if (ICCM_ENABLE == 1) begin : check_iccm
     assign addr_in_iccm =  (start_addr_dc1[31:28] == ICCM_REGION);
  end
  else begin
     assign addr_in_iccm = 1'b0;
  end
   // PIC memory check
   // Start address check
   rvrangecheck #(.CCM_SADR(`RV_PIC_BASE_ADDR),
                  .CCM_SIZE(`RV_PIC_SIZE)) start_addr_pic_rangecheck (
      .addr(start_addr_dc1[31:0]),
      .in_range(start_addr_in_pic_dc1),
      .in_region(start_addr_in_pic_region_dc1)
   );

   // End address check
   rvrangecheck #(.CCM_SADR(`RV_PIC_BASE_ADDR),
                  .CCM_SIZE(`RV_PIC_SIZE)) end_addr_pic_rangecheck (
      .addr(end_addr_dc1[31:0]),
      .in_range(end_addr_in_pic_dc1),
      .in_region(end_addr_in_pic_region_dc1)
   );

   assign addr_in_dccm_dc1        = (start_addr_in_dccm_dc1 & end_addr_in_dccm_dc1);
   assign addr_in_pic_dc1         = (start_addr_in_pic_dc1 & end_addr_in_pic_dc1);

   assign addr_external_dc1   = ~(addr_in_dccm_dc1 | addr_in_pic_dc1);  //~addr_in_dccm_region_dc1;
   assign csr_idx[4:0]       = {start_addr_dc1[31:28], 1'b1};
   assign is_sideeffects_dc1 = dec_tlu_mrac_ff[csr_idx] & ~(start_addr_in_dccm_region_dc1 | start_addr_in_pic_region_dc1 | addr_in_iccm);  //every region has the 2 LSB indicating ( 1: sideeffects/no_side effects, and 0: cacheable ). Ignored in internal regions
   assign is_aligned_dc1    = (lsu_pkt_dc1.word & (start_addr_dc1[1:0] == 2'b0)) |
                              (lsu_pkt_dc1.half & (start_addr_dc1[0] == 1'b0)) |
                              lsu_pkt_dc1.by;

    assign non_dccm_access_ok = (~(|{`RV_DATA_ACCESS_ENABLE0,`RV_DATA_ACCESS_ENABLE1,`RV_DATA_ACCESS_ENABLE2,`RV_DATA_ACCESS_ENABLE3,`RV_DATA_ACCESS_ENABLE4,`RV_DATA_ACCESS_ENABLE5,`RV_DATA_ACCESS_ENABLE6,`RV_DATA_ACCESS_ENABLE7})) |

                             (((`RV_DATA_ACCESS_ENABLE0 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK0)) == (`RV_DATA_ACCESS_ADDR0 | `RV_DATA_ACCESS_MASK0)) |
                               (`RV_DATA_ACCESS_ENABLE1 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK1)) == (`RV_DATA_ACCESS_ADDR1 | `RV_DATA_ACCESS_MASK1)) |
                               (`RV_DATA_ACCESS_ENABLE2 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK2)) == (`RV_DATA_ACCESS_ADDR2 | `RV_DATA_ACCESS_MASK2)) |
                               (`RV_DATA_ACCESS_ENABLE3 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK3)) == (`RV_DATA_ACCESS_ADDR3 | `RV_DATA_ACCESS_MASK3)) |
                               (`RV_DATA_ACCESS_ENABLE4 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK4)) == (`RV_DATA_ACCESS_ADDR4 | `RV_DATA_ACCESS_MASK4)) |
                               (`RV_DATA_ACCESS_ENABLE5 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK5)) == (`RV_DATA_ACCESS_ADDR5 | `RV_DATA_ACCESS_MASK5)) |
                               (`RV_DATA_ACCESS_ENABLE6 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK6)) == (`RV_DATA_ACCESS_ADDR6 | `RV_DATA_ACCESS_MASK6)) |
                               (`RV_DATA_ACCESS_ENABLE7 & ((start_addr_dc1[31:0] | `RV_DATA_ACCESS_MASK7)) == (`RV_DATA_ACCESS_ADDR7 | `RV_DATA_ACCESS_MASK7)))        &

                              ((`RV_DATA_ACCESS_ENABLE0 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK0)) == (`RV_DATA_ACCESS_ADDR0 | `RV_DATA_ACCESS_MASK0)) |
                               (`RV_DATA_ACCESS_ENABLE1 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK1)) == (`RV_DATA_ACCESS_ADDR1 | `RV_DATA_ACCESS_MASK1)) |
                               (`RV_DATA_ACCESS_ENABLE2 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK2)) == (`RV_DATA_ACCESS_ADDR2 | `RV_DATA_ACCESS_MASK2)) |
                               (`RV_DATA_ACCESS_ENABLE3 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK3)) == (`RV_DATA_ACCESS_ADDR3 | `RV_DATA_ACCESS_MASK3)) |
                               (`RV_DATA_ACCESS_ENABLE4 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK4)) == (`RV_DATA_ACCESS_ADDR4 | `RV_DATA_ACCESS_MASK4)) |
                               (`RV_DATA_ACCESS_ENABLE5 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK5)) == (`RV_DATA_ACCESS_ADDR5 | `RV_DATA_ACCESS_MASK5)) |
                               (`RV_DATA_ACCESS_ENABLE6 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK6)) == (`RV_DATA_ACCESS_ADDR6 | `RV_DATA_ACCESS_MASK6)) |
                               (`RV_DATA_ACCESS_ENABLE7 & ((end_addr_dc1[31:0]   | `RV_DATA_ACCESS_MASK7)) == (`RV_DATA_ACCESS_ADDR7 | `RV_DATA_ACCESS_MASK7))));

   // Access fault logic
   // 1. Addr in dccm region but not in dccm offset
   // 2. Addr in picm region but not in picm offset
   // 3. DCCM -> PIC offset cross when DCCM/PIC in same region (PIC access are always word aligned so no cross possible from PIC->DCCM)
   // 4. Ld/St access to picm are not word aligned
   // 5. Address not in protected space or dccm/pic region
   if (DCCM_REGION == PIC_REGION) begin
      assign access_fault_dc1  = ((start_addr_in_dccm_region_dc1 & ~(start_addr_in_dccm_dc1 | start_addr_in_pic_dc1)) |
                                  (end_addr_in_dccm_region_dc1 & ~(end_addr_in_dccm_dc1 | end_addr_in_pic_dc1))       |
                                  (start_addr_in_dccm_dc1 & end_addr_in_pic_dc1)                                      |
                                  (start_addr_in_pic_dc1  & end_addr_in_dccm_dc1)                                     |
                                  ((addr_in_pic_dc1 & ((start_addr_dc1[1:0] != 2'b0) | ~lsu_pkt_dc1.word))) |
                                  (~start_addr_in_dccm_region_dc1 & ~non_dccm_access_ok)) & lsu_pkt_dc1.valid & ~lsu_pkt_dc1.dma;
   end else begin
      assign access_fault_dc1  = ((start_addr_in_dccm_region_dc1 & ~start_addr_in_dccm_dc1) |
                                  (end_addr_in_dccm_region_dc1 & ~end_addr_in_dccm_dc1)     |
                                  (start_addr_in_pic_region_dc1 & ~start_addr_in_pic_dc1)   |
                                  (end_addr_in_pic_region_dc1 & ~end_addr_in_pic_dc1)       |
                                  ((addr_in_pic_dc1 & ((start_addr_dc1[1:0] != 2'b0) | ~lsu_pkt_dc1.word))) |
                                  (~start_addr_in_pic_region_dc1 & ~start_addr_in_dccm_region_dc1 & ~non_dccm_access_ok)) & lsu_pkt_dc1.valid & ~lsu_pkt_dc1.dma;
   end

   // Misaligned happens due to 2 reasons
   // 1. Region cross
   // 2. sideeffects access which are not aligned
   assign misaligned_fault_dc1 = ((start_addr_dc1[31:28] != end_addr_dc1[31:28]) |
                                  (is_sideeffects_dc1 & ~is_aligned_dc1)) & addr_external_dc1 & lsu_pkt_dc1.valid & ~lsu_pkt_dc1.dma;

   rvdff_fpga #(.WIDTH(1)) is_sideeffects_dc2ff (.din(is_sideeffects_dc1), .dout(is_sideeffects_dc2), .clk(lsu_freeze_c2_dc2_clk), .clken(lsu_freeze_c2_dc2_clken), .rawclk(clk), .*);
   rvdff_fpga #(.WIDTH(1)) is_sideeffects_dc3ff (.din(is_sideeffects_dc2), .dout(is_sideeffects_dc3), .clk(lsu_freeze_c2_dc3_clk), .clken(lsu_freeze_c2_dc3_clken), .rawclk(clk), .*);


endmodule // lsu_addrcheck

