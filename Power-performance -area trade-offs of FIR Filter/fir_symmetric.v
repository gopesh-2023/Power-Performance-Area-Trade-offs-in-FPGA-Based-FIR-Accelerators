`timescale 1ns / 1ps

module fir_symmetric(
    input signed [15:0] input_data,
    input CLK,
    input RST,
    input ENABLE,
    output signed [31:0] output_data,
    output signed [15:0] sampleT
);

    // Filter coefficients (0.125 scaled by 128)
    wire signed [15:0] b0 = 16'sd4096;
    wire signed [15:0] b1 = 16'sd4096;
    wire signed [15:0] b2 = 16'sd4096;
    wire signed [15:0] b3 = 16'sd4096;

    // Shift registers for input samples (Delay Line)
    reg signed [15:0] x[0:6];

    // Pre-Adders (Adding symmetric taps together)
    wire signed [16:0] pre_add_0;
    wire signed [16:0] pre_add_1;
    wire signed [16:0] pre_add_2;
    wire signed [16:0] pre_add_3;

    // Expand to 17 bits to prevent overflow during addition
    assign pre_add_0 = {input_data[15], input_data} + {x[6][15], x[6]};
    assign pre_add_1 = {x[0][15], x[0]} + {x[5][15], x[5]};
    assign pre_add_2 = {x[1][15], x[1]} + {x[4][15], x[4]};
    assign pre_add_3 = {x[2][15], x[2]} + {x[3][15], x[3]};

    // The Multipliers (Only 4 needed)
    wire signed [31:0] mult_0 = pre_add_0 * b0;
    wire signed [31:0] mult_1 = pre_add_1 * b1;
    wire signed [31:0] mult_2 = pre_add_2 * b2;
    wire signed [31:0] mult_3 = pre_add_3 * b3;

    // Output Register
    reg signed [31:0] output_data_reg;

    always @(posedge CLK) begin
        if (RST == 1'b1) begin
            x[0] <= 0; x[1] <= 0; x[2] <= 0; x[3] <= 0;
            x[4] <= 0; x[5] <= 0; x[6] <= 0;
            output_data_reg <= 0;
        end
        else if (ENABLE == 1'b1) begin 
            // Shift input data
            x[0] <= input_data;
            x[1] <= x[0];
            x[2] <= x[1];
            x[3] <= x[2];
            x[4] <= x[3];
            x[5] <= x[4];
            x[6] <= x[5];

            // Final Sum (Only adding 4 things together instead of 8)
            output_data_reg <= mult_0 + mult_1 + mult_2 + mult_3;
        end
    end

    assign output_data = output_data_reg;
    assign sampleT = x[0];                         

endmodule