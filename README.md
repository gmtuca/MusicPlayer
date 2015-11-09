# MusicPlayer
Jukebox program written in ARM assembly for an FPGA controller

<pre><i>
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
</i></pre>

Songs in the file <b>Playlist.s</b> are in the format
<pre><i>
song_[id]  DEFB "Song name", 0
           DEFB "CcDdEFfGgAaB", 0
</i></pre>

Upper case letters represent soft  notes C,  D,  E,  F,  G,  A,  B <br />
Lower case letters represent sharp nodes C#, D#, F#, G#, A# <br />
<br />
The notes are defined on <b>Music.s</b> based on the following periods for octave 4.

<pre><i>
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
</i></pre>
<br />
Octaves can be changed based on the right/left arrow click and will shift such values upwards/downwards.
