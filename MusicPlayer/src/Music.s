;****** MUSIC NOTES ******
; periods in microseconds
; of octave zero notes
_C  EQU 8000  ; Do  / C
_Cs EQU 7552  ;     / C#
_D  EQU 7128  ; Re  / D
_Ds EQU 6728  ;     / D#
_E  EQU 6352  ; Mi  / E
_F  EQU 5992  ; Fa  / F
_Fs EQU 5656  ;     / F#
_G  EQU 5336  ; Sol / G
_Gs EQU 5040  ;     / G#
_A  EQU 4760  ; La  / A
_As EQU 4488  ;     / A#
_B  EQU 4240  ; Ti  / B

MAX_NOTE          EQU 7   ; A-G or a-g

MAX_OCTAVE        EQU 7 ; 7th octave = max
DEFAULT_OCTAVE    EQU 4

;****** DURATIONS *******
NOTE_DURATION     EQU 400 ; duration of a single note, in ms
SILENCE_DURATION  EQU 40  ; duration of silence after each note

;**********************************
;base address is FPGA_PIO_BASE_ADDR
BUZZER_OFFSET     EQU 0X0 ; (this is just here for simplicity)


;======================== REGISTER USAGE ======================
; ♫ R0  period of note to be played
;       ASCII char to be converted to note period
; ♬ R1  FPGA_PIO_BASE_ADDR
; ♩ R2  Octave of note to be played (0-7)
;
; ♬ R10 song to be played
; ♪ R11 used for song conversion
;==============================================================

;##############################################################
play_note ; R0: note to be played (octave 0)
          ; R2: octave
  PUSH{R0-R2,LR}

  ADRL R1, FPGA_PIO_BASE_ADDR

  CMP R2, #MAX_OCTAVE
  MOVHI R2, #DEFAULT_OCTAVE ; if octave is invalid
                            ; use the default

  ; divide by 2 (shift right) according to the amount of octaves
  MOV R0, R0, LSR R2 ; R2 = octave

  STRH R0, [R1, #BUZZER_OFFSET]

  POP{R0-R2,PC}

;--------------------------------------------------------------
play_silence
  PUSH{R0}
  MOV R0, #0
  SVC SVC_PLAY_NOTE
  POP{R0}
  MOV PC, LR

;--------------------------------------------------------------
play_next_note ; current note is pointed by R10
  PUSH{R0,LR} 

  LDRB R0, [R10], #1
  CMP R0, #0 ; see if song terminator is found
  BEQ terminate_song
  

  ; else if song is still playing
  BL convert_char_to_period ; find the period of the next note
  SVC SVC_PLAY_NOTE         ; play it!

  POP{R0,PC}

;--------------------------------------------------------------
terminate_song
  SVC SVC_CLEAR_SCREEN
  MOV R10, #0 ; R10 (song pointer = null)
              ; it means there are no songs being played now
  POPEQ {R0, LR}

;--------------------------------------------------------------
convert_char_to_period
  ; converts the ASCII character at R0 to a note period
  ; any character which is not [A-Ga-g] will return silence (#0)
  ; (so SPACE can be used as silence)
  PUSH{R11,LR}

  ADR LR, check_valid

  CMP R0, #'a' ; find  if it's sharp or natural
  BGE isLower
  BLT isUpper


  check_valid
  CMP R0, #MAX_NOTE ; make sure it's not over G/g and not lower than A/a
  MOVHS R0, #0 ; return silence if invalid value
  BHS conversion_end

  ; R0 is 0-6 (0=A, 6=G)
  ; to know if it is upper or lower we have R11

  ; should only get here if character is [a-gA-G],
  ; which means valid input
  ADD R11, R11, R0, LSL #1 ; take the address of where the period is
                           ; LSL 1 because each period is half a word

  LDRH R0, [R11] ; finally get period value

  conversion_end

  POP{R11,PC}

isUpper ; upper case represents natural (white piano notes)
  SUB R0, R0, #'A'
  ADR R11, notes_upper
  MOV PC, LR

isLower ; lower case represents sharp   (black piano notes)
  SUB R0, R0, #'a'
  ADR R11, notes_lower
  MOV PC, LR

notes_upper DEFH _A
            DEFH _B
            DEFH _C
            DEFH _D
            DEFH _E
            DEFH _F
            DEFH _G

notes_lower DEFH _As
            DEFH _C ; B# is the same as C natural
            DEFH _Cs
            DEFH _Ds
            DEFH _E ; E# is the same as E natural
            DEFH _Fs
            DEFH _Gs

INCLUDE Playlist.s