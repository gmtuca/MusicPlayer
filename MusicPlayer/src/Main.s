;=============================================================
;============= ♫ ♩ ♪  ARM MUSIC PLAYER  ♩ ♬ ♪ ================
;=============================================================
; Author: Arthur Bicalho Ceccotti - 8544173
; Last modified: 29/04/2014
;
; ♬ I grant permission for usage and
;   demonstration of this project
;
; Contains files:
;        ♫ Main.s       overall definitions,
;                       setup, user code, svc interface,
;                       stack definitions
;
;        ♩ Music.s      music note definitions,
;                       svc function to play a note,
;                       library function to read a song               
;                       and to terminate one
;
;        ♬ Playlist.s   contains an AWESOME collection
;                       of songs. Want your own songs?
;                       Edit this file =)
;
;        ♪ Interrupt.s  interrupt service routine, 
;                       interrupt acknowledgement and
;                       timer compare update
;
;        ♩ Keypad.s     keypad setup and functions
;                       to poll the keypad or a specific row
;        
;        ♫ Display.s    svc functions to print a char,
;                       clear the screen and library
;                       function to print a string
;
;        ♬ Buttons.s    library functions to poll the
;                       lower and upper buttons
;
;
; Usage:
;    ♫ The program starts with a blank screen and no songs
;      being played.
;
;    ♪ As soon as a keypad key is pressed the corresponding
;      song title is printed and the song starts playing.
;
;    ♬ Songs can be interrupted at any time by pressing a
;      keypad key, which issues a new song to be played.
;
;    ♫ The octaves of notes in a song can be increased
;      by pressing the upper button or decreased by
;      pressing the lower button. These changes are
;      discarted once a new song is issued.
;
;    ♩ If a song finishes playing, the screen will go
;      blank, waiting for a new song to be chosen.
; 
;
;
; Legend:
;    === General documentation
;    *** Definitions / Symbols
;    ### SVC function / Supervisor code
;    --- Library / General function
;
;  ♬ Have fun! ♬
;=============================================================

;************** I/O ***************
IO_BASE_ADDR         EQU 0x10000000
TIMER_OFFSET         EQU 0x8
IRQ_OFFSET           EQU 0x18
IRQ_ENABLE_OFFSET    EQU 0x1C
TIMER_CMP_OFFSET     EQU 0x0C
EXIT_OFFSET          EQU 0x20

;************ FPGA/PIO ************
FPGA_PIO_BASE_ADDR   EQU 0x20000000

;********** MODES ***********
SYSTEM_MODE          EQU 0xDF
SUPERVISOR_MODE      EQU 0xD3
INTERRUPT_MODE       EQU 0xD2
USER_MODE            EQU 0x10 ; Interrupts are disabled for all modes but user

;********** STACKS **********
SUPERVISOR_STACK_SIZE EQU 200
INTERRUPT_STACK_SIZE  EQU 200
USER_STACK_SIZE       EQU 200

;************************* SVC ****************************
SVC_NUMBER_BITS    EQU 0xFFFFFF ; first 24 bits of (LR - 4)
SVC_MAX            EQU (svc_table_end - svc_table_start) / 4

SVC_PRINT_CHAR     EQU 0
SVC_CLEAR_SCREEN   EQU 1
SVC_PLAY_NOTE      EQU 2
SVC_EXIT           EQU 3

;======================= START OF PROGRAM =====================
ORG 0X0
  B setup
  B . ; undefined
  B svc_call
  B . ; prefetch_abort
  B . ; data_abort
  B . ; chuck_norris
  B irq
  B . ; fiq

;#############################################################
setup ; initial supervisor setup
  ADRL SP, supervisor_stack

  MSR CPSR_C, #SYSTEM_MODE  ; switch to system mode
  ADRL SP, user_stack       ; and setup user stack

  MSR CPSR_C, #INTERRUPT_MODE ; switch to interrupt mode
  ADRL SP, interrupt_stack    ; and setup interrupt stack

  MSR CPSR_C, #SUPERVISOR_MODE

  BL setup_keypad                    ; located in Keypad.s
  BL enable_timer_cmp_interrupt_ONLY ; located in Interrupt.s

  MSR SPSR_C, #USER_MODE
  ADR R4, user_code
  MOVS PC, R4 ; switch to user mode, with interrupts enabled

;#############################################################
svc_call
  PUSH{R4,R5,LR}
  LDR R5, [LR, #-4]
  AND R5, R5, #SVC_NUMBER_BITS ; evaluate SVC number
  CMP R5, #SVC_MAX
  BHS exit  ; unknown svc (lower than 0 or greater than SVC_MAX): exit program
  ADR R4, svc_table_start
  ADR LR, svc_table_end
  ADD PC, R4, R5, LSL #2

  ; svc jump table
  svc_table_start 
    B print_char    ; prints R0 (ASCII) to the LCD display
    B clear_screen  ; prints LCD screen and resets cursor
    B play_note     ; plays note with period at R0 and octave (offset) at R2
    B exit          ; halts the processor
  svc_table_end

  POP{R4,R5,PC}^

;############################################################
exit
  ADRL R1, IO_BASE_ADDR
  MOV R0, #1
  STR R0, [R1, #EXIT_OFFSET] ; exit program
  B .     ; in case of failure loop infinitely


;**** RUNTIME OF PROGRAM ****
CURRENT_TIME  DEFW 0x0  ; milliseconds passed since start
                        ; of the program (is maintained by the IRQ)


;**** KEY CURRENTLY PRESSED ****
NO_KEYS_PRESSED  EQU 0xFF
PRESSED_KEY      DEFB NO_KEYS_PRESSED  ; a number between 0 and B (0-11 decimal).
                                       ; returns:              0 1 2 3 4 5 6 7 8 9 A B
                                       ; equivalent to keypad: 3 6 9 # 2 5 8 0 1 4 7 *
                                       ; if no keys have been pressed yet, it
                                       ; is defaulted to 0xFF

                                       ; this is a good approach when concerned
                                       ; about a single key being pressed (if multiple are
                                       ; pressed it will take the last one)

;******* BUTTON STATUS *******
; 0 = not pressed, 1 = pressed
UPPER_BUTTON     DEFB 0x0 
LOWER_BUTTON     DEFB 0X0

ALIGN


;=========================== USER CODE ======================== 
;======================== REGISTER USAGE ======================
; ♫ R0  current runtime
; ♬ R1  octave of note to be played (0-7)
; ♩ R3  used as time to break out of wait/sleep loop
; ♪ R4  current upper/lower button status (0/1)
; ♫ R5  upper button status by end of note being played
; ♬ R6  lower button status by end of note being played
;
; ♫ R8  currently pressed keypad key
; ♩ R9  keypad key pressed while note was playing
; ♬ R10 pointer to song being played
;
; ♪ R12 previously pressed keypad key
;==============================================================

;========================================== USER CODE ==========================================
user_code

  no_songs ; at the start of the program do nothing
           ; but wait for a key to be pressed
           ; (in order to play the according song)
    BL check_pressed_key
    CMP R8, #NO_KEYS_PRESSED
    BEQ no_songs


  MOV R9, R8

  ; a key is finally pressed and a song
  ; is about to be played
  play_new_song
  
  SVC SVC_CLEAR_SCREEN

  MOV R2, #4 ; R2 is the octave. Starts at 4. The user is able to increase
             ; or decrease it using the upper/lower buttons

  ; R8 holds a value between 0 and 11
  ; according to the pressed key
  ADRL R10, song_keys
  ADD R10, R10, R9, LSL #2 ; calculate location of song
  LDR R10, [R10]

  BL print_title ; given R10, print the first string
                 ; on the song pointer (which is the title)

                 ; R10 is UPDATED such that now it points
                 ; to whatever comes after the title,
                 ; which are the actual notes
                 ; (this can be done with an array of notes
                 ; and a different array of titles if wanted)

  ; now that R10 points to the array of notes (as characters)
  note_loop

    MOV R5, #0 ; R5 will be used to tell if the upper button is pressed
    MOV R6, #0 ; R6 will be used to tell if the lower button is pressed

    MOV R12, R9 ; R12 holds value of previously pressed button
    MOV R9, #NO_KEYS_PRESSED ; R9 (will hold) the value of the
                             ; currently pressed key (if any)

    BL play_next_note ; located in Music.s
    CMP R10, #0 ; if song has been terminated
    BEQ song_end

    MOV R1, #NOTE_DURATION
    BL wait ; play note for #NOTE_DURATION ms

    BL play_silence ; located in Music.s

    MOV R1, #SILENCE_DURATION
    BL wait ; silence for a short period (#SILENCE_DURATION ms)
            ; to make transition between notes more clear.
            ; trust me, it sounds better like that =) 

    ; finally take actions about keypad
    CMP R9, #NO_KEYS_PRESSED ; check if a key has been pressed while
                             ; the note was being played
    BNE key_was_pressed


    ; should get here if no keys have been pressed while the note
    ; was playing, or if the key (which is equivalent to the current song)
    ; is being held
    keep_playing

    ; finally take actions about buttons
    CMP R5, #1 ; check if upper button was pressed
    BLEQ increase_octave 

    CMP R6, #1 ; check if lower button was pressed
    BLEQ decrease_octave

    B note_loop ; play next note of the song

  ; song has finished
  song_end

  B no_songs


  SVC SVC_EXIT

;---------------------------------------------------------------------------
increase_octave
  ADD R2, R2, #1 ; increase octave

  CMP R2, #MAX_OCTAVE 
  MOVGT R2, #MAX_OCTAVE ; cap at MAX_OCTAVE

  MOV PC, LR

;---------------------------------------------------------------------------
decrease_octave
  SUBS R2, R2, #1 ; decrease octave
  MOVMI R2, #0 ; cap at 0

  MOV PC, LR

;---------------------------------------------------------------------------
key_was_pressed
    ; R9 = key pressed now, R12 = key pressed last time
    CMP R9, R12 ; make sure it's not the same key as before.
                ; this way if a key is being held we don't restart the
                ; song all the time, we simply let it play.
                ; but if a key is pressed, then released, then pressed again
                ; we will restart the song =)
    MOVNE R8, R9      ; R8 = song to be played (0-B)
    BNE play_new_song ; if a key is pressed now and wasn't pressed before
                      ;   then play a new song! (or restart)
    B   keep_playing  ; else (if it is being held) keep playing our song 

;----------------------------------------------------------------------------
wait ; sleeps for R1 milliseconds, while
     ; checking for buttons/keypad
  PUSH{R0,R3,LR}

  BL get_time    ; R0 now holds the current time
  ADD R3, R0, R1 ; R3 now holds the timestamp at which we
                 ; want to break out of the loop


  wait_loop

    ; while we wait why not check for buttons/keypad?

    BL check_pressed_key
    CMP R8, #NO_KEYS_PRESSED
    MOVNE R9, R8 ; if a key has been pressed, report it.
                 ; (the last -and usually only- key pressed
                 ; for the node's duration will decide what
                 ; happens after this note)

   ; if a button (upper/lower) or a key is pressed at any point
   ; while the song is playing, report it.
   ; as soon as the note is over (finished playing) we will see what
   ; happened to the buttons/keypad and take actions

   ; trust me, it sonds much better when you take actions
   ; after the note is over, because it keeps the flow going =)

    BL check_upper_button 
    CMP R4, #1 ; R4 = upper button status
    MOVEQ R5, #1 ; R5 tells us if the upper button has been pressed
                 ; at all for the duration of the current note

    BL check_lower_button
    CMP R4, #1 ; R4 = upper button status
    MOVEQ R6, #1 ; R6 tells us if the lower button has been pressed
                 ; at all for the duration of the current note


    BL get_time ; get current time
    CMP R3, R0  ; is ittime to wake up?
    BGT wait_loop ; no? then I'll keep waiting...

  ; the long wait is finally over! let's move on!
  POP{R0,R3,PC}

;------------------------------------------------------------------
get_time ; gets the current time of program execution
  PUSH{R2}
  ADRL R2, CURRENT_TIME
  LDR R0, [R2]
  POP{R2}
  MOV PC, LR

;------------------------------------------------------------------
check_pressed_key ; returns the currently pressed key. (0-B)
                  ; or FF if none are pressed
  PUSH{R2}
  ADRL R2, PRESSED_KEY
  LDRB R8, [R2]
  POP{R2}
  MOV PC, LR

;------------------------------------------------------------------
check_upper_button ; returns upper button status on R4
  PUSH{R2}
  ADRL R2, UPPER_BUTTON
  LDRB R4, [R2]
  POP{R2}
  MOV PC, LR

;------------------------------------------------------------------
check_lower_button ; returns upper button status on R4
  PUSH{R2}
  ADRL R2, LOWER_BUTTON
  LDRB R4, [R2]
  POP{R2}
  MOV PC, LR

;************** KEYPAD + SONG DEFINITIONS **************
song_keys ; array of pointers to songs
  DEFW song_2, song_5, song_8, song_11 ; top    row 369#
  DEFW song_1, song_4, song_7, song_10 ; middle row 2580
  DEFW song_0, song_3, song_6, song_9  ; bottom row 147*

ALIGN

INCLUDE Interrupt.s
INCLUDE Keypad.s
INCLUDE Buttons.s
INCLUDE Music.s
INCLUDE Display.s

;**** STACK DEFINITIONS ****
DEFS SUPERVISOR_STACK_SIZE
     supervisor_stack

DEFS INTERRUPT_STACK_SIZE
     interrupt_stack

DEFS USER_STACK_SIZE
     user_stack