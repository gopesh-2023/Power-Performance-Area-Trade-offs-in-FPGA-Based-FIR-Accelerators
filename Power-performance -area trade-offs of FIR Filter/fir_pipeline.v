`timescale 1ns / 1ps

module fir_pipeline(
    input signed [15:0] input_data,
    input CLK,
    input RST,
    input ENABLE,
    output signed [31:0] output_data,
    output signed [15:0] sampleT
);

    parameter N1 = 8;
    wire signed [N1-1:0] b[0:7];

    // Filter coefficients (0.125 scaled by 128)
    assign b[0] = 8'b00010000;
    assign b[1] = 8'b00010000;
    assign b[2] = 8'b00010000;
    assign b[3] = 8'b00010000;
    assign b[4] = 8'b00010000;
    assign b[5] = 8'b00010000;
    assign b[6] = 8'b00010000;
    assign b[7] = 8'b00010000;

    // Shift registers for input samples
    reg signed [15:0] samples[0:6];

    // PIPELINE STAGE 1: Multiplications
    (* use_dsp = "yes" *) reg signed [31:0] mult_reg[0:7];

    // PIPELINE STAGE 2: Intermediate Addition (Pairs)
    reg signed [31:0] add_stage1_reg[0:3];

    // PIPELINE STAGE 3: Final sum
    reg signed [31:0] output_data_reg;

    always @(posedge CLK) begin
        if (RST == 1'b1) begin
            samples[0] <= 0; samples[1] <= 0; samples[2] <= 0; samples[3] <= 0;
            samples[4] <= 0; samples[5] <= 0; samples[6] <= 0;
            
            mult_reg[0] <= 0; mult_reg[1] <= 0; mult_reg[2] <= 0; mult_reg[3] <= 0;
            mult_reg[4] <= 0; mult_reg[5] <= 0; mult_reg[6] <= 0; mult_reg[7] <= 0;
            
            add_stage1_reg[0] <= 0; add_stage1_reg[1] <= 0; 
            add_stage1_reg[2] <= 0; add_stage1_reg[3] <= 0;
            
            output_data_reg <= 0;
        end
        else if (ENABLE == 1'b1) begin 
            // ---------------------------------------------------------
            // Shift input data
            // ---------------------------------------------------------
            samples[0] <= input_data;
            samples[1] <= samples[0];
            samples[2] <= samples[1];
            samples[3] <= samples[2];
            samples[4] <= samples[3];
            samples[5] <= samples[4];
            samples[6] <= samples[5];

            // ---------------------------------------------------------
            // Stage 1: Multiplications
            // ---------------------------------------------------------
            mult_reg[0] <= b[0] * input_data;
            mult_reg[1] <= b[1] * samples[0];
            mult_reg[2] <= b[2] * samples[1];
            mult_reg[3] <= b[3] * samples[2];
            mult_reg[4] <= b[4] * samples[3];
            mult_reg[5] <= b[5] * samples[4];
            mult_reg[6] <= b[6] * samples[5];
            mult_reg[7] <= b[7] * samples[6];
            
            // ---------------------------------------------------------
            // Stage 2: Add in Pairs (Reduces critical path by 50%)
            // ---------------------------------------------------------
            add_stage1_reg[0] <= mult_reg[0] + mult_reg[1];
            add_stage1_reg[1] <= mult_reg[2] + mult_reg[3];
            add_stage1_reg[2] <= mult_reg[4] + mult_reg[5];
            add_stage1_reg[3] <= mult_reg[6] + mult_reg[7];

            // ---------------------------------------------------------
            // Stage 3: Final Addition
            // ---------------------------------------------------------
            output_data_reg <= add_stage1_reg[0] + add_stage1_reg[1] + 
                               add_stage1_reg[2] + add_stage1_reg[3];
        end
    end

    assign output_data = output_data_reg;
    assign sampleT = samples[0];                         

endmodule