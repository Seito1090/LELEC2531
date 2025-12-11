// Partial Remainder Calculator

// This calculates the remainder value at each iteration of the algorithm. 
// Tt does shifting and append, substraction, and new remainder is given out 
module PRC(
	input  logic [1:0]  PAIR, 	// Pair of bits 
	input  logic [31:0] PREV_REM, 	// Previous remainder
	input  logic [31:0] CURR_ROOT,	// Current value of root
	output logic [31:0] REM		// Computed remainder
);

logic [31:0] NEW_REM;
logic [31:0] TEST_ROOT;

always_comb begin 
// Append PAIR to PREV_REM 
	NEW_REM = {PREV_REM[29:0], PAIR[1:0]};
// Append 01 to the existing answer = exisiting root value that has been calculated so far
	TEST_ROOT = {CURR_ROOT[29:0], 2'b01};
// Substract to get REM
	REM = NEW_REM - TEST_ROOT;
end 
endmodule
