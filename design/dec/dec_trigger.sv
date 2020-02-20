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
// Function: DEC Trigger Logic
// Comments:
//
//********************************************************************************
module dec_trigger
   import swerv_types::*;
(
   input logic         clk,
   input logic         rst_l,

   input trigger_pkt_t [3:0] trigger_pkt_any,           // Packet from tlu. 'select':0-pc,1-Opcode  'Execute' needs to be set for dec triggers to fire. 'match'-1 do mask, 0: full match
   input logic [31:1]  dec_i0_pc_d,                     // i0 pc
   input logic [31:1]  dec_i1_pc_d,                     // i1 pc

   output logic [3:0] dec_i0_trigger_match_d,
   output logic [3:0] dec_i1_trigger_match_d
);

   logic [3:0][31:0]  dec_i0_match_data;
   logic [3:0]        dec_i0_trigger_data_match;
   logic [3:0][31:0]  dec_i1_match_data;
   logic [3:0]        dec_i1_trigger_data_match;

   for (genvar i=0; i<4; i++) begin
      assign dec_i0_match_data[i][31:0] = ({32{~trigger_pkt_any[i].select & trigger_pkt_any[i].execute}} & {dec_i0_pc_d[31:1], trigger_pkt_any[i].tdata2[0]});      // select=0; do a PC match

      assign dec_i1_match_data[i][31:0] = ({32{~trigger_pkt_any[i].select & trigger_pkt_any[i].execute}} & {dec_i1_pc_d[31:1], trigger_pkt_any[i].tdata2[0]} );     // select=0; do a PC match

      rvmaskandmatch trigger_i0_match (.mask(trigger_pkt_any[i].tdata2[31:0]), .data(dec_i0_match_data[i][31:0]), .masken(trigger_pkt_any[i].match), .match(dec_i0_trigger_data_match[i]));
      rvmaskandmatch trigger_i1_match (.mask(trigger_pkt_any[i].tdata2[31:0]), .data(dec_i1_match_data[i][31:0]), .masken(trigger_pkt_any[i].match), .match(dec_i1_trigger_data_match[i]));

      assign dec_i0_trigger_match_d[i] = trigger_pkt_any[i].execute & trigger_pkt_any[i].m & dec_i0_trigger_data_match[i];
      assign dec_i1_trigger_match_d[i] = trigger_pkt_any[i].execute & trigger_pkt_any[i].m & dec_i1_trigger_data_match[i];
   end

endmodule // dec_trigger

