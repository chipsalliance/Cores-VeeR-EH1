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
`ifndef VERILATOR
module tb_top;
`else
module tb_top ( input logic core_clk, input logic reset_l, output finished);
`endif

`ifndef VERILATOR
   logic                                reset_l;
   logic                                core_clk;
`endif
   logic                                nmi_int;

   logic        [31:0]                  reset_vector;
   logic        [31:0]                  nmi_vector;

   logic        [31:0]                  ic_haddr        ;
   logic        [2:0]                   ic_hburst       ;
   logic                                ic_hmastlock    ;
   logic        [3:0]                   ic_hprot        ;
   logic        [2:0]                   ic_hsize        ;
   logic        [1:0]                   ic_htrans       ;
   logic                                ic_hwrite       ;
   logic        [63:0]                  ic_hrdata       ;
   logic                                ic_hready       ;
   logic                                ic_hresp        ;

   logic        [31:0]                  lsu_haddr       ;
   logic        [2:0]                   lsu_hburst      ;
   logic                                lsu_hmastlock   ;
   logic        [3:0]                   lsu_hprot       ;
   logic        [2:0]                   lsu_hsize       ;
   logic        [1:0]                   lsu_htrans      ;
   logic                                lsu_hwrite      ;
   logic        [63:0]                  lsu_hrdata      ;
   logic        [63:0]                  lsu_hwdata      ;
   logic                                lsu_hready      ;
   logic                                lsu_hresp        ;

   logic        [31:0]                  sb_haddr        ;
   logic        [2:0]                   sb_hburst       ;
   logic                                sb_hmastlock    ;
   logic        [3:0]                   sb_hprot        ;
   logic        [2:0]                   sb_hsize        ;
   logic        [1:0]                   sb_htrans       ;
   logic                                sb_hwrite       ;

   logic        [63:0]                  sb_hrdata       ;
   logic        [63:0]                  sb_hwdata       ;
   logic                                sb_hready       ;
   logic                                sb_hresp        ;

   logic        [63:0]                  trace_rv_i_insn_ip;
   logic        [63:0]                  trace_rv_i_address_ip;
   logic        [2:0]                   trace_rv_i_valid_ip;
   logic        [2:0]                   trace_rv_i_exception_ip;
   logic        [4:0]                   trace_rv_i_ecause_ip;
   logic        [2:0]                   trace_rv_i_interrupt_ip;
   logic        [31:0]                  trace_rv_i_tval_ip;

   logic                                o_debug_mode_status;
   logic                                dec_tlu_perfcnt0;
   logic                                dec_tlu_perfcnt1;
   logic                                dec_tlu_perfcnt2;
   logic                                dec_tlu_perfcnt3;


   logic                                jtag_tdo;
   logic                                o_cpu_halt_ack;
   logic                                o_cpu_halt_status;
   logic                                o_cpu_run_ack;

   logic                                mailbox_write;
   logic        [63:0]                  dma_hrdata       ;
   logic        [63:0]                  dma_hwdata       ;
   logic                                dma_hready       ;
   logic                                dma_hresp        ;

   logic        [31:0]                  cycleCnt       ;
   logic                                mailbox_data_val;
   logic                                finished;
   //assign mailbox_write = &{i_ahb_lsu.Write, i_ahb_lsu.Last_HADDR==32'hD0580000, i_ahb_lsu.HRESETn==1};
   assign mailbox_write = i_ahb_lsu.mailbox_write;
   //assign mailbox_write = i_ahb_lsu.mailbox_write & !core_clk;
   assign mailbox_data_val = (i_ahb_lsu.WriteData[7:0] > 8'h5) & (i_ahb_lsu.WriteData[7:0] < 8'h7f);

   assign finished = finished | &{i_ahb_lsu.mailbox_write, (i_ahb_lsu.WriteData[7:0] == 8'hff)};

`ifndef VERILATOR
   `define FORCE force
`else
   `define FORCE 
`endif


   integer fd;
   initial begin
     fd = $fopen("console.log","w");
   end

   integer tp;

   always @(posedge core_clk or negedge reset_l) begin
     if( reset_l == 0)
         cycleCnt <= 0;
     else 
         cycleCnt <= cycleCnt+1;
   end

   always @(posedge core_clk) begin
      //if(cycleCnt == 32'h800)
        if(cycleCnt == 32'h800) begin
            $display ("Hit max cycle count.. stopping");
            $finish;
        end
   end


`ifdef VERILATOR
   always @(negedge mailbox_write)
`else
   always @(posedge mailbox_write)
`endif
     if( mailbox_data_val ) begin
           $fwrite(fd,"%c", i_ahb_lsu.WriteData[7:0]);
           $write("%c", i_ahb_lsu.WriteData[7:0]);
     end

   always @(posedge finished) begin
        $display("\n\nFinished : minstret = %0d, mcycle = %0d", rvtop.swerv.dec.tlu.minstretl[31:0],rvtop.swerv.dec.tlu.mcyclel[31:0]);
`ifndef VERILATOR
        $finish;
`endif
     end

   always @(posedge core_clk)
       if (rvtop.trace_rv_i_valid_ip !== 0) begin
        $fwrite(tp,"%b,%h,%h,%0h,%0h,3,%b,%h,%h,%b\n", rvtop.trace_rv_i_valid_ip, rvtop.trace_rv_i_address_ip[63:32], rvtop.trace_rv_i_address_ip[31:0], rvtop.trace_rv_i_insn_ip[63:32], rvtop.trace_rv_i_insn_ip[31:0],rvtop.trace_rv_i_exception_ip,rvtop.trace_rv_i_ecause_ip,rvtop.trace_rv_i_tval_ip,rvtop.trace_rv_i_interrupt_ip);
        end

   initial begin

`ifndef VERILATOR
     core_clk = 0;
`endif

     reset_vector = 32'h80000000;
     nmi_vector   = 32'hee000000;
     nmi_int   = 0;

`ifndef VERILATOR
     @(posedge core_clk);
     reset_l = 0;
`endif

     $readmemh("data.hex",     i_ahb_lsu.mem);
     $readmemh("program.hex",  i_ahb_ic.mem);
     tp = $fopen("trace_port.csv","w");

`ifndef VERILATOR
     repeat (5) @(posedge core_clk);
     reset_l = 1;
     #100000 $display("");$finish;
`endif
   end

`ifndef VERILATOR
initial begin
   forever  begin 
     core_clk = #5 ~core_clk;
   end
end
`endif

   //=========================================================================-
   // RTL instance
   //=========================================================================-
   swerv_wrapper rvtop (
            .rst_l              ( reset_l       ),
            .clk                ( core_clk      ),
            .rst_vec            ( 31'h40000000  ),
            .nmi_int            ( nmi_int       ),
            .nmi_vec            ( 31'h77000000  ),

            .haddr              ( ic_haddr      ),
            .hburst             ( ic_hburst     ),
            .hmastlock          ( ic_hmastlock  ),
            .hprot              ( ic_hprot      ),
            .hsize              ( ic_hsize      ),
            .htrans             ( ic_htrans     ),
            .hwrite             ( ic_hwrite     ),

            .hrdata             ( ic_hrdata[63:0]),
            .hready             ( ic_hready     ),
            .hresp              ( ic_hresp      ),

           //---------------------------------------------------------------
           // Debug AHB Master
           //---------------------------------------------------------------
           .sb_haddr            ( sb_haddr      ),
           .sb_hburst           ( sb_hburst     ),
           .sb_hmastlock        ( sb_hmastlock  ),
           .sb_hprot            ( sb_hprot      ),
           .sb_hsize            ( sb_hsize      ),
           .sb_htrans           ( sb_htrans     ),
           .sb_hwrite           ( sb_hwrite     ),
           .sb_hwdata           ( sb_hwdata     ),

           .sb_hrdata           ( sb_hrdata     ),
           .sb_hready           ( sb_hready     ),
           .sb_hresp            ( sb_hresp      ),


            //---------------------------------------------------------------
            // LSU AHB Master
            //---------------------------------------------------------------
            .lsu_haddr     ( lsu_haddr       ),
            .lsu_hburst    ( lsu_hburst      ),
            .lsu_hmastlock ( lsu_hmastlock   ),
            .lsu_hprot     ( lsu_hprot       ),
            .lsu_hsize     ( lsu_hsize       ),
            .lsu_htrans    ( lsu_htrans      ),
            .lsu_hwrite    ( lsu_hwrite      ),
            .lsu_hwdata    ( lsu_hwdata      ),

            .lsu_hrdata    ( lsu_hrdata[63:0]),
            .lsu_hready    ( lsu_hready      ),
            .lsu_hresp     ( lsu_hresp       ),


           //---------------------------------------------------------------
           // DMA Slave
           //---------------------------------------------------------------
           .dma_haddr           ( '0     ),
           .dma_hburst          ( '0    ),
           .dma_hmastlock       ( '0 ),
           .dma_hprot           ( '0     ),
           .dma_hsize           ( '0     ),
           .dma_htrans          ( '0    ),
           .dma_hwrite          ( '0    ),
           .dma_hwdata          ( '0    ),

           .dma_hrdata          ( dma_hrdata    ),
           .dma_hready          ( dma_hready    ),
           .dma_hresp           ( dma_hresp     ),

           .timer_int           ( 1'b0     ),
           `ifdef TB_RESTRUCT
           .extintsrc_req       ( '0  ),
           `else
           .extintsrc_req       ( '0  ),
           `endif

           `ifdef RV_BUILD_AHB_LITE
           .lsu_bus_clk_en ( 1'b1  ),// Clock ratio b/w cpu core clk & AHB master interface
           .ifu_bus_clk_en ( 1'b1  ),// Clock ratio b/w cpu core clk & AHB master interface
           .dbg_bus_clk_en ( 1'b0  ),// Clock ratio b/w cpu core clk & AHB Debug master interface
           .dma_bus_clk_en ( 1'b0  ),// Clock ratio b/w cpu core clk & AHB slave interface
           `endif

           .trace_rv_i_insn_ip(trace_rv_i_insn_ip),
           .trace_rv_i_address_ip(trace_rv_i_address_ip),
           .trace_rv_i_valid_ip(trace_rv_i_valid_ip),
           .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
           .trace_rv_i_ecause_ip(trace_rv_i_ecause_ip),
           .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
           .trace_rv_i_tval_ip(trace_rv_i_tval_ip),





           .jtag_tck            ( 1'b0  ),          // JTAG clk
           .jtag_tms            ( 1'b0  ),          // JTAG TMS
           .jtag_tdi            ( 1'b0  ),          // JTAG tdi
           .jtag_trst_n         ( 1'b0  ),       // JTAG Reset
           .jtag_tdo            ( jtag_tdo ),          // JTAG TDO
           .i_cpu_halt_req      ( 1'b0  ),    // Async halt req to CPU
           .o_cpu_halt_ack      ( o_cpu_halt_ack ),    // core response to halt
           .o_cpu_halt_status   ( o_cpu_halt_status ), // 1'b1 indicates core is halted
           .i_cpu_run_req       ( 1'b0  ),     // Async restart req to CPU
           .o_debug_mode_status (o_debug_mode_status),
           .o_cpu_run_ack       ( o_cpu_run_ack ),     // Core response to run req

           .dec_tlu_perfcnt0(dec_tlu_perfcnt0),
           .dec_tlu_perfcnt1(dec_tlu_perfcnt1),
           .dec_tlu_perfcnt2(dec_tlu_perfcnt2),
           .dec_tlu_perfcnt3(dec_tlu_perfcnt3),

           .scan_mode           ( 1'b0 ),         // To enable scan mode
           .mbist_mode          ( 1'b0 )        // to enable mbist

         );

initial begin
  `FORCE rvtop.dccm_rd_data_hi = '0;
  `FORCE rvtop.dccm_rd_data_lo = '0;
end


   //=========================================================================-
   // AHB I$ instance
   //=========================================================================-

   ahb_sif i_ahb_ic (

     // Inputs
     .HWDATA(64'h0),
     .HCLK(core_clk),
     .HSEL(1'b1),
     .HPROT(ic_hprot),
     .HWRITE(ic_hwrite),
     .HTRANS(ic_htrans),
     .HSIZE(ic_hsize),
     .HREADY(ic_hready),
     .HRESETn(reset_l),
     .HADDR(ic_haddr),
     .HBURST(ic_hburst),

     // Outputs
     .HREADYOUT(ic_hready),
     .HRESP(ic_hresp),
     .HRDATA(ic_hrdata[63:0])

     );


   ahb_sif i_ahb_lsu (

     // Inputs
     .HWDATA(lsu_hwdata),
     .HCLK(core_clk),
     .HSEL(1'b1),
     .HPROT(lsu_hprot),
     .HWRITE(lsu_hwrite),
     .HTRANS(lsu_htrans),
     .HSIZE(lsu_hsize),
     .HREADY(lsu_hready),
     .HRESETn(reset_l),
     .HADDR(lsu_haddr),
     .HBURST(lsu_hburst),

     // Outputs
     .HREADYOUT(lsu_hready),
     .HRESP(lsu_hresp),
     .HRDATA(lsu_hrdata[63:0])

     );

   ahb_sif i_ahb_sb (

     // Inputs
     .HWDATA(sb_hwdata),
     .HCLK(core_clk),
     .HSEL(1'b1),
     .HPROT(sb_hprot),
     .HWRITE(sb_hwrite),
     .HTRANS(sb_htrans),
     .HSIZE(sb_hsize),
     .HREADY(1'b0),
     .HRESETn(reset_l),
     .HADDR(sb_haddr),
     .HBURST(sb_hburst),

     // Outputs
     .HREADYOUT(sb_hready),
     .HRESP(sb_hresp),
     .HRDATA(sb_hrdata[63:0])

     );


endmodule
