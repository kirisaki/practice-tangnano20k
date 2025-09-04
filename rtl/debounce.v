module debounce #(
  parameter integer CLK_HZ = 27_000_000,
  parameter integer MS     = 5
)(
  input  wire clk,
  input  wire in_n,
  output reg  level = 1'b0,
  output reg  tick  = 1'b0 
);
  wire in = ~in_n;
  reg s0=0,s1=0; always @(posedge clk) begin s0<=in; s1<=s0; end
  localparam integer LIM = (CLK_HZ/1000)*MS;
  localparam integer W   = (LIM<=1)?1:$clog2(LIM);
  reg [W-1:0] cnt = 0;
  always @(posedge clk) begin
    tick <= 1'b0;
    if (s1 == level) begin
      cnt <= 0;
    end else if (cnt == LIM-1) begin
      level <= s1;
      tick  <= s1;
      cnt   <= 0;
    end else begin
      cnt <= cnt + 1;
    end
  end
endmodule