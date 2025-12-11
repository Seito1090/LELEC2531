module SqrtAccelerator (
    input  logic        clk,
    input  logic        reset,
    input  logic        cs,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
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

    // WRITE LOGIC (Positive Edge is safer for SignalTap/Constraints)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            input_reg <= 0;
            start     <= 0;
        end else begin
            start <= 0; 
            // Write to Offset 0x0 triggers start
            if (cs && we && addr[3:2] == 2'b00) begin
                input_reg <= wdata;
                start     <= 1; 
            end
        end
    end

    // RESULT CAPTURE
    always_ff @(posedge clk or posedge reset) begin
        if (reset) output_reg <= 0;
        else if (done) output_reg <= result;
    end

    // ============================================================
    // FIX: ROBUST COMBINATIONAL READ
    // ============================================================
    // We use addr[3:2] to ignore byte alignment issues.
    // 0x0 = 0000 (00), 0x4 = 0100 (01), 0x8 = 1000 (10)
    always_comb begin
        rdata = 32'b0;
        if (cs && !we) begin
            case (addr[3:2])
                2'b10:   rdata = {31'b0, busy | done}; // Offset 0x8 or 0xC -> Status
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
    input  logic [31:0] radicand,
    output logic [31:0] root,
    output logic        busy,
    output logic        done
);
    // State machine states
    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        COMPUTE     = 2'b01,
        DONE_STATE  = 2'b10
    } state_t;
    
    state_t state, next_state;
    
    // Registers
    logic [31:0] x, q, ac;
    logic [4:0]  iter;
    
    // Combinational signals
    logic [31:0] ac_shifted;
    logic [31:0] x_shifted;
    logic [31:0] test_res;
    
    assign ac_shifted = {ac[29:0], x[31:30]};
    assign x_shifted  = {x[29:0], 2'b00};
    assign test_res   = ac_shifted - {q[29:0], 2'b01};
    
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
                        iter <= 5'd0;
                        x    <= radicand;
                        q    <= 32'd0;
                        ac   <= 32'd0;
                    end
                end
                
                COMPUTE: begin
                    // Perform iteration
                    if (test_res[31] == 1'b0) begin
                        ac <= test_res;
                        q  <= {q[30:0], 1'b1};
                    end else begin
                        ac <= ac_shifted;
                        q  <= {q[30:0], 1'b0};
                    end
                    
                    x    <= x_shifted;
                    iter <= iter + 5'd1;
                    
                    // Save result on last iteration
                    if (iter == 5'd15) begin
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