;****** BUTTON DEFINITIONS *****
;base address is IO_BASE_ADDR
BUTTONS_OFFSET    EQU 0x4

UPPER_BUTTON_BIT  EQU 0b01000000
LOWER_BUTTON_BIT  EQU 0b10000000

;---------------------------------------------
poll_buttons
  PUSH{R0,R1,R9,LR}

  ADRL R1, IO_BASE_ADDR

  ;check value reported by
  ;address of buttons
  LDRB R0, [R1, #BUTTONS_OFFSET]

  MOV R1, #UPPER_BUTTON_BIT
  ADRL R9, UPPER_BUTTON
  BL check_button

  MOV R1, #LOWER_BUTTON_BIT
  ADRL R9, LOWER_BUTTON
  BL check_button

  POP{R0,R1,R9,PC}

;---------------------------------------------
check_button
  PUSH{R0}
  TST R0, R1   ; R1 = bit of upper/lower button
  MOVNE R0, #1 ; button pressed
  MOVEQ R0, #0 ; button NOT pressed

  STRB R0, [R9] ; make available
                ; to the user in a friendly
                ; way (0 or 1) if a certain
                ; button has been pressed
  POP{R0}
  MOV PC, LR
