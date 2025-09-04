module edge_det #(
  parameter integer CLK_HZ     = 27_000_000,
  parameter integer STARTUP_MS = 100,
  parameter         ACTIVE_LOW = 1'b1
)(
  input  wire clk,
  input  wire btn_in,
  output reg  level = 1'b0,
  output reg  press = 1'b0,
  output reg  rel = 1'b0
);
  wire in_norm = ACTIVE_LOW ? ~btn_in : btn_in;

  reg s0=1'b0, s1=1'b0;
  always @(posedge clk) begin s0 <= in_norm; s1 <= s0; end

  localparam integer LIM = (CLK_HZ/1000)*STARTUP_MS;
  localparam integer W   = (LIM<=1)?1:$clog2(LIM);
  reg [W-1:0] por_cnt = {W{1'b0}};
  wire armed = (por_cnt == LIM-1);
  always @(posedge clk) if (!armed) por_cnt <= por_cnt + 1'b1;

  reg prev = 1'b0;
  always @(posedge clk) begin
    press   <= 1'b0;
    rel <= 1'b0;

    if (!armed) begin
      level <= s1;
      prev  <= s1;
    end else begin
      level <= s1;
      if (s1 & ~prev) press   <= 1'b1;
      if (~s1 & prev) rel <= 1'b1;
      prev <= s1;
    end
  end
endmodule
