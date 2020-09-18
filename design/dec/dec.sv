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

// dec: decode unit - decode, bypassing, ARF, interrupts
//
//********************************************************************************
// $Id$
//
//
// Function: Decode
// Comments: Decode, dependency scoreboard, ARF
//
//
// A -> D -> EX1 ... WB
//
//********************************************************************************

module dec
   import swerv_types::*;
(
   input logic clk,
   input logic free_clk,
   input logic active_clk,


   output logic       dec_pause_state_cg,           // pause state for clock-gating

   input logic rst_l,                        // reset, active low
   input logic [31:1] rst_vec,               // reset vector, from core pins

   input logic        nmi_int,               // NMI pin
   input logic [31:1] nmi_vec,               // NMI vector, from pins

   input logic  i_cpu_halt_req,              // Asynchronous Halt request to CPU
   input logic  i_cpu_run_req,               // Asynchronous Restart request to CPU

   output logic o_cpu_halt_status,           // Halt status of core (pmu/fw)
   output logic o_cpu_halt_ack,              // Halt request ack
   output logic o_cpu_run_ack,               // Run request ack
   output logic o_debug_mode_status,         // Core to the PMU that core is in debug mode. When core is in debug mode, the PMU should refrain from sendng a halt or run request

   // external MPC halt/run interface
   input logic mpc_debug_halt_req, // Async halt request
   input logic mpc_debug_run_req, // Async run request
   input logic mpc_reset_run_req, // Run/halt after reset
   output logic mpc_debug_halt_ack, // Halt ack
   output logic mpc_debug_run_ack, // Run ack
   output logic debug_brkpt_status, // debug breakpoint


   output logic dec_ib0_valid_eff_d,         // effective valid taking decode into account
   output logic dec_ib1_valid_eff_d,

   input logic       exu_pmu_i0_br_misp,     // slot 0 branch misp
   input logic       exu_pmu_i0_br_ataken,   // slot 0 branch actual taken
   input logic       exu_pmu_i0_pc4,         // slot 0 4 byte branch
   input logic       exu_pmu_i1_br_misp,     // slot 1 branch misp
   input logic       exu_pmu_i1_br_ataken,   // slot 1 branch actual taken
   input logic       exu_pmu_i1_pc4,         // slot 1 4 byte branch


   input logic                                 lsu_nonblock_load_valid_dc3,      // valid nonblock load at dc3
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_tag_dc3,        // -> corresponding tag
   input logic                                 lsu_nonblock_load_inv_dc5,        // invalidate request for nonblock load dc5
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_inv_tag_dc5,    // -> corresponding tag
   input logic                                 lsu_nonblock_load_data_valid,     // valid nonblock load data back
   input logic                                 lsu_nonblock_load_data_error,     // nonblock load bus error
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_data_tag,       // -> corresponding tag
   input logic [31:0]                          lsu_nonblock_load_data,           // nonblock load data

   input logic       lsu_pmu_bus_trxn,       // D side bus transaction
   input logic       lsu_pmu_bus_misaligned, // D side bus misaligned
   input logic       lsu_pmu_bus_error,      // D side bus error
   input logic       lsu_pmu_bus_busy,       // D side bus busy
   input logic       lsu_pmu_misaligned_dc3, // D side load or store misaligned

   input logic [1:0] ifu_pmu_instr_aligned,  // aligned instructions
   input logic       ifu_pmu_align_stall,    // aligner stalled
   input logic       ifu_pmu_fetch_stall,    // fetch unit stalled
   input logic       ifu_pmu_ic_miss,        // icache miss
   input logic       ifu_pmu_ic_hit,         // icache hit
   input logic       ifu_pmu_bus_error,      // Instruction side bus error
   input logic       ifu_pmu_bus_busy,       // Instruction side bus busy
   input logic       ifu_pmu_bus_trxn,       // Instruction side bus transaction

   input logic [3:0]  lsu_trigger_match_dc3,
   input logic        dbg_cmd_valid,   // debugger abstract command valid
   input logic  [1:0] dbg_cmd_size,    // size of the abstract mem access debug command
   input logic        dbg_cmd_write,   // command is a write
   input logic  [1:0] dbg_cmd_type,    // command type
   input logic [31:0] dbg_cmd_addr,    // command address
   input logic  [1:0] dbg_cmd_wrdata,  // command write data, for fence/fence_i


   input logic   ifu_i0_icaf,          // icache access fault
   input logic   ifu_i1_icaf,
   input logic   ifu_i0_icaf_second,       // i0 has access fault on second 2B of 4B inst
   input logic   ifu_i1_icaf_second,
   input logic   ifu_i0_perr,          // icache parity error
   input logic   ifu_i1_perr,
   input logic   ifu_i0_sbecc,         // icache/iccm single-bit error
   input logic   ifu_i1_sbecc,
   input logic   ifu_i0_dbecc,         // icache/iccm double-bit error
   input logic   ifu_i1_dbecc,

   input logic lsu_freeze_dc3,         // freeze pipe: decode -> dc3
   input logic lsu_idle_any,      // lsu idle for fence instructions
   input logic lsu_halt_idle_any,      // lsu idle for halting

   input br_pkt_t i0_brp,              // branch packet
   input br_pkt_t i1_brp,

   input    lsu_error_pkt_t lsu_error_pkt_dc3, // LSU exception/error packet
   input logic         lsu_single_ecc_error_incr,    // Increment the counter for Single ECC error

   input logic lsu_load_ecc_stbuf_full_dc3,    // STBUF full, ecc errors should be rfpc'd

   input logic         lsu_imprecise_error_load_any,   // LSU imprecise load bus error
   input logic         lsu_imprecise_error_store_any,  // LSU imprecise store bus error
   input logic [31:0]  lsu_imprecise_error_addr_any,   // LSU imprecise bus error address
   input logic         lsu_freeze_external_ints_dc3,   // load to side effect region

   input logic exu_i0_flush_lower_e4,       // slot 0 flush for mp
   input logic exu_i1_flush_lower_e4,       // slot 1 flush for mp
   input logic [31:1] exu_i0_flush_path_e4, // slot 0 flush target for mp
   input logic [31:1] exu_i1_flush_path_e4, // slot 1 flush target for mp

   input logic [15:0] ifu_illegal_inst,     // 16b opcode for illegal inst

   input logic exu_div_stall,               // stall decode for div executing
   input logic [31:0]  exu_div_result,      // final div result
   input logic exu_div_finish,              // cycle div finishes

   input logic [31:0] exu_mul_result_e3,    // 32b mul result

   input logic [31:0] exu_csr_rs1_e1,       // rs1 for csr instruction

   input logic [31:0] lsu_result_dc3,       // load result
   input logic [31:0] lsu_result_corr_dc4, // corrected load result

   input logic        lsu_load_stall_any,   // This is for blocking loads
   input logic        lsu_store_stall_any,  // This is for blocking stores
   input logic        dma_dccm_stall_any,   // stall any load/store at decode, pmu event
   input logic        dma_iccm_stall_any,   // iccm stalled, pmu event

   input logic       iccm_dma_sb_error,     // ICCM DMA single bit error

   input logic exu_i0_flush_final,          // slot0 flush
   input logic exu_i1_flush_final,          // slot1 flush

   input logic [31:1] exu_npc_e4,           // next PC

   input logic exu_flush_final,             // final flush

   input logic [31:0] exu_i0_result_e1,     // alu result e1
   input logic [31:0] exu_i1_result_e1,

   input logic [31:0] exu_i0_result_e4,     // alu result e4
   input logic [31:0] exu_i1_result_e4,


   input logic         ifu_i0_valid, ifu_i1_valid,    // fetch valids to instruction buffer
   input logic [31:0]  ifu_i0_instr, ifu_i1_instr,    // fetch inst's to instruction buffer
   input logic [31:1]  ifu_i0_pc, ifu_i1_pc,          // pc's for instruction buffer
   input logic         ifu_i0_pc4, ifu_i1_pc4,        // indication of 4B or 2B for corresponding inst
   input logic  [31:1] exu_i0_pc_e1,                  // pc's for e1 from the alu's
   input logic  [31:1] exu_i1_pc_e1,

   input logic mexintpend,                            // External interrupt pending
   input logic timer_int,                             // Timer interrupt pending (from pin)

   input logic [7:0] pic_claimid,                     // PIC claimid
   input logic [3:0] pic_pl,                          // PIC priv level
   input logic       mhwakeup,                        // High priority wakeup

   output logic [3:0] dec_tlu_meicurpl,               // to PIC, Current priv level
   output logic [3:0] dec_tlu_meipt,                  // to PIC

`ifdef RV_ICACHE_ECC
   input logic [41:0] ifu_ic_debug_rd_data,           // diagnostic icache read data
`else
   input logic [33:0] ifu_ic_debug_rd_data,           // diagnostic icache read data
`endif
   input logic ifu_ic_debug_rd_data_valid,            // diagnostic icache read data valid
   output cache_debug_pkt_t dec_tlu_ic_diag_pkt,      // packet of DICAWICS, DICAD0/1, DICAGO info for icache diagnostics


// Debug start
   input logic dbg_halt_req,                 // DM requests a halt
   input logic dbg_resume_req,               // DM requests a resume
   input logic ifu_miss_state_idle,          // I-side miss buffer empty

  output logic dec_tlu_flush_noredir_wb ,    // Tell fetch to idle on this flush
   output logic dec_tlu_mpc_halted_only, // Core is halted only due to MPC
   output logic dec_tlu_dbg_halted,          // Core is halted and ready for debug command
   output logic dec_tlu_pmu_fw_halted,       // Core is halted due to Power management unit or firmware halt
   output logic dec_tlu_debug_mode,          // Core is in debug mode
   output logic dec_tlu_resume_ack,          // Resume acknowledge
   output logic dec_tlu_flush_leak_one_wb,   // single step
   output logic dec_tlu_flush_err_wb,        // iside perr/ecc rfpc
   output logic dec_tlu_stall_dma,           // stall dma access when there's a halt request

   output logic dec_debug_wdata_rs1_d,       // insert debug write data into rs1 at decode

   output logic [31:0] dec_dbg_rddata,       // debug command read data

   output logic dec_dbg_cmd_done,            // abstract command is done
   output logic dec_dbg_cmd_fail,            // abstract command failed (illegal reg address)

   output trigger_pkt_t  [3:0] trigger_pkt_any, // info needed by debug trigger blocks

// Debug end
   // branch info from pipe0 for errors or counter updates
   input logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i0_br_index_e4, // index
   input logic [1:0]  exu_i0_br_hist_e4,                             // history
   input logic [1:0]  exu_i0_br_bank_e4,                             // bank
   input logic        exu_i0_br_error_e4,                            // error
   input logic        exu_i0_br_start_error_e4,                      // start error
   input logic        exu_i0_br_valid_e4,                            // valid
   input logic        exu_i0_br_mp_e4,                               // mispredict
   input logic        exu_i0_br_middle_e4,                           // middle of bank
   input logic [`RV_BHT_GHR_RANGE]  exu_i0_br_fghr_e4,               // FGHR when predicted

   // branch info from pipe1 for errors or counter updates
   input logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i1_br_index_e4, // index
   input logic [1:0]  exu_i1_br_hist_e4,                             // history
   input logic [1:0]  exu_i1_br_bank_e4,                             // bank
   input logic        exu_i1_br_error_e4,                            // error
   input logic        exu_i1_br_start_error_e4,                      // start error
   input logic        exu_i1_br_valid_e4,                            // valid
   input logic        exu_i1_br_mp_e4,                               // mispredict
   input logic        exu_i1_br_middle_e4,                           // middle of bank
   input logic [`RV_BHT_GHR_RANGE]  exu_i1_br_fghr_e4,               // FGHR when predicted


`ifdef RV_BTB_48
   input logic [1:0]       exu_i1_br_way_e4,        // way hit or repl
   input logic [1:0]       exu_i0_br_way_e4,        // way hit or repl
`else
   input logic        exu_i1_br_way_e4,             // way hit or repl
   input logic        exu_i0_br_way_e4,             // way hit or repl
`endif

   output logic  [31:0] gpr_i0_rs1_d,               // gpr rs1 data
   output logic  [31:0] gpr_i0_rs2_d,               // gpr rs2 data
   output logic  [31:0] gpr_i1_rs1_d,
   output logic  [31:0] gpr_i1_rs2_d,

   output logic [31:0] dec_i0_immed_d,              // immediate data
   output logic [31:0] dec_i1_immed_d,

   output logic [12:1] dec_i0_br_immed_d,           // br immediate data
   output logic [12:1] dec_i1_br_immed_d,

   output        alu_pkt_t i0_ap,                   // alu packet
   output        alu_pkt_t i1_ap,

   output logic          dec_i0_alu_decode_d,       // alu schedule on primary alu
   output logic          dec_i1_alu_decode_d,

   output logic          dec_i0_select_pc_d,        // select pc onto rs1 for jal's
   output logic          dec_i1_select_pc_d,

   output logic [31:1] dec_i0_pc_d, dec_i1_pc_d,    // pc's at decode
   output logic         dec_i0_rs1_bypass_en_d,     // rs1 bypass enable
   output logic         dec_i0_rs2_bypass_en_d,     // rs2 bypass enable
   output logic         dec_i1_rs1_bypass_en_d,
   output logic         dec_i1_rs2_bypass_en_d,

   output logic [31:0] i0_rs1_bypass_data_d,       // rs1 bypass data
   output logic [31:0] i0_rs2_bypass_data_d,       // rs2 bypass data
   output logic [31:0] i1_rs1_bypass_data_d,
   output logic [31:0] i1_rs2_bypass_data_d,
   output logic         dec_ib3_valid_d,           // ib3 buffer valid
   output logic         dec_ib2_valid_d,           // ib2 buffer valid

   output lsu_pkt_t    lsu_p,                      // lsu packet
   output mul_pkt_t    mul_p,                      // mul packet
   output div_pkt_t    div_p,                      // div packet

   output logic [11:0] dec_lsu_offset_d,           // 12b offset for load/store addresses
   output logic        dec_i0_lsu_d,               // is load/store
   output logic        dec_i1_lsu_d,

   output logic        flush_final_e3,             // final flush
   output logic        i0_flush_final_e3,          // final flush from i0

   output logic        dec_csr_ren_d,              // csr read enable

   output logic        dec_tlu_cancel_e4,          // Cancel lsu op at DC4 due to future trigger hit

   output logic        dec_tlu_flush_lower_wb,     // tlu flush due to late mp, exception, rfpc, or int
   output logic [31:1] dec_tlu_flush_path_wb,      // tlu flush target
   output logic        dec_tlu_i0_kill_writeb_wb,  // I0 is flushed, don't writeback any results to arch state
   output logic        dec_tlu_i1_kill_writeb_wb,  // I1 is flushed, don't writeback any results to arch state
   output logic        dec_tlu_fence_i_wb,         // flush is a fence_i rfnpc, flush icache

   output logic        dec_i0_mul_d,               // chose which gpr value to use
   output logic        dec_i1_mul_d,
   output logic        dec_i0_div_d,               // chose which gpr value to use
   output logic        dec_i1_div_d,
   output logic        dec_i1_valid_e1,            // i1 valid at e1 stage
   output logic        dec_div_decode_e4,          // div at e4 stage
   output logic [31:1] pred_correct_npc_e2,        // npc if prediction is correct at e2 stage

   output logic        dec_i0_rs1_bypass_en_e3,    // rs1 bypass enable e3
   output logic        dec_i0_rs2_bypass_en_e3,    // rs2 bypass enable e3
   output logic        dec_i1_rs1_bypass_en_e3,
   output logic        dec_i1_rs2_bypass_en_e3,
   output logic [31:0] i0_rs1_bypass_data_e3,      // rs1 bypass data e3
   output logic [31:0] i0_rs2_bypass_data_e3,      // rs2 bypass data e3
   output logic [31:0] i1_rs1_bypass_data_e3,
   output logic [31:0] i1_rs2_bypass_data_e3,
   output logic        dec_i0_sec_decode_e3,       // secondary decode e3
   output logic        dec_i1_sec_decode_e3,
   output logic [31:1] dec_i0_pc_e3,               // pc at e3
   output logic [31:1] dec_i1_pc_e3,

   output logic        dec_i0_rs1_bypass_en_e2,    // rs1 bypass enable e2
   output logic        dec_i0_rs2_bypass_en_e2,    // rs2 bypass enable e2
   output logic        dec_i1_rs1_bypass_en_e2,
   output logic        dec_i1_rs2_bypass_en_e2,
   output logic [31:0] i0_rs1_bypass_data_e2,      // rs1 bypass data e2
   output logic [31:0] i0_rs2_bypass_data_e2,      // rs2 bypass data e2
   output logic [31:0] i1_rs1_bypass_data_e2,
   output logic [31:0] i1_rs2_bypass_data_e2,

   output br_tlu_pkt_t dec_tlu_br0_wb_pkt,         // slot 0 branch predictor update packet
   output br_tlu_pkt_t dec_tlu_br1_wb_pkt,         // slot 1 branch predictor update packet

   output logic [1:0] dec_tlu_perfcnt0,                  // toggles when perf counter 0 has an event inc
   output logic [1:0] dec_tlu_perfcnt1,                  // toggles when perf counter 1 has an event inc
   output logic [1:0] dec_tlu_perfcnt2,                  // toggles when perf counter 2 has an event inc
   output logic [1:0] dec_tlu_perfcnt3,                  // toggles when perf counter 3 has an event inc

   output predict_pkt_t  i0_predict_p_d,           // prediction packet to alus
   output predict_pkt_t  i1_predict_p_d,

   output logic dec_i0_lsu_decode_d,               // load/store decode

   output logic [31:0] i0_result_e4_eff,           // alu result e4
   output logic [31:0] i1_result_e4_eff,

   output   logic dec_tlu_i0_valid_e4,             // slot 0 instruction is valid at e4
   output   logic dec_tlu_i1_valid_e4,             // slot 1 instruction is valid at e4, implies i0_valid_e4

   output logic [31:0] i0_result_e2,               // i0 result data e2
   output logic [31:0] dec_tlu_mrac_ff,            // CSR for memory region control

   output logic [31:1] dec_tlu_i0_pc_e4,           // pc e4
   output logic [31:1] dec_tlu_i1_pc_e4,

   output logic [4:2] dec_i0_data_en,              // clock-gate control logic
   output logic [4:1] dec_i0_ctl_en,
   output logic [4:2] dec_i1_data_en,
   output logic [4:1] dec_i1_ctl_en,

   output logic       dec_nonblock_load_freeze_dc2,  // lsu must freeze nonblock load due to younger dependency in pipe

   input logic [15:0] ifu_i0_cinst,                  // 16b compressed instruction
   input logic [15:0] ifu_i1_cinst,

   output trace_pkt_t  trace_rv_trace_pkt,             // trace packet

   // feature disable from mfdc
   output logic  dec_tlu_sideeffect_posted_disable,    // disable posted writes to side-effect address
   output logic  dec_tlu_core_ecc_disable,           // disable core ECC
   output logic  dec_tlu_sec_alu_disable,            // disable secondary ALU
   output logic  dec_tlu_non_blocking_disable,       // disable non blocking loads
   output logic  dec_tlu_fast_div_disable,           // disable fast divider
   output logic  dec_tlu_bpred_disable,              // disable branch prediction
   output logic  dec_tlu_wb_coalescing_disable,      // disable writebuffer coalescing
   output logic  dec_tlu_ld_miss_byp_wb_disable,     // disable loads miss bypass write buffer
   output logic [2:0]  dec_tlu_dma_qos_prty,         // DMA QoS priority coming from MFDC [18:16]

   // clock gating overrides from mcgc
   output logic  dec_tlu_misc_clk_override,          // override misc clock domain gating
   output logic  dec_tlu_exu_clk_override,           // override exu clock domain gating
   output logic  dec_tlu_ifu_clk_override,           // override fetch clock domain gating
   output logic  dec_tlu_lsu_clk_override,           // override load/store clock domain gating
   output logic  dec_tlu_bus_clk_override,           // override bus clock domain gating
   output logic  dec_tlu_pic_clk_override,           // override PIC clock domain gating
   output logic  dec_tlu_dccm_clk_override,          // override DCCM clock domain gating
   output logic  dec_tlu_icm_clk_override,           // override ICCM clock domain gating

   input  logic        scan_mode

   );

   localparam GPR_BANKS = 1;
   localparam GPR_BANKS_LOG2 = (GPR_BANKS == 1) ? 1 : $clog2(GPR_BANKS);

   logic  dec_tlu_dec_clk_override; // to and from dec blocks
   logic  clk_override;

   logic               dec_ib1_valid_d;
   logic               dec_ib0_valid_d;

   logic [1:0]         dec_pmu_instr_decoded;
   logic               dec_pmu_decode_stall;
   logic               dec_pmu_presync_stall;
   logic               dec_pmu_postsync_stall;

   logic dec_tlu_wr_pause_wb;           // CSR write to pause reg is at WB.

   logic        dec_i0_rs1_en_d;
   logic        dec_i0_rs2_en_d;
   logic        dec_fence_pending; // tell TLU to stall DMA

   logic [4:0]  dec_i0_rs1_d;
   logic [4:0]  dec_i0_rs2_d;


   logic        dec_i1_rs1_en_d;
   logic        dec_i1_rs2_en_d;

   logic [4:0]  dec_i1_rs1_d;
   logic [4:0]  dec_i1_rs2_d;


   logic [31:0] dec_i0_instr_d, dec_i1_instr_d;

   logic  dec_tlu_pipelining_disable;
   logic  dec_tlu_dual_issue_disable;


   logic [4:0]  dec_i0_waddr_wb;
   logic        dec_i0_wen_wb;
   logic [31:0] dec_i0_wdata_wb;

   logic [4:0]  dec_i1_waddr_wb;
   logic        dec_i1_wen_wb;
   logic [31:0] dec_i1_wdata_wb;

   logic        dec_csr_wen_wb;      // csr write enable at wb
   logic [11:0] dec_csr_rdaddr_d;      // read address for csr
   logic [11:0] dec_csr_wraddr_wb;      // write address for csryes

   logic [31:0] dec_csr_wrdata_wb;    // csr write data at wb

   logic [31:0] dec_csr_rddata_d;    // csr read data at wb
   logic        dec_csr_legal_d;            // csr indicates legal operation

   logic        dec_csr_wen_unq_d;       // valid csr with write - for csr legal
   logic        dec_csr_any_unq_d;       // valid csr - for csr legal
   logic        dec_csr_stall_int_ff;    // csr is mie/mstatus



   trap_pkt_t dec_tlu_packet_e4;

   logic        dec_i0_pc4_d, dec_i1_pc4_d;
   logic        dec_tlu_presync_d;
   logic        dec_tlu_postsync_d;
   logic        dec_tlu_debug_stall;

   logic [31:0] dec_illegal_inst;


   // GPR Bank ID write signals
   logic                      wen_bank_id;
   logic [GPR_BANKS_LOG2-1:0] wr_bank_id;

   logic                      dec_i0_icaf_d;
   logic                      dec_i1_icaf_d;
   logic                      dec_i0_perr_d;
   logic                      dec_i1_perr_d;
   logic                      dec_i0_sbecc_d;
   logic                      dec_i1_sbecc_d;
   logic                      dec_i0_dbecc_d;
   logic                      dec_i1_dbecc_d;

   logic                      dec_i0_icaf_second_d;

   logic                      dec_i0_decode_d;
   logic                      dec_i1_decode_d;

   logic [3:0]                dec_i0_trigger_match_d;
   logic [3:0]                dec_i1_trigger_match_d;


   logic                      dec_debug_fence_d;

   logic                      dec_nonblock_load_wen;
   logic [4:0]                dec_nonblock_load_waddr;
   logic                      dec_tlu_flush_pause_wb;

   logic                      dec_i0_load_e4;

   logic                      dec_pause_state;

   br_pkt_t dec_i0_brp;
   br_pkt_t dec_i1_brp;

   assign clk_override = dec_tlu_dec_clk_override;


   assign dec_dbg_rddata[31:0] = dec_i0_wdata_wb[31:0];

   dec_ib_ctl instbuff (.*
                        );

   dec_decode_ctl decode (.*);

   dec_tlu_ctl tlu (.*);

   // Temp hookups
   assign wen_bank_id = '0;
   assign wr_bank_id  = '0;



   dec_gpr_ctl #(.GPR_BANKS(GPR_BANKS),
                 .GPR_BANKS_LOG2(GPR_BANKS_LOG2)) arf (.*,
                    // inputs
                    .raddr0(dec_i0_rs1_d[4:0]), .rden0(dec_i0_rs1_en_d),
                    .raddr1(dec_i0_rs2_d[4:0]), .rden1(dec_i0_rs2_en_d),
                    .raddr2(dec_i1_rs1_d[4:0]), .rden2(dec_i1_rs1_en_d),
                    .raddr3(dec_i1_rs2_d[4:0]), .rden3(dec_i1_rs2_en_d),

                    .waddr0(dec_i0_waddr_wb[4:0]),         .wen0(dec_i0_wen_wb),         .wd0(dec_i0_wdata_wb[31:0]),
                    .waddr1(dec_i1_waddr_wb[4:0]),         .wen1(dec_i1_wen_wb),         .wd1(dec_i1_wdata_wb[31:0]),
                    .waddr2(dec_nonblock_load_waddr[4:0]), .wen2(dec_nonblock_load_wen), .wd2(lsu_nonblock_load_data[31:0]),

                    // outputs
                    .rd0(gpr_i0_rs1_d[31:0]), .rd1(gpr_i0_rs2_d[31:0]),
                    .rd2(gpr_i1_rs1_d[31:0]), .rd3(gpr_i1_rs2_d[31:0])
                    );

// Trigger

   dec_trigger dec_trigger (.*);





// trace
   logic [15:0] dec_i0_cinst_d;
   logic [15:0] dec_i1_cinst_d;
   logic [31:0]               dec_i0_inst_wb1;
   logic [31:0]               dec_i1_inst_wb1;
   logic [31:1]               dec_i0_pc_wb1;
   logic [31:1]               dec_i1_pc_wb1;
   logic dec_tlu_i1_valid_wb1, dec_tlu_i0_valid_wb1,  dec_tlu_int_valid_wb1;
   logic [4:0] dec_tlu_exc_cause_wb1;
   logic [31:0] dec_tlu_mtval_wb1;

   logic        dec_tlu_i0_exc_valid_wb1, dec_tlu_i1_exc_valid_wb1;

   // also need retires_p==3

   assign trace_rv_trace_pkt.trace_rv_i_insn_ip    = { 32'b0, dec_i1_inst_wb1[31:0], dec_i0_inst_wb1[31:0] };
   assign trace_rv_trace_pkt.trace_rv_i_address_ip = { 32'b0, dec_i1_pc_wb1[31:1], 1'b0, dec_i0_pc_wb1[31:1], 1'b0 };

   assign trace_rv_trace_pkt.trace_rv_i_valid_ip =     {dec_tlu_int_valid_wb1,   // always int
                                                    dec_tlu_i1_valid_wb1 | dec_tlu_i1_exc_valid_wb1,  // not interrupts
                                                    dec_tlu_i0_valid_wb1 | dec_tlu_i0_exc_valid_wb1
                                                    };
   assign trace_rv_trace_pkt.trace_rv_i_exception_ip = {dec_tlu_int_valid_wb1, dec_tlu_i1_exc_valid_wb1, dec_tlu_i0_exc_valid_wb1};
   assign trace_rv_trace_pkt.trace_rv_i_ecause_ip =     dec_tlu_exc_cause_wb1[4:0];  // replicate across ports
   assign trace_rv_trace_pkt.trace_rv_i_interrupt_ip = {dec_tlu_int_valid_wb1,2'b0};
   assign trace_rv_trace_pkt.trace_rv_i_tval_ip =    dec_tlu_mtval_wb1[31:0];        // replicate across ports



// end trace

endmodule // dec

