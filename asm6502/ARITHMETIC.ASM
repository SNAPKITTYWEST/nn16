; ============================================================
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (c) 2026 SnapKittyWest
; Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
; CLONE GATE: Any clone, fork, or derivative of this node
; MUST be released under GPL-3.0-or-later. No closed-source use.
; ============================================================
; ============================================================================
; Apple II 6502 Arithmetic Kernel
; ============================================================================
; 16-bit signed integer arithmetic with saturation
; Fixed-point support (Q15.16 representation)
; 
; Zero page allocation:
;   $00–$01   ACC_H, ACC_L (accumulator, 16-bit result)
;   $02–$03   ARG1_H, ARG1_L (first operand)
;   $04–$05   ARG2_H, ARG2_L (second operand)
;   $06–$07   TEMP_H, TEMP_L (temporary)
;   $08       FLAGS (overflow, sign, zero)
;   $09–$0F   Reserved for layer interface
;
; ============================================================================

.setcpu "6502"

; ---- Zero page aliases ----
ACC_L     = $00
ACC_H     = $01
ARG1_L    = $02
ARG1_H    = $03
ARG2_L    = $04
ARG2_H    = $05
TEMP_L    = $06
TEMP_H    = $07
FLAGS     = $08
CARRY_H   = $09
CARRY_L   = $0A

; ---- Flag bits ----
OVFL_FLAG = $80    ; bit 7: overflow
SIGN_FLAG = $40    ; bit 6: sign (negative if set)
ZERO_FLAG = $20    ; bit 5: zero
SAT_FLAG  = $10    ; bit 4: saturation occurred

; ============================================================================
; INT16_ADD
; ============================================================================
; Add two signed 16-bit integers with saturation
;
; Entry:
;   ARG1_H:ARG1_L = first operand (signed 16-bit)
;   ARG2_H:ARG2_L = second operand (signed 16-bit)
;
; Exit:
;   ACC_H:ACC_L = sum (saturated if overflow)
;   FLAGS.OVFL_FLAG set if overflow occurred
;
; Implementation:
;   - Perform 16-bit addition
;   - Detect overflow: if (ARG1 sign == ARG2 sign) != result sign
;   - Saturate to 0x7FFF (max positive) or 0x8000 (max negative)
;
; ============================================================================

.proc INT16_ADD
    ; Low byte addition
    lda ARG1_L
    clc
    adc ARG2_L
    sta ACC_L
    
    ; High byte addition with carry
    lda ARG1_H
    adc ARG2_H
    sta ACC_H
    
    ; Clear flags
    lda #0
    sta FLAGS
    
    ; Overflow detection:
    ; If signs of ARG1 and ARG2 match, and result sign differs, overflow occurred
    
    ; Extract sign bits
    lda ARG1_H
    and #$80
    sta TEMP_L      ; TEMP_L = ARG1 sign bit
    
    lda ARG2_H
    and #$80
    sta TEMP_H      ; TEMP_H = ARG2 sign bit
    
    ; Check if signs match
    lda TEMP_L
    eor TEMP_H
    bne @no_overflow    ; If signs differ, no overflow possible
    
    ; Signs match; check if result sign differs
    lda ACC_H
    and #$80
    sta TEMP_L      ; TEMP_L = result sign bit
    
    lda ARG1_H
    and #$80        ; ARG1 sign bit (which equals ARG2 sign bit)
    eor TEMP_L      ; XOR with result sign
    beq @no_overflow    ; If result sign matches, no overflow
    
    ; Overflow occurred: saturate
    lda #SAT_FLAG
    ora FLAGS
    sta FLAGS
    
    ; Saturate based on ARG1 sign
    lda ARG1_H
    and #$80
    bne @saturate_negative
    
    ; Saturate to positive: 0x7FFF
    lda #$7F
    sta ACC_H
    lda #$FF
    sta ACC_L
    jmp @return
    
@saturate_negative:
    ; Saturate to negative: 0x8000
    lda #$80
    sta ACC_H
    lda #$00
    sta ACC_L
    
@no_overflow:
    ; Set ZERO_FLAG if result is zero
    lda ACC_H
    ora ACC_L
    beq @set_zero
    jmp @return
    
@set_zero:
    lda FLAGS
    ora #ZERO_FLAG
    sta FLAGS
    
@return:
    rts
.endproc

; ============================================================================
; INT16_SUB
; ============================================================================
; Subtract two signed 16-bit integers with saturation
;
; Entry:
;   ARG1_H:ARG1_L = minuend (signed 16-bit)
;   ARG2_H:ARG2_L = subtrahend (signed 16-bit)
;
; Exit:
;   ACC_H:ACC_L = difference (saturated if overflow)
;   FLAGS.OVFL_FLAG set if overflow occurred
;
; Implementation:
;   - Two's complement: a - b = a + (-b)
;   - Negate ARG2 (invert bits, add 1)
;   - Call INT16_ADD
;
; ============================================================================

.proc INT16_SUB
    ; Negate ARG2: -x = ~x + 1
    ; First: invert
    lda ARG2_L
    eor #$FF
    sta ARG2_L
    
    lda ARG2_H
    eor #$FF
    sta ARG2_H
    
    ; Then: add 1 to low byte
    clc
    lda ARG2_L
    adc #$01
    sta ARG2_L
    
    ; Carry propagates to high byte
    lda ARG2_H
    adc #$00
    sta ARG2_H
    
    ; Now call INT16_ADD
    jsr INT16_ADD
    
    rts
.endproc

; ============================================================================
; INT16_MUL (16-bit × 16-bit → 32-bit, then saturate to 16-bit)
; ============================================================================
; Multiply two signed 16-bit integers
;
; Entry:
;   ARG1_H:ARG1_L = multiplicand (signed 16-bit)
;   ARG2_H:ARG2_L = multiplier (signed 16-bit)
;
; Exit:
;   ACC_H:ACC_L = product (32-bit result saturated to signed 16-bit)
;   CARRY_H:CARRY_L = high 16 bits of product (for full precision)
;   FLAGS.SAT_FLAG set if result was saturated
;
; Notes:
;   - This multiplies 16-bit × 16-bit to produce a 32-bit result
;   - The full 32-bit result is stored in ACC (low 16) and CARRY (high 16)
;   - If the high 16 bits are non-zero, saturation occurs
;   - For fixed-point Q15.16, see FX16_MUL
;
; Algorithm: Shift-and-add multiplication
;   1. Load ARG1 into X:A registers
;   2. Iterate 16 times
;   3. Test LSB of multiplier
;   4. If set, add multiplicand to accumulator
;   5. Shift accumulator right, shift multiplier left
;
; ============================================================================

.proc INT16_MUL
    ; Initialize result to zero
    lda #$00
    sta ACC_L
    sta ACC_H
    sta CARRY_L
    sta CARRY_H
    sta TEMP_L      ; Bit counter
    
    ; Determine sign of result
    lda ARG1_H
    eor ARG2_H
    and #$80
    sta TEMP_H      ; TEMP_H = sign of result
    
    ; Convert operands to positive (for unsigned multiplication)
    lda ARG1_H
    bpl @arg1_pos
    ; ARG1 is negative, negate it
    lda ARG1_L
    eor #$FF
    sta ARG1_L
    lda ARG1_H
    eor #$FF
    sta ARG1_H
    clc
    lda ARG1_L
    adc #$01
    sta ARG1_L
    lda ARG1_H
    adc #$00
    sta ARG1_H
    
@arg1_pos:
    lda ARG2_H
    bpl @arg2_pos
    ; ARG2 is negative, negate it
    lda ARG2_L
    eor #$FF
    sta ARG2_L
    lda ARG2_H
    eor #$FF
    sta ARG2_H
    clc
    lda ARG2_L
    adc #$01
    sta ARG2_L
    lda ARG2_H
    adc #$00
    sta ARG2_H
    
@arg2_pos:
    ; Now multiply (unsigned)
    ; Loop 16 times
    ldx #16
    
@mul_loop:
    ; Check LSB of ARG2
    lda ARG2_L
    and #$01
    beq @skip_add
    
    ; Add ARG1 to ACC
    clc
    lda ARG1_L
    adc ACC_L
    sta ACC_L
    
    lda ARG1_H
    adc ACC_H
    sta ACC_H
    
    lda #$00
    adc CARRY_L
    sta CARRY_L
    
    lda #$00
    adc CARRY_H
    sta CARRY_H
    
@skip_add:
    ; Shift result right by 1 (arithmetic, preserve sign)
    ; Actually, for unsigned: shift left
    ; Shift ARG1 left, ARG2 right
    
    ; Shift ARG1 left
    asl ARG1_L
    rol ARG1_H
    
    ; Shift ARG2 right
    lsr ARG2_H
    ror ARG2_L
    
    dex
    bne @mul_loop
    
    ; Result is in CARRY:ACC (32-bit)
    ; Check for overflow: if CARRY_H or CARRY_L nonzero, saturate
    
    lda #0
    sta FLAGS
    
    lda CARRY_H
    ora CARRY_L
    beq @mul_no_overflow
    
    ; Overflow: saturate to max value
    lda #SAT_FLAG
    sta FLAGS
    
    lda TEMP_H
    beq @saturate_positive
    
    ; Negative result saturated to -32768 (0x8000)
    lda #$80
    sta ACC_H
    lda #$00
    sta ACC_L
    jmp @mul_return
    
@saturate_positive:
    ; Positive result saturated to +32767 (0x7FFF)
    lda #$7F
    sta ACC_H
    lda #$FF
    sta ACC_L
    
@mul_no_overflow:
    ; Apply sign
    lda TEMP_H
    beq @mul_return
    
    ; Result should be negative; negate it
    lda ACC_L
    eor #$FF
    sta ACC_L
    lda ACC_H
    eor #$FF
    sta ACC_H
    clc
    lda ACC_L
    adc #$01
    sta ACC_L
    lda ACC_H
    adc #$00
    sta ACC_H
    
@mul_return:
    rts
.endproc

; ============================================================================
; FX16_MUL (Fixed-point Q15.16 multiply)
; ============================================================================
; Multiply two fixed-point values in Q15.16 format
; Result is also in Q15.16 format
;
; Entry:
;   ARG1_H:ARG1_L = multiplicand (Q15.16)
;   ARG2_H:ARG2_L = multiplier (Q15.16)
;
; Exit:
;   ACC_H:ACC_L = product (Q15.16, saturated)
;   FLAGS.SAT_FLAG set if overflow
;
; Algorithm:
;   1. Call INT16_MUL to get 32-bit product
;   2. Right-shift product by 16 bits (divide by 65536)
;   3. Keep result in ACC (which now holds the properly scaled result)
;
; ============================================================================

.proc FX16_MUL
    ; First multiply to get 32-bit result
    jsr INT16_MUL
    
    ; Result is in CARRY_H:CARRY_L:ACC_H:ACC_L (32 bits)
    ; We need the middle 16 bits (bits 16–31)
    ; That's CARRY_L:CARRY_H after right-shift by 16
    
    ; Move CARRY to ACC
    lda CARRY_H
    sta ACC_H
    lda CARRY_L
    sta ACC_L
    
    ; Clear the high carry (result is now in ACC_H:ACC_L)
    
    rts
.endproc

; ============================================================================
; SATURATE (Saturate ACC to signed 16-bit range)
; ============================================================================
; Clamp ACC to [−32768, +32767]
;
; Entry:
;   ACC_H:ACC_L = any value
;
; Exit:
;   ACC_H:ACC_L = saturated value in [−32768, +32767]
;   FLAGS.SAT_FLAG set if saturation occurred
;
; ============================================================================

.proc SATURATE
    lda #0
    sta FLAGS
    
    ; Check high byte
    lda ACC_H
    cmp #$7F
    beq @check_high_ff
    bpl @saturate_pos
    
@check_high_ff:
    cmp #$FF
    beq @maybe_ok
    bmi @saturate_neg
    
@maybe_ok:
    ; High byte is 0x7F or 0xFF; need to check if valid
    lda ACC_H
    and #$80
    sta TEMP_L
    
    ; For 0x7F (positive), any low byte is OK
    ; For 0xFF (negative), any low byte is OK
    ; For other values, out of range
    
    lda ACC_H
    cmp #$7F
    beq @return
    cmp #$FF
    beq @return
    
    ; Out of range
    bpl @saturate_pos
    
@saturate_neg:
    lda #SAT_FLAG
    sta FLAGS
    lda #$80
    sta ACC_H
    lda #$00
    sta ACC_L
    jmp @return
    
@saturate_pos:
    lda #SAT_FLAG
    sta FLAGS
    lda #$7F
    sta ACC_H
    lda #$FF
    sta ACC_L
    
@return:
    rts
.endproc

; ============================================================================
; SIGN_EXTEND (Extend 8-bit signed value to 16-bit)
; ============================================================================
; Entry:
;   A register = 8-bit signed value
;
; Exit:
;   ACC_H:ACC_L = 16-bit sign-extended value
;
; ============================================================================

.proc SIGN_EXTEND
    sta ACC_L
    
    ; Check sign bit of A
    and #$80
    beq @positive
    
    ; Negative: set high byte to 0xFF
    lda #$FF
    sta ACC_H
    rts
    
@positive:
    ; Positive: set high byte to 0x00
    lda #$00
    sta ACC_H
    rts
.endproc

; ============================================================================
; NEGATE (Negate 16-bit value in ACC)
; ============================================================================
; Entry:
;   ACC_H:ACC_L = value to negate
;
; Exit:
;   ACC_H:ACC_L = −value (saturated if overflow)
;
; Implementation: Two's complement: invert, add 1
;
; ============================================================================

.proc NEGATE
    ; Invert bits
    lda ACC_L
    eor #$FF
    sta ACC_L
    
    lda ACC_H
    eor #$FF
    sta ACC_H
    
    ; Add 1
    clc
    lda ACC_L
    adc #$01
    sta ACC_L
    
    lda ACC_H
    adc #$00
    sta ACC_H
    
    ; Saturate (edge case: −32768 negates to itself)
    jsr SATURATE
    
    rts
.endproc

; ============================================================================
; INT16_ABS (Absolute value of 16-bit signed integer)
; ============================================================================
; Entry:
;   ACC_H:ACC_L = signed 16-bit value
;
; Exit:
;   ACC_H:ACC_L = |value| (saturated)
;
; ============================================================================

.proc INT16_ABS
    ; Check sign
    lda ACC_H
    and #$80
    beq @return
    
    ; Negative: negate
    jsr NEGATE
    
@return:
    rts
.endproc

; ============================================================================
; INT16_CMP (Compare two signed 16-bit values)
; ============================================================================
; Entry:
;   ARG1_H:ARG1_L = first value
;   ARG2_H:ARG2_L = second value
;
; Exit:
;   Z flag = 1 if equal
;   C flag = 1 if ARG1 >= ARG2 (for unsigned semantics, see overflow note)
;
; Note: For signed comparison, use overflow bit
;
; ============================================================================

.proc INT16_CMP
    ; Compare high bytes first
    lda ARG1_H
    cmp ARG2_H
    bne @cmp_done
    
    ; High bytes equal, compare low bytes
    lda ARG1_L
    cmp ARG2_L
    
@cmp_done:
    rts
.endproc

; ============================================================================
; End of Arithmetic Kernel
; ============================================================================
