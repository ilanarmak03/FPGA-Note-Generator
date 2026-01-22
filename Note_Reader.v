//===========================================================
// EECS 3201 Project - Note Reader UART Transmitter + 7-seg
// Ali Kamran - DE10-Lite (Final Working Version)
//===========================================================
module Note_Reader(
    input  wire CLOCK_50,
    input  wire [9:0] SW,      // switches
    input  wire [1:0] KEY,     // push buttons
    output wire UART_TX,       // serial output
    output wire [9:0] LEDR,    // status LEDs
    output wire AUDIO_OUT,     // <-- This goes to GPIO pin
    output reg  [7:0] HEX0,
    output reg  [7:0] HEX1,
    output reg  [7:0] HEX2,
    output reg  [7:0] HEX3,
    output reg  [7:0] HEX4,
    output reg  [7:0] HEX5
);

    // --- Switch Decoding ---
    wire [3:0] sw_pitch   = SW[3:0];
    wire [1:0] sw_octave  = SW[5:4];
    wire       sw_forceA4 = SW[6];
    wire       freeze     = SW[7];
    wire       uart_enable= SW[8];

    // --- KEYS ---
    wire reset_n = KEY[0]; // active-low reset

    // --- Debouncer + Send Request ---
    wire send_button_down;
    wire send_button_pressed;

    ButtonDebounce db_send (
        .clk        (CLOCK_50),
        .reset_n    (reset_n),
        .btn_n      (KEY[1]),
        .btn_down   (send_button_down),
        .btn_pressed(send_button_pressed)
    );

    reg send_req;
    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n)
            send_req <= 0;
        else begin
            if (send_button_pressed)
                send_req <= 1;
            else if (send_state != 0)
                send_req <= 0;
        end
    end

    // --------- FREEZE LATCH ----------
    reg [3:0] lat_pitch;
    reg [1:0] lat_octave;
    reg       lat_forceA4;
    reg [3:0] d_th, d_hu, d_ten, d_one;
	 reg [3:0] m_th, m_hu, m_ten, m_one;
	 integer tm;
    integer t;

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            lat_pitch   <= 4'd9;  // default A
            lat_octave  <= 2'b01; // default 4
            lat_forceA4 <= 1'b0;
        end else if (!freeze) begin
            lat_pitch   <= sw_pitch;
            lat_octave  <= sw_octave;
            lat_forceA4 <= sw_forceA4;
        end
    end

    wire [3:0] pitch_sel   = lat_pitch;
    wire [1:0] octave_sel  = lat_octave;
    wire       force_A4    = lat_forceA4;

    // --- Note ASCII registers ---
    reg [7:0] note_char;
    reg [7:0] accidental;
    reg [7:0] octave_ascii;

    always @(*) begin
        if (force_A4) begin
            note_char    = "A";
            accidental   = " ";
            octave_ascii = "4";
        end else begin
            case (octave_sel)
                2'b00: octave_ascii = "3";
                2'b01: octave_ascii = "4";
                2'b10: octave_ascii = "5";
                2'b11: octave_ascii = "6";
            endcase
            case (pitch_sel)
                4'd0:  begin note_char="C"; accidental=" "; end
                4'd1:  begin note_char="C"; accidental="#"; end
                4'd2:  begin note_char="D"; accidental=" "; end
                4'd3:  begin note_char="D"; accidental="#"; end
                4'd4:  begin note_char="E"; accidental=" "; end
                4'd5:  begin note_char="F"; accidental=" "; end
                4'd6:  begin note_char="F"; accidental="#"; end
                4'd7:  begin note_char="G"; accidental=" "; end
                4'd8:  begin note_char="G"; accidental="#"; end
                4'd9:  begin note_char="A"; accidental=" "; end
                4'd10: begin note_char="A"; accidental="#"; end
                4'd11: begin note_char="B"; accidental=" "; end
                default: begin note_char="?"; accidental="?"; end
            endcase
        end
    end

    // --- UART wires ---
    wire busy, tx_done;
    reg  [7:0] tx_byte;
    reg        tx_start;
    UART_TX uart_tx_inst (
        .clk(CLOCK_50),
        .reset(reset_n),
        .tx_enable(uart_enable),
        .tx_data(tx_byte),
        .send(tx_start),
        .tx(UART_TX),
        .busy(busy),
        .tx_done(tx_done)
    );

    // --- UART Send FSM ---
    reg [3:0] send_state = 0;
    wire [7:0] freq_ascii_th  = (d_th  == 0) ? " " : ("0" + d_th);
    wire [7:0] freq_ascii_hu  = (d_th==0 && d_hu==0) ? " " : ("0" + d_hu);
    wire [7:0] freq_ascii_ten = (d_th==0 && d_hu==0 && d_ten==0) ? " " : ("0" + d_ten);
    wire [7:0] freq_ascii_one = "0" + d_one;

    wire [7:0] meas_ascii_th  = (m_th  == 0) ? " " : ("0" + m_th);
    wire [7:0] meas_ascii_hu  = (m_th==0 && m_hu==0) ? " " : ("0" + m_hu);
    wire [7:0] meas_ascii_ten = (m_th==0 && m_hu==0 && m_ten==0) ? " " : ("0" + m_ten);
    wire [7:0] meas_ascii_one = "0" + m_one;

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            send_state <= 0;
            tx_start   <= 0;
        end else begin
            tx_start <= 0;  // default

            case (send_state)

                // 0: Start when pressed and UART not busy
                0: if (send_req && uart_enable && !busy) begin
                       tx_byte    <= note_char;
                       tx_start   <= 1;
                       send_state <= 1;
                   end

                // 1: send accidental
                1: if (tx_done) begin
                       tx_byte    <= accidental;
                       tx_start   <= 1;
                       send_state <= 2;
                   end

                // 2: send octave
                2: if (tx_done) begin
                       tx_byte    <= octave_ascii;
                       tx_start   <= 1;
                       send_state <= 3;
                   end

                // comma
                3: if (tx_done) begin
                       tx_byte    <= 8'h2C;
                       tx_start   <= 1;
                       send_state <= 4;
                   end

                // 3: send freq thousands
                4: if (tx_done) begin
                       tx_byte    <= freq_ascii_th;
                       tx_start   <= 1;
                       send_state <= 5;
                   end

                // 4: send freq hundreds
                5: if (tx_done) begin
                       tx_byte    <= freq_ascii_hu;
                       tx_start   <= 1;
                       send_state <= 6;
                   end

                // 5: send freq tens
                6: if (tx_done) begin
                       tx_byte    <= freq_ascii_ten;
                       tx_start   <= 1;
                       send_state <= 7;
                   end

                // 6: send freq ones
                // --- Expected frequency (done previously) ---
                7: if (tx_done) begin
                       tx_byte    <= freq_ascii_one;
                       tx_start   <= 1;
                       send_state <= 8;
                   end

                // --- Add COMMA between expected and measured ---
                8: if (tx_done) begin
                       tx_byte    <= 8'h2C;   // ','
                       tx_start   <= 1;
                       send_state <= 9;
                   end

                // --- Measured frequency thousands ---
                9: if (tx_done) begin
                       tx_byte    <= meas_ascii_th;
                       tx_start   <= 1;
                       send_state <= 10;
                   end

                // hundreds
                10: if (tx_done) begin
                        tx_byte    <= meas_ascii_hu;
                        tx_start   <= 1;
                        send_state <= 11;
                    end

                // tens
                11: if (tx_done) begin
                        tx_byte    <= meas_ascii_ten;
                        tx_start   <= 1;
                        send_state <= 12;
                    end

                // ones
                12: if (tx_done) begin
                        tx_byte    <= meas_ascii_one;
                        tx_start   <= 1;
                        send_state <= 13;
                    end

                // CR
                13: if (tx_done) begin
                        tx_byte    <= 8'h0D;
                        tx_start   <= 1;
                        send_state <= 14;
                    end

                // LF
                14: if (tx_done) begin
                        tx_byte    <= 8'h0A;
                        tx_start   <= 1;
                        send_state <= 0;
                    end

            endcase
        end
    end

    // --- LEDs ---
    assign LEDR[0]   = busy;
    assign LEDR[9:1] = SW[8:0];

    // --- Frequency Mapping ---
    reg [15:0] freq_hz;
    always @(*) begin
        if (force_A4) freq_hz = 16'd440;
        else begin
            case (octave_sel)
                2'd0: case (pitch_sel)
                    0: freq_hz=16'd131; 1: freq_hz=16'd139; 2: freq_hz=16'd147; 3: freq_hz=16'd156;
                    4: freq_hz=16'd165; 5: freq_hz=16'd175; 6: freq_hz=16'd185; 7: freq_hz=16'd196;
                    8: freq_hz=16'd208; 9: freq_hz=16'd220;10: freq_hz=16'd233;11: freq_hz=16'd247;
                endcase
                2'd1: case (pitch_sel)
                    0: freq_hz=16'd262;1: freq_hz=16'd277;2: freq_hz=16'd294;3: freq_hz=16'd311;
                    4: freq_hz=16'd330;5: freq_hz=16'd349;6: freq_hz=16'd370;7: freq_hz=16'd392;
                    8: freq_hz=16'd415;9: freq_hz=16'd440;10:freq_hz=16'd466;11:freq_hz=16'd494;
                endcase
                2'd2: case (pitch_sel)
                    0: freq_hz=16'd523;1: freq_hz=16'd554;2: freq_hz=16'd587;3: freq_hz=16'd622;
                    4: freq_hz=16'd659;5: freq_hz=16'd698;6: freq_hz=16'd740;7: freq_hz=16'd784;
                    8: freq_hz=16'd831;9: freq_hz=16'd880;10:freq_hz=16'd932;11:freq_hz=16'd988;
                endcase
                2'd3: case (pitch_sel)
                    0: freq_hz=16'd1046;1: freq_hz=16'd1109;2: freq_hz=16'd1175;3: freq_hz=16'd1245;
                    4: freq_hz=16'd1319;5: freq_hz=16'd1397;6: freq_hz=16'd1480;7: freq_hz=16'd1568;
                    8: freq_hz=16'd1661;9: freq_hz=16'd1760;10:freq_hz=16'd1865;11:freq_hz=16'd1976;
                endcase
            endcase
        end
    end

    always @(*) begin
        t      = freq_hz;
        d_th   = t / 1000;  t = t % 1000;
        d_hu   = t / 100;   t = t % 100;
        d_ten  = t / 10;    t = t % 10;
        d_one  = t[3:0];
    end

    //-----------------------------------------------------------
    // Tone Generator (Square Wave Output)
    //-----------------------------------------------------------
    Square_Wave_Generator tone(
        .clk      (CLOCK_50),
        .reset_n  (reset_n),
        .freq_hz  (freq_hz),
        .audio_out(AUDIO_OUT)
    );

    //-----------------------------------------------------------
    // Frequency Measurement Module
    //-----------------------------------------------------------
    wire [15:0] freq_measured;

    Freq_Measure meas(
        .clk     (CLOCK_50),
        .reset_n (reset_n),
        .signal_in (AUDIO_OUT),   // measure the square wave we just produced
        .measured_freq    (freq_measured)
    );

    always @(*) begin
        tm   = freq_measured;
        m_th = tm / 1000; tm = tm % 1000;
        m_hu = tm / 100;  tm = tm % 100;
        m_ten= tm / 10;   tm = tm % 10;
        m_one= tm[3:0];
    end

    function [6:0] seg7_digit(input [3:0] v);
        case (v)
            4'h0: seg7_digit = 7'b1000000; 4'h1: seg7_digit = 7'b1111001;
            4'h2: seg7_digit = 7'b0100100; 4'h3: seg7_digit = 7'b0110000;
            4'h4: seg7_digit = 7'b0011001; 4'h5: seg7_digit = 7'b0010010;
            4'h6: seg7_digit = 7'b0000010; 4'h7: seg7_digit = 7'b1111000;
            4'h8: seg7_digit = 7'b0000000; 4'h9: seg7_digit = 7'b0010000;
            default: seg7_digit = 7'b1111111;
        endcase
    endfunction

    function [6:0] seg7_letter(input [7:0] ch);
        case (ch)
            "A": seg7_letter = 7'b0001000; "b": seg7_letter = 7'b0000011;
            "C": seg7_letter = 7'b1000110; "d": seg7_letter = 7'b0100001;
            "E": seg7_letter = 7'b0000110; "F": seg7_letter = 7'b0001110;
            "G": seg7_letter = 7'b1000010; "B": seg7_letter = 7'b0000011;
            "D": seg7_letter = 7'b0100001; default: seg7_letter = 7'b1111111;
        endcase
    endfunction

    localparam [6:0] SEG_BLANK = 7'b1111111;
    wire       sharp           = (accidental == "#");
    wire [6:0] s_hex5          = seg7_letter((note_char=="B") ? "b" : note_char);
    wire [6:0] s_hex4          = seg7_digit(octave_ascii - "0");
    wire [6:0] s_hex3          = (d_th == 0) ? SEG_BLANK : seg7_digit(d_th);
    wire [6:0] s_hex2          = ((d_th==0)&&(d_hu==0)) ? SEG_BLANK : seg7_digit(d_hu);
    wire [6:0] s_hex1          = ((d_th==0)&&(d_hu==0)&&(d_ten==0)) ? SEG_BLANK : seg7_digit(d_ten);
    wire [6:0] s_hex0          = seg7_digit(d_one);

    always @(*) begin
        HEX5 = { ~sharp, s_hex5 };
        HEX4 = { 1'b1,   s_hex4 };
        HEX3 = { 1'b1,   s_hex3 };
        HEX2 = { 1'b1,   s_hex2 };
        HEX1 = { 1'b1,   s_hex1 };
        HEX0 = { 1'b1,   s_hex0 };
    end
endmodule

//===========================================================
// Simple Button Debouncer
//===========================================================
module ButtonDebounce(
    input  wire clk,
    input  wire reset_n,
    input  wire btn_n,
    output reg  btn_down,
    output reg  btn_pressed
);
    reg [1:0] sync;
    always @(posedge clk or negedge reset_n)
        if (!reset_n) sync <= 2'b11;
        else sync <= {sync[0], btn_n};

    wire btn_raw = ~sync[1];

    reg [17:0] cnt;
    reg        state;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= 0; cnt <= 0;
        end else if (btn_raw != state) begin
            cnt <= cnt + 1;
            if (&cnt) begin
                state <= btn_raw;
                cnt   <= 0;
            end
        end else cnt <= 0;
    end

    reg state_d;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state_d      <= 0;
            btn_down     <= 0;
            btn_pressed  <= 0;
        end else begin
            state_d      <= state;
            btn_down     <= state;
            btn_pressed  <= state & ~state_d;
        end
    end
endmodule
