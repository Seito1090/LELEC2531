
//=======================================================
//  MyARM
//=======================================================

module MyDE0_Nano(

//////////// CLOCK //////////
input logic 		          		CLOCK_50,

//////////// LED //////////
output logic		     [7:0]		LED,

//////////// KEY //////////
input logic 		     [1:0]		KEY,

//////////// SW //////////
input logic 		     [3:0]		SW,

//////////// SDRAM //////////
output logic		    [12:0]		DRAM_ADDR,
output logic		     [1:0]		DRAM_BA,
output logic		          		DRAM_CAS_N,
output logic		          		DRAM_CKE,
output logic		          		DRAM_CLK,
output logic		          		DRAM_CS_N,
inout logic 		    [15:0]		DRAM_DQ,
output logic		     [1:0]		DRAM_DQM,
output logic		          		DRAM_RAS_N,
output logic		          		DRAM_WE_N,

//////////// EPCS //////////
output logic		          		EPCS_ASDO,
input logic 		          		EPCS_DATA0,
output logic		          		EPCS_DCLK,
output logic		          		EPCS_NCSO,

//////////// Accelerometer and EEPROM //////////
output logic		          		G_SENSOR_CS_N,
input logic 		          		G_SENSOR_INT,
output logic		          		I2C_SCLK,
inout logic 		          		I2C_SDAT,

//////////// ADC //////////
output logic		          		ADC_CS_N,
output logic		          		ADC_SADDR,
output logic		          		ADC_SCLK,
input logic 		          		ADC_SDAT,

//////////// 2x13 GPIO Header //////////
inout logic 		    [12:0]		GPIO_2,
input logic 		     [2:0]		GPIO_2_IN,

//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
inout logic 		    [33:0]		GPIO_0_PI,
input logic 		     [1:0]		GPIO_0_PI_IN,

//////////// GPIO_1, GPIO_1 connect to GPIO Default //////////
inout logic 		    [33:0]		GPIO_1,
input logic 		     [1:0]		GPIO_1_IN
);			 

//=======================================================
//  MyARM
//=======================================================

	logic 		 	clk, reset;
   logic [31:0] 	WriteDataM, DataAdrM;
	logic 		 	MemWriteM;
	logic [31:0] 	PCF, InstrF, ReadDataM, ReadData_dmem, ReadData_spi;
	
	logic  			cs_dmem, cs_led, cs_spi, cs_sqrt;
	logic [7:0] 	led_reg;
	logic [31:0]	spi_data;
	
	// SQRT signals
	logic [31:0]	sqrt_result;
	logic          sqrt_busy;
	logic          sqrt_done;
	logic          sqrt_start;
	logic [31:0]   sqrt_input;
	
	assign clk   = CLOCK_50;
	assign reset = GPIO_0_PI[1];
  
	// Instantiate processor and memories
	arm arm(clk, reset, PCF, InstrF, MemWriteM, DataAdrM, WriteDataM, ReadDataM);
	imem imem(PCF, InstrF);
	dmem dmem(clk, cs_dmem, MemWriteM, DataAdrM, WriteDataM, ReadData_dmem);
	
	// Chip Select logic

	// Address MAP : 0x0000 - 0x03FF : RAM (255 words of 32 bits)
	//               0x0400 - 0x04FF : SPI - expanded to full 0x4-- range
	//               0x0500          : LED Reg
	//               0x0600 - 0x06FF : SQRT Accelerator (MOVED HERE)
	//                  0x0600       : Input Register (Write only)
	//                  0x0604       : Result Register (Read only)
	//                  0x0608       : Status Register (Read: bit 0 = busy)

	assign cs_dmem   = ~DataAdrM[11] & ~DataAdrM[10];                              // 0x000-0x3FF
	assign cs_spi    = ~DataAdrM[11] &  DataAdrM[10] & ~DataAdrM[9] & ~DataAdrM[8]; // 0x400-0x4FF (FULL RANGE)
	assign cs_sqrt   = ~DataAdrM[11] &  DataAdrM[10] &  DataAdrM[9] & ~DataAdrM[8]; // 0x600-0x6FF (MOVED)
	assign cs_led    = ~DataAdrM[11] &  DataAdrM[10] & ~DataAdrM[9] &  DataAdrM[8]; // 0x500-0x5FF

	// Read Data
	always_comb
		if (cs_dmem) ReadDataM = ReadData_dmem;
		else if (cs_spi) ReadDataM = spi_data;
		else if (cs_sqrt) begin
        // Address decode for SQRT registers
        case (DataAdrM[3:2])
            2'b00:  ReadDataM = sqrt_input;         // 0x600: Read back input
            2'b01:  ReadDataM = sqrt_result;        // 0x604: Read result
            2'b10:  ReadDataM = {31'b0, sqrt_busy}; // 0x608: Read status
            default: ReadDataM = 32'b0;
        endcase
		end
		else if (cs_led) ReadDataM = {24'h000000, led_reg};
		else ReadDataM = 32'b0;
	
	// LED logic	
	assign LED = led_reg;	
	always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        led_reg <= 8'd0;
    end else if (MemWriteM & cs_led) begin
        led_reg <= WriteDataM[7:0];  // Normal LED write
    end else begin
        // Always write sqr_result to check 
        led_reg <= sqrt_result[7:0];
    end
	end

	// Testbench
	assign GPIO_1[33]    = MemWriteM;
	assign GPIO_1[15:0]  = WriteDataM[15:0];
	assign GPIO_1[31:16] = ReadDataM[15:0];
	assign GPIO_2[12:0]  = DataAdrM[12:0];

//=======================================================
//  SPI
//=======================================================

	logic 			spi_clk, spi_cs, spi_mosi, spi_miso;

	spi_slave spi_slave_instance(
		.SPI_CLK    (spi_clk),
		.SPI_CS     (spi_cs),
		.SPI_MOSI   (spi_mosi),
		.SPI_MISO   (spi_miso),
		.Data_WE    (MemWriteM & cs_spi),
		.Data_Addr  (DataAdrM),
		.Data_Write (WriteDataM),
		.Data_Read  (spi_data),
		.Clk        (clk)
	);
	
	assign spi_clk  		= GPIO_0_PI[11];	// SCLK = pin 16 = GPIO_11
	assign spi_cs   		= GPIO_0_PI[9];	// CE0  = pin 14 = GPIO_9
	assign spi_mosi     	= GPIO_0_PI[15];	// MOSI = pin 20 = GPIO_15
	
	assign GPIO_0_PI[13] = spi_cs ? 1'bz : spi_miso;  // MISO = pin 18 = GPIO_13
	
//=======================================================
// SQRT Accelerator Logic
//=======================================================
	
	// Start signal: pulse when writing to 0x480
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			sqrt_start <= 0;
			sqrt_input <= 0;
		end else begin
			sqrt_start <= 0;  // Default: no start
			
			// Writing to 0x480 triggers computation
			if (cs_sqrt && MemWriteM && (DataAdrM[3:2] == 2'b00)) begin
            sqrt_input <= WriteDataM;
            sqrt_start <= 1;
			end
		end
	end
	
	// Instantiate SQRT Core
	SqrtCore sqrt_core (
		.clk      (clk),
		.rst      (reset),
		.start    (sqrt_start),
		.radicand (sqrt_input),
		.root     (sqrt_result),
		.busy     (sqrt_busy),
		.done     (sqrt_done)
	);
	

endmodule

//=======================================================
//  Memory
//=======================================================	

module dmem(input logic clk, we, cs,
				input logic [31:0] a, wd,
            output logic [31:0] rd);
				
  logic [31:0] RAM[255:0];
    
assign rd = RAM[a[31:2]]; // word aligned

always_ff @(posedge clk)
    if (cs & we) RAM[a[31:2]] <= wd;
endmodule

module imem(input  logic [31:0] a,
            output logic [31:0] rd);
				
  logic [31:0] RAM[255:0];
  
initial $readmemh("MyProgram_Pipelined.hex",RAM);
assign rd = RAM[a[31:2]]; // word aligned

endmodule


	

