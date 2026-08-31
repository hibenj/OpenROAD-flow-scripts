// Instruction-trace testbench for the ibex_core netlist (activity VCD).
// A behavioral memory serves a hand-assembled RV32I program: a 100-iteration
// ALU+store loop followed by WFI. The store stream is the self-check (100
// stores of 1..100), and the post-WFI span is the idle-heavy tail that gives
// clock gating something to save. Active:idle duty is roughly 1:10.
`timescale 1ps / 1ps

module tb;
  parameter int CLK_PS = 1000;
  parameter int N_LOOP = 100;
  parameter int IDLE_CYCLES = 15000;

  // rst_n starts HIGH and is pulled low after two cycles: the liberty-derived
  // DFF models handle async set/clear on the falling edge, so a reset already
  // asserted at time zero would never register (no edge).
  logic clk = 0, rst_n = 1;
  logic instr_gnt = 0, instr_rvalid = 0;
  logic [31:0] instr_rdata = 0;
  logic data_gnt = 0, data_rvalid = 0;
  wire instr_req, data_req, data_we, core_sleep;
  wire [31:0] instr_addr, data_addr, data_wdata;
  wire [3:0] data_be;

  ibex_core dut (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0),
    .hart_id_i(32'h0), .boot_addr_i(32'h0),
    .instr_req_o(instr_req), .instr_gnt_i(instr_gnt),
    .instr_rvalid_i(instr_rvalid), .instr_addr_o(instr_addr),
    .instr_rdata_i(instr_rdata), .instr_err_i(1'b0),
    .data_req_o(data_req), .data_gnt_i(data_gnt),
    .data_rvalid_i(data_rvalid), .data_we_o(data_we),
    .data_be_o(data_be), .data_addr_o(data_addr),
    .data_wdata_o(data_wdata), .data_rdata_i(32'h0), .data_err_i(1'b0),
    .irq_software_i(1'b0), .irq_timer_i(1'b0), .irq_external_i(1'b0),
    .irq_fast_i(15'h0), .irq_nm_i(1'b0),
    .debug_req_i(1'b0), .fetch_enable_i(1'b1),
    .alert_minor_o(), .alert_major_o(), .core_sleep_o(core_sleep));

  always #(CLK_PS / 2) clk = ~clk;

  // program: reset vector is boot_addr + 0x80
  function automatic [31:0] rom(input [31:0] addr);
    case (addr[7:2])
      6'h20: return 32'h06400293;  // 0x80: addi x5, x0, 100
      6'h21: return 32'h00000313;  // 0x84: addi x6, x0, 0
      6'h22: return 32'h00130313;  // 0x88: addi x6, x6, 1   <- loop
      6'h23: return 32'h005343B3;  // 0x8c: xor  x7, x6, x5
      6'h24: return 32'h00602023;  // 0x90: sw   x6, 0(x0)
      6'h25: return 32'hFE629AE3;  // 0x94: bne  x5, x6, loop
      default: return 32'h10500073; // wfi everywhere else
    endcase
  endfunction

  // simple memories: grant in the request cycle, rvalid the cycle after
  always @(posedge clk) begin
    instr_gnt <= instr_req;
    instr_rvalid <= instr_req && instr_gnt;
    if (instr_req) instr_rdata <= rom(instr_addr);
    data_gnt <= data_req;
    data_rvalid <= data_req && data_gnt;
  end

  int stores = 0, errors = 0;
  always @(posedge clk) begin
    if (rst_n && data_req && data_gnt && data_we) begin
      stores <= stores + 1;
      if (data_wdata != stores + 1) begin
        $display("STORE MISMATCH #%0d: got %0d", stores, data_wdata);
        errors <= errors + 1;
      end
    end
  end

  initial begin
    string vcd;
    int cycles = 0;
    if (!$value$plusargs("vcd=%s", vcd)) vcd = "ibex.vcd";
    $dumpfile(vcd);
    $dumpvars(0, tb.dut);

    repeat (2) @(negedge clk);
    rst_n = 0;
    repeat (10) @(negedge clk);
    rst_n = 1;

    while (!core_sleep) begin
      @(negedge clk);
      cycles = cycles + 1;
      if (cycles > 100000) $fatal(1, "TIMEOUT: core never slept");
    end
    // idle tail: core asleep, clock still running
    repeat (IDLE_CYCLES) @(negedge clk);

    $display("tb_ibex: %0d stores, %0d errors, slept after %0d cycles",
             stores, errors, cycles);
    if (errors != 0 || stores != N_LOOP) $fatal(1, "MISMATCHES");
    $finish;
  end
endmodule
