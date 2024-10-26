.syntax unified
  .cpu cortex-m3
  .thumb
  .global task5

.equ GPIOC_ODR,	 0x4001100C	// For 7-seg on pins 0 to 7
.equ GPIOA_IDR,	 0x40010808	// For custom buttons on pins 8-11
.equ DELAY,		   0xF4240	  // 1 000 000
.equ NEXT_STATES,0x36CD2	  // 000 000 110 110 110 011 010 010

/*
	NEXT_STATES holds the Next-State table Q2+,Q1+,Q0+ values for when the input A is 0
	States are 0 through 7 : Representing the student number [C, 3, 4, 0, 1, 7, 8, 9]
	Example: If input A is 0 and the current state is 0 (C), the next state is 010 -> 2 (4)
*/


// Entry point from main.c

task5:
	/* Initialize register to default values */

	LDR R0, =DATALUT		  // Store output data for LED into R0
  MOV R1, #7            // Store current state [Start at end so we wrap to front on first pulse]
	LDR R2, =NEXT_STATES	// Load our next-state q values into R2
	MOV R4, #3				    // Multiplier required for MUL in set_LED
	MOV R5, #21				    // Store current offset within NEXT_STATES [Start at end so we wrap to front on first pulse]
	LDR R7, =GPIOC_ODR		// Store address of output data register
	LDR R8, =GPIOA_IDR 		// Store address of input data register
	LDR R9, =DELAY			  // Store counter
	MOV R10, #0x0			    // Value for input CLK
	MOV R11, #0x0			    // Value for input A
	MOV R12, #0x0			    // Debounce flag used for CLK

	B loop					      // Branch to loop

loop:
	/* Check CLK pin, update LED and delay on first pulse only. Reset when pin is low after delay */

	LDR R10, [R8] 			  // Load the GPIOA_IDR data from the address stored at R8 and store it in R11
	UBFX R11, R10, #9, #1	// Get 1 bit @ position 0 from R10, store in R11 - CLK input

	CMP R11, R12			    // Compare CLK(R11) value against FLAG (R12)
	ITT GT					      // If flag(R12) is low and CLK(R11) was high (R11 > R12)
		MOVGT R12, #1		    // Set the FLAG (R12) high
		BLGT set_LED		    // also, update the LED

	BL delay				      // Debounce period wait
							          // ===== Reset the flag and delay =====
	CMP R11, #0				    // Once CLK has returned to low, reset
	ITT EQ
		MOVEQ R12, 0		    // If pin was reset, reset the flag to 0
		LDREQ R9, =DELAY	  // also reset the delay back to max


	b loop					      // Return to top of loop


set_LED:
	/* Set the LED - Based on the Input Pin value (R10).
	Take 3 bits from next state map (R2) based on position of current
	state which is held in R1.
	*/
	UBFX R10, R10, #8, #1	// Get 1 bit @ position 8 from R10, store to R10 - input pin

							          // ===== Check input pin, low:all numbers, high:even numbers
	CMP R10, #1				    // Check if the input pin(R10) is low(all numbers)
	ITTEE EQ
							          // ===== Logic for normal operation
		ADDEQ R1, R1, #1	  // Go to the next state in R1, add 1 to it
		ANDEQ R1, R1, #7	  // Mask the lower 3 bits (7 = 111b), ignore upper bits. [Wraps any values over 7 back to 0]
							          // ===== Logic for even number operation
		LSRNE R3, R2, R5	  // Take the next state map(R2), Shift right by R5 digits. Store in R3
		ANDNE R1, R3, #7	  // Mask the lower 3 bits (7 = 111b) and store them in R1.

	MUL R5, R1, R4			  // Take our current state (R1), multiply by 3 bits (R4), store into R5
							          // This is our current position within the next state map (R2)

							          // ===== Load lookup table for DATALUT
	LDRB R6, [R0, R1] 		// Load 1 byte from data[R0] at position state[R1], store in R6
  STR R6, [R7]			    // Store the byte at R6 into ODR[R7]


	BX LR					        // Return to address @ link register

delay:						      // function:delay - for period stored in R9
	CMP R9, #0				    // Compare the current counter(R9) to 0
	ITT GT					      // If counter is greater than 0
		SUBGT R9, R9, #1	  // Set the current counter (R9) to be the current value (R9) minus 1
		BGT delay			      // Still counting, return to delay
	BX LR					        // Finished counting, return to link register address


.align 4
DATALUT:
	.byte 0x39  			    // C
    .byte 0x4F  			  // 3
    .byte 0x66  			  // 4
    .byte 0x3F  			  // 0
    .byte 0x06  			  // 1
    .byte 0x07  			  // 7
    .byte 0x7F  			  // 8
    .byte 0x67  			  // 9
