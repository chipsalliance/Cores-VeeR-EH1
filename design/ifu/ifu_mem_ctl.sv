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


//********************************************************************************
// Function: Icache , iccm  control
// BFF -> F1 -> F2 -> A
//********************************************************************************

module ifu_mem_ctl
   import swerv_types::*;
(
   input logic clk,
   input logic free_clk,                                            // free clock always except during pause
   input logic active_clk,                                          // Active always except during pause
   input logic rst_l,

   input logic                       exu_flush_final,               // Flush from the pipeline.
   input logic                       dec_tlu_flush_err_wb,          // Flush from the pipeline due to perr.

   input logic [31:1]                fetch_addr_f1,                 // Fetch Address byte aligned always.      F1 stage.
   input logic                       ifc_fetch_uncacheable_f1,      // The fetch request is uncacheable space. F1 stage
   input logic                       ifc_fetch_req_f1,              // Fetch request. Comes with the address.  F1 stage
   input logic                       ifc_fetch_req_f1_raw,          // Fetch request without some qualifications. Used for clock-gating. F1 stage
   input logic                       ifc_iccm_access_f1,            // This request is to the ICCM. Do not generate misses to the bus.
   input logic                       ifc_region_acc_fault_f1,       // Access fault. in ICCM region but offset is outside defined ICCM.
   input logic                       ifc_dma_access_ok,             // It is OK to give dma access to the ICCM. (ICCM is not busy this cycle).
   input logic                       dec_tlu_fence_i_wb,            // Fence.i instruction is committing. Clear all Icache valids.


   input logic [16:6]                ifu_icache_error_index,        //  Index with parity/ecc error
   input logic                       ifu_icache_error_val,          //  Parity/Ecc  error
   input logic                       ifu_icache_sb_error_val,       //  single bit iccm  error
   input logic [7:1]                 ifu_bp_inst_mask_f2,           // tell ic which valids to kill because of a taken branch, right justified

   output logic                      ifu_miss_state_idle,           // No icache misses are outstanding.
   output logic                      ifu_ic_mb_empty,               // Continue with normal fetching. This does not mean that miss is finished.
   output logic                      ic_dma_active  ,               // In the middle of servicing dma request to ICCM. Do not make any new requests.
   output logic                      ic_write_stall,                // Stall fetch the cycle we are writing the cache.

/// PMU signals
   output logic                      ifu_pmu_ic_miss,               // IC miss event
   output logic                      ifu_pmu_ic_hit,                // IC hit event
   output logic                      ifu_pmu_bus_error,             // Bus error event
   output logic                      ifu_pmu_bus_busy,              // Bus busy event
   output logic                      ifu_pmu_bus_trxn,              // Bus transaction

   // AXI Write Channels - IFU never writes. So, 0 out mostly
   output logic                           ifu_axi_awvalid,
   input  logic                           ifu_axi_awready,
   output logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_awid,
   output logic [31:0]                    ifu_axi_awaddr,
   output logic [3:0]                     ifu_axi_awregion,
   output logic [7:0]                     ifu_axi_awlen,
   output logic [2:0]                     ifu_axi_awsize,
   output logic [1:0]                     ifu_axi_awburst,
   output logic                           ifu_axi_awlock,
   output logic [3:0]                     ifu_axi_awcache,
   output logic [2:0]                     ifu_axi_awprot,
   output logic [3:0]                     ifu_axi_awqos,

   output logic                           ifu_axi_wvalid,
   input  logic                           ifu_axi_wready,
   output logic [63:0]                    ifu_axi_wdata,
   output logic [7:0]                     ifu_axi_wstrb,
   output logic                           ifu_axi_wlast,

   input  logic                           ifu_axi_bvalid,
   output logic                           ifu_axi_bready,
   input  logic [1:0]                     ifu_axi_bresp,
   input  logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_bid,

   // AXI Read Channels
   output logic                           ifu_axi_arvalid,
   input  logic                           ifu_axi_arready,
   output logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_arid,
   output logic [31:0]                    ifu_axi_araddr,
   output logic [3:0]                     ifu_axi_arregion,
   output logic [7:0]                     ifu_axi_arlen,
   output logic [2:0]                     ifu_axi_arsize,
   output logic [1:0]                     ifu_axi_arburst,
   output logic                           ifu_axi_arlock,
   output logic [3:0]                     ifu_axi_arcache,
   output logic [2:0]                     ifu_axi_arprot,
   output logic [3:0]                     ifu_axi_arqos,

   input  logic                           ifu_axi_rvalid,
   output logic                           ifu_axi_rready,
   input  logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_rid,
   input  logic [63:0]                    ifu_axi_rdata,
   input  logic [1:0]                     ifu_axi_rresp,
   input  logic                           ifu_axi_rlast,

    /// SCVI Bus interface
    input  logic                     ifu_bus_clk_en,


   input  logic                      dma_iccm_req,      //  dma iccm command (read or write)
   input  logic [31:0]               dma_mem_addr,      //  dma address
   input  logic [2:0]                dma_mem_sz,        //  size
   input  logic                      dma_mem_write,     //  write
   input  logic [63:0]               dma_mem_wdata,     //  write data

   output logic                      iccm_dma_ecc_error,//   Data read from iccm has an ecc error
   output logic                      iccm_dma_rvalid,   //   Data read from iccm is valid
   output logic [63:0]               iccm_dma_rdata,    //   dma data read from iccm
   output logic                      iccm_ready,        //   iccm ready to accept new command.


//   I$ & ITAG Ports
   output logic [31:2]               ic_rw_addr,         // Read/Write addresss to the Icache.
   output logic [3:0]                ic_wr_en,           // Icache write enable, when filling the Icache.
   output logic                      ic_rd_en,           // Icache read  enable.

`ifdef RV_ICACHE_ECC
   output logic [83:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [167:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [24:0]               ictag_debug_rd_data,// Debug icache tag.
   output logic [41:0]               ic_debug_wr_data,   // Debug wr cache.
   output logic [41:0]               ifu_ic_debug_rd_data,       // debug data read
`else
   output logic [67:0]               ic_wr_data,         // Data to fill to the Icache. With Parity
   input  logic [135:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With Parity
   input  logic [20:0]               ictag_debug_rd_data,// Debug icache tag.
   output logic [33:0]               ic_debug_wr_data,   // Debug wr cache.
   output logic [33:0]               ifu_ic_debug_rd_data,       // debug data read
`endif

   output logic [15:2]               ic_debug_addr,      // Read/Write addresss to the Icache.
   output logic                      ic_debug_rd_en,     // Icache debug rd
   output logic                      ic_debug_wr_en,     // Icache debug wr
   output logic                      ic_debug_tag_array, // Debug tag array
   output logic [3:0]                ic_debug_way,       // Debug way. Rd or Wr.


   output logic [3:0]                ic_tag_valid,       // Valid bits when accessing the Icache. One valid bit per way. F2 stage

   input  logic [3:0]                ic_rd_hit,          // Compare hits from Icache tags. Per way.  F2 stage
   input  logic                      ic_tag_perr,        // Icache Tag parity error

`ifdef RV_ICCM_ENABLE
   // ICCM ports
   output logic [`RV_ICCM_BITS-1:2]  iccm_rw_addr,       // ICCM read/write address.
   output logic                      iccm_wren,          // ICCM write enable (through the DMA)
   output logic                      iccm_rden,          // ICCM read enable.
   output logic [77:0]               iccm_wr_data,       // ICCM write data.
   output logic [2:0]                iccm_wr_size,       // ICCM write location within DW.

   input  logic [155:0]              iccm_rd_data,       // Data read from ICCM.
`endif


   // IFU control signals
   output logic                      ic_hit_f2,              // Hit in Icache(if Icache access) or ICCM access( ICCM always has ic_hit_f2)
   output logic                      ic_crit_wd_rdy,         // Critical fetch is ready to be bypassed.
   output logic  [7:0]               ic_access_fault_f2,     // Access fault (bus error or ICCM access in region but out of offset range).
   output logic                      ic_rd_parity_final_err, // This fetch has an tag parity error.
   output logic                      iccm_rd_ecc_single_err, // This fetch has a single ICCM ecc  error.
   output logic  [7:0]               iccm_rd_ecc_double_err, // This fetch has a double ICCM ecc  error.
   output logic                      iccm_dma_sb_error,      // Single Bit ECC error from a DMA access
   output logic [7:0]                ic_fetch_val_f2,        // valid bytes for fetch. To the Aligner.
   output logic [127:0]              ic_data_f2,             // Data read from Icache or ICCM. To the Aligner.
   output icache_err_pkt_t           ic_error_f2 ,           // Parity or ECC bits for the Icache Data
   output logic                      ifu_icache_fetch_f2  ,
   output logic [127:0]              ic_premux_data,         // Premuxed data to be muxed with Icache data
   output logic                      ic_sel_premux_data,     // Select premux data.

/////  Debug
   input  cache_debug_pkt_t          dec_tlu_ic_diag_pkt ,       // Icache/tag debug read/write packet
   input  logic                      dec_tlu_core_ecc_disable,   // disable the ecc checking and flagging
   output logic                      ifu_ic_debug_rd_data_valid, // debug data valid.


   input  logic         scan_mode
   );

`include "global.h"

//  Create different defines for ICACHE and ICCM enable combinations
`ifdef RV_ICCM_ENABLE
     `ifdef RV_ICACHE_ENABLE
        `define ICCM_AND_ICACHE
      `else
        `define ICCM_AND_NOT_ICACHE
      `endif
`else
     `ifdef RV_ICACHE_ENABLE
        `define NOT_ICCM_AND_ICACHE
      `else
        `define NOT_ICCM_AND_NOT_ICACHE
      `endif
`endif


 localparam   NUM_OF_BEATS = 8 ;



   logic [31:3]    ifu_ic_req_addr_f2;
   logic           uncacheable_miss_in ;
   logic           uncacheable_miss_ff;


   logic           ifu_wr_en_new  ;
   logic           ifu_wr_en_new_q  ;
   logic [63:0]    ifu_wr_data_new ;

   logic           axi_ifu_wr_en_new  ;
   logic           axi_ifu_wr_en_new_q  ;
   logic           axi_ifu_wr_en_new_wo_err  ;
   logic [63:0]    axi_ifu_wr_data_new ;
   logic [3:0]     axi_ic_wr_en ;

   logic           reset_tag_valid_for_miss  ;


   logic [2:0]     way_status;
   logic [2:0]     way_status_mb_in;
   logic [2:0]     way_status_rep_new;
   logic [2:0]     way_status_mb_ff;
   logic [2:0]     way_status_new;
   logic [2:0]     way_status_hit_new;
   logic [2:0]     way_status_new_w_debug;
   logic [3:0]     tagv_mb_in;
   logic [3:0]     tagv_mb_ff;


   logic           ifu_wr_data_comb_err ;
   logic           ifu_wr_data_error;
   logic  [7:0]    ifu_byp_data_err;
   logic           ifu_wr_cumulative_err_data;
   logic           ifu_wr_cumulative_err;
   logic           ifu_wr_data_comb_err_ff;
   logic           write_even_beat;


   logic           ifc_dma_access_q_ok;
   logic           ifc_iccm_access_f2 ;
   logic           ifc_region_acc_fault_f2;
   logic  [7:0]    ifc_bus_acc_fault_f2;
   logic           ic_act_miss_f2;
   logic           ic_miss_under_miss_f2;
   logic           ic_act_hit_f2;
   logic           miss_pending;
   logic [31:1]    imb_in , imb_ff  ;
   logic           flush_final_f2;
   logic           ifc_fetch_req_f2;
   logic           ifc_fetch_req_f2_raw;
   logic           fetch_req_f2_qual   ;
   logic           ifc_fetch_req_qual_f1 ;
   logic [3:0]     replace_way_mb_any;
   logic           last_beat;
   logic           reset_beat_cnt  ;
   logic [2:0]     req_addr_count ;
   logic [5:3]     ic_req_addr_bits_5_3 ;
   logic [5:3]     ic_wr_addr_bits_5_3 ;
   logic [31:1]    ifu_fetch_addr_int_f2 ;
   logic [31:1]    ifu_ic_rw_int_addr ;
   logic           ic_crit_wd_rdy_in ;
   logic           crit_wd_byp_ok_ff ;
   logic           ic_crit_wd_rdy_ff;
   logic           ic_byp_hit_f2 ;
   logic           ic_valid ;
   logic           ic_valid_ff;
   logic           reset_all_tags;
   logic           ic_valid_w_debug;

   logic [3:0]     ifu_tag_wren,ifu_tag_wren_ff;
   logic [3:0]     ic_debug_tag_wr_en;
   logic [3:0]     ifu_tag_wren_w_debug;
   logic [3:0]     ic_debug_way_ff;
   logic           ic_debug_rd_en_ff   ;
   logic           write_bypass_data;
   logic           fetch_f1_f2_c1_clken ;
   logic           fetch_f1_f2_c1_clk;
   logic           debug_c1_clken;
   logic           debug_c1_clk;

   logic           reset_ic_in ;
   logic           reset_ic_ff ;
   logic [3:1]     vaddr_f2 ;
   logic [31:1]    ifu_status_wr_addr;
   logic           sel_fetch_u_miss;
   logic           sel_fetch_u_miss_ff;
   logic           sel_mb_addr ;
   logic           sel_mb_addr_ff ;
   logic [127:0]   ic_final_data;

   logic [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] ifu_ic_rw_int_addr_ff ;
   logic [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] ifu_status_wr_addr_ff ;
   logic [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] ifu_ic_rw_int_addr_w_debug ;
   logic [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] ifu_status_wr_addr_w_debug ;

   logic [2:0]                              way_status_new_ff ;
   logic                                    way_status_wr_en_ff ;
   logic [ICACHE_TAG_DEPTH-1:0][2:0]        way_status_out ;
   logic [1:0]                              ic_debug_way_enc;
   logic [127:0]                            ic_byp_data_only;
   logic [127:0]                            ic_rd_data_only;

   logic [`RV_IFU_BUS_TAG-1:0]             ifu_axi_rid_ff;

   logic         fetch_req_icache_f2;
   logic         fetch_req_iccm_f2;
   logic         ic_iccm_hit_f2;
   logic         fetch_uncacheable_ff;
   logic         way_status_wr_en;
   logic         sel_byp_data;
   logic         sel_ic_data;
   logic         sel_iccm_data;
   logic         ic_rd_parity_final_err_ff;
   logic         ic_act_miss_f2_delayed;
   logic         axi_ifu_wr_data_error;
   logic         way_status_wr_en_w_debug;
   logic         ic_debug_tag_val_rd_out;
   logic         ifu_pmu_ic_miss_in;
   logic         ifu_pmu_ic_hit_in;
   logic         ifu_pmu_bus_error_in;
   logic         ifu_pmu_bus_trxn_in;
   logic         ifu_pmu_bus_busy_in;
   logic         ic_debug_ict_array_sel_in;
   logic         ic_debug_ict_array_sel_ff;
   logic         debug_data_clk;
   logic         debug_data_clken;
   logic                   ifc_region_acc_fault_final_f1, ifc_region_acc_fault_memory, ifc_region_acc_okay;


`ifdef RV_ICACHE_ECC
   logic [19:0]  ic_wr_ecc;
   logic [3:0] [1:0] ic_wr_ecc0_unused;   // bit 6:5 are not used for a the 16bit sedded

`else
   logic [3:0]   ic_wr_parity;
`endif



   assign ifu_axi_awvalid                        = '0;
   assign ifu_axi_awid[`RV_IFU_BUS_TAG-1:0]      = '0;
   assign ifu_axi_awaddr[31:0]                   = '0;
   assign ifu_axi_awsize[2:0]                    = '0;
   assign ifu_axi_awprot[2:0]                    = '0;
   assign ifu_axi_awcache[3:0]                   = '0;
   assign ifu_axi_awregion[3:0]                  = '0;
   assign ifu_axi_awlen[7:0]                     = '0;
   assign ifu_axi_awburst[1:0]                   = '0;
   assign ifu_axi_awqos[3:0]                     = '0;
   assign ifu_axi_awlock                         = '0;
   // AXI Write Data Channel
   assign ifu_axi_wvalid                         = '0;
   assign ifu_axi_wdata[63:0]                    = '0;
   assign ifu_axi_wstrb[7:0]                     = '0;
   assign ifu_axi_wlast                          = '1;
   // AXI Write Response Channel
   assign ifu_axi_bready                         = '1;


// ---- Clock gating section -----
// c1 clock enables


   assign fetch_f1_f2_c1_clken  = ifc_fetch_req_f1_raw | ifc_fetch_req_f2 | miss_pending | exu_flush_final ;
   assign debug_c1_clken        = ic_debug_rd_en | ic_debug_wr_en ;
   // C1 - 1 clock pulse for data



// ------ end clock gating section ------------------------


   logic [ICCM_BITS-1:2]                iccm_ecc_corr_index_ff;
   logic [38:0]                         iccm_ecc_corr_data_ff;
   logic                                iccm_ecc_write_status     ;
   logic                                iccm_correct_ecc     ;
   logic                                iccm_rd_ecc_single_err_ff   ;
   logic                                perr_state_en;
   logic [7:0] fetch_mask, ic_fetch_mem_val, bp_mask, ic_bp_mem_mask, ic_fetch_val_mem_f2;
   logic                                dma_iccm_rd_req_f1;
   logic                                dma_iccm_rd_req_f2;
   logic [3:0]                          iccm_single_ecc_error;

   assign dma_iccm_rd_req_f1  = (dma_iccm_req & ~dma_mem_write) ;
   rvdff #(1)  dma_iccm_req_ff (.*, .clk(free_clk), .din (dma_iccm_rd_req_f1), .dout(dma_iccm_rd_req_f2));

   assign iccm_dma_sb_error  = (|iccm_single_ecc_error ) & dma_iccm_rd_req_f2;


   typedef enum logic [2:0] {ERR_IDLE=3'b000, PERR_WFF=3'b001 , ECC_WFF=3'b010 , ECC_CORR=3'b011, DMA_SB_ERR=3'b100} perr_state_t;
   perr_state_t perr_state, perr_nxtstate;


   assign ic_dma_active =  iccm_correct_ecc | (perr_state == DMA_SB_ERR) | (dec_tlu_flush_err_wb & (perr_state == ECC_WFF));
   //////////////////////////////////// Create Miss State Machine ///////////////////////
   //                                   Create Miss State Machine                      //
   //                                   Create Miss State Machine                      //
   //                                   Create Miss State Machine                      //
   //////////////////////////////////// Create Miss State Machine ///////////////////////
   logic   miss_state_en;

   typedef enum logic [2:0] {IDLE=3'b000, CRIT_BYP_OK=3'b001, HIT_U_MISS=3'b010, MISS_WAIT=3'b011,CRIT_WRD_RDY=3'b100,SCND_MISS=3'b101} miss_state_t;
   miss_state_t miss_state, miss_nxtstate;

   // FIFO state machine
   always_comb begin : MISS_SM
      miss_nxtstate   = IDLE;
      miss_state_en   = 1'b0;
      case (miss_state)
         IDLE: begin : idle
                  miss_nxtstate = (ic_act_miss_f2 & ~exu_flush_final) ? CRIT_BYP_OK : HIT_U_MISS ;
                  miss_state_en = ic_act_miss_f2;
         end
         CRIT_BYP_OK: begin : crit_byp_ok
                  miss_nxtstate = ( ic_byp_hit_f2 &  ~exu_flush_final & ~(ifu_wr_en_new & last_beat) & ~uncacheable_miss_ff) ? MISS_WAIT :
                                  ( ic_byp_hit_f2                                                    &  uncacheable_miss_ff) ? IDLE :
                                  (~ic_byp_hit_f2 &  ~exu_flush_final &  (ifu_wr_en_new & last_beat) &  uncacheable_miss_ff) ? CRIT_WRD_RDY :
                                  (                                      (ifu_wr_en_new & last_beat) & ~uncacheable_miss_ff) ? IDLE :
                                  (                   exu_flush_final & ~(ifu_wr_en_new & last_beat)                       ) ? HIT_U_MISS : IDLE;
                  miss_state_en =  exu_flush_final | ic_byp_hit_f2 | (ifu_wr_en_new & last_beat)  ;
         end
         CRIT_WRD_RDY: begin : crit_wrd_rdy
                  miss_nxtstate =  IDLE ;
                  miss_state_en =  exu_flush_final | flush_final_f2 | ic_byp_hit_f2   ;
         end
         MISS_WAIT: begin : miss_wait
                  miss_nxtstate =  (exu_flush_final & ~(ifu_wr_en_new & last_beat)) ? HIT_U_MISS  : IDLE ;
                  miss_state_en =   exu_flush_final | (ifu_wr_en_new & last_beat)  ;
         end
         HIT_U_MISS: begin : hit_u_miss
                  miss_nxtstate =  ic_miss_under_miss_f2 & ~(ifu_wr_en_new & last_beat) ? SCND_MISS :  IDLE  ;
                  miss_state_en = (ifu_wr_en_new & last_beat) | ic_miss_under_miss_f2;
         end
         SCND_MISS: begin : scnd_miss
                  miss_nxtstate =  IDLE  ;
                  miss_state_en = (ifu_wr_en_new & last_beat)  ;
         end
         default: begin : def_case
                  miss_nxtstate   = IDLE;
                  miss_state_en   = 1'b0;
         end
      endcase
   end
   rvdffs #(($bits(miss_state_t))) miss_state_ff (.clk(free_clk), .din(miss_nxtstate), .dout({miss_state}), .en(miss_state_en),   .*);
   logic    sel_hold_imb     ;

   assign miss_pending       =  (miss_state != IDLE) ;
   assign crit_wd_byp_ok_ff  =  (miss_state == CRIT_BYP_OK) | ((miss_state == CRIT_WRD_RDY) & ~flush_final_f2);
   assign sel_hold_imb       =  (miss_pending & ~(ifu_wr_en_new & last_beat) & ~((miss_state == CRIT_WRD_RDY) & exu_flush_final)) | ic_act_miss_f2 |
                                (miss_pending & (miss_nxtstate == CRIT_WRD_RDY)) ;




   assign ic_req_addr_bits_5_3[5:3] = req_addr_count[2:0] ;
   assign ic_wr_addr_bits_5_3[5:3]  = ifu_axi_rid_ff[2:0] ;
   // NOTE: Cacheline size is 16 bytes in this example.
   // Tag     Index  Bank Offset
   // [31:16] [15:5] [4]  [3:0]


   assign fetch_req_icache_f2   = ifc_fetch_req_f2 & ~ifc_iccm_access_f2 & ~ifc_region_acc_fault_f2;
   assign fetch_req_iccm_f2     = ifc_fetch_req_f2 &  ifc_iccm_access_f2;

   assign ic_iccm_hit_f2        = fetch_req_iccm_f2  &  (~miss_pending | (miss_state==HIT_U_MISS));
   assign ic_byp_hit_f2         = ic_crit_wd_rdy  & fetch_req_icache_f2 &  miss_pending ;
   assign ic_act_hit_f2         = (|ic_rd_hit[3:0]) & fetch_req_icache_f2 & ~reset_all_tags & (~miss_pending | (miss_state==HIT_U_MISS)) & ~sel_mb_addr_ff;
   assign ic_act_miss_f2        = (~(|ic_rd_hit[3:0]) | reset_all_tags) & fetch_req_icache_f2 & ~miss_pending & ~ifc_region_acc_fault_f2;
   assign ic_miss_under_miss_f2 = (~(|ic_rd_hit[3:0]) | reset_all_tags) & fetch_req_icache_f2 & (miss_state == HIT_U_MISS) ;
   assign ic_hit_f2             =  ic_act_hit_f2 | ic_byp_hit_f2 | ic_iccm_hit_f2 | (ifc_region_acc_fault_f2 & ifc_fetch_req_f2 & ~((miss_state == CRIT_BYP_OK) | (miss_state == SCND_MISS)));

   assign uncacheable_miss_in   = sel_hold_imb ? uncacheable_miss_ff : ifc_fetch_uncacheable_f1 ;
   assign imb_in[31:1]          = sel_hold_imb ? imb_ff[31:1] : {fetch_addr_f1[31:1]} ;
   assign way_status_mb_in[2:0] = ( miss_pending) ? way_status_mb_ff[2:0] : {way_status[2:0]} ;
   assign tagv_mb_in[3:0]       = ( miss_pending) ? tagv_mb_ff[3:0]       : {ic_tag_valid[3:0]} ;

   assign reset_ic_in           = miss_pending  &  (reset_all_tags |  reset_ic_ff) ;

   rvdff #(1)  reset_ic_f (.*, .clk(free_clk), .din (reset_ic_in), .dout(reset_ic_ff));
   rvdff #(1)  uncache_ff (.*, .clk(active_clk), .din (ifc_fetch_uncacheable_f1), .dout(fetch_uncacheable_ff));



   rvdffe #(31) ifu_fetch_addr_f2_ff (.*,
                    .en (fetch_f1_f2_c1_clken),
                    .din ({fetch_addr_f1[31:1]}),
                    .dout({ifu_fetch_addr_int_f2[31:1]}));

   assign vaddr_f2[3:1] = ifu_fetch_addr_int_f2[3:1] ;


   rvdff_fpga #(1)  unc_miss_ff        (.*, .clk(fetch_f1_f2_c1_clk), .clken(fetch_f1_f2_c1_clken), .rawclk(clk), .din (uncacheable_miss_in),     .dout(uncacheable_miss_ff));
   rvdff_fpga #(3)  mb_rep_wayf2_ff    (.*, .clk(fetch_f1_f2_c1_clk), .clken(fetch_f1_f2_c1_clken), .rawclk(clk), .din ({way_status_mb_in[2:0]}), .dout({way_status_mb_ff[2:0]}));
   rvdff_fpga #(4)  mb_tagv_ff         (.*, .clk(fetch_f1_f2_c1_clk), .clken(fetch_f1_f2_c1_clken), .rawclk(clk), .din ({tagv_mb_in[3:0]}),       .dout({tagv_mb_ff[3:0]}));
   rvdff_fpga #(1) ifu_iccm_acc_ff     (.*, .clk(fetch_f1_f2_c1_clk), .clken(fetch_f1_f2_c1_clken), .rawclk(clk), .din(ifc_iccm_access_f1),       .dout(ifc_iccm_access_f2));
   rvdff_fpga #(1) ifu_iccm_reg_acc_ff (.*, .clk(fetch_f1_f2_c1_clk), .clken(fetch_f1_f2_c1_clken), .rawclk(clk), .din(ifc_region_acc_fault_final_f1), .dout(ifc_region_acc_fault_f2));

   rvdffe #(31) imb_f2_ff       (.*, .en(fetch_f1_f2_c1_clken), .din ({imb_in[31:1]}), .dout({imb_ff[31:1]}));

   assign ifc_fetch_req_qual_f1  = ifc_fetch_req_f1  & ~((miss_state == CRIT_WRD_RDY) & flush_final_f2) ;// & ~exu_flush_final ;
   rvdff #(1) fetch_req_f2_ff  (.*, .clk(active_clk),  .din(ifc_fetch_req_qual_f1), .dout(ifc_fetch_req_f2_raw));

   assign ifc_fetch_req_f2       = ifc_fetch_req_f2_raw & ~exu_flush_final ;


   assign ifu_ic_req_addr_f2[31:3] = {imb_ff[31:6] , ic_req_addr_bits_5_3[5:3] };
   assign ifu_ic_mb_empty          = ((miss_state == HIT_U_MISS) & ~(ifu_wr_en_new & last_beat)) |  ~miss_pending ;
   assign ifu_miss_state_idle      = (miss_state == IDLE) ;

//   four-way set associative - three bits
//   each bit represents one branch point in a binary decision tree; let 1
//   represent that the left side has been referenced more recently than the
//   right side, and 0 vice-versa
//
//              are all 4 ways valid?
//                   /       \
//                  |        no, use an invalid way.
//                  |
//                  |
//             bit_0 == 0?             state | replace      ref to | next state
//               /       \             ------+--------      -------+-----------
//              y         n             x00  |  way_0      way_0 |    _11
//             /           \            x10  |  way_1      way_1 |    _01
//      bit_1 == 0?    bit_2 == 0?      0x1  |  way_2      way_2 |    1_0
//        /    \          /    \        1x1  |  way_3      way_3 |    0_0
//       y      n        y      n
//      /        \      /        \        ('x' means don't care       ('_' means unchanged)
//    way_0    way_1  way_2     way_3      don't care)




   assign replace_way_mb_any[3] = ( way_status_mb_ff[2]  & way_status_mb_ff[0] & (&tagv_mb_ff[3:0])) |
                                  (~tagv_mb_ff[3]& tagv_mb_ff[2] &  tagv_mb_ff[1] &  tagv_mb_ff[0]) ;
   assign replace_way_mb_any[2] = (~way_status_mb_ff[2]  & way_status_mb_ff[0] & (&tagv_mb_ff[3:0])) |
                                  (~tagv_mb_ff[2]& tagv_mb_ff[1] &  tagv_mb_ff[0]) ;
   assign replace_way_mb_any[1] = ( way_status_mb_ff[1] & ~way_status_mb_ff[0] & (&tagv_mb_ff[3:0])) |
                                  (~tagv_mb_ff[1]& tagv_mb_ff[0] ) ;
   assign replace_way_mb_any[0] = (~way_status_mb_ff[1] & ~way_status_mb_ff[0] & (&tagv_mb_ff[3:0])) |
                                  (~tagv_mb_ff[0] ) ;

  assign way_status_hit_new[2:0] = ({3{ic_rd_hit[0]}} & {way_status[2] , 1'b1 , 1'b1}) |
                                   ({3{ic_rd_hit[1]}} & {way_status[2] , 1'b0 , 1'b1}) |
                                   ({3{ic_rd_hit[2]}} & {1'b1 ,way_status[1]  , 1'b0}) |
                                   ({3{ic_rd_hit[3]}} & {1'b0 ,way_status[1]  , 1'b0}) ;

  assign way_status_rep_new[2:0] = ({3{replace_way_mb_any[0]}} & {way_status_mb_ff[2] , 1'b1 , 1'b1}) |
                                   ({3{replace_way_mb_any[1]}} & {way_status_mb_ff[2] , 1'b0 , 1'b1}) |
                                   ({3{replace_way_mb_any[2]}} & {1'b1 ,way_status_mb_ff[1]  , 1'b0}) |
                                   ({3{replace_way_mb_any[3]}} & {1'b0 ,way_status_mb_ff[1]  , 1'b0}) ;

  // Make sure to select the way_status_hit_new even when in hit_under_miss.
  assign way_status_new[2:0]     = (ifu_wr_en_new_q  )  ? way_status_rep_new[2:0] :
                                                          way_status_hit_new[2:0] ;


  assign way_status_wr_en  = (ifu_wr_en_new_q  ) | ic_act_hit_f2;



   assign sel_fetch_u_miss  =  ((miss_state == HIT_U_MISS) & ifc_fetch_req_f1 ) ;
   rvdff #(1) sel_f_u_m_ff (.*, .clk(free_clk), .din (sel_fetch_u_miss), .dout(sel_fetch_u_miss_ff));


   assign sel_mb_addr  = ((miss_pending & ifu_wr_en_new ) | reset_tag_valid_for_miss) ;
   assign ifu_ic_rw_int_addr[31:1] = ({31{ sel_mb_addr}}  &  {imb_ff[31:6] , ic_wr_addr_bits_5_3[5:3] , imb_ff[2:1]})  |
                                     ({31{~sel_mb_addr}}  &  fetch_addr_f1[31:1] )   ;

   assign ifu_status_wr_addr[31:1] = ({31{ sel_mb_addr}}  &  {imb_ff[31:6] , ic_wr_addr_bits_5_3[5:3] , imb_ff[2:1]})  |
                                     ({31{~sel_mb_addr}}  &  ifu_fetch_addr_int_f2[31:1] )   ;

   rvdff #(1) sel_mb_addr_flop (.*, .clk(free_clk), .din({sel_mb_addr}), .dout({sel_mb_addr_ff}));

  assign ic_rw_addr[31:2]      = ifu_ic_rw_int_addr[31:2] ;


genvar i ;
for (i=0 ; i < 4 ; i++) begin : DATA_PGEN
 `ifdef RV_ICACHE_ECC
                rvecc_encode  ic_ecc_encode0 (
                           .din    ({16'b0, ifu_wr_data_new[((16*i)+15):(16*i)]}),
                           .ecc_out({ ic_wr_ecc0_unused[i],ic_wr_ecc[i*5+4:i*5]}));

  `else
       rveven_paritygen #(16) parlo  (.data_in   (ifu_wr_data_new[((16*i)+15):(16*i)]),
                                      .parity_out(ic_wr_parity[i]));

  `endif
end

  assign ifu_wr_data_comb_err       =  ifu_wr_data_error ;
  assign ifu_wr_cumulative_err      = (ifu_wr_data_comb_err | ifu_wr_data_comb_err_ff) & ~reset_beat_cnt;
  assign ifu_wr_cumulative_err_data =  ifu_wr_data_comb_err | ifu_wr_data_comb_err_ff ;

  rvdff #(1) cumul_err_ff (.*, .clk(free_clk),  .din (ifu_wr_cumulative_err), .dout(ifu_wr_data_comb_err_ff));

`ifdef RV_ICACHE_ECC
   assign ic_rd_data_only[127:0]   = {ic_rd_data [157:126], ic_rd_data [115:84] , ic_rd_data [73:42],ic_rd_data [31:0]} ;
   assign ic_error_f2.ecc[39:0]    = {ic_rd_data[167:158], ic_rd_data[125:116], ic_rd_data[83:74] ,ic_rd_data[41:32]};
   assign ic_wr_data[83:0] = {ic_wr_ecc[19:10],
                              ifu_wr_data_new[63:32],
                              ic_wr_ecc[9:0],
                              ifu_wr_data_new[31:0]} ;

`else
   assign ic_rd_data_only[127:0]  = {ic_rd_data [133:102], ic_rd_data [99:68] , ic_rd_data [65:34] ,ic_rd_data [31:0]} ;
   assign ic_error_f2.parity[7:0] = {ic_rd_data[135:134] , ic_rd_data[101:100], ic_rd_data [67:66] ,ic_rd_data [33:32]};
   assign ic_wr_data[67:0] = {ic_wr_parity[3:2],
                              ifu_wr_data_new[63:32],
                              ic_wr_parity[1:0],
                              ifu_wr_data_new[31:0]} ;


`endif


  assign sel_byp_data     =  ic_crit_wd_rdy  ;//& ~ifu_byp_data_err;
  assign sel_ic_data      = ~ic_crit_wd_rdy & ~fetch_req_iccm_f2 ;
`ifdef ICCM_AND_ICACHE
  assign sel_iccm_data    =  fetch_req_iccm_f2  ;

  assign ic_final_data  = ({128{sel_byp_data | sel_iccm_data | sel_ic_data}} & {ic_rd_data_only[127:0]} ) ;

  assign ic_premux_data = ({128{sel_byp_data }} & {ic_byp_data_only[127:0]} ) |
                          ({128{sel_iccm_data}} & {iccm_rd_data[148:117],iccm_rd_data[109:78] , iccm_rd_data[70:39],iccm_rd_data[31:0]});

  assign ic_sel_premux_data = sel_iccm_data | sel_byp_data ;

`endif

`ifdef ICCM_AND_NOT_ICACHE
  assign sel_iccm_data    =  fetch_req_iccm_f2  ;
  assign ic_final_data  = ({128{sel_byp_data }} & {ic_byp_data_only[127:0]} ) |
                          ({128{sel_iccm_data}} & {iccm_rd_data[148:117],iccm_rd_data[109:78] , iccm_rd_data[70:39],iccm_rd_data[31:0]});
  assign ic_premux_data = '0 ;
  assign ic_sel_premux_data = '0 ;
`endif

`ifdef NOT_ICCM_AND_ICACHE

    assign ic_final_data  = ({128{sel_byp_data | sel_ic_data}} & {ic_rd_data_only[127:0]} ) ;

  assign ic_premux_data = ({128{sel_byp_data }} & {ic_byp_data_only[127:0]} ) ;
  assign ic_sel_premux_data =  sel_byp_data ;
`endif

`ifdef NOT_ICCM_AND_NOT_ICACHE
  assign ic_final_data  = ({128{sel_byp_data }} & {ic_byp_data_only[127:0]} ) ;
  assign ic_premux_data = 0 ;
  assign ic_sel_premux_data = '0 ;
`endif

 assign ifu_icache_fetch_f2   =  sel_ic_data ;

  assign ifc_bus_acc_fault_f2[7:0]   =  {8{ic_byp_hit_f2}} & ifu_byp_data_err[7:0] ;
  assign ic_data_f2[127:0]      =  ic_final_data[127:0];


rvdff #(1) flush_final_ff (.*, .clk(free_clk), .din({exu_flush_final}), .dout({flush_final_f2}));
assign fetch_req_f2_qual       = ic_hit_f2 & ~exu_flush_final;
assign ic_access_fault_f2[7:0]  = ({8{ifc_region_acc_fault_f2}} | ifc_bus_acc_fault_f2[7:0])  & {8{~exu_flush_final}};

  // right justified
assign ic_fetch_val_f2[7] = fetch_req_f2_qual & ifu_bp_inst_mask_f2[7] & ((!vaddr_f2[3]&!vaddr_f2[2]&!vaddr_f2[1]));
assign ic_fetch_val_f2[6] = fetch_req_f2_qual & ifu_bp_inst_mask_f2[6] & ((!vaddr_f2[3]&!vaddr_f2[2]));
assign ic_fetch_val_f2[5] = fetch_req_f2_qual & ifu_bp_inst_mask_f2[5] & ((!vaddr_f2[3]&!vaddr_f2[1]) | (!vaddr_f2[3]&!vaddr_f2[2]));
assign ic_fetch_val_f2[4] = fetch_req_f2_qual & ifu_bp_inst_mask_f2[4] & ((!vaddr_f2[3]));
assign ic_fetch_val_f2[3] = fetch_req_f2_qual & ifu_bp_inst_mask_f2[3] & ((!vaddr_f2[2]&!vaddr_f2[1]) | (!vaddr_f2[3]));
assign ic_fetch_val_f2[2] = fetch_req_f2_qual & ifu_bp_inst_mask_f2[2] & ((!vaddr_f2[2]) | (!vaddr_f2[3]));
assign ic_fetch_val_f2[1] = fetch_req_f2_qual & ifu_bp_inst_mask_f2[1] & ((!vaddr_f2[1]) | (!vaddr_f2[2]) | (!vaddr_f2[3])) ;
assign ic_fetch_val_f2[0] = fetch_req_f2_qual ;

   assign fetch_mask[7:0] = {vaddr_f2[3:1]==3'b111,vaddr_f2[3:1]==3'b110,vaddr_f2[3:1]==3'b101,vaddr_f2[3:1]==3'b100,vaddr_f2[3:1]==3'b011,vaddr_f2[3:1]==3'b010,vaddr_f2[3:1]==3'b001,vaddr_f2[3:1]==3'b000};

   assign ic_fetch_mem_val[7:0] = { 1'b1, |fetch_mask[6:0], |fetch_mask[5:0], |fetch_mask[4:0], |fetch_mask[3:0], |fetch_mask[2:0], |fetch_mask[1:0], fetch_mask[0] };

   assign bp_mask[7:0] = {ifu_bp_inst_mask_f2[7:1], 1'b1};

   assign ic_bp_mem_mask[7:0] = ({8{fetch_mask[0]}} &  bp_mask[7:0]) |            // unrotate the bpmask
                                ({8{fetch_mask[1]}} & {bp_mask[6:0],1'b0}) |
                                ({8{fetch_mask[2]}} & {bp_mask[5:0],2'b0}) |
                                ({8{fetch_mask[3]}} & {bp_mask[4:0],3'b0}) |
                                ({8{fetch_mask[4]}} & {bp_mask[3:0],4'b0}) |
                                ({8{fetch_mask[5]}} & {bp_mask[2:0],5'b0}) |
                                ({8{fetch_mask[6]}} & {bp_mask[1:0],6'b0}) |
                                ({8{fetch_mask[7]}} & {bp_mask[0]  ,7'b0});

   assign ic_fetch_val_mem_f2[7:0] = {8{fetch_req_f2_qual}} & ic_bp_mem_mask[7:0] & ic_fetch_mem_val[7:0];



/////////////////////////////////////////////////////////////////////////////////////
//   New logic for bypass
/////////////////////////////////////////////////////////////////////////////////////

  logic                   write_byp_first_data ;
  logic                   write_byp_second_data ;

  logic [63:0]            ifu_byp_data_first_half;
  logic [63:0]            ifu_byp_data_second_half;
  logic                   ifu_byp_data_error_first_half_in;
  logic                   ifu_byp_data_error_first_half;
  logic                   ifu_byp_data_error_second_half_in;
  logic                   ifu_byp_data_error_second_half;
  logic                   ifu_byp_data_first_half_valid_in ;
  logic                   ifu_byp_data_first_half_valid    ;
  logic                   ifu_byp_data_second_half_valid_in ;
  logic                   ifu_byp_data_second_half_valid    ;
  logic                   ic_crit_wd_complete    ;

  logic [IFU_BUS_TAG-1:0] byp_tag_ff;
  logic                   byp_data_first_c1_clken ;
  logic                   byp_data_first_c1_clk;
  logic                   byp_data_second_c1_clken ;
  logic                   byp_data_second_c1_clk;

  assign   byp_data_first_c1_clken  = write_byp_first_data;
  assign   byp_data_second_c1_clken = write_byp_second_data;

  assign byp_tag_ff[IFU_BUS_TAG-1:0]  =  IFU_BUS_TAG'({imb_ff[5:4] , 1'b0});
  assign write_byp_first_data         =   axi_ifu_wr_en_new & ({byp_tag_ff[IFU_BUS_TAG-1:1],1'b0}  == ifu_axi_rid_ff[IFU_BUS_TAG-1:0]);
  assign write_byp_second_data        =   axi_ifu_wr_en_new & ({byp_tag_ff[IFU_BUS_TAG-1:1],1'b1}  == ifu_axi_rid_ff[IFU_BUS_TAG-1:0]);

 // First Half flops
  rvdffe #(64) byp_data_first_half (.*,
            .en(byp_data_first_c1_clken),
            .din (ifu_wr_data_new[63:0]),
            .dout(ifu_byp_data_first_half[63:0]));

  assign ifu_byp_data_error_first_half_in = write_byp_first_data ? ifu_wr_data_error : (ifu_byp_data_error_first_half  & ~ic_act_miss_f2) ;

  rvdff #(1) byp_data_first_half_err (.*,
            .clk(free_clk),
            .din (ifu_byp_data_error_first_half_in),
            .dout(ifu_byp_data_error_first_half));

  assign ifu_byp_data_first_half_valid_in = write_byp_first_data ? 1'b1  : (ifu_byp_data_first_half_valid  & ~ic_act_miss_f2) ;
  rvdff #(1) byp_data_first_half_val (.*,
            .clk(free_clk),
            .din (ifu_byp_data_first_half_valid_in),
            .dout(ifu_byp_data_first_half_valid));


 // Second Half flops
  rvdffe #(64) byp_data_second_half (.*,
            .en(byp_data_second_c1_clken),
            .din (ifu_wr_data_new[63:0]),
            .dout(ifu_byp_data_second_half[63:0]));

  assign ifu_byp_data_error_second_half_in = write_byp_second_data ? ifu_wr_data_error : (ifu_byp_data_error_second_half  & ~ic_act_miss_f2) ;
  rvdff #(1) byp_data_second_half_err (.*,
                   .clk(free_clk),
                   .din (ifu_byp_data_error_second_half_in),
                   .dout(ifu_byp_data_error_second_half));

  assign ifu_byp_data_second_half_valid_in = write_byp_second_data ? 1'b1  : (ifu_byp_data_second_half_valid  & ~ic_act_miss_f2) ;
  rvdff #(1) byp_data_second_half_val (.*,
                   .clk(free_clk),
                    .din (ifu_byp_data_second_half_valid_in),
                    .dout(ifu_byp_data_second_half_valid));

  assign ic_byp_data_only[127:0] = { ifu_byp_data_second_half[63:0] , ifu_byp_data_first_half[63:0] } ;

  assign ifu_byp_data_err[7:0]  =  {{4{ ifu_byp_data_error_second_half}} , {4{ifu_byp_data_error_first_half}}} ;

// Critical word ready.
   assign    ic_crit_wd_complete = (write_byp_first_data  & ifu_byp_data_second_half_valid) |
                                   (write_byp_second_data & ifu_byp_data_first_half_valid)  ;

   assign    ic_crit_wd_rdy_in = (ic_crit_wd_complete & crit_wd_byp_ok_ff & ~exu_flush_final ) |
                                 (ic_crit_wd_rdy_ff & ~fetch_req_icache_f2 & crit_wd_byp_ok_ff & ~exu_flush_final) ;

   rvdff #(1)           crit_wd_ff      (.*, .clk(free_clk),  .din(ic_crit_wd_rdy_in),   .dout(ic_crit_wd_rdy_ff));
/////////////////////////////////////////////////////////////////////////////////////
// Parity checking logic for Icache logic.                                         //
/////////////////////////////////////////////////////////////////////////////////////


assign ic_rd_parity_final_err = ic_tag_perr & ifu_icache_fetch_f2  ;

logic [16:6]                                  ifu_ic_rw_int_addr_f2_Q ;
logic [3:0]                                   perr_err_inv_way;
logic [16:6]                                  perr_ic_index_ff;
logic                                         perr_sel_invalidate;
logic                                         perr_sb_write_status   ;
logic                                         ifu_icache_sb_error_val_ff   ;

         rvdff #(11) ic_index_q (.*,
                   .clk(active_clk),
                   .din(ifu_icache_error_index[16:6]),
                   .dout(ifu_ic_rw_int_addr_f2_Q[16:6]));




   rvdff  #((1))  perr_err_ff    (.clk(active_clk), .din(ifu_icache_error_val),   .dout(ic_rd_parity_final_err_ff),   .*);
   rvdff  #((1))  sbiccm_err_ff  (.clk(active_clk), .din(ifu_icache_sb_error_val),       .dout(ifu_icache_sb_error_val_ff),   .*);
   rvdffs #((11)) perr_dat_ff    (.clk(active_clk), .din(ifu_ic_rw_int_addr_f2_Q[16:6]), .dout(perr_ic_index_ff), .en(perr_sb_write_status),  .*);

   assign perr_err_inv_way[3:0]   =  {4{perr_sel_invalidate}} ;

   //////////////////////////////////// Create Parity Error State Machine ///////////////////////
   //                                   Create Parity Error State Machine                      //
   //                                   Create Parity Error State Machine                      //
   //                                   Create Parity Error State Machine                      //
   //////////////////////////////////// Create Parity Error State Machine ///////////////////////

   assign iccm_correct_ecc = (perr_state == ECC_CORR);

   // FIFO state machine
   always_comb begin  : ERROR_SM
      perr_nxtstate            = ERR_IDLE;
      perr_state_en            = 1'b0;
      perr_sb_write_status     = 1'b0;
      perr_sel_invalidate      = 1'b0;
      //iccm_correct_ecc         = 1'b0;

      case (perr_state)
         ERR_IDLE: begin : err_idle
                  perr_nxtstate         =  iccm_dma_sb_error ? DMA_SB_ERR : (ic_rd_parity_final_err_ff & ~exu_flush_final) ? PERR_WFF : ECC_WFF;
                  perr_state_en         =  ((ic_rd_parity_final_err_ff | ifu_icache_sb_error_val_ff) & ~exu_flush_final) | iccm_dma_sb_error;
                  perr_sb_write_status  =  perr_state_en;
         end
         PERR_WFF: begin : perr_wff
                  perr_nxtstate       =  ERR_IDLE ;
                  perr_state_en       =   exu_flush_final  ;
                  perr_sel_invalidate =  (dec_tlu_flush_err_wb &  exu_flush_final);
         end
         ECC_WFF: begin : ecc_wff
                  perr_nxtstate       =  (~dec_tlu_flush_err_wb &  exu_flush_final ) ? ERR_IDLE : ECC_CORR ;
                  perr_state_en       =   exu_flush_final   ;
         end
         DMA_SB_ERR : begin : dma_sb_ecc
                 perr_nxtstate       = ECC_CORR;
                 perr_state_en       = 1'b1;
         end
         ECC_CORR: begin : ecc_corr
                  perr_nxtstate       =  ERR_IDLE  ;
                  perr_state_en       =   1'b1   ;
         end
         default: begin : def_case
                  perr_nxtstate            = ERR_IDLE;
                  perr_state_en            = 1'b0;
                  perr_sb_write_status     = 1'b0;
                  perr_sel_invalidate      = 1'b0;
                 // iccm_correct_ecc         = 1'b0;
         end
      endcase
   end
   rvdffs #(($bits(perr_state_t))) perr_state_ff (.clk(free_clk), .din(perr_nxtstate), .dout({perr_state}), .en(perr_state_en),   .*);

`ifdef RV_ICCM_ENABLE
/////////////////////////////////////////////////////////////////////////////////////
// ECC checking logic for ICCM data.                                               //
/////////////////////////////////////////////////////////////////////////////////////

logic [3:0] [31:0] iccm_corrected_data;
logic [3:0] [06:0] iccm_corrected_ecc;
logic [3:0]        iccm_double_ecc_error;
logic [3:0]        iccm_ecc_word_enable;


logic [ICCM_BITS-1:4]       iccm_rw_addr_f2;

logic [31:0]       iccm_corrected_data_f2_mux;
logic [06:0]       iccm_corrected_ecc_f2_mux;
logic [3:0]        iccm_rd_err_f2_mux;
logic              iccm_dma_rvalid_in;

for (i=0; i < 4 ; i++) begin : ICCM_ECC_CHECK
assign iccm_ecc_word_enable[i] = ((|ic_fetch_val_mem_f2[(2*i+1):(2*i)] & ~exu_flush_final & sel_iccm_data) | iccm_dma_rvalid_in) & ~dec_tlu_core_ecc_disable;
rvecc_decode  ecc_decode (
                           .en(iccm_ecc_word_enable[i]),
                           .sed_ded ( 1'b0 ),    // 1 : means only detection
                           .din(iccm_rd_data[(39*i+31):(39*i)]),
                           .ecc_in(iccm_rd_data[(39*i+38):(39*i+32)]),
                           .dout(iccm_corrected_data[i][31:0]),
                           .ecc_out(iccm_corrected_ecc[i][6:0]),
                           .single_ecc_error(iccm_single_ecc_error[i]),
                           .double_ecc_error(iccm_double_ecc_error[i]));
end

assign iccm_rd_ecc_single_err  = (|iccm_single_ecc_error ) & ifc_iccm_access_f2;
assign iccm_rd_ecc_double_err[7:0]  = ({{2{iccm_double_ecc_error[3]}}, {2{iccm_double_ecc_error[2]}} , {2{iccm_double_ecc_error[1]}} , {2{iccm_double_ecc_error[0]}}} ) & {8{ifc_iccm_access_f2}};

assign iccm_corrected_data_f2_mux[31:0] = iccm_single_ecc_error[0] ? iccm_corrected_data[0] :
                                          iccm_single_ecc_error[1] ? iccm_corrected_data[1] :
                                          iccm_single_ecc_error[2] ? iccm_corrected_data[2] :
                                                                     iccm_corrected_data[3] ;

assign iccm_corrected_ecc_f2_mux[06:0]  = iccm_single_ecc_error[0] ? iccm_corrected_ecc[0] :
                                          iccm_single_ecc_error[1] ? iccm_corrected_ecc[1] :
                                          iccm_single_ecc_error[2] ? iccm_corrected_ecc[2] :
                                                                     iccm_corrected_ecc[3] ;


  rvdff #(ICCM_BITS-4) iccm_index_f2 (.*, .clk(free_clk),   .din(iccm_rw_addr[ICCM_BITS-1:4]), .dout(iccm_rw_addr_f2[ICCM_BITS-1:4]));

  assign iccm_rd_err_f2_mux[1:0] =  iccm_single_ecc_error[0] ? 2'b00:
                                     iccm_single_ecc_error[1] ? 2'b01:
                                     iccm_single_ecc_error[2] ? 2'b10: 2'b11 ;


   logic  iccm_rd_ecc_single_err_hold_in ;

   assign iccm_ecc_write_status          =  ((iccm_rd_ecc_single_err & ~iccm_rd_ecc_single_err_ff)  & ~exu_flush_final) | iccm_dma_sb_error;
   assign iccm_rd_ecc_single_err_hold_in =  (iccm_rd_ecc_single_err | iccm_rd_ecc_single_err_ff) & ~exu_flush_final;

   rvdff  #((1))          ecc_rr_ff    (.clk(free_clk), .din(iccm_rd_ecc_single_err_hold_in),   .dout(iccm_rd_ecc_single_err_ff),            .*);
   rvdffs #((32))         ecc_dat0_ff  (.clk(free_clk), .din(iccm_corrected_data_f2_mux[31:0]), .dout(iccm_ecc_corr_data_ff[31:0]),          .en(iccm_ecc_write_status),  .*);
   rvdffs #((7))          ecc_dat1_ff  (.clk(free_clk), .din(iccm_corrected_ecc_f2_mux[6:0]),   .dout(iccm_ecc_corr_data_ff[38:32]),         .en(iccm_ecc_write_status),  .*);
   rvdffs #((ICCM_BITS-4))ecc_ind0_ff  (.clk(free_clk), .din(iccm_rw_addr_f2[ICCM_BITS-1:4]),   .dout(iccm_ecc_corr_index_ff[ICCM_BITS-1:4]),.en(iccm_ecc_write_status),  .*);
   rvdffs #((2))          ecc_ind1_ff  (.clk(free_clk), .din(iccm_rd_err_f2_mux[1:0]),          .dout(iccm_ecc_corr_index_ff[3:2]),          .en(iccm_ecc_write_status),  .*);

`else
assign iccm_rd_ecc_single_err     = 1'b0 ;
assign iccm_rd_ecc_double_err     = '0 ;
assign iccm_rd_ecc_single_err_ff  = 1'b0 ;

assign iccm_ecc_corr_index_ff[ICCM_BITS-1:2]  =  '0;
assign iccm_ecc_corr_data_ff[38:0]            =  '0;
assign iccm_ecc_write_status                  =  '0;
assign iccm_single_ecc_error                  =  '0;


`endif

   logic        axiclk;
   logic        axiclk_reset;
   logic        axi_ifu_bus_clk_en_ff;
   logic        axi_ifu_bus_clk_en ;

   logic        ifc_axi_ic_req_ff_in;
   logic        ifc_axi_ic_req_ff2 ;

   logic        axi_inc_data_beat_cnt     ;
   logic        axi_reset_data_beat_cnt   ;
   logic        axi_hold_data_beat_cnt    ;

   logic        axi_inc_cmd_beat_cnt     ;
   logic        axi_reset_cmd_beat_cnt_0   ;
   logic        axi_reset_cmd_beat_cnt_6   ;
   logic        axi_hold_cmd_beat_cnt    ;

   logic [2:0]  axi_new_data_beat_count  ;
   logic [2:0]  axi_data_beat_count      ;

   logic [2:0]  axi_new_cmd_beat_count  ;
   logic [2:0]  axi_cmd_beat_count      ;

   logic        axi_inc_rd_addr_cnt  ;
   logic        axi_set_rd_addr_cnt  ;
   logic        axi_reset_rd_addr_cnt;
   logic        axi_hold_rd_addr_cnt ;

   logic [2:0]  axi_new_rd_addr_count;
   logic [2:0]  axi_rd_addr_count;


   logic        axi_cmd_sent           ;
   logic        axi_last_data_beat     ;
   logic        axi_wrap_addr          ;


   logic        ifu_axi_rvalid_ff        ;
   logic        ifu_axi_rvalid_unq_ff    ;
   logic        ifu_axi_arready_unq_ff    ;
   logic        ifu_axi_arvalid_ff        ;
   logic        ifu_axi_arready_ff        ;
   logic [63:0] ifu_axi_rdata_ff        ;
   logic [1:0]  ifu_axi_rresp_ff          ;

   logic        axi_w0_wren            ;
   logic        axi_w1_wren            ;
   logic        axi_w2_wren            ;
   logic        axi_w3_wren            ;

   logic        axi_w0_wren_last       ;
   logic        axi_w1_wren_last       ;
   logic        axi_w2_wren_last       ;
   logic        axi_w3_wren_last       ;

   logic        w0_wren_reset_miss      ;
   logic        w1_wren_reset_miss      ;
   logic        w2_wren_reset_miss      ;
   logic        w3_wren_reset_miss      ;

   logic        ifc_dma_access_ok_d;
   logic        ifc_dma_access_ok_prev;

assign axi_ifu_bus_clk_en =  ifu_bus_clk_en ;



   rvdff #(1)           axi_clken_ff  (.*, .clk(free_clk), .din(axi_ifu_bus_clk_en), .dout(axi_ifu_bus_clk_en_ff));

   logic   axi_cmd_req_in ;
   logic   axi_cmd_req_hold ;


   assign  ifc_axi_ic_req_ff_in  = (ic_act_miss_f2 | axi_cmd_req_hold | ifc_axi_ic_req_ff2) & ~((axi_cmd_beat_count==3'b111) & ifu_axi_arvalid & ifu_axi_arready & miss_pending);

   assign    axi_cmd_req_in  = (ic_act_miss_f2 | axi_cmd_req_hold) & ~axi_cmd_sent  ; // hold until first command sent
   // changes for making the axi blocking
   rvdff #(1)  axi_cmd_req_ff  (.*,  .clk(free_clk), .din(axi_cmd_req_in), .dout(axi_cmd_req_hold));

`ifndef RV_FPGA_OPTIMIZE
   rvclkhdr fetch_f1_f2_c1_cgc   ( .en(fetch_f1_f2_c1_clken),     .l1clk(fetch_f1_f2_c1_clk), .* );  // ifndef FPGA_OPTIMIZE
   rvclkhdr axi_clk(.en(axi_ifu_bus_clk_en),.l1clk(axiclk), .*);                                     // ifndef FPGA_OPTIMIZE
   rvclkhdr axi_clk_reset(.en(axi_ifu_bus_clk_en | ic_act_miss_f2),   .l1clk(axiclk_reset), .*);     // ifndef FPGA_OPTIMIZE
`endif


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  logic   axi_cmd_rsp_pend;
// `ifdef RV_BUILD_SVC
//     rvdffsc  axi_cmd_rsp_pend_ff  ( .din(ifu_axi_arready), .dout(axi_cmd_rsp_pend), .en(ifu_axi_arvalid), .clear(ifu_axi_rvalid & ifu_axi_rready), .clk(axiclk), .*);
// `elsif RV_BUILD_AXI4
//     rvdffsc  axi_cmd_rsp_pend_ff  ( .din(ifu_axi_arready), .dout(axi_cmd_rsp_pend), .en(ifu_axi_arvalid), .clear(ifu_axi_rvalid & ifu_axi_rready), .clk(axiclk), .*);
// `else
//     assign    axi_cmd_rsp_pend      = 1'b0;
// `endif
//   assign    ifu_axi_arvalid                 = ifc_axi_ic_req_ff2 & ~axi_cmd_rsp_pend;
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   assign    ifu_axi_arvalid                 = ifc_axi_ic_req_ff2 ;
   assign    ifu_axi_arid[IFU_BUS_TAG-1:0]   = IFU_BUS_TAG'(axi_rd_addr_count[2:0]);
   assign    ifu_axi_araddr[31:0]            = {ifu_ic_req_addr_f2[31:3],3'b0} ;
   assign    ifu_axi_rready                  = 1'b1;
   assign    ifu_axi_arsize[2:0]             = 3'b011;
   assign    ifu_axi_arcache[3:0]            = 4'b1111;
   assign    ifu_axi_arprot[2:0]             = 3'b100;
   assign    ifu_axi_arregion[3:0]           = ifu_axi_araddr[31:28];
   assign    ifu_axi_arlen[7:0]              = '0;
   assign    ifu_axi_arburst[1:0]            = 2'b01;
   assign    ifu_axi_arqos[3:0]              = '0;
   assign    ifu_axi_arlock                  = '0;

   // IFU Write channels - not needed, so 00 out
   rvdff_fpga #(1)            axi_ic_req_ff2   (.*, .clk(axiclk), .clken(axi_ifu_bus_clk_en), .rawclk(clk), .din(ifc_axi_ic_req_ff_in),          .dout(ifc_axi_ic_req_ff2));
   rvdff_fpga #(1)            axi_rdy_ff       (.*, .clk(axiclk), .clken(axi_ifu_bus_clk_en), .rawclk(clk), .din(ifu_axi_arready),               .dout(ifu_axi_arready_unq_ff));
   rvdff_fpga #(1)            axi_rsp_vld_ff   (.*, .clk(axiclk), .clken(axi_ifu_bus_clk_en), .rawclk(clk), .din(ifu_axi_rvalid),                .dout(ifu_axi_rvalid_unq_ff));
   rvdff_fpga #(1)            axi_cmd_ff       (.*, .clk(axiclk), .clken(axi_ifu_bus_clk_en), .rawclk(clk), .din(ifu_axi_arvalid),               .dout(ifu_axi_arvalid_ff));
   rvdff_fpga #(2)            scvi_rsp_cmd_ff  (.*, .clk(axiclk), .clken(axi_ifu_bus_clk_en), .rawclk(clk), .din(ifu_axi_rresp[1:0]),            .dout(ifu_axi_rresp_ff[1:0]));
   rvdff_fpga #(IFU_BUS_TAG)  scvi_rsp_tag_ff  (.*, .clk(axiclk), .clken(axi_ifu_bus_clk_en), .rawclk(clk), .din(ifu_axi_rid[IFU_BUS_TAG-1:0]),  .dout(ifu_axi_rid_ff[IFU_BUS_TAG-1:0]));
   rvdff_fpga #(64)           axi_data_ff      (.*, .clk(axiclk), .clken(axi_ifu_bus_clk_en), .rawclk(clk), .din(ifu_axi_rdata[63:0]),           .dout(ifu_axi_rdata_ff[63:0]));



   assign    ifu_axi_arready_ff   =  ifu_axi_arready_unq_ff & axi_ifu_bus_clk_en_ff ;
   assign    ifu_axi_rvalid_ff   =  ifu_axi_rvalid_unq_ff & axi_ifu_bus_clk_en_ff ;
   assign    axi_cmd_sent        =  ifu_axi_arvalid & ifu_axi_arready & miss_pending & axi_ifu_bus_clk_en;
   assign axi_inc_data_beat_cnt         = (axi_ifu_wr_en_new & ~axi_last_data_beat) ;
   assign axi_reset_data_beat_cnt       =  ic_act_miss_f2 | (axi_ifu_wr_en_new &  axi_last_data_beat) ;
   assign axi_hold_data_beat_cnt        = ~axi_inc_data_beat_cnt & ~axi_reset_data_beat_cnt ;

   assign axi_new_data_beat_count[2:0] = ({3{axi_reset_data_beat_cnt}} & 3'b000 ) |
                                     ({3{axi_inc_data_beat_cnt}}   & (axi_data_beat_count[2:0] + 3'b001)) |
                                     ({3{axi_hold_data_beat_cnt}}  &  axi_data_beat_count[2:0]) ;

   rvdff #(3)  axi_mb_beat_count_ff (.*, .clk(free_clk), .din ({axi_new_data_beat_count[2:0]}), .dout({axi_data_beat_count[2:0]}));

// Request Address Count
   assign axi_inc_rd_addr_cnt     = axi_cmd_sent;
   assign axi_set_rd_addr_cnt     = ic_act_miss_f2  ;
   assign axi_hold_rd_addr_cnt    = ~axi_inc_rd_addr_cnt & ~axi_set_rd_addr_cnt;

   assign axi_new_rd_addr_count[2:0] = ~miss_pending ? {imb_ff[5:4],1'b0} :  axi_inc_rd_addr_cnt ? (axi_rd_addr_count[2:0] + 3'b001) : axi_rd_addr_count[2:0];


   rvdff_fpga  #(3)  axi_cmd_beat_ff (.*,           .clk(axiclk_reset), .clken(axi_ifu_bus_clk_en | ic_act_miss_f2), .rawclk(clk), .din ({axi_new_cmd_beat_count[2:0]}), .dout({axi_cmd_beat_count[2:0]}));
   rvdffs_fpga #(3)  axi_rd_addr_ff (.*, .en(1'b1), .clk(axiclk_reset), .clken(axi_ifu_bus_clk_en | ic_act_miss_f2), .rawclk(clk), .din ({axi_new_rd_addr_count[2:0]}), .dout({axi_rd_addr_count[2:0]}));

// command beat Count
   assign axi_inc_cmd_beat_cnt     =  ifu_axi_arvalid         &  ifu_axi_arready & miss_pending;
   assign axi_reset_cmd_beat_cnt_0 =  ic_act_miss_f2        & ~uncacheable_miss_in ;
   assign axi_reset_cmd_beat_cnt_6 =  ic_act_miss_f2        &  uncacheable_miss_in ;
   assign axi_hold_cmd_beat_cnt    = ~axi_inc_cmd_beat_cnt & ~ic_act_miss_f2 ;

   assign axi_new_cmd_beat_count[2:0] =  ({3{axi_reset_cmd_beat_cnt_0}} & 3'b000 ) |
                                          ({3{axi_reset_cmd_beat_cnt_6}} & 3'b110 ) |
                                          ({3{axi_inc_cmd_beat_cnt}}   & (axi_cmd_beat_count[2:0] + 3'b001)) |
                                          ({3{axi_hold_cmd_beat_cnt}}  &  axi_cmd_beat_count[2:0]) ;


   assign    req_addr_count[2:0]    = axi_rd_addr_count[2:0] ;



    assign axi_last_data_beat     =  uncacheable_miss_ff ? (axi_data_beat_count[2:0] == 3'b001) : (axi_data_beat_count[2:0] == 3'b111);
    assign axi_wrap_addr          =  (axi_rd_addr_count[2:0] == 3'b111);

   assign  axi_ifu_wr_en_new         =  ifu_axi_rvalid_ff  & miss_pending ;
   assign  axi_ifu_wr_en_new_q       =  ifu_axi_rvalid_ff  & miss_pending & ~uncacheable_miss_ff & ~(|ifu_axi_rresp_ff[1:0]); // qualify with no-error conditions ;
   assign  axi_ifu_wr_en_new_wo_err  =  ifu_axi_rvalid_ff & miss_pending &  ~uncacheable_miss_ff;
   assign  axi_ifu_wr_data_new[63:0] =  ifu_axi_rdata_ff[63:0] ;

   assign axi_w0_wren = axi_ifu_wr_en_new_q & (replace_way_mb_any[3:0] == 4'b0001) & miss_pending ;
   assign axi_w1_wren = axi_ifu_wr_en_new_q & (replace_way_mb_any[3:0] == 4'b0010) & miss_pending ;
   assign axi_w2_wren = axi_ifu_wr_en_new_q & (replace_way_mb_any[3:0] == 4'b0100) & miss_pending ;
   assign axi_w3_wren = axi_ifu_wr_en_new_q & (replace_way_mb_any[3:0] == 4'b1000) & miss_pending ;

   assign axi_ic_wr_en[3:0] = {axi_w3_wren , axi_w2_wren , axi_w1_wren , axi_w0_wren} ;

   assign axi_w0_wren_last = axi_ifu_wr_en_new_wo_err & (replace_way_mb_any[3:0] == 4'b0001) & miss_pending & axi_last_data_beat;
   assign axi_w1_wren_last = axi_ifu_wr_en_new_wo_err & (replace_way_mb_any[3:0] == 4'b0010) & miss_pending & axi_last_data_beat;
   assign axi_w2_wren_last = axi_ifu_wr_en_new_wo_err & (replace_way_mb_any[3:0] == 4'b0100) & miss_pending & axi_last_data_beat;
   assign axi_w3_wren_last = axi_ifu_wr_en_new_wo_err & (replace_way_mb_any[3:0] == 4'b1000) & miss_pending & axi_last_data_beat;

   rvdff #(1)  act_miss_ff (.*, .clk(free_clk), .din (ic_act_miss_f2), .dout(ic_act_miss_f2_delayed));
   assign reset_tag_valid_for_miss = ic_act_miss_f2_delayed & (miss_state == CRIT_BYP_OK) ;

   assign w0_wren_reset_miss    = (replace_way_mb_any[3:0] == 4'b0001) & reset_tag_valid_for_miss ;
   assign w1_wren_reset_miss    = (replace_way_mb_any[3:0] == 4'b0010) & reset_tag_valid_for_miss ;
   assign w2_wren_reset_miss    = (replace_way_mb_any[3:0] == 4'b0100) & reset_tag_valid_for_miss ;
   assign w3_wren_reset_miss    = (replace_way_mb_any[3:0] == 4'b1000) & reset_tag_valid_for_miss ;

   assign    axi_ifu_wr_data_error = |ifu_axi_rresp_ff[1:0] &  ifu_axi_rvalid_ff  & miss_pending;

   rvdff #(1)           dma_ok_prev_ff  (.*, .clk(free_clk),  .din(ifc_dma_access_ok_d), .dout(ifc_dma_access_ok_prev));

   assign ic_crit_wd_rdy   = ic_crit_wd_rdy_ff ;
   assign last_beat        =  axi_last_data_beat ;
   assign ifu_wr_data_error = axi_ifu_wr_data_error ;
   assign reset_beat_cnt    = axi_reset_data_beat_cnt ;

// DMA
   // Making sure that the dma_access is allowed when we have 2 back to back dma_access_ok. Also gating with current state == idle
   assign ifc_dma_access_ok_d  = ifc_dma_access_ok &  ~iccm_correct_ecc;
   assign ifc_dma_access_q_ok  = ifc_dma_access_ok &  ~iccm_correct_ecc & ifc_dma_access_ok_prev &  (perr_state == ERR_IDLE) ;
   assign iccm_ready           = ifc_dma_access_q_ok ;

    `ifdef RV_ICCM_ENABLE
         logic  dma_select_upper  ;
         logic  iccm_dma_rden    ;

//         logic  ic_dma_active_in;
         logic  iccm_dma_ecc_error_in;
         logic  [13:0] dma_mem_ecc;
         logic  [63:0] iccm_dma_rdata_in;

//         assign ic_dma_active_in   =  ifc_dma_access_q_ok & dma_iccm_req ;
         assign iccm_wren          =  (ifc_dma_access_q_ok & dma_iccm_req &  dma_mem_write) | iccm_correct_ecc;
         assign iccm_rden          =  (ifc_dma_access_q_ok & dma_iccm_req & ~dma_mem_write) | (ifc_iccm_access_f1 & ifc_fetch_req_f1);
         assign iccm_dma_rden      =  (ifc_dma_access_q_ok & dma_iccm_req & ~dma_mem_write)                     ;
         assign iccm_wr_size[2:0]  =   {3{dma_iccm_req  & dma_mem_write}} &  dma_mem_sz[2:0] ;

         rvecc_encode  iccm_ecc_encode0 (
                           .din(dma_mem_wdata[31:0]),
                           .ecc_out(dma_mem_ecc[6:0]));

         rvecc_encode  iccm_ecc_encode1 (
                           .din(dma_mem_wdata[63:32]),
                           .ecc_out(dma_mem_ecc[13:7]));

         assign iccm_wr_data[38:0]  =  (iccm_correct_ecc & ~(ifc_dma_access_q_ok & dma_iccm_req)) ?  iccm_ecc_corr_data_ff[38:0] :
                                       {dma_mem_ecc[ 6:0],dma_mem_wdata[31:0]};
         assign iccm_wr_data[77:39] =  (iccm_correct_ecc & ~(ifc_dma_access_q_ok & dma_iccm_req)) ?  iccm_ecc_corr_data_ff[38:0] :
                                       {dma_mem_ecc[13:7],dma_mem_wdata[63:32]};

         assign iccm_dma_rdata_in[63:0] =  iccm_dma_ecc_error_in ? {2{dma_mem_addr[31:0]}} : dma_select_upper ? {iccm_corrected_data[3], iccm_corrected_data[2]} : {iccm_corrected_data[1],iccm_corrected_data[0]};
         assign iccm_dma_ecc_error_in   =  dma_select_upper ? |(iccm_double_ecc_error[3:2]) : |(iccm_double_ecc_error[1:0]);

         rvdff #(1)           dma_addr_bt3_ff  (.*, .clk(free_clk), .din(dma_mem_addr[3]),         .dout(dma_select_upper));
         rvdff #(1)           ccm_rdy_in_ff    (.*, .clk(free_clk), .din(iccm_dma_rden),           .dout(iccm_dma_rvalid_in));
         rvdff #(1)           ccm_rdy_ff       (.*, .clk(free_clk), .din(iccm_dma_rvalid_in),      .dout(iccm_dma_rvalid));
         rvdff #(1)           ccm_err_ff       (.*, .clk(free_clk), .din(iccm_dma_ecc_error_in),   .dout(iccm_dma_ecc_error));
         rvdff #(64)          dma_data_ff      (.*, .clk(free_clk), .din(iccm_dma_rdata_in[63:0]), .dout(iccm_dma_rdata[63:0]));

         assign iccm_rw_addr[ICCM_BITS-1:2]    = (  ifc_dma_access_q_ok & dma_iccm_req  & ~iccm_correct_ecc) ? dma_mem_addr[ICCM_BITS-1:2] :
                                                 (~(ifc_dma_access_q_ok & dma_iccm_req) &  iccm_correct_ecc) ? iccm_ecc_corr_index_ff[ICCM_BITS-1:2] : fetch_addr_f1[ICCM_BITS-1:2] ;
    `else
         assign iccm_dma_rvalid = 1'b0 ;
         assign iccm_dma_ecc_error = 1'b0 ;
         assign iccm_dma_rdata[63:0] = '0 ;
    `endif


////// ICCM signals

assign   ic_rd_en    = ifc_fetch_req_f1 & ~ifc_fetch_uncacheable_f1;

assign ifu_tag_wren[0] = axi_w0_wren_last | w0_wren_reset_miss;
assign ifu_tag_wren[1] = axi_w1_wren_last | w1_wren_reset_miss;
assign ifu_tag_wren[2] = axi_w2_wren_last | w2_wren_reset_miss;
assign ifu_tag_wren[3] = axi_w3_wren_last | w3_wren_reset_miss;
assign ifu_wr_en_new   = axi_ifu_wr_en_new;
assign ifu_wr_en_new_q = axi_ifu_wr_en_new_q;
assign ifu_wr_data_new[63:0]=  axi_ifu_wr_data_new[63:0];
assign ic_wr_en[3:0]   =  axi_ic_wr_en[3:0];
assign ic_write_stall  = ifu_wr_en_new &  ~(((miss_state== CRIT_BYP_OK) & ~(ifu_wr_en_new & last_beat)));

   rvdff #(1) reset_all_tag_ff (.*, .clk(active_clk),  .din(dec_tlu_fence_i_wb), .dout(reset_all_tags));



///////////////////////////////////////////////////////////////
// Icache status and LRU
///////////////////////////////////////////////////////////////
`ifdef RV_ICACHE_ENABLE
   assign  ic_valid  = ~ifu_wr_cumulative_err_data & ~(reset_ic_in | reset_ic_ff) & ~reset_tag_valid_for_miss;

   assign ifu_status_wr_addr_w_debug[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] = ((ic_debug_rd_en | ic_debug_wr_en ) & ic_debug_tag_array) ?
                                                                           ic_debug_addr[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] :
                                                                           ifu_status_wr_addr[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW];

   // status
         rvdff #(ICACHE_TAG_HIGH-ICACHE_TAG_LOW) status_wr_addr_ff (.*,  .clk(free_clk), .din(ifu_status_wr_addr_w_debug[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]),
                   .dout(ifu_status_wr_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]));

         assign way_status_wr_en_w_debug = way_status_wr_en | (ic_debug_wr_en  & ic_debug_tag_array);
         rvdff #(1) status_wren_ff (.*, .clk(free_clk),  .din(way_status_wr_en_w_debug), .dout(way_status_wr_en_ff));

         assign way_status_new_w_debug[2:0]  = (ic_debug_wr_en  & ic_debug_tag_array) ? ic_debug_wr_data[6:4] :
                                                way_status_new[2:0] ;
         rvdff #(3) status_data_ff (.*,  .clk(free_clk), .din(way_status_new_w_debug[2:0]), .dout(way_status_new_ff[2:0]));

   logic [(ICACHE_TAG_DEPTH/8)-1 : 0] way_status_clken;
   logic [(ICACHE_TAG_DEPTH/8)-1 : 0] way_status_clk;

   genvar  j;
   for (i=0 ; i<ICACHE_TAG_DEPTH/8 ; i++) begin : CLK_GRP_WAY_STATUS
      assign way_status_clken[i] = (ifu_status_wr_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+3] == i );


`ifndef RV_FPGA_OPTIMIZE
   rvclkhdr way_status_cgc ( .en(way_status_clken[i]),   .l1clk(way_status_clk[i]), .* );            // ifndef FPGA_OPTIMIZE
`endif

      for (j=0 ; j<8 ; j++) begin : WAY_STATUS

         rvdffs_fpga #(3) ic_way_status (.*,
                   .clk(way_status_clk[i]),
                   .clken(way_status_clken[i]),
                   .rawclk(clk),
                   .en(((ifu_status_wr_addr_ff[ICACHE_TAG_LOW+2:ICACHE_TAG_LOW] == j) & way_status_wr_en_ff)),
                   .din(way_status_new_ff[2:0]),
                   .dout(way_status_out[8*i+j]));

      end  // WAY_STATUS
   end  // CLK_GRP_WAY_STATUS

  always_comb begin : way_status_out_mux
      way_status[2:0] = 3'b0 ;
      for (int j=0; j< ICACHE_TAG_DEPTH; j++) begin : status_mux_loop
        if (ifu_ic_rw_int_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] == (ICACHE_TAG_HIGH-ICACHE_TAG_LOW)'(j)) begin : mux_out
         way_status[2:0] =  way_status_out[j];
        end
      end
  end

assign ifu_ic_rw_int_addr_w_debug[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] = ((ic_debug_rd_en | ic_debug_wr_en ) & ic_debug_tag_array) ?
                                                                        ic_debug_addr[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] :
                                                                        ifu_ic_rw_int_addr[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW];

         rvdff #(ICACHE_TAG_HIGH-ICACHE_TAG_LOW) tag_addr_ff (.*, .clk(free_clk),
                   .din(ifu_ic_rw_int_addr_w_debug[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]),
                   .dout(ifu_ic_rw_int_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW]));

         assign ifu_tag_wren_w_debug[3:0] = ifu_tag_wren[3:0] | ic_debug_tag_wr_en[3:0] ;
         rvdff #(4) tag_v_we_ff (.*, .clk(free_clk),
                   .din(ifu_tag_wren_w_debug[3:0]),
                   .dout(ifu_tag_wren_ff[3:0]));

         assign ic_valid_w_debug = (ic_debug_wr_en & ic_debug_tag_array) ? ic_debug_wr_data[0] : ic_valid;
         rvdff #(1) tag_v_ff (.*, .clk(free_clk),
                   .din(ic_valid_w_debug),
                   .dout(ic_valid_ff));

   logic [3:0] [ICACHE_TAG_DEPTH-1:0] ic_tag_valid_out ;

   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w0_clken ;
   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w1_clken ;
   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w2_clken ;
   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w3_clken ;

   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w0_clk   ;
   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w1_clk   ;
   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w2_clk   ;
   logic [(ICACHE_TAG_DEPTH/32)-1:0]  tag_valid_w3_clk   ;



   for (i=0 ; i<ICACHE_TAG_DEPTH/32 ; i++) begin : CLK_GRP_TAG_VALID
      assign tag_valid_w0_clken[i] = (((ifu_ic_rw_int_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  ifu_tag_wren_ff[0] ) |
                                      ((perr_ic_index_ff     [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  perr_err_inv_way[0]) | reset_all_tags);
      assign tag_valid_w1_clken[i] = (((ifu_ic_rw_int_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  ifu_tag_wren_ff[1] ) |
                                      ((perr_ic_index_ff     [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  perr_err_inv_way[1]) | reset_all_tags);
      assign tag_valid_w2_clken[i] = (((ifu_ic_rw_int_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  ifu_tag_wren_ff[2] ) |
                                      ((perr_ic_index_ff     [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  perr_err_inv_way[2]) | reset_all_tags);
      assign tag_valid_w3_clken[i] = (((ifu_ic_rw_int_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  ifu_tag_wren_ff[3] ) |
                                      ((perr_ic_index_ff     [ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW+5] == i ) &  perr_err_inv_way[3]) | reset_all_tags);

`ifndef RV_FPGA_OPTIMIZE
      rvclkhdr way0_status_cgc ( .en(tag_valid_w0_clken[i]),   .l1clk(tag_valid_w0_clk[i]), .* );  // ifndef FPGA_OPTIMIZE
      rvclkhdr way1_status_cgc ( .en(tag_valid_w1_clken[i]),   .l1clk(tag_valid_w1_clk[i]), .* );  // ifndef FPGA_OPTIMIZE
      rvclkhdr way2_status_cgc ( .en(tag_valid_w2_clken[i]),   .l1clk(tag_valid_w2_clk[i]), .* );  // ifndef FPGA_OPTIMIZE
      rvclkhdr way3_status_cgc ( .en(tag_valid_w3_clken[i]),   .l1clk(tag_valid_w3_clk[i]), .* );  // ifndef FPGA_OPTIMIZE
`endif

    for (j=0 ; j<32 ; j++) begin : TAG_VALID
         rvdffs_fpga #(1) ic_way0_tagvalid_dup (.*,
                   .clk(tag_valid_w0_clk[i]),
                   .clken(tag_valid_w0_clken[i]),
                   .rawclk(clk),
                   .en(((ifu_ic_rw_int_addr_ff[ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & ifu_tag_wren_ff[0] ) |
                        ((perr_ic_index_ff     [ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & perr_err_inv_way[0]) | reset_all_tags),
                   .din(ic_valid_ff & ~reset_all_tags & ~perr_sel_invalidate),
                   .dout(ic_tag_valid_out[0][32*i+j]));

         rvdffs_fpga #(1) ic_way1_tagvalid_dup (.*,
                   .clk(tag_valid_w1_clk[i]),
                   .clken(tag_valid_w1_clken[i]),
                   .rawclk(clk),
                   .en(((ifu_ic_rw_int_addr_ff[ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & ifu_tag_wren_ff[1] ) |
                        ((perr_ic_index_ff     [ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & perr_err_inv_way[1]) | reset_all_tags),
                   .din(ic_valid_ff & ~reset_all_tags & ~perr_sel_invalidate),
                   .dout(ic_tag_valid_out[1][32*i+j]));

         rvdffs_fpga #(1) ic_way2_tagvalid_dup (.*,
                   .clk(tag_valid_w2_clk[i]),
                   .clken(tag_valid_w2_clken[i]),
                   .rawclk(clk),
                   .en(((ifu_ic_rw_int_addr_ff[ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & ifu_tag_wren_ff[2] ) |
                        ((perr_ic_index_ff     [ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & perr_err_inv_way[2]) | reset_all_tags),
                   .din(ic_valid_ff & ~reset_all_tags & ~perr_sel_invalidate),
                   .dout(ic_tag_valid_out[2][32*i+j]));
         rvdffs_fpga #(1) ic_way3_tagvalid_dup (.*,
                   .clk(tag_valid_w3_clk[i]),
                   .clken(tag_valid_w3_clken[i]),
                   .rawclk(clk),
                   .en(((ifu_ic_rw_int_addr_ff[ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & ifu_tag_wren_ff[3] ) |
                        ((perr_ic_index_ff     [ICACHE_TAG_LOW+4:ICACHE_TAG_LOW] == j) & perr_err_inv_way[3]) | reset_all_tags),
                   .din(ic_valid_ff & ~reset_all_tags & ~perr_sel_invalidate),
                   .dout(ic_tag_valid_out[3][32*i+j]));
    end //TAG_VALID
   end  // CLK_GRP_TAG_VALID
  logic [3:0] ic_tag_valid_unq;
  always_comb begin : tag_valid_out_mux
      ic_tag_valid_unq[3:0] = 4'b0 ;
      for (int j=0; j< ICACHE_TAG_DEPTH; j++) begin : tag_valid_loop
        if (ifu_ic_rw_int_addr_ff[ICACHE_TAG_HIGH-1:ICACHE_TAG_LOW] == (ICACHE_TAG_HIGH-ICACHE_TAG_LOW)'(j)) begin : valid_out
         ic_tag_valid_unq[3:0] =  {ic_tag_valid_out[3][j] , ic_tag_valid_out[2][j] , ic_tag_valid_out[1][j], ic_tag_valid_out[0][j]};
        end
      end
  end

`else
  logic [3:0] ic_tag_valid_unq;
  assign ic_tag_valid_unq[3:0] = '0 ;
  assign way_status[2:0]       = '0 ;
`endif

   assign ic_tag_valid[3:0] = ic_tag_valid_unq[3:0] & {4{(~fetch_uncacheable_ff & ifc_fetch_req_f2) }} ;
   assign ic_debug_tag_val_rd_out = |(ic_tag_valid_unq[3:0] &  ic_debug_way_ff[3:00] & {4{ic_debug_rd_en_ff}}) ;
///////////////////////////////////////////
// PMU signals
///////////////////////////////////////////

 assign ifu_pmu_ic_miss_in   = ic_act_miss_f2 ;
 assign ifu_pmu_ic_hit_in    = ic_act_hit_f2  ;
 assign ifu_pmu_bus_error_in = |ifc_bus_acc_fault_f2;
 assign ifu_pmu_bus_trxn_in  = axi_cmd_sent ;
 assign ifu_pmu_bus_busy_in  = ifu_axi_arvalid_ff & ~ifu_axi_arready_ff & miss_pending ;

   rvdff #(5) ifu_pmu_sigs_ff (.*,
                    .clk (active_clk),
                    .din ({ifu_pmu_ic_miss_in,
                           ifu_pmu_ic_hit_in,
                           ifu_pmu_bus_error_in,
                           ifu_pmu_bus_busy_in,
                           ifu_pmu_bus_trxn_in
                          }),
                    .dout({ifu_pmu_ic_miss,
                           ifu_pmu_ic_hit,
                           ifu_pmu_bus_error,
                           ifu_pmu_bus_busy,
                           ifu_pmu_bus_trxn
                           }));


///////////////////////////////////////////////////////
// Cache debug logic                                 //
///////////////////////////////////////////////////////
logic ic_debug_ic_array_sel_word0_in;
logic ic_debug_ic_array_sel_word1_in;
logic ic_debug_ic_array_sel_word2_in;
logic ic_debug_ic_array_sel_word3_in;

logic ic_debug_ic_array_sel_word0   ;
logic ic_debug_ic_array_sel_word1   ;
logic ic_debug_ic_array_sel_word2   ;
logic ic_debug_ic_array_sel_word3   ;



assign ic_debug_addr[15:02]     = dec_tlu_ic_diag_pkt.icache_dicawics[15:2] ;
assign ic_debug_way_enc[01:00]  = dec_tlu_ic_diag_pkt.icache_dicawics[17:16] ;

`ifdef RV_ICACHE_ECC
assign ic_debug_wr_data[41:0]   = dec_tlu_ic_diag_pkt.icache_wrdata[41:0] ;
`else
assign ic_debug_wr_data[33:0]   = dec_tlu_ic_diag_pkt.icache_wrdata[33:0] ;
`endif

assign ic_debug_tag_array       = dec_tlu_ic_diag_pkt.icache_dicawics[18] ;
assign ic_debug_rd_en           = dec_tlu_ic_diag_pkt.icache_rd_valid ;
assign ic_debug_wr_en           = dec_tlu_ic_diag_pkt.icache_wr_valid ;


assign ic_debug_way[3:0]        = {(ic_debug_way_enc[1:0] == 2'b11),
                                   (ic_debug_way_enc[1:0] == 2'b10),
                                   (ic_debug_way_enc[1:0] == 2'b01),
                                   (ic_debug_way_enc[1:0] == 2'b00) };

assign ic_debug_tag_wr_en[3:0] = {4{ic_debug_wr_en & ic_debug_tag_array}} & ic_debug_way[3:0] ;

assign ic_debug_ic_array_sel_word0_in = (ic_debug_addr[3:2] == 2'b00) & ic_debug_rd_en & ~ic_debug_tag_array ;
assign ic_debug_ic_array_sel_word1_in = (ic_debug_addr[3:2] == 2'b01) & ic_debug_rd_en & ~ic_debug_tag_array ;
assign ic_debug_ic_array_sel_word2_in = (ic_debug_addr[3:2] == 2'b10) & ic_debug_rd_en & ~ic_debug_tag_array ;
assign ic_debug_ic_array_sel_word3_in = (ic_debug_addr[3:2] == 2'b11) & ic_debug_rd_en & ~ic_debug_tag_array ;
assign ic_debug_ict_array_sel_in      =  ic_debug_rd_en & ic_debug_tag_array ;

rvdffe #(09) ifu_debug_sel_ff (.*,
                    .en (debug_c1_clken),
                    .din ({ic_debug_ic_array_sel_word0_in,
                           ic_debug_ic_array_sel_word1_in,
                           ic_debug_ic_array_sel_word2_in,
                           ic_debug_ic_array_sel_word3_in,
                           ic_debug_ict_array_sel_in,
                           ic_debug_way[3:0]
                          }),
                    .dout({ic_debug_ic_array_sel_word0,
                           ic_debug_ic_array_sel_word1,
                           ic_debug_ic_array_sel_word2,
                           ic_debug_ic_array_sel_word3,
                           ic_debug_ict_array_sel_ff,
                           ic_debug_way_ff[3:0]
                           }));


rvdff #(1) ifu_debug_rd_en_ff (.*,.clk(free_clk),
                    .din ({
                           ic_debug_rd_en
                          }),
                    .dout({
                           ic_debug_rd_en_ff
                           }));


`ifdef RV_ICACHE_ECC
logic [41:0] ifu_ic_debug_rd_data_in   ;
assign ifu_ic_debug_rd_data_in[41:0] = ( {42{ic_debug_ict_array_sel_ff   }} &  {5'b0,ictag_debug_rd_data[24:20], ictag_debug_rd_data[19:0] ,5'b0, way_status[2:0], 3'b0, ic_debug_tag_val_rd_out} ) |
                                       ( {42{ic_debug_ic_array_sel_word0 }} &  {ic_rd_data [41:0]}  )  |
                                       ( {42{ic_debug_ic_array_sel_word1 }} &  {ic_rd_data [83:42]} )  |
                                       ( {42{ic_debug_ic_array_sel_word2 }} &  {ic_rd_data [125:84]})  |
                                       ( {42{ic_debug_ic_array_sel_word3 }} &  {ic_rd_data [167:126]}) ;

rvdffe #(42) ifu_debug_data_ff (.*,
                    .en (debug_data_clken),
                    .din ({
                           ifu_ic_debug_rd_data_in[41:0]
                          }),
                    .dout({
                           ifu_ic_debug_rd_data
                           }));

`else
logic [33:0] ifu_ic_debug_rd_data_in   ;
assign ifu_ic_debug_rd_data_in[33:0] = ( {34{ic_debug_ict_array_sel_ff   }} &  {1'b0,ictag_debug_rd_data[20], ictag_debug_rd_data[19:0] ,5'b0, way_status[2:0], 3'b0, ic_debug_tag_val_rd_out} ) |
                                       ( {34{ic_debug_ic_array_sel_word0 }} &  {ic_rd_data [33:0]}  )  |
                                       ( {34{ic_debug_ic_array_sel_word1 }} &  {ic_rd_data [67:34]} )  |
                                       ( {34{ic_debug_ic_array_sel_word2 }} &  {ic_rd_data [101:68]})  |
                                       ( {34{ic_debug_ic_array_sel_word3 }} &  {ic_rd_data [135:102]}) ;

rvdffe #(34) ifu_debug_data_ff (.*,
                    .en (debug_data_clken),
                    .din ({
                           ifu_ic_debug_rd_data_in[33:0]
                          }),
                    .dout({
                           ifu_ic_debug_rd_data
                           }));

`endif

assign debug_data_clken  =  ic_debug_rd_en_ff;

rvdff #(1) ifu_debug_valid_ff (.*, .clk(free_clk),
                    .din ({
                           ic_debug_rd_en_ff
                          }),
                    .dout({
                           ifu_ic_debug_rd_data_valid
                           }));

// memory protection
   assign ifc_region_acc_okay           =  (~(|{`RV_INST_ACCESS_ENABLE0,`RV_INST_ACCESS_ENABLE1,`RV_INST_ACCESS_ENABLE2,`RV_INST_ACCESS_ENABLE3,`RV_INST_ACCESS_ENABLE4,`RV_INST_ACCESS_ENABLE5,`RV_INST_ACCESS_ENABLE6,`RV_INST_ACCESS_ENABLE7})) |
                                           (`RV_INST_ACCESS_ENABLE0 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK0) == (`RV_INST_ACCESS_ADDR0 | `RV_INST_ACCESS_MASK0))) |
                                           (`RV_INST_ACCESS_ENABLE1 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK1) == (`RV_INST_ACCESS_ADDR1 | `RV_INST_ACCESS_MASK1))) |
                                           (`RV_INST_ACCESS_ENABLE2 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK2) == (`RV_INST_ACCESS_ADDR2 | `RV_INST_ACCESS_MASK2))) |
                                           (`RV_INST_ACCESS_ENABLE3 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK3) == (`RV_INST_ACCESS_ADDR3 | `RV_INST_ACCESS_MASK3))) |
                                           (`RV_INST_ACCESS_ENABLE4 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK4) == (`RV_INST_ACCESS_ADDR4 | `RV_INST_ACCESS_MASK4))) |
                                           (`RV_INST_ACCESS_ENABLE5 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK5) == (`RV_INST_ACCESS_ADDR5 | `RV_INST_ACCESS_MASK5))) |
                                           (`RV_INST_ACCESS_ENABLE6 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK6) == (`RV_INST_ACCESS_ADDR6 | `RV_INST_ACCESS_MASK6))) |
                                           (`RV_INST_ACCESS_ENABLE7 & (({fetch_addr_f1[31:1],1'b0} | `RV_INST_ACCESS_MASK7) == (`RV_INST_ACCESS_ADDR7 | `RV_INST_ACCESS_MASK7)));

   assign ifc_region_acc_fault_memory   =  ~ifc_iccm_access_f1 & ~ifc_region_acc_okay & ifc_fetch_req_f1;

   assign ifc_region_acc_fault_final_f1 = ifc_region_acc_fault_f1 | ifc_region_acc_fault_memory;





////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
///  Assertions , Assertions , Assertions , Assertions , Assertions , Assertions ///
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
`ifdef ASSERT_ON
   assert_hit_miss_one_z_hot: assert #0 ($onehot0({ic_iccm_hit_f2,ic_byp_hit_f2,ic_act_hit_f2,ic_act_miss_f2,ic_miss_under_miss_f2}));

   property fetch_stall;
     @(posedge clk) disable iff(~rst_l) (ic_debug_rd_en | ic_debug_wr_en | ic_dma_active | ic_write_stall)  |->  ~ifc_fetch_req_f1;
   endproperty
   assert_fetch_stall: assert property (fetch_stall) else
     $display("Assertion fetch_stall: ic_debug_rd_en=1'b%b, ic_debug_wr_en=1'b%b,  ic_dma_active=1'b%b,  ic_write_stall=1'b%b",ic_debug_rd_en,ic_debug_wr_en, ic_dma_active, ic_write_stall);


   assert_perr_one_z_hot: assert #0 ($onehot0({ifu_icache_error_val,ifu_icache_sb_error_val}));

`endif

endmodule  // ifu_mem_ctl
