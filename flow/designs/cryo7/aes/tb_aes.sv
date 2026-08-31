// Testbench for the aes_cipher_top netlist (gate-level activity VCD).
// Self-check: the FIPS-197 appendix C.1 known-answer vector (checked every
// time the fixed key/plaintext pair is driven); random blocks in between
// provide realistic switching, with idle gaps so the activity profile is
// bursty rather than back-to-back.
`timescale 1ps / 1ps

module tb;
  parameter int CLK_PS = 380;
  parameter int N_BLOCKS = 40;
  parameter int SEED = 1;

  logic clk = 0, rst = 1, ld = 0;
  logic [127:0] key, text_in;
  wire done;
  wire [127:0] text_out;

  aes_cipher_top dut (.clk(clk), .rst(rst), .ld(ld), .done(done),
                      .key(key), .text_in(text_in), .text_out(text_out));

  always #(CLK_PS / 2) clk = ~clk;

  localparam logic [127:0] KAT_KEY = 128'h000102030405060708090a0b0c0d0e0f;
  localparam logic [127:0] KAT_PT  = 128'h00112233445566778899aabbccddeeff;
  localparam logic [127:0] KAT_CT  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

  int blocks = 0, kats = 0, errors = 0;

  task automatic encrypt(input logic [127:0] k, input logic [127:0] pt,
                         input bit check);
    int guard = 0;
    @(negedge clk);
    key <= k;
    text_in <= pt;
    ld <= 1;
    @(negedge clk);
    ld <= 0;
    do begin
      @(negedge clk);
      guard++;
      if (guard > 100) $fatal(1, "TIMEOUT waiting for done");
    end while (!done);
    if (check) begin
      kats++;
      if (text_out !== KAT_CT) begin
        $display("KAT MISMATCH: got %h", text_out);
        errors++;
      end
    end
    blocks++;
  endtask

  initial begin
    string vcd;
    void'($urandom(SEED));
    if (!$value$plusargs("vcd=%s", vcd)) vcd = "aes.vcd";
    $dumpfile(vcd);
    $dumpvars(0, tb.dut);

    key = '0; text_in = '0;
    // deassert-then-assert so a falling edge exists for async-control models
    repeat (2) @(negedge clk);
    rst = 0;
    repeat (5) @(negedge clk);
    rst = 1;
    repeat (5) @(negedge clk);

    while (blocks < N_BLOCKS) begin
      if (blocks % 4 == 0)
        encrypt(KAT_KEY, KAT_PT, 1);
      else
        encrypt({$urandom(), $urandom(), $urandom(), $urandom()},
                {$urandom(), $urandom(), $urandom(), $urandom()}, 0);
      // idle gap: 0-2 block times of quiet every few blocks
      if ($urandom() % 3 == 0)
        repeat (($urandom() % 3) * 13) @(negedge clk);
    end
    // idle tail
    repeat (200) @(negedge clk);

    $display("tb_aes: %0d blocks, %0d KATs, %0d errors", blocks, kats, errors);
    if (errors != 0) $fatal(1, "MISMATCHES");
    $finish;
  end
endmodule
