module top (
    input wire clk,
    input wire btn1,
    input wire btn2,
    output wire uart_tx,
    output wire [5:0] led
);

  wire b1_lv, b2_lv, b1_pr, b1_rl, b2_pr, b2_rl;

  edge_det #(
      .CLK_HZ(27_000_000),
      .STARTUP_MS(100),
      .ACTIVE_LOW(1)
  ) u_ed1 (
      .clk(clk),
      .btn_in(btn1),
      .level(b1_lv),
      .press(b1_pr),
      .rel(b1_rl)
  );
  edge_det #(
      .CLK_HZ(27_000_000),
      .STARTUP_MS(100),
      .ACTIVE_LOW(1)
  ) u_ed2 (
      .clk(clk),
      .btn_in(btn2),
      .level(b2_lv),
      .press(b2_pr),
      .rel(b2_rl)
  );

  reg [5:0] cnt = 6'd0;

  wire press_any = b1_pr | b2_pr;
  wire [6:0] next_cnt_calc = b1_pr ? (cnt + 1) : b2_pr ? (cnt - 1) : cnt;
  wire [5:0] next_cnt = next_cnt_calc[5:0];

  localparam integer MSG_LEN = 9;
  reg [7:0] msg[0:MSG_LEN-1];
  reg [5:0] cnt_latched;
  reg [3:0] idx = 4'd0;
  reg busy = 1'b0;
  reg pending = 1'b0;

  reg [7:0] din = 8'h00;
  reg empty = 1'b1;
  wire re;
  wire uart_dout;
  assign uart_tx = uart_dout;

  reg  re_q = 1'b0;
  wire re_p = re & ~re_q;
  reg  deassert_empty = 1'b0;
  reg  schedule_next = 1'b0;

  always @(posedge clk) begin
    re_q <= re;

    if (press_any) begin
      cnt <= next_cnt;
      if (!busy) begin
        busy           <= 1'b1;
        pending        <= 1'b0;
        idx            <= 4'd0;
        cnt_latched    <= next_cnt;
        msg[0]         <= "C";
        msg[1]         <= "N";
        msg[2]         <= "T";
        msg[3]         <= ":";
        msg[4]         <= " ";
        msg[5]         <= "0" + (next_cnt / 10);
        msg[6]         <= "0" + (next_cnt % 10);
        msg[7]         <= "\r";
        msg[8]         <= "\n";
        din            <= msg[0];
        empty          <= 1'b0;
        deassert_empty <= 1'b0;
        schedule_next  <= 1'b0;
      end else begin
        pending <= 1'b1;
      end
    end else if (busy) begin
      if (re_p) begin
        deassert_empty <= 1'b1;
      end else if (deassert_empty) begin
        deassert_empty <= 1'b0;
        empty <= 1'b1;
        if (idx == MSG_LEN - 1) begin
          if (pending) begin
            pending       <= 1'b0;
            idx           <= 4'd0;
            cnt_latched   <= cnt;
            msg[0]        <= "C";
            msg[1]        <= "N";
            msg[2]        <= "T";
            msg[3]        <= ":";
            msg[4]        <= " ";
            msg[5]        <= "0" + (cnt / 10);
            msg[6]        <= "0" + (cnt % 10);
            msg[7]        <= "\r";
            msg[8]        <= "\n";
            din           <= msg[0];
            schedule_next <= 1'b1;
          end else begin
            busy <= 1'b0;
          end
        end else begin
          idx <= idx + 1'b1;
          din <= msg[idx+1'b1];
          schedule_next <= 1'b1;
        end
      end else if (schedule_next) begin
        schedule_next <= 1'b0;
        empty <= 1'b0;
      end
    end else begin
      empty <= 1'b1;
      deassert_empty <= 1'b0;
      schedule_next <= 1'b0;
    end
  end

  assign led = ~cnt;

  uart_tx #(
      .CLOCK_FREQUENCY(32'd27_000_000),
      .BAUD_RATE      (32'd115200),
      .WORD_WIDTH     (32'd8)
  ) U_TX (
      .clk  (clk),
      .rst  (1'b0),
      .din  (din),
      .empty(empty),
      .re   (re),
      .dout (uart_dout)
  );
endmodule
