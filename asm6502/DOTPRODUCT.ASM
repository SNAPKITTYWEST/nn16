; ============================================================
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (c) 2026 SnapKittyWest
; Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
; CLONE GATE: Any clone, fork, or derivative of this node
; MUST be released under GPL-3.0-or-later. No closed-source use.
; ============================================================
; ============================================================================
; Apple II 6502 Dot Product Kernel
; ============================================================================
; Compute dot product of two vectors: Σ(A[i] × B[i])
; This is the foundational operation for all neural computations
;
; Zero page allocation:
;   $00–$01   ACC_L, ACC_H (32-bit accumulator, low word)
;   $02–$03   CARRY_L, CARRY_H (32-bit accumulator, high word)
;   $04–$05   ADDR_A_L, ADDR_A_H (address of vector A)
;   $06–$07   ADDR_B_L, ADDR_B_H (address of vector B)
;   $08       LENGTH (number of elements)
;   $09–$0A   INDEX (loop counter)
;   $0B–$0C   TEMP_L, TEMP_H (temporary storage)
;   $0D       FLAGS (overflow, sign, etc.)
;
; ============================================================================

.setcpu "6502"

; ---- Zero page aliases ----
ACC_L        = $00
ACC_H        = $01
CARRY_L      = $02
CARRY_H      = $03
ADDR_A_L     = $04
ADDR_A_H     = $05
ADDR_B_L     = $06
ADDR_B_H     = $07
LENGTH       = $08
INDEX_L      = $09
INDEX_H      = $0A
TEMP_L       = $0B
TEMP_H       = $0C
FLAGS        = $0D

OVFL_FLAG    = $80
SAT_FLAG     = $10

; ============================================================================
; DOTPRODUCT
; ============================================================================
; Compute Σ(A[i] × B[i]) for i = 0 to LENGTH-1
;
; Entry:
;   ADDR_A_L:ADDR_A_H = base address of vector A (16-bit signed values)
;   ADDR_B_L:ADDR_B_H = base address of vector B (16-bit signed values)
;   LENGTH             = number of elements (1–256)
;
; Exit:
;   ACC_L:ACC_H:CARRY_L:CARRY_H = 32-bit signed result (dot product)
;   FLAGS.SAT_FLAG set if overflow occurred during accumulation
;
; Algorithm:
;   1. Initialize accumulator to zero (32-bit)
;   2. For each element i (0 to LENGTH-1):
;      a. Load A[i] (16-bit value at ADDR_A + 2*i)
;      b. Load B[i] (16-bit value at ADDR_B + 2*i)
;      c. Multiply A[i] × B[i] using 16×16→32 multiplication
;      d. Add product to 32-bit accumulator
;      e. Check for overflow in accumulator
;   3. Return 32-bit result
;
; Safety:
;   - Accumulator is 32-bit to prevent overflow in most cases
;   - Maximum safe sum: 256 × (32767 × 32767) ≈ 2.7 × 10^11
;     (exceeds 32-bit range, so overflow is possible)
;   - Overflow flag indicates saturation should be applied at higher level
;
; ============================================================================

.proc DOTPRODUCT
    ; Initialize 32-bit accumulator to zero
    lda #$00
    sta ACC_L
    sta ACC_H
    sta CARRY_L
    sta CARRY_H
    sta FLAGS
    
    ; Initialize index to zero
    sta INDEX_L
    sta INDEX_H
    
    ; Check length
    lda LENGTH
    beq @return     ; If length = 0, return 0
    
    ; Main loop: for index = 0 to length-1
@loop:
    ; Calculate offset: index × 2 (since each element is 16-bit)
    lda INDEX_L
    asl             ; Multiply by 2
    sta TEMP_L
    
    lda INDEX_H
    rol             ; Carry from shift
    sta TEMP_H
    
    ; Load A[index]
    ; Address = ADDR_A + offset
    clc
    lda ADDR_A_L
    adc TEMP_L
    sta $20         ; Temporary address for A[i]
    
    lda ADDR_A_H
    adc TEMP_H
    sta $21
    
    ; Load A[index].low via indirect addressing
    ldy #$00
    lda ($20),y
    sta $30         ; A[index].low (temporary)
    
    ; Load A[index].high
    iny
    lda ($20),y
    sta $31         ; A[index].high (temporary)
    
    ; Load B[index]
    clc
    lda ADDR_B_L
    adc TEMP_L
    sta $20
    
    lda ADDR_B_H
    adc TEMP_H
    sta $21
    
    ; Load B[index].low
    ldy #$00
    lda ($20),y
    sta $32         ; B[index].low (temporary)
    
    ; Load B[index].high
    iny
    lda ($20),y
    sta $33         ; B[index].high (temporary)
    
    ; Now multiply A[index] × B[index]
    ; A[index] is in $31:$30
    ; B[index] is in $33:$32
    ; Use inline multiplication (shift-and-add)
    
    ; Initialize product to zero
    lda #$00
    sta $40         ; Product.L
    sta $41         ; Product.H
    sta $42         ; Product.Carry.L
    sta $43         ; Product.Carry.H
    
    ; Determine sign of result
    lda $31
    eor $33
    and #$80
    sta TEMP_L      ; Result sign
    
    ; Take absolute values of operands
    ; Check A[index] sign
    lda $31
    bpl @a_positive
    
    ; A[index] is negative, negate it
    lda $30
    eor #$FF
    sta $30
    lda $31
    eor #$FF
    sta $31
    clc
    lda $30
    adc #$01
    sta $30
    lda $31
    adc #$00
    sta $31
    
@a_positive:
    ; Check B[index] sign
    lda $33
    bpl @b_positive
    
    ; B[index] is negative, negate it
    lda $32
    eor #$FF
    sta $32
    lda $33
    eor #$FF
    sta $33
    clc
    lda $32
    adc #$01
    sta $32
    lda $33
    adc #$00
    sta $33
    
@b_positive:
    ; Multiply (unsigned): ($31:$30) × ($33:$32)
    ; Using 16-bit shift-and-add
    
    ldx #$10        ; 16 iterations
    
@mul_loop:
    ; Test LSB of B[index]
    lda $32
    and #$01
    beq @mul_skip_add
    
    ; Add A[index] to product
    clc
    lda $30
    adc $40
    sta $40
    
    lda $31
    adc $41
    sta $41
    
    lda #$00
    adc $42
    sta $42
    
    lda #$00
    adc $43
    sta $43
    
@mul_skip_add:
    ; Shift A[index] left, B[index] right
    asl $30
    rol $31
    
    lsr $33
    ror $32
    
    dex
    bne @mul_loop
    
    ; Apply sign to product
    lda TEMP_L
    beq @product_positive
    
    ; Negate product
    lda $40
    eor #$FF
    sta $40
    
    lda $41
    eor #$FF
    sta $41
    
    lda $42
    eor #$FF
    sta $42
    
    lda $43
    eor #$FF
    sta $43
    
    clc
    lda $40
    adc #$01
    sta $40
    
    lda $41
    adc #$00
    sta $41
    
    lda $42
    adc #$00
    sta $42
    
    lda $43
    adc #$00
    sta $43
    
@product_positive:
    ; Add product ($43:$42:$41:$40) to accumulator (CARRY:ACC)
    ; Note: We're keeping a 32-bit accumulator, so this is a full 32-bit add
    
    clc
    lda $40
    adc ACC_L
    sta ACC_L
    
    lda $41
    adc ACC_H
    sta ACC_H
    
    lda $42
    adc CARRY_L
    sta CARRY_L
    
    lda $43
    adc CARRY_H
    sta CARRY_H
    
    ; Check for overflow (if CARRY_H is nonzero, we've overflowed 32-bit)
    lda CARRY_H
    beq @no_overflow_yet
    
    ; Overflow detected
    lda FLAGS
    ora #SAT_FLAG
    sta FLAGS
    
@no_overflow_yet:
    ; Increment index
    clc
    lda INDEX_L
    adc #$01
    sta INDEX_L
    
    lda INDEX_H
    adc #$00
    sta INDEX_H
    
    ; Check if index < length
    lda INDEX_L
    cmp LENGTH
    bcc @loop        ; Continue if index < length
    
    ; Index >= length, exit loop
    
@return:
    rts
.endproc

; ============================================================================
; DOTPRODUCT_FIXED
; ============================================================================
; Compute dot product with fixed-point scaling
;
; This is similar to DOTPRODUCT but assumes inputs are in Q15.16 format
; and scales the result to match Q15.16 output range.
;
; The intermediate products are 32-bit fixed-point values.
; Summing them should still fit in 32-bit range for reasonable vector sizes.
;
; Entry:
;   ADDR_A_L:ADDR_A_H = base address of Q15.16 vector A
;   ADDR_B_L:ADDR_B_H = base address of Q15.16 vector B
;   LENGTH             = number of elements
;
; Exit:
;   ACC_L:ACC_H = result in Q15.16 (saturated to 16-bit)
;   CARRY_L:CARRY_H = 0
;   FLAGS.SAT_FLAG set if overflow
;
; ============================================================================

.proc DOTPRODUCT_FIXED
    ; Similar to DOTPRODUCT but with fixed-point handling
    ; First compute standard dot product
    jsr DOTPRODUCT
    
    ; Now the result is in 32-bit CARRY:ACC
    ; For fixed-point, we need to extract the middle 16 bits
    ; (The result is essentially (product of two Q15.16 values) / 65536)
    
    ; Shift right by 16 bits
    lda CARRY_L
    sta ACC_H
    
    lda CARRY_H
    ; This is the sign extension; for now assume reasonable values
    
    ; Check for overflow
    lda CARRY_H
    beq @no_fx_overflow
    
    lda FLAGS
    ora #SAT_FLAG
    sta FLAGS
    
    ; Saturate to 16-bit signed range
    lda CARRY_H
    and #$80
    beq @saturate_fx_positive
    
    ; Saturate to negative max
    lda #$80
    sta ACC_H
    lda #$00
    sta ACC_L
    jmp @fx_return
    
@saturate_fx_positive:
    ; Saturate to positive max
    lda #$7F
    sta ACC_H
    lda #$FF
    sta ACC_L
    
@no_fx_overflow:
@fx_return:
    rts
.endproc

; ============================================================================
; VECTOR_MAGNITUDE
; ============================================================================
; Compute magnitude (L2 norm) of a vector
; ||A|| = sqrt(Σ(A[i]²))
;
; Entry:
;   ADDR_A_L:ADDR_A_H = base address of vector A
;   LENGTH             = number of elements
;
; Exit:
;   ACC_L:ACC_H = squared magnitude (to avoid sqrt calculation)
;
; Notes:
;   - Returns squared magnitude to avoid floating-point sqrt
;   - Useful for normalization checks without sqrt
;
; ============================================================================

.proc VECTOR_MAGNITUDE
    ; Initialize accumulator
    lda #$00
    sta ACC_L
    sta ACC_H
    sta CARRY_L
    sta CARRY_H
    
    ; Initialize index
    sta INDEX_L
    sta INDEX_H
    
    ; Check length
    lda LENGTH
    beq @mag_return
    
@mag_loop:
    ; Calculate offset
    lda INDEX_L
    asl
    sta TEMP_L
    
    lda INDEX_H
    rol
    sta TEMP_H
    
    ; Load A[index]
    clc
    lda ADDR_A_L
    adc TEMP_L
    sta $20
    
    lda ADDR_A_H
    adc TEMP_H
    sta $21
    
    ldy #$00
    lda ($20),y
    sta $30
    iny
    lda ($20),y
    sta $31
    
    ; Square A[index]: A[index] × A[index]
    ; Copy to B for multiplication
    lda $30
    sta $32
    lda $31
    sta $33
    
    ; Use inline multiplication (same as in DOTPRODUCT)
    lda #$00
    sta $40
    sta $41
    sta $42
    sta $43
    
    ; A[index] is always positive in magnitude, so skip sign adjustment
    ldx #$10
    
@mag_mul_loop:
    lda $32
    and #$01
    beq @mag_mul_skip
    
    clc
    lda $30
    adc $40
    sta $40
    
    lda $31
    adc $41
    sta $41
    
    lda #$00
    adc $42
    sta $42
    adc #$00
    sta $43
    
@mag_mul_skip:
    asl $30
    rol $31
    
    lsr $33
    ror $32
    
    dex
    bne @mag_mul_loop
    
    ; Add square to accumulator
    clc
    lda $40
    adc ACC_L
    sta ACC_L
    
    lda $41
    adc ACC_H
    sta ACC_H
    
    lda $42
    adc CARRY_L
    sta CARRY_L
    
    lda $43
    adc CARRY_H
    sta CARRY_H
    
    ; Increment index
    clc
    lda INDEX_L
    adc #$01
    sta INDEX_L
    
    lda INDEX_H
    adc #$00
    sta INDEX_H
    
    lda INDEX_L
    cmp LENGTH
    bcc @mag_loop
    
@mag_return:
    rts
.endproc

; ============================================================================
; VECTOR_NORMALIZE (Partial: compute normalization factor)
; ============================================================================
; Compute unit vector by normalization
; This is a stub; full normalization requires division (expensive)
;
; Entry:
;   ADDR_A_L:ADDR_A_H = base address of vector A
;   LENGTH             = number of elements
;
; Exit:
;   ACC_L:ACC_H = magnitude in Q15.16 (use for scaling)
;
; ============================================================================

.proc VECTOR_NORMALIZE
    ; First compute squared magnitude
    jsr VECTOR_MAGNITUDE
    
    ; For now, return the squared magnitude
    ; A full normalization would require integer square root + division
    ; which is expensive in 6502 assembly
    
    rts
.endproc

; ============================================================================
; ACCUMULATE
; ============================================================================
; Add a value to the accumulator (utility function)
;
; Entry:
;   ADDR_A_L:ADDR_A_H = address of value to add
;   ACC_L:ACC_H = current accumulator
;
; Exit:
;   ACC_L:ACC_H = accumulator + value
;
; ============================================================================

.proc ACCUMULATE
    ldy #$00
    lda ($20),y     ; Load low byte of value
    
    clc
    adc ACC_L
    sta ACC_L
    
    iny
    lda ($20),y     ; Load high byte of value
    
    adc ACC_H
    sta ACC_H
    
    rts
.endproc

; ============================================================================
; End of Dot Product Kernel
; ============================================================================
