module SqrtAccelerator (
    // Signals between our accelerator and system BUS
    input  logic        clk,
    input  logic        reset, // Set registers to 0 and resets the core
    input  logic        cs, // High if the CPU wants to talk with the accelerator, if 0 we ignore signals
    input  logic        we, // 1 = CPU wants to Write data to the accelerator; 0 = CPU wants to Read data from the accelerator.
    input  logic [31:0] addr, // Which register inside the wrapper the CPU wants to access (input, output , status)
    input  logic [31:0] wdata, // If CPU is writting, it carries the radicand (number we want the square root of)
    output logic [31:0] rdata // The wrapper places the requested data (result or status) on this wire so the CPU can read it.
);

    logic [31:0] input_reg;
    logic [31:0] output_reg;
    logic        start;
    logic        busy, done;
    logic [31:0] result;

    SqrtCore core (
        .clk(clk),
        .rst(reset),
        .start(start),
        .radicand(input_reg),
        .root(result),
        .busy(busy),
        .done(done)
    );

    // Write logic (Send data to Core)
    // When the CPU writes to Offset 0x00, the hardware simultaneously saves the number into input_reg and pulses the start signal to tell the Core to wake up.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            input_reg <= 0;
            start     <= 0;
        end else begin
            start <= 0; 
            // Write to Offset 0x0 (address 0x600 in this case) triggers start 
            // IF: Chip Select is ON, Write Enable is ON, and Address is 0x0
            if (cs && we && addr[3:2] == 2'b00) begin
                input_reg <= wdata; // Capture data from bus
                start     <= 1; // Pulse start signal HIGH for one cycle
            end
        end
    end

    // Saving / resetting our output register
    always_ff @(posedge clk or posedge reset) begin
        if (reset) output_reg <= 0;
        else if (done) output_reg <= result; //  While the Core is busy, done is 0, output_reg stays unchanged.
    end

    // Read logic, we use addr[3:2] to ignore byte alignment issues.
    // So in the end we have 0x60- with - being : 0x0 = 0000 (00), 0x4 = 0100 (01), 0x8 = 1000 (10)
    always_comb begin
        rdata = 32'b0;
        // The CPU can poll offset 0x08. If it reads a 1, the accelerator is processing. If 0, it's done. Then the CPU reads offset 0x04 to get the answer.
        if (cs && !we) begin
            case (addr[3:2])
                2'b10:   rdata = {31'b0, busy}; // Offset 0x8 or 0xC -> Status
                2'b01:   rdata = output_reg;    // Offset 0x4 -> Result
                2'b00:   rdata = input_reg;     // Offset 0x0 -> Input
                default: rdata = output_reg;    // Fallback: Show result
            endcase
        end
    end

endmodule

module SqrtCore (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [31:0] radicand, // From CPU write
    output logic [31:0] root,
    output logic        busy,
    output logic        done
);
    // State machine states
    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        COMPUTE     = 2'b01,
        DONE_STATE  = 2'b10 // Signals completion for one cycle
    } state_t;
    
    state_t state, next_state;
    
    // Registers (variables)
    logic [31:0] x; // (Radicand/Remainder): The number we are processing
    logic [31:0] q; // (Quotient/Root): The growing result
    logic [31:0] ac; // (Accumulator): Holds the high-order remainder bits for the subtraction test
    logic [4:0]  iter; //  A counter from 0 to 15
    
    // Combinational signals
    logic [31:0] ac_shifted;
    logic [31:0] x_shifted;
    logic [31:0] test_res;
    
    assign ac_shifted = {ac[29:0], x[31:30]}; // Shift AC left, pull in 2 bits from X
    assign x_shifted  = {x[29:0], 2'b00}; // Shift x (radicand) to left, fill with zeroes
    assign test_res   = ac_shifted - {q[29:0], 2'b01}; // Try subtracting (2*Q + 1), 
    
    assign busy = (state == COMPUTE);
    assign done = (state == DONE_STATE);
    
    // State register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
            end
            COMPUTE: begin
                if (iter == 5'd15)
                    next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = next_state;
        endcase
    end
    
    // Datapath
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            root <= 32'd0;
            iter <= 5'd0;
            x    <= 32'd0;
            q    <= 32'd0;
            ac   <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        iter <= 5'd0; // Set iteration number to 0
                        x    <= radicand; // Load input radicant to x register
                        q    <= 32'd0;
                        ac   <= 32'd0;
                    end
                end
                
                COMPUTE: begin
                    // Perform iteration
                    // Signe check, if the substraction is positive (MSB = 0)
                    if (test_res[31] == 1'b0) begin
                        ac <= test_res; // Keep substracted test_res and use it for the next iteration
                        q  <= {q[30:0], 1'b1}; // Record 1 for the root result
                    // Signe check, if the substraction is negatie (MSB = 1)
                    end else begin
                        ac <= ac_shifted; // Reuse previous acc for the next iteration "and shift it".
                        q  <= {q[30:0], 1'b0}; // Record 0 for the root result
                    end
                    
                    x    <= x_shifted; // Shift x (radicant) to left by 2 to prepare next bits pair
                    iter <= iter + 5'd1; // increment counter
                    
                    // Compute and save result on last iteration (same cycle)
                    if (iter == 5'd15) begin // Algo is finished on iter == 15 (16th iteration) because there is 16 pairs of bits in a 32bits radicant
                        root <= (test_res[31] == 1'b0) ? {q[30:0], 1'b1} : {q[30:0], 1'b0};
                    end
                end
                
                DONE_STATE: begin
                    // Transition back to IDLE next cycle
                end
                
                default: begin
                    // Do nothing
                end
            endcase
        end
    end
endmodule