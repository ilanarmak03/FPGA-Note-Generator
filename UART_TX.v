//===========================================================
// Simple UART Transmitter - 8N1
// Ali Kamran - EECS 3201 Project
//===========================================================
module UART_TX(
    input  wire       clk,        // 50 MHz for DE10-Lite
    input  wire       reset,      // active low
    input  wire       tx_enable,
    input  wire [7:0] tx_data,    
    input  wire       send,       // pulse high to start sending
    output reg        tx,
    output reg        busy,
    output wire       tx_done
);
    parameter CLK_FREQ = 50000000;
    parameter BAUD     = 115200;
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD; // ~434

    // Internal registers
    reg [15:0] baud_cnt   = 0;
    reg [3:0]  bit_idx    = 0;
    reg [9:0]  shiftreg   = 10'b1111111111;
    reg [7:0]  buffer_data = 0;
    reg        buffer_full = 0;
    reg [2:0]  state      = 0;
    reg        tx_done_r  = 0;
    assign tx_done = tx_done_r;

    localparam IDLE  = 0,
               START = 1,
               DATA  = 2,
               STOP  = 3,
               DONE  = 4;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state       <= IDLE;
            tx          <= 1'b1;
            busy        <= 1'b0;
            baud_cnt    <= 0;
            bit_idx     <= 0;
            buffer_full <= 0;
            tx_done_r   <= 0;
        end else begin
            tx_done_r <= 1'b0; // default low each cycle
            case (state)
                IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (tx_enable) begin
                        if (send && !busy) begin
                            shiftreg <= {1'b1, tx_data, 1'b0};
                            busy     <= 1'b1;
                            baud_cnt <= 0;
                            bit_idx  <= 0;
                            state    <= START;
                        end else if (buffer_full) begin
                            shiftreg <= {1'b1, buffer_data, 1'b0};
                            buffer_full <= 0;
                            busy     <= 1'b1;
                            baud_cnt <= 0;
                            bit_idx  <= 0;
                            state    <= START;
                        end
                    end
                    // store to buffer if busy
                    if (send && busy && !buffer_full) begin
                        buffer_full <= 1;
                        buffer_data <= tx_data;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (baud_cnt < CLKS_PER_BIT - 1)
                        baud_cnt <= baud_cnt + 1;
                    else begin
                        baud_cnt <= 0;
                        state    <= DATA;
                    end
                end

                DATA: begin
                    tx <= shiftreg[bit_idx + 1];
                    if (baud_cnt < CLKS_PER_BIT - 1)
                        baud_cnt <= baud_cnt + 1;
                    else begin
                        baud_cnt <= 0;
                        if (bit_idx < 7)
                            bit_idx <= bit_idx + 1;
                        else
                            state <= STOP;
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (baud_cnt < CLKS_PER_BIT - 1)
                        baud_cnt <= baud_cnt + 1;
                    else begin
                        baud_cnt <= 0;
                        state    <= DONE;
                    end
                end

                DONE: begin
                    busy      <= 1'b0;
                    tx_done_r <= 1'b1; // 1-clock pulse
                    state     <= IDLE;
                end
            endcase
        end
    end
endmodule
