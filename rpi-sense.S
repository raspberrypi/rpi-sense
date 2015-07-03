/*
 * rpi-sense.S - Atmel assembly routines for LED framebuffer scan-out
 *
 * Copyright (c) 2015 Raspberry Pi Foundation
 *
 * Author: Serge Schneider <serge@raspberrypi.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *	* Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	* Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *	* Neither the name of Raspberry Pi nor the
 *	  names of its contributors may be used to endorse or promote products
 *	  derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <avr/io.h>
#include <util/twi.h>

LINE	= 24
PARAM	= 24
PWM	= 25
I2C_OFF	= 26	; XL

.equiv I2C_WAI	, 0xf0
.equiv I2C_VER	, 0xf1
.equiv I2C_KEYS	, 0xf2
.equiv I2C_EE_WP, 0xf3
.equiv I2C_ID	, 's'
.equiv VERSION	, 0

; PORTB
.equiv EE_WP	, PB0
.equiv KEYS_INT	, PB6
.equiv FRAME_INT, PB7

; PORTC
.equiv LED_SDO	, PC0
.equiv LED_CLKR	, PC1
.equiv LED_LE	, PC2
.equiv LED_SDI	, PC3
.equiv SDA	, PC4
.equiv SCL	, PC5
.equiv LED_OE_N	, PC7

.macro CLOCK_OUT
	SBI	_SFR_IO_ADDR(PORTC), LED_CLKR
	CBI	_SFR_IO_ADDR(PORTC), LED_CLKR
.endm

.macro COL_OUT reg
	CP	PWM, \reg
	BRSH	lclear\reg
	SBI	_SFR_IO_ADDR(PORTC), LED_SDI
	RJMP	ldone\reg
lclear\reg:
	CBI	_SFR_IO_ADDR(PORTC), LED_SDI
ldone\reg:
	CLOCK_OUT
.endm

.global draw_loop
.global delay
.global read_data
.global write_data
.global TWI_vect

.extern pixels
.extern id
.extern key
.extern i2c_reg

.section .text
.func draw_loop
draw_loop:
Lframe_loop:
	CBI	_SFR_IO_ADDR(PORTC), FRAME_INT
	LDI	YL, lo8(pixels)
	LDI	YH, hi8(pixels)
	LDI	LINE, 0xFE
Lline_loop:
	OUT	_SFR_IO_ADDR(PORTD), LINE
	LDI	PWM, 0
	LD	r0, Y+
	LD	r1, Y+
	LD	r2, Y+
	LD	r3, Y+
	LD	r4, Y+
	LD	r5, Y+
	LD	r6, Y+
	LD	r7, Y+
	LD	r8, Y+
	LD	r9, Y+
	LD	r10, Y+
	LD	r11, Y+
	LD	r12, Y+
	LD	r13, Y+
	LD	r14, Y+
	LD	r15, Y+
	LD	r16, Y+
	LD	r17, Y+
	LD	r18, Y+
	LD	r19, Y+
	LD	r20, Y+
	LD	r21, Y+
	LD	r22, Y+
	LD	r23, Y+
Lpwm_loop:
	COL_OUT	r0
	COL_OUT	r1
	COL_OUT	r2
	COL_OUT	r3
	COL_OUT	r4
	COL_OUT	r5
	COL_OUT	r6
	COL_OUT	r7
	COL_OUT	r8
	COL_OUT	r9
	COL_OUT	r10
	COL_OUT	r11
	COL_OUT	r12
	COL_OUT	r13
	COL_OUT	r14
	COL_OUT	r15
	COL_OUT	r16
	COL_OUT	r17
	COL_OUT	r18
	COL_OUT	r19
	COL_OUT	r20
	COL_OUT	r21
	SBI	_SFR_IO_ADDR(PORTC), LED_LE
	COL_OUT	r22
	COL_OUT	r23
	CBI	_SFR_IO_ADDR(PORTC), LED_LE
	INC	PWM
	SBRS	PWM, 6
	RJMP	Lpwm_loop
	ROL	LINE
	BRCC	lframeend
	INC	LINE
	RJMP	Lline_loop
lframeend:
	SBI	_SFR_IO_ADDR(PORTB), FRAME_INT
	CBI	_SFR_IO_ADDR(PORTD), 7		; Clear PORTD

	SBI	_SFR_IO_ADDR(PORTB), LED_OE_N	; Scan
	LDI	PARAM, 0xF8
	OUT	_SFR_IO_ADDR(PORTD), PARAM
	COM	PARAM
	OUT	_SFR_IO_ADDR(DDRD), PARAM
	LDS	PWM, keys
	IN	PARAM, _SFR_IO_ADDR(PIND)
	COM	PARAM
	LSR	PARAM
	LSR	PARAM
	LSR	PARAM
	STS	keys, PARAM
	CPSE	PARAM, PWM
	SBI     _SFR_IO_ADDR(PORTB), KEYS_INT
	LDI	PARAM, 0xFF
	OUT	_SFR_IO_ADDR(DDRD), PARAM
	COM	PARAM
	OUT	_SFR_IO_ADDR(PORTD), PARAM
	CBI	_SFR_IO_ADDR(PORTB), LED_OE_N	; /Scan
	RJMP	Lframe_loop
	RET
.endfunc

.func delay
delay:
	PUSH	r19
	PUSH	r20
	IN	r20, _SFR_IO_ADDR(TCNT0)	; start = TCNT0;
lloop:
	IN	r19, _SFR_IO_ADDR(TCNT0)	; do {
	SUB	r19, r20			; diff = TCNT0 - start;
	CP	r19, LINE			; } while (diff < ticks);
	BRLO	lloop
	POP	r20
	POP	r19
	RET
 .endfunc

.func write_data
; r20-23 DATA
; r24 TYPE
write_data:
	PUSH	r18
	;PUSH	r20
	PUSH	r21
	PUSH	r22
	PUSH	r23
	PUSH	r24
	LDI	r18, 24	;
1:						; do {
	SBRS	r23, 0				; 	if (data&1)
	RJMP	2f
	SBI	_SFR_IO_ADDR(PORTC), LED_SDI	; 		set LED_SDI;
	RJMP	3f
2:						; 	else
	CBI	_SFR_IO_ADDR(PORTC), LED_SDI	;		clr LED_SDI;
3:
	ASR	r23				; 	data <<= 1;
	ROR	r22
	ROR	r21
	;ROR	r20								; Don't need?
	CP	r24, r18			; 	if (type == i)
	BRNE	4f
	SBI	_SFR_IO_ADDR(PORTC), LED_LE	; 		set LDE_LE;
4:
	CLOCK_OUT
	DEC	r18				; 	i--;
	BRNE	1b				; } while (i!=0);
	CBI	_SFR_IO_ADDR(PORTC), LED_LE	; 		clr LDE_LE
	POP	r24
	POP	r23
	POP	r22
	POP	r21
	;POP	r20
	POP	r18
	RET
.endfunc

.func read_data
; r22-25 RETURN
; r24 TYPE
read_data:
	PUSH	r18
	PUSH	r19
	;PUSH	r20
	PUSH	r21
	PUSH	r22
	PUSH	r23
	PUSH	r24
	LDI	r18, 24	;
1:						; do {
	IN	r19, _SFR_IO_ADDR(PORTC)	; ret |= PINC&1;
	ANDI	r19, LED_SDI


	SBRS	r23, 0				; 	if (data&1)
	RJMP	2f
	SBI	_SFR_IO_ADDR(PORTC), LED_SDI	; 		set LED_SDI;
	RJMP	3f
2:						; 	else
	CBI	_SFR_IO_ADDR(PORTC), LED_SDI	;		clr LED_SDI;
3:
	ASR	r23				; 	data <<= 1;
	ROR	r22
	ROR	r21
	;ROR	r20								; Don't need?


	CP	r24, r18			; 	if (type == i)
	BRNE	4f
	SBI	_SFR_IO_ADDR(PORTC), LED_LE	; 		set LDE_LE;
4:
	CLOCK_OUT
	DEC	r18				; 	i--;
	BRNE	1b				; } while (i!=0);
	CBI	_SFR_IO_ADDR(PORTC), LED_LE	; 		clr LDE_LE
	POP	r24
	POP	r23
	POP	r22
	POP	r21
	;POP	r20
	POP	r19
	POP	r18
	RET
.endfunc

;TODO: Add reads and NACK bad addresses.
;PARAM (r24) - TWSR
;PWM (r25) - SREG
;DI2C/XL (r26) - Address
.func TWI_vect
TWI_vect:
	PUSH	PARAM
	PUSH	PWM
	PUSH	YL
	PUSH	YH
	PUSH	I2C_OFF
	IN	PWM, _SFR_IO_ADDR(SREG)
	LDS	PARAM, TWSR
	ANDI	PARAM, 0xF8
	LDS	I2C_OFF, i2c_reg
	CPI	PARAM, TW_ST_SLA_ACK		; Slave Receive ACK Address
	BREQ	ltsend
	CPI	PARAM, TW_SR_DATA_ACK		; Slave Receive Data
	BREQ	lreceive
	CPI	PARAM, TW_SR_SLA_ACK		; Slave Receive ACK Address
	BREQ	lrack
	CPI	PARAM, TW_ST_DATA_ACK		; Slave Transmit Data
	BREQ	ltsend
	CPI	PARAM, TW_ST_DATA_NACK
	BREQ	ltdnack
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT) ;ELSE
	RJMP	ldone
lreceive:
	LDS	PARAM, TWDR			; Data
	CPI	I2C_OFF, 193			; if address<=192
	BRLO	lrspixel
	CPI	I2C_OFF, 0xff			; if address==0xff
	BREQ	lrsreg
	CPI	I2C_OFF, I2C_EE_WP
	BREQ	lree
	; NACK here
	RJMP	lrdone				; else...
lree:
	SBI	_SFR_IO_ADDR(PORTB), EE_WP
	CPSE	PARAM, 0
	CBI	_SFR_IO_ADDR(PORTB), EE_WP
	RJMP	lrdone
lrsreg:
	STS	i2c_reg, PARAM			; address = DATA
	RJMP	lrdone
lrspixel:
	LDI	YL, lo8(pixels)
	LDI	YH, hi8(pixels)
	ADD	YL, I2C_OFF
	INC	I2C_OFF
	STS	i2c_reg, I2C_OFF
	CLR	I2C_OFF
	ADC	YH, I2C_OFF
	ST	Y, PARAM
lrdone:
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT)
ldone:
	STS	TWCR, PARAM
	OUT	_SFR_IO_ADDR(SREG), PWM
	POP	I2C_OFF
	POP	YH
	POP	YL
	POP	PWM
	POP	PARAM
	RETI
lrack:
	LDI	PARAM, 0xff		; Address = 0xff
	STS	i2c_reg, PARAM
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT)
	RJMP	ldone
ltdnack:
	RJMP	ltdone
ltsend:
	CPI     I2C_OFF, 193                    ; if address<=192
        BRLO    ltspixel
        CPI     I2C_OFF, I2C_KEYS
        BREQ    ltskeys
        CPI     I2C_OFF, I2C_WAI                ; if address==I2C_WAI
        BREQ    ltswai
        CPI     I2C_OFF, I2C_EE_WP
        BREQ    ltsee
	CPI     I2C_OFF, I2C_VER
        BREQ    ltsver
	LDI	PARAM, 0xff
	STS	TWDR, PARAM
	RJMP	ltdone
ltswai:
        LDI     PARAM, I2C_ID
        STS     TWDR, PARAM
        RJMP    ltdone
ltsver:
        LDI     PARAM, VERSION
        STS     TWDR, PARAM
        RJMP    ltdone
ltskeys:
        CBI     _SFR_IO_ADDR(PORTB), KEYS_INT
        LDS	PARAM, keys
        STS     TWDR, PARAM
	RJMP    ltdone
ltsee:
        LDI     PARAM, 0
        SBIS    _SFR_IO_ADDR(PORTB), EE_WP
        LDI     PARAM, 1
        STS     TWDR, PARAM
        RJMP    ltdone
ltspixel:
        LDI     YL, lo8(pixels)
        LDI     YH, hi8(pixels)
        ADD     YL, I2C_OFF
        INC     I2C_OFF
        STS     i2c_reg, I2C_OFF
        CLR     I2C_OFF
        ADC     YH, I2C_OFF
        LD      I2C_OFF, Y
        STS     TWDR, I2C_OFF
ltdone:
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT)
	RJMP	ldone
.endfunc
