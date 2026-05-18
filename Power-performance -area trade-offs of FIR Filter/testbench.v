`timescale 1ns / 1ps 

module testbench;

// Parameters
parameter N1 = 8;
parameter N2 = 16;
parameter N3 = 32;

// Standard Testbench Signals
reg CLK;
reg RST;
reg ENABLE;
reg signed [N2-1:0] input_data;
wire signed [N3-1:0] output_data;
wire signed [N2-1:0] sampleT;

// File I/O Variables
integer FILE_IN;
integer FILE_OUT;
integer scan_status;

// -------------------------------------------------------------------------
// THE UNIVERSAL INSTANTIATION BLOCK
// Uncomment ONLY the module you are currently testing.
// -------------------------------------------------------------------------

//fir_baseline UUT (.input_data(input_data), .CLK(CLK), .RST(RST), .ENABLE(ENABLE), .output_data(output_data), .sampleT(sampleT));
//fir_pipeline UUT (.input_data(input_data), .CLK(CLK), .RST(RST), .ENABLE(ENABLE), .output_data(output_data), .sampleT(sampleT));
//fir_symmetric UUT (.input_data(input_data), .CLK(CLK), .RST(RST), .ENABLE(ENABLE), .output_data(output_data), .sampleT(sampleT));
fir_mac      UUT (.input_data(input_data), .CLK(CLK), .RST(RST), .ENABLE(ENABLE), .output_data(output_data), .sampleT(sampleT));
//fir_shift_add      UUT (.input_data(input_data), .CLK(CLK), .RST(RST), .ENABLE(ENABLE), .output_data(output_data), .sampleT(sampleT));
//fir_filter_6_approx_da UUT(.input_data(input_data), .output_data(output_data), .CLK(CLK), .RST(RST), .ENABLE(ENABLE), .sampleT(sampleT));
// -------------------------------------------------------------------------

// Clock Generation (100 MHz -> 10ns period)
always #5 CLK = ~CLK;

initial begin
    // Open the files using ABSOLUTE paths
    FILE_IN  = $fopen("C:/Users/GOPESH/OneDrive/Desktop/FIR FILTER FINAL/FinalYrProj/input.data", "r"); 
    FILE_OUT = $fopen("C:/Users/GOPESH/OneDrive/Desktop/FIR FILTER FINAL/FinalYrProj/save.data", "w");
    
    // Error checking to prevent silent failures
    if (FILE_IN == 0) begin
        $display("ERROR: Could not open D:/FinalYrProj/input.data! Check the path.");
        $finish;
    end

    // Initialize state
    CLK = 0;
    RST = 1'b1;
    ENABLE = 1'b0;
    input_data = 0;
    #60;
    
    // Release reset, start filter
    RST = 1'b0;
    ENABLE = 1'b1;
    
    // Dynamically read until end of file
    while (!$feof(FILE_IN)) begin
        @(posedge CLK);
        scan_status = $fscanf(FILE_IN, "%b\n", input_data);
        
        // Save the output from the PREVIOUS cycle
        $fdisplay(FILE_OUT, "%b", output_data);
    end
    
    // Clean up
    $fclose(FILE_IN);
    $fclose(FILE_OUT);
    $display("Simulation Complete! All samples processed.");
    $finish;
end

endmodule