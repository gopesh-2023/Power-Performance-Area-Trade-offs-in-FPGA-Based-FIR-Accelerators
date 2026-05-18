`timescale 1ns / 1ps

// ==============================================================================
// Sub-module: Approximate Carry-Truncated Adder (CTA)
// ==============================================================================
module approx_cta #(parameter W = 24, parameter K = 4) (
    input  [W-1:0] A,
    input  [W-1:0] B,
    output [W-1:0] Sum
);
    // 1. Probabilistic carry estimation based on the MSBs of the truncated section
    wire carry_est = A[K-1] & B[K-1];

    // 2. Exact carry-propagate for MSBs, utilizing the estimated fast carry-in
    assign Sum[W-1:K] = A[W-1:K] + B[W-1:K] + carry_est;

    // 3. Approximate XOR sum for LSBs (completely eliminates carry ripple logic)
    assign Sum[K-1:0] = A[K-1:0] ^ B[K-1:0];
endmodule

// ==============================================================================
// Main Module: Transposed-Form Approximate FIR Filter
// ==============================================================================
module fir_filter_8_approx_transposed (
    input signed [15:0] input_data,
    input CLK,
    input RST,
    input ENABLE,
    output reg signed [31:0] output_data,
    output signed [15:0] sample_T
);

    // 1. Broadcast Input and Constant Coefficient Multiplication
    wire signed [23:0] px;
    assign px = {{4{input_data[15]}}, input_data, 4'd0};

    // 2. Accumulator Pipeline Registers for Transposed Form (7 Internal states)
    reg signed [23:0] R [0:6];
    
    // Delay registers purely to simulate 'sample_T' correctly in transposed form
    reg signed [15:0] sim_delay [0:7];
    integer j;
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            for (j = 0; j < 8; j = j + 1) sim_delay[j] <= 16'd0;
        end else if (ENABLE) begin
            sim_delay[0] <= input_data;
            for (j = 1; j < 8; j = j + 1) sim_delay[j] <= sim_delay[j-1];
        end
    end
    assign sample_T = sim_delay[7];

    // 3. Carry-Truncated Adder (CTA) Combinational Outputs
    wire [23:0] sum1, sum2, sum3, sum4, sum5, sum6, sum7;

    approx_cta #(.W(24), .K(4)) cta1 (.A(px), .B(R[0]), .Sum(sum1));
    approx_cta #(.W(24), .K(4)) cta2 (.A(px), .B(R[1]), .Sum(sum2));
    approx_cta #(.W(24), .K(4)) cta3 (.A(px), .B(R[2]), .Sum(sum3));
    approx_cta #(.W(24), .K(4)) cta4 (.A(px), .B(R[3]), .Sum(sum4));
    approx_cta #(.W(24), .K(4)) cta5 (.A(px), .B(R[4]), .Sum(sum5));
    approx_cta #(.W(24), .K(4)) cta6 (.A(px), .B(R[5]), .Sum(sum6));
    approx_cta #(.W(24), .K(4)) cta7 (.A(px), .B(R[6]), .Sum(sum7));

    // 4. Systolic Transposed Datapath Pipeline Update
    integer i;
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            for (i = 0; i < 7; i = i + 1) begin
                R[i] <= 24'd0;
            end
            output_data <= 32'd0;
        end else if (ENABLE) begin
            R[0] <= px;       
            R[1] <= sum1;     
            R[2] <= sum2;     
            R[3] <= sum3;     
            R[4] <= sum4;     
            R[5] <= sum5;     
            R[6] <= sum6;     

            output_data <= {{8{sum7[23]}}, sum7};
        end
    end

endmodule