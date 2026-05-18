`timescale 1ns / 1ps

module fir_filter_6_approx_da(
    input signed [15:0] input_data,
    input CLK,
    input RST,
    input ENABLE,
    output signed [31:0] output_data,
    output signed [15:0] sampleT
);

    //FIR coefficient word width
    parameter N1 = 8;
    //input data word width
    parameter N2 = 16;
    //output data word width
    parameter N3 = 32;

    // Filter coefficients (Exactly matching your Arch 1)
    wire signed [N1-1:0] b [0:7];
    assign b[0] = 8'b00010000;
    assign b[1] = 8'b00010000;
    assign b[2] = 8'b00010000;
    assign b[3] = 8'b00010000;
    assign b[4] = 8'b00010000;
    assign b[5] = 8'b00010000;
    assign b[6] = 8'b00010000;
    assign b[7] = 8'b00010000;

    // 1. INPUT TRUNCATION & ERROR COMPENSATION (IEEE Paper Sec IV.A)
    // Truncating bottom 4 bits to save area/power, adding 2^(k-1) = 8 for compensation
    wire signed [15:0] din_trunc;
    assign din_trunc = {input_data[15:4], 4'b0000} + 16'h0008;

    // 2. DELAY LINE (Shift Register)
    reg signed [15:0] delay_line [0:7];
    integer i;
    always @(posedge CLK) begin
        if (RST) begin
            for (i=0; i<8; i=i+1) delay_line[i] <= 0;
        end else if (ENABLE) begin
            delay_line[0] <= din_trunc;
            for (i=1; i<8; i=i+1) delay_line[i] <= delay_line[i-1];
        end
    end

    // Additional output for testing (Matches your original design)
    assign sampleT = delay_line[0];

    // 3. APPROXIMATE RECODING ADDERS FOR 3X
    wire signed [15:0] x_times_3 [0:7];
    genvar g;
    generate
        for (g=0; g<8; g=g+1) begin : gen_3x
            approx_loa_adder #(16, 3) add_3x_inst (
                .a(delay_line[g] <<< 1),
                .b(delay_line[g]),
                .sum(x_times_3[g])
            );
        end
    endgenerate

    // 4. RADIX-8 BOOTH PARTIAL PRODUCT GENERATOR
    // Since N1=8 (8-bit coefficients), we need only 3 Radix-8 slices (8/3 rounded up = 3)
    reg signed [19:0] pp [0:2][0:7]; 

    function integer get_booth_digit;
        input [7:0] c;
        input integer slice_idx;
        reg [9:0] padded_coeff;
        reg [3:0] window;
        begin
            padded_coeff = {c[7], c[7], c}; // Sign extend by 2 bits for bounds
            if (slice_idx == 0)
                window = {padded_coeff[2:0], 1'b0};
            else
                window = padded_coeff[(slice_idx*3 + 2) -: 4]; 

            case(window) // Radix-8 Booth Truth Table
                4'b0000, 4'b1111: get_booth_digit = 0;
                4'b0001, 4'b0010: get_booth_digit = 1;
                4'b0011, 4'b0100: get_booth_digit = 2;
                4'b0101, 4'b0110: get_booth_digit = 3;
                4'b0111:          get_booth_digit = 4;
                4'b1000:          get_booth_digit = -4;
                4'b1001, 4'b1010: get_booth_digit = -3;
                4'b1011, 4'b1100: get_booth_digit = -2;
                4'b1101, 4'b1110: get_booth_digit = -1;
                default:          get_booth_digit = 0;
            endcase
        end
    endfunction

    integer slice, tap, digit;
    always @(*) begin
        for (slice=0; slice<3; slice=slice+1) begin
            for (tap=0; tap<8; tap=tap+1) begin
                digit = get_booth_digit(b[tap], slice);
                case(digit)
                    4:  pp[slice][tap] = delay_line[tap] <<< 2;
                    3:  pp[slice][tap] = x_times_3[tap];
                    2:  pp[slice][tap] = delay_line[tap] <<< 1;
                    1:  pp[slice][tap] = delay_line[tap];
                    0:  pp[slice][tap] = 0;
                    -1: pp[slice][tap] = -delay_line[tap];
                    -2: pp[slice][tap] = -(delay_line[tap] <<< 1);
                    -3: pp[slice][tap] = -x_times_3[tap];
                    -4: pp[slice][tap] = -(delay_line[tap] <<< 2);
                    default: pp[slice][tap] = 0;
                endcase
            end
        end
    end

    // 5. APPROXIMATE WALLACE TREE (AWT) ACCUMULATION
    wire signed [19:0] sum_L1 [0:2][0:3];
    wire signed [19:0] sum_L2 [0:2][0:1];
    wire signed [19:0] sum_L3 [0:2];

    generate
        genvar s, k;
        for (s=0; s<3; s=s+1) begin : gen_slice_sum
            for (k=0; k<4; k=k+1) begin : gen_L1
                approx_loa_adder #(20, 3) add_L1 (.a(pp[s][2*k]), .b(pp[s][2*k+1]), .sum(sum_L1[s][k]));
            end
            for (k=0; k<2; k=k+1) begin : gen_L2
                approx_loa_adder #(20, 3) add_L2 (.a(sum_L1[s][2*k]), .b(sum_L1[s][2*k+1]), .sum(sum_L2[s][k]));
            end
            approx_loa_adder #(20, 3) add_L3 (.a(sum_L2[s][0]), .b(sum_L2[s][1]), .sum(sum_L3[s]));
        end
    endgenerate

    // Pipeline register to sever the critical path
    reg signed [19:0] slice_sum_reg [0:2];
    always @(posedge CLK) begin
        if (RST) begin
            for (i=0; i<3; i=i+1) slice_sum_reg[i] <= 0;
        end else if (ENABLE) begin
            for (i=0; i<3; i=i+1) slice_sum_reg[i] <= sum_L3[i];
        end
    end

    // 6. FINAL SHIFT-AND-ACCUMULATE DA STAGE
    wire signed [31:0] ext_s0 = slice_sum_reg[0]; 
    wire signed [31:0] ext_s1 = slice_sum_reg[1];
    wire signed [31:0] ext_s2 = slice_sum_reg[2]; 

    wire signed [31:0] final_y = ext_s0 + (ext_s1 <<< 3) + (ext_s2 <<< 6);

    // Output register
    reg signed [31:0] output_data_reg;
    always @(posedge CLK) begin
        if (RST)
            output_data_reg <= 0;
        else if (ENABLE)
            output_data_reg <= final_y; 
    end

    assign output_data = output_data_reg;

endmodule

// ----------------------------------------------------------------------------------
// Sub-Module: Lower-Part-OR Adder (LOA) for Approximate Wallace Tree
// ----------------------------------------------------------------------------------
module approx_loa_adder #(
    parameter WIDTH = 20,
    parameter APPROX_BITS = 3
)(
    input signed [WIDTH-1:0] a,
    input signed [WIDTH-1:0] b,
    output signed [WIDTH-1:0] sum
);
    wire [APPROX_BITS-1:0] lower_sum = a[APPROX_BITS-1:0] | b[APPROX_BITS-1:0];
    wire carry_in = a[APPROX_BITS-1] & b[APPROX_BITS-1];
    wire [WIDTH-1:APPROX_BITS] upper_sum = a[WIDTH-1:APPROX_BITS] + b[WIDTH-1:APPROX_BITS] + carry_in;
    assign sum = {upper_sum, lower_sum};
endmodule