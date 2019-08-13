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

//=========================================================================================================================
//=================================== START OF CCM  =======================================================================
//============= Possible sram sizes for a 39 bit wide memory ( 4 bytes + 7 bits ECC ) =====================================
//-------------------------------------------------------------------------------------------------------------------------
module ram_32768x39 
  ( input logic CLK,
    input logic [14:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [32767:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_32768x39


module ram_16384x39 
  ( input logic CLK,
    input logic [13:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [16383:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_16384x39

module ram_8192x39 
  ( input logic CLK,
    input logic [12:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [8191:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_8192x39

module ram_4096x39 
  ( input logic CLK,
    input logic [11:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [4095:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_4096x39

module ram_3072x39 
  ( input logic CLK,
    input logic [11:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [3071:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_3072x39



module ram_2048x39 
  ( input logic CLK,
    input logic [10:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [2047:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_2048x39

module ram_1536x39     // need this for the 48KB DCCM option
  ( input logic CLK,
    input logic [10:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [1535:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_1536x39


module ram_1024x39 
  ( input logic CLK,
    input logic [9:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [1023:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_1024x39

module ram_768x39 
  ( input logic CLK,
    input logic [9:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [767:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_768x39


module ram_512x39 
  ( input logic CLK,
    input logic [8:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [511:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_512x39


module ram_256x39 
  ( input logic CLK,
    input logic [7:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [255:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_512x39


module ram_128x39 
  ( input logic CLK,
    input logic [6:0] ADR,
    input logic [38:0] D,

    output logic [38:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [38:0]   ram_core [127:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   


endmodule // ram_128x39

//=========================================================================================================================
//=================================== START OF TAGS =======================================================================
// I CACHE TAGS
module ram_1024x20 
  ( input logic CLK,

    input logic [9:0] ADR,
    input logic [19:0] D,

    output logic [19:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [19:0]   ram_core [1023:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end

   

endmodule // ram_1024x20

module ram_512x20 
  ( input logic CLK,
    input logic [8:0] ADR,
    input logic [19:0] D,

    output logic [19:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [19:0]   ram_core [511:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end




endmodule // ram_512x20

module ram_256x20 
  ( input logic CLK,
    input logic [7:0] ADR,
    input logic [19:0] D,

    output logic [19:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [19:0]   ram_core [255:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end



endmodule // ram_256x20

module ram_128x20 
  ( input logic CLK,
    input logic [6:0] ADR,
    input logic [19:0] D,

    output logic [19:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [19:0]   ram_core [127:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end




endmodule // ram_128x20

module ram_64x20 
  ( input logic CLK,
    input logic [5:0] ADR,
    input logic [19:0] D,

    output logic [19:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [19:0]   ram_core [63:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end




endmodule // ram_64x20

// LATEST ICACHE MEMORIES


// 4096 x 34
module ram_4096x34 
  ( input logic CLK,
    input logic [11:0] ADR,
    input logic [33:0] D,

    output logic [33:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [33:0]   ram_core [4095:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_4096x34

// 2048x34   
module ram_2048x34 
  ( input logic CLK,
    input logic [10:0] ADR,
    input logic [33:0] D,

    output logic [33:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [33:0]   ram_core [2047:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_2048x34

// 1024x34   
module ram_1024x34 
  ( input logic CLK,
    input logic [9:0] ADR,
    input logic [33:0] D,

    output logic [33:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [33:0]   ram_core [1023:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_1024x34

// 512x34   
module ram_512x34 
  ( input logic CLK,
    input logic [8:0] ADR,
    input logic [33:0] D,

    output logic [33:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [33:0]   ram_core [511:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_512x34

// 256x34   
module ram_256x34 
  ( input logic CLK,
    input logic [7:0] ADR,
    input logic [33:0] D,

    output logic [33:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [33:0]   ram_core [255:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_256x34

// 128x34   
module ram_128x34 
  ( input logic CLK,
    input logic [6:0] ADR,
    input logic [33:0] D,

    output logic [33:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [33:0]   ram_core [127:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end




endmodule // ram_128x34

// 64x34   
module ram_64x34 
  ( input logic CLK,
    input logic [5:0] ADR,
    input logic [33:0] D,

    output logic [33:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [33:0]   ram_core [63:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end




endmodule // ram_64x34

// New SRAMS for ECC; ECC on 16b boundaries

// 4096x44   
module ram_4096x42 
  ( input logic CLK,
    input logic [11:0] ADR,
    input logic [41:0] D,

    output logic [41:0] Q,
  
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [41:0]   ram_core [4095:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end




endmodule // ram_4096x42


// 2048x44   
module ram_2048x42 
  ( input logic CLK,
    input logic [10:0] ADR,
    input logic [41:0] D,

    output logic [41:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [41:0]   ram_core [2047:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end




endmodule // ram_2048x42

// 1024x44   
module ram_1024x42 
  ( input logic CLK,
    input logic [9:0] ADR,
    input logic [41:0] D,

    output logic [41:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [41:0]   ram_core [1023:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end



endmodule // ram_1024x42


// 512x44   
module ram_512x42 
  ( input logic CLK,
    input logic [8:0] ADR,
    input logic [41:0] D,

    output logic [41:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [41:0]   ram_core [511:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_512x42


// 256x42   
module ram_256x42 
  ( input logic CLK,
    input logic [7:0] ADR,
    input logic [41:0] D,

    output logic [41:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [41:0]   ram_core [255:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_256x42

// 128x42   
module ram_128x42 
  ( input logic CLK,
    input logic [6:0] ADR,
    input logic [41:0] D,

    output logic [41:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [41:0]   ram_core [127:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_128x42

// 64x42   
module ram_64x42 
  ( input logic CLK,
    input logic [5:0] ADR,
    input logic [41:0] D,

    output logic [41:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [41:0]   ram_core [63:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


endmodule // ram_64x42


/// END DATA

// START TAGS

// 1024x21   
module ram_1024x21 
  ( input logic CLK,
    input logic [9:0] ADR,
    input logic [20:0] D,

    output logic [20:0] Q,

    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [20:0]   ram_core [1023:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end



endmodule // ram_1024x21

// 512x21   
module ram_512x21 
  ( input logic CLK,
    input logic [8:0] ADR,
    input logic [20:0] D,

    output logic [20:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [20:0]   ram_core [511:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_512x21

// 256x21   
module ram_256x21 
  ( input logic CLK,
    input logic [7:0] ADR,
    input logic [20:0] D,

    output logic [20:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE 

   reg [20:0]   ram_core [255:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_256x21

// 128x21   
module ram_128x21 
  ( input logic CLK,
    input logic [6:0] ADR,
    input logic [20:0] D,

    output logic [20:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [20:0]   ram_core [127:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_128x21

// 64x21   
module ram_64x21 
  ( input logic CLK,
    input logic [5:0] ADR,
    input logic [20:0] D,

    output logic [20:0] Q,
    input logic WE );

   // behavior to be replaced by actual SRAM in VLE

   reg [20:0]   ram_core [63:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


endmodule // ram_64x21

// New tag rams for ECC. 

// 1024x25  
module ram_1024x25 
  ( input logic CLK,
    input logic [9:0] ADR,
    input logic [24:0] D,

    output logic [24:0] Q,
    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [24:0]   ram_core [1023:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_1024x25

// 512x25   
module ram_512x25 
  ( input logic CLK,
    input logic [8:0] ADR,
    input logic [24:0] D,

    output logic [24:0] Q,

    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [24:0]   ram_core [511:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_512x25

// 256x25   
module ram_256x25 
  ( input logic CLK,
    input logic [7:0] ADR,
    input logic [24:0] D,

    output logic [24:0] Q,

    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE 

   reg [24:0]   ram_core [255:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_256x25

// 128x25   
module ram_128x25 
  ( input logic CLK,
    input logic [6:0] ADR,
    input logic [24:0] D,

    output logic [24:0] Q,

    input logic WE );
   
   // behavior to be replaced by actual SRAM in VLE

   reg [24:0]   ram_core [127:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_128x25

// 64x25   
module ram_64x25 
  ( input logic CLK,
    input logic [5:0] ADR,
    input logic [24:0] D,

    output logic [24:0] Q,

    input logic WE );

   // behavior to be replaced by actual SRAM in VLE

   reg [24:0]   ram_core [63:0];

   always_ff @(posedge CLK) begin
      if (WE) begin// for active high WE - must be specified by user
         ram_core[ADR] <= D; Q <= 'x; end else
           Q <= ram_core[ADR];
   end


   


endmodule // ram_64x25
