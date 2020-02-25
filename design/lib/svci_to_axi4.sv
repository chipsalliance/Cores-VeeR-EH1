// SPDX-License-Identifier: Apache-2.0
// Copyright 2018 Western Digital Corporation or it's affiliates.
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
// Owner:
// Function: SVCI to AXI4 Bridge
// Comments:
//
//********************************************************************************
module svci_to_axi4 #(parameter TAG  = 1,
                                ID   = 1,
                                PRTY = 1) (

   input  logic            clk,
   input  logic            rst_l,
   input  logic            scan_mode,
   input  logic            bus_clk_en,
   input  logic            clk_override,

   // AXI signals
   // AXI Write Channels
   output logic            axi_awvalid,
   input  logic            axi_awready,
   output logic            axi_awposted,
   output logic [TAG-1:0]  axi_awid,
   output logic [31:0]     axi_awaddr,
   output logic [2:0]      axi_awsize,
   output logic [2:0]      axi_awprot,
   output logic [7:0]      axi_awlen,
   output logic [1:0]      axi_awburst,
   output logic [ID-1:0]   axi_awmid,
   output logic [PRTY-1:0] axi_awprty,

   output logic            axi_wvalid,
   input  logic            axi_wready,
   output logic [63:0]     axi_wdata,
   output logic [7:0]      axi_wstrb,
   output logic            axi_wlast,

   input  logic            axi_bvalid,
   output logic            axi_bready,
   input  logic            axi_bposted,
   input  logic [1:0]      axi_bresp,
   input  logic [TAG-1:0]  axi_bid,
   input  logic [ID-1:0]   axi_bmid,
   input  logic [PRTY-1:0] axi_bprty,

   // AXI Read Channels
   output logic            axi_arvalid,
   input  logic            axi_arready,
   output logic [TAG-1:0]  axi_arid,
   output logic [31:0]     axi_araddr,
   output logic [2:0]      axi_arsize,
   output logic [2:0]      axi_arprot,
   output logic [7:0]      axi_arlen,
   output logic [1:0]      axi_arburst,
   output logic [ID-1:0]   axi_armid,
   output logic [PRTY-1:0] axi_arprty,

   input  logic            axi_rvalid,
   output logic            axi_rready,
   input  logic [TAG-1:0]  axi_rid,
   input  logic [63:0]     axi_rdata,
   input  logic [1:0]      axi_rresp,
   input  logic [ID-1:0]   axi_rmid,
   input  logic [PRTY-1:0] axi_rprty,

   // SVCI signals
   input logic             svci_cmd_valid,
   output logic            svci_cmd_ready,
   input logic [TAG-1:0]   svci_cmd_tag,
   input logic [ID-1:0]    svci_cmd_mid,
   input logic [31:0]      svci_cmd_addr,
   input logic [63:0]      svci_cmd_wdata,
   input logic [7:0]       svci_cmd_wbe,
   input logic [2:0]       svci_cmd_length,
   input logic [2:0]       svci_cmd_opc,
   input logic [PRTY-1:0]  svci_cmd_prty,
   input logic             dma_slv_algn_err,

   output logic            svci_rsp_valid,
   input logic             svci_rsp_ready,
   output logic [TAG-1:0]  svci_rsp_tag,
   output logic [ID-1:0]   svci_rsp_mid,
   output logic [63:0]     svci_rsp_rdata,
   output logic [3:0]      svci_rsp_opc,
   output logic [PRTY-1:0] svci_rsp_prty
);

   logic                   cmdbuf_wr_en, cmdbuf_data_en, cmdbuf_rst, cmdbuf_data_rst;
   logic                   cmdbuf_full;
   logic                   cmdbuf_vld, cmdbuf_data_vld;
   logic [2:0]             cmdbuf_opc, cmdbuf_size;
   logic [7:0]             cmdbuf_wstrb;
   logic [31:0]            cmdbuf_addr;
   logic [63:0]            cmdbuf_wdata;
   logic [TAG-1:0]         cmdbuf_tag;
   logic [ID-1:0]          cmdbuf_mid;
   logic [PRTY-1:0]        cmdbuf_prty;

   logic                   wrbuf_en, wrbuf_rst;
   logic                   wrbuf_vld;
   logic                   wrbuf_posted;
   logic [TAG-1:0]         wrbuf_tag;
   logic [ID-1:0]          wrbuf_mid;
   logic [1:0]             wrbuf_resp;
   logic [63:0]            error_address;    // SVCI needs the error address back on the rdata.
   logic [PRTY-1:0]        wrbuf_prty;

   logic [1:0]             axi_bresp_in;     // need to map 2 errors in to 3 errors
   logic                   bus_clk;

   // Command buffer
   assign cmdbuf_wr_en       = svci_cmd_valid & svci_cmd_ready;
   assign cmdbuf_data_en     = cmdbuf_wr_en & (svci_cmd_opc[2:1] == 2'b01);
   assign cmdbuf_rst         = ((axi_awvalid & axi_awready) | (axi_arvalid & axi_arready)) & ~cmdbuf_wr_en;
   assign cmdbuf_data_rst    = (axi_wvalid & axi_wready) & (cmdbuf_opc[2:1] == 2'b01) & ~cmdbuf_data_en;

   assign cmdbuf_full        = (cmdbuf_vld & ~((axi_awvalid & axi_awready) | (axi_arvalid & axi_arready))) | (cmdbuf_data_vld & ~((axi_wvalid & axi_wready) & (cmdbuf_opc[2:1] == 2'b01)));

   rvdffsc #(.WIDTH(1)) cmdbuf_vldff(.din(1'b1), .dout(cmdbuf_vld), .en(cmdbuf_wr_en), .clear(cmdbuf_rst), .clk(bus_clk), .*);
   rvdffsc #(.WIDTH(1)) cmdbuf_data_vldff(.din(1'b1), .dout(cmdbuf_data_vld), .en(cmdbuf_data_en), .clear(cmdbuf_data_rst), .clk(bus_clk), .*);
   rvdffs  #(.WIDTH(3)) cmdbuf_opcff(.din(svci_cmd_opc[2:0]), .dout(cmdbuf_opc[2:0]), .en(cmdbuf_wr_en), .clk(bus_clk), .*);
   rvdffs  #(.WIDTH(3)) cmdbuf_sizeff(.din(svci_cmd_length[2:0]), .dout(cmdbuf_size[2:0]), .en(cmdbuf_wr_en), .clk(bus_clk), .*);
   rvdffe  #(.WIDTH(8)) cmdbuf_wstrbff(.din(svci_cmd_wbe[7:0]), .dout(cmdbuf_wstrb[7:0]), .en(cmdbuf_wr_en & bus_clk_en), .*);
   rvdffe  #(.WIDTH(32)) cmdbuf_addrff(.din(svci_cmd_addr[31:0]), .dout(cmdbuf_addr[31:0]), .en(cmdbuf_wr_en & bus_clk_en), .*);
   rvdffe  #(.WIDTH(64)) cmdbuf_wdataff(.din(svci_cmd_wdata[63:0]), .dout(cmdbuf_wdata[63:0]), .en(cmdbuf_data_en & bus_clk_en), .*);
   rvdffs  #(.WIDTH(TAG)) cmdbuf_tagff(.din(svci_cmd_tag[TAG-1:0]), .dout(cmdbuf_tag[TAG-1:0]), .en(cmdbuf_wr_en), .clk(bus_clk), .*);
   rvdffs  #(.WIDTH(ID)) cmdbuf_midff(.din(svci_cmd_mid[ID-1:0]), .dout(cmdbuf_mid[ID-1:0]), .en(cmdbuf_wr_en), .clk(bus_clk), .*);
   rvdffs  #(.WIDTH(PRTY)) cmdbuf_prtyff(.din(svci_cmd_prty[PRTY-1:0]), .dout(cmdbuf_prty[PRTY-1:0]), .en(cmdbuf_wr_en), .clk(bus_clk), .*);

   // AXI Write Channels
   assign axi_awvalid       = cmdbuf_vld & (cmdbuf_opc[2:1] == 2'b01);
   assign axi_awposted      = axi_awvalid & ~cmdbuf_opc[0];
   assign axi_awid[TAG-1:0] = cmdbuf_tag[TAG-1:0];
   assign axi_awaddr[31:0]  = cmdbuf_addr[31:0];
   assign axi_awsize[2:0]   = cmdbuf_size[2:0];
   assign axi_awprot[2:0]   = 3'b0;
   assign axi_awlen[7:0]    = '0;
   assign axi_awburst[1:0]  = 2'b01;
   assign axi_awmid         = cmdbuf_mid[ID-1:0];
   assign axi_awprty        = cmdbuf_prty[PRTY-1:0];

   assign axi_wvalid      = cmdbuf_data_vld;
   assign axi_wdata[63:0] = cmdbuf_wdata[63:0];
   assign axi_wstrb[7:0]  = cmdbuf_wstrb[7:0];
   assign axi_wlast       = 1'b1;

   assign axi_bready      = ~wrbuf_vld | svci_rsp_ready;

   // AXI Read Channels
   assign axi_arvalid       = cmdbuf_vld & (cmdbuf_opc[2:0] == 3'b0);
   assign axi_arid[TAG-1:0] = cmdbuf_tag[TAG-1:0];
   assign axi_araddr[31:0]  = cmdbuf_addr[31:0];
   assign axi_arsize[2:0]   = cmdbuf_size[2:0];
   assign axi_arprot        = 3'b0;
   assign axi_arlen[7:0]    = '0;
   assign axi_arburst[1:0]  = 2'b01;
   assign axi_armid         = cmdbuf_mid[ID-1:0];
   assign axi_rready        = ~wrbuf_vld & svci_rsp_ready;
   assign axi_arprty        = cmdbuf_prty[PRTY-1:0];

   // SVCI_response signals
   assign svci_rsp_valid        = wrbuf_vld | axi_rvalid;
   assign svci_rsp_tag[TAG-1:0] = wrbuf_vld ? wrbuf_tag[TAG-1:0] : axi_rid[TAG-1:0];
   assign svci_rsp_mid[ID-1:0]  = wrbuf_vld ? wrbuf_mid[ID-1:0] : axi_rmid[ID-1:0];
   assign svci_rsp_rdata[63:0]  = wrbuf_vld ? {32'b0, error_address[31:0]} : axi_rdata[63:0];    // rdata
   assign svci_rsp_opc[3:2]     = wrbuf_vld ? {1'b1, ~wrbuf_posted} : 2'b0;
  // assign svci_rsp_opc[1:0]     = wrbuf_vld ? {wrbuf_resp[1] ? (wrbuf_resp[0] ? 2'b10 : 2'b01) : 2'b0}  :     // AXI Slave Error -> SVCI Slave Error, AXI Decode Error -> SVCI Address Error
  //                                           {axi_rresp[1] ? (axi_rresp[0] ? 2'b10 : 2'b01) : 2'b0};
   assign svci_rsp_opc[1:0]     = wrbuf_vld ? wrbuf_resp[1:0]  :     // AXI Slave Error -> SVCI Slave Error, AXI Decode Error -> SVCI Address Error
                                             {axi_rresp[1] ? (axi_rresp[0] ? 2'b10 : {dma_slv_algn_err, 1'b1}) : 2'b0};
   assign svci_rsp_prty[PRTY-1:0] = wrbuf_vld ? wrbuf_prty[PRTY-1:0] : axi_rprty[PRTY-1:0];

   assign svci_cmd_ready = ~cmdbuf_full;

   // Write Response Buffer. Errors for writes need to send the Error address back on the rsp_rdata for SVCI. The address is sent back on axi_rdata bus for both reads and writes that have errors.
  // assign wrbuf_en  = axi_bvalid & svci_rsp_ready & (~axi_bposted | axi_bresp[1]);
   assign wrbuf_en  = axi_bvalid & axi_bready & (~axi_bposted | axi_bresp[1]);
   assign wrbuf_rst = svci_rsp_valid & svci_rsp_ready & svci_rsp_opc[3] & ~wrbuf_en;
   assign axi_bresp_in[1:0] = {axi_bresp[1] ? (axi_bresp[0] ? 2'b10 : {dma_slv_algn_err, 1'b1}) : 2'b0};
   rvdffsc  #(.WIDTH(1))   wrbuf_vldff   (.din(1'b1), .dout(wrbuf_vld), .en(wrbuf_en), .clear(wrbuf_rst), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(32))  wrbuf_erroff  (.din(axi_rdata[31:0]), .dout(error_address[31:0]), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(1))   wrbuf_postedff(.din(axi_bposted), .dout(wrbuf_posted), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(TAG)) wrbuf_tagff   (.din(axi_bid[TAG-1:0]), .dout(wrbuf_tag[TAG-1:0]), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(ID))  wrbuf_midff   (.din(axi_bmid[ID-1:0]), .dout(wrbuf_mid[ID-1:0]), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(PRTY))wrbuf_prtyff  (.din(axi_bprty[PRTY-1:0]), .dout(wrbuf_prty[PRTY-1:0]), .en(wrbuf_en), .clk(bus_clk), .*);
   rvdffs   #(.WIDTH(2))   wrbuf_respff  (.din(axi_bresp_in[1:0]), .dout(wrbuf_resp[1:0]), .en(wrbuf_en), .clk(bus_clk), .*);

   // Clock header logic
   rvclkhdr bus_cgc        (.en(bus_clk_en),       .l1clk(bus_clk),       .*);

endmodule // svci_to_axi4

