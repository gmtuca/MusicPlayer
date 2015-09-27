;******** LCD DEFINITIONS ********
;====== Hitachi HD44780 LCD ======
; base address is IO_BASE_ADDRESS
PORT_A_OFFSET   EQU 0x0 ; portA - LCD data
PORT_B_OFFSET   EQU 0X4 ; portB - LCD control

RW    EQU 0b00000100
RS    EQU 0b00000010
E     EQU 0b00000001

CLEAR_DISPLAY_BIT  EQU 0b00000001
BUSY_BIT           EQU 0b10000000

;======================== REGISTER USAGE ======================
; ♫ R0  char to be printed
; ♬ R1  IO_BASE_ADDR
; ♫ R2  port B (control) manipulation
; ♪ R3  LCD status byte 
;
; ♬ R10 string to be printed
;===============================================================

;---------------------------------------------------------------------
print_title ; prints string pointed by R10
  PUSH{R0,LR} ; does not preserve value at R10 because
    print_next_char ; the song notes are located right
                    ; after the title. So they can now be retrieved.
    LDRB R0, [R10], #1 ; read current char and increment
    CMP R0, #0         ; check if terminator is found
    POPEQ {R0,PC}

    SVC SVC_PRINT_CHAR  ; print current char at R0

    B print_next_char

;#####################################################################
print_char ; takes R0 as value of ASCII character
  PUSH {R1-R3, LR}

  ADRL R1, IO_BASE_ADDR

  BL set_to_read_control

  check_busy
    BL enableDataBus
    LDRB R3, [R1, #PORT_A_OFFSET]  ; read LCD status byte on portA
    BL disableDataBus

    ;check if bit 8 of status byte was high
    ;if high then LCD is busy
    ;keep checking until it is not busy
    TST R3, #BUSY_BIT
    BNE check_busy

  BL set_to_write_output_data

  STRB R0, [R1, #PORT_A_OFFSET] ; output desired byte onto data bus

  BL enableDataBus
  BL disableDataBus

  POP {R1-R3, PC}

;#####################################################################
clear_screen ; doesn't take any arguments. Clears the LCD screen
  PUSH {R0-R3, LR}

  ADRL R1, IO_BASE_ADDR
  BL set_to_write_control_input

  MOV  R0, #CLEAR_DISPLAY_BIT
  STRB R0, [R1, #PORT_A_OFFSET]

  BL enableDataBus
  BL disableDataBus

  POP {R0-R3, PC}

;==================== Functions used by svc calls ====================
set_to_read_control
  LDRB R2, [R1, #PORT_B_OFFSET]
  ORR  R2, R2, #RW  ; R/W = 1
  BIC  R2, R2, #RS  ; RS = 0
  STRB R2, [R1, #PORT_B_OFFSET]
  MOV PC, LR

enableDataBus
  LDRB R2, [R1, #PORT_B_OFFSET]
  ORR  R2, R2, #E    ; E = 1
  STRB R2, [R1, #PORT_B_OFFSET]
  MOV  PC, LR

disableDataBus
  LDRB R2, [R1, #PORT_B_OFFSET]
  BIC  R2, R2, #E    ; E = 0
  STRB R2, [R1, #PORT_B_OFFSET]
  MOV  PC, LR

set_to_write_output_data
  LDRB R2, [R1, #PORT_B_OFFSET]
  BIC  R2, R2, #RW  ; R/W = 0
  ORR  R2, R2, #RS  ; RS = 1
  STRB R2, [R1, #PORT_B_OFFSET]
  MOV  PC, LR

set_to_write_control_input
  LDRB R2, [R1, #PORT_B_OFFSET]
  BIC R2, R2, #RW  ; R/W = 0
  BIC R2, R2, #RS  ; RS = 0
  STRB R2, [R1, #PORT_B_OFFSET]
  MOV  PC, LR