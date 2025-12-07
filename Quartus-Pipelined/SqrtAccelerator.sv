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
            default: next_state = IDLE;
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