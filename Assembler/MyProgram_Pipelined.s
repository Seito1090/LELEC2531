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
    SUB R0, R15, R15        @ R0 = 0
    STR R0, [R0, #0x500]    @ Clear LED
    
    @ Test with a known value first (e.g., 16, sqrt = 4)
    LDR R1, [R0, #0x400]    @ Test value
    STR R1, [R0, #0x500]    @ Show input on LED
    
    STR R1, [R0, #0x600]    @ Write to SQRT input (triggers start)
    
wait_sqrt:
    LDR R3, [R0, #0x608]    @ Read status
    AND R3, R3, #1          @ Mask busy bit
    CMP R3, #1
    BEQ wait_sqrt           @ Loop while busy
    
    LDR R2, [R0, #0x604]    @ Read result
    STR R2, [R0, #0x500]    @ Display on LED (should be 4)
    
done:
    B done
.end