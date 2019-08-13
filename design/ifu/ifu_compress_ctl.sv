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

// purpose of this file is to convert 16b RISCV compressed instruction into 32b equivalent

module ifu_compress_ctl
  (
   input  logic [15:0] din,
   output logic [31:0] dout,
   output logic legal
   );

   

   logic [15:0]  i;
   
   logic [31:0]  o,l1,l2,l3;

   
   assign i[15:0] = din[15:0];
   

   logic [4:0]   rs2d,rdd,rdpd,rs2pd;
   
logic rdrd;
logic rdrs1;
logic rs2rs2;
logic rdprd;
logic rdprs1;
logic rs2prs2;
logic rs2prd;
logic uimm9_2;
logic ulwimm6_2;
logic ulwspimm7_2;
logic rdeq2;
logic rdeq1;
logic rs1eq2;
logic sbroffset8_1;
logic simm9_4;
logic simm5_0;
logic sjaloffset11_1;
logic sluimm17_12;
logic uimm5_0;
logic uswimm6_2;
logic uswspimm7_2;



   // form the opcodes

   // formats
   //
   // c.add rd 11:7 rs2  6:2
   // c.and rdp 9:7 rs2p 4:2
   //
   // add rs2 24:20 rs1 19:15  rd 11:7
   
   assign rs2d[4:0] = i[6:2];

   assign rdd[4:0] = i[11:7];

   assign rdpd[4:0] = {2'b01, i[9:7]};

   assign rs2pd[4:0] = {2'b01, i[4:2]};   
   
   

   // merge in rd, rs1, rs2

   
   // rd
   assign l1[6:0] = o[6:0];

   assign l1[11:7] = o[11:7] | 
                     ({5{rdrd}} & rdd[4:0]) |
                     ({5{rdprd}} & rdpd[4:0]) |
                     ({5{rs2prd}} & rs2pd[4:0]) |
                     ({5{rdeq1}} & 5'd1) |
                     ({5{rdeq2}} & 5'd2);
   

   // rs1                    
   assign l1[14:12] = o[14:12];
   assign l1[19:15] = o[19:15] | 
                      ({5{rdrs1}} & rdd[4:0]) |
                      ({5{rdprs1}} & rdpd[4:0]) |
                      ({5{rs1eq2}} & 5'd2);
      
   
   // rs2
   assign l1[24:20] = o[24:20] | 
                      ({5{rs2rs2}} & rs2d[4:0]) |
                      ({5{rs2prs2}} & rs2pd[4:0]);

   assign l1[31:25] = o[31:25];
   
   logic [5:0] simm5d;
   logic [9:2] uimm9d;

   logic [9:4] simm9d;
   logic [6:2] ulwimm6d;
   logic [7:2] ulwspimm7d;
   logic [5:0] uimm5d;
   logic [20:1] sjald;

   logic [31:12] sluimmd;   
   
   // merge in immediates + jal offset

   assign simm5d[5:0] = { i[12], i[6:2] };

   assign uimm9d[9:2] = { i[10:7], i[12:11], i[5], i[6] };

   assign simm9d[9:4] = { i[12], i[4:3], i[5], i[2], i[6] };

   assign ulwimm6d[6:2] = { i[5], i[12:10], i[6] };

   assign ulwspimm7d[7:2] = { i[3:2], i[12], i[6:4] };

   assign uimm5d[5:0] = { i[12], i[6:2] };

   assign sjald[11:1] = { i[12], i[8], i[10:9], i[6], i[7], i[2], i[11], i[5:4], i[3] };
   
   assign sjald[20:12] =  {9{i[12]}};


   
   assign sluimmd[31:12] = { {15{i[12]}}, i[6:2] };
   
   
   assign l2[31:20] = ( l1[31:20] ) | 
                      ( {12{simm5_0}}   &  {{7{simm5d[5]}},simm5d[4:0]} ) |
                      ( {12{uimm9_2}}   &  {2'b0,uimm9d[9:2],2'b0} ) |
                      ( {12{simm9_4}}   &   {{3{simm9d[9]}},simm9d[8:4],4'b0} ) |
                      ( {12{ulwimm6_2}} &   {5'b0,ulwimm6d[6:2],2'b0} ) |
                      ( {12{ulwspimm7_2}}  & {4'b0,ulwspimm7d[7:2],2'b0} ) |
                      ( {12{uimm5_0}}      &    {6'b0,uimm5d[5:0]} ) |
                      ( {12{sjaloffset11_1}} &  {sjald[20],sjald[10:1],sjald[11]} ) |
                      ( {12{sluimm17_12}}    &  sluimmd[31:20] );
                      
   
   
   assign l2[19:12] = ( l1[19:12] ) |
                      ( {8{sjaloffset11_1}} & sjald[19:12] ) |
                      ( {8{sluimm17_12}} & sluimmd[19:12] );
   

   assign l2[11:0] = l1[11:0];
   
   
   // merge in branch offset and store immediates

   logic [8:1]   sbr8d;
   logic [6:2]   uswimm6d;
   logic [7:2]   uswspimm7d;
   
   
   assign sbr8d[8:1] =   { i[12], i[6], i[5], i[2], i[11], i[10], i[4], i[3] };

   assign uswimm6d[6:2] = { i[5], i[12:10], i[6] };

   assign uswspimm7d[7:2] = { i[8:7], i[12:9] };
   
   assign l3[31:25] = ( l2[31:25] ) | 
                      ( {7{sbroffset8_1}} & { {4{sbr8d[8]}},sbr8d[7:5] } ) |
                      ( {7{uswimm6_2}}    & { 5'b0, uswimm6d[6:5] } ) |
                      ( {7{uswspimm7_2}} & { 4'b0, uswspimm7d[7:5] } );
   

   assign l3[24:12] = l2[24:12];
   
   assign l3[11:7] = ( l2[11:7] ) |
                     ( {5{sbroffset8_1}} & { sbr8d[4:1], sbr8d[8] } ) |
                     ( {5{uswimm6_2}} & { uswimm6d[4:2], 2'b0 } ) |
                     ( {5{uswspimm7_2}} & { uswspimm7d[4:2], 2'b0 } );

   assign l3[6:0] = l2[6:0];
   
   
   assign dout[31:0] = l3[31:0] & {32{legal}};


// file "cdecode" is human readable file that has all of the compressed instruction decodes defined and is part of git repo
// modify this file as needed

// to generate all the equations below from "cdecode" except legal equation:

// 1) coredecode -in cdecode > cdecode.e

// 2) espresso -Dso -oeqntott cdecode.e | addassign > compress_equations

// to generate the legal (16b compressed instruction is legal)  equation below:

// 1) coredecode -in cdecode -legal > clegal.e

// 2) espresso -Dso -oeqntott clegal.e | addassign > clegal_equation



   
   
// espresso decodes
assign rdrd = (!i[14]&i[6]&i[1]) | (!i[15]&i[14]&i[11]&i[0]) | (!i[14]&i[5]&i[1]) | (
    !i[15]&i[14]&i[10]&i[0]) | (!i[14]&i[4]&i[1]) | (!i[15]&i[14]&i[9]
    &i[0]) | (!i[14]&i[3]&i[1]) | (!i[15]&i[14]&!i[8]&i[0]) | (!i[14]
    &i[2]&i[1]) | (!i[15]&i[14]&i[7]&i[0]) | (!i[15]&i[1]) | (!i[15]
    &!i[13]&i[0]);

assign rdrs1 = (!i[14]&i[12]&i[11]&i[1]) | (!i[14]&i[12]&i[10]&i[1]) | (!i[14]
    &i[12]&i[9]&i[1]) | (!i[14]&i[12]&i[8]&i[1]) | (!i[14]&i[12]&i[7]
    &i[1]) | (!i[14]&!i[12]&!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]
    &i[12]&i[6]&i[1]) | (!i[14]&i[12]&i[5]&i[1]) | (!i[14]&i[12]&i[4]
    &i[1]) | (!i[14]&i[12]&i[3]&i[1]) | (!i[14]&i[12]&i[2]&i[1]) | (
    !i[15]&!i[14]&!i[13]&i[0]) | (!i[15]&!i[14]&i[1]);

assign rs2rs2 = (i[15]&i[6]&i[1]) | (i[15]&i[5]&i[1]) | (i[15]&i[4]&i[1]) | (
    i[15]&i[3]&i[1]) | (i[15]&i[2]&i[1]) | (i[15]&i[14]&i[1]);

assign rdprd = (i[15]&!i[14]&!i[13]&i[0]);

assign rdprs1 = (i[15]&!i[13]&i[0]) | (i[15]&i[14]&i[0]) | (i[14]&!i[1]&!i[0]);

assign rs2prs2 = (i[15]&!i[14]&!i[13]&i[11]&i[10]&i[0]) | (i[15]&!i[1]&!i[0]);

assign rs2prd = (!i[15]&!i[1]&!i[0]);

assign uimm9_2 = (!i[14]&!i[1]&!i[0]);

assign ulwimm6_2 = (!i[15]&i[14]&!i[1]&!i[0]);

assign ulwspimm7_2 = (!i[15]&i[14]&i[1]);

assign rdeq2 = (!i[15]&i[14]&i[13]&!i[11]&!i[10]&!i[9]&i[8]&!i[7]);

assign rdeq1 = (!i[14]&i[12]&i[11]&!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]
    &i[12]&i[10]&!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]&i[12]&i[9]
    &!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]&i[12]&i[8]&!i[6]&!i[5]
    &!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]&i[12]&i[7]&!i[6]&!i[5]&!i[4]&!i[3]
    &!i[2]&i[1]) | (!i[15]&!i[14]&i[13]);

assign rs1eq2 = (!i[15]&i[14]&i[13]&!i[11]&!i[10]&!i[9]&i[8]&!i[7]) | (i[14]
    &i[1]) | (!i[14]&!i[1]&!i[0]);

assign sbroffset8_1 = (i[15]&i[14]&i[0]);

assign simm9_4 = (!i[15]&i[14]&i[13]&!i[11]&!i[10]&!i[9]&i[8]&!i[7]);

assign simm5_0 = (!i[14]&!i[13]&i[11]&!i[10]&i[0]) | (!i[15]&!i[13]&i[0]);

assign sjaloffset11_1 = (!i[14]&i[13]);

assign sluimm17_12 = (!i[15]&i[14]&i[13]&i[7]) | (!i[15]&i[14]&i[13]&!i[8]) | (
    !i[15]&i[14]&i[13]&i[9]) | (!i[15]&i[14]&i[13]&i[10]) | (!i[15]&i[14]
    &i[13]&i[11]);

assign uimm5_0 = (i[15]&!i[14]&!i[13]&!i[11]&i[0]) | (!i[15]&!i[14]&i[1]);

assign uswimm6_2 = (i[15]&!i[1]&!i[0]);

assign uswspimm7_2 = (i[15]&i[14]&i[1]);

assign o[31]  = 1'b0;

assign o[30] = (i[15]&!i[14]&!i[13]&i[10]&!i[6]&!i[5]&i[0]) | (i[15]&!i[14]
    &!i[13]&!i[11]&i[10]&i[0]);

assign o[29]  = 1'b0;

assign o[28]  = 1'b0;

assign o[27]  = 1'b0;

assign o[26]  = 1'b0;

assign o[25]  = 1'b0;

assign o[24]  = 1'b0;

assign o[23]  = 1'b0;

assign o[22]  = 1'b0;

assign o[21]  = 1'b0;

assign o[20] = (!i[14]&i[12]&!i[11]&!i[10]&!i[9]&!i[8]&!i[7]&!i[6]&!i[5]&!i[4]
    &!i[3]&!i[2]&i[1]);

assign o[19]  = 1'b0;

assign o[18]  = 1'b0;

assign o[17]  = 1'b0;

assign o[16]  = 1'b0;

assign o[15]  = 1'b0;

assign o[14] = (i[15]&!i[14]&!i[13]&!i[11]&i[0]) | (i[15]&!i[14]&!i[13]&!i[10]
    &i[0]) | (i[15]&!i[14]&!i[13]&i[6]&i[0]) | (i[15]&!i[14]&!i[13]&i[5]
    &i[0]);

assign o[13] = (i[15]&!i[14]&!i[13]&i[11]&!i[10]&i[0]) | (i[15]&!i[14]&!i[13]
    &i[11]&i[6]&i[0]) | (i[14]&!i[0]);

assign o[12] = (i[15]&!i[14]&!i[13]&i[6]&i[5]&i[0]) | (i[15]&!i[14]&!i[13]&!i[11]
    &i[0]) | (i[15]&!i[14]&!i[13]&!i[10]&i[0]) | (!i[15]&!i[14]&i[1]) | (
    i[15]&i[14]&i[13]);

assign o[11]  = 1'b0;

assign o[10]  = 1'b0;

assign o[9]  = 1'b0;

assign o[8]  = 1'b0;

assign o[7]  = 1'b0;

assign o[6] = (i[15]&!i[14]&!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&!i[0]) | (!i[14]&i[13]) | (
    i[15]&i[14]&i[0]);

assign o[5] = (i[15]&!i[0]) | (i[15]&i[11]&i[10]) | (i[13]&!i[8]) | (i[13]&i[7]) | (
    i[13]&i[9]) | (i[13]&i[10]) | (i[13]&i[11]) | (!i[14]&i[13]) | (
    i[15]&i[14]);

assign o[4] = (!i[14]&!i[11]&!i[10]&!i[9]&!i[8]&!i[7]&!i[0]) | (!i[15]&!i[14]
    &!i[0]) | (!i[14]&i[6]&!i[0]) | (!i[15]&i[14]&i[0]) | (!i[14]&i[5]
    &!i[0]) | (!i[14]&i[4]&!i[0]) | (!i[14]&!i[13]&i[0]) | (!i[14]&i[3]
    &!i[0]) | (!i[14]&i[2]&!i[0]);

assign o[3] = (!i[14]&i[13]);

assign o[2] = (!i[14]&i[12]&i[11]&!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]
    &i[12]&i[10]&!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]&i[12]&i[9]
    &!i[6]&!i[5]&!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]&i[12]&i[8]&!i[6]&!i[5]
    &!i[4]&!i[3]&!i[2]&i[1]) | (!i[14]&i[12]&i[7]&!i[6]&!i[5]&!i[4]&!i[3]
    &!i[2]&i[1]) | (i[15]&!i[14]&!i[12]&!i[6]&!i[5]&!i[4]&!i[3]&!i[2]
    &!i[0]) | (!i[15]&i[13]&!i[8]) | (!i[15]&i[13]&i[7]) | (!i[15]&i[13]
    &i[9]) | (!i[15]&i[13]&i[10]) | (!i[15]&i[13]&i[11]) | (!i[14]&i[13]);

// 32b instruction has lower two bits 2'b11
   
assign o[1]  = 1'b1;

assign o[0]  = 1'b1;

assign legal = (!i[13]&!i[12]&i[11]&i[1]&!i[0]) | (!i[13]&!i[12]&i[6]&i[1]&!i[0]) | (
    !i[15]&!i[13]&i[11]&!i[1]) | (!i[13]&!i[12]&i[5]&i[1]&!i[0]) | (
    !i[13]&!i[12]&i[10]&i[1]&!i[0]) | (!i[15]&!i[13]&i[6]&!i[1]) | (
    i[15]&!i[12]&!i[1]&i[0]) | (!i[13]&!i[12]&i[9]&i[1]&!i[0]) | (!i[12]
    &i[6]&!i[1]&i[0]) | (!i[15]&!i[13]&i[5]&!i[1]) | (!i[13]&!i[12]&i[8]
    &i[1]&!i[0]) | (!i[12]&i[5]&!i[1]&i[0]) | (!i[15]&!i[13]&i[10]&!i[1]) | (
    !i[13]&!i[12]&i[7]&i[1]&!i[0]) | (i[12]&i[11]&!i[10]&!i[1]&i[0]) | (
    !i[15]&!i[13]&i[9]&!i[1]) | (!i[13]&!i[12]&i[4]&i[1]&!i[0]) | (i[13]
    &i[12]&!i[1]&i[0]) | (!i[15]&!i[13]&i[8]&!i[1]) | (!i[13]&!i[12]&i[3]
    &i[1]&!i[0]) | (i[13]&i[4]&!i[1]&i[0]) | (!i[13]&!i[12]&i[2]&i[1]
    &!i[0]) | (!i[15]&!i[13]&i[7]&!i[1]) | (i[13]&i[3]&!i[1]&i[0]) | (
    i[13]&i[2]&!i[1]&i[0]) | (i[14]&!i[13]&!i[1]) | (!i[14]&!i[12]&!i[1]
    &i[0]) | (i[15]&!i[13]&i[12]&i[1]&!i[0]) | (!i[15]&!i[13]&!i[12]&i[1]
    &!i[0]) | (!i[15]&!i[13]&i[12]&!i[1]) | (i[14]&!i[13]&!i[0]);


   

endmodule
