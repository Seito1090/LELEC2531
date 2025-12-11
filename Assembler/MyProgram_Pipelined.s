/************* CODE SECTION *************/
@Name Here
.text   @ the following is executable assembly

@ Ensure code section is 4-byte aligned:
.balign 4

@ main is the entry point and must be global
.global main

B main          @ begin at main

/************* MAIN SECTION *************/

main:
    SUB R0, R15, R15        @ R0 = 0
    STR R0, [R0, #0x500]    @ Clear LED
    
    LDR R1, [R0, #0x400]
    STR R1, [R0, #0x500]    @ Show input (16) on LED
    
    STR R1, [R0, #0x600]    @ Start Accelerator
    
wait_sqrt:
    ADD R6, R6, #1
    LDR R3, [R0, #0x608]
    AND R3, R3, #1
    CMP R3, #1
    BEQ wait_sqrt

    SUB R0, R15, R15        @ R0 = 0     
    
    LDR R2, [R0, #0x604]    @ Read Result (4)
    STR R2, [R0, #0x500]    @ Write Result to LED
    STR R2, [R0, #0x404]    @ Write Result to SPI
done:
    B done