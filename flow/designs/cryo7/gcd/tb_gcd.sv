// Random-stimulus testbench for the gcd netlist (gate-level activity VCD).
// Self-checking: compares resp_msg against a reference Euclid model, so a
// passing run also validates the generated liberty behavioral models.
//
// Verilate with:  verilator --binary --timing -Wno-fatal tb_gcd.sv \
//                   <6_final.v> <gen_cryo7_stdcells_sim.v> \
//                   -GCLK_PS=<clock period in ps> -o tb_gcd
`timescale 1ps / 1ps

module tb;
  parameter int CLK_PS = 320;      // sim clock period, ps (match the SDC)
  parameter int N_TXN = 2000;      // transactions to run
  parameter int SEED = 1;

  logic clk = 0, reset = 1;
  logic [31:0] req_msg;
  logic req_val, resp_rdy;
  wire req_rdy, resp_val;
  wire [15:0] resp_msg;

  gcd dut (.clk(clk), .reset(reset),
           .req_msg(req_msg), .req_val(req_val), .req_rdy(req_rdy),
           .resp_msg(resp_msg), .resp_val(resp_val), .resp_rdy(resp_rdy));

  always #(CLK_PS / 2) clk = ~clk;

  function automatic [15:0] ref_gcd(input [15:0] a, input [15:0] b);
    logic [15:0] t;
    while (b != 0) begin
      t = b;
      b = a % b;
      a = t;
    end
    return a;
  endfunction

  // queue of expected results (handshakes are in order)
  logic [15:0] expq[$];
  int sent = 0, recv = 0, errors = 0;

  initial begin
    string vcd;
    logic [15:0] ra, rb;
    void'($urandom(SEED));
    if (!$value$plusargs("vcd=%s", vcd)) vcd = "gcd.vcd";
    $dumpfile(vcd);
    $dumpvars(0, tb.dut);

    req_val = 0;
    resp_rdy = 0;
    req_msg = '0;
    repeat (5) @(negedge clk);
    reset = 0;

    while (recv < N_TXN) begin
      @(negedge clk);
      // request side: 75% offer rate
      if (!req_val || req_rdy) begin
        if ($urandom() % 4 != 0 && sent < N_TXN) begin
          ra = $urandom();
          rb = $urandom();
          req_msg <= {ra, rb};
          req_val <= 1;
        end else begin
          req_val <= 0;
        end
      end
      // response side: 75% ready rate
      resp_rdy <= ($urandom() % 4 != 0);
    end
    $display("tb_gcd: %0d transactions, %0d errors", recv, errors);
    if (errors != 0) $fatal(1, "MISMATCHES");
    $finish;
  end

  always @(posedge clk) begin
    if (!reset && req_val && req_rdy) begin
      expq.push_back(ref_gcd(req_msg[31:16], req_msg[15:0]));
      sent <= sent + 1;
    end
    if (!reset && resp_val && resp_rdy) begin
      if (expq.size() == 0) begin
        errors <= errors + 1;
      end else begin
        automatic logic [15:0] exp = expq.pop_front();
        if (resp_msg !== exp) begin
          $display("MISMATCH txn %0d: got %h exp %h", recv, resp_msg, exp);
          errors <= errors + 1;
        end
      end
      recv <= recv + 1;
    end
  end
endmodule
