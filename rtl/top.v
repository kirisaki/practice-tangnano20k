module top(
  input  wire clk,
  input  wire btn1,
  input  wire btn2,
  output wire [5:0] led
);
  wire b1_lv, b1_tick, b2_lv, b2_tick;
  debounce #(.CLK_HZ(27_000_000), .MS(80)) d1(.clk(clk), .in_n(btn1), .level(b1_lv), .tick(b1_tick));
  debounce #(.CLK_HZ(27_000_000), .MS(80)) d2(.clk(clk), .in_n(btn2), .level(b2_lv), .tick(b2_tick));

  reg [5:0] cnt = 6'b000000;
  always @(posedge clk) begin
    if (b1_tick) cnt <= cnt + 1;
    if (b2_tick) cnt <= cnt - 1;
  end
  assign led = ~cnt;
endmodule