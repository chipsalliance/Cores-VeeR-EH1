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
// Function: Top level file for Icache, Fetch, Branch prediction & Aligner
// BFF -> F1 -> F2 -> A
//********************************************************************************

module ifu
   import swerv_types::*;
(
   input logic free_clk,
   input logic active_clk,
   input logic clk,
   input logic clk_override,
   input logic rst_l,

   input logic dec_ib3_valid_d, dec_ib2_valid_d, // mass balance for decode buffer

   input logic dec_ib0_valid_eff_d,   // effective valid taking decode into account 
   input logic dec_ib1_valid_eff_d,   // effective valid taking decode into account 
   
   input logic        exu_i0_br_ret_e4, // i0 branch commit is a ret
   input logic        exu_i1_br_ret_e4, // i1 branch commit is a ret
   input logic        exu_i0_br_call_e4, // i0 branch commit is a call
   input logic        exu_i1_br_call_e4, // i1 branch commit is a call

   input logic exu_flush_final, // flush, includes upper and lower
   input logic dec_tlu_flush_err_wb , // flush due to parity error.
   input logic dec_tlu_flush_noredir_wb, // don't fetch, validated with exu_flush_final
   input logic dec_tlu_dbg_halted, // halted, used for leaving IDLE state
   input logic dec_tlu_pmu_fw_halted, // Core is halted
   input logic [31:1] exu_flush_path_final, // flush fetch address
   input logic        exu_flush_upper_e2,    // flush upper, either i0 or i1

   input logic [31:0]  dec_tlu_mrac_ff ,// Side_effect , cacheable for each region
   input logic         dec_tlu_fence_i_wb, // fence.i, invalidate icache, validated with exu_flush_final
   input logic         dec_tlu_flush_leak_one_wb, // ignore bp for leak one fetches
  
   input logic                       dec_tlu_bpred_disable, // disable all branch prediction          
   input logic                       dec_tlu_core_ecc_disable,  // disable ecc checking and flagging

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

 //// AHB LITE BUS
//`ifdef RV_BUILD_AHB_LITE 
   input  logic                      ifu_bus_clk_en,


   input  logic                      dma_iccm_req, 
   input  logic                      dma_iccm_stall_any, 
   input  logic [31:0]               dma_mem_addr,
   input  logic [2:0]                dma_mem_sz,
   input  logic                      dma_mem_write,
   input  logic [63:0]               dma_mem_wdata,
                                     
   output logic                      iccm_dma_ecc_error,                 
   output logic                      iccm_dma_rvalid,            
   output logic [63:0]               iccm_dma_rdata,
   output logic                      iccm_ready,

//`endif   

   output logic [1:0] ifu_pmu_instr_aligned,
   output logic       ifu_pmu_align_stall,
   output logic       ifu_pmu_fetch_stall,
   
//   I$ & ITAG Ports   
   output logic [31:3]               ic_rw_addr,         // Read/Write addresss to the Icache.   
   output logic [3:0]                ic_wr_en,           // Icache write enable, when filling the Icache.
   output logic                      ic_rd_en,           // Icache read  enable.
`ifdef RV_ICACHE_ECC
   output logic [83:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [167:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [24:0]               ictag_debug_rd_data,// Debug icache tag. 
   output logic [41:0]               ic_debug_wr_data,   // Debug wr cache. 
   output logic [41:0]               ifu_ic_debug_rd_data,
`else 
   output logic [67:0]               ic_wr_data,         // Data to fill to the Icache. With Parity
   input  logic [135:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With Parity
   input  logic [20:0]               ictag_debug_rd_data,// Debug icache tag. 
   output logic [33:0]               ic_debug_wr_data,   // Debug wr cache. 
   output logic [33:0]               ifu_ic_debug_rd_data,
`endif


   output logic [127:0]              ic_premux_data,     // Premux data to be muxed with each way of the Icache. 
   output logic                      ic_sel_premux_data, // Select the premux data.

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
   output logic [`RV_ICCM_BITS-1:2]               iccm_rw_addr,       // ICCM read/write address.
   output logic                      iccm_wren,          // ICCM write enable (through the DMA)
   output logic                      iccm_rden,          // ICCM read enable.
   output logic [77:0]               iccm_wr_data,       // ICCM write data.
   output logic [2:0]                iccm_wr_size,       // ICCM write location within DW. 
                                     
   input  logic [155:0]              iccm_rd_data,       // Data read from ICCM.
`endif

// Perf counter sigs
   output logic       ifu_pmu_ic_miss, // ic miss
   output logic       ifu_pmu_ic_hit, // ic hit 
   output logic       ifu_pmu_bus_error, // iside bus error
   output logic       ifu_pmu_bus_busy,  // iside bus busy
   output logic       ifu_pmu_bus_trxn, // iside bus transactions


   output logic  ifu_i0_valid,        // Instruction 0 valid. From Aligner to Decode 
   output logic  ifu_i1_valid,        // Instruction 1 valid. From Aligner to Decode 
   output logic  ifu_i0_icaf,         // Instruction 0 access fault. From Aligner to Decode
   output logic  ifu_i1_icaf,         // Instruction 1 access fault. From Aligner to Decode 
   output logic  ifu_i0_icaf_f1,      // Instruction 0 has access fault on second fetch group
   output logic  ifu_i1_icaf_f1,      // Instruction 1 has access fault on second fetch group
   output logic  ifu_i0_perr,         // Instruction 0 parity error. From Aligner to Decode
   output logic  ifu_i1_perr,         // Instruction 1 parity error. From Aligner to Decode 
   output logic  ifu_i0_sbecc,        // Instruction 0 has single bit ecc error
   output logic  ifu_i1_sbecc,        // Instruction 1 has single bit ecc error
   output logic  ifu_i0_dbecc,        // Instruction 0 has double bit ecc error
   output logic  ifu_i1_dbecc,        // Instruction 1 has double bit ecc error
   output logic  iccm_dma_sb_error,   // Single Bit ECC error from a DMA access
   output logic[31:0] ifu_i0_instr,   // Instruction 0 . From Aligner to Decode
   output logic[31:0] ifu_i1_instr,   // Instruction 1 . From Aligner to Decode 
   output logic[31:1] ifu_i0_pc,      // Instruction 0 pc. From Aligner to Decode 
   output logic[31:1] ifu_i1_pc,      // Instruction 1 pc. From Aligner to Decode
   output logic ifu_i0_pc4,           // Instruction 0 is 4 byte. From Aligner to Decode
   output logic ifu_i1_pc4,           // Instruction 1 is 4 byte. From Aligner to Decode 
   output logic [15:0] ifu_illegal_inst, // Illegal instruction.

   output logic ifu_miss_state_idle,   // There is no outstanding miss. Cache miss state is idle.


   output br_pkt_t i0_brp,           // Instruction 0 branch packet. From Aligner to Decode
   output br_pkt_t i1_brp,           // Instruction 1 branch packet. From Aligner to Decode

   input predict_pkt_t  exu_mp_pkt, // mispredict packet
   input logic [`RV_BHT_GHR_RANGE] exu_mp_eghr, // execute ghr

   input br_tlu_pkt_t dec_tlu_br0_wb_pkt, // slot0 update/error pkt
   input br_tlu_pkt_t dec_tlu_br1_wb_pkt, // slot1 update/error pkt
   input dec_tlu_flush_lower_wb,
   
   input rets_pkt_t exu_rets_e1_pkt, // E1 return stack packet
   input rets_pkt_t exu_rets_e4_pkt, // E4 return stack packet

   // pc's  used to maintain and update the BP RET stacks
`ifdef REAL_COMM_RS
   input logic [31:1] exu_i0_pc_e1,
   input logic [31:1] exu_i1_pc_e1,
   input logic [31:1] dec_tlu_i0_pc_e4,
   input logic [31:1] dec_tlu_i1_pc_e4,
`endif

   output logic [15:0] ifu_i0_cinst,
   output logic [15:0] ifu_i1_cinst,


/// Icache debug 
   input  cache_debug_pkt_t        dec_tlu_ic_diag_pkt ,
   output logic                    ifu_ic_debug_rd_data_valid,
 


   input logic scan_mode   
   );

   localparam TAGWIDTH = 2 ;
   localparam IDWIDTH  = 2 ;

   logic                   ifu_fb_consume1, ifu_fb_consume2;
   logic [31:1]            ifc_fetch_addr_f2;
   logic                   ifc_fetch_uncacheable_f1;

   logic [7:0]   ifu_fetch_val;  // valids on a 2B boundary, left justified [7] implies valid fetch
   logic [31:1]  ifu_fetch_pc;   // starting pc of fetch

   logic [31:1] ifc_fetch_addr_f1;
   
   logic        ic_crit_wd_rdy;
   logic        ic_write_stall;
   logic        ic_dma_active;
   logic        ifc_dma_access_ok;
   logic        ifc_iccm_access_f1;
   logic        ifc_region_acc_fault_f1;
   logic        ic_access_fault_f2;
   logic        ifu_ic_mb_empty;

   
   logic ic_hit_f2;
   
   // fetch control
   ifu_ifc_ctl ifc (.*
                    );


`ifdef RV_BTB_48
   logic [7:0][1:0] ifu_bp_way_f2; // way indication; right justified
`else
   logic [7:0]  ifu_bp_way_f2; // way indication; right justified
`endif
   logic  ifu_bp_kill_next_f2; // kill next fetch; taken target found
   logic [31:1] ifu_bp_btb_target_f2; //  predicted target PC
   logic [7:1]  ifu_bp_inst_mask_f2; // tell ic which valids to kill because of a taken branch; right justified
   logic [7:0]  ifu_bp_hist1_f2; // history counters for all 4 potential branches; right justified
   logic [7:0]  ifu_bp_hist0_f2; // history counters for all 4 potential branches; right justified
   logic [11:0] ifu_bp_poffset_f2; // predicted target
   logic [7:0]  ifu_bp_ret_f2; // predicted ret ; right justified
   logic [7:0]  ifu_bp_pc4_f2; // pc4 indication; right justified
   logic [7:0]  ifu_bp_valid_f2; // branch valid, right justified
   logic [`RV_BHT_GHR_RANGE] ifu_bp_fghr_f2;
   
   // branch predictor
   ifu_bp_ctl bp (.*);

   
   logic [7:0]   ic_fetch_val_f2;
   logic [127:0] ic_data_f2;
   logic [127:0] ifu_fetch_data;
   logic ifc_fetch_req_f1_raw, ifc_fetch_req_f1, ifc_fetch_req_f2;
   logic ic_rd_parity_final_err;  // This fetch has a  data_cache or tag  parity error. 
   logic iccm_rd_ecc_single_err;  // This fetch has an iccm single error. 
   logic iccm_rd_ecc_double_err;  // This fetch has an iccm double error.

   icache_err_pkt_t ic_error_f2;
   
   logic         ifu_icache_fetch_f2 ;
   logic [16:2]  ifu_icache_error_index;       //  Index with parity error
   logic         ifu_icache_error_val;   //  Parity error 
   logic         ifu_icache_sb_error_val;

   assign ifu_fetch_data[127:0] = ic_data_f2[127:0];
   assign ifu_fetch_val[7:0] = ic_fetch_val_f2[7:0];
   assign ifu_fetch_pc[31:1] = ifc_fetch_addr_f2[31:1];
   
   // aligner
   ifu_aln_ctl aln (.*);

   // icache
   ifu_mem_ctl mem_ctl  
     (.*,
      .fetch_addr_f1(ifc_fetch_addr_f1),
      .ifu_icache_error_index(ifu_icache_error_index[16:6]),  
      .ic_hit_f2(ic_hit_f2),
      .ic_data_f2(ic_data_f2[127:0])
      );
   


   // Performance debug info
   //
   //
`ifdef DUMP_BTB_ON
   logic              exu_mp_valid; // conditional branch mispredict
   logic exu_mp_way; // conditional branch mispredict
   logic exu_mp_ataken; // direction is actual taken
   logic exu_mp_boffset; // branch offsett
   logic exu_mp_pc4; // branch is a 4B inst
   logic exu_mp_call; // branch is a call inst
   logic exu_mp_ret; // branch is a ret inst
   logic exu_mp_ja; // branch is a jump always
   logic [1:0] exu_mp_hist; // new history
   logic [11:0] exu_mp_tgt; // target offset
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_mp_addr; // BTB/BHT address
   logic [1:0]                          exu_mp_bank; // write bank; based on branch PC[3:2]
   logic [`RV_BTB_BTAG_SIZE-1:0] exu_mp_btag; // branch tag
   logic [`RV_BHT_GHR_RANGE] exu_mp_fghr; // original fetch ghr (for correcting dir)

   assign exu_mp_valid = exu_mp_pkt.misp; // conditional branch mispredict
   assign exu_mp_ataken = exu_mp_pkt.ataken;  // direction is actual taken
   assign exu_mp_boffset = exu_mp_pkt.boffset;  // branch offset
   assign exu_mp_pc4 = exu_mp_pkt.pc4;  // branch is a 4B inst
   assign exu_mp_call = exu_mp_pkt.pcall;  // branch is a call inst
   assign exu_mp_ret = exu_mp_pkt.pret;  // branch is a ret inst
   assign exu_mp_ja = exu_mp_pkt.pja;  // branch is a jump always
   assign exu_mp_way = exu_mp_pkt.way;  // branch is a jump always
   assign exu_mp_hist[1:0] = exu_mp_pkt.hist[1:0];  // new history
   assign exu_mp_tgt[11:0]  = exu_mp_pkt.toffset[11:0] ;  // target offset
   assign exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]  = exu_mp_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ;  // BTB/BHT address
   assign exu_mp_bank[1:0]  = exu_mp_pkt.bank[1:0] ;  // write bank = exu_mp_pkt.;  based on branch PC[3:2]
   assign exu_mp_btag = exu_mp_pkt.btag[`RV_BTB_BTAG_SIZE-1:0] ;  // branch tag
   assign exu_mp_fghr[`RV_BHT_GHR_RANGE]  = exu_mp_pkt.fghr[`RV_BHT_GHR_RANGE] ;  // original fetch ghr (for correcting dir)

   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] btb_rd_addr_f2;
 `define DEC `CPU_TOP.dec
 `define EXU `CPU_TOP.exu
   rvbtb_addr_hash f2hash(.pc(ifc_fetch_addr_f2[31:1]), .hash(btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   logic [31:0] mppc_ns, mppc;
   assign mppc_ns[31:1] = `EXU.exu_i0_flush_upper_e1 ? `DEC.decode.i0_pc_e1[31:1] : (`EXU.exu_i1_flush_upper_e1 ? `DEC.decode.i1_pc_e1[31:1] : (`EXU.exu_i0_flush_lower_e4 ?  `DEC.decode.i0_pc_e4[31:1] :  `DEC.decode.i1_pc_e4[31:1]));
   assign mppc_ns[0] = 1'b0;
   logic [3:0] ic_rd_hit_f2;
   rvdff #(36)  mdseal_ff (.*, .din({mppc_ns[31:0], mem_ctl.ic_rd_hit[3:0]}), .dout({mppc[31:0],ic_rd_hit_f2[3:0]}));
logic [2:0] tmp_bnk;
assign tmp_bnk[2:0] = encode8_3(bp.btb_sel_f2[7:0]);
   always @(negedge clk) begin
      if(`DEC.tlu.mcyclel[31:0] == 32'h0000_0010) begin
         $display("BTB_CONFIG: %d",`RV_BTB_ARRAY_DEPTH*4);
         `ifndef BP_NOGSHARE
         $display("BHT_CONFIG: %d gshare: 1",`RV_BHT_ARRAY_DEPTH*4);
         `else
         $display("BHT_CONFIG: %d gshare: 0",`RV_BHT_ARRAY_DEPTH*4);
         `endif
         $display("RS_CONFIG: %d", `RV_RET_STACK_SIZE);
      end
       if(exu_flush_final & ~(dec_tlu_br0_wb_pkt.br_error | dec_tlu_br0_wb_pkt.br_start_error | dec_tlu_br1_wb_pkt.br_error | dec_tlu_br1_wb_pkt.br_start_error) & (exu_mp_pkt.misp | exu_mp_pkt.ataken)) 
         $display("%7d BTB_MP  : index: %0h bank: %0h call: %b ret: %b ataken: %b hist: %h valid: %b tag: %h targ: %h eghr: %b pred: %b ghr_index: %h brpc: %h way: %h", `DEC.tlu.mcyclel[31:0]+32'ha, exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO], exu_mp_bank[1:0], exu_mp_call, exu_mp_ret, exu_mp_ataken, exu_mp_hist[1:0], exu_mp_valid, exu_mp_pkt.btag[`RV_BTB_BTAG_SIZE-1:0], {exu_flush_path_final[31:1], 1'b0}, exu_mp_eghr[`RV_BHT_GHR_RANGE], exu_mp_valid, bp.bht_wr_addr0, mppc[31:0], exu_mp_pkt.way);
     for(int i = 0; i < 8; i++) begin
      if(ifu_bp_valid_f2[i] & ifc_fetch_req_f2) 
        $display("%7d BTB_HIT : index: %0h bank: %0h call: %b ret: %b taken: %b strength: %b tag: %h targ: %h ghr: %4b ghr_index: %h way: %h", `DEC.tlu.mcyclel[31:0]+32'ha,btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO],encode8_3(bp.btb_sel_f2[7:0]), bp.btb_rd_call_f2, bp.btb_rd_ret_f2, ifu_bp_hist1_f2[tmp_bnk], ifu_bp_hist0_f2[tmp_bnk], bp.fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0], {ifu_bp_btb_target_f2[31:1], 1'b0}, bp.fghr[`RV_BHT_GHR_RANGE], bp.bht_rd_addr_f1, ifu_bp_way_f2[tmp_bnk]);
     end
`ifdef RV_BTB_48
      for(int y = 0; y < 4; y++) begin
         for(int z = 0; z < 4; z++) begin
            if(bp.lru_bank_sel[y][z])
              $display("%7d BTB_LRU: index: %0h bank: %0h newlru %h", `DEC.tlu.mcyclel[31:0]+32'ha, z,y,bp.lru_bank_wr_data[y][z]);     
         end
      end
`endif      
      if(dec_tlu_br0_wb_pkt.valid & ~(dec_tlu_br0_wb_pkt.br_error | dec_tlu_br0_wb_pkt.br_start_error))
        $display("%7d BTB_UPD0: ghr_index: %0h bank: %0h hist: %h  way: %h", `DEC.tlu.mcyclel[31:0]+32'ha,bp.br0_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO],{dec_tlu_br0_wb_pkt.bank[1:0],dec_tlu_br0_wb_pkt.middle}, dec_tlu_br0_wb_pkt.hist, dec_tlu_br0_wb_pkt.way); 
      if(dec_tlu_br1_wb_pkt.valid & ~(dec_tlu_br1_wb_pkt.br_error | dec_tlu_br1_wb_pkt.br_start_error))
        $display("%7d BTB_UPD1: ghr_index: %0h bank: %0h hist: %h  way: %h", `DEC.tlu.mcyclel[31:0]+32'ha,bp.br1_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO],{dec_tlu_br1_wb_pkt.bank[1:0],dec_tlu_br1_wb_pkt.middle}, dec_tlu_br1_wb_pkt.hist, dec_tlu_br1_wb_pkt.way); 
      if(dec_tlu_br0_wb_pkt.br_error | dec_tlu_br0_wb_pkt.br_start_error)
        $display("%7d BTB_ERR0: index: %0h bank: %0h start: %b rfpc: %h way: %h", `DEC.tlu.mcyclel[31:0]+32'ha,dec_tlu_br0_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO],dec_tlu_br0_wb_pkt.bank[1:0], dec_tlu_br0_wb_pkt.br_start_error, {exu_flush_path_final[31:1], 1'b0}, dec_tlu_br0_wb_pkt.way);  
      if(dec_tlu_br1_wb_pkt.br_error | dec_tlu_br1_wb_pkt.br_start_error)
        $display("%7d BTB_ERR1: index: %0h bank: %0h start: %b rfpc: %h way: %h", `DEC.tlu.mcyclel[31:0]+32'ha,dec_tlu_br1_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO],dec_tlu_br1_wb_pkt.bank[1:0], dec_tlu_br1_wb_pkt.br_start_error, {exu_flush_path_final[31:1], 1'b0}, dec_tlu_br1_wb_pkt.way);
   end // always @ (negedge clk)
      function [2:0] encode8_3;
      input [7:0] in;

      encode8_3[2] = |in[7:4];
      encode8_3[1] = in[7] | in[6] | in[3] | in[2];
      encode8_3[0] = in[7] | in[5] | in[3] | in[1];

   endfunction          
`endif
endmodule // ifu
