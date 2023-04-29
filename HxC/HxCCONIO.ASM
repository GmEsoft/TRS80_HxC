;
;	HXCCONIO/ASM		;CONIO Routines
;
*MOD
BRK	DEFL	0		;Enable Breakpoints

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

SYSINIT	DI
	LD	A,8EH		;Bring video RAM
	OUT	(84H),A		;
	LD	HL,0F800H
	LD	DE,0F801H
	LD	BC,07FFH
	LD	(HL),' '
	LDIR
	LD	SP,0100H
	LD	HL,0000H
	LD	DE,SYSINIT
	CALL	SETVEC
	LD	DE,RST08
	CALL	SETVEC
	LD	DE,RST10
	CALL	SETVEC
	LD	DE,RST18
	CALL	SETVEC
	LD	DE,RST20
	CALL	SETVEC
	LD	DE,RST28
	CALL	SETVEC
	LD	DE,RST30
	CALL	SETVEC
	LD	DE,RST38
	CALL	SETVEC
	JR	SYSINI1

;------------------------------------------------------------------------------
SETVEC	LD	(HL),0C3H
	INC	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	LD	DE,6
	ADD	HL,DE
	RET

SYSINI1	;$$BREAK
	JP	START

;------------------------------------------------------------------------------
RST08:
RST10:
RST18:
RST20:
RST30:
RST38:
	$$BREAK
	JR	$

;------------------------------------------------------------------------------
RST28:
	PUSH	HL
	LD	HL,TSVCVEC

JVECTOR:
	PUSH	AF
	ADD	A,A
	ADD	A,L
	LD	L,A
	LD	A,H
	ADC	A,0
	LD	H,A
	LD	A,(HL)
	INC	HL
	LD	H,(HL)
	LD	L,A
	POP	AF
	EX	(SP),HL
	RET

TSVCVEC:
	DW	S@IPL,S@KEY,S@DSP,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;00
	DW	S@KBD,S@KEYIN,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,S@VDCTL	;08
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,S@EXIT,NOSVC	;10
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;18
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;20
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;28
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;30
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;38
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;40
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;48
	DW	NOSVC,S@GTDCT,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC	;50
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;58
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;60
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;68
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;70
	DW	NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC,NOSVC		;78

NOSVC:	$$BREAK
	RET

;------------------------------------------------------------------------------
S@DSP:	;$$BREAK			; @DSP - *DO routine
	PUSH	HL
	PUSH	DE
	PUSH	BC

	LD	A,8EH		;Bring video RAM
	OUT	(84H),A		;

	LD	HL,(CURPOS)
	LD	A,(CURCHR)
	LD	(HL),A
	LD	A,C
	CP	20H
	JR	C,S@DSPCT
	LD	(HL),A
	INC	HL

S@DSPX	;Exit *DO, Scroll if needed
	LD	A,H
	CP	0FFH
	JR	C,S@DSPXX
	LD	A,L
	CP	80H
	JR	C,S@DSPXX
	LD	HL,0F850H
	LD	DE,0F800H
	LD	BC,00730H
	LDIR
	PUSH	DE
	LD	H,D
	LD	L,E
	INC	DE
	LD	C,50H
	LD	(HL),' '
	LDIR
	POP	HL
S@DSPXX	LD	A,(HL)		; End *DO routine
	LD	(CURCHR),A
	LD	(HL),'_'
	LD	(CURPOS),HL
	POP	BC
	POP	DE
	POP	HL
	RET

S@DSPCT	PUSH	HL		; Control char
	LD	HL,S@DSPX
	EX	(SP),HL
	PUSH	HL
	LD	HL,TDOCTRL
	JP	JVECTOR

S@DSP08	LD	DE,0F800H
	EX	DE,HL
	OR	A
	SBC	HL,DE
	EX	DE,HL
	LD	A,D
	OR	E
	RET	Z
	DEC	HL
	RET

S@DSP09:			; Tab
	INC	HL
	LD	A,L
	AND	07H
	JR	NZ,S@DSP09
	RET

S@DSP0A:
S@DSP0D	LD	BC,80		; New Line
S@DSPL1	OR	A
	SBC	HL,BC
	LD	A,H
	CP	0F7H
	JR	NZ,S@DSPL1
	ADD	HL,BC
	LD	C,L
	LD	HL,(CURPOS)
	OR	A
	SBC	HL,BC
	LD	C,80
	ADD	HL,BC
	RET

S@DSP1C	LD	HL,0F800H	; Home cursor
S@DSPNI	RET			; Not implemented ctrl char

S@DSP1F	LD	BC,0FF80H	; clear to end of screen
	PUSH	HL
S@DSPCL	LD	(HL),' '
	INC	HL
	LD	A,L
	CP	C
	JR	NZ,S@DSPCL
	LD	A,H
	CP	B
	JR	NZ,S@DSPCL
	POP	HL
	RET


TDOCTRL	DW	S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI	;00
	DW	S@DSP08,S@DSP09,S@DSP0A,S@DSPNI,S@DSPNI,S@DSP0D,S@DSPNI,S@DSPNI	;08
	DW	S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI	;10
	DW	S@DSPNI,S@DSPNI,S@DSPNI,S@DSPNI,S@DSP1C,S@DSPNI,S@DSPNI,S@DSP1F	;18

CURPOS	DW	0F800H
CURCHR	DB	' '

;------------------------------------------------------------------------------

S@VDCTL:			; Video CTL
	PUSH	HL
	PUSH	DE
	PUSH	BC

	LD	A,8EH		;Bring video RAM
	OUT	(84H),A		;

	LD	A,B
	CP	5
	JR	NZ,S@VDCTLX

	LD	DE,0F800H
	LD	BC,00780H
	LDIR

S@VDCTLX:
	POP	BC
	POP	DE
	POP	HL
	RET

;------------------------------------------------------------------------------

S@KEY:				; wait for key press
	;$$BREAK
S@KEY1:	LD	A,@KBD
	RST	28H
	OR	A
	JR	Z,S@KEY1
	RET

;------------------------------------------------------------------------------

S@KBD:				; wait for key press
	PUSH	HL
	PUSH	DE
	PUSH	BC

	LD	A,8EH		;Bring video RAM
	OUT	(84H),A		;

	CALL	KEYF123		;check F1/F2/F3 and translate
	JP	NZ,KBDEXIT	;exit with char in A

	;kbd scan loop 1
LKBSCN1	LD	DE,0F401H	;memory mapped keyboard row 1
	LD	B,00H
	LD	HL,DKIDOWN	;saved keys down
	;kbd scan loop 2
LKBSCN2	LD	A,(DE)
	LD	C,A
	XOR	(HL)
	LD	(HL),C
	AND	C
	JR	NZ,KBDNEWK	;New key down
	INC	B
	INC	HL
	RLC	E
	JP	P,LKBSCN2	;kbd scan loop 2
	LD	A,(DKINEWR)	;new key physical row
	LD	E,A
	LD	A,(DE)
	LD	C,A
	LD	HL,(DKINEWS)	;new key state ptr
	LD	A,(HL)
	AND	C
	JR	NZ,JKBSCN1	;kbd scan jump 1
	SBC	HL,HL
	LD	(DKBDCNT),HL	;key down counter for repeat
	LD	HL,0800H
	LD	(DKBDRPT),HL	;key down repeat delay
	JR	KBDEXIT		;exit with char in A

	;kbd scan jump 1
JKBSCN1	XOR	A
	EX	DE,HL
	LD	HL,(DKBDCNT)	;key down counter for repeat
	INC	HL
	LD	(DKBDCNT),HL	;key down counter for repeat
	LD	BC,(DKBDRPT)	;key down repeat delay
	SBC	HL,BC
	JR	C,KBDEXIT	;exit with char in A
	LD	(DE),A
	LD	(DKBDCNT),HL	;key down counter for repeat
	LD	L,80H
	LD	(DKBDRPT),HL	;key down repeat delay
	JR	LKBSCN1		;kbd scan loop 1

	;New key down
KBDNEWK	LD	C,A
	CALL	KBDDBNC		;keyboard debounce
	JR	Z,KBDEXIT	;exit with char in A
	LD	A,E
	LD	(DKINEWR),A	;new key physical row
	LD	(DKINEWS),HL	;new key state ptr
	SLA	B
	SLA	B
	SLA	B
	DEC	B
	;convert bit order to raw char
LKEYBIT	INC	B
	SRL	C
	JR	NC,LKEYBIT	;convert bit order to raw char


	LD	HL,DKIDWN7	;shift/ctrl/clear/special keys
	LD	A,B
	CP	20H
	JR	NC,KEYSYMB	;not alpha

	BIT	2,(HL)		;CTRL ?
	JR	NZ,KBDEXIT	;exit with char in A
	SET	6,B
	OR	A


	JR	Z,KBDEXTB	;exit with char in B


	LD	A,(DKBDCPS)	;caps lock flag
	OR	A
	JR	NZ,KBDEXTB	;exit with char in B
	SET	5,B
KBDINT2	LD	A,03H		;either SHIFT down ?
	AND	(HL)
	JR	Z,KBDEXTB	;exit with char in B
	LD	A,20H
	XOR	B
	JR	KBDEXIT		;exit with char in A

	;digits and symbols
KEYSYMB:
	;$$BREAK
	SUB	20H
	LD	C,A
	LD	B,00H
	LD	DE,DKBTRAN	;keyboard translation table
	EX	DE,HL
	ADD	HL,BC
	LD	BC,0018H
	LD	A,(DE)
	AND	07H
	JR	Z,KBDXTHL	;exit with char in (HL)
	ADD	HL,BC
	AND	04H
	JR	Z,KBDXTHL	;exit with char in (HL)
	ADD	HL,BC
	;exit with char in (HL)
KBDXTHL	LD	B,(HL)
	;exit with char in B
KBDEXTB	LD	A,B
	;exit with char in A
KBDEXIT	LD	C,A
	LD	A,8FH
	OUT	(84H),A
	LD	A,C
	OR	A

S$KBDX:	POP	BC
	POP	DE
	POP	HL
	RET

	;check F1/F2/F3 and translate
KEYF123	LD	HL,(DKIFNPT)	;function key translate pointer
	LD	A,H
	OR	L
	JR	NZ,KEYFCHR	;get next translated F-key char
	LD	DE,0F47FH	;mem mapped kbd all keys except row 8
	LD	C,E
	LD	A,(DE)
	OR	A
	JR	Z,JKEYFN1	;no non-special key presses
	LD	C,07H
	;no non-special key presses
JKEYFN1	LD	HL,DKIDWN7	;shift/ctrl/clear/special keys
	INC	E
	LD	A,(DE)
	AND	C
	LD	C,A
	XOR	(HL)
	LD	(HL),C
	AND	C
	RET	Z
	LD	C,A
	CALL	KBDDBNC		;keyboard debounce
	RET	Z
	BIT	3,C
	JR	Z,JKEYFN2	;no CAPS
	LD	A,(DKBDCPS)	;caps lock flag
	XOR	01H
	LD	(DKBDCPS),A	;caps lock flag
	;PUSH	BC
	;LD	C,28H
	;CALL	NZ,BEEP		;emit beep with duration in C
	;POP	BC
	;no CAPS
JKEYFN2	LD	A,70H
	AND	C
	RET	Z
	RLCA
	EX	DE,HL
	LD	HL,LEF10
	LD	BC,0009H
	;loop to point to F1-F3 string
LKEYFN1	SBC	HL,BC
	RLCA
	JR	NC,LKEYFN1	;loop to point to F1-F3 string
	LD	C,1BH
	LD	A,(DE)
	AND	03H
	JR	NZ,JKEYFN3	;point to shift-Fn
	LD	A,(DE)
	AND	04H
	JR	Z,KEYFCHR	;get next translated F-key char
	ADD	HL,BC
	;point to shift-Fn
JKEYFN3	ADD	HL,BC
	;get next translated F-key char
KEYFCHR	LD	A,(HL)
	INC	HL
	OR	A
	LD	(DKIFNPT),HL	;function key translate pointer
	RET	NZ
	LD	H,A
	LD	L,A
	LD	(DKIFNPT),HL	;function key translate pointer
	RET

	;keyboard debounce
KBDDBNC	LD	A,0FH
	CALL	DELAY		;delay( A )
	LD	A,(DE)
	AND	C
	RET

	;clear keyboard state
KBDCLR	CALL	FILL0SP		;fill (SP+2) zeros at (SP)

	DW	DKIPEND,0012H

	LD	HL,0800H
	LD	(DKBDRPT),HL	;key down repeat delay
	RET

	;delay( A )
DELAY	PUSH	BC
LED15	LD	B,99H
LED17	DJNZ	LED17
	LD	B,9AH
LED1B	DJNZ	LED1B
	NOP
	DEC	A
	JR	NZ,LED15
	POP	BC
	RET

	;fill (SP+2) zeros at (SP)
FILL0SP	XOR	A
	EX	(SP),HL
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	INC	HL
	LD	C,(HL)
	INC	HL
	LD	B,(HL)
	INC	HL
	EX	(SP),HL
	;fill BC bytes at (DE) with A
FILLA	LD	H,D
	LD	L,E
	LD	(HL),A
	DEC	BC
	LD	A,B
	OR	C
	RET	Z
	INC	DE
	LDIR
	RET

	;pending keyboard char
DKIPEND	DB	00H
	;function key translate pointer
DKIFNPT	DB	00H,00H
	;saved keys down
DKIDOWN	DB	00H,00H,00H,00H,00H,00H,00H
	;shift/ctrl/clear/special keys
DKIDWN7	DB	00H
	;new key physical row
DKINEWR	DB	08H
	;new key state ptr
DKINEWS	DW	DKIDOWN+3
	;key down repeat delay
DKBDRPT	DW	0800H
	;key down counter for repeat
DKBDCNT	DW	0000H
	;caps lock flag
DKBDCPS	DB	00H
	;keyboard transl table      ENT CLR BRK UP  DWN LFT RGT SPC
DKBTRAN	DB	'0123456789:;,-./' ,0DH,18H,80H,0BH,0AH,08H,09H,' ' ;Normal
	DB	'0!"#$%&''()*+<=>?',0DH,1BH,80H,5BH,1AH,18H,19H,' ' ;Shift
	DB	'0|2~4^6`[]:;{_}\' ,0DH,7FH,03H,0BH,0AH,08H,09H,' ' ;Ctrl

	DB	80H,'HELP',0DH ,0,0,0	;F1	HELP
	DB	80H,'FILES',0DH  ,0,0	;F2	FILES
	DB	80H,'HXC',0DH,0,0,0,0	;F3	HXC
LEF10	DB	80H,'CONFIG',0DH   ,0	;Sh-F1	CONFIG
	DB	'_'  ,0,0,0,0,0,0,0,0	;Sh-F2	ZAP prev track
	DB	'.'  ,0,0,0,0,0,0,0,0	;Sh-F3	ZAP next track
	DB	80H,'ZAP',0DH,0,0,0,0	;Ctl-F1	ZAP
	DB	'-'  ,0,0,0,0,0,0,0,0	;Ctl-F2	ZAP prev page
	DB	';'  ,0,0,0,0,0,0,0,0	;Ctl-F3	ZAP next page

;------------------------------------------------------------------------------

S@KEYIN:
	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	E,0
S@KEYIN0:
	LD	A,@KEY
	RST	28H
	CP	80H
	JR	Z,S@KEYINBK
	CP	' '
	JR	C,S@KEYIN1
	LD	C,A
	LD	A,B
	OR	A
	JR	Z,S@KEYIN0
	LD	(HL),C
	INC	HL
	INC	E
	DEC	B
	LD	A,@DSP
	RST	28H
	JR	S@KEYIN0
S@KEYIN1:
	CP	0DH
	JR	NZ,S@KEYIN2
S@KEYINBK:
	LD	D,A
	LD	C,0DH
	LD	A,@DSP
	RST	28H
	XOR	A
	LD	(HL),A
	LD	A,D
	CP	80H
	CCF
	JR	S@KEYINX
S@KEYIN2:
	CP	08H
	JR	NZ,S@KEYIN3
	LD	C,A
	LD	A,E
	OR	A
	JR	Z,S@KEYIN0
	DEC	HL
	DEC	E
	INC	B
	LD	A,@DSP
	RST	28H
	LD	C,' '
	LD	A,@DSP
	RST	28H
	LD	C,08H
	LD	A,@DSP
	RST	28H

	JR	S@KEYIN0
S@KEYIN3:
	JR	S@KEYIN0
S@KEYINX:
	LD	A,E
	POP	BC
	POP	DE
	POP	HL
	LD	B,A
	LD	A,0
	RET

;------------------------------------------------------------------------------

S@EXIT:				;SVC @EXIT (16H) - exit to DOS
	DB	0EDH,0F6H
	JR	S@IPL		;IPL if $EXIT not implemented in emulator

;------------------------------------------------------------------------------

S@IPL:				;SVC @IPL (00H) - Reboot the system
	LD	HL,SIPL01
	LD	DE,04000H
	LD	BC,SIPL02-SIPL01
	PUSH	DE
	LDIR
	RET
SIPL01	XOR	A
	OUT	(84H),A		;Toggle in Model III boot ROM
	INC	A
	OUT	(9CH),A		;Toggle in Model 4P boot ROM
	RST	0		;Reboot
SIPL02	EQU	$


;------------------------------------------------------------------------------

S@GTDCT:
	LD	IY,TDCT
	RET

TDCT	DB	0C3H		;active if C3, inactive if C9
	DW	$-$		;driver address
	DB	0		;flags (b3=hard drive)
	DB	1		;Physical host drive
	DB	0		;current track

;------------------------------------------------------------------------------

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END
