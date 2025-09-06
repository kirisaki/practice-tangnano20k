module uart_rx #(
    parameter [31:0] CLOCK_FREQUENCY = 32'd100_000_000,
    parameter [31:0] BAUD_RATE       = 32'd115200,
    parameter [31:0] WORD_WIDTH      = 32'd8
) (
    input                   clk,
    input                   rst,
    input                   din,
    output [WORD_WIDTH-1:0] dout,
    input                   full,
    output                  we
);
  localparam integer OS = 16;

  reg rx_meta = 1'b1, rx_sync = 1'b1;
  always @(posedge clk) begin
    rx_meta <= din;
    rx_sync <= rx_meta;
  end

  reg [47:0] acc = 48'd0;
  wire [47:0] inc = BAUD_RATE * OS;
  wire [47:0] modv = CLOCK_FREQUENCY;
  wire os_tick = (acc >= modv);
  always @(posedge clk) begin
    if (rst) acc <= 48'd0;
    else begin
      acc <= acc + inc;
      if (os_tick) acc <= acc + inc - modv;
    end
  end

  localparam S_IDLE = 2'd0;
  localparam S_START = 2'd1;
  localparam S_DATA = 2'd2;
  localparam S_STOP = 2'd3;

  reg [1:0] state = S_IDLE;
  reg [3:0] os_cnt = 4'd0;
  reg [3:0] bit_cnt = 4'd0;
  reg [WORD_WIDTH-1:0] shift = {WORD_WIDTH{1'b0}};
  reg we_r = 1'b0;

  assign dout = shift;
  assign we   = we_r;

  always @(posedge clk) begin
    we_r <= 1'b0;
    if (rst) begin
      state   <= S_IDLE;
      os_cnt  <= 4'd0;
      bit_cnt <= 4'd0;
    end else if (os_tick) begin
      case (state)
        S_IDLE: begin
          if (~rx_sync) begin
            state  <= S_START;
            os_cnt <= 4'd0;
          end
        end
        S_START: begin
          os_cnt <= os_cnt + 4'd1;
          if (os_cnt == (OS / 2 - 1)) begin
            if (~rx_sync) begin
              state   <= S_DATA;
              os_cnt  <= 4'd0;
              bit_cnt <= 4'd0;
            end else begin
              state <= S_IDLE;
            end
          end
        end
        S_DATA: begin
          os_cnt <= os_cnt + 4'd1;
          if (os_cnt == (OS - 1)) begin
            os_cnt  <= 4'd0;
            shift   <= {rx_sync, shift[WORD_WIDTH-1:1]};
            bit_cnt <= bit_cnt + 4'd1;
            if (bit_cnt == (WORD_WIDTH - 1)) state <= S_STOP;
          end
        end
        S_STOP: begin
          os_cnt <= os_cnt + 4'd1;
          if (os_cnt == (OS - 1)) begin
            os_cnt <= 4'd0;
            if (rx_sync && ~full) we_r <= 1'b1;
            state <= S_IDLE;
          end
        end
      endcase
    end
  end
endmodule
