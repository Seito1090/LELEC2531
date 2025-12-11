// Partial Square Root Calculator 

// This module calculates one given digit of the root.
// It checks if the value is pos / neg, sets the root digit
module PSRC(
	input  logic [31:0] REM,	// Calculated Remainder  
	output logic        ROOT	// Computed digit of root
);


always_comb begin
// Check value and set root
	if (REM[31]) begin 
		ROOT = 0;
	end else begin 
		ROOT = 1;
	end
end
endmodule
