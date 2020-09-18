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
package swerv_types;

// performance monitor stuff
typedef struct packed {
                       logic [2:0] trace_rv_i_valid_ip;
                       logic [95:0] trace_rv_i_insn_ip;
                       logic [95:0] trace_rv_i_address_ip;
                       logic [2:0] trace_rv_i_exception_ip;
                       logic [4:0] trace_rv_i_ecause_ip;
                       logic [2:0] trace_rv_i_interrupt_ip;
                       logic [31:0] trace_rv_i_tval_ip;
                       } trace_pkt_t;


typedef enum logic [3:0] {
                          NULL     = 4'b0000,
                          MUL      = 4'b0001,
                          LOAD     = 4'b0010,
                          STORE    = 4'b0011,
                          ALU      = 4'b0100,
                          CSRREAD  = 4'b0101,
                          CSRWRITE = 4'b0110,
                          CSRRW    = 4'b0111,
                          EBREAK   = 4'b1000,
                          ECALL    = 4'b1001,
                          FENCE    = 4'b1010,
                          FENCEI   = 4'b1011,
                          MRET     = 4'b1100,
                          CONDBR   = 4'b1101,
                          JAL      = 4'b1110
                          } inst_t;

typedef struct packed {
`ifdef RV_ICACHE_ECC
                       logic [39:0] ecc;
`else
                       logic [7:0] parity;
`endif
                       } icache_err_pkt_t;

typedef struct packed {
                       logic valid;
                       logic wb;
                       logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] tag;
                       logic [4:0] rd;
                       } load_cam_pkt_t;

typedef struct packed {
                       logic pc0_call;
                       logic pc0_ret;
                       logic pc0_pc4;
                       logic pc1_call;
                       logic pc1_ret;
                       logic pc1_pc4;
                       } rets_pkt_t;
typedef struct packed {
                       logic valid;
                       logic [11:0] toffset;
                       logic [1:0] hist;
                       logic br_error;
                       logic br_start_error;
                       logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] index;
                       logic [1:0] bank;
                       logic [31:1] prett;  // predicted ret target
                       logic [`RV_BHT_GHR_RANGE] fghr;
`ifdef RV_BTB_48
                       logic [1:0] way;
`else
                       logic way;
`endif
                       logic ret;
                       logic [`RV_BTB_BTAG_SIZE-1:0] btag;
                       } br_pkt_t;

typedef struct packed {
                       logic valid;
                       logic [1:0] hist;
                       logic br_error;
                       logic br_start_error;
                       logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] index;
                       logic [1:0] bank;
                       logic [`RV_BHT_GHR_RANGE] fghr;
`ifdef RV_BTB_48
                       logic [1:0] way;
`else
                       logic way;
`endif
                       logic middle;
                       } br_tlu_pkt_t;

typedef struct packed {
                       logic misp;
                       logic ataken;
                       logic boffset;
                       logic pc4;
                       logic [1:0] hist;
                       logic [11:0] toffset;
                       logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] index;
                       logic [1:0] bank;
                       logic valid;
                       logic br_error;
                       logic br_start_error;
                       logic [31:1] prett;
                       logic pcall;
                       logic pret;
                       logic pja;
                       logic [`RV_BTB_BTAG_SIZE-1:0] btag;
                       logic [`RV_BHT_GHR_RANGE] fghr;
`ifdef RV_BTB_48
                       logic [1:0] way;
`else
                       logic way;
`endif
                       } predict_pkt_t;

typedef struct packed {
                       logic legal;
                       logic icaf;
                       logic icaf_second;
                       logic perr;
                       logic sbecc;
                       logic fence_i;
                       logic [3:0] i0trigger;
                       logic [3:0] i1trigger;
                       inst_t pmu_i0_itype;        // pmu - instruction type
                       inst_t pmu_i1_itype;        // pmu - instruction type
                       logic pmu_i0_br_unpred;     // pmu
                       logic pmu_i1_br_unpred;     // pmu
                       logic pmu_divide;
                       logic pmu_lsu_misaligned;
                       } trap_pkt_t;

typedef struct packed {
                       logic [4:0] i0rd;
                       logic i0mul;
                       logic i0load;
                       logic i0store;
                       logic i0div;
                       logic i0v;
                       logic i0valid;
                       logic i0secondary;
                       logic [1:0] i0rs1bype2;
                       logic [1:0] i0rs2bype2;
                       logic [3:0] i0rs1bype3;
                       logic [3:0] i0rs2bype3;
                       logic [4:0] i1rd;
                       logic i1mul;
                       logic i1load;
                       logic i1store;
                       logic i1v;
                       logic i1valid;
                       logic csrwen;
                       logic csrwonly;
                       logic [11:0] csrwaddr;
                       logic i1secondary;
                       logic [1:0] i1rs1bype2;
                       logic [1:0] i1rs2bype2;
                       logic [6:0] i1rs1bype3;
                       logic [6:0] i1rs2bype3;
                       } dest_pkt_t;

typedef struct packed {
                       logic mul;
                       logic load;
                       logic sec;
                       logic alu;
                       } class_pkt_t;

typedef struct packed {
                       logic [4:0] rs1;
                       logic [4:0] rs2;
                       logic [4:0] rd;
                       } reg_pkt_t;


typedef struct packed {
                       logic valid;
                       logic land;
                       logic lor;
                       logic lxor;
                       logic sll;
                       logic srl;
                       logic sra;
                       logic beq;
                       logic bne;
                       logic blt;
                       logic bge;
                       logic add;
                       logic sub;
                       logic slt;
                       logic unsign;
                       logic jal;
                       logic predict_t;
                       logic predict_nt;
                       logic csr_write;
                       logic csr_imm;
                       } alu_pkt_t;

typedef struct packed {
                       logic by;
                       logic half;
                       logic word;
                       logic dword;  // for dma
                       logic load;
                       logic store;
                       logic unsign;
                       logic dma;    // dma pkt
                       logic store_data_bypass_c1;
                       logic load_ldst_bypass_c1;
                       logic store_data_bypass_c2;
                       logic store_data_bypass_i0_e2_c2;
                       logic [1:0] store_data_bypass_e4_c1;
                       logic [1:0] store_data_bypass_e4_c2;
                       logic [1:0] store_data_bypass_e4_c3;
                       logic valid;
                       } lsu_pkt_t;

typedef struct packed {
                      logic exc_valid;
                      logic single_ecc_error;
                      logic inst_type;   //0: Load, 1: Store
                      logic inst_pipe;   //0: i0, 1: i1
                      logic dma_valid;
                      logic exc_type;    //0: MisAligned, 1: Access Fault
                      logic [31:0] addr;
                      } lsu_error_pkt_t;

typedef struct packed {
                       logic alu;
                       logic rs1;
                       logic rs2;
                       logic imm12;
                       logic rd;
                       logic shimm5;
                       logic imm20;
                       logic pc;
                       logic load;
                       logic store;
                       logic lsu;
                       logic add;
                       logic sub;
                       logic land;
                       logic lor;
                       logic lxor;
                       logic sll;
                       logic sra;
                       logic srl;
                       logic slt;
                       logic unsign;
                       logic condbr;
                       logic beq;
                       logic bne;
                       logic bge;
                       logic blt;
                       logic jal;
                       logic by;
                       logic half;
                       logic word;
                       logic csr_read;
                       logic csr_clr;
                       logic csr_set;
                       logic csr_write;
                       logic csr_imm;
                       logic presync;
                       logic postsync;
                       logic ebreak;
                       logic ecall;
                       logic mret;
                       logic mul;
                       logic rs1_sign;
                       logic rs2_sign;
                       logic low;
                       logic div;
                       logic rem;
                       logic fence;
                       logic fence_i;
                       logic pm_alu;
                       logic legal;
                       } dec_pkt_t;


typedef struct packed {
                       logic valid;
                       logic rs1_sign;
                       logic rs2_sign;
                       logic low;
                       logic load_mul_rs1_bypass_e1;
                       logic load_mul_rs2_bypass_e1;
                       } mul_pkt_t;

typedef struct packed {
                       logic valid;
                       logic unsign;
                       logic rem;
                       } div_pkt_t;


typedef struct packed {
                        logic        select;
                        logic        match;
                        logic        store;
                        logic        load;
                        logic        execute;
                        logic        m;
                        logic [31:0] tdata2;
            } trigger_pkt_t;


typedef struct packed {
`ifdef RV_ICACHE_ECC
                        logic [41:0]  icache_wrdata; // {dicad0[31:0], dicad1[1:0]}
`else
                        logic [33:0]  icache_wrdata; // {dicad0[31:0], dicad1[1:0]}
`endif
                        logic [18:2]  icache_dicawics;
                        logic         icache_rd_valid;
                        logic         icache_wr_valid;
            } cache_debug_pkt_t;


endpackage // swerv_types
