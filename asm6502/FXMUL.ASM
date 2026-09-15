; NN/16 6502 Fixed-Point Kernel
; FXMUL: A*B -> scale >>8 -> round half away from zero -> clip [-256,255]
; Entry: zp_MUL_A_LO/HI = A, zp_MUL_B_LO/HI = B
; Exit:  zp_Q_LO/HI = result in [-256, 255]

        include KERNEL.I

FXMUL:
        JSR MUL16X16
        ; Product in PROD0..PROD3 (32-bit)
        ; Scale >>8: take PROD1 as Q_LO, PROD2 as Q_HI
        LDA zp_PROD1
        STA zp_Q_LO
        LDA zp_PROD2
        STA zp_Q_HI

        ; Rounding: inspect bit 7 of PROD0 (the 0.5 bit)
        LDA zp_PROD0
        BPL @noround        ; bit7=0, |rem| < 128, no round
        ; Round away from zero
        LDA zp_SIGN
        BNE @neground
        ; Positive: add 1 to Q
        INC zp_Q_LO
        BNE @noround
        INC zp_Q_HI
        JMP @noround
@neground:
        ; Negative: subtract 1 from Q (away from zero)
        LDA zp_Q_LO
        BNE @dec1
        DEC zp_Q_HI
@dec1:  DEC zp_Q_LO
@noround:

        ; Clip to [-256, 255]
        ; 255  = $00FF, Q_HI=0, Q_LO<=FF
        ; -256 = $FF00, Q_HI=FF, Q_LO=00
        LDA zp_Q_HI
        BMI @checkmin
        ; Positive: check > 255 (Q_HI > 0)
        BEQ @done            ; Q_HI=0, value in [0,255] already
        ; Q_HI > 0: clamp to 255
        LDA #$FF
        STA zp_Q_LO
        LDA #$00
        STA zp_Q_HI
        JMP @done
@checkmin:
        ; Negative: check < -256 (Q_HI < $FF)
        CMP #$FF
        BEQ @done            ; Q_HI=$FF: value in [-256,-1] already
        ; Q_HI < $FF: clamp to -256
        LDA #$00
        STA zp_Q_LO
        LDA #$FF
        STA zp_Q_HI
@done:  RTS

; --- SATADD16 using FXMUL register layout ---
; Entry: zp_A_LO/HI, zp_B_LO/HI
; Exit:  zp_R_LO/HI = SATADD(A, B)
SATADD_FX:
        CLC
        LDA zp_A_LO
        ADC zp_B_LO
        STA zp_R_LO
        LDA zp_A_HI
        ADC zp_B_HI
        STA zp_R_HI
        ; Saturation check via overflow of signed add
        ; Simplified: check Q_HI for out-of-range
        LDA zp_R_HI
        BPL @pos
        CMP #$80
        BNE @done
        LDA zp_R_LO
        JMP @done
@pos:   CMP #$7F
        BCC @done
        LDA #$FF
        STA zp_R_LO
        LDA #$7F
        STA zp_R_HI
@done:  RTS

; --- ACT: clip Q to [-256, 255] ---
; Entry: zp_Q_LO/HI
; Exit:  zp_Q_LO/HI clipped
ACT6502:
        LDA zp_Q_HI
        BMI @neg
        BEQ @done            ; 0..255 OK
        ; > 255
        LDA #$FF
        STA zp_Q_LO
        LDA #$00
        STA zp_Q_HI
        RTS
@neg:   CMP #$FF
        BEQ @done            ; -256..-1 OK
        ; < -256
        LDA #$00
        STA zp_Q_LO
        LDA #$FF
        STA zp_Q_HI
@done:  RTS
