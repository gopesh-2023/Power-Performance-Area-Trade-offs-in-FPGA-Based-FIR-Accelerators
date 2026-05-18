`timescale 1ns / 1ps

// ==============================================================================
// Sub-module: Approximate Carry-Save Adder (CSA)
// ==============================================================================
module approx_csa #(parameter W = 24, parameter K = 4) (
    input  [W-1:0] A,
    input  [W-1:0] B,
    input  [W-1:0] C,
    output [W-1:0] Sum,
    output [W-1:0] Carry
);
    // Accurate MSB part: Standard 3:2 Carry-Save logic
    assign Sum[W-1:K]   = A[W-1:K] ^ B[W-1:K] ^ C[W-1:K];
    assign Carry[W-1:K] = (A[W-1:K] & B[W-1:K]) | (B[W-1:K] & C[W-1:K]) | (A[W-1:K] & C[W-1:K]);

    // Approximate LSB part: OR-based logic to eliminate carry switching
    assign Sum[K-1:0]   = A[K-1:0] | B[K-1:0] | C[K-1:0];
    assign Carry[K-1:0] = {K{1'b0}}; // No carry generated in the LSBs
endmodule

// ==============================================================================
// Main Module: Approximate CSA FIR Filter
// ==============================================================================
module fir_filter_7_approx_csa (
    input signed [15:0] input_data,
    input CLK,
    input RST,
    input ENABLE,
    output reg signed [31:0] output_data,
    output signed [15:0] sample_T
);

    // 1. Tapped Delay Line
    reg signed [15:0] delay [0:7];
    integer i;
    
    // Connect sample_T to the last tap for testbench tracking
    assign sample_T = delay[7];

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            for (i = 0; i < 8; i = i + 1)
                delay[i] <= 16'd0;
        end else if (ENABLE) begin
            delay[0] <= input_data;
            for (i = 1; i < 8; i = i + 1)
                delay[i] <= delay[i-1];
        end
    end

    // 2. Coefficient Multiplication (Hardwired Shift by 4 for Coeff = 16)
    wire [23:0] p_ext [0:7];
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : bit_ext
            // Sign extend 16-bit to 20-bit, shift left by 4, yield 24-bit partial sum
            assign p_ext[j] = {{4{delay[j][15]}}, delay[j], 4'b0000};
        end
    endgenerate

    // 3. Approximate CSA Tree - Level 1 (Reduces 8 operands)
    wire [23:0] S1, C1, S2, C2;
    approx_csa #(.W(24), .K(4)) csa1 (.A(p_ext[0]), .B(p_ext[1]), .C(p_ext[2]), .Sum(S1), .Carry(C1));
    approx_csa #(.W(24), .K(4)) csa2 (.A(p_ext[3]), .B(p_ext[4]), .C(p_ext[5]), .Sum(S2), .Carry(C2));

    // 4. Approximate CSA Tree - Level 2
    wire [23:0] S3, C3, S4, C4;
    approx_csa #(.W(24), .K(4)) csa3 (.A(S1), .B({C1[22:0], 1'b0}), .C(p_ext[6]), .Sum(S3), .Carry(C3));
    approx_csa #(.W(24), .K(4)) csa4 (.A(S2), .B({C2[22:0], 1'b0}), .C(p_ext[7]), .Sum(S4), .Carry(C4));

    // 5. Structural Pipeline Register
    reg [23:0] S3_reg, C3_reg, S4_reg, C4_reg;
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            S3_reg <= 24'd0; C3_reg <= 24'd0;
            S4_reg <= 24'd0; C4_reg <= 24'd0;
        end else if (ENABLE) begin
            S3_reg <= S3; C3_reg <= C3;
            S4_reg <= S4; C4_reg <= C4;
        end
    end

    // 6. Approximate CSA Tree - Level 3
    wire [23:0] S5, C5;
    approx_csa #(.W(24), .K(4)) csa5 (.A(S3_reg), .B({C3_reg[22:0], 1'b0}), .C(S4_reg), .Sum(S5), .Carry(C5));

    // 7. Approximate CSA Tree - Level 4
    wire [23:0] S6, C6;
    approx_csa #(.W(24), .K(4)) csa6 (.A(S5), .B({C5[22:0], 1'b0}), .C({C4_reg[22:0], 1'b0}), .Sum(S6), .Carry(C6));

    // 8. Final Exact Carry Propagate Adder (CPA)
    wire [23:0] final_sum = S6 + {C6[22:0], 1'b0};

    // Output logic
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            output_data <= 32'd0;
        end else if (ENABLE) begin
            output_data <= {{8{final_sum[23]}}, final_sum};
        end
    end

endmodule