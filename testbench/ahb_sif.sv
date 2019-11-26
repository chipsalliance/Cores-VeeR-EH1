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
//

module ahb_sif (
                  input logic [63:0] HWDATA,
                  input logic HCLK,
                  input logic HSEL,
                  input logic [3:0] HPROT,
                  input logic HWRITE,
                  input logic [1:0] HTRANS,
                  input logic [2:0] HSIZE,
                  input logic HREADY,
                  input logic HRESETn,
                  input logic [31:0] HADDR,
                  input logic [2:0] HBURST,

                  output logic HREADYOUT,
                  output logic HRESP,
                  output logic [63:0] HRDATA

);

localparam MEM_SIZE_DW = 8192;
localparam MAILBOX_ADDR = 32'hD0580000;

logic Last_HSEL;
logic NextLast_HSEL;
logic Last_HWRITE;
logic [1:0] Last_HTRANS;
logic [1:0] NextLast_HTRANS;
logic [31:0] Last_HADDR;
logic [63:0] Next_HRDATA;
logic [63:0] WriteReadData;
logic [63:0] WriteMask;

bit [7:0] mem [0:MEM_SIZE_DW-1];


// Wires
wire [63:0] Next_WriteMask =  HSIZE == 3'b000 ? (64'hff << {HADDR[2:0], 3'b000}) : (HSIZE == 3'b001 ? (64'hffff << {HADDR[2], 4'h0}) : (HSIZE == 3'b010 ? (64'hffff_ffff << {HADDR[3],5'h0}) : 64'hffff_ffff_ffff_ffff));

wire [63:0] MaskedWriteData     =  HWDATA & WriteMask;
wire [63:0] MaskedWriteReadData =  WriteReadData & ~WriteMask;
wire [63:0] WriteData           = (MaskedWriteData | MaskedWriteReadData );
wire Write                      = &{Last_HSEL,   Last_HWRITE, Last_HTRANS[1]};
wire Read                       = &{     HSEL,       ~HWRITE,      HTRANS[1]};

wire mailbox_write   = &{Write, Last_HADDR==MAILBOX_ADDR, HRESETn==1};
wire Next_HWRITE     = |{HTRANS} ? HWRITE : Last_HWRITE;
wire [63:0] mem_dout =  {mem[{Last_HADDR[12:3],3'b0}+7],mem[{Last_HADDR[12:3],3'b0}+6],mem[{Last_HADDR[12:3],3'b0}+5],mem[{Last_HADDR[12:3],3'b0}+4],mem[{Last_HADDR[12:3],3'b0}+3],mem[{Last_HADDR[12:3],3'b0}+2],mem[{Last_HADDR[12:3],3'b0}+1],mem[{Last_HADDR[12:3],3'b0}]};


always @ (posedge HCLK or negedge HRESETn) begin
  if (Write && Last_HADDR == 32'h0) begin
    mem[{Last_HADDR[12:3],3'b0}+7] <= #1 { WriteData[63:56] };
    mem[{Last_HADDR[12:3],3'b0}+6] <= #1 { WriteData[55:48] };
    mem[{Last_HADDR[12:3],3'b0}+5] <= #1 { WriteData[47:40] };
    mem[{Last_HADDR[12:3],3'b0}+4] <= #1 { WriteData[39:32] };
    mem[{Last_HADDR[12:3],3'b0}+3] <= #1 { WriteData[31:24] };
    mem[{Last_HADDR[12:3],3'b0}+2] <= #1 { WriteData[23:16] };
    mem[{Last_HADDR[12:3],3'b0}+1] <= #1 { WriteData[15:08] };
    mem[{Last_HADDR[12:3],3'b0}+0] <= #1 { WriteData[07:00] };
  end
end

always @(posedge HCLK or negedge HRESETn) begin
  if(~HRESETn) begin
    HREADYOUT   <= #1 1'b0 ;
    HRESP       <= #1 1'b0;
  end else begin
    HREADYOUT   <= #1 |HTRANS;
    HRESP       <= #1 1'b0;
    WriteMask   <= #1 Next_WriteMask;
  end
end

`ifdef VERILATOR
always @(posedge HCLK or negedge HRESETn) begin
`else
always @(negedge HCLK or negedge HRESETn) begin
`endif
  if(~HRESETn) begin
    Last_HADDR  <= #1 32'b0;
  end else begin
    Last_HADDR  <= #1  |{HTRANS} ? {HADDR[31:2], 2'b00}  : Last_HADDR;
  end
end

always @(posedge HCLK or negedge HRESETn) begin
  if(~HRESETn) begin
    Last_HWRITE <= #1 1'b0;
  end else begin
    Last_HWRITE <= #1 Next_HWRITE;
  end
end

always @(posedge HCLK or negedge HRESETn) begin
  if(~HRESETn) begin
    Last_HTRANS <= #1 2'b0;
  end else begin
    Last_HTRANS <= #1 HTRANS;
  end
end

always @(posedge HCLK or negedge HRESETn) begin
  if(~HRESETn) begin
    Last_HSEL <= #1 1'b0;
  end else begin
    Last_HSEL <= #1 HSEL;
  end
end


`ifndef VERILATOR

always @(posedge HCLK or negedge HRESETn) begin
  if(~HRESETn) begin
    HRDATA      <= #1 Next_HRDATA ;
  end else begin
    HRDATA      <= #1 Next_HRDATA ;
  end
end

always @* begin
  Next_HRDATA = mem_dout;
end

`else

always @(posedge HCLK) begin
  Next_HRDATA <= mem_dout;
end

assign HRDATA = mem_dout;

`endif


always @* begin
  if(Last_HSEL) begin
    WriteReadData[07:00] = mem[{Last_HADDR[12:3],3'b0}];
    WriteReadData[15:08] = mem[{Last_HADDR[12:3],3'b0}+1];
    WriteReadData[23:16] = mem[{Last_HADDR[12:3],3'b0}+2];
    WriteReadData[31:24] = mem[{Last_HADDR[12:3],3'b0}+3];
    WriteReadData[39:32] = mem[{Last_HADDR[12:3],3'b0}+4];
    WriteReadData[47:40] = mem[{Last_HADDR[12:3],3'b0}+5];
    WriteReadData[55:48] = mem[{Last_HADDR[12:3],3'b0}+6];
    WriteReadData[63:56] = mem[{Last_HADDR[12:3],3'b0}+7];
  end
end


endmodule
