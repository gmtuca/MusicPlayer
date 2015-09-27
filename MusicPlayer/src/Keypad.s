;*********** KEYPAD ***********
; base address is FPGA_PIO_BASE_ADDR
KEYPAD_DATA_OFFSET      EQU 0x2
KEYPAD_CONTROL_OFFSET   EQU 0x3

TOP       EQU 0b00100000
MIDDLE    EQU 0b01000000
BOTTOM    EQU 0b10000000


;======================== REGISTER USAGE ======================
; ♫ R0  keypad_setup
;       ASCII char to be converted to note period
; ♬ R1  FPGA_PIO_BASE_ADDR
; ♪ R2  row to be scanned
;
; ♫ R4  key scan counter (4-0, one for every key of a row)
; ♬ R5  key being currently scanned
; 
; ♩ R8  previously pressed key
; ♬ R9  location to store/retrieve current runtime
;==============================================================


;======================== OS Function =========================
setup_keypad
  PUSH{R0, R1}
  MOV R0, #0b00011111 ; set 5 least significant bits as input
                      ; and 3 most significant bits as output
  ADRL R1, FPGA_PIO_BASE_ADDR
  STRB R0, [R1, #KEYPAD_CONTROL_OFFSET]
  POP{R0, R1}
  MOV PC, LR

;-----------------------------------------------------------------------------
poll_keypad
  PUSH{R1,R2,R5,R8,R9,LR}

  ADRL R1, FPGA_PIO_BASE_ADDR 

  MOV R2, #TOP ; we start by scanning the top row
  MOV R5, #-1 ; R5 represents the currently pressed key

  ADRL R9, PRESSED_KEY ; used to report to the user the last key which is pressed

  LDRB R8, [R9] ; R8 = previously pressed key (0-B), FF = none pressed

  poll_loop
    BL poll_row ; poll current row
    MOVS R2, R2, LSL #1 ;   TOP row  -> MIDDLE row -> BOTTOM row -> break out
    BCC poll_loop       ; 0b00100000 -> 0b01000000 -> 0b10000000 -> OVERFLOW

  POP{R1,R2,R5,R8,R9,PC}

;-----------------------------------------------------------------------------
poll_row ; poll current roll pointed by R2
  PUSH{R2,R4,LR}

  STRB R2, [R1, #KEYPAD_DATA_OFFSET] ; write to keyboard specifying row to poll
  LDRB R2, [R1, #KEYPAD_DATA_OFFSET] ; read back its response
  AND  R2, R2, #0b1111 ; the 4 least significant bits of keypad data represent
                       ; the buttons clicked or not

  ; check status of every button of current row (a total of 4 times)
  MOV R4, #4 ; R4 counts down 4-3-2-1 for each key

  key_scan_loop
    BL check_key        ; check status of current key
    MOV R2, R2, LSR #1  ; move on to the next key
    SUBS R4, R4, #1
    BNE key_scan_loop   ; while at least one clicked key hasn't been checked

  POP{R2,R4,PC}

;-----------------------------------------------------------------------------
check_key
                 ; R5 = key being currently checked (0-B)
  ADD R5, R5, #1 ; R5 increments for every key check. 
                 ; This way we keey track of the current key.
                 ;
                 ; R5 will return           0 1 2 3   4 5 6 7   8 9 A B
                 ; equivalent to keys:     (3 6 9 #) (2 5 8 0) (1 4 7 *)
                 ;                            TOP      MIDDLE    BOTTOM

  CMP R2, #1 ; was the key pressed?
  BNE not_pressed

  ; a key has been pressed! yey!
  pressed
    CMP R5, R8 ; if a button is being held we don't need to update it
    MOVEQ PC, LR

    STRB R5, [R9] ; store value of key pressed so that
                  ; the user can see it user can see it
                  ; (also in a friendly way: 0-B, or FF)

    MOV PC, LR

;-----------------------------------------------------------------------------
not_pressed
  ; is called when a key is released or not pressed at all
  CMP R5, R8   ; if it used to be pressed
  BEQ released ; it's now released

  MOV PC, LR

;-----------------------------------------------------------------------------
released
  PUSH{R0}
  MOV R0, #NO_KEYS_PRESSED ; FF = not pressed
  STRB R0, [R9]
  POP{R0}
  MOV PC, LR