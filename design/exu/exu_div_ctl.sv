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


module exu_div_ctl
  (
   input logic  clk,                       // Top level clock
   input logic  active_clk,                // Level 1 active clock
   input logic  rst_l,                     // Reset
   input logic  scan_mode,                 // Scan mode

   input logic  dec_tlu_fast_div_disable,  // Disable small number optimization

   input logic [31:0] dividend,            // Numerator
   input logic [31:0] divisor,             // Denominator
 
   input div_pkt_t    dp,                  // valid, sign, rem

   input logic  flush_lower,               // Flush pipeline


   output logic valid_ff_e1,               // Valid E1 stage
   output logic finish_early,              // Finish smallnum
   output logic finish,                    // Finish smallnum or normal divide

   output logic div_stall,                 // Divide is running

   output logic [31:0] out                 // Result

   );

   
   logic         run_in, run_state;
   logic [5:0]   count_in, count;
   logic [32:0]  m_ff;
   logic [32:0]  q_in, q_ff;
   logic [32:0]  a_in, a_ff;
   logic [32:0]  m_eff;
   logic [32:0]  a_shift;
   logic         dividend_neg_ff, divisor_neg_ff;
   logic [31:0]  dividend_comp;
   logic [31:0]  dividend_eff;
   logic [31:0]  q_ff_comp;
   logic [31:0]  q_ff_eff;
   logic [31:0]  a_ff_comp;
   logic [31:0]  a_ff_eff;
   logic         sign_ff, sign_eff;
   logic         rem_ff;
   logic         add;
   logic [32:0]  a_eff;
   logic         rem_correct;
   logic         flush_lower_ff;
   logic         e1val;
   logic         valid_e1;


   // short circuit logic for small numbers
   
   rvdff #(1) e1val_ff (.*, .clk(active_clk), .din(dp.valid & ~flush_lower_ff), .dout(valid_ff_e1));

   assign valid_e1 = valid_ff_e1 & ~flush_lower_ff;

   // dividend q_ff[31:0]
   // divisor m_ff[31:0]

   // smallnum case does not cover divide by 0
   logic         smallnum_case, smallnum_case_ff;

   logic [3:0]   smallnum, smallnum_ff;
   
   assign smallnum_case = (q_ff[31:4] == 28'b0) & (m_ff[31:4] == 28'b0) & (m_ff[3:0] != 4'b0) & ~rem_ff & valid_e1 & ~dec_tlu_fast_div_disable;

// small number divides - any 4b / 4b is done in 1 cycle (divisor != 0)

// to generate espresso equations:

// 1)  smalldiv > smalldiv.e

// 2) espresso -Dso -oeqntott smalldiv.e | addassign > smalldiv
   
   assign smallnum[3] = (q_ff[3]&!m_ff[3]&!m_ff[2]&!m_ff[1]);

   assign smallnum[2] = (q_ff[3]&!m_ff[3]&!m_ff[2]&!m_ff[0]) | (q_ff[2]&!m_ff[3]
       &!m_ff[2]&!m_ff[1]) | (q_ff[3]&q_ff[2]&!m_ff[3]&!m_ff[2]);

   assign smallnum[1] = (q_ff[2]&!m_ff[3]&!m_ff[2]&!m_ff[0]) | (q_ff[1]&!m_ff[3]
       &!m_ff[2]&!m_ff[1]) | (q_ff[3]&!m_ff[3]&!m_ff[1]&!m_ff[0]) | (
       q_ff[3]&!q_ff[2]&!m_ff[3]&!m_ff[2]&m_ff[1]&m_ff[0]) | (!q_ff[3]
       &q_ff[2]&q_ff[1]&!m_ff[3]&!m_ff[2]) | (q_ff[3]&q_ff[2]&!m_ff[3]
       &!m_ff[0]) | (q_ff[3]&q_ff[2]&!m_ff[3]&m_ff[2]&!m_ff[1]) | (q_ff[3]
       &q_ff[1]&!m_ff[3]&!m_ff[1]) | (q_ff[3]&q_ff[2]&q_ff[1]&!m_ff[3]
       &m_ff[2]);

   assign smallnum[0] = (q_ff[2]&q_ff[1]&q_ff[0]&!m_ff[3]&!m_ff[1]) | (q_ff[3]
       &!q_ff[2]&q_ff[0]&!m_ff[3]&m_ff[1]&m_ff[0]) | (q_ff[2]&!m_ff[3]
       &!m_ff[1]&!m_ff[0]) | (q_ff[1]&!m_ff[3]&!m_ff[2]&!m_ff[0]) | (
       q_ff[0]&!m_ff[3]&!m_ff[2]&!m_ff[1]) | (!q_ff[3]&q_ff[2]&!q_ff[1]
       &!m_ff[3]&!m_ff[2]&m_ff[1]&m_ff[0]) | (!q_ff[3]&q_ff[2]&q_ff[1]
       &!m_ff[3]&!m_ff[0]) | (q_ff[3]&!m_ff[2]&!m_ff[1]&!m_ff[0]) | (
       q_ff[3]&!q_ff[2]&!m_ff[3]&m_ff[2]&m_ff[1]) | (!q_ff[3]&q_ff[2]
       &q_ff[1]&!m_ff[3]&m_ff[2]&!m_ff[1]) | (!q_ff[3]&q_ff[2]&q_ff[0]
       &!m_ff[3]&!m_ff[1]) | (q_ff[3]&!q_ff[2]&!q_ff[1]&!m_ff[3]&m_ff[2]
       &m_ff[0]) | (!q_ff[2]&q_ff[1]&q_ff[0]&!m_ff[3]&!m_ff[2]) | (q_ff[3]
       &q_ff[2]&!m_ff[1]&!m_ff[0]) | (q_ff[3]&q_ff[1]&!m_ff[2]&!m_ff[0]) | (
       !q_ff[3]&q_ff[2]&q_ff[1]&q_ff[0]&!m_ff[3]&m_ff[2]) | (q_ff[3]&q_ff[2]
       &m_ff[3]&!m_ff[2]) | (q_ff[3]&q_ff[1]&m_ff[3]&!m_ff[2]&!m_ff[1]) | (
       q_ff[3]&q_ff[0]&!m_ff[2]&!m_ff[1]) | (q_ff[3]&!q_ff[1]&!m_ff[3]
       &m_ff[2]&m_ff[1]&m_ff[0]) | (q_ff[3]&q_ff[2]&q_ff[1]&m_ff[3]&!m_ff[0]) | (
       q_ff[3]&q_ff[2]&q_ff[1]&m_ff[3]&!m_ff[1]) | (q_ff[3]&q_ff[2]&q_ff[0]
       &m_ff[3]&!m_ff[1]) | (q_ff[3]&!q_ff[2]&q_ff[1]&!m_ff[3]&m_ff[1]) | (
       q_ff[3]&q_ff[1]&q_ff[0]&!m_ff[2]) | (q_ff[3]&q_ff[2]&q_ff[1]&q_ff[0]
       &m_ff[3]);

   rvdff #(5) smallnumff (.*, .clk(active_clk), .din({smallnum_case,smallnum[3:0]}), .dout({smallnum_case_ff,smallnum_ff[3:0]}));


   // end short circuit
   
   
   rvdff #(1) flush_any_ff (.*, .clk(active_clk), .din(flush_lower), .dout(flush_lower_ff));
   

   assign div_stall = run_state;
   
   
   assign run_in = (dp.valid | run_state) & ~finish & ~flush_lower_ff;

   rvdff #(1) runff (.*, .clk(active_clk), .din(run_in), .dout(run_state));

   assign count_in[5:0] = {6{run_state & ~finish & ~flush_lower_ff}} & (count[5:0] + 1'b1);
   

   rvdff #(6) countff (.*, .clk(active_clk), .din(count_in[5:0]), .dout(count[5:0]));

   assign finish_early = smallnum_case;
   
   assign finish = (smallnum_case | ((~rem_ff) ? (count[5:0] == 6'd32) : (count[5:0] == 6'd33))) & ~flush_lower & ~flush_lower_ff;

   assign sign_eff = ~dp.unsign & (divisor[31:0] != 32'b0);
   

   // divisor
   rvdffe #(33) mff (.*, .en(dp.valid), .din({sign_eff & divisor[31], divisor[31:0]}), .dout(m_ff[32:0]));

   
   // quotient
   assign q_in[32:0] = ({33{dp.valid}}                               &  {1'b0,dividend[31:0]}) |
                       ({33{~dp.valid & run_state & ~(|count[5:0])}} &  {dividend_eff[31:0], ~a_in[32]}) |
                       ({33{~dp.valid & run_state & |count[5:0]}}    &  {q_ff[31:0], ~a_in[32]});
   

   rvdffe #(33) qff (.*, .en(dp.valid | run_state), .din(q_in[32:0]), .dout(q_ff[32:0]));

   rvtwoscomp #(32) dividend_c (.din(q_ff[31:0]), .dout(dividend_comp[31:0]));
   
   assign dividend_eff[31:0] = (sign_ff & dividend_neg_ff) ? dividend_comp[31:0] : q_ff[31:0];

   
   assign m_eff[32:0] = ( add ) ? m_ff[32:0] : ~m_ff[32:0];

   assign a_eff[32:0] = (rem_correct) ? a_ff[32:0] : {a_ff[31:0], q_ff[32]};
   
   assign a_shift[32:0] = {33{~dp.valid & run_state}} & a_eff[32:0];

   // run_state to quiet a_in for power
   assign a_in[32:0] = (a_shift[32:0] + m_eff[32:0] + {32'b0,~add}) & {33{run_state & ~dp.valid}};

   logic         a_en;

   assign a_en = (run_state & count[5:0]!=6'd33) | rem_correct | dp.valid;

   // remainder
   rvdffe #(33) aff (.*, .en(a_en), .din(a_in[32:0]), .dout(a_ff[32:0]));

   logic         m_already_comp;
   
   assign m_already_comp = (divisor_neg_ff & sign_ff);

   // if m already complemented, then invert operation add->sub, sub->add

   assign add =  (a_ff[32] | rem_correct) ^ m_already_comp;

   assign rem_correct = (count[5:0] == 6'd33) & rem_ff & a_ff[32];
   
   
   rvdffs #(4) miscf (.*, .clk(active_clk), .en(dp.valid), .din({dividend[31],divisor[31],sign_eff,dp.rem}), .dout({dividend_neg_ff,divisor_neg_ff,sign_ff,rem_ff}));

   rvtwoscomp #(32) q_ff_c (.din(q_ff[31:0]), .dout(q_ff_comp[31:0]));

   rvtwoscomp #(32) a_ff_c (.din(a_ff[31:0]), .dout(a_ff_comp[31:0]));
   
   assign q_ff_eff[31:0] = (sign_ff & (dividend_neg_ff ^ divisor_neg_ff)) ? q_ff_comp[31:0] : q_ff[31:0];

   assign a_ff_eff[31:0] = (sign_ff &  dividend_neg_ff) ? a_ff_comp[31:0] : a_ff[31:0];

   assign out[31:0] = (smallnum_case_ff) ? {28'b0, smallnum_ff[3:0]} :
                      (rem_ff) ? a_ff_eff[31:0] : q_ff_eff[31:0];
   
   
endmodule // exu_div_ctl
