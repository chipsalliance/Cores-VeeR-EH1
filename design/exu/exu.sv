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


module exu
   import swerv_types::*;
(

   input logic clk,                                                    // Top level clock
   input logic active_clk,                                             // Level 1 active clock
   input logic clk_override,                                           // Override multiply clock enables
   input logic rst_l,                                                  // Reset
   input logic scan_mode,                                              // Scan control
   input logic lsu_freeze_dc3,                                         // Freeze pipe from D to DC3

   input logic  dec_tlu_fast_div_disable,                              // Disable divide small number optimization

   input logic [4:2] dec_i0_data_en,                                   // Slot I0 clock enable {e1, e2, e3    }, one cycle pulse
   input logic [4:1] dec_i0_ctl_en,                                    // Slot I0 clock enable {e1, e2, e3, e4}, two cycle pulse
   input logic [4:2] dec_i1_data_en,                                   // Slot I1 clock enable {e1, e2, e3    }, one cycle pulse
   input logic [4:1] dec_i1_ctl_en,                                    // Slot I1 clock enable {e1, e2, e3, e4}, two cycle pulse

   input logic dec_debug_wdata_rs1_d,                                  // Debug select to primary I0 RS1

   input logic [31:0] dbg_cmd_wrdata,                                  // Debug data   to primary I0 RS1

   input logic [31:0] lsu_result_dc3,                                  // Load result

   input predict_pkt_t  i0_predict_p_d,                                // DEC branch predict packet
   input predict_pkt_t  i1_predict_p_d,                                // DEC branch predict packet

   input logic        dec_i0_rs1_bypass_en_e2,                         // DEC bypass bus select for E2 stage
   input logic        dec_i0_rs2_bypass_en_e2,                         // DEC bypass bus select for E2 stage
   input logic        dec_i1_rs1_bypass_en_e2,                         // DEC bypass bus select for E2 stage
   input logic        dec_i1_rs2_bypass_en_e2,                         // DEC bypass bus select for E2 stage
   input logic [31:0] i0_rs1_bypass_data_e2,                           // DEC bypass bus
   input logic [31:0] i0_rs2_bypass_data_e2,                           // DEC bypass bus
   input logic [31:0] i1_rs1_bypass_data_e2,                           // DEC bypass bus
   input logic [31:0] i1_rs2_bypass_data_e2,                           // DEC bypass bus

   input logic        dec_i0_rs1_bypass_en_e3,                         // DEC bypass bus select for E3 stage
   input logic        dec_i0_rs2_bypass_en_e3,                         // DEC bypass bus select for E3 stage
   input logic        dec_i1_rs1_bypass_en_e3,                         // DEC bypass bus select for E3 stage
   input logic        dec_i1_rs2_bypass_en_e3,                         // DEC bypass bus select for E3 stage
   input logic [31:0] i0_rs1_bypass_data_e3,                           // DEC bypass bus
   input logic [31:0] i0_rs2_bypass_data_e3,                           // DEC bypass bus
   input logic [31:0] i1_rs1_bypass_data_e3,                           // DEC bypass bus
   input logic [31:0] i1_rs2_bypass_data_e3,                           // DEC bypass bus

   input logic        dec_i0_sec_decode_e3,                            // Secondary ALU valid
   input logic        dec_i1_sec_decode_e3,                            // Secondary ALU valid
   input logic [31:1] dec_i0_pc_e3,                                    // Secondary ALU PC
   input logic [31:1] dec_i1_pc_e3,                                    // Secondary ALU PC

   input logic [31:1] pred_correct_npc_e2,                             // DEC NPC for correctly predicted branch

   input logic        dec_i1_valid_e1,                                 // I1 valid E1

   input logic        dec_i0_mul_d,                                    // Select for Multiply GPR value
   input logic        dec_i1_mul_d,                                    // Select for Multiply GPR value

   input logic        dec_i0_div_d,                                    // Select for Divide GPR value
   input logic        dec_i1_div_d,                                    // Select for Divide GPR value

   input logic [31:0] gpr_i0_rs1_d,                                    // DEC data gpr
   input logic [31:0] gpr_i0_rs2_d,                                    // DEC data gpr
   input logic [31:0] dec_i0_immed_d,                                  // DEC data immediate

   input logic [31:0] gpr_i1_rs1_d,                                    // DEC data gpr
   input logic [31:0] gpr_i1_rs2_d,                                    // DEC data gpr
   input logic [31:0] dec_i1_immed_d,                                  // DEC data immediate

   input logic [31:0] i0_rs1_bypass_data_d,                            // DEC bypass data
   input logic [31:0] i0_rs2_bypass_data_d,                            // DEC bypass data
   input logic [31:0] i1_rs1_bypass_data_d,                            // DEC bypass data
   input logic [31:0] i1_rs2_bypass_data_d,                            // DEC bypass data

   input logic [12:1] dec_i0_br_immed_d,                               // Branch immediate
   input logic [12:1] dec_i1_br_immed_d,                               // Branch immediate

   input         alu_pkt_t i0_ap,                                      // DEC alu {valid,predecodes}
   input         alu_pkt_t i1_ap,                                      // DEC alu {valid,predecodes}

   input logic   dec_i0_alu_decode_d,                                  // Valid to Primary ALU
   input logic   dec_i1_alu_decode_d,                                  // Valid to Primary ALU

   input logic   dec_i0_select_pc_d,                                   // PC select to RS1
   input logic   dec_i1_select_pc_d,                                   // PC select to RS1

   input logic [31:1] dec_i0_pc_d, dec_i1_pc_d,                        // Instruction PC

   input logic  dec_i0_rs1_bypass_en_d,                                // DEC bypass select
   input logic  dec_i0_rs2_bypass_en_d,                                // DEC bypass select
   input logic  dec_i1_rs1_bypass_en_d,                                // DEC bypass select
   input logic  dec_i1_rs2_bypass_en_d,                                // DEC bypass select

   input logic        dec_tlu_flush_lower_wb,                          // Flush divide and secondary ALUs
   input logic [31:1] dec_tlu_flush_path_wb,                           // Redirect target

   input logic dec_tlu_i0_valid_e4,                                    // Valid for GHR
   input logic dec_tlu_i1_valid_e4,                                    // Valid for GHR

   output logic [31:0] exu_i0_result_e1,                               // Primary ALU result to DEC
   output logic [31:0] exu_i1_result_e1,                               // Primary ALU result to DEC
   output logic [31:1] exu_i0_pc_e1,                                   // Primary PC  result to DEC
   output logic [31:1] exu_i1_pc_e1,                                   // Primary PC  result to DEC


   output logic [31:0] exu_i0_result_e4,                               // Secondary ALU result
   output logic [31:0] exu_i1_result_e4,                               // Secondary ALU result


   output logic        exu_i0_flush_final,                             // I0 flush to DEC
   output logic        exu_i1_flush_final,                             // I1 flush to DEC



   input mul_pkt_t  mul_p,                                             // DEC {valid, operand signs, low, operand bypass}

   input div_pkt_t  div_p,                                             // DEC {valid, unsigned, rem}

   input logic   dec_i0_lsu_d,                                         // Bypass control for LSU operand bus
   input logic   dec_i1_lsu_d,                                         // Bypass control for LSU operand bus

   input logic   dec_csr_ren_d,                                        // Clear I0 RS1 primary

   output logic [31:0] exu_lsu_rs1_d,                                  // LSU operand
   output logic [31:0] exu_lsu_rs2_d,                                  // LSU operand

   output logic [31:0] exu_csr_rs1_e1,                                 // RS1 source for a CSR instruction

   output logic         exu_flush_final,                               // Pipe is being flushed this cycle
   output logic [31:1]  exu_flush_path_final,                          // Target for the oldest flush source

   output logic [31:0] exu_mul_result_e3,                              // Multiply result

   output logic [31:0]  exu_div_result,                                // Divide result
   output logic exu_div_finish,                                        // Divide is finished
   output logic exu_div_stall,                                         // Divide is running
   output logic [31:1] exu_npc_e4,                                     // Divide NPC

   output logic exu_i0_flush_lower_e4,                                 // to TLU - lower branch flush
   output logic exu_i1_flush_lower_e4,                                 // to TLU - lower branch flush
   output logic [31:1] exu_i0_flush_path_e4,                           // to TLU - lower branch flush path
   output logic [31:1] exu_i1_flush_path_e4,                           // to TLU - lower branch flush path

   output predict_pkt_t exu_mp_pkt,                                    // Mispredict branch packet

   output logic [`RV_BHT_GHR_RANGE]  exu_mp_eghr,                      // Mispredict global history

   output logic [1:0]  exu_i0_br_hist_e4,                              // to DEC  I0 branch history
   output logic [1:0]  exu_i0_br_bank_e4,                              // to DEC  I0 branch bank
   output logic        exu_i0_br_error_e4,                             // to DEC  I0 branch error
   output logic        exu_i0_br_start_error_e4,                       // to DEC  I0 branch start error
   output logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i0_br_index_e4,  // to DEC  I0 branch index
   output logic        exu_i0_br_valid_e4,                             // to DEC  I0 branch valid
   output logic        exu_i0_br_mp_e4,                                // to DEC  I0 branch mispredict
`ifdef RV_BTB_48
   output logic [1:0]  exu_i0_br_way_e4,                               // to DEC  I0 branch way
`else
   output logic        exu_i0_br_way_e4,                               // to DEC  I0 branch way
`endif
   output logic        exu_i0_br_middle_e4,                            // to DEC  I0 branch middle
   output logic [`RV_BHT_GHR_RANGE]  exu_i0_br_fghr_e4,                // to DEC  I0 branch fghr
   output logic        exu_i0_br_ret_e4,                               // to DEC  I0 branch return
   output logic        exu_i0_br_call_e4,                              // to DEC  I0 branch call

   output logic [1:0]  exu_i1_br_hist_e4,                              // to DEC  I1 branch history
   output logic [1:0]  exu_i1_br_bank_e4,                              // to DEC  I1 branch bank
   output logic        exu_i1_br_error_e4,                             // to DEC  I1 branch error
   output logic        exu_i1_br_start_error_e4,                       // to DEC  I1 branch start error
   output logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i1_br_index_e4,  // to DEC  I1 branch index
   output logic        exu_i1_br_valid_e4,                             // to DEC  I1 branch valid
   output logic        exu_i1_br_mp_e4,                                // to DEC  I1 branch mispredict
`ifdef RV_BTB_48
   output logic [1:0]  exu_i1_br_way_e4,                               // to DEC  I1 branch way
`else
   output logic        exu_i1_br_way_e4,                               // to DEC  I1 branch way
`endif
   output logic        exu_i1_br_middle_e4,                            // to DEC  I1 branch middle
   output logic [`RV_BHT_GHR_RANGE]  exu_i1_br_fghr_e4,                // to DEC  I1 branch fghr
   output logic        exu_i1_br_ret_e4,                               // to DEC  I1 branch return
   output logic        exu_i1_br_call_e4,                              // to DEC  I1 branch call
   output logic        exu_flush_upper_e2,                             // flush upper, either i0 or i1

   output rets_pkt_t exu_rets_e1_pkt,                                  // to IFU - I0+I1 {call, return, pc}
   output rets_pkt_t exu_rets_e4_pkt,                                  // to IFU - I0+I1 {call, return, pc}

   output logic exu_pmu_i0_br_misp,                                    // to PMU - I0 E4 branch mispredict
   output logic exu_pmu_i0_br_ataken,                                  // to PMU - I0 E4 taken
   output logic exu_pmu_i0_pc4,                                        // to PMU - I0 E4 PC
   output logic exu_pmu_i1_br_misp,                                    // to PMU - I1 E4 branch mispredict
   output logic exu_pmu_i1_br_ataken,                                  // to PMU - I1 E4 taken
   output logic exu_pmu_i1_pc4                                         // to PMU - I1 E4 PC

   );


   logic [31:0] i0_rs1_d,i0_rs2_d,i1_rs1_d,i1_rs2_d;



   logic        exu_i0_flush_upper_e1;
   logic [31:1] exu_i0_flush_path_e1;

   logic        exu_i1_flush_upper_e1;
   logic [31:1] exu_i1_flush_path_e1;

   logic [31:0] i0_rs1_final_d;

   logic [31:1]  exu_flush_path_e2;
   logic [31:0]  mul_rs1_d, mul_rs2_d;

   logic [31:0]  div_rs1_d, div_rs2_d;

   logic        i1_valid_e2;
   logic [31:1] npc_e4;
   logic [31:1] div_npc;

   logic [31:0] i0_rs1_e1, i0_rs2_e1;
   logic [31:0] i0_rs1_e2, i0_rs2_e2;
   logic [31:0] i0_rs1_e3, i0_rs2_e3;
   logic [12:1] i0_br_immed_e1, i0_br_immed_e2, i0_br_immed_e3;

   logic [31:0] i1_rs1_e1, i1_rs2_e1;
   logic [31:0] i1_rs1_e2, i1_rs2_e2;
   logic [31:0] i1_rs1_e3, i1_rs2_e3;

   logic [12:1] i1_br_immed_e1, i1_br_immed_e2, i1_br_immed_e3;

   logic [31:0] i0_rs1_e2_final, i0_rs2_e2_final;
   logic [31:0] i1_rs1_e2_final, i1_rs2_e2_final;
   logic [31:0] i0_rs1_e3_final, i0_rs2_e3_final;
   logic [31:0] i1_rs1_e3_final, i1_rs2_e3_final;
   logic [31:1] i0_alu_pc_nc, i1_alu_pc_nc;
   logic [31:1] exu_flush_path_e1;
   logic        exu_i0_flush_upper_e2, exu_i1_flush_upper_e2;
   logic        i1_valid_e3, i1_valid_e4;
   logic [31:1] pred_correct_npc_e3, pred_correct_npc_e4;
   logic                                  exu_i0_flush_upper_e3;
   logic                                  exu_i0_flush_upper_e4;
   logic        i1_pred_correct_upper_e1, i0_pred_correct_upper_e1;
   logic        i1_pred_correct_upper_e2, i0_pred_correct_upper_e2;
   logic        i1_pred_correct_upper_e3, i0_pred_correct_upper_e3;
   logic        i1_pred_correct_upper_e4, i0_pred_correct_upper_e4;
   logic        i1_pred_correct_lower_e4, i0_pred_correct_lower_e4;


   logic        i1_valid_e4_eff;
   logic        i1_sec_decode_e4, i0_sec_decode_e4;
   logic        i1_pred_correct_e4_eff, i0_pred_correct_e4_eff;
   logic [31:1] i1_flush_path_e4_eff, i0_flush_path_e4_eff;
   logic [31:0] csr_rs1_in_d;
   logic [31:1] i1_flush_path_upper_e2, i0_flush_path_upper_e2;
   logic [31:1] i1_flush_path_upper_e3, i0_flush_path_upper_e3;
   logic [31:1] i1_flush_path_upper_e4, i0_flush_path_upper_e4;

   logic        div_valid_e1;
   logic        div_finish_early;
   logic        freeze;


   alu_pkt_t i0_ap_e1, i0_ap_e2, i0_ap_e3, i0_ap_e4;
   alu_pkt_t i1_ap_e1, i1_ap_e2, i1_ap_e3, i1_ap_e4;
   assign freeze = lsu_freeze_dc3;

   assign i0_rs1_d[31:0] = ({32{~dec_i0_rs1_bypass_en_d}} & ((dec_debug_wdata_rs1_d) ? dbg_cmd_wrdata[31:0] : gpr_i0_rs1_d[31:0])) |
                           ({32{~dec_i0_rs1_bypass_en_d   & dec_i0_select_pc_d}} & { dec_i0_pc_d[31:1], 1'b0}) |    // for jal's
                           ({32{ dec_i0_rs1_bypass_en_d}} & i0_rs1_bypass_data_d[31:0]);


   assign i0_rs1_final_d[31:0] = ({32{~dec_csr_ren_d}} & i0_rs1_d[31:0]);

   assign i0_rs2_d[31:0]       = ({32{~dec_i0_rs2_bypass_en_d}} & gpr_i0_rs2_d[31:0]) |
                                 ({32{~dec_i0_rs2_bypass_en_d}} & dec_i0_immed_d[31:0]) |
                                 ({32{ dec_i0_rs2_bypass_en_d}} & i0_rs2_bypass_data_d[31:0]);

   assign i1_rs1_d[31:0]       = ({32{~dec_i1_rs1_bypass_en_d}} & gpr_i1_rs1_d[31:0]) |
                                 ({32{~dec_i1_rs1_bypass_en_d   & dec_i1_select_pc_d}} & { dec_i1_pc_d[31:1], 1'b0}) |  // pc orthogonal with rs1
                                 ({32{ dec_i1_rs1_bypass_en_d}} & i1_rs1_bypass_data_d[31:0]);

   assign i1_rs2_d[31:0]       = ({32{~dec_i1_rs2_bypass_en_d}} & gpr_i1_rs2_d[31:0]) |
                                 ({32{~dec_i1_rs2_bypass_en_d}} & dec_i1_immed_d[31:0]) |
                                 ({32{ dec_i1_rs2_bypass_en_d}} & i1_rs2_bypass_data_d[31:0]);

   assign exu_lsu_rs1_d[31:0]  = ({32{ ~dec_i0_rs1_bypass_en_d &  dec_i0_lsu_d               }} & gpr_i0_rs1_d[31:0]        ) |
                                 ({32{ ~dec_i1_rs1_bypass_en_d & ~dec_i0_lsu_d & dec_i1_lsu_d}} & gpr_i1_rs1_d[31:0]        ) |
                                 ({32{  dec_i0_rs1_bypass_en_d &  dec_i0_lsu_d               }} & i0_rs1_bypass_data_d[31:0]) |
                                 ({32{  dec_i1_rs1_bypass_en_d & ~dec_i0_lsu_d & dec_i1_lsu_d}} & i1_rs1_bypass_data_d[31:0]);

   assign exu_lsu_rs2_d[31:0]  = ({32{ ~dec_i0_rs2_bypass_en_d &  dec_i0_lsu_d               }} & gpr_i0_rs2_d[31:0]        ) |
                                 ({32{ ~dec_i1_rs2_bypass_en_d & ~dec_i0_lsu_d & dec_i1_lsu_d}} & gpr_i1_rs2_d[31:0]        ) |
                                 ({32{  dec_i0_rs2_bypass_en_d &  dec_i0_lsu_d               }} & i0_rs2_bypass_data_d[31:0]) |
                                 ({32{  dec_i1_rs2_bypass_en_d & ~dec_i0_lsu_d & dec_i1_lsu_d}} & i1_rs2_bypass_data_d[31:0]);

   assign mul_rs1_d[31:0]      = ({32{ ~dec_i0_rs1_bypass_en_d &  dec_i0_mul_d               }} & gpr_i0_rs1_d[31:0]        ) |
                                 ({32{ ~dec_i1_rs1_bypass_en_d & ~dec_i0_mul_d & dec_i1_mul_d}} & gpr_i1_rs1_d[31:0]        ) |
                                 ({32{  dec_i0_rs1_bypass_en_d &  dec_i0_mul_d               }} & i0_rs1_bypass_data_d[31:0]) |
                                 ({32{  dec_i1_rs1_bypass_en_d & ~dec_i0_mul_d & dec_i1_mul_d}} & i1_rs1_bypass_data_d[31:0]);

   assign mul_rs2_d[31:0]      = ({32{ ~dec_i0_rs2_bypass_en_d &  dec_i0_mul_d               }} & gpr_i0_rs2_d[31:0]        ) |
                                 ({32{ ~dec_i1_rs2_bypass_en_d & ~dec_i0_mul_d & dec_i1_mul_d}} & gpr_i1_rs2_d[31:0]        ) |
                                 ({32{  dec_i0_rs2_bypass_en_d &  dec_i0_mul_d               }} & i0_rs2_bypass_data_d[31:0]) |
                                 ({32{  dec_i1_rs2_bypass_en_d & ~dec_i0_mul_d & dec_i1_mul_d}} & i1_rs2_bypass_data_d[31:0]);



   assign div_rs1_d[31:0]      = ({32{ ~dec_i0_rs1_bypass_en_d &  dec_i0_div_d               }} & gpr_i0_rs1_d[31:0]) |
                                 ({32{ ~dec_i1_rs1_bypass_en_d & ~dec_i0_div_d & dec_i1_div_d}} & gpr_i1_rs1_d[31:0]) |
                                 ({32{  dec_i0_rs1_bypass_en_d &  dec_i0_div_d               }} & i0_rs1_bypass_data_d[31:0]) |
                                 ({32{  dec_i1_rs1_bypass_en_d & ~dec_i0_div_d & dec_i1_div_d}} & i1_rs1_bypass_data_d[31:0]);

   assign div_rs2_d[31:0]      = ({32{ ~dec_i0_rs2_bypass_en_d &  dec_i0_div_d               }} & gpr_i0_rs2_d[31:0]) |
                                 ({32{ ~dec_i1_rs2_bypass_en_d & ~dec_i0_div_d & dec_i1_div_d}} & gpr_i1_rs2_d[31:0]) |
                                 ({32{  dec_i0_rs2_bypass_en_d &  dec_i0_div_d               }} & i0_rs2_bypass_data_d[31:0]) |
                                 ({32{  dec_i1_rs2_bypass_en_d & ~dec_i0_div_d & dec_i1_div_d}} & i1_rs2_bypass_data_d[31:0]);


   assign csr_rs1_in_d[31:0] = (dec_csr_ren_d) ? i0_rs1_d[31:0] : exu_csr_rs1_e1[31:0];

   logic       i0_e1_data_en, i0_e2_data_en, i0_e3_data_en;
   logic       i0_e1_ctl_en,  i0_e2_ctl_en,  i0_e3_ctl_en,  i0_e4_ctl_en;

   assign {i0_e1_data_en, i0_e2_data_en, i0_e3_data_en }                = dec_i0_data_en[4:2];
   assign {i0_e1_ctl_en,  i0_e2_ctl_en,  i0_e3_ctl_en,  i0_e4_ctl_en }  = dec_i0_ctl_en[4:1];

   logic       i1_e1_data_en, i1_e2_data_en, i1_e3_data_en;
   logic       i1_e1_ctl_en,  i1_e2_ctl_en,  i1_e3_ctl_en,  i1_e4_ctl_en;

   assign {i1_e1_data_en, i1_e2_data_en, i1_e3_data_en}                = dec_i1_data_en[4:2];
   assign {i1_e1_ctl_en,  i1_e2_ctl_en,  i1_e3_ctl_en,  i1_e4_ctl_en}  = dec_i1_ctl_en[4:1];




   rvdffe #(32) csr_rs1_ff (.*, .en(i0_e1_data_en), .din(csr_rs1_in_d[31:0]), .dout(exu_csr_rs1_e1[31:0]));


   exu_mul_ctl mul_e1    (.*,
                          .clk_override  ( clk_override                ),   // I
                          .freeze        ( freeze                      ),   // I
                          .mp            ( mul_p                       ),   // I
                          .a             ( mul_rs1_d[31:0]             ),   // I
                          .b             ( mul_rs2_d[31:0]             ),   // I
                          .out           ( exu_mul_result_e3[31:0]     ));  // O


   exu_div_ctl div_e1    (.*,
                          .flush_lower   ( dec_tlu_flush_lower_wb      ),   // I
                          .dp            ( div_p                       ),   // I
                          .dividend      ( div_rs1_d[31:0]             ),   // I
                          .divisor       ( div_rs2_d[31:0]             ),   // I
                          .valid_ff_e1   ( div_valid_e1                ),   // O
                          .div_stall     ( exu_div_stall               ),   // O
                          .finish_early  ( div_finish_early            ),   // O
                          .finish        ( exu_div_finish              ),   // O
                          .out           ( exu_div_result[31:0]        ));  // O


   predict_pkt_t i0_predict_newp_d, i1_predict_newp_d;

   always_comb begin
      i0_predict_newp_d = i0_predict_p_d;
      i0_predict_newp_d.boffset = dec_i0_pc_d[1];  // from the start of inst

      i0_predict_newp_d.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = i0_predict_p_d.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]; // from the end of inst
      i0_predict_newp_d.bank[1:0] = i0_predict_p_d.bank[1:0];

      i1_predict_newp_d = i1_predict_p_d;
      i1_predict_newp_d.boffset = dec_i1_pc_d[1];

      i1_predict_newp_d.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = i1_predict_p_d.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
      i1_predict_newp_d.bank[1:0] = i1_predict_p_d.bank[1:0];

   end


   predict_pkt_t i0_predict_p_e1, i0_predict_p_e4;
   predict_pkt_t i1_predict_p_e1, i1_predict_p_e4;

   assign exu_pmu_i0_br_misp   = i0_predict_p_e4.misp   & ~exu_div_finish;  // qual with divide
   assign exu_pmu_i0_br_ataken = i0_predict_p_e4.ataken & ~exu_div_finish;  // qual with divide
   assign exu_pmu_i0_pc4       = i0_predict_p_e4.pc4 | exu_div_finish;      // divides are always 4B
   assign exu_pmu_i1_br_misp   = i1_predict_p_e4.misp;
   assign exu_pmu_i1_br_ataken = i1_predict_p_e4.ataken;
   assign exu_pmu_i1_pc4       = i1_predict_p_e4.pc4;


   exu_alu_ctl i0_alu_e1 (.*,
                          .freeze        ( freeze                      ),   // I
                          .enable        ( i0_e1_ctl_en                ),   // I
                          .predict_p     ( i0_predict_newp_d           ),   // I
                          .valid         ( dec_i0_alu_decode_d         ),   // I
                          .flush         ( exu_flush_final             ),   // I
                          .a             ( i0_rs1_final_d[31:0]        ),   // I
                          .b             ( i0_rs2_d[31:0]              ),   // I
                          .pc            ( dec_i0_pc_d[31:1]           ),   // I
                          .brimm         ( dec_i0_br_immed_d[12:1]     ),   // I
                          .ap            ( i0_ap_e1                    ),   // I
                          .out           ( exu_i0_result_e1[31:0]      ),   // O
                          .flush_upper   ( exu_i0_flush_upper_e1       ),   // O : will be 0 if freeze this cycle
                          .flush_path    ( exu_i0_flush_path_e1[31:1]  ),   // O
                          .predict_p_ff  ( i0_predict_p_e1             ),   // O
                          .pc_ff         ( exu_i0_pc_e1[31:1]          ),   // O
                          .pred_correct  ( i0_pred_correct_upper_e1    )    // O
                          );


   exu_alu_ctl i1_alu_e1 (.*,
                          .freeze        ( freeze                      ),   // I
                          .enable        ( i1_e1_ctl_en                ),   // I
                          .predict_p     ( i1_predict_newp_d           ),   // I
                          .valid         ( dec_i1_alu_decode_d         ),   // I
                          .flush         ( exu_flush_final             ),   // I
                          .a             ( i1_rs1_d[31:0]              ),   // I
                          .b             ( i1_rs2_d[31:0]              ),   // I
                          .pc            ( dec_i1_pc_d[31:1]           ),   // I
                          .brimm         ( dec_i1_br_immed_d[12:1]     ),   // I
                          .ap            ( i1_ap_e1                    ),   // I
                          .out           ( exu_i1_result_e1[31:0]      ),   // O
                          .flush_upper   ( exu_i1_flush_upper_e1       ),   // O : will be 0 if freeze this cycle
                          .flush_path    ( exu_i1_flush_path_e1[31:1]  ),   // O
                          .predict_p_ff  ( i1_predict_p_e1             ),   // O
                          .pc_ff         ( exu_i1_pc_e1[31:1]          ),   // O
                          .pred_correct  ( i1_pred_correct_upper_e1    )    // O
                          );

   predict_pkt_t i0_pp_e2, i0_pp_e3, i0_pp_e4_in;

   rvdffe #($bits(predict_pkt_t)) i0_pp_e2_ff (.*, .en(i0_e2_ctl_en), .din(i0_predict_p_e1),.dout(i0_pp_e2) );
   rvdffe #($bits(predict_pkt_t)) i0_pp_e3_ff (.*, .en(i0_e3_ctl_en), .din(i0_pp_e2),.dout(i0_pp_e3) );

   predict_pkt_t i1_pp_e2, i1_pp_e3, i1_pp_e4_in;

   rvdffe #($bits(predict_pkt_t)) i1_pp_e2_ff (.*, .en(i1_e2_ctl_en), .din(i1_predict_p_e1),.dout(i1_pp_e2) );
   rvdffe #($bits(predict_pkt_t)) i1_pp_e3_ff (.*, .en(i1_e3_ctl_en), .din(i1_pp_e2),.dout(i1_pp_e3) );

   // set the predict_pkt to 0's if freeze, goes to secondary alu's
   assign i0_pp_e4_in = (freeze) ? '0 : i0_pp_e3;
   assign i1_pp_e4_in = (freeze) ? '0 : i1_pp_e3;

   rvdffe #($bits(alu_pkt_t)) i0_ap_e1_ff (.*,  .en(i0_e1_ctl_en), .din(i0_ap),   .dout(i0_ap_e1) );
   rvdffe #($bits(alu_pkt_t)) i0_ap_e2_ff (.*,  .en(i0_e2_ctl_en), .din(i0_ap_e1),.dout(i0_ap_e2) );
   rvdffe #($bits(alu_pkt_t)) i0_ap_e3_ff (.*,  .en(i0_e3_ctl_en), .din(i0_ap_e2),.dout(i0_ap_e3) );
   rvdffe #($bits(alu_pkt_t)) i0_ap_e4_ff (.*,  .en(i0_e4_ctl_en), .din(i0_ap_e3),.dout(i0_ap_e4) );


   rvdffe #($bits(alu_pkt_t)) i1_ap_e1_ff (.*,  .en(i1_e1_ctl_en), .din(i1_ap),   .dout(i1_ap_e1) );
   rvdffe #($bits(alu_pkt_t)) i1_ap_e2_ff (.*,  .en(i1_e2_ctl_en), .din(i1_ap_e1),.dout(i1_ap_e2) );
   rvdffe #($bits(alu_pkt_t)) i1_ap_e3_ff (.*,  .en(i1_e3_ctl_en), .din(i1_ap_e2),.dout(i1_ap_e3) );
   rvdffe #($bits(alu_pkt_t)) i1_ap_e4_ff (.*,  .en(i1_e4_ctl_en), .din(i1_ap_e3),.dout(i1_ap_e4) );

   assign exu_rets_e1_pkt.pc0_call = i0_predict_p_e1.pcall & i0_predict_p_e1.valid & ~i0_predict_p_e1.br_error;
   assign exu_rets_e1_pkt.pc1_call = i1_predict_p_e1.pcall & i1_predict_p_e1.valid & ~i1_predict_p_e1.br_error;
   assign exu_rets_e1_pkt.pc0_ret  = i0_predict_p_e1.pret  & i0_predict_p_e1.valid & ~i0_predict_p_e1.br_error;
   assign exu_rets_e1_pkt.pc1_ret  = i1_predict_p_e1.pret  & i1_predict_p_e1.valid & ~i1_predict_p_e1.br_error;
   assign exu_rets_e1_pkt.pc0_pc4  = i0_predict_p_e1.pc4;
   assign exu_rets_e1_pkt.pc1_pc4  = i1_predict_p_e1.pc4;



   rvdffe #(76) i0_src_e1_ff (.*,
                            .en(i0_e1_data_en),
                            .din( {i0_rs1_d[31:0], i0_rs2_d[31:0], dec_i0_br_immed_d[12:1]}),
                            .dout({i0_rs1_e1[31:0], i0_rs2_e1[31:0], i0_br_immed_e1[12:1]})
                            );

   rvdffe #(76) i0_src_e2_ff (.*,
                            .en(i0_e2_data_en),
                            .din( {i0_rs1_e1[31:0], i0_rs2_e1[31:0], i0_br_immed_e1[12:1]}),
                            .dout({i0_rs1_e2[31:0], i0_rs2_e2[31:0], i0_br_immed_e2[12:1]})
                            );

   rvdffe #(76) i0_src_e3_ff (.*,
                            .en(i0_e3_data_en),
                            .din( {i0_rs1_e2_final[31:0], i0_rs2_e2_final[31:0], i0_br_immed_e2[12:1]}),
                            .dout({i0_rs1_e3[31:0], i0_rs2_e3[31:0], i0_br_immed_e3[12:1]})
                            );



   rvdffe #(76) i1_src_e1_ff (.*,
                            .en(i1_e1_data_en),
                            .din( {i1_rs1_d[31:0], i1_rs2_d[31:0], dec_i1_br_immed_d[12:1]}),
                            .dout({i1_rs1_e1[31:0], i1_rs2_e1[31:0], i1_br_immed_e1[12:1]})
                            );

   rvdffe #(76) i1_src_e2_ff (.*,
                            .en(i1_e2_data_en),
                            .din( {i1_rs1_e1[31:0], i1_rs2_e1[31:0], i1_br_immed_e1[12:1]}),
                            .dout({i1_rs1_e2[31:0], i1_rs2_e2[31:0], i1_br_immed_e2[12:1]})
                            );

   rvdffe #(76) i1_src_e3_ff (.*,
                            .en(i1_e3_data_en),
                            .din( {i1_rs1_e2_final[31:0], i1_rs2_e2_final[31:0], i1_br_immed_e2[12:1]}),
                            .dout({i1_rs1_e3[31:0], i1_rs2_e3[31:0], i1_br_immed_e3[12:1]})
                            );




   assign i0_rs1_e2_final[31:0] = (dec_i0_rs1_bypass_en_e2) ? i0_rs1_bypass_data_e2[31:0] : i0_rs1_e2[31:0];
   assign i0_rs2_e2_final[31:0] = (dec_i0_rs2_bypass_en_e2) ? i0_rs2_bypass_data_e2[31:0] : i0_rs2_e2[31:0];
   assign i1_rs1_e2_final[31:0] = (dec_i1_rs1_bypass_en_e2) ? i1_rs1_bypass_data_e2[31:0] : i1_rs1_e2[31:0];
   assign i1_rs2_e2_final[31:0] = (dec_i1_rs2_bypass_en_e2) ? i1_rs2_bypass_data_e2[31:0] : i1_rs2_e2[31:0];


   assign i0_rs1_e3_final[31:0] = (dec_i0_rs1_bypass_en_e3) ? i0_rs1_bypass_data_e3[31:0] : i0_rs1_e3[31:0];
   assign i0_rs2_e3_final[31:0] = (dec_i0_rs2_bypass_en_e3) ? i0_rs2_bypass_data_e3[31:0] : i0_rs2_e3[31:0];
   assign i1_rs1_e3_final[31:0] = (dec_i1_rs1_bypass_en_e3) ? i1_rs1_bypass_data_e3[31:0] : i1_rs1_e3[31:0];
   assign i1_rs2_e3_final[31:0] = (dec_i1_rs2_bypass_en_e3) ? i1_rs2_bypass_data_e3[31:0] : i1_rs2_e3[31:0];

   // E1 GHR
   // fill in the ptaken for secondary branches.

   logic [`RV_BHT_GHR_RANGE] ghr_e4_ns, ghr_e4;
   logic [`RV_BHT_GHR_RANGE] ghr_e1_ns, ghr_e1;
   logic i0_taken_e1, i1_taken_e1, dec_i0_alu_decode_e1, dec_i1_alu_decode_e1, i0_valid_e1, i1_valid_e1, i0_ataken_e1, i1_ataken_e1, exu_flush_final_f;
   assign i0_valid_e1 = ~exu_flush_final & ~exu_flush_final_f & (i0_predict_p_e1.valid | i0_predict_p_e1.misp);
   assign i1_valid_e1 = ~exu_flush_final & ~exu_flush_final_f & (i1_predict_p_e1.valid | i1_predict_p_e1.misp) & ~exu_i0_flush_upper_e1;
   assign i0_ataken_e1 = i0_predict_p_e1.ataken;
   assign i1_ataken_e1 = i1_predict_p_e1.ataken;

   assign i0_taken_e1 = (i0_ataken_e1 & dec_i0_alu_decode_e1) | (i0_predict_p_e1.hist[1] & ~dec_i0_alu_decode_e1);
   assign i1_taken_e1= (i1_ataken_e1 & dec_i1_alu_decode_e1) | (i1_predict_p_e1.hist[1] & ~dec_i1_alu_decode_e1);

    assign ghr_e1_ns[`RV_BHT_GHR_RANGE] = ( ({`RV_BHT_GHR_SIZE{~dec_tlu_flush_lower_wb & i0_valid_e1 & (i0_predict_p_e1.misp | ~i1_valid_e1)}} & {ghr_e1[`RV_BHT_GHR_SIZE-2:0], i0_taken_e1}) |
`ifdef RV_BHT_GHR_SIZE_2
                                           ({`RV_BHT_GHR_SIZE{~dec_tlu_flush_lower_wb & i0_valid_e1 & ~i0_predict_p_e1.misp &  i1_valid_e1}} & {                              i0_taken_e1, i1_taken_e1}) |
`else
                                           ({`RV_BHT_GHR_SIZE{~dec_tlu_flush_lower_wb & i0_valid_e1 & ~i0_predict_p_e1.misp &  i1_valid_e1}} & {ghr_e1[`RV_BHT_GHR_SIZE-3:0], i0_taken_e1, i1_taken_e1}) |
`endif
                                           ({`RV_BHT_GHR_SIZE{~dec_tlu_flush_lower_wb & ~i0_valid_e1 & ~i0_predict_p_e1.br_error & i1_valid_e1}} & {ghr_e1[`RV_BHT_GHR_SIZE-2:0], i1_taken_e1}) |
                                           ({`RV_BHT_GHR_SIZE{dec_tlu_flush_lower_wb}} & ghr_e4[`RV_BHT_GHR_RANGE]) |
                                           ({`RV_BHT_GHR_SIZE{~dec_tlu_flush_lower_wb & ~i0_valid_e1 & ~i1_valid_e1}} & ghr_e1[`RV_BHT_GHR_RANGE]) );

   rvdffs #(`RV_BHT_GHR_SIZE) e1ghrff (.*, .clk(active_clk), .en(~freeze), .din({ghr_e1_ns[`RV_BHT_GHR_RANGE]}), .dout({ghr_e1[`RV_BHT_GHR_RANGE]}));
   rvdffs #(2)             e1ghrdecff (.*, .clk(active_clk), .en(~freeze), .din({dec_i0_alu_decode_d, dec_i1_alu_decode_d}), .dout({dec_i0_alu_decode_e1, dec_i1_alu_decode_e1}));

   // E4 GHR
   // the ataken is filled in by e1 stage if e1 stage executes the branch, otherwise by e4 stage.
   logic i0_valid_e4, i1_pred_valid_e4;
   assign i0_valid_e4 = dec_tlu_i0_valid_e4 & ((i0_predict_p_e4.valid) | i0_predict_p_e4.misp);
   assign i1_pred_valid_e4 = dec_tlu_i1_valid_e4 & ((i1_predict_p_e4.valid) | i1_predict_p_e4.misp) & ~exu_i0_flush_upper_e4;
   assign ghr_e4_ns[`RV_BHT_GHR_RANGE]  = ( ({`RV_BHT_GHR_SIZE{i0_valid_e4 & (i0_predict_p_e4.misp | ~i1_pred_valid_e4)}} & {ghr_e4[`RV_BHT_GHR_SIZE-2:0], i0_predict_p_e4.ataken}) |
`ifdef RV_BHT_GHR_SIZE_2
                                           ({`RV_BHT_GHR_SIZE{i0_valid_e4  & ~i0_predict_p_e4.misp &  i1_pred_valid_e4}} & {                              i0_predict_p_e4.ataken, i1_predict_p_e4.ataken}) |
`else
                                           ({`RV_BHT_GHR_SIZE{i0_valid_e4  & ~i0_predict_p_e4.misp &  i1_pred_valid_e4}} & {ghr_e4[`RV_BHT_GHR_SIZE-3:0], i0_predict_p_e4.ataken, i1_predict_p_e4.ataken}) |
`endif
                                           ({`RV_BHT_GHR_SIZE{~i0_valid_e4 & ~i0_predict_p_e4.br_error & i1_pred_valid_e4}} & {ghr_e4[`RV_BHT_GHR_SIZE-2:0], i1_predict_p_e4.ataken}) |
                                           ({`RV_BHT_GHR_SIZE{~i0_valid_e4 & ~i1_pred_valid_e4}} & ghr_e4[`RV_BHT_GHR_RANGE]) );

   rvdff #(`RV_BHT_GHR_SIZE) e4ghrff (.*, .clk(active_clk), .din({ghr_e4_ns[`RV_BHT_GHR_RANGE]}),
                                                            .dout({ghr_e4[`RV_BHT_GHR_RANGE]}));
   rvdff #(1)           e4ghrflushff (.*, .clk(active_clk), .din({exu_flush_final}),
                                                            .dout({exu_flush_final_f}));

// RV_NO_SECONDARY_ALU {{
`ifdef RV_NO_SECONDARY_ALU

   rvdffe #($bits(predict_pkt_t)) i0_pp_e4_ff (.*, .en(i0_e4_ctl_en), .din(i0_pp_e4_in),.dout(i0_predict_p_e4) );
   rvdffe #($bits(predict_pkt_t)) i1_pp_e4_ff (.*, .en(i1_e4_ctl_en), .din(i1_pp_e4_in),.dout(i1_predict_p_e4) );

   assign exu_i0_result_e4[31:0]     = '0;
   assign exu_i0_flush_lower_e4      = '0;
   assign exu_i0_flush_path_e4[31:1] = '0;
   assign i0_alu_pc_nc[31:1]         = '0;
   assign i0_pred_correct_lower_e4   = '0;

   assign exu_i1_result_e4[31:0]     = '0;
   assign exu_i1_flush_lower_e4      = '0;
   assign exu_i1_flush_path_e4[31:1] = '0;
   assign i1_alu_pc_nc[31:1]         = '0;
   assign i1_pred_correct_lower_e4   = '0;

`else

   exu_alu_ctl i0_alu_e4 (.*,
                          .freeze        ( 1'b0                        ),   // I
                          .enable        ( i0_e4_ctl_en                ),   // I
                          .predict_p     ( i0_pp_e4_in                 ),   // I
                          .valid         ( dec_i0_sec_decode_e3        ),   // I
                          .flush         ( dec_tlu_flush_lower_wb      ),   // I
                          .a             ( i0_rs1_e3_final[31:0]       ),   // I
                          .b             ( i0_rs2_e3_final[31:0]       ),   // I
                          .pc            ( dec_i0_pc_e3[31:1]          ),   // I
                          .brimm         ( i0_br_immed_e3[12:1]        ),   // I
                          .ap            ( i0_ap_e4                    ),   // I
                          .out           ( exu_i0_result_e4[31:0]      ),   // O
                          .flush_upper   ( exu_i0_flush_lower_e4       ),   // O
                          .flush_path    ( exu_i0_flush_path_e4[31:1]  ),   // O
                          .predict_p_ff  ( i0_predict_p_e4             ),   // O
                          .pc_ff         ( i0_alu_pc_nc[31:1]          ),   // O
                          .pred_correct  ( i0_pred_correct_lower_e4    )    // O
                          );


   exu_alu_ctl i1_alu_e4 (.*,
                          .freeze        ( 1'b0                        ),   // I
                          .enable        ( i1_e4_ctl_en                ),   // I
                          .predict_p     ( i1_pp_e4_in                 ),   // I
                          .valid         ( dec_i1_sec_decode_e3        ),   // I
                          .flush         ( dec_tlu_flush_lower_wb      ),   // I
                          .a             ( i1_rs1_e3_final[31:0]       ),   // I
                          .b             ( i1_rs2_e3_final[31:0]       ),   // I
                          .pc            ( dec_i1_pc_e3[31:1]          ),   // I
                          .brimm         ( i1_br_immed_e3[12:1]        ),   // I
                          .ap            ( i1_ap_e4                    ),   // I
                          .out           ( exu_i1_result_e4[31:0]      ),   // O
                          .flush_upper   ( exu_i1_flush_lower_e4       ),   // O
                          .flush_path    ( exu_i1_flush_path_e4[31:1]  ),   // O
                          .predict_p_ff  ( i1_predict_p_e4             ),   // O
                          .pc_ff         ( i1_alu_pc_nc[31:1]          ),   // O
                          .pred_correct  ( i1_pred_correct_lower_e4    )    // O
                          );

`endif      // RV_NO_SECONDARY_ALU  }}


   assign exu_i0_br_hist_e4[1:0]               = i0_predict_p_e4.hist[1:0];
   assign exu_i0_br_bank_e4[1:0]               = i0_predict_p_e4.bank[1:0];
   assign exu_i0_br_error_e4                   = i0_predict_p_e4.br_error;
   assign exu_i0_br_fghr_e4[`RV_BHT_GHR_RANGE] = i0_predict_p_e4.fghr[`RV_BHT_GHR_RANGE];
   assign exu_i0_br_middle_e4                  = i0_predict_p_e4.pc4 ^ i0_predict_p_e4.boffset;
   assign exu_i0_br_start_error_e4     = i0_predict_p_e4.br_start_error;
   assign exu_i0_br_index_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]     = i0_predict_p_e4.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   assign exu_i0_br_valid_e4           = i0_predict_p_e4.valid;
   assign exu_i0_br_mp_e4              = i0_predict_p_e4.misp; // needed to squash i1 error
   assign exu_i0_br_ret_e4             = i0_predict_p_e4.pret;
   assign exu_i0_br_call_e4            = i0_predict_p_e4.pcall;
   assign exu_i0_br_way_e4             = i0_predict_p_e4.way;

   assign exu_i1_br_hist_e4[1:0]               = i1_predict_p_e4.hist[1:0];
   assign exu_i1_br_bank_e4[1:0]               = i1_predict_p_e4.bank[1:0];
   assign exu_i1_br_fghr_e4[`RV_BHT_GHR_RANGE] = i1_predict_p_e4.fghr[`RV_BHT_GHR_RANGE];
   assign exu_i1_br_middle_e4                  = i1_predict_p_e4.pc4 ^ i1_predict_p_e4.boffset;
   assign exu_i1_br_error_e4                   = i1_predict_p_e4.br_error;
   assign exu_i1_br_index_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]     = i1_predict_p_e4.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   assign exu_i1_br_start_error_e4     = i1_predict_p_e4.br_start_error;
   assign exu_i1_br_valid_e4           = i1_predict_p_e4.valid;
   assign exu_i1_br_mp_e4              = i1_predict_p_e4.misp;
   assign exu_i1_br_way_e4             = i1_predict_p_e4.way;

   assign exu_i1_br_ret_e4             = i1_predict_p_e4.pret;
   assign exu_i1_br_call_e4            = i1_predict_p_e4.pcall;

   assign exu_rets_e4_pkt.pc0_call = i0_predict_p_e4.pcall & i0_predict_p_e4.valid & ~i0_predict_p_e4.br_error;
   assign exu_rets_e4_pkt.pc1_call = i1_predict_p_e4.pcall & i1_predict_p_e4.valid & ~i1_predict_p_e4.br_error;
   assign exu_rets_e4_pkt.pc0_ret = i0_predict_p_e4.pret & i0_predict_p_e4.valid & ~i0_predict_p_e4.br_error;
   assign exu_rets_e4_pkt.pc1_ret = i1_predict_p_e4.pret & i1_predict_p_e4.valid & ~i1_predict_p_e4.br_error;
   assign exu_rets_e4_pkt.pc0_pc4 = i0_predict_p_e4.pc4;
   assign exu_rets_e4_pkt.pc1_pc4 = i1_predict_p_e4.pc4;

   predict_pkt_t final_predict_mp, final_predict_mp_ff;

   logic fp_enable, fp_enable_ff;

   assign fp_enable = exu_i0_flush_lower_e4 | exu_i1_flush_lower_e4 |
                      exu_i0_flush_upper_e1 | exu_i1_flush_upper_e1;

   rvdff #(1) final_predict_ff (.*, .clk(active_clk), .din(fp_enable), .dout(fp_enable_ff));


   // flush_upper_e1's below take freeze into account
   assign final_predict_mp = (exu_i0_flush_lower_e4) ? i0_predict_p_e4 :
                             (exu_i1_flush_lower_e4) ? i1_predict_p_e4 :
                             (exu_i0_flush_upper_e1) ? i0_predict_p_e1 :
                             (exu_i1_flush_upper_e1) ? i1_predict_p_e1 : '0;

   rvdffe #($bits(predict_pkt_t)) predict_mp_ff (.*, .en(fp_enable | fp_enable_ff), .din(final_predict_mp), .dout(final_predict_mp_ff));

   logic [`RV_BHT_GHR_RANGE] final_eghr, after_flush_eghr;
   assign final_eghr[`RV_BHT_GHR_RANGE] = ((exu_i0_flush_upper_e1 | exu_i1_flush_upper_e1) & ~dec_tlu_flush_lower_wb & ~exu_i0_flush_lower_e4 & ~exu_i1_flush_lower_e4 ) ? ghr_e1[`RV_BHT_GHR_RANGE] : ghr_e4[`RV_BHT_GHR_RANGE];

   assign after_flush_eghr[`RV_BHT_GHR_RANGE] = ((exu_i0_flush_upper_e2 | exu_i1_flush_upper_e2) & ~dec_tlu_flush_lower_wb) ? ghr_e1[`RV_BHT_GHR_RANGE] : ghr_e4[`RV_BHT_GHR_RANGE];


   assign exu_mp_pkt.way                                    = final_predict_mp_ff.way;
   assign exu_mp_pkt.misp                                   = final_predict_mp_ff.misp;
   assign exu_mp_pkt.pcall                                  = final_predict_mp_ff.pcall;
   assign exu_mp_pkt.pja                                    = final_predict_mp_ff.pja;
   assign exu_mp_pkt.pret                                   = final_predict_mp_ff.pret;
   assign exu_mp_pkt.ataken                                 = final_predict_mp_ff.ataken;
   assign exu_mp_pkt.boffset                                = final_predict_mp_ff.boffset;
   assign exu_mp_pkt.pc4                                    = final_predict_mp_ff.pc4;
   assign exu_mp_pkt.hist[1:0]                              = final_predict_mp_ff.hist[1:0];
   assign exu_mp_pkt.toffset[11:0]                          = final_predict_mp_ff.toffset[11:0];
   assign exu_mp_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = final_predict_mp_ff.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign exu_mp_pkt.bank[1:0]                              = final_predict_mp_ff.bank[1:0];
   assign exu_mp_pkt.btag[`RV_BTB_BTAG_SIZE-1:0]            = final_predict_mp_ff.btag[`RV_BTB_BTAG_SIZE-1:0];
   assign exu_mp_pkt.fghr[`RV_BHT_GHR_RANGE]                = after_flush_eghr[`RV_BHT_GHR_RANGE];     // fghr repair value

   assign exu_mp_eghr[`RV_BHT_GHR_RANGE] = final_predict_mp_ff.fghr[`RV_BHT_GHR_RANGE]; // mp ghr for bht write



   rvdffe #(32) i0_upper_flush_e2_ff (.*,
                                    .en(i0_e2_ctl_en),
                                    .din({
                                          exu_i0_flush_path_e1[31:1],
                                          exu_i0_flush_upper_e1}),

                                    .dout({
                                           i0_flush_path_upper_e2[31:1],
                                           exu_i0_flush_upper_e2})
                                    );

   rvdffe #(33) i1_upper_flush_e2_ff (.*,
                                    .en(i1_e2_ctl_en),
                                    .din({dec_i1_valid_e1,
                                          exu_i1_flush_path_e1[31:1],
                                          exu_i1_flush_upper_e1}),
                                    .dout({i1_valid_e2,
                                           i1_flush_path_upper_e2[31:1],
                                           exu_i1_flush_upper_e2})
                                    );

   assign exu_flush_path_e2[31:1] = (exu_i0_flush_upper_e2) ? i0_flush_path_upper_e2[31:1] : i1_flush_path_upper_e2[31:1];

   assign exu_i0_flush_final = dec_tlu_flush_lower_wb | (exu_i0_flush_upper_e2 & ~freeze);

   assign exu_i1_flush_final = dec_tlu_flush_lower_wb | (exu_i1_flush_upper_e2 & ~freeze);

   assign exu_flush_upper_e2 = (exu_i0_flush_upper_e2 | exu_i1_flush_upper_e2) & ~freeze;

   assign exu_flush_final = dec_tlu_flush_lower_wb | exu_flush_upper_e2;

   assign exu_flush_path_final[31:1] = (dec_tlu_flush_lower_wb) ? dec_tlu_flush_path_wb[31:1] : exu_flush_path_e2[31:1];


   rvdffe #(63) i0_upper_flush_e3_ff (.*,
                                    .en(i0_e3_ctl_en),
                                    .din({i0_flush_path_upper_e2[31:1],
                                          pred_correct_npc_e2[31:1],
                                          exu_i0_flush_upper_e2}),
                                    .dout({
                                           i0_flush_path_upper_e3[31:1],
                                           pred_correct_npc_e3[31:1],
                                           exu_i0_flush_upper_e3})
                                    );

   rvdffe #(32) i1_upper_flush_e3_ff (.*,
                                    .en(i1_e3_ctl_en),
                                    .din({i1_valid_e2,
                                          i1_flush_path_upper_e2[31:1]
                                          }),
                                    .dout({i1_valid_e3,
                                           i1_flush_path_upper_e3[31:1]})
                                    );

   rvdffe #(63) i0_upper_flush_e4_ff (.*,
                                    .en(i0_e4_ctl_en),
                                    .din({
                                          i0_flush_path_upper_e3[31:1],
                                          pred_correct_npc_e3[31:1],
                                          exu_i0_flush_upper_e3 & ~freeze}),
                                    .dout({
                                           i0_flush_path_upper_e4[31:1],
                                           pred_correct_npc_e4[31:1],
                                           exu_i0_flush_upper_e4})
                                    );

   rvdffe #(32) i1_upper_flush_e4_ff (.*,
                                    .en(i1_e4_ctl_en),
                                    .din({i1_valid_e3 & ~freeze,
                                          i1_flush_path_upper_e3[31:1]}),
                                    .dout({i1_valid_e4,
                                           i1_flush_path_upper_e4[31:1]})
                                    );


   // npc logic for commit

   rvdffs #(2) pred_correct_upper_e2_ff  (.*,
                                       .clk(active_clk),
                                       .en(~freeze),
                                       .din({i1_pred_correct_upper_e1,i0_pred_correct_upper_e1}),
                                       .dout({i1_pred_correct_upper_e2,i0_pred_correct_upper_e2})
                                       );

   rvdffs #(2) pred_correct_upper_e3_ff  (.*,
                                       .clk(active_clk),
                                       .en(~freeze),
                                       .din({i1_pred_correct_upper_e2,i0_pred_correct_upper_e2}),
                                       .dout({i1_pred_correct_upper_e3,i0_pred_correct_upper_e3})
                                       );

   rvdff #(2) pred_correct_upper_e4_ff  (.*,
                                       .clk(active_clk),
                                       .din({i1_pred_correct_upper_e3,i0_pred_correct_upper_e3}),
                                       .dout({i1_pred_correct_upper_e4,i0_pred_correct_upper_e4})
                                       );

   rvdff #(2) sec_decode_e4_ff  (.*,
                                       .clk(active_clk),
                                       .din({dec_i0_sec_decode_e3,dec_i1_sec_decode_e3}),
                                       .dout({i0_sec_decode_e4,i1_sec_decode_e4})
                               );



   assign i1_valid_e4_eff = i1_valid_e4 & ~((i0_sec_decode_e4) ? exu_i0_flush_lower_e4 : exu_i0_flush_upper_e4);

   assign i1_pred_correct_e4_eff = (i1_sec_decode_e4) ? i1_pred_correct_lower_e4 : i1_pred_correct_upper_e4;
   assign i0_pred_correct_e4_eff = (i0_sec_decode_e4) ? i0_pred_correct_lower_e4 : i0_pred_correct_upper_e4;

   assign i1_flush_path_e4_eff[31:1] = (i1_sec_decode_e4) ? exu_i1_flush_path_e4[31:1] : i1_flush_path_upper_e4[31:1];
   assign i0_flush_path_e4_eff[31:1] = (i0_sec_decode_e4) ? exu_i0_flush_path_e4[31:1] : i0_flush_path_upper_e4[31:1];


   assign npc_e4[31:1] = (i1_valid_e4_eff) ? ((i1_pred_correct_e4_eff) ? pred_correct_npc_e4[31:1] : i1_flush_path_e4_eff[31:1]) :
                                             ((i0_pred_correct_e4_eff) ? pred_correct_npc_e4[31:1] : i0_flush_path_e4_eff[31:1]);


   assign exu_npc_e4[31:1] = (div_finish_early) ? exu_i0_flush_path_e1[31:1] :
                             (exu_div_finish)   ? div_npc[31:1]              :
                                                  npc_e4[31:1];

   // remember the npc of the divide
   rvdffe #(31) npc_any_ff (.*, .en(div_valid_e1), .din(exu_i0_flush_path_e1[31:1]),    .dout(div_npc[31:1]));


endmodule // exu
