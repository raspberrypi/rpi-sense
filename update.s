#include "avr/io.h"
#include <util/twi.h>

LINE	= 24
PARAM	= 24
PWM	= 25
DI2C	= 26	; XL


; PORTB
.equiv ROE_N	, PB0
.equiv GOE_N	, PB1
.equiv BOE_N	, PB2
.equiv OE_N	, (1 << ROE_N) | (1 << GOE_N) | (1 << BOE_N)
.equiv SDO	, PB3
.equiv SDI	, PB4 
.equiv CLOCK	, PB5
.equiv LE	, PB6

; PORTC
.equiv LINE_INT		, PC0
.equiv FRAME_INT	, PC1
.equiv SDA		, PC4
.equiv SCL		, PC5

.macro CLOCK_OUT
	SBI	_SFR_IO_ADDR(PORTB), CLOCK
	CBI	_SFR_IO_ADDR(PORTB), CLOCK
.endm

.macro COL_OUT reg
	CP	PWM, \reg
	BRSH	Lclear\reg
	SBI	_SFR_IO_ADDR(PORTB), SDO
	RJMP	Ldone\reg
Lclear\reg:
	CBI	_SFR_IO_ADDR(PORTB), SDO
Ldone\reg:
	CLOCK_OUT
.endm

.global draw_loop
.global clear_gain
.global delay
.global TWI_vect

.extern delay

.func draw_loop
draw_loop:
	MOVW	ZL, PARAM
Lframe_loop:
	CBI	_SFR_IO_ADDR(PORTC), FRAME_INT
	MOVW	YL, ZL
	LDI	LINE, 1
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
	SBI	_SFR_IO_ADDR(PORTB), LE
	COL_OUT	r22
	COL_OUT	r23
	CBI	_SFR_IO_ADDR(PORTB), LE
	INC	PWM
	SBRS	PWM, 6
	RJMP	Lpwm_loop
	LSL	LINE
	BRCS	lframeend
	RJMP	Lline_loop
lframeend:
	SBI	_SFR_IO_ADDR(PORTC), FRAME_INT
	CBI	_SFR_IO_ADDR(PORTD), 7		; Clear PORTD
	;LDI	PARAM, 255			; 5e-3/(8e6/256)^-1 = 156
	;RCALL	delay
	//disable RGB/OE (portb 0-2)
	LDI	PARAM, 7			; TODO: Scan keys
	OUT	_SFR_IO_ADDR(PORTB), PARAM
	CBI	_SFR_IO_ADDR(DDRD), 7 
	SBI	_SFR_IO_ADDR(PIND), 7
	NOP
	NOP
	NOP
	NOP
	CBI	_SFR_IO_ADDR(PIND), 7
	SBI	_SFR_IO_ADDR(DDRD), 7
	LDI	PARAM, 0
	OUT	_SFR_IO_ADDR(PORTB), PARAM	;/Scan
	RJMP	Lframe_loop
	RET
.endfunc

.func delay
delay:
	PUSH	r19
	PUSH	r20
	IN	r20, _SFR_IO_ADDR(TCNT0)	; start = TCNT0;
Lloop:
	IN	r19, _SFR_IO_ADDR(TCNT0)	; do {
	SUB	r19, r20			; diff = TCNT0 - start;
	CP	r19, LINE			; } while (diff < ticks);
	BRLO	Lloop
	POP	r20
	POP	r19
	RET
 .endfunc

 ;TODO: Make this a generic read/write function
.func clear_gain
clear_gain:
	CBI	_SFR_IO_ADDR(PORTB), SDO
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	SBI	_SFR_IO_ADDR(PORTB), LE
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CLOCK_OUT
	CBI	_SFR_IO_ADDR(PORTB), LE
	RET
.endfunc

;TODO: Add reads and check ranges.
.func TWI_vect
TWI_vect:
	PUSH	PARAM
	PUSH	PWM
	IN	PWM, _SFR_IO_ADDR(SREG)
	LDS	PARAM, TWSR
	ANDI	PARAM, 0xF8
	CPI	PARAM, TW_SR_DATA_ACK		; Slave Receive Data
	BREQ	lreceive
	CPI	PARAM, TW_ST_DATA_ACK		; Slave Transmit Data
	BREQ	lsend
	CPI	PARAM, TW_SR_SLA_ACK		; Slave ACK Address
	BREQ	lack
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT) ;ELSE
	RJMP	ldone
lreceive:
	LDS	PARAM, TWDR	; Data
	ST	X+, PARAM
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT)
ldone:	
	STS	TWCR, PARAM
	OUT	_SFR_IO_ADDR(SREG), PWM
	POP	PWM
	POP	PARAM
	RETI
lack:
	MOVW	DI2C, ZL
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT)
	RJMP	ldone
lsend:
	LD	PARAM, X+
	STS	TWSR, PARAM
	LDI	PARAM,  (1<<TWEA) | (1<<TWEN) | (1<<TWIE) | (1<<TWINT)
	RJMP	ldone
.endfunc