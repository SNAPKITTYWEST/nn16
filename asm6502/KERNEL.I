; ============================================================
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (c) 2026 SnapKittyWest
; Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
; CLONE GATE: Any clone, fork, or derivative of this node
; MUST be released under GPL-3.0-or-later. No closed-source use.
; ============================================================
; NN/16 6502 Kernel — Zero-page parameter equates
; Include this first in every kernel source file.

; --- 16-bit operand registers ---
R0L = $E0   ; operand 0 low
R0H = $E1   ; operand 0 high
R1L = $E2   ; operand 1 low
R1H = $E3   ; operand 1 high
R2L = $E4   ; operand 2 low
R2H = $E5   ; operand 2 high
R3L = $E6   ; operand 3 low
R3H = $E7   ; operand 3 high

; --- 16-bit pointers ---
PTR1 = $E8
PTR2 = $EA
PTR3 = $EC

; --- loop counter ---
CNT = $EE

; --- 32-bit accumulator (two's complement) ---
ACCL = $F0   ; low word low byte
ACCH = $F1   ; low word high byte
ACCML= $F2   ; high word low byte
ACCMH= $F3   ; high word high byte

; --- scratch ---
SIGN = $F4   ; $00 = positive, $FF = negative
OVFL = $F5   ; overflow flag
TMP1 = $F6
TMP2 = $F7

; --- LFSR state ---
SEED = $F8   ; 15-bit LFSR state (low byte)
SEEDH= $F9   ; high byte

; --- multiply temporaries ---
zp_MUL_A_LO = $E0
zp_MUL_A_HI = $E1
zp_MUL_B_LO = $E2
zp_MUL_B_HI = $E3
zp_PROD0    = $F0
zp_PROD1    = $F1
zp_PROD2    = $F2
zp_PROD3    = $F3
zp_SIGN     = $F4

; --- add/result ---
zp_A_LO = $E0
zp_A_HI = $E1
zp_B_LO = $E2
zp_B_HI = $E3
zp_R_LO = $E4
zp_R_HI = $E5

; --- Q result (fxmul output) ---
zp_Q_LO = $E4
zp_Q_HI = $E5
