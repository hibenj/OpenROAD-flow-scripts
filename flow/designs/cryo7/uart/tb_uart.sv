// Loopback testbench for the uart netlist (gate-level activity VCD).
// txd is wired back to rxd; random bytes are streamed in over AXI with idle
// gaps between them, received bytes are checked against a queue. Idle time on
// the serial line is what gives clock gating something to save, so the
// traffic pattern alternates bursts with quiet spans.
`timescale 1ps / 1ps

module tb;
  parameter int CLK_PS = 270;
  parameter int N_BYTES = 64;
  parameter int SEED = 1;
  parameter int PRESCALE = 4;   // baud = clk / (PRESCALE * 8)

  logic clk = 0, rst = 1;
  logic [7:0] s_axis_tdata;
  logic s_axis_tvalid = 0, m_axis_tready = 1;
  wire s_axis_tready, m_axis_tvalid;
  wire [7:0] m_axis_tdata;
  wire txd, tx_busy, rx_busy, rx_overrun_error, rx_frame_error;

  uart dut (.clk(clk), .rst(rst),
            .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
            .s_axis_tready(s_axis_tready),
            .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid),
            .m_axis_tready(m_axis_tready),
            .rxd(txd), .txd(txd),
            .tx_busy(tx_busy), .rx_busy(rx_busy),
            .rx_overrun_error(rx_overrun_error),
            .rx_frame_error(rx_frame_error),
            .prescale(16'(PRESCALE)));

  always #(CLK_PS / 2) clk = ~clk;

  logic [7:0] expq[$];
  int sent = 0, recv = 0, errors = 0;

  initial begin
    string vcd;
    logic [7:0] b;
    void'($urandom(SEED));
    if (!$value$plusargs("vcd=%s", vcd)) vcd = "uart.vcd";
    $dumpfile(vcd);
    $dumpvars(0, tb.dut);

    repeat (5) @(negedge clk);
    rst = 0;
    repeat (5) @(negedge clk);

    while (sent < N_BYTES) begin
      b = $urandom();
      expq.push_back(b);
      s_axis_tdata <= b;
      s_axis_tvalid <= 1;
      do @(posedge clk); while (!s_axis_tready);  // transfer happens here
      @(negedge clk);
      s_axis_tvalid <= 0;
      sent++;
      // idle gap: 0-3 byte times of quiet line every few bytes
      if ($urandom() % 4 == 0)
        repeat (($urandom() % 4) * PRESCALE * 8 * 10) @(negedge clk);
    end

    // drain: wait for the last bytes to trickle through the serial loop
    repeat (PRESCALE * 8 * 12 * 4) @(negedge clk);
    $display("tb_uart: sent %0d received %0d errors %0d", sent, recv, errors);
    if (errors != 0 || recv != sent) $fatal(1, "MISMATCHES");
    $finish;
  end

  always @(posedge clk) begin
    if (!rst && m_axis_tvalid && m_axis_tready) begin
      if (expq.size() == 0 || m_axis_tdata !== expq.pop_front())
        errors <= errors + 1;
      recv <= recv + 1;
    end
  end
endmodule
