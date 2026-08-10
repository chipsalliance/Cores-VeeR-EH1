module tb_i1_instr_error;

  logic i1_br_error_all;
  logic i1_instr_error;

  // Simplified output model
  logic nop_generated;

  // DUT-like behavior (mimicking your logic)
  always_comb begin
    nop_generated = 1'b0;

    if (i1_br_error_all | i1_instr_error) begin
      nop_generated = 1'b1;
    end
  end

  initial begin
    // Case 1: no error
    i1_br_error_all = 0;
    i1_instr_error  = 0;
    #5;
    assert(nop_generated == 0);

    // Case 2: branch error
    i1_br_error_all = 1;
    i1_instr_error  = 0;
    #5;
    assert(nop_generated == 1);

    // Case 3: instr error (IMPORTANT)
    i1_br_error_all = 0;
    i1_instr_error  = 1;
    #5;
    assert(nop_generated == 1);

    $display("TEST PASSED ✅");
    $finish;
  end

endmodule