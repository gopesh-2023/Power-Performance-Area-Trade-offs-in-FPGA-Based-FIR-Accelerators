`timescale 1ns / 1ps

module fir_mac(
    input signed [15:0] input_data,
    input CLK,
    input RST,
    input ENABLE,
    output signed [31:0] output_data,
    output signed [15:0] sampleT
);

    // Filter coefficients
    wire signed [15:0] b[0:7];
    assign b[0] = 16'sd4096;
    assign b[1] = 16'sd4096;
    assign b[2] = 16'sd4096;
    assign b[3] = 16'sd4096;
    assign b[4] = 16'sd4096;
    assign b[5] = 16'sd4096;
    assign b[6] = 16'sd4096;
    assign b[7] = 16'sd4096;

    // Delay line
    reg signed [15:0] x[0:7];
    assign sampleT = x[0]; // Debug port

    // The SINGLE Multiplier and Accumulator
    (* use_dsp = "yes" *) reg signed [31:0] accumulator;
    reg signed [31:0] output_data_reg;
    
    // State machine counter (0 to 8)
    reg [3:0] state;

    always @(posedge CLK) begin
        if (RST == 1'b1) begin
            x[0]<=0; x[1]<=0; x[2]<=0; x[3]<=0;
            x[4]<=0; x[5]<=0; x[6]<=0; x[7]<=0;
            accumulator <= 0;
            output_data_reg <= 0;
            state <= 0;
        end
        else if (ENABLE == 1'b1) begin
            
            if (state == 0) begin
                // State 0: Shift in new data, reset accumulator
                x[0] <= input_data;
                x[1] <= x[0];
                x[2] <= x[1];
                x[3] <= x[2];
                x[4] <= x[3];
                x[5] <= x[4];
                x[6] <= x[5];
                x[7] <= x[6];
                
                accumulator <= 0;
                state <= 1;
            end
            else if (state >= 1 && state <= 8) begin
                // States 1-8: The MAC Loop (Multiply and Accumulate)
                // Use (state-1) to access the correct index
                accumulator <= accumulator + (x[state-1] * b[state-1]);
                
                if (state == 8) begin
                    // Final state: Output the result and loop back to 0
                    output_data_reg <= accumulator + (x[7] * b[7]);
                    state <= 0;
                end else begin
                    state <= state + 1;
                end
            end
        end
    end

    assign output_data = output_data_reg;

endmodule