/************* CODE SECTION *************/
@Name Here
.text   @ the following is executable assembly

@ Ensure code section is 4-byte aligned:
.balign 4

@ main is the entry point and must be global
.global main

B main          @ begin at main
.balign 128

/************* MAIN SECTION *************/

main:
	SUB R0, R15, R15 	@ R0 = 0
	STR R0, [R0, #0x500]    @ Clear the LED
	LDR R1, [R0, #0x400]    @ Load value A from SPI transfer in R1
	LDR R2, [R0, #0x404]    @ Load value B from SPI transfer in R2
	CMP R1, #0				@ If A=0
	BEQ GCD_Done    
	CMP R2, #0				@ If B=0
	BEQ GCD_Done   

GCD_Loop       
	CMP R1, R2 				@ Compare A and B
	BEQ GCD_Done
	BLT Sub_A
	BGT Sub_B
	B GCD_Done              @ Go Back to done if nothing is taken
    
Sub_A
	SUB R2, R2, R1			@ B = B - A 
	B GCD_Loop

Sub_B
	SUB R1, R1, R2			@ A = A - B
	B GCD_Loop

GCD_Done
	STR R1, [R0, #0x500]		        
	STR R1, [R0, #0x408] 	@ CGD=R1=R2, send back through SPI
	@ Display the GCD on the LEDs, YOU NEED TO ADD AN INSTRUCTION
.end     @ end of code