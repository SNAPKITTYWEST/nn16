; NN/16 6502 ADD Kernel
; 16-bit signed addition with carry / saturation option
; Zero-page parameter passing per KERNEL.I

zp_A_LO = $E0
zp_A_HI = $E1
zp_B_LO = $E2
zp_B_HI = $E3
zp_R_LO = $E4
zp_R_HI = $E5
zp_SIGN = $F4

ADD16:
        CLC
        LDA zp_A_LO
        ADC zp_B_LO
        STA zp_R_LO
        LDA zp_A_HI
        ADC zp_B_HI
        STA zp_R_HI
        RTS

; Saturated signed add -> clamp to $8000..$7FFF
SATADD16:
        JSR ADD16
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
