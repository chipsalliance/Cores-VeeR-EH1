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
//------------------------------------------------------------------------------------
//
//  Copyright Western Digital, 2019
//  Owner : Anusha Narayanamoorthy
//  Description:  
//                Double flop synchronizer
//
//-------------------------------------------------------------------------------------


module double_flop_sync (
  input            clk,     // Input clock
  input            rst_n,   // Input reset
  input            inp,     // Input singal
  output reg       op       // Double flopped output signal
);

reg       d_inp;


  // Flop the enable signal in the Destination clock domain
  always @ (posedge clk or negedge rst_n)
    if(!rst_n)
      d_inp <= 1'b0;
    else
      d_inp <= inp;



  // Double flop the enable signal in the Destination clock domain
  always @ (posedge clk or negedge rst_n)
    if(!rst_n)
      op <= 1'b0;
    else
      op <= d_inp;


endmodule
