# MusicPlayer
Jukebox program written in ARM assembly for an FPGA controller

File <b>Playlist.s</b> contains the list of songs to be played.
These are in the format:
<pre><i>
song_[id]  DEFB "Song name", 0
           DEFB "CcDdEFfGgAaB", 0
</i></pre>

Where Upper case letters represent soft  notes C,  D,  E,  F,  G,  A,  B <br />
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
Octaves can be changed based on the button click and will shift such values upwards or downwards.
