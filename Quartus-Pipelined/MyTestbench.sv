`timescale 1 ps / 1 ps

module MyTestbench();
  logic        clk;
  logic        reset;
  logic [7:0]  LED;
  
  wire [33:0]  GPIO_0_PI;
  wire [33:0]  GPIO_1;
  wire [12:0]  GPIO_2;
  
  integer cycle_count;
  logic [7:0] prev_led;
  
  // instantiate device to be tested
  MyDE0_Nano dut(
    .CLOCK_50(clk),
    .LED(LED),
    .GPIO_0_PI(GPIO_0_PI),
    .GPIO_1(GPIO_1),  
    .GPIO_2(GPIO_2)
  );
  
  assign GPIO_0_PI[1] = reset;
  
  // initialize test
  initial begin
    cycle_count = 0;
    prev_led = 8'hFF;
    
    $display("========================================");
    $display("Starting SQRT Accelerator Test");
    $display("========================================");
    $display("Watching LED changes...");
    $display("Expected sequence:");
    $display("  0x01 - Started computation");
    $display("  0x02 - Busy cleared");
    $display("  0x04 - Result (sqrt(16) = 4)");
    $display("========================================");
    
    reset <= 1; 
    #22; 
    reset <= 0;
    
    $display("Reset released at time %t", $time);
  end
  
  // generate clock
  always begin
    clk <= 1; #5; clk <= 0; #5;
  end
  
  // Cycle counter
  always @(posedge clk) begin
    if (!reset)
      cycle_count <= cycle_count + 1;
    else
      cycle_count <= 0;
  end
  
  // Monitor LED changes
  always @(posedge clk) begin
    if (LED !== prev_led && LED !== 8'bxxxxxxxx) begin
      $display("[Cycle %0d] LED changed: 0x%02x (%3d decimal)", cycle_count, LED, LED);
      prev_led <= LED;
      
      // Check for expected result
      if (LED == 8'h04) begin
        $display("========================================");
        $display("SUCCESS! SQRT(16) = 4 detected on LEDs");
        $display("========================================");
        #1000;
        $stop;
      end
    end
  end
  
  // Display periodic status
  always @(posedge clk) begin
    if (cycle_count % 5000 == 0 && cycle_count > 0) begin
      $display("[Cycle %0d] Status check - LED: 0x%02x, SQRT busy: %b", 
               cycle_count, LED, dut.sqrt_busy);
    end
  end
  
  // Timeout
  always @(posedge clk) begin
    if (cycle_count > 50000) begin
      $display("========================================");
      $display("TIMEOUT at cycle %0d", cycle_count);
      $display("Final LED value: 0x%02x (%d decimal)", LED, LED);
      $display("========================================");
      
      // Try to check internal state
      $display("Debug info:");
      $display("  sqrt_input:  0x%08x", dut.sqrt_input);
      $display("  sqrt_result: 0x%08x", dut.sqrt_result);
      $display("  sqrt_busy:   %b", dut.sqrt_busy);
      $display("  sqrt_start:  %b", dut.sqrt_start);
      
      $display("========================================");
      $stop;
    end
  end
     
endmodule