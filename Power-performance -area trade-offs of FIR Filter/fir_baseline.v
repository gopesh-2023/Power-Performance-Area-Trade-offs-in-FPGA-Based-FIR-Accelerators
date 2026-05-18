`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.04.2026 21:39:18
// Design Name: 
// Module Name: fir_filter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module fir_filter(input_data, CLK, RST, ENABLE, output_data, sampleT);
//FIR coeffecient word width
parameter N1 = 8;
//input data word width
parameter N2 = 16;
//output data word width
parameter N3 = 32;

//This array is used to store the coefficients
wire signed [N1-1:0] b[0:7];

//filter coefficients
assign b[0] = 8'b00010000;
assign b[1] = 8'b00010000;
assign b[2] = 8'b00010000;
assign b[3] = 8'b00010000;
assign b[4] = 8'b00010000;
assign b[5] = 8'b00010000;
assign b[6] = 8'b00010000;
assign b[7] = 8'b00010000;

//input data
input signed [N2-1:0] input_data;

//output data samples
output signed [N2-1:0] sampleT;

//clock
input CLK;

//used to set to zero all filter taps
input RST;

//used to enable the filter
input ENABLE;

//filtered data
output signed [N3-1:0] output_data;

//this register is used to store the output
reg signed [N3-1:0] output_data_reg;

//this array is used to store samples and to shift them
reg signed [N2-1:0] samples[0:6];

always @(posedge CLK)
begin
    if (RST == 1'b1)
        begin
            samples[0] <= 0;
            samples[1] <= 0;
            samples[2] <= 0;
            samples[3] <= 0;
            samples[4] <= 0;
            samples[5] <= 0;
            samples[6] <= 0;
            samples[7] <= 0;
            output_data_reg <= 0;
        end
    if ((ENABLE == 1'b1) && (RST == 1'b0))
        begin 
            output_data_reg <= b[0]*input_data + b[1]*samples[0] + b[2]*samples[1] + b[3]*samples[2] + b[4]*samples[3] + b[5]*samples[4] + b[6]*samples[5] + b[7]*samples[6];
            samples[0] <= input_data;
            samples[1] <= samples[0];
            samples[2] <= samples[1];
            samples[3] <= samples[2];
            samples[4] <= samples[3];
            samples[5] <= samples[4];
            samples[6] <= samples[5];
        end
end
assign output_data = output_data_reg;
assign sampleT = samples[0];                         
endmodule
