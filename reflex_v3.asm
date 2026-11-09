; Reflex test v3 for ATmega32 at 8 MHz
; Microchip Studio / AVRASM2
; Buttons are active low on PD2, PD3 and PD4.
; Display segments A-G and DP use PC0-PC7.
; The result is shown for 3 s, then the next round starts automatically.

.equ MIN_WAIT_MS = 500
.equ MAX_WAIT_MS = 8000
.equ RESULT_HOLD_MS = 3000
.equ TIMER1_COMPARE = 124

.cseg
.org 0x0000
reset:
    cli
    clr r2
    ldi r16, 0x08
    out 0x3e, r16
    ldi r16, 0x5f
    out 0x3d, r16

    ; Disable JTAG to free PC2 through PC5.
    in r16, 0x34
    ori r16, 0x80
    out 0x34, r16
    out 0x34, r16

    out 0x1b, r2
    out 0x15, r2
    ldi r16, 0xef
    out 0x1a, r16
    ldi r16, 0xff
    out 0x14, r16
    out 0x11, r2
    ldi r16, 0x1c
    out 0x12, r16

    ; Timer1 CTC at 1 kHz: 8 MHz / 64 / (124 + 1).
    out 0x2f, r2
    out 0x2e, r2
    out 0x2d, r2
    out 0x2c, r2
    out 0x2b, r2
    ldi r16, TIMER1_COMPARE
    out 0x2a, r16
    ldi r16, 0x10
    out 0x38, r16
    ldi r16, 0x0b
    out 0x2e, r16

    clr r17
    ldi r26, 0x39
    ldi r27, 0x6a
L_round:
    ldi r20, 0x3f
    mov r21, r20
    mov r22, r20
    mov r23, r20

L_delay_choice:
    rcall L_random
    movw r24, r26
    andi r25, 0x1f
    cpi r24, low(MAX_WAIT_MS + 1)
    ldi r16, high(MAX_WAIT_MS + 1)
    cpc r25, r16
    brsh L_delay_choice
    ; Keep 0000 visible for at least half a second in every round.
    cpi r24, low(MIN_WAIT_MS)
    ldi r16, high(MIN_WAIT_MS)
    cpc r25, r16
    brlo L_delay_choice
L_delay_tick:
    rcall L_tick
    sbiw r24, 1
    brne L_delay_tick

L_choose_target:
    rcall L_random
    mov r28, r26
    andi r28, 3
    cpi r28, 3
    breq L_choose_target
    ldi r16, 0x04
    tst r28
    breq L_target_mask
    lsl r16
    cpi r28, 1
    breq L_target_mask
    lsl r16
L_target_mask:
    mov r15, r16
    inc r28
    mov r16, r28
    rcall L_glyph
    mov r23, r16
    clr r20
    clr r21
    clr r22
    clr r8
    clr r9
    clr r10
    clr r11
    clr r12
    clr r14

    ; Sample just before displaying the target to detect an already held key.
    in r18, 0x10
    com r18
    and r18, r15
    mov r13, r18
    ldi r17, 3
    rcall L_tick
    tst r13
    breq L_reaction_tick

L_release_target:
    rcall L_tick
    rcall L_random
    rcall L_count_ms
    and r18, r15
    breq L_release_sample
    clr r14
    rjmp L_release_target
L_release_sample:
    inc r14
    ldi r16, 5
    cp r14, r16
    brlo L_release_target
    clr r14

L_reaction_tick:
    rcall L_tick
    rcall L_random
    rcall L_count_ms
    and r18, r15
    breq L_cancel_sample
    tst r14
    brne L_confirm_sample
    mov r3, r8
    mov r4, r9
    mov r5, r10
    mov r6, r11
    mov r7, r12
L_confirm_sample:
    inc r14
    ldi r16, 5
    cp r14, r16
    brlo L_reaction_tick
    rjmp L_result
L_cancel_sample:
    clr r14
    rjmp L_reaction_tick

L_result:
    tst r7
    brne L_long_result
    mov r16, r6
    rcall L_glyph
    ori r16, 0x80
    mov r20, r16
    mov r16, r5
    rcall L_glyph
    mov r21, r16
    mov r16, r4
    rcall L_glyph
    mov r22, r16
    mov r16, r3
    rcall L_glyph
    mov r23, r16
    rjmp L_result_hold
L_long_result:
    mov r16, r7
    rcall L_glyph
    mov r20, r16
    mov r16, r6
    rcall L_glyph
    ori r16, 0x80
    mov r21, r16
    mov r16, r5
    rcall L_glyph
    mov r22, r16
    mov r16, r4
    rcall L_glyph
    mov r23, r16

L_result_hold:
    ; Hold the result for 3 s. The next round starts automatically.
    ldi r24, low(RESULT_HOLD_MS)
    ldi r25, high(RESULT_HOLD_MS)
L_result_tick:
    rcall L_tick
    sbiw r24, 1
    brne L_result_tick
    rjmp L_round

L_tick:
    in r16, 0x38
    sbrs r16, 4
    rjmp L_tick
    ldi r16, 0x10
    out 0x38, r16

    ; Blank the segment bus and allow the previous digit driver to turn off.
    out 0x15, r2
    out 0x1b, r2
    ldi r16, 250
L_blank:
    dec r16
    brne L_blank

    ; Physical digit order: PA2, PA1, PA3, PA0.
    mov r16, r20
    ldi r19, 0x04
    cpi r17, 0
    breq L_drive
    mov r16, r21
    ldi r19, 0x02
    cpi r17, 1
    breq L_drive
    mov r16, r22
    ldi r19, 0x08
    cpi r17, 2
    breq L_drive
    mov r16, r23
    ldi r19, 0x01
L_drive:
    out 0x15, r16
    ldi r16, 32
L_settle:
    dec r16
    brne L_settle
    out 0x1b, r19
    inc r17
    andi r17, 3
    in r18, 0x10
    com r18
    andi r18, 0x1c
    ret

L_random:
    lsr r27
    ror r26
    brcc L_random_done
    ldi r16, 0xb4
    eor r27, r16
L_random_done:
    ret

L_glyph:
    ldi r30, low(2 * L_glyphs)
    ldi r31, high(2 * L_glyphs)
    add r30, r16
    adc r31, r2
    lpm r16, Z
    ret

L_count_ms:
    ldi r16, 10
    inc r8
    cp r8, r16
    brlo L_count_done
    clr r8
    inc r9
    cp r9, r16
    brlo L_count_done
    clr r9
    inc r10
    cp r10, r16
    brlo L_count_done
    clr r10
    inc r11
    cp r11, r16
    brlo L_count_done
    clr r11
    inc r12
    cp r12, r16
    brlo L_count_done
    dec r16
    mov r8, r16
    mov r9, r16
    mov r10, r16
    mov r11, r16
    mov r12, r16
L_count_done:
    ret

L_glyphs:
    .db 0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f
