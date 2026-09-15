; NN/16 6502 Signed Multiply Kernel
; 16x16 -> 32-bit shift-add then scale >>8

zp_MUL_A_LO = $E0
zp_MUL_A_HI = $E1
zp_MUL_B_LO = $E2
zp_MUL_B_HI = $E3
zp_PROD0    = $F0
zp_PROD1    = $F1
zp_PROD2    = $F2
zp_PROD3    = $F3
zp_SIGN     = $F4

MUL16X16:
        LDA zp_MUL_A_HI
        EOR zp_MUL_B_HI
        AND #$80
        STA zp_SIGN

        LDA #0
        STA zp_PROD0
        STA zp_PROD1
        STA zp_PROD2
        STA zp_PROD3

        LDX #16
@loop:  LSR zp_MUL_B_HI
        ROR zp_MUL_B_LO
        BCC @noadd
        CLC
        LDA zp_PROD0
        ADC zp_MUL_A_LO
        STA zp_PROD0
        LDA zp_PROD1
        ADC zp_MUL_A_HI
        STA zp_PROD1
        LDA zp_PROD2
        ADC #0
        STA zp_PROD2
        LDA zp_PROD3
        ADC #0
        STA zp_PROD3
@noadd: ASL zp_MUL_A_LO
        ROL zp_MUL_A_HI
        DEX
        BNE @loop

        LDA zp_SIGN
        BEQ @done
        SEC
        LDA #0
        SBC zp_PROD0
        STA zp_PROD0
        LDA #0
        SBC zp_PROD1
        STA zp_PROD1
        LDA #0
        SBC zp_PROD2
        STA zp_PROD2
        LDA #0
        SBC zp_PROD3
        STA zp_PROD3
@done:  RTS
