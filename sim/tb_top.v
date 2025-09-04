`timescale 1ns/1ps

module tb_top;
  // ==== DUT I/O ====
  reg  clk = 0;
  reg  btn1 = 1'b1; // in_n: not pressed = 1
  reg  btn2 = 1'b1;
  wire [5:0] led;

  // ==== Device Under Test ====
  top dut(.clk(clk), .btn1(btn1), .btn2(btn2), .led(led));

  // ==== Clock generator (10ns period = 100 MHz / 2 = 50 MHz effective) ====
  always #5 clk = ~clk;

  // ==== Shorten debounce parameters for simulation ====
  // Original: 27 MHz * 80 ms → too long for sim
  // Simulation: 1 MHz * 1 ms → manageable (~1000 cycles)
  localparam integer CLK_HZ_SIM = 1_000_000;
  localparam integer MS_SIM     = 1;
  localparam integer LIM        = (CLK_HZ_SIM/1000)*MS_SIM;

  // Override parameters of child instances inside top
  defparam dut.d1.CLK_HZ = CLK_HZ_SIM;
  defparam dut.d1.MS     = MS_SIM;
  defparam dut.d2.CLK_HZ = CLK_HZ_SIM;
  defparam dut.d2.MS     = MS_SIM;

  // ==== Waveform dump ====
  initial begin
    $dumpfile("build/wave.vcd");
    $dumpvars(0, tb_top);
  end

  // ==== Utility: wait for a rising edge of clk ====
  task tick; begin @(posedge clk); end endtask

  // Task to emulate a button press with bouncing noise
  // Sequence: noisy press → stable low → noisy release → stable high
  task press_with_bounce(input integer which);
    integer i;
    reg tmp;
    // 1) bouncing before press
    for (i=0; i<10; i=i+1) begin
      tmp = (i[0]==0) ? 1'b0 : 1'b1; // toggle 0,1,0,1...
      if (which==1) btn1 = tmp; else btn2 = tmp;
      tick();
    end
    // 2) stable pressed (active low)
    if (which==1) btn1 = 1'b0; else btn2 = 1'b0;
    repeat (LIM+5) tick(); // wait until debounce is complete

    // 3) bouncing before release
    for (i=0; i<10; i=i+1) begin
      tmp = (i[0]==0) ? 1'b1 : 1'b0; // toggle 1,0,1,0...
      if (which==1) btn1 = tmp; else btn2 = tmp;
      tick();
    end
    // 4) stable released (inactive high)
    if (which==1) btn1 = 1'b1; else btn2 = 1'b1;
    repeat (LIM+5) tick();
  endtask

  // ==== Expected value tracking ====
  reg [5:0] expect_cnt = 6'd0;
  function [5:0] cnt_from_led(input [5:0] ledv);
    cnt_from_led = ~ledv;
  endfunction

  // ==== Test scenario ====
  initial begin
    // let the design settle
    repeat (5) tick();

    // Case 1: btn1 press → increment
    fork
      begin
        @(posedge dut.d1.tick);
        repeat (2) tick(); // allow cnt to update
        expect_cnt = expect_cnt + 1;
        if (cnt_from_led(led) !== expect_cnt) begin
          $display("[FAIL] after btn1 press: led=%b expect=%0d", led, expect_cnt);
          $fatal;
        end else
          $display("[PASS] btn1 press -> cnt=%0d", expect_cnt);
      end
      press_with_bounce(1);
    join

    // Case 2: btn1 press again → increment
    fork
      begin
        @(posedge dut.d1.tick);
        repeat (2) tick();
        expect_cnt = expect_cnt + 1;
        if (cnt_from_led(led) !== expect_cnt) begin
          $display("[FAIL] after 2nd btn1: led=%b expect=%0d", led, expect_cnt);
          $fatal;
        end else
          $display("[PASS] 2nd btn1 -> cnt=%0d", expect_cnt);
      end
      press_with_bounce(1);
    join

    // Case 3: btn2 press → decrement
    fork
      begin
        @(posedge dut.d2.tick);
        repeat (2) tick();
        expect_cnt = expect_cnt - 1;
        if (cnt_from_led(led) !== expect_cnt) begin
          $display("[FAIL] after btn2 press: led=%b expect=%0d", led, expect_cnt);
          $fatal;
        end else
          $display("[PASS] btn2 press -> cnt=%0d", expect_cnt);
      end
      press_with_bounce(2);
    join

    $display("[DONE] all checks passed. cnt=%0d", expect_cnt);
    $finish;
  end
endmodule
