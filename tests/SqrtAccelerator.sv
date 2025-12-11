module SqrtCore (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [31:0] radicand,
    output logic [31:0] root,
    output logic        busy,
    output logic        done
);
    // Registers
    logic [31:0] x, q, ac;
    logic [4:0]  iter;
    
    // Internal signals
    logic [31:0] ac_shifted;
    logic [31:0] x_shifted;
    logic [31:0] test_res;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 0; done <= 0;
            root <= 0; iter <= 0;
            x <= 0; q <= 0; ac <= 0;
        end else begin
            done <= 0; // Pulse done usually triggers for 1 cycle

            if (start && !busy) begin
                busy <= 1;
                iter <= 0;
                x    <= radicand;
                q    <= 0; 
                ac   <= 0;
            end 
            else if (busy) begin
                // 1. Prepare shifted values (Virtual shift)
                // We bring in 2 bits from X into AC
                ac_shifted = {ac[29:0], x[31:30]};
                x_shifted  = {x[29:0], 2'b00};
                
                // 2. Try subtraction
                // q needs to be shifted left by 1 (which becomes << 2 in the math) | 1
                test_res = ac_shifted - {q[29:0], 2'b01};
                
                // 3. Update Registers based on result
                if (test_res[31] == 0) begin // Result is positive
                    ac <= test_res;
                    q  <= {q[30:0], 1'b1};
                end else begin               // Result is negative
                    ac <= ac_shifted;
                    q  <= {q[30:0], 1'b0};
                end
                
                x <= x_shifted;
                iter <= iter + 1;

                // 4. Check for finish (16 iterations for 32-bit input)
                if (iter == 15) begin
                    busy <= 0;
                    done <= 1;
                    root <= (test_res[31] == 0) ? {q[30:0], 1'b1} : {q[30:0], 1'b0};
                end
            end
        end
    end
endmodule
