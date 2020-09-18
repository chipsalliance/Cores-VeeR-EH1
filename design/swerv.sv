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
// Function: Top level SWERV core file
// Comments:
//
//********************************************************************************
module swerv
   import swerv_types::*;
(
   input logic                  clk,
   input logic                  rst_l,
   input logic                  dbg_rst_l,
   input logic [31:1]           rst_vec,
   input logic                  nmi_int,
   input logic [31:1]           nmi_vec,
   output logic                 core_rst_l,   // This is "rst_l | dbg_rst_l"

   output logic [63:0] trace_rv_i_insn_ip,
   output logic [63:0] trace_rv_i_address_ip,
   output logic [2:0]  trace_rv_i_valid_ip,
   output logic [2:0]  trace_rv_i_exception_ip,
   output logic [4:0]  trace_rv_i_ecause_ip,
   output logic [2:0]  trace_rv_i_interrupt_ip,
   output logic [31:0] trace_rv_i_tval_ip,


   output logic                 lsu_freeze_dc3,
   output logic                 dccm_clk_override,
   output logic                 icm_clk_override,
   output logic                 dec_tlu_core_ecc_disable,

   // external halt/run interface
   input logic  i_cpu_halt_req,    // Asynchronous Halt request to CPU
   input logic  i_cpu_run_req,     // Asynchronous Restart request to CPU
   output logic o_cpu_halt_ack,    // Core Acknowledge to Halt request
   output logic o_cpu_halt_status, // 1'b1 indicates processor is halted
   output logic o_cpu_run_ack,     // Core Acknowledge to run request
   output logic o_debug_mode_status, // Core to the PMU that core is in debug mode. When core is in debug mode, the PMU should refrain from sendng a halt or run request

   // external MPC halt/run interface
   input logic mpc_debug_halt_req, // Async halt request
   input logic mpc_debug_run_req, // Async run request
   input logic mpc_reset_run_req, // Run/halt after reset
   output logic mpc_debug_halt_ack, // Halt ack
   output logic mpc_debug_run_ack, // Run ack
   output logic debug_brkpt_status, // debug breakpoint

   output logic [1:0] dec_tlu_perfcnt0, // toggles when perf counter 0 has an event inc
   output logic [1:0] dec_tlu_perfcnt1,
   output logic [1:0] dec_tlu_perfcnt2,
   output logic [1:0] dec_tlu_perfcnt3,

   // DCCM ports
   output logic                          dccm_wren,
   output logic                          dccm_rden,
   output logic [`RV_DCCM_BITS-1:0]          dccm_wr_addr,
   output logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_lo,
   output logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_hi,
   output logic [`RV_DCCM_FDATA_WIDTH-1:0]   dccm_wr_data,

   input logic [`RV_DCCM_FDATA_WIDTH-1:0]    dccm_rd_data_lo,
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]    dccm_rd_data_hi,

`ifdef RV_ICCM_ENABLE
   // ICCM ports
   output logic [`RV_ICCM_BITS-1:2]           iccm_rw_addr,
   output logic                  iccm_wren,
   output logic                  iccm_rden,
   output logic [2:0]            iccm_wr_size,
   output logic [77:0]           iccm_wr_data,

   input  logic [155:0]          iccm_rd_data,
`endif

   // ICache , ITAG  ports
   output logic [31:2]           ic_rw_addr,
   output logic [3:0]            ic_tag_valid,
   output logic [3:0]            ic_wr_en,
   output logic                  ic_rd_en,

`ifdef RV_ICACHE_ECC
   output logic [83:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [167:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [24:0]               ictag_debug_rd_data,// Debug icache tag.
   output logic [41:0]               ic_debug_wr_data,   // Debug wr cache.
`else
   output logic [67:0]               ic_wr_data,         // Data to fill to the Icache. With Parity
   input  logic [135:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With Parity
   input  logic [20:0]               ictag_debug_rd_data,// Debug icache tag.
   output logic [33:0]               ic_debug_wr_data,   // Debug wr cache.
`endif

   output logic [127:0]              ic_premux_data,     // Premux data to be muxed with each way of the Icache.
   output logic                      ic_sel_premux_data, // Select premux data


   output logic [15:2]               ic_debug_addr,      // Read/Write addresss to the Icache.
   output logic                      ic_debug_rd_en,     // Icache debug rd
   output logic                      ic_debug_wr_en,     // Icache debug wr
   output logic                      ic_debug_tag_array, // Debug tag array
   output logic [3:0]                ic_debug_way,       // Debug way. Rd or Wr.



   input  logic [3:0]            ic_rd_hit,
   input  logic                  ic_tag_perr,        // Icache Tag parity error

`ifdef RV_BUILD_AXI4
   //-------------------------- LSU AXI signals--------------------------
   // AXI Write Channels
   output logic                            lsu_axi_awvalid,
   input  logic                            lsu_axi_awready,
   output logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_awid,
   output logic [31:0]                     lsu_axi_awaddr,
   output logic [3:0]                      lsu_axi_awregion,
   output logic [7:0]                      lsu_axi_awlen,
   output logic [2:0]                      lsu_axi_awsize,
   output logic [1:0]                      lsu_axi_awburst,
   output logic                            lsu_axi_awlock,
   output logic [3:0]                      lsu_axi_awcache,
   output logic [2:0]                      lsu_axi_awprot,
   output logic [3:0]                      lsu_axi_awqos,

   output logic                            lsu_axi_wvalid,
   input  logic                            lsu_axi_wready,
   output logic [63:0]                     lsu_axi_wdata,
   output logic [7:0]                      lsu_axi_wstrb,
   output logic                            lsu_axi_wlast,

   input  logic                            lsu_axi_bvalid,
   output logic                            lsu_axi_bready,
   input  logic [1:0]                      lsu_axi_bresp,
   input  logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_bid,

   // AXI Read Channels
   output logic                            lsu_axi_arvalid,
   input  logic                            lsu_axi_arready,
   output logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_arid,
   output logic [31:0]                     lsu_axi_araddr,
   output logic [3:0]                      lsu_axi_arregion,
   output logic [7:0]                      lsu_axi_arlen,
   output logic [2:0]                      lsu_axi_arsize,
   output logic [1:0]                      lsu_axi_arburst,
   output logic                            lsu_axi_arlock,
   output logic [3:0]                      lsu_axi_arcache,
   output logic [2:0]                      lsu_axi_arprot,
   output logic [3:0]                      lsu_axi_arqos,

   input  logic                            lsu_axi_rvalid,
   output logic                            lsu_axi_rready,
   input  logic [`RV_LSU_BUS_TAG-1:0]      lsu_axi_rid,
   input  logic [63:0]                     lsu_axi_rdata,
   input  logic [1:0]                      lsu_axi_rresp,
   input  logic                            lsu_axi_rlast,

   //-------------------------- IFU AXI signals--------------------------
   // AXI Write Channels
   output logic                            ifu_axi_awvalid,
   input  logic                            ifu_axi_awready,
   output logic [`RV_IFU_BUS_TAG-1:0]      ifu_axi_awid,
   output logic [31:0]                     ifu_axi_awaddr,
   output logic [3:0]                      ifu_axi_awregion,
   output logic [7:0]                      ifu_axi_awlen,
   output logic [2:0]                      ifu_axi_awsize,
   output logic [1:0]                      ifu_axi_awburst,
   output logic                            ifu_axi_awlock,
   output logic [3:0]                      ifu_axi_awcache,
   output logic [2:0]                      ifu_axi_awprot,
   output logic [3:0]                      ifu_axi_awqos,

   output logic                            ifu_axi_wvalid,
   input  logic                            ifu_axi_wready,
   output logic [63:0]                     ifu_axi_wdata,
   output logic [7:0]                      ifu_axi_wstrb,
   output logic                            ifu_axi_wlast,

   input  logic                            ifu_axi_bvalid,
   output logic                            ifu_axi_bready,
   input  logic [1:0]                      ifu_axi_bresp,
   input  logic [`RV_IFU_BUS_TAG-1:0]      ifu_axi_bid,

   // AXI Read Channels
   output logic                            ifu_axi_arvalid,
   input  logic                            ifu_axi_arready,
   output logic [`RV_IFU_BUS_TAG-1:0]      ifu_axi_arid,
   output logic [31:0]                     ifu_axi_araddr,
   output logic [3:0]                      ifu_axi_arregion,
   output logic [7:0]                      ifu_axi_arlen,
   output logic [2:0]                      ifu_axi_arsize,
   output logic [1:0]                      ifu_axi_arburst,
   output logic                            ifu_axi_arlock,
   output logic [3:0]                      ifu_axi_arcache,
   output logic [2:0]                      ifu_axi_arprot,
   output logic [3:0]                      ifu_axi_arqos,

   input  logic                            ifu_axi_rvalid,
   output logic                            ifu_axi_rready,
   input  logic [`RV_IFU_BUS_TAG-1:0]      ifu_axi_rid,
   input  logic [63:0]                     ifu_axi_rdata,
   input  logic [1:0]                      ifu_axi_rresp,
   input  logic                            ifu_axi_rlast,

   //-------------------------- SB AXI signals--------------------------
   // AXI Write Channels
   output logic                            sb_axi_awvalid,
   input  logic                            sb_axi_awready,
   output logic [`RV_SB_BUS_TAG-1:0]       sb_axi_awid,
   output logic [31:0]                     sb_axi_awaddr,
   output logic [3:0]                      sb_axi_awregion,
   output logic [7:0]                      sb_axi_awlen,
   output logic [2:0]                      sb_axi_awsize,
   output logic [1:0]                      sb_axi_awburst,
   output logic                            sb_axi_awlock,
   output logic [3:0]                      sb_axi_awcache,
   output logic [2:0]                      sb_axi_awprot,
   output logic [3:0]                      sb_axi_awqos,

   output logic                            sb_axi_wvalid,
   input  logic                            sb_axi_wready,
   output logic [63:0]                     sb_axi_wdata,
   output logic [7:0]                      sb_axi_wstrb,
   output logic                            sb_axi_wlast,

   input  logic                            sb_axi_bvalid,
   output logic                            sb_axi_bready,
   input  logic [1:0]                      sb_axi_bresp,
   input  logic [`RV_SB_BUS_TAG-1:0]       sb_axi_bid,

   // AXI Read Channels
   output logic                            sb_axi_arvalid,
   input  logic                            sb_axi_arready,
   output logic [`RV_SB_BUS_TAG-1:0]       sb_axi_arid,
   output logic [31:0]                     sb_axi_araddr,
   output logic [3:0]                      sb_axi_arregion,
   output logic [7:0]                      sb_axi_arlen,
   output logic [2:0]                      sb_axi_arsize,
   output logic [1:0]                      sb_axi_arburst,
   output logic                            sb_axi_arlock,
   output logic [3:0]                      sb_axi_arcache,
   output logic [2:0]                      sb_axi_arprot,
   output logic [3:0]                      sb_axi_arqos,

   input  logic                            sb_axi_rvalid,
   output logic                            sb_axi_rready,
   input  logic [`RV_SB_BUS_TAG-1:0]       sb_axi_rid,
   input  logic [63:0]                     sb_axi_rdata,
   input  logic [1:0]                      sb_axi_rresp,
   input  logic                            sb_axi_rlast,

   //-------------------------- DMA AXI signals--------------------------
   // AXI Write Channels
   input  logic                         dma_axi_awvalid,
   output logic                         dma_axi_awready,
   input  logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_awid,
   input  logic [31:0]                  dma_axi_awaddr,
   input  logic [2:0]                   dma_axi_awsize,
   input  logic [2:0]                   dma_axi_awprot,
   input  logic [7:0]                   dma_axi_awlen,
   input  logic [1:0]                   dma_axi_awburst,


   input  logic                         dma_axi_wvalid,
   output logic                         dma_axi_wready,
   input  logic [63:0]                  dma_axi_wdata,
   input  logic [7:0]                   dma_axi_wstrb,
   input  logic                         dma_axi_wlast,

   output logic                         dma_axi_bvalid,
   input  logic                         dma_axi_bready,
   output logic [1:0]                   dma_axi_bresp,
   output logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_bid,

   // AXI Read Channels
   input  logic                         dma_axi_arvalid,
   output logic                         dma_axi_arready,
   input  logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_arid,
   input  logic [31:0]                  dma_axi_araddr,
   input  logic [2:0]                   dma_axi_arsize,
   input  logic [2:0]                   dma_axi_arprot,
   input  logic [7:0]                   dma_axi_arlen,
   input  logic [1:0]                   dma_axi_arburst,

   output logic                         dma_axi_rvalid,
   input  logic                         dma_axi_rready,
   output logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_rid,
   output logic [63:0]                  dma_axi_rdata,
   output logic [1:0]                   dma_axi_rresp,
   output logic                         dma_axi_rlast,

`endif

`ifdef RV_BUILD_AHB_LITE
 //// AHB LITE BUS
   output logic [31:0]           haddr,
   output logic [2:0]            hburst,
   output logic                  hmastlock,
   output logic [3:0]            hprot,
   output logic [2:0]            hsize,
   output logic [1:0]            htrans,
   output logic                  hwrite,

   input  logic [63:0]           hrdata,
   input  logic                  hready,
   input  logic                  hresp,

   // LSU AHB Master
   output logic [31:0]          lsu_haddr,
   output logic [2:0]           lsu_hburst,
   output logic                 lsu_hmastlock,
   output logic [3:0]           lsu_hprot,
   output logic [2:0]           lsu_hsize,
   output logic [1:0]           lsu_htrans,
   output logic                 lsu_hwrite,
   output logic [63:0]          lsu_hwdata,

   input  logic [63:0]          lsu_hrdata,
   input  logic                 lsu_hready,
   input  logic                 lsu_hresp,

   //System Bus Debug Master
   output logic [31:0]          sb_haddr,
   output logic [2:0]           sb_hburst,
   output logic                 sb_hmastlock,
   output logic [3:0]           sb_hprot,
   output logic [2:0]           sb_hsize,
   output logic [1:0]           sb_htrans,
   output logic                 sb_hwrite,
   output logic [63:0]          sb_hwdata,

   input  logic [63:0]          sb_hrdata,
   input  logic                 sb_hready,
   input  logic                 sb_hresp,

   // DMA Slave
   input logic [31:0]            dma_haddr,
   input logic [2:0]             dma_hburst,
   input logic                   dma_hmastlock,
   input logic [3:0]             dma_hprot,
   input logic [2:0]             dma_hsize,
   input logic [1:0]             dma_htrans,
   input logic                   dma_hwrite,
   input logic [63:0]            dma_hwdata,
   input logic                   dma_hsel,
   input logic                   dma_hreadyin,

   output  logic [63:0]          dma_hrdata,
   output  logic                 dma_hreadyout,
   output  logic                 dma_hresp,

`endif //  `ifdef RV_BUILD_AHB_LITE

   input   logic                 lsu_bus_clk_en,
   input   logic                 ifu_bus_clk_en,
   input   logic                 dbg_bus_clk_en,
   input   logic                 dma_bus_clk_en,

   //Debug module
   input  logic                  dmi_reg_en,
   input  logic [6:0]            dmi_reg_addr,
   input  logic                  dmi_reg_wr_en,
   input  logic [31:0]           dmi_reg_wdata,
   output logic [31:0]           dmi_reg_rdata,
   input  logic                  dmi_hard_reset,

   input logic [`RV_PIC_TOTAL_INT:1]           extintsrc_req,
   input logic                   timer_int,
   input logic                   scan_mode
);

`include "global.h"



// for the testbench
// `define DATAWIDTH 64
`define ADDRWIDTH 32

`ifndef RV_BUILD_AXI4

   // LSU AXI signals
   // AXI Write Channels
   logic                         lsu_axi_awvalid;
   logic                         lsu_axi_awready;
   logic [LSU_BUS_TAG-1:0]       lsu_axi_awid;
   logic [31:0]                  lsu_axi_awaddr;
   logic [3:0]                   lsu_axi_awregion;
   logic [7:0]                   lsu_axi_awlen;
   logic [2:0]                   lsu_axi_awsize;
   logic [1:0]                   lsu_axi_awburst;
   logic                         lsu_axi_awlock;
   logic [3:0]                   lsu_axi_awcache;
   logic [2:0]                   lsu_axi_awprot;
   logic [3:0]                   lsu_axi_awqos;

   logic                         lsu_axi_wvalid;
   logic                         lsu_axi_wready;
   logic [63:0]                  lsu_axi_wdata;
   logic [7:0]                   lsu_axi_wstrb;
   logic                         lsu_axi_wlast;

   logic                         lsu_axi_bvalid;
   logic                         lsu_axi_bready;
   logic [1:0]                   lsu_axi_bresp;
   logic [LSU_BUS_TAG-1:0]       lsu_axi_bid;

   // AXI Read Channels
   logic                         lsu_axi_arvalid;
   logic                         lsu_axi_arready;
   logic [LSU_BUS_TAG-1:0]       lsu_axi_arid;
   logic [31:0]                  lsu_axi_araddr;
   logic [3:0]                   lsu_axi_arregion;
   logic [7:0]                   lsu_axi_arlen;
   logic [2:0]                   lsu_axi_arsize;
   logic [1:0]                   lsu_axi_arburst;
   logic                         lsu_axi_arlock;
   logic [3:0]                   lsu_axi_arcache;
   logic [2:0]                   lsu_axi_arprot;
   logic [3:0]                   lsu_axi_arqos;

   logic                         lsu_axi_rvalid;
   logic                         lsu_axi_rready;
   logic [LSU_BUS_TAG-1:0]       lsu_axi_rid;
   logic [63:0]                  lsu_axi_rdata;
   logic [1:0]                   lsu_axi_rresp;
   logic                         lsu_axi_rlast;

   // IFU AXI signals
   // AXI Write Channels
   logic                         ifu_axi_awvalid;
   logic                         ifu_axi_awready;
   logic [IFU_BUS_TAG-1:0]       ifu_axi_awid;
   logic [31:0]                  ifu_axi_awaddr;
   logic [3:0]                   ifu_axi_awregion;
   logic [7:0]                   ifu_axi_awlen;
   logic [2:0]                   ifu_axi_awsize;
   logic [1:0]                   ifu_axi_awburst;
   logic                         ifu_axi_awlock;
   logic [3:0]                   ifu_axi_awcache;
   logic [2:0]                   ifu_axi_awprot;
   logic [3:0]                   ifu_axi_awqos;

   logic                         ifu_axi_wvalid;
   logic                         ifu_axi_wready;
   logic [63:0]                  ifu_axi_wdata;
   logic [7:0]                   ifu_axi_wstrb;
   logic                         ifu_axi_wlast;

   logic                         ifu_axi_bvalid;
   logic                         ifu_axi_bready;
   logic [1:0]                   ifu_axi_bresp;
   logic [IFU_BUS_TAG-1:0]       ifu_axi_bid;

   // AXI Read Channels
   logic                         ifu_axi_arvalid;
   logic                         ifu_axi_arready;
   logic [IFU_BUS_TAG-1:0]       ifu_axi_arid;
   logic [31:0]                  ifu_axi_araddr;
   logic [3:0]                   ifu_axi_arregion;
   logic [7:0]                   ifu_axi_arlen;
   logic [2:0]                   ifu_axi_arsize;
   logic [1:0]                   ifu_axi_arburst;
   logic                         ifu_axi_arlock;
   logic [3:0]                   ifu_axi_arcache;
   logic [2:0]                   ifu_axi_arprot;
   logic [3:0]                   ifu_axi_arqos;

   logic                         ifu_axi_rvalid;
   logic                         ifu_axi_rready;
   logic [IFU_BUS_TAG-1:0]       ifu_axi_rid;
   logic [63:0]                  ifu_axi_rdata;
   logic [1:0]                   ifu_axi_rresp;
   logic                         ifu_axi_rlast;

   // SB AXI signals
   // AXI Write Channels
   logic                         sb_axi_awvalid;
   logic                         sb_axi_awready;
   logic [SB_BUS_TAG-1:0]        sb_axi_awid;
   logic [31:0]                  sb_axi_awaddr;
   logic [3:0]                   sb_axi_awregion;
   logic [7:0]                   sb_axi_awlen;
   logic [2:0]                   sb_axi_awsize;
   logic [1:0]                   sb_axi_awburst;
   logic                         sb_axi_awlock;
   logic [3:0]                   sb_axi_awcache;
   logic [2:0]                   sb_axi_awprot;
   logic [3:0]                   sb_axi_awqos;

   logic                         sb_axi_wvalid;
   logic                         sb_axi_wready;
   logic [63:0]                  sb_axi_wdata;
   logic [7:0]                   sb_axi_wstrb;
   logic                         sb_axi_wlast;

   logic                         sb_axi_bvalid;
   logic                         sb_axi_bready;
   logic [1:0]                   sb_axi_bresp;
   logic [SB_BUS_TAG-1:0]        sb_axi_bid;

   // AXI Read Channels
   logic                         sb_axi_arvalid;
   logic                         sb_axi_arready;
   logic [SB_BUS_TAG-1:0]        sb_axi_arid;
   logic [31:0]                  sb_axi_araddr;
   logic [3:0]                   sb_axi_arregion;
   logic [7:0]                   sb_axi_arlen;
   logic [2:0]                   sb_axi_arsize;
   logic [1:0]                   sb_axi_arburst;
   logic                         sb_axi_arlock;
   logic [3:0]                   sb_axi_arcache;
   logic [2:0]                   sb_axi_arprot;
   logic [3:0]                   sb_axi_arqos;

   logic                         sb_axi_rvalid;
   logic                         sb_axi_rready;
   logic [SB_BUS_TAG-1:0]        sb_axi_rid;
   logic [63:0]                  sb_axi_rdata;
   logic [1:0]                   sb_axi_rresp;
   logic                         sb_axi_rlast;

   // DMA AXI signals
   // AXI Write Channels
   logic                         dma_axi_awvalid;
   logic                         dma_axi_awready;
   logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_awid;
   logic [31:0]                  dma_axi_awaddr;
   logic [2:0]                   dma_axi_awsize;
   logic [2:0]                   dma_axi_awprot;
   logic [3:0]                   dma_axi_awcache;
   logic [7:0]                   dma_axi_awlen;
   logic [1:0]                   dma_axi_awburst;

   logic                         dma_axi_wvalid;
   logic                         dma_axi_wready;
   logic [63:0]                  dma_axi_wdata;
   logic [7:0]                   dma_axi_wstrb;
   logic                         dma_axi_wlast;

   logic                         dma_axi_bvalid;
   logic                         dma_axi_bready;
   logic [1:0]                   dma_axi_bresp;
   logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_bid;

   // AXI Read Channels
   logic                         dma_axi_arvalid;
   logic                         dma_axi_arready;
   logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_arid;
   logic [31:0]                  dma_axi_araddr;
   logic [2:0]                   dma_axi_arsize;
   logic [2:0]                   dma_axi_arprot;
   logic [3:0]                   dma_axi_arcache;
   logic [7:0]                   dma_axi_arlen;
   logic [1:0]                   dma_axi_arburst;

   logic                         dma_axi_rvalid;
   logic                         dma_axi_rready;
   logic [`RV_DMA_BUS_TAG-1:0]   dma_axi_rid;
   logic [63:0]                  dma_axi_rdata;
   logic [1:0]                   dma_axi_rresp;
   logic                         dma_axi_rlast;
`endif

`ifdef RV_BUILD_AHB_LITE
   logic [63:0]              hwdata_nc;
`endif

   //----------------------------------------------------------------------
   //
   //----------------------------------------------------------------------

   logic [1:0]                   ifu_pmu_instr_aligned;
   logic                         ifu_pmu_align_stall;
   logic                         dma_slv_algn_err;
// Icache debug
`ifdef RV_ICACHE_ECC
   logic [41:0] ifu_ic_debug_rd_data; // diagnostic icache read data
`else
   logic [33:0] ifu_ic_debug_rd_data; // diagnostic icache read data
`endif
   logic ifu_ic_debug_rd_data_valid; // diagnostic icache read data valid
   cache_debug_pkt_t dec_tlu_ic_diag_pkt; // packet of DICAWICS, DICAD0/1, DICAGO info for icache diagnostics


   logic  [31:0] gpr_i0_rs1_d;
   logic  [31:0] gpr_i0_rs2_d;
   logic  [31:0] gpr_i1_rs1_d;
   logic  [31:0] gpr_i1_rs2_d;

   logic [31:0] i0_rs1_bypass_data_d;
   logic [31:0] i0_rs2_bypass_data_d;
   logic [31:0] i1_rs1_bypass_data_d;
   logic [31:0] i1_rs2_bypass_data_d;
   logic [31:0] exu_i0_result_e1, exu_i1_result_e1;
   logic  [31:1] exu_i0_pc_e1;
   logic  [31:1] exu_i1_pc_e1;  // from the primary alu's
   logic [31:1]  exu_npc_e4;
   logic [31:1] dec_tlu_i0_pc_e4;
   logic [31:1] dec_tlu_i1_pc_e4;

   alu_pkt_t  i0_ap, i1_ap;

   // Trigger signals
   trigger_pkt_t [3:0]     trigger_pkt_any;
   logic [3:0]             lsu_trigger_match_dc3;
   logic        dec_ib3_valid_d, dec_ib2_valid_d;
   logic        dec_ib1_valid_eff_d;
   logic        dec_ib0_valid_eff_d;


   logic [31:0] dec_i0_immed_d;
   logic [31:0] dec_i1_immed_d;

   logic [12:1] dec_i0_br_immed_d;
   logic [12:1] dec_i1_br_immed_d;

   logic         dec_i0_select_pc_d;
   logic         dec_i1_select_pc_d;

   logic [31:1] dec_i0_pc_d, dec_i1_pc_d;
   logic        dec_i0_rs1_bypass_en_d;
   logic        dec_i0_rs2_bypass_en_d;
   logic        dec_i1_rs1_bypass_en_d;
   logic        dec_i1_rs2_bypass_en_d;


   logic         dec_i0_alu_decode_d;
   logic         dec_i1_alu_decode_d;

   rets_pkt_t exu_rets_e1_pkt;
   rets_pkt_t exu_rets_e4_pkt;

   logic         dec_tlu_cancel_e4;
   logic         ifu_miss_state_idle;
   logic         dec_tlu_flush_noredir_wb;
   logic         dec_tlu_flush_leak_one_wb;
   logic         dec_tlu_flush_err_wb;
   logic         ifu_i0_valid, ifu_i1_valid;
   logic [31:0]  ifu_i0_instr, ifu_i1_instr;
   logic [31:1]  ifu_i0_pc, ifu_i1_pc;

   logic        exu_i0_flush_final;
   logic        exu_i1_flush_final;

   logic        exu_flush_final;    // flush upper; either i0 or i1
   logic        exu_flush_upper_e2;    // flush upper, either i0 or i1

   logic [31:1] exu_flush_path_final;

   logic [31:0] exu_lsu_rs1_d;
   logic [31:0] exu_lsu_rs2_d;


   lsu_pkt_t    lsu_p;

   logic [11:0] dec_lsu_offset_d;
   logic        dec_i0_lsu_d;       // chose which gpr value to use
   logic        dec_i1_lsu_d;

   logic [31:0]  lsu_result_dc3;
   logic [31:0]  lsu_result_corr_dc4;    // ECC corrected lsu load data
   lsu_error_pkt_t lsu_error_pkt_dc3;
   logic         lsu_single_ecc_error_incr;    // Increment the counter for Single ECC error
   logic         lsu_freeze_external_ints_dc3;
   logic         lsu_imprecise_error_load_any;
   logic         lsu_imprecise_error_store_any;
   logic [31:0]  lsu_imprecise_error_addr_any;
   logic         lsu_load_stall_any;       // This is for blocking stores
   logic         lsu_store_stall_any;       // This is for blocking stores
   logic         lsu_load_ecc_stbuf_full_dc3;   // Load with ecc error can't allocate to stbuf
   logic         lsu_idle_any;
   logic         lsu_halt_idle_any;   // This is used to enter halt mode. Exclude DMA

   // Non-blocking loads
   logic                                  lsu_nonblock_load_valid_dc3;
   logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]   lsu_nonblock_load_tag_dc3;
   logic                                  lsu_nonblock_load_inv_dc5;
   logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]   lsu_nonblock_load_inv_tag_dc5;
   logic                                  lsu_nonblock_load_data_valid;
   logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]   lsu_nonblock_load_data_tag;
   logic [31:0]                           lsu_nonblock_load_data;

   logic        flush_final_e3;
   logic        i0_flush_final_e3;

   logic        dec_csr_ren_d;

   logic [31:0] exu_csr_rs1_e1;

   logic        dec_tlu_flush_lower_wb;
   logic        dec_tlu_i0_kill_writeb_wb;    // I0 is flushed, don't writeback any results to arch state
   logic        dec_tlu_i1_kill_writeb_wb;    // I1 is flushed, don't writeback any results to arch state
   logic        dec_tlu_fence_i_wb;           // flush is a fence_i rfnpc, flush icache

   logic dec_tlu_i0_valid_e4;
   logic dec_tlu_i1_valid_e4;
   logic [31:1] dec_tlu_flush_path_wb;
   logic [31:0] dec_tlu_mrac_ff;        // CSR for memory region control

   logic        ifu_i0_pc4, ifu_i1_pc4;

   mul_pkt_t  mul_p;

   logic [31:0] exu_mul_result_e3;

   logic dec_i0_mul_d;
   logic dec_i1_mul_d;

   div_pkt_t  div_p;

   logic [31:0] exu_div_result;
   logic exu_div_finish;
   logic exu_div_stall;


   logic dec_i0_div_d;
   logic dec_i1_div_d;


   logic [15:0] ifu_illegal_inst;

   logic        dec_i1_valid_e1;

   logic        dec_div_decode_e4;

   logic [31:1] pred_correct_npc_e2;

   logic [31:0] exu_i0_result_e4;
   logic [31:0] exu_i1_result_e4;

   logic        dec_i0_rs1_bypass_en_e3;
   logic        dec_i0_rs2_bypass_en_e3;
   logic        dec_i1_rs1_bypass_en_e3;
   logic        dec_i1_rs2_bypass_en_e3;
   logic [31:0] i0_rs1_bypass_data_e3;
   logic [31:0] i0_rs2_bypass_data_e3;
   logic [31:0] i1_rs1_bypass_data_e3;
   logic [31:0] i1_rs2_bypass_data_e3;
   logic        dec_i0_sec_decode_e3;
   logic        dec_i1_sec_decode_e3;
   logic [31:1] dec_i0_pc_e3;
   logic [31:1] dec_i1_pc_e3;

   logic        dec_i0_rs1_bypass_en_e2;
   logic        dec_i0_rs2_bypass_en_e2;
   logic        dec_i1_rs1_bypass_en_e2;
   logic        dec_i1_rs2_bypass_en_e2;
   logic [31:0] i0_rs1_bypass_data_e2;
   logic [31:0] i0_rs2_bypass_data_e2;
   logic [31:0] i1_rs1_bypass_data_e2;
   logic [31:0] i1_rs2_bypass_data_e2;

   logic        exu_i0_flush_lower_e4;     // to tlu for lower branch flushes
   logic        exu_i1_flush_lower_e4;
   logic [31:1] exu_i0_flush_path_e4;
   logic [31:1] exu_i1_flush_path_e4;

   br_tlu_pkt_t dec_tlu_br0_wb_pkt;
   br_tlu_pkt_t dec_tlu_br1_wb_pkt;


   predict_pkt_t  exu_mp_pkt;
   logic [`RV_BHT_GHR_RANGE]  exu_mp_eghr;

   logic [`RV_BHT_GHR_RANGE]  exu_i0_br_fghr_e4;
   logic [1:0]  exu_i0_br_hist_e4;
   logic [1:0]  exu_i0_br_bank_e4;
   logic        exu_i0_br_error_e4;
   logic        exu_i0_br_start_error_e4;
   logic        exu_i0_br_valid_e4;
   logic        exu_i0_br_mp_e4;
   logic        exu_i0_br_ret_e4;
   logic        exu_i0_br_call_e4;
   logic        exu_i0_br_middle_e4;
   logic [`RV_BHT_GHR_RANGE]  exu_i1_br_fghr_e4;

   logic [1:0]  exu_i1_br_hist_e4;
   logic [1:0]  exu_i1_br_bank_e4;
   logic        exu_i1_br_error_e4;
   logic        exu_i1_br_start_error_e4;
   logic        exu_i1_br_valid_e4;
   logic        exu_i1_br_mp_e4;
   logic        exu_i1_br_ret_e4;
   logic        exu_i1_br_call_e4;
   logic        exu_i1_br_middle_e4;

`ifdef RV_BTB_48
   logic [1:0]       exu_i0_br_way_e4;
   logic [1:0]       exu_i1_br_way_e4;
`else
   logic        exu_i0_br_way_e4;
   logic        exu_i1_br_way_e4;
`endif
   logic        dec_i0_lsu_decode_d;

   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i0_br_index_e4;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i1_br_index_e4;

   logic        dma_dccm_req;
   logic        dma_iccm_req;
   logic [31:0] dma_mem_addr;
   logic [2:0]  dma_mem_sz;
   logic        dma_mem_write;
   logic [63:0] dma_mem_wdata;

   logic        dccm_dma_rvalid;
   logic        dccm_dma_ecc_error;
   logic [63:0] dccm_dma_rdata;
   logic        iccm_dma_rvalid;
   logic        iccm_dma_ecc_error;
   logic [63:0] iccm_dma_rdata;

   logic        dma_dccm_stall_any;       // Stall the ld/st in decode if asserted
   logic        dma_iccm_stall_any;       // Stall the fetch
   logic        dccm_ready;
   logic        iccm_ready;

   logic [31:0] i0_result_e4_eff;
   logic [31:0] i1_result_e4_eff;

   logic [31:0] i0_result_e2;

   logic        ifu_i0_icaf;
   logic        ifu_i1_icaf;
   logic        ifu_i0_icaf_second;
   logic        ifu_i1_icaf_second;
   logic        ifu_i0_perr;
   logic        ifu_i1_perr;
   logic        ifu_i0_sbecc;
   logic        ifu_i1_sbecc;
   logic        ifu_i0_dbecc;
   logic        ifu_i1_dbecc;
   logic        iccm_dma_sb_error;

   br_pkt_t i0_brp;
   br_pkt_t i1_brp;

   predict_pkt_t  i0_predict_p_d;
   predict_pkt_t  i1_predict_p_d;

   // logic extint_pend,wakeup;
      // PIC ports
   logic                  picm_wren;
   logic                  picm_rden;
   logic                  picm_mken;
   logic [31:0]           picm_addr;
   logic [31:0]           picm_wr_data;
   logic [31:0]           picm_rd_data;


   // feature disable from mfdc
   logic  dec_tlu_sec_alu_disable;
   logic  dec_tlu_non_blocking_disable;
   logic  dec_tlu_fast_div_disable;
   logic  dec_tlu_bpred_disable;
   logic  dec_tlu_wb_coalescing_disable;
   logic  dec_tlu_ld_miss_byp_wb_disable;
   logic  dec_tlu_sideeffect_posted_disable;
   logic [2:0] dec_tlu_dma_qos_prty;
   // clock gating overrides from mcgc
   logic  dec_tlu_misc_clk_override;
   logic  dec_tlu_exu_clk_override;
   logic  dec_tlu_ifu_clk_override;
   logic  dec_tlu_lsu_clk_override;
   logic  dec_tlu_bus_clk_override;
   logic  dec_tlu_pic_clk_override;
   logic  dec_tlu_dccm_clk_override;
   logic  dec_tlu_icm_clk_override;

   assign        dccm_clk_override = dec_tlu_dccm_clk_override;   // dccm memory
   assign        icm_clk_override = dec_tlu_icm_clk_override;    // icache/iccm memory

   // -----------------------DEBUG  START -------------------------------

   logic [31:0]            dbg_cmd_addr;              // the address of the debug command to used by the core
   logic [31:0]            dbg_cmd_wrdata;            // If the debug command is a write command, this has the data to be written to the CSR/GPR
   logic                   dbg_cmd_valid;             // commad is being driven by the dbg module. One pulse. Only dirven when core_halted has been seen
   logic                   dbg_cmd_write;             // 1: write command; 0: read_command
   logic [1:0]             dbg_cmd_type;              // 0:gpr 1:csr 2: memory
   logic [1:0]             dbg_cmd_size;              // size of the abstract mem access debug command
   logic                   dbg_halt_req;              // Sticky signal indicating that the debug module wants to start the entering of debug mode ( start the halting sequence )
   logic                   dbg_resume_req;            // Sticky signal indicating that the debug module wants to resume from debug mode
   logic                   dbg_core_rst_l;            // Core reset from DM

   logic                   core_dbg_cmd_done;         // Final muxed cmd done to debug
   logic                   core_dbg_cmd_fail;         // Final muxed cmd done to debug
   logic [31:0]            core_dbg_rddata;           // Final muxed cmd done to debug

   logic                   dma_dbg_cmd_done;          // Abstarct memory command sent to dma is done
   logic                   dma_dbg_cmd_fail;          // Abstarct memory command sent to dma failed
   logic [31:0]            dma_dbg_rddata;            // Read data for abstract memory access

   logic                   dbg_dma_bubble;            // Debug needs a bubble to send a valid
   logic                   dma_dbg_ready;             // DMA is ready to accept debug request

   logic [31:0]            dec_dbg_rddata;            // The core drives this data ( intercepts the pipe and sends it here )
   logic                   dec_dbg_cmd_done;          // This will be treated like a valid signal
   logic                   dec_dbg_cmd_fail;          // Abstract command failed
   logic                   dec_tlu_mpc_halted_only;   // Only halted due to MPC
   logic                   dec_tlu_dbg_halted;        // The core has finished the queiscing sequence. Sticks this signal high
   logic                   dec_tlu_pmu_fw_halted;     // The core has finished the queiscing sequence. Sticks this signal high
   logic                   dec_tlu_resume_ack;
   logic                   dec_tlu_debug_mode;        // Core is in debug mode
   logic                   dec_debug_wdata_rs1_d;
   logic                   dec_tlu_stall_dma;         // stall dma accesses, tlu is attempting to enter halt/debug mode

   logic [4:2]             dec_i0_data_en;
   logic [4:1]             dec_i0_ctl_en;
   logic [4:2]             dec_i1_data_en;
   logic [4:1]             dec_i1_ctl_en;

   logic                   dec_nonblock_load_freeze_dc2;

   // PMU Signals
   logic                   exu_pmu_i0_br_misp;
   logic                   exu_pmu_i0_br_ataken;
   logic                   exu_pmu_i0_pc4;
   logic                   exu_pmu_i1_br_misp;
   logic                   exu_pmu_i1_br_ataken;
   logic                   exu_pmu_i1_pc4;

   logic                   lsu_pmu_misaligned_dc3;
   logic                   lsu_pmu_bus_trxn;
   logic                   lsu_pmu_bus_misaligned;
   logic                   lsu_pmu_bus_error;
   logic                   lsu_pmu_bus_busy;

   logic                   ifu_pmu_fetch_stall;
   logic                   ifu_pmu_ic_miss;
   logic                   ifu_pmu_ic_hit;
   logic                   ifu_pmu_bus_error;
   logic                   ifu_pmu_bus_busy;
   logic                   ifu_pmu_bus_trxn;

   logic                   active_state;
   logic                   free_clk, active_clk;
   logic                   dec_pause_state_cg;

   logic                   lsu_nonblock_load_data_error;

   logic [15:0]            ifu_i0_cinst;
   logic [15:0]            ifu_i1_cinst;

   trace_pkt_t  trace_rv_trace_pkt;


   assign active_state = ~dec_pause_state_cg | dec_tlu_flush_lower_wb | dec_tlu_misc_clk_override;

   rvoclkhdr free_cg   ( .en(1'b1),         .l1clk(free_clk), .* );
   rvoclkhdr active_cg ( .en(active_state), .l1clk(active_clk), .* );


   assign core_dbg_cmd_done = dma_dbg_cmd_done | dec_dbg_cmd_done;
   assign core_dbg_cmd_fail = dma_dbg_cmd_fail | dec_dbg_cmd_fail;
   assign core_dbg_rddata[31:0] = dma_dbg_cmd_done ? dma_dbg_rddata[31:0] : dec_dbg_rddata[31:0];

   dbg dbg (
      .clk_override(dec_tlu_misc_clk_override),
      .*
   );

   // -----------------   DEBUG END -----------------------------

   assign core_rst_l = rst_l & (dbg_core_rst_l | scan_mode);

   // fetch
   ifu ifu (
       .clk_override(dec_tlu_ifu_clk_override),
       .rst_l(core_rst_l),
       .*
   );



   dec dec (
            .dbg_cmd_wrdata(dbg_cmd_wrdata[1:0]),
            .rst_l(core_rst_l),
            .*
            );

   exu exu (
      .clk_override(dec_tlu_exu_clk_override),
      .rst_l(core_rst_l),
      .*
   );

   lsu lsu (
      .clk_override(dec_tlu_lsu_clk_override),
      .rst_l(core_rst_l),
      .*
   );

   logic [7:0]  pic_claimid;
   logic [3:0]  pic_pl, dec_tlu_meicurpl, dec_tlu_meipt;

   logic        mexintpend;
   logic        mhwakeup;

   logic        dec_tlu_claim_ack_wb;

   pic_ctrl  pic_ctrl_inst (
                  .clk_override(dec_tlu_pic_clk_override),
                  .picm_mken (picm_mken),
                  .extintsrc_req({extintsrc_req[`RV_PIC_TOTAL_INT:1],1'b0}),
                  .pl(pic_pl[3:0]),
                  .claimid(pic_claimid[7:0]),
                  .meicurpl(dec_tlu_meicurpl[3:0]),
                  .meipt(dec_tlu_meipt[3:0]),
                  .rst_l(core_rst_l),
                     .*);

   dma_ctrl dma_ctrl (
      .rst_l(core_rst_l),
      .clk_override(dec_tlu_misc_clk_override),
      .*
   );

`ifdef RV_BUILD_AHB_LITE

   // AXI4 -> AHB Gasket for LSU
   axi4_to_ahb #(.TAG(LSU_BUS_TAG)) lsu_axi4_to_ahb (
      .clk_override(dec_tlu_bus_clk_override),
      .bus_clk_en(lsu_bus_clk_en),

      // AXI Write Channels
      .axi_awvalid(lsu_axi_awvalid),
      .axi_awready(lsu_axi_awready),
      .axi_awid(lsu_axi_awid[LSU_BUS_TAG-1:0]),
      .axi_awaddr(lsu_axi_awaddr[31:0]),
      .axi_awsize(lsu_axi_awsize[2:0]),
      .axi_awprot(lsu_axi_awprot[2:0]),

      .axi_wvalid(lsu_axi_wvalid),
      .axi_wready(lsu_axi_wready),
      .axi_wdata(lsu_axi_wdata[63:0]),
      .axi_wstrb(lsu_axi_wstrb[7:0]),
      .axi_wlast(lsu_axi_wlast),

      .axi_bvalid(lsu_axi_bvalid),
      .axi_bready(lsu_axi_bready),
      .axi_bresp(lsu_axi_bresp[1:0]),
      .axi_bid(lsu_axi_bid[LSU_BUS_TAG-1:0]),

      // AXI Read Channels
      .axi_arvalid(lsu_axi_arvalid),
      .axi_arready(lsu_axi_arready),
      .axi_arid(lsu_axi_arid[LSU_BUS_TAG-1:0]),
      .axi_araddr(lsu_axi_araddr[31:0]),
      .axi_arsize(lsu_axi_arsize[2:0]),
      .axi_arprot(lsu_axi_arprot[2:0]),

      .axi_rvalid(lsu_axi_rvalid),
      .axi_rready(lsu_axi_rready),
      .axi_rid(lsu_axi_rid[LSU_BUS_TAG-1:0]),
      .axi_rdata(lsu_axi_rdata[63:0]),
      .axi_rresp(lsu_axi_rresp[1:0]),
      .axi_rlast(lsu_axi_rlast),
      // AHB-LITE signals
      .ahb_haddr(lsu_haddr[31:0]),
      .ahb_hburst(lsu_hburst),
      .ahb_hmastlock(lsu_hmastlock),
      .ahb_hprot(lsu_hprot[3:0]),
      .ahb_hsize(lsu_hsize[2:0]),
      .ahb_htrans(lsu_htrans[1:0]),
      .ahb_hwrite(lsu_hwrite),
      .ahb_hwdata(lsu_hwdata[63:0]),

      .ahb_hrdata(lsu_hrdata[63:0]),
      .ahb_hready(lsu_hready),
      .ahb_hresp(lsu_hresp),

      .*
   );

   // AXI4 -> AHB Gasket for System Bus
   axi4_to_ahb #(.TAG(SB_BUS_TAG)) sb_axi4_to_ahb (
      .clk_override(dec_tlu_bus_clk_override),
      .bus_clk_en(dbg_bus_clk_en),

      // AXI Write Channels
      .axi_awvalid(sb_axi_awvalid),
      .axi_awready(sb_axi_awready),
      .axi_awid(sb_axi_awid[SB_BUS_TAG-1:0]),
      .axi_awaddr(sb_axi_awaddr[31:0]),
      .axi_awsize(sb_axi_awsize[2:0]),
      .axi_awprot(sb_axi_awprot[2:0]),

      .axi_wvalid(sb_axi_wvalid),
      .axi_wready(sb_axi_wready),
      .axi_wdata(sb_axi_wdata[63:0]),
      .axi_wstrb(sb_axi_wstrb[7:0]),
      .axi_wlast(sb_axi_wlast),

      .axi_bvalid(sb_axi_bvalid),
      .axi_bready(sb_axi_bready),
      .axi_bresp(sb_axi_bresp[1:0]),
      .axi_bid(sb_axi_bid[SB_BUS_TAG-1:0]),

      // AXI Read Channels
      .axi_arvalid(sb_axi_arvalid),
      .axi_arready(sb_axi_arready),
      .axi_arid(sb_axi_arid[SB_BUS_TAG-1:0]),
      .axi_araddr(sb_axi_araddr[31:0]),
      .axi_arsize(sb_axi_arsize[2:0]),
      .axi_arprot(sb_axi_arprot[2:0]),

      .axi_rvalid(sb_axi_rvalid),
      .axi_rready(sb_axi_rready),
      .axi_rid(sb_axi_rid[SB_BUS_TAG-1:0]),
      .axi_rdata(sb_axi_rdata[63:0]),
      .axi_rresp(sb_axi_rresp[1:0]),
      .axi_rlast(sb_axi_rlast),
      // AHB-LITE signals
      .ahb_haddr(sb_haddr[31:0]),
      .ahb_hburst(sb_hburst),
      .ahb_hmastlock(sb_hmastlock),
      .ahb_hprot(sb_hprot[3:0]),
      .ahb_hsize(sb_hsize[2:0]),
      .ahb_htrans(sb_htrans[1:0]),
      .ahb_hwrite(sb_hwrite),
      .ahb_hwdata(sb_hwdata[63:0]),

      .ahb_hrdata(sb_hrdata[63:0]),
      .ahb_hready(sb_hready),
      .ahb_hresp(sb_hresp),

      .*
   );

   axi4_to_ahb #(.TAG(IFU_BUS_TAG)) ifu_axi4_to_ahb (
      .clk(clk),
      .clk_override(dec_tlu_bus_clk_override),
      .bus_clk_en(ifu_bus_clk_en),

       // AHB-Lite signals
      .ahb_haddr(haddr[31:0]),
      .ahb_hburst(hburst),
      .ahb_hmastlock(hmastlock),
      .ahb_hprot(hprot[3:0]),
      .ahb_hsize(hsize[2:0]),
      .ahb_htrans(htrans[1:0]),
      .ahb_hwrite(hwrite),
      .ahb_hwdata(hwdata_nc[63:0]),

      .ahb_hrdata(hrdata[63:0]),
      .ahb_hready(hready),
      .ahb_hresp(hresp),

      // AXI Write Channels
      .axi_awvalid(ifu_axi_awvalid),
      .axi_awready(ifu_axi_awready),
      .axi_awid(ifu_axi_awid[IFU_BUS_TAG-1:0]),
      .axi_awaddr(ifu_axi_awaddr[31:0]),
      .axi_awsize(ifu_axi_awsize[2:0]),
      .axi_awprot(ifu_axi_awprot[2:0]),

      .axi_wvalid(ifu_axi_wvalid),
      .axi_wready(ifu_axi_wready),
      .axi_wdata(ifu_axi_wdata[63:0]),
      .axi_wstrb(ifu_axi_wstrb[7:0]),
      .axi_wlast(ifu_axi_wlast),

      .axi_bvalid(ifu_axi_bvalid),
      .axi_bready(ifu_axi_bready),
      .axi_bresp(ifu_axi_bresp[1:0]),
      .axi_bid(ifu_axi_bid[IFU_BUS_TAG-1:0]),

      // AXI Read Channels
      .axi_arvalid(ifu_axi_arvalid),
      .axi_arready(ifu_axi_arready),
      .axi_arid(ifu_axi_arid[IFU_BUS_TAG-1:0]),
      .axi_araddr(ifu_axi_araddr[31:0]),
      .axi_arsize(ifu_axi_arsize[2:0]),
      .axi_arprot(ifu_axi_arprot[2:0]),

      .axi_rvalid(ifu_axi_rvalid),
      .axi_rready(ifu_axi_rready),
      .axi_rid(ifu_axi_rid[IFU_BUS_TAG-1:0]),
      .axi_rdata(ifu_axi_rdata[63:0]),
      .axi_rresp(ifu_axi_rresp[1:0]),
      .axi_rlast(ifu_axi_rlast),
      .*
   );

   //AHB -> AXI4 Gasket for DMA
   ahb_to_axi4 #(.TAG(DMA_BUS_TAG)) dma_ahb_to_axi4 (
      .clk_override(dec_tlu_bus_clk_override),
      .bus_clk_en(dma_bus_clk_en),

      // AXI Write Channels
      .axi_awvalid(dma_axi_awvalid),
      .axi_awready(dma_axi_awready),
      .axi_awid(dma_axi_awid[DMA_BUS_TAG-1:0]),
      .axi_awaddr(dma_axi_awaddr[31:0]),
      .axi_awsize(dma_axi_awsize[2:0]),
      .axi_awprot(dma_axi_awprot[2:0]),
      .axi_awlen(dma_axi_awlen[7:0]),
      .axi_awburst(dma_axi_awburst[1:0]),

      .axi_wvalid(dma_axi_wvalid),
      .axi_wready(dma_axi_wready),
      .axi_wdata(dma_axi_wdata[63:0]),
      .axi_wstrb(dma_axi_wstrb[7:0]),
      .axi_wlast(dma_axi_wlast),

      .axi_bvalid(dma_axi_bvalid),
      .axi_bready(dma_axi_bready),
      .axi_bresp(dma_axi_bresp[1:0]),
      .axi_bid(dma_axi_bid[DMA_BUS_TAG-1:0]),

      // AXI Read Channels
      .axi_arvalid(dma_axi_arvalid),
      .axi_arready(dma_axi_arready),
      .axi_arid(dma_axi_arid[DMA_BUS_TAG-1:0]),
      .axi_araddr(dma_axi_araddr[31:0]),
      .axi_arsize(dma_axi_arsize[2:0]),
      .axi_arprot(dma_axi_arprot[2:0]),
      .axi_arlen(dma_axi_arlen[7:0]),
      .axi_arburst(dma_axi_arburst[1:0]),

      .axi_rvalid(dma_axi_rvalid),
      .axi_rready(dma_axi_rready),
      .axi_rid(dma_axi_rid[DMA_BUS_TAG-1:0]),
      .axi_rdata(dma_axi_rdata[63:0]),
      .axi_rresp(dma_axi_rresp[1:0]),

       // AHB signals
      .ahb_haddr(dma_haddr[31:0]),
      .ahb_hburst(dma_hburst),
      .ahb_hmastlock(dma_hmastlock),
      .ahb_hprot(dma_hprot[3:0]),
      .ahb_hsize(dma_hsize[2:0]),
      .ahb_htrans(dma_htrans[1:0]),
      .ahb_hwrite(dma_hwrite),
      .ahb_hwdata(dma_hwdata[63:0]),

      .ahb_hrdata(dma_hrdata[63:0]),
      .ahb_hreadyout(dma_hreadyout),
      .ahb_hresp(dma_hresp),
      .ahb_hreadyin(dma_hreadyin),
      .ahb_hsel(dma_hsel),
      .*
   );

`endif


`ifdef RV_BUILD_AHB_LITE
`ifdef ASSERT_ON
   property ahb_trxn_aligned;
     @(posedge clk) disable iff(~rst_l) (lsu_htrans[1:0] != 2'b0)  |-> ((lsu_hsize[2:0] == 3'h0)                              |
                                                                        ((lsu_hsize[2:0] == 3'h1) & (lsu_haddr[0] == 1'b0))   |
                                                                        ((lsu_hsize[2:0] == 3'h2) & (lsu_haddr[1:0] == 2'b0)) |
                                                                        ((lsu_hsize[2:0] == 3'h3) & (lsu_haddr[2:0] == 3'b0)));
   endproperty
   assert_ahb_trxn_aligned: assert property (ahb_trxn_aligned) else
     $display("Assertion ahb_trxn_aligned failed: lsu_htrans=2'h%h, lsu_hsize=3'h%h, lsu_haddr=32'h%h",lsu_htrans[1:0], lsu_hsize[2:0], lsu_haddr[31:0]);

   property dma_trxn_aligned;
     @(posedge clk) disable iff(~rst_l) (dma_htrans[1:0] != 2'b0)  |-> ((dma_hsize[2:0] == 3'h0)                              |
                                                                        ((dma_hsize[2:0] == 3'h1) & (dma_haddr[0] == 1'b0))   |
                                                                        ((dma_hsize[2:0] == 3'h2) & (dma_haddr[1:0] == 2'b0)) |
                                                                        ((dma_hsize[2:0] == 3'h3) & (dma_haddr[2:0] == 3'b0)));
   endproperty
   //assert_dma_trxn_aligned: assert property (dma_trxn_aligned) else
   //  $display("Assertion dma_trxn_aligned failed: dma_htrans=2'h%h, dma_hsize=3'h%h, dma_haddr=32'h%h",dma_htrans[1:0], dma_hsize[2:0], dma_haddr[31:0]);

`endif
`endif


      // unpack packet
      // also need retires_p==3

      assign trace_rv_i_insn_ip[63:0]     = trace_rv_trace_pkt.trace_rv_i_insn_ip[63:0];

      assign trace_rv_i_address_ip[63:0]  = trace_rv_trace_pkt.trace_rv_i_address_ip[63:0];

      assign trace_rv_i_valid_ip[2:0]     = trace_rv_trace_pkt.trace_rv_i_valid_ip[2:0];

      assign trace_rv_i_exception_ip[2:0] = trace_rv_trace_pkt.trace_rv_i_exception_ip[2:0];

      assign trace_rv_i_ecause_ip[4:0]    = trace_rv_trace_pkt.trace_rv_i_ecause_ip[4:0];

      assign trace_rv_i_interrupt_ip[2:0] = trace_rv_trace_pkt.trace_rv_i_interrupt_ip[2:0];

      assign trace_rv_i_tval_ip[31:0]     = trace_rv_trace_pkt.trace_rv_i_tval_ip[31:0];


   // constants should be hooked up at platform level
   // trace_rv_i_context_ip   = '0;
   // trace_rv_i_privilege_ip = {3{4'b0011}};
   // trace_rv_i_status_ip    = '0;
   // trace_rv_i_user_ip      = '0;

   // trace_rv_halted_ip = o_cpu_halt_status;   hook this up at platform level





endmodule // swerv

