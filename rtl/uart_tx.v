module uart_tx #(
    parameter [31:0] CLOCK_FREQUENCY = 32'd100_000_000,
    parameter [31:0] BAUD_RATE       = 32'd115200,
    parameter [31:0] WORD_WIDTH      = 32'd8
) (
    input                   clk,
    input                   rst,
    input  [WORD_WIDTH-1:0] din,
    input                   empty,
    output                  re,
    output                  dout
);

  // constant
  localparam [31:0] CLOCKS_PER_BIT = CLOCK_FREQUENCY / BAUD_RATE;

  // state encoding (replaces typedef enum)
  localparam [1:0]
    STATE_WAIT               = 2'h0,
    STATE_ASSERT_READ_ENABLE = 2'h1,
    STATE_READ_WORD          = 2'h2,
    STATE_TRANSMIT_BITS      = 2'h3;

  // registers and wires
  reg  [           1:0] state;
  reg  [WORD_WIDTH+1:0] data;
  reg  [          31:0] clock_counts;
  wire                  full_clock_counts;

  // logics
  assign re   = (state == STATE_ASSERT_READ_ENABLE);
  assign dout = (state == STATE_TRANSMIT_BITS) ? data[0] : 1'b1;

  // state register
  always @(posedge clk) begin
    if (rst) state <= STATE_WAIT;
    else begin
      case (state)
        STATE_WAIT: state <= (~empty) ? STATE_ASSERT_READ_ENABLE : state;
        STATE_ASSERT_READ_ENABLE: state <= STATE_READ_WORD;
        STATE_READ_WORD: state <= STATE_TRANSMIT_BITS;
        STATE_TRANSMIT_BITS:
        state <= (full_clock_counts && (data == {{WORD_WIDTH{1'b0}}, 1'b1})) ? STATE_WAIT : state;
        default: state <= STATE_WAIT;
      endcase
    end
  end

  // data shifter
  always @(posedge clk) begin
    if (rst) data <= {WORD_WIDTH + 1{1'b1}};
    else begin
      case (state)
        STATE_READ_WORD:     data <= {1'b1, din, 1'b0};
        STATE_TRANSMIT_BITS: data <= full_clock_counts ? {1'b0, data[WORD_WIDTH+1:1]} : data;
        default:             data <= {WORD_WIDTH + 1{1'b1}};
      endcase
    end
  end

  // baud clock counter
  always @(posedge clk) begin
    if (rst) clock_counts <= 32'h0;
    else begin
      case (state)
        STATE_TRANSMIT_BITS: clock_counts <= full_clock_counts ? 32'h0 : (clock_counts + 32'h1);
        default:             clock_counts <= 32'h0;
      endcase
    end
  end

  assign full_clock_counts = (clock_counts == (CLOCKS_PER_BIT - 1));

endmodule
