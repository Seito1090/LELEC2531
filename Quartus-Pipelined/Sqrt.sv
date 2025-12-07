module sqrt(
	input  logic [31:0]  REG_IN,
	input  logic 	     CLK, CHP, RST,
	output logic [31:0]  REG_OUT,
	output logic   	     BUSY, // Used for debugging purposes
	output logic [33:0]  DEBUG 	
);

logic [6:0]	iteration;
logic [31:0] 	q, q_next; // Intermediate root (quotient)
logic [31:0]	x, x_next; // Radicand copy
logic [33:0]	ac, ac_next; // accumulator
logic [33:0]	test_res; // Sign test result
logic [6:0]     max_iter;

assign max_iter = 32'd16;

// Computation logic 
always_comb begin
	test_res = ac - {q, 2'b01};
	DEBUG = test_res;
	if (test_res[33] == 0) begin // Test value positive ?
		{ac_next, x_next} = {test_res[31:0], x, 2'b0};
		q_next = {q[30:0], 1'b1}; // Append 1
	end else begin
		{ac_next, x_next} = {ac[31:0], x, 2'b0};
		q_next = {q[30:0], 1'b0}; // Append 0 
	end 
end 

// Management logic
always_ff@(posedge CLK) begin
	// Reset logic 
	if (RST) begin 
		REG_OUT <= 32'd0;
		BUSY <= 0;
		q <= 32'd0;
		iteration <= 7'd0;
		x <= 32'd0;
		ac <= 34'd0;
	// Init logic
	end else if (CHP && !BUSY) begin // If busy don't start
			BUSY <= 1;
			iteration <= 0;
			q <= 0;
			{ac, x} <= {{32{1'b0}}, REG_IN, 2'b0};
	end else if (BUSY) begin
		if (iteration == max_iter - 1) begin // Finished
			BUSY <= 0;
			REG_OUT <= q_next;
		end else begin // Next iteration
			iteration <= iteration + 1;
			x <= x_next;
			ac <= ac_next;
			q <= q_next;
		end 
	end 
end 

endmodule 
		