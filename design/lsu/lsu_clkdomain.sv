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
// Function: Clock Generation Block
// Comments: All the clocks are generate here
//
// //********************************************************************************


module lsu_clkdomain
   import swerv_types::*;
(
   input logic      clk,                               // clock
   input logic      free_clk,                          // clock
   input logic      rst_l,                             // reset

   // Inputs
   input logic      clk_override,                      // chciken bit to turn off clock gating
   input logic      lsu_freeze_dc3,                    // freeze
   input logic      addr_in_dccm_dc2,                  // address in dccm
   input logic      addr_in_pic_dc2,                   // address is in pic
   input logic      dma_dccm_req,                      // dma is active
   input logic      dma_mem_write,                     // dma write is active
   input logic      load_stbuf_reqvld_dc3,             // instruction to stbuf
   input logic      store_stbuf_reqvld_dc3,            // instruction to stbuf
   input logic      stbuf_reqvld_any,                  // stbuf is draining
   input logic      stbuf_reqvld_flushed_any,          // instruction going to stbuf is flushed
   input logic      lsu_busreq_dc5,                    // busreq in dc5
   input logic      lsu_bus_buffer_pend_any,           // bus buffer has a pending bus entry
   input logic      lsu_bus_buffer_empty_any,          // external bus buffer is empty
   input logic      lsu_stbuf_empty_any,               // stbuf is empty
   //input logic      lsu_load_stall_any,                // Need to turn on clocks for this case

   input logic      lsu_bus_clk_en,               // bus clock enable

   input lsu_pkt_t  lsu_p,                             // lsu packet in decode
   input lsu_pkt_t  lsu_pkt_dc1,                       // lsu packet in dc1
   input lsu_pkt_t  lsu_pkt_dc2,                       // lsu packet in dc2
   input lsu_pkt_t  lsu_pkt_dc3,                       // lsu packet in dc3
   input lsu_pkt_t  lsu_pkt_dc4,                       // lsu packet in dc4
   input lsu_pkt_t  lsu_pkt_dc5,                       // lsu packet in dc5

   // Outputs
   output logic     lsu_c1_dc3_clk,                    // dc3 pipe single pulse clock
   output logic     lsu_c1_dc4_clk,                    // dc4 pipe single pulse clock
   output logic     lsu_c1_dc5_clk,                    // dc5 pipe single pulse clock

   output logic     lsu_c2_dc3_clk,                    // dc3 pipe double pulse clock
   output logic     lsu_c2_dc4_clk,                    // dc4 pipe double pulse clock
   output logic     lsu_c2_dc5_clk,                    // dc5 pipe double pulse clock

   output logic     lsu_store_c1_dc1_clken,              // store in dc1
   output logic     lsu_store_c1_dc2_clken,              // store in dc2
   output logic     lsu_store_c1_dc3_clken,              // store in dc3
   output logic     lsu_store_c1_dc4_clk,              // store in dc4
   output logic     lsu_store_c1_dc5_clk,              // store in dc5

   output logic     lsu_freeze_c1_dc1_clken,             // freeze
   output logic     lsu_freeze_c1_dc2_clken,             // freeze
   output logic     lsu_freeze_c1_dc3_clken,             // freeze

   output logic     lsu_freeze_c1_dc2_clk,             // freeze
   output logic     lsu_freeze_c1_dc3_clk,             // freeze

   output logic     lsu_freeze_c2_dc1_clk,
   output logic     lsu_freeze_c2_dc2_clk,
   output logic     lsu_freeze_c2_dc3_clk,
   output logic     lsu_freeze_c2_dc4_clk,

   output logic     lsu_freeze_c2_dc1_clken,
   output logic     lsu_freeze_c2_dc2_clken,
   output logic     lsu_freeze_c2_dc3_clken,
   output logic     lsu_freeze_c2_dc4_clken,

   output logic     lsu_dccm_c1_dc3_clk,               // dccm clock
   output logic     lsu_dccm_c1_dc3_clken,

   output logic     lsu_pic_c1_dc3_clken,              // pic clock enable

   output logic     lsu_stbuf_c1_clk,
   output logic     lsu_bus_obuf_c1_clk,               // ibuf clock
   output logic     lsu_bus_ibuf_c1_clk,               // ibuf clock
   output logic     lsu_bus_buf_c1_clk,                // ibuf clock
   output logic     lsu_busm_clk,                      // bus clock

   output logic     lsu_free_c2_clk,

   input  logic     scan_mode
);

   logic lsu_c1_dc1_clken, lsu_c1_dc2_clken, lsu_c1_dc3_clken, lsu_c1_dc4_clken, lsu_c1_dc5_clken;
   logic lsu_c2_dc3_clken, lsu_c2_dc4_clken, lsu_c2_dc5_clken;
   logic lsu_c1_dc1_clken_q, lsu_c1_dc2_clken_q, lsu_c1_dc3_clken_q, lsu_c1_dc4_clken_q, lsu_c1_dc5_clken_q;
   logic lsu_store_c1_dc4_clken, lsu_store_c1_dc5_clken;

   logic lsu_freeze_c1_dc4_clken;

   logic lsu_freeze_c1_dc1_clken_q, lsu_freeze_c1_dc2_clken_q, lsu_freeze_c1_dc3_clken_q, lsu_freeze_c1_dc4_clken_q;

   logic lsu_stbuf_c1_clken;
   logic lsu_bus_ibuf_c1_clken, lsu_bus_obuf_c1_clken, lsu_bus_buf_c1_clken;


   logic lsu_free_c1_clken, lsu_free_c1_clken_q, lsu_free_c2_clken;
   logic lsu_bus_valid_clken;

   //-------------------------------------------------------------------------------------------
   // Clock Enable logic
   //-------------------------------------------------------------------------------------------

   // Also use the flopped clock enable. We want to turn on the clocks from dc1->dc5 even if there is a freeze
   assign lsu_c1_dc1_clken = lsu_p.valid | dma_dccm_req | clk_override;
   assign lsu_c1_dc2_clken = lsu_pkt_dc1.valid | lsu_c1_dc1_clken_q | clk_override;
   assign lsu_c1_dc3_clken = lsu_pkt_dc2.valid | lsu_c1_dc2_clken_q | clk_override;
   assign lsu_c1_dc4_clken = lsu_pkt_dc3.valid | lsu_c1_dc3_clken_q | clk_override;
   assign lsu_c1_dc5_clken = lsu_pkt_dc4.valid | lsu_c1_dc4_clken_q | clk_override;

   assign lsu_c2_dc3_clken = lsu_c1_dc3_clken | lsu_c1_dc3_clken_q | clk_override;
   assign lsu_c2_dc4_clken = lsu_c1_dc4_clken | lsu_c1_dc4_clken_q | clk_override;
   assign lsu_c2_dc5_clken = lsu_c1_dc5_clken | lsu_c1_dc5_clken_q | clk_override;

   assign lsu_store_c1_dc1_clken = ((lsu_c1_dc1_clken & (lsu_p.store | dma_mem_write)) | clk_override) & ~lsu_freeze_dc3;
   assign lsu_store_c1_dc2_clken = ((lsu_c1_dc2_clken & lsu_pkt_dc1.store) | clk_override) & ~lsu_freeze_dc3;
   assign lsu_store_c1_dc3_clken = ((lsu_c1_dc3_clken & lsu_pkt_dc2.store) | clk_override) & ~lsu_freeze_dc3;
   assign lsu_store_c1_dc4_clken = (lsu_c1_dc4_clken & lsu_pkt_dc3.store) | clk_override;
   assign lsu_store_c1_dc5_clken = (lsu_c1_dc5_clken & lsu_pkt_dc4.store) | clk_override;

   assign lsu_freeze_c1_dc1_clken = (lsu_p.valid | dma_dccm_req | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c1_dc2_clken = (lsu_pkt_dc1.valid | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c1_dc3_clken = (lsu_pkt_dc2.valid | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c1_dc4_clken = (lsu_pkt_dc3.valid | clk_override) & ~lsu_freeze_dc3;

   assign lsu_freeze_c2_dc1_clken = (lsu_freeze_c1_dc1_clken | lsu_freeze_c1_dc1_clken_q | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c2_dc2_clken = (lsu_freeze_c1_dc2_clken | lsu_freeze_c1_dc2_clken_q | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c2_dc3_clken = (lsu_freeze_c1_dc3_clken | lsu_freeze_c1_dc3_clken_q | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c2_dc4_clken = (lsu_freeze_c1_dc4_clken | lsu_freeze_c1_dc4_clken_q | clk_override) & ~lsu_freeze_dc3;


   assign lsu_stbuf_c1_clken = load_stbuf_reqvld_dc3 | store_stbuf_reqvld_dc3 | stbuf_reqvld_any | stbuf_reqvld_flushed_any | clk_override;
   assign lsu_bus_ibuf_c1_clken = lsu_busreq_dc5 | clk_override;
   assign lsu_bus_obuf_c1_clken = ((lsu_bus_buffer_pend_any | lsu_busreq_dc5) & lsu_bus_clk_en) | clk_override;
   assign lsu_bus_buf_c1_clken  = ~lsu_bus_buffer_empty_any | lsu_busreq_dc5 | clk_override;

   assign lsu_dccm_c1_dc3_clken = ((lsu_c1_dc3_clken & addr_in_dccm_dc2) | clk_override) & ~lsu_freeze_dc3;
   assign lsu_pic_c1_dc3_clken  = ((lsu_c1_dc3_clken & addr_in_pic_dc2) | clk_override) & ~lsu_freeze_dc3;

   assign lsu_free_c1_clken = (lsu_p.valid | lsu_pkt_dc1.valid | lsu_pkt_dc2.valid | lsu_pkt_dc3.valid | lsu_pkt_dc4.valid | lsu_pkt_dc5.valid) |
                              ~lsu_bus_buffer_empty_any | ~lsu_stbuf_empty_any | clk_override;
   assign lsu_free_c2_clken = lsu_free_c1_clken | lsu_free_c1_clken_q | clk_override;

    // Flops
   rvdff #(1) lsu_free_c1_clkenff (.din(lsu_free_c1_clken), .dout(lsu_free_c1_clken_q), .clk(free_clk), .*);

   rvdff #(1) lsu_c1_dc1_clkenff (.din(lsu_c1_dc1_clken), .dout(lsu_c1_dc1_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc2_clkenff (.din(lsu_c1_dc2_clken), .dout(lsu_c1_dc2_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc3_clkenff (.din(lsu_c1_dc3_clken), .dout(lsu_c1_dc3_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc4_clkenff (.din(lsu_c1_dc4_clken), .dout(lsu_c1_dc4_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc5_clkenff (.din(lsu_c1_dc5_clken), .dout(lsu_c1_dc5_clken_q), .clk(lsu_free_c2_clk), .*);

   rvdff_fpga #(1) lsu_freeze_c1_dc1_clkenff (.din(lsu_freeze_c1_dc1_clken), .dout(lsu_freeze_c1_dc1_clken_q), .clk(lsu_freeze_c2_dc1_clk), .clken(lsu_freeze_c2_dc1_clken), .rawclk(clk), .*);
   rvdff_fpga #(1) lsu_freeze_c1_dc2_clkenff (.din(lsu_freeze_c1_dc2_clken), .dout(lsu_freeze_c1_dc2_clken_q), .clk(lsu_freeze_c2_dc2_clk), .clken(lsu_freeze_c2_dc2_clken), .rawclk(clk), .*);
   rvdff_fpga #(1) lsu_freeze_c1_dc3_clkenff (.din(lsu_freeze_c1_dc3_clken), .dout(lsu_freeze_c1_dc3_clken_q), .clk(lsu_freeze_c2_dc3_clk), .clken(lsu_freeze_c2_dc3_clken), .rawclk(clk), .*);
   rvdff_fpga #(1) lsu_freeze_c1_dc4_clkenff (.din(lsu_freeze_c1_dc4_clken), .dout(lsu_freeze_c1_dc4_clken_q), .clk(lsu_freeze_c2_dc4_clk), .clken(lsu_freeze_c2_dc4_clken), .rawclk(clk), .*);

   // Clock Headers
   rvoclkhdr lsu_c1dc3_cgc ( .en(lsu_c1_dc3_clken), .l1clk(lsu_c1_dc3_clk), .* );
   rvoclkhdr lsu_c1dc4_cgc ( .en(lsu_c1_dc4_clken), .l1clk(lsu_c1_dc4_clk), .* );
   rvoclkhdr lsu_c1dc5_cgc ( .en(lsu_c1_dc5_clken), .l1clk(lsu_c1_dc5_clk), .* );

   rvoclkhdr lsu_c2dc3_cgc ( .en(lsu_c2_dc3_clken), .l1clk(lsu_c2_dc3_clk), .* );
   rvoclkhdr lsu_c2dc4_cgc ( .en(lsu_c2_dc4_clken), .l1clk(lsu_c2_dc4_clk), .* );
   rvoclkhdr lsu_c2dc5_cgc ( .en(lsu_c2_dc5_clken), .l1clk(lsu_c2_dc5_clk), .* );

   rvoclkhdr lsu_store_c1dc4_cgc (.en(lsu_store_c1_dc4_clken), .l1clk(lsu_store_c1_dc4_clk), .*);
   rvoclkhdr lsu_store_c1dc5_cgc (.en(lsu_store_c1_dc5_clken), .l1clk(lsu_store_c1_dc5_clk), .*);

`ifdef RV_FPGA_OPTIMIZE
   assign lsu_freeze_c1_dc2_clk = 1'b0;
   assign lsu_freeze_c1_dc3_clk = 1'b0;
   assign lsu_freeze_c2_dc1_clk = 1'b0;
   assign lsu_freeze_c2_dc2_clk = 1'b0;
   assign lsu_freeze_c2_dc3_clk = 1'b0;
   assign lsu_freeze_c2_dc4_clk = 1'b0;

   assign lsu_busm_clk = 1'b0;
   assign lsu_dccm_c1_dc3_clk = 1'b0;

`else
   rvclkhdr lsu_freeze_c1dc2_cgc ( .en(lsu_freeze_c1_dc2_clken), .l1clk(lsu_freeze_c1_dc2_clk), .* );  // ifndef FPGA_OPTIMIZE
   rvclkhdr lsu_freeze_c1dc3_cgc ( .en(lsu_freeze_c1_dc3_clken), .l1clk(lsu_freeze_c1_dc3_clk), .* );  // ifndef FPGA_OPTIMIZE
   rvclkhdr lsu_freeze_c2dc1_cgc ( .en(lsu_freeze_c2_dc1_clken), .l1clk(lsu_freeze_c2_dc1_clk), .* );  // ifndef FPGA_OPTIMIZE
   rvclkhdr lsu_freeze_c2dc2_cgc ( .en(lsu_freeze_c2_dc2_clken), .l1clk(lsu_freeze_c2_dc2_clk), .* );  // ifndef FPGA_OPTIMIZE
   rvclkhdr lsu_freeze_c2dc3_cgc ( .en(lsu_freeze_c2_dc3_clken), .l1clk(lsu_freeze_c2_dc3_clk), .* );  // ifndef FPGA_OPTIMIZE
   rvclkhdr lsu_freeze_c2dc4_cgc ( .en(lsu_freeze_c2_dc4_clken), .l1clk(lsu_freeze_c2_dc4_clk), .* );  // ifndef FPGA_OPTIMIZE

   rvclkhdr lsu_busm_cgc (.en(lsu_bus_clk_en), .l1clk(lsu_busm_clk), .*);                              // ifndef FPGA_OPTIMIZE
   rvclkhdr lsu_dccm_c1dc3_cgc (.en(lsu_dccm_c1_dc3_clken), .l1clk(lsu_dccm_c1_dc3_clk), .*);          // ifndef FPGA_OPTIMIZE

`endif

   rvoclkhdr lsu_stbuf_c1_cgc ( .en(lsu_stbuf_c1_clken), .l1clk(lsu_stbuf_c1_clk), .* );
   rvoclkhdr lsu_bus_ibuf_c1_cgc ( .en(lsu_bus_ibuf_c1_clken), .l1clk(lsu_bus_ibuf_c1_clk), .* );
   rvoclkhdr lsu_bus_obuf_c1_cgc ( .en(lsu_bus_obuf_c1_clken), .l1clk(lsu_bus_obuf_c1_clk), .* );
   rvoclkhdr lsu_bus_buf_c1_cgc  ( .en(lsu_bus_buf_c1_clken),  .l1clk(lsu_bus_buf_c1_clk), .* );



   rvoclkhdr lsu_free_cgc (.en(lsu_free_c2_clken), .l1clk(lsu_free_c2_clk), .*);

endmodule

