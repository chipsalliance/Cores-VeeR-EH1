module tb_condition_check;

  logic a, b;
  logic out;

  always_comb begin
    out = 0;
    if ((a | b))
      out = 1;
  end

  initial begin
    a = 0; b = 0; #5;
    assert(out == 0);

    a = 1; b = 0; #5;
    assert(out == 1);

    b = 1; #5;
    assert(out == 1);

    $display("PASS ✅");
    $finish;
  end

endmodule