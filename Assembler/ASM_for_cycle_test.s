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
    SUB R0, R0, R0
    
master_loop:
    LDR R1, [R0, #0x400]     @ Read Input from SPI, forced for fairness in comparison

    SUB R1, R1, R1           @ Comparison case is 45
    ADD R1, R1, #45
   
start_calc:
    @ Initialize: R2=q, R3=ac, R4=iter, R6=x
    SUB R2, R2, R2
    SUB R3, R3, R3
    SUB R4, R4, R4
    ADD R6, R1, #0

calc_loop:                   @ Main compute loop
    CMP R4, #16              @ 16 itterations needed in every case 
    BEQ write_output
    
    @ ac = ac * 4
    ADD R3, R3, R3
    ADD R3, R3, R3
    
    @ Extract top 2 bits of x into R5
    SUB R5, R5, R5
    
    SUBS R7, R6, #0
    BPL bit31_clear
    ADD R5, R5, #2
    
bit31_clear:                 @ Clear the 2 bits used
    ADD R7, R6, R6
    SUBS R8, R7, #0
    BPL bit30_clear
    ADD R5, R5, #1
    
bit30_clear:
    ORR R3, R3, R5
    
    @ x = x * 4
    ADD R6, R6, R6
    ADD R6, R6, R6
    
    @ test_res = ac - (q*4 + 1)
    ADD R5, R2, R2
    ADD R5, R5, R5
    ADD R5, R5, #1
    SUB R7, R3, R5
    
    @ q = q * 2
    ADD R2, R2, R2
    
    @ Check sign of test_res
    SUBS R8, R7, #0
    BPL positive_test
    B continue_iter
    
positive_test:                @ Test to determine if root digit is 0 or 1
    ADD R3, R7, #0
    ORR R2, R2, #1
    
continue_iter:
    ADD R4, R4, #1
    B calc_loop
    
write_output:
    SUB R0, R0, R0
    STR R2, [R0, #0x500]
    STR R2, [R0, #0x404]

    B master_loop
.end
