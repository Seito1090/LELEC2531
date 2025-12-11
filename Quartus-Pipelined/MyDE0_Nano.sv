
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
	logic [31:0]    sqrt_data; // Data coming from accelerator
	
	assign clk   = CLOCK_50;
	assign reset = GPIO_0_PI[1];
  
	// Instantiate processor and memories
	arm arm(clk, reset, PCF, InstrF, MemWriteM, DataAdrM, WriteDataM, ReadDataM);
	imem imem(PCF, InstrF);
	dmem dmem(clk, cs_dmem, MemWriteM, DataAdrM, WriteDataM, ReadData_dmem);
	
	// Chip Select logic
	assign cs_dmem   = ~DataAdrM[11] & ~DataAdrM[10];                              
	assign cs_spi    = ~DataAdrM[11] &  DataAdrM[10] & ~DataAdrM[9] & ~DataAdrM[8]; 
	assign cs_led    = ~DataAdrM[11] &  DataAdrM[10] & ~DataAdrM[9] &  DataAdrM[8];
    // SQRT Select: 0x600 - 0x6FF
	assign cs_sqrt   = ~DataAdrM[11] &  DataAdrM[10] &  DataAdrM[9] & ~DataAdrM[8]; 

	// Read Data Mux
	always_comb
		if (cs_dmem) ReadDataM = ReadData_dmem;
		else if (cs_spi) ReadDataM = spi_data;
		else if (cs_sqrt) ReadDataM = sqrt_data; // Connect Wrapper Output
		else if (cs_led) ReadDataM = {24'h000000, led_reg};
		else ReadDataM = 32'b0;
	
	// LED logic	
	assign LED = led_reg;	
	always_ff @(posedge clk or posedge reset) begin
        if (reset) led_reg <= 8'd0;
        else if (MemWriteM & cs_led) led_reg <= WriteDataM[7:0];
	end

    // Testbench assignments...
	assign GPIO_1[33]    = MemWriteM;
	assign GPIO_1[15:0]  = WriteDataM[15:0];
	assign GPIO_1[31:16] = ReadDataM[15:0];
	assign GPIO_2[12:0]  = DataAdrM[12:0];

//=======================================================
//  SPI
//=======================================================
    // ... (Keep SPI Slave Instance exactly as it was) ...
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
	
	assign spi_clk  		= GPIO_0_PI[11];	
	assign spi_cs   		= GPIO_0_PI[9];	
	assign spi_mosi     	= GPIO_0_PI[15];	
	assign GPIO_0_PI[13] = spi_cs ? 1'bz : spi_miso; 
	
//=======================================================
// SQRT Accelerator (Instantiate the Wrapper)
//=======================================================
	
	SqrtAccelerator sqrt_wrap (
		.clk		 	 (clk),
		.reset	    (reset),
		.cs 			 (cs_sqrt),
		.we 			 (MemWriteM & cs_sqrt),
		.addr			 (DataAdrM),
		.wdata	    (WriteDataM),
		.rdata	    (sqrt_data)
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


	
