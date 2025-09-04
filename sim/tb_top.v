`timescale 1ns/1ps

module tb_top;
  // ==== DUT I/O ====
  reg  clk  = 0;
  reg  btn1 = 1'b1; // active-low button: not pressed = 1
  reg  btn2 = 1'b1;
  wire [5:0] led;

  // ==== Device Under Test ====
  top dut(.clk(clk), .btn1(btn1), .btn2(btn2), .led(led));

  // ==== Clock generator (10ns period = 100 MHz) ====
  always #5 clk = ~clk;

  // ==== Param overrides for simulation (faster POR window) ====
  // We keep STARTUP_MS >= 1 to avoid LIM=0 corner cases in DUT.
  localparam integer CLK_HZ_SIM   = 1_000_000; // 1 MHz logical setting for POR counter
  localparam integer STARTUP_MS_SIM = 1;       // small startup mask
  defparam dut.e1.CLK_HZ     = CLK_HZ_SIM;
  defparam dut.e1.STARTUP_MS = STARTUP_MS_SIM;
  defparam dut.e2.CLK_HZ     = CLK_HZ_SIM;
  defparam dut.e2.STARTUP_MS = STARTUP_MS_SIM;

  // ==== Waveform dump ====
  initial begin
    $dumpfile("build/wave.vcd");
    $dumpvars(0, tb_top);
  end

  // ==== Global watchdog to avoid endless wait ====
  initial begin
    // Fail fast if the test doesn't complete in reasonable sim time
    #1_000_000; // 1 ms at 1 ns timescale
    $display("[FATAL] Test timeout.");
    $fatal;
  end

  // ==== Utilities ====
  task tick; begin @(posedge clk); end endtask

  // Clean press (no bounce): active-low -> 1 -> 0 -> hold -> 1
  task press_clean(input integer which, input integer hold_cycles);
    if (which==1) begin
      btn1 = 1'b0;      // press (low)
      repeat (hold_cycles) tick();
      btn1 = 1'b1;      // release (high)
    end else begin
      btn2 = 1'b0;
      repeat (hold_cycles) tick();
      btn2 = 1'b1;
    end
    // let it settle a bit
    repeat (5) tick();
  endtask

  // ==== Expected value tracking ====
  reg [5:0] expect_cnt = 6'd0;
  function [5:0] cnt_from_led(input [5:0] ledv);
    cnt_from_led = ~ledv;
  endfunction

  // ==== Test scenario ====
  initial begin
    integer i;

    // Let design settle and pass DUT startup mask (POR window)
    repeat (5) tick();
    // edge_det counts a POR window based on its own CLK_HZ parameter.
    // We conservatively wait 1200 cycles here (enough for STARTUP_MS_SIM=1).
    repeat (1200) tick();

    // Case 0: pressing during POR should NOT count (sanity)
    // (We already waited out POR, but keep a sanity quick check by snapshot)
    // No explicit action here since POR has passed.

    // Case 1: btn1 press → increment once on press (release shouldn't change cnt)
    fork
      begin
        @(posedge dut.e1.press);
        repeat (2) tick();
        expect_cnt = expect_cnt + 1;
        if (cnt_from_led(led) !== expect_cnt) begin
          $display("[FAIL] after btn1 press: led=%b expect=%0d", led, expect_cnt);
          $fatal;
        end else
          $display("[PASS] btn1 press -> cnt=%0d", expect_cnt);
      end
      press_clean(1, /*hold_cycles=*/8);
    join

    // Verify release pulse exists but does NOT change count
    // (We don't need to wait for rel explicitly; just confirm count remains.)
    if (cnt_from_led(led) !== expect_cnt) begin
      $display("[FAIL] release affected count unexpectedly.");
      $fatal;
    end

    // Case 2: btn1 press again → increment
    fork
      begin
        @(posedge dut.e1.press);
        repeat (2) tick();
        expect_cnt = expect_cnt + 1;
        if (cnt_from_led(led) !== expect_cnt) begin
          $display("[FAIL] after 2nd btn1: led=%b expect=%0d", led, expect_cnt);
          $fatal;
        end else
          $display("[PASS] 2nd btn1 -> cnt=%0d", expect_cnt);
      end
      press_clean(1, 8);
    join

    // Case 3: btn2 press → decrement
    fork
      begin
        @(posedge dut.e2.press);
        repeat (2) tick();
        expect_cnt = expect_cnt - 1;
        if (cnt_from_led(led) !== expect_cnt) begin
          $display("[FAIL] after btn2 press: led=%b expect=%0d", led, expect_cnt);
          $fatal;
        end else
          $display("[PASS] btn2 press -> cnt=%0d", expect_cnt);
      end
      press_clean(2, 8);
    join

    // Optional: multi-press sequence
    for (i=0; i<3; i=i+1) begin
      fork
        begin
          @(posedge dut.e1.press);
          repeat (1) tick();
          expect_cnt = expect_cnt + 1;
        end
        press_clean(1, 3);
      join
    end
    if (cnt_from_led(led) !== expect_cnt) begin
      $display("[FAIL] after burst presses: led=%b expect=%0d", led, expect_cnt);
      $fatal;
    end else
      $display("[PASS] burst presses -> cnt=%0d", expect_cnt);

    $display("[DONE] all checks passed. cnt=%0d", expect_cnt);
    $finish;
  end
endmodule
