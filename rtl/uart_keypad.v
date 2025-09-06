module uart_keypad #(
    parameter [31:0] CLOCK_FREQUENCY = 32'd100_000_000,
    parameter [31:0] BAUD_RATE       = 32'd115200,
    parameter [ 7:0] KEY_UP1         = 8'h75,
    parameter [ 7:0] KEY_UP2         = 8'h55,
    parameter [ 7:0] KEY_DOWN1       = 8'h64,
    parameter [ 7:0] KEY_DOWN2       = 8'h44
) (
    input  clk,
    input  rst,
    input  rx,
    output up_pulse,
    output down_pulse
);
  wire [7:0] rx_data;
  wire       rx_we;

  uart_rx #(
      .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
      .BAUD_RATE(BAUD_RATE),
      .WORD_WIDTH(32'd8)
  ) u_rx (
      .clk (clk),
      .rst (rst),
      .din (rx),
      .dout(rx_data),
      .full(1'b0),
      .we  (rx_we)
  );

  assign up_pulse   = rx_we & ((rx_data == KEY_UP1) | (rx_data == KEY_UP2));
  assign down_pulse = rx_we & ((rx_data == KEY_DOWN1) | (rx_data == KEY_DOWN2));
endmodule
