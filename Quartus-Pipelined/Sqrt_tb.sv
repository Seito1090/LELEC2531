`timescale 1ns/1ns

module sqrt_int_tb;

    parameter WIDTH = 32;

    logic clk;
    logic start;             // start signal
    logic busy;              // calculation in progress
    logic rst;
    logic we;
    logic [31:0] rad;   // radicand
    logic [31:0] root;  // root
    logic done;

    SqrtCore dut(clk, rst, start, rad, root, busy, done);

    // Clock
    always begin
       #10 clk = ~clk;
    end

    initial begin
        $monitor("\t%d:\tsqrt(%d) =%d", $time, rad, root);
    end

    initial begin
                clk = 1;
        	rst = 1;  // Added reset initialization
        	start = 0;
        	rad = 0;

	#10 	rst = 0;
        #10    rad = 8'b01111001;  // 121
                start = 1;

        #340     start = 0;

        #10     rad = 8'b01010001;  // 81
                start = 1;
        #340     start = 0;

        #10     rad = 8'b01011010;  // 90
                start = 1;
        #340     start = 0;

        #10     rad = 8'b11111111;  // 255
                start = 1;
        #340     start = 0;

        #50     $finish;
    end
endmodule