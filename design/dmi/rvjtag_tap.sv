// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or it's affiliates.
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

module rvjtag_tap #(
parameter AWIDTH = 7
)
(
input               trst,
input               tck,
input               tms,
input               tdi,
output   reg        tdo,
output              tdoEnable,

output [31:0]       wr_data,
output [AWIDTH-1:0] wr_addr,
output              wr_en,
output              rd_en,

input   [31:0]      rd_data,
input   [1:0]       rd_status,

output  reg         dmi_reset,
output  reg         dmi_hard_reset,

input   [2:0]       idle,
input   [1:0]       dmi_stat,
/*
--  revisionCode        : 4'h0;
--  manufacturersIdCode : 11'h45;
--  deviceIdCode        : 16'h0001;
--  order MSB .. LSB -> [4 bit version or revision] [16 bit part number] [11 bit manufacturer id] [value of 1'b1 in LSB]
*/
input   [31:1]      jtag_id,
input   [3:0]       version
);

localparam USER_DR_LENGTH = AWIDTH + 34;


reg [USER_DR_LENGTH-1:0] sr, nsr, dr;

///////////////////////////////////////////////////////
//                      Tap controller
///////////////////////////////////////////////////////
logic[3:0] state, nstate;
logic [4:0] ir;
wire jtag_reset;
wire shift_dr;
wire pause_dr;
wire update_dr;
wire capture_dr;
wire shift_ir;
wire pause_ir ;
wire update_ir ;
wire capture_ir;
wire[1:0] dr_en;
wire devid_sel;
wire [5:0] abits;

assign abits = AWIDTH[5:0];


localparam TEST_LOGIC_RESET_STATE = 0;
localparam RUN_TEST_IDLE_STATE    = 1;
localparam SELECT_DR_SCAN_STATE   = 2;
localparam CAPTURE_DR_STATE       = 3;
localparam SHIFT_DR_STATE         = 4;
localparam EXIT1_DR_STATE         = 5;
localparam PAUSE_DR_STATE         = 6;
localparam EXIT2_DR_STATE         = 7;
localparam UPDATE_DR_STATE        = 8;
localparam SELECT_IR_SCAN_STATE   = 9;
localparam CAPTURE_IR_STATE       = 10;
localparam SHIFT_IR_STATE         = 11;
localparam EXIT1_IR_STATE         = 12;
localparam PAUSE_IR_STATE         = 13;
localparam EXIT2_IR_STATE         = 14;
localparam UPDATE_IR_STATE        = 15;

always_comb  begin
    nstate = state;
    case(state)
    TEST_LOGIC_RESET_STATE: nstate = tms ? TEST_LOGIC_RESET_STATE : RUN_TEST_IDLE_STATE;
    RUN_TEST_IDLE_STATE:    nstate = tms ? SELECT_DR_SCAN_STATE   : RUN_TEST_IDLE_STATE;
    SELECT_DR_SCAN_STATE:   nstate = tms ? SELECT_IR_SCAN_STATE   : CAPTURE_DR_STATE;
    CAPTURE_DR_STATE:       nstate = tms ? EXIT1_DR_STATE         : SHIFT_DR_STATE;
    SHIFT_DR_STATE:         nstate = tms ? EXIT1_DR_STATE         : SHIFT_DR_STATE;
    EXIT1_DR_STATE:         nstate = tms ? UPDATE_DR_STATE        : PAUSE_DR_STATE;
    PAUSE_DR_STATE:         nstate = tms ? EXIT2_DR_STATE         : PAUSE_DR_STATE;
    EXIT2_DR_STATE:         nstate = tms ? UPDATE_DR_STATE        : SHIFT_DR_STATE;
    UPDATE_DR_STATE:        nstate = tms ? SELECT_DR_SCAN_STATE   : RUN_TEST_IDLE_STATE;
    SELECT_IR_SCAN_STATE:   nstate = tms ? TEST_LOGIC_RESET_STATE : CAPTURE_IR_STATE;
    CAPTURE_IR_STATE:       nstate = tms ? EXIT1_IR_STATE         : SHIFT_IR_STATE;
    SHIFT_IR_STATE:         nstate = tms ? EXIT1_IR_STATE         : SHIFT_IR_STATE;
    EXIT1_IR_STATE:         nstate = tms ? UPDATE_IR_STATE        : PAUSE_IR_STATE;
    PAUSE_IR_STATE:         nstate = tms ? EXIT2_IR_STATE         : PAUSE_IR_STATE;
    EXIT2_IR_STATE:         nstate = tms ? UPDATE_IR_STATE        : SHIFT_IR_STATE;
    UPDATE_IR_STATE:        nstate = tms ? SELECT_DR_SCAN_STATE   : RUN_TEST_IDLE_STATE;
    default:                nstate = TEST_LOGIC_RESET_STATE;
    endcase
end

always @ (posedge tck or negedge trst) begin
    if(!trst) state <= TEST_LOGIC_RESET_STATE;
    else state <= nstate;
end

assign jtag_reset = state == TEST_LOGIC_RESET_STATE;
assign shift_dr   = state == SHIFT_DR_STATE;
assign pause_dr   = state == PAUSE_DR_STATE;
assign update_dr  = state == UPDATE_DR_STATE;
assign capture_dr = state == CAPTURE_DR_STATE;
assign shift_ir   = state == SHIFT_IR_STATE;
assign pause_ir   = state == PAUSE_IR_STATE;
assign update_ir  = state == UPDATE_IR_STATE;
assign capture_ir = state == CAPTURE_IR_STATE;

assign tdoEnable = shift_dr | shift_ir;

///////////////////////////////////////////////////////
//                      IR register
///////////////////////////////////////////////////////

always @ (negedge tck or negedge trst) begin
   if (!trst) ir <= 5'b1;
   else begin
      if (jtag_reset) ir <= 5'b1;
      else if (update_ir) ir <= (sr[4:0] == '0) ? 5'h1f :sr[4:0];
   end
end


assign devid_sel  = ir == 5'b00001;
assign dr_en[0]   = ir == 5'b10000;
assign dr_en[1]   = ir == 5'b10001;

///////////////////////////////////////////////////////
//                      Shift register
///////////////////////////////////////////////////////
always @ (posedge tck or negedge trst) begin
    if(!trst)begin
        sr <= '0;
    end
    else begin
        sr <= nsr;
    end
end

// SR next value
always_comb begin
    nsr = sr;
    case(1)
    shift_dr:   begin
                    case(1)
                    dr_en[1]:   nsr = {tdi, sr[USER_DR_LENGTH-1:1]};

                    dr_en[0],
                    devid_sel:  nsr = {{USER_DR_LENGTH-32{1'b0}},tdi, sr[31:1]};
                    default:    nsr = {{USER_DR_LENGTH-1{1'b0}},tdi}; // bypass
                    endcase
                end
    capture_dr: begin
                    nsr[0] = 1'b0;
                    case(1)
                    dr_en[0]:   nsr = {{USER_DR_LENGTH-15{1'b0}}, idle, dmi_stat, abits, version};
                    dr_en[1]:   nsr = {{AWIDTH{1'b0}}, rd_data, rd_status};
                    devid_sel:  nsr = {{USER_DR_LENGTH-32{1'b0}}, jtag_id, 1'b1};
                    endcase
                end
    shift_ir:   nsr = {{USER_DR_LENGTH-5{1'b0}},tdi, sr[4:1]};
    capture_ir: nsr = {{USER_DR_LENGTH-1{1'b0}},1'b1};
    endcase
end

// TDO retiming
always @ (negedge tck ) tdo <= sr[0];

// DMI CS register
always @ (posedge tck or negedge trst) begin
    if(!trst) begin
        dmi_hard_reset <= 1'b0;
        dmi_reset      <= 1'b0;
    end
    else if (update_dr & dr_en[0]) begin
        dmi_hard_reset <= sr[17];
        dmi_reset      <= sr[16];
    end
    else begin
        dmi_hard_reset <= 1'b0;
        dmi_reset      <= 1'b0;
    end
end

// DR register
always @ (posedge tck or negedge trst) begin
    if(!trst)
        dr <=  '0;
    else begin
        if (update_dr & dr_en[1])
            dr <= sr;
        else
            dr <= {dr[USER_DR_LENGTH-1:2],2'b0};
    end
end

assign {wr_addr, wr_data, wr_en, rd_en} = dr;




endmodule
