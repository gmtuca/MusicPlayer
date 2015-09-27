;******************* TIMER COMPARE *******************
POLL_FREQUENCY    EQU 20 ; how frequently, in ms, the
                         ; keyboard/buttons are polled
                         ; (an interrupt is generated)

TIMER_CMP_BIT     EQU 0b00000001


;======================== REGISTER USAGE ======================
; ♫ R0  interrupt acknowledgement and timer cmp update
; ♬ R1  IO_BASE_ADDR
; ♫ R2  type of interrupt
; ♪ R3  CURRENT_TIME address
; ♬ R4  current time since first interrupt
;===============================================================

;============================== IRQ ============================
irq
  SUB LR, LR, #4 ; make sure to later get back to the
                 ; instruction that was being executed
  PUSH{R0-R4,LR}

  ADRL R1, IO_BASE_ADDR ; global IRQ variable
  LDRB R2, [R1, #IRQ_OFFSET] ; R2 now holds the bits to identify
                             ; what type of interrupt(s) occured

  BL acknowledge_interrupt

  TST R2, #TIMER_CMP_BIT ; this program only supports
  BEQ irq_end            ; the timer compare interrupt

  BL update_timer_cmp ; for next time


  ; the irq maintains a clock representing
  ; the amount of milliseconds passed from the
  ; start of the program, which is updated
  ; whenever timer compare issues an interrupt
  ADR R3, CURRENT_TIME
  LDR R4, [R3]
  ADD R4, R4, #POLL_FREQUENCY
  STR R4, [R3]


  BL poll_buttons ; located in Buttons.s (I could choose to have 
                  ; button interrupts instead of polling,
                  ; but as I am already polling the keypad and
                  ; I also have to report button releases I
                  ; prefer this approach).
  BL poll_keypad  ; located in Keypad.s

  irq_end

  POP{R0-R4,PC}^

;------------------------------------------------------------------------
acknowledge_interrupt
  MOV R0, #0b00000000 ; clear all interrupt bits
  STRB R0, [R1, #IRQ_OFFSET]
  MOV PC, LR

;------------------------------------------------------------------------
update_timer_cmp
  ; updates the timer compare so that the next timer interrupt is called
  ; after POLL_FREQUENCY milliseconds. If not used, an interrupt will
  ; be generated every 256 ms
  LDRB R0, [R1, #TIMER_CMP_OFFSET]
  ADD  R0, R0, #POLL_FREQUENCY ; it already does the wrap around case,
                               ; because I load and store bytes
                               ; (if it goes over 255 we just won't see
                               ;  anything above bit 7)
  STRB R0, [R1, #TIMER_CMP_OFFSET]
  MOV PC, LR

;=========== OS Function ============
enable_timer_cmp_interrupt_ONLY
  PUSH{R0, R1}
  MOV  R0, #TIMER_CMP_BIT
  MOV  R1, #IO_BASE_ADDR
  STRB R0, [R1, #IRQ_ENABLE_OFFSET]
  POP{R0, R1}
  MOV PC, LR