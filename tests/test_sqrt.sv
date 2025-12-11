// Module that implements the square root accelerator
module MySQRT(
	input  logic [31:0] REG_IN, 		// Input data, radicand
	input  logic 	    CLK, CHP, RST,	// CLK : Clock, CHP : Chip select, RST : Reset
	output logic [31:0] REG_OUT, 		// Output data, root
	output logic 	    BUSY		// Indicates if the accelerator is working 
);

logic [4:0] 	MAX_ITERATIONS;		// Max iterations is set to Bitsize / 2 since we do pairs
logic [4:0] 	ITERATION;		// Keeps track which iteration we're on
logic [31:0] 	CURR_ROOT;		// Stores the current computed root value
logic [31:0]	REM;			// Stores the currently computed remainder
logic [1:0]  	RADICAND_PAIR;  	// Current pair of bits from radicand
logic [31:0]	CURR_COMPUTE;		// Current radicand being computed
logic [31:0] 	NEXT_REM;        	// NEW: Declare this
logic        	NEXT_ROOT_BIT;   	// NEW: Single bit from PSRC
logic [31:0]	TEST;
	
assign MAX_ITERATIONS = 5'd20;

// Instantiate PRC
PRC PRC_inst (
    .PAIR(RADICAND_PAIR),
    .PREV_REM(REM),
    .CURR_ROOT(CURR_ROOT),
    .REM(NEXT_REM)
);

// Instantiate PSRC
PSRC PSRC_inst (
    .REM(NEXT_REM),
    .ROOT(NEXT_ROOT_BIT)
);

always_ff @(posedge CLK) begin
    if (RST) begin
        BUSY <= 0;
        REG_OUT <= 32'd0;
        ITERATION <= 5'd0;
        CURR_ROOT <= 32'd0;
        REM <= 32'd0;
        CURR_COMPUTE <= 32'd0;
        RADICAND_PAIR <= 2'b00;
    end else if (CHP && !BUSY) begin
        // Cycle 1: Start new computation (Load and prepare first pair)
        BUSY <= 1;
        ITERATION <= 5'd1;
        
        // 1. Initial Remainder: Use the first pair (31:30) of the input
        REM <= {REG_IN[31:30], 30'b0}; // Bits 31:30 of REG_IN are loaded into bits 31:30 of REM
        
        // 2. Shift Register: Store the remaining bits (29:0)
        // This is the data that will be shifted in cycle by cycle
        CURR_COMPUTE <= REG_IN << 2; // Shifted left so the next pair (29:28) is now at 31:30

        // 3. Prepare next pair: The next pair (original 29:28) is now at [31:30]
       RADICAND_PAIR <= 32'(REG_IN << 2)[31:30];
        
        CURR_ROOT <= 32'd0;
    end else if (BUSY) begin
        if (ITERATION == MAX_ITERATIONS) begin
            // Done - store final result
            BUSY <= 0;
            REG_OUT <= {CURR_ROOT[30:0], NEXT_ROOT_BIT}; // Include last bit
            ITERATION <= 5'd0;
        end else begin
            // Update state for next iteration (Cycle 2 through 16)
            ITERATION <= ITERATION + 1;
            
            // 1. Update Remainder
            REM <= NEXT_REM;
            
            // 2. Update Root
            CURR_ROOT <= {CURR_ROOT[30:0], NEXT_ROOT_BIT}; // Shift in new bit
            
            // 3. Prepare the pair for the *next* cycle's computation
            // RADICAND_PAIR gets the next pair (from the MSB of CURR_COMPUTE)
            RADICAND_PAIR <= CURR_COMPUTE[31:30];
            
            // 4. Shift the remaining radicand bits for the *following* cycle
            CURR_COMPUTE <= CURR_COMPUTE << 2;
        end
    end
end

endmodule
