module top(
  input  wire clk,
  input  wire btn1,
  input  wire btn2,
  output wire [5:0] led
);
  wire b1_lv, b2_lv, b1_pr, b1_rl, b2_pr, b2_rl;
  edge_det #(.CLK_HZ(27_000_000), .STARTUP_MS(100), .ACTIVE_LOW(1)) e1(
    .clk(clk), .btn_in(btn1), .level(b1_lv), .press(b1_pr), .rel(b1_rl)
  );
  edge_det #(.CLK_HZ(27_000_000), .STARTUP_MS(100), .ACTIVE_LOW(1)) e2(
    .clk(clk), .btn_in(btn2), .level(b2_lv), .press(b2_pr), .rel(b2_rl)
  );

  reg [5:0] cnt = 6'd0;
  always @(posedge clk) begin
    if (b1_pr) cnt <= cnt + 1;
    if (b2_pr) cnt <= cnt - 1;
  end

  assign led = ~cnt;
endmodule
