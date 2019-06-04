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
// limitations under the License
// //------------------------------------------------------------------------------------
//
//  Copyright Western Digital, 2019
//  Owner : Anusha Narayanamoorthy
//  Description:  
//                Toggle synchronizer
//
//-------------------------------------------------------------------------------------

module toggle_sync(
  input  src_rst_n,  // Source reset
  input  src_clk,  // Source clock
  input  dst_clk,  // Destination clock 
  input  dst_rst_n,  // Destination reset
  input  src_enb,  // Enable signal in Source clock domain
  output  dst_enb  // Enable signal in destination clock domain
);


// Reg declaration
reg  tgle_s_en;
reg  d3_en;

// Wire Declararation
wire dble_flp_en;


  // Latching the enable signal in Source clock domain
  always @ (posedge src_clk or negedge src_rst_n)
    if(!src_rst_n)
      tgle_s_en <= 1'b0;
    else if (src_enb)
      tgle_s_en <= ~tgle_s_en;

  // Instantiation of Double flop synchronizer
  double_flop_sync i_double_flop_sync(
    .clk(dst_clk),
    .rst_n(dst_rst_n),
    .inp(tgle_s_en),
    .op(dble_flp_en)
);



  // Triple flop the enable signal in the Destination clock domain
  always @ (posedge dst_clk or negedge dst_rst_n)
    if(!dst_rst_n)
      d3_en <= 1'b0;
    else
      d3_en <= dble_flp_en;


  assign dst_enb =  dble_flp_en ^ d3_en;

endmodule
