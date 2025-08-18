`timescale 1ns / 1ps
// ---------------------------------------------------------------
//  Top module: UART transceiver test with “×2” feedback
// ---------------------------------------------------------------
module invert_uart_transceiver_test #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire        clk,
    input  wire        rst_n,     // KEY0, active‑LOW
    input  wire        key1_n,    // KEY1, active‑LOW (TX trigger)
    // ------------- UART pins -------------
    output wire        txd,
    input  wire        rxd,
    // ------------- Indicators ------------
    output wire [7:0]  rx_data,
    output wire [7:0]  leds,
    output wire [6:0]  seg
);

    // -----------------------------------------------------------
    //  House‑keeping
    // -----------------------------------------------------------
    wire rst  = ~rst_n;           // internal active‑HIGH reset
    wire key1 = ~key1_n;          // active‑HIGH push‑button

    // ---------- baud‑rate tick ----------
    reg [15:0] baud_cnt = 0;
    wire       baud_tick;

    always @(posedge clk or posedge rst) begin
        if (rst)
            baud_cnt <= 0;
        else if (baud_cnt == (CLK_FREQ / BAUD_RATE - 1))
            baud_cnt <= 0;
        else
            baud_cnt <= baud_cnt + 1;
    end
    assign baud_tick = (baud_cnt == 0);

    // -----------------------------------------------------------
    //  KEY1 debouncer / edge detector
    // -----------------------------------------------------------
    reg  [2:0] key1_sync;
    wire       key1_pressed;

    always @(posedge clk) begin
        key1_sync <= {key1_sync[1:0], key1};
    end
    assign key1_pressed = (key1_sync[2:1] == 2'b10);   // button press

    // -----------------------------------------------------------
    //  Transmit control
    // -----------------------------------------------------------
    reg        tx_start;
    reg  [7:0] tx_data;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_start <= 1'b0;
            tx_data  <= 8'h00;
        end else begin
            tx_start <= key1_pressed;                 // one‑cycle pulse
            if (key1_pressed)
                // multiply received low nibble by 2
                tx_data <= {(rx_data[7:0] << 1)};
        end
    end

    // -----------------------------------------------------------
    //  UART instances
    // -----------------------------------------------------------
    uart_tx transmitter (
        .clk       (clk),
        .rst       (rst),
        .start     (tx_start),
        .data      (tx_data),
        .baud_tick (baud_tick),
        .tx        (txd)
    );

    uart_rx receiver (
        .clk       (clk),
        .rst       (rst),
        .rx        (rxd),
        .baud_tick (baud_tick),
        .data      (rx_data)
    );

    // -----------------------------------------------------------
    //  Indicators
    // -----------------------------------------------------------
    assign leds = rx_data;       // show full received byte

    // only last 4 bits on 7‑segment
    binary_to_7seg seg_decoder (
        .data_in (rx_data[3:0]),
        .data_out(seg)
    );

endmodule
