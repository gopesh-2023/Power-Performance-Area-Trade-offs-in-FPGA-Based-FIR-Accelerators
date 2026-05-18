`timescale 1ns / 1ps

module fir_shift_add(
    input signed [15:0] input_data,
    input CLK,
    input RST,
    input ENABLE,
    output signed [31:0] output_data,
    output signed [15:0] sampleT
);

    // Shift registers for input samples (The Delay Line)
    reg signed [15:0] samples[0:6];

    // Register to hold the final sum
    reg signed [31:0] output_data_reg;

    // ---------------------------------------------------------
    // Multiplier-less Logic
    // Multiplying by 16 (8'b00010000) is identical to shifting left by 4.
    // Sign-extend the 16-bit inputs to 32-bit, then shift (<<< 4)
    // ---------------------------------------------------------
    wire signed [31:0] shifted_val_0 = {{16{input_data[15]}}, input_data} <<< 4;
    wire signed [31:0] shifted_val_1 = {{16{samples[0][15]}}, samples[0]} <<< 4;
    wire signed [31:0] shifted_val_2 = {{16{samples[1][15]}}, samples[1]} <<< 4;
    wire signed [31:0] shifted_val_3 = {{16{samples[2][15]}}, samples[2]} <<< 4;
    wire signed [31:0] shifted_val_4 = {{16{samples[3][15]}}, samples[3]} <<< 4;
    wire signed [31:0] shifted_val_5 = {{16{samples[4][15]}}, samples[4]} <<< 4;
    wire signed [31:0] shifted_val_6 = {{16{samples[5][15]}}, samples[5]} <<< 4;
    wire signed [31:0] shifted_val_7 = {{16{samples[6][15]}}, samples[6]} <<< 4;

    always @(posedge CLK) begin
        if (RST == 1'b1) begin
            samples[0] <= 0; samples[1] <= 0; samples[2] <= 0; samples[3] <= 0;
            samples[4] <= 0; samples[5] <= 0; samples[6] <= 0;
            
            output_data_reg <= 0;
        end
        else if (ENABLE == 1'b1) begin 
            // Shift input data down the delay line
            samples[0] <= input_data;
            samples[1] <= samples[0];
            samples[2] <= samples[1];
            samples[3] <= samples[2];
            samples[4] <= samples[3];
            samples[5] <= samples[4];
            samples[6] <= samples[5];

            // Add all the shifted values together directly
            // ZERO multipliers used
            output_data_reg <= shifted_val_0 + shifted_val_1 + 
                               shifted_val_2 + shifted_val_3 + 
                               shifted_val_4 + shifted_val_5 + 
                               shifted_val_6 + shifted_val_7;
        end
    end

    assign output_data = output_data_reg;
    assign sampleT = samples[0];                         

endmodule