// argv=9
// TOTAL_INT=9 NUM_LEVELS=4
`ifdef RV_PIC_2CYCLE
// LEVEL0
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] level_intpend_w_prior_en_1;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] level_intpend_id_1;
    for (m=0; m<=(TOTAL_INT)/(2**(1)) ; m++) begin : COMPARE0
       if ( m == (TOTAL_INT)/(2**(1))) begin
            assign level_intpend_w_prior_en_1[m+1] = '0 ;
            assign level_intpend_id_1[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l1 (
                      .a_id(level_intpend_id[0][2*m]),
                      .a_priority(level_intpend_w_prior_en[0][2*m]),
                      .b_id(level_intpend_id[0][2*m+1]),
                      .b_priority(level_intpend_w_prior_en[0][2*m+1]),
                      .out_id(level_intpend_id_1[m]),
                      .out_priority(level_intpend_w_prior_en_1[m])) ;

 end

// LEVEL1
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] level_intpend_w_prior_en_2;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] level_intpend_id_2;
    for (m=0; m<=(TOTAL_INT)/(2**(2)) ; m++) begin : COMPARE1
       if ( m == (TOTAL_INT)/(2**(2))) begin
            assign level_intpend_w_prior_en_2[m+1] = '0 ;
            assign level_intpend_id_2[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l2 (
                      .a_id(level_intpend_id_1[2*m]),
                      .a_priority(level_intpend_w_prior_en_1[2*m]),
                      .b_id(level_intpend_id_1[2*m+1]),
                      .b_priority(level_intpend_w_prior_en_1[2*m+1]),
                      .out_id(level_intpend_id_2[m]),
                      .out_priority(level_intpend_w_prior_en_2[m])) ;

 end

for (i=0; i<=TOTAL_INT/2**(NUM_LEVELS/2) ; i++) begin : MIDDLE_FLOPS
  rvdff #(INTPRIORITY_BITS) level2_intpend_prior_reg  (.*, .din (level_intpend_w_prior_en_2[i]), .dout(l2_intpend_w_prior_en_ff[i]),  .clk(active_clk));
  rvdff #(ID_BITS)          level2_intpend_id_reg     (.*, .din (level_intpend_id_2[i]),         .dout(l2_intpend_id_ff[i]),          .clk(active_clk));
end
// LEVEL2
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] levelx_intpend_w_prior_en_3;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] levelx_intpend_id_3;
    for (m=0; m<=(TOTAL_INT)/(2**(3)) ; m++) begin : COMPARE2
       if ( m == (TOTAL_INT)/(2**(3))) begin
            assign levelx_intpend_w_prior_en_3[m+1] = '0 ;
            assign levelx_intpend_id_3[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l3 (
                      .a_id(levelx_intpend_id[2][2*m]),
                      .a_priority(levelx_intpend_w_prior_en[2][2*m]),
                      .b_id(levelx_intpend_id[2][2*m+1]),
                      .b_priority(levelx_intpend_w_prior_en[2][2*m+1]),
                      .out_id(levelx_intpend_id_3[m]),
                      .out_priority(levelx_intpend_w_prior_en_3[m])) ;

 end

// LEVEL3
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] levelx_intpend_w_prior_en_4;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] levelx_intpend_id_4;
    for (m=0; m<=(TOTAL_INT)/(2**(4)) ; m++) begin : COMPARE3
       if ( m == (TOTAL_INT)/(2**(4))) begin
            assign levelx_intpend_w_prior_en_4[m+1] = '0 ;
            assign levelx_intpend_id_4[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l4 (
                      .a_id(levelx_intpend_id_3[2*m]),
                      .a_priority(levelx_intpend_w_prior_en_3[2*m]),
                      .b_id(levelx_intpend_id_3[2*m+1]),
                      .b_priority(levelx_intpend_w_prior_en_3[2*m+1]),
                      .out_id(levelx_intpend_id_4[m]),
                      .out_priority(levelx_intpend_w_prior_en_4[m])) ;

 end

assign claimid_in[ID_BITS-1:0]                      =      levelx_intpend_id_4[0] ;   // This is the last level output
assign selected_int_priority[INTPRIORITY_BITS-1:0]  =      levelx_intpend_w_prior_en_4[0] ;
`else
// LEVEL0
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] level_intpend_w_prior_en_1;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] level_intpend_id_1;
    for (m=0; m<=(TOTAL_INT)/(2**(1)) ; m++) begin : COMPARE0
       if ( m == (TOTAL_INT)/(2**(1))) begin
            assign level_intpend_w_prior_en_1[m+1] = '0 ;
            assign level_intpend_id_1[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l1 (
                      .a_id(level_intpend_id[0][2*m]),
                      .a_priority(level_intpend_w_prior_en[0][2*m]),
                      .b_id(level_intpend_id[0][2*m+1]),
                      .b_priority(level_intpend_w_prior_en[0][2*m+1]),
                      .out_id(level_intpend_id_1[m]),
                      .out_priority(level_intpend_w_prior_en_1[m])) ;

 end

// LEVEL1
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] level_intpend_w_prior_en_2;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] level_intpend_id_2;
    for (m=0; m<=(TOTAL_INT)/(2**(2)) ; m++) begin : COMPARE1
       if ( m == (TOTAL_INT)/(2**(2))) begin
            assign level_intpend_w_prior_en_2[m+1] = '0 ;
            assign level_intpend_id_2[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l2 (
                      .a_id(level_intpend_id_1[2*m]),
                      .a_priority(level_intpend_w_prior_en_1[2*m]),
                      .b_id(level_intpend_id_1[2*m+1]),
                      .b_priority(level_intpend_w_prior_en_1[2*m+1]),
                      .out_id(level_intpend_id_2[m]),
                      .out_priority(level_intpend_w_prior_en_2[m])) ;

 end

// LEVEL2
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] level_intpend_w_prior_en_3;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] level_intpend_id_3;
    for (m=0; m<=(TOTAL_INT)/(2**(3)) ; m++) begin : COMPARE2
       if ( m == (TOTAL_INT)/(2**(3))) begin
            assign level_intpend_w_prior_en_3[m+1] = '0 ;
            assign level_intpend_id_3[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l3 (
                      .a_id(level_intpend_id_2[2*m]),
                      .a_priority(level_intpend_w_prior_en_2[2*m]),
                      .b_id(level_intpend_id_2[2*m+1]),
                      .b_priority(level_intpend_w_prior_en_2[2*m+1]),
                      .out_id(level_intpend_id_3[m]),
                      .out_priority(level_intpend_w_prior_en_3[m])) ;

 end

// LEVEL3
logic [TOTAL_INT+2:0] [INTPRIORITY_BITS-1:0] level_intpend_w_prior_en_4;
logic [TOTAL_INT+2:0] [ID_BITS-1:0] level_intpend_id_4;
    for (m=0; m<=(TOTAL_INT)/(2**(4)) ; m++) begin : COMPARE3
       if ( m == (TOTAL_INT)/(2**(4))) begin
            assign level_intpend_w_prior_en_4[m+1] = '0 ;
            assign level_intpend_id_4[m+1]         = '0 ;
       end
       cmp_and_mux  #(
                      .ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l4 (
                      .a_id(level_intpend_id_3[2*m]),
                      .a_priority(level_intpend_w_prior_en_3[2*m]),
                      .b_id(level_intpend_id_3[2*m+1]),
                      .b_priority(level_intpend_w_prior_en_3[2*m+1]),
                      .out_id(level_intpend_id_4[m]),
                      .out_priority(level_intpend_w_prior_en_4[m])) ;

 end

assign claimid_in[ID_BITS-1:0]                      =      level_intpend_id_4[0] ;   // This is the last level output
assign selected_int_priority[INTPRIORITY_BITS-1:0]  =      level_intpend_w_prior_en_4[0] ;
`endif
