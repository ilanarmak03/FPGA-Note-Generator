//===========================================================
// Frequency Measurement Module (Fully Commented)
// Measures frequency of a square wave by counting 50MHz cycles
// between rising edges.
//===========================================================
module Freq_Measure(
    input  wire       clk,           // 50 MHz system clock
    input  wire       reset_n,       // asynchronous active-low reset
    input  wire       signal_in,     // incoming square wave to measure
    output reg [15:0] measured_freq  // measured frequency in Hz
);

    // Store previous sample so we can detect rising edges
    reg prev_sample;

    // Stores the number of clock cycles measured for one full period
    reg [31:0] period_count;

    // Counts cycles between rising edges
    reg [31:0] cycle_counter;

    //===========================================================
    // MAIN LOGIC — triggered on rising edge of 50MHz clock
    //===========================================================
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset everything to known state
            prev_sample    <= 1'b0;
            cycle_counter  <= 32'd0;
            period_count   <= 32'd0;
            measured_freq  <= 16'd0;

        end else begin

            // Save input from previous cycle for edge detection
            prev_sample <= signal_in;

            // Count number of 50MHz cycles since last rising edge
            cycle_counter <= cycle_counter + 1;

            //===================================================
            // RISING EDGE DETECTION
            // Detect transition: prev_sample = 0 AND signal_in = 1
            //===================================================
            if (!prev_sample && signal_in) begin

                // Store number of cycles measured for one full period
                period_count <= cycle_counter;

                // Reset counter for next period measurement
                cycle_counter <= 0;

                //===================================================
                // Convert period to frequency:
                //    freq = 50,000,000 / period_count
                //
                // Only update if period is non-zero
                //===================================================
                if (period_count != 0)
                    measured_freq <= 50_000_000 / period_count;
                else
                    measured_freq <= 0;

            end
        end
    end

endmodule
