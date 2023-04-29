;======	DISPLAY BUFFER ROUTINES ============================
;
;	PUTHEX			Put  A as hex in disp buffer @ IY
;	PUTCHR			Put char to disp buffer @ IY
;	PUTHEX4			Put 4 bytes @ HL to disp buffer @ IY
;	PUTMSG			Put message @ HL to disp buffer @ IY
;	PUTMPC			Put message @ PC to disp buffer @IY
;	FMT			Get sector display format (0-3) (ascii bytes)
;	FMTA			Format ASCII bytes
;	PUTPAG			Put sector bytes @ HL to disp buffer @ IY
;	DECHL			Get decimal value from KI into HL
;	PUTDSP			Put disp buffer on screen
;	BUFCLS			Clear Screen
;
;	BUFPUTCHRB		Put one char in disp buffer @IY
;	BUFREVERSE		Set buffer reverse mode
;	BUFNORMAL		Set buffer normal mode
;	BUFREVZ			Set Reverse Display if A=0
;	BUFCLRLINE		Clear line @IY
;	BUFCENTER		Clear line and center message in disp buffer @IY
;	BUFRIGHT		Right-justify message in disp buffer line @IY
;	BUFLEFT			Left-justify message in disp buffer line @IY
;	BUFMSG			Put message in disp buffer @IY
;	BUFDECA			Put A in decimal in disp buffer @IY

*MOD

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

;	MLIST	ON

	DB	' HxCDisp>'

;======	DISPLAY BUFFER ROUTINES =================

;-----	Put  A as hex in disp buffer @ IY
PUTHEX:	PUSH	AF
	SRL	A
	SRL	A
	SRL	A
	SRL	A
	CALL	ADJHEX
	POP	AF
	AND	0FH
ADJHEX:	ADD	A,30H
	CP	3AH
	JR	C,PUTCHR
	ADD	A,7

;-----	Put char to disp buffer @ IY
PUTCHR:	LD	(IY+0),A
	INC	IY
	RET

;-----	Put Y/N to disp buffer @ IY (Y if A==0, N if A!=0)
PUTYN:	OR	A
	LD	A,'Y'
	JR	Z,PUTCHR
	LD	A,'N'
	JR	PUTCHR

;-----	Put 4 bytes @ HL to disp buffer @ IY
PUTHEX4:
	PUSH	BC
	LD	BC,4
	ADD	HL,BC
	LD	B,C
PHEX41:	DEC	HL
	LD	A,(HL)
	CALL	PUTHEX
	DJNZ	PHEX41
	POP	BC
	RET

;-----	Put message @ HL to disp buffer @ IY
PUTMSG:	LD	A,(HL)
	INC	HL
	OR	A
	RET	Z
	CP	3
	RET	Z
	CALL	PUTCHR
	CP	0DH
	RET	Z
	JR	PUTMSG

;-----	Put message @ PC to disp buffer @IY
PUTMPC:	EX	(SP),HL
	CALL	PUTMSG
	EX	(SP),HL
	RET

;-----	Get sector display format (0-3) (ascii bytes)
FMT:	CALL	WAITKI
	CP	'0'
	JP	C,FMT
	CP	'4'
	JP	NC,FMT
	CALL	DDISA
	LD	HL,FMT0
	CP	'0'		;'0' = display all bytes verbatim
	JR	Z,XFMT
	LD	HL,FMT1
	CP	'1'		;'1' = display printable chars only
	JR	Z,XFMT
	LD	HL,FMT2
	CP	'2'		;'2' = display printable and graphics chars
	JR	Z,XFMT
	LD	HL,FMT3		;'3' = display printable chars in 7-bit ascii
XFMT:	LD	(FMTA+1),HL
	RET

;-----	Format ASCII bytes
FMTA:	JP	FMT1		;vector

FMT0:	RET			;no change

FMT3:	AND	7FH		;change to 7-bit ascii, non-printable chars to '.'

FMT1:	CP	80H		;graphics and non-printable chars to '.'
	JR	NC,FMTP

FMT2:	CP	20H		;non-printable chars to '.'
	RET	NC

FMTP:	LD	A,'.'
	RET

;-----	Put sector bytes @ HL to disp buffer @ IY
PUTPAG:	LD	BC,1000H
BDISP0:	PUSH	BC
	PUSH	IY
	IF	DBG
	LD	A,H
	CALL	PUTHEX
	LD	A,L
	CALL	PUTHEX
	ELSE
	LD	A,C
	CALL	PUTHEX
	ENDIF
	INC	IY
	INC	IY
	LD	B,8
	PUSH	HL
BDISP1:	LD	A,(HL)
	INC	HL
	CALL	PUTHEX
	LD	A,(HL)
	INC	HL
	CALL	PUTHEX
	INC	IY
	DJNZ	BDISP1
	POP	HL
	LD	B,10H
BDISP2:	LD	A,(HL)
	INC	HL
	CALL	FMTA
	CALL	PUTCHR
	DJNZ	BDISP2
	POP	IY
	LD	BC,80
	ADD	IY,BC
	POP	BC
	LD	A,C
	ADD	A,10H
	LD	C,A
	DJNZ	BDISP0
	RET

;-----	Get decimal value from KI into HL
DECHL	LD	HL,0
DECHL0	CALL	WAITKI
	CP	0DH
	RET	Z
	CP	'9'+1
	JR	NC,DECHLX
	CP	'0'
	JR	C,DECHLX
	CALL	DDISA
	SUB	'0'
	LD	E,A
	LD	D,0
	LD	B,H
	LD	C,L
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,BC
	ADD	HL,HL
	ADD	HL,DE
	JR	DECHL0
DECHLX	LD	H,255
	RET

;-----	Put disp buffer on screen
PUTDSP:	PUSH	HL
	PUSH	BC
	LD	HL,DSPBUF
	LD	B,5		;Buffer To Video
	$SVC	@VDCTL
	POP	BC
	POP	HL
	RET

;-----	Clear Screen
BUFCLS:
;	CALL	01C9H
	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	HL,DSPBUF
	LD	DE,DSPBUF+1
	LD	BC,24*80-1
	LD	(HL),' '
	LDIR
	POP	BC
	POP	DE
	POP	HL
	RET

;======	DISPLAY BUFFER ROUTINES WITH REVERSE MODE ======


;-----	Put one char in disp buffer @IY
BUFPUTCHRB:	; with decrementing B
	DEC	B
	JR	NZ,BUFPUTCHR
	INC	B
	RET
BUFPUTCHR:	; without decrementing B
	OR	0
BUFREVFLAG EQU	$-1
	JP	PUTCHR

;-----	Set buffer reverse mode
BUFREVERSE:
	PUSH	HL
	LD	HL,BUFREVFLAG
	SET	7,(HL)
	POP	HL
	RET

;-----	Set buffer normal mode
BUFNORMAL:
	PUSH	HL
	LD	HL,BUFREVFLAG
	RES	7,(HL)
	POP	HL
	RET

;-----	Set Reverse Display if A=0
BUFREVZ:
	SUB	1
	SBC	A,A
	AND	80H
	LD	(BUFREVFLAG),A
	RET

;-----	Clear line @IY
BUFCLRLINE:
	PUSH	IY
	PUSH	BC
	LD	B,80
	LD	A,' '
BUFCLN1	CALL	BUFPUTCHR
	DJNZ	BUFCLN1
	POP	BC
	POP	IY
	RET

;-----	Clear line and center message in disp buffer @IY
BUFCENTER:
	PUSH	BC
	PUSH	DE
	LD	DE,80

BUFC1	PUSH	HL
	LD	BC,0
BUFC2	LD	A,(HL)
	INC	HL
	INC	C
	CP	' '
	JR	NC,BUFC2
	POP	HL

	SRL	C
	LD	A,40
	SUB	C
	LD	C,A
	CALL	BUFCLRLINE

	PUSH	IY
	ADD	IY,BC
BUFC4	LD	A,(HL)
	INC	HL
	CP	' '
	JR	C,BUFC5
	CALL	BUFPUTCHR
	JR	BUFC4
BUFC5	OR	A
	JR	Z,BUFC6
	CP	3
	JR	Z,BUFC6
	CP	0DH
	JR	NZ,BUFC4
BUFC6	POP	IY

	ADD	IY,DE
	CP	0DH
	JR	Z,BUFC1

	POP	DE
	POP	BC
	RET

;-----	Right-justify message in disp buffer line @IY
BUFRIGHT:
	PUSH	BC

	PUSH	HL
	LD	BC,00FFH
BUFR2	LD	A,(HL)
	INC	HL
	INC	C
	CP	' '
	JR	NC,BUFR2
	POP	HL

	LD	A,80
	SUB	C
	LD	C,A

	PUSH	IY
	ADD	IY,BC
BUFR4	LD	A,(HL)
	INC	HL
	CP	' '
	JR	C,BUFR6
	CALL	BUFPUTCHR
	JR	BUFR4
BUFR6	POP	IY

	POP	BC
	RET

;-----	Left-justify message in disp buffer line @IY
BUFLEFT:
	PUSH	IY
	CALL	BUFMSG
	POP	IY
	RET

;-----	Put message in disp buffer @IY
BUFMSG:
BUFL4	LD	A,(HL)
	INC	HL
	CP	' '
	RET	C
	CALL	BUFPUTCHR
	JR	BUFL4

;-----	Put A in decimal in disp buffer @IY (2 digits)
BUFDECA2:
	PUSH	AF
	PUSH	HL
	LD	HL,BUFDCA1+1
	LD	(HL),' '
	JR	BUFDCA0

;-----	Put A in decimal in disp buffer @IY (3 digits)
BUFDECA:
;	$$BREAK
	PUSH	AF
	PUSH	HL
	LD	HL,BUFDCA1+1
	LD	(HL),' '
	LD	H,100
	CALL	BUFDCA1
BUFDCA0:
	LD	H,10
	CALL	BUFDCA1
	LD	H,1
	CALL	BUFDCA1
	POP	HL
	POP	AF
	RET

BUFDCA1:
	LD	L,' '
	DEC	L
BUFDCA11:
	SUB	H
	INC	L
	JR	NC,BUFDCA11
	ADD	A,H
	PUSH	AF
	LD	A,L
	CP	' '
	JR	Z,BUFDCA12
	LD	A,'0'
	LD	(BUFDCA1+1),A
	OR	L
BUFDCA12:
	CALL	BUFPUTCHR
	POP	AF
	RET



;======	DATA SEG ======

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA segment

;	DB	' HxCDisp:'

;-----	Screen Buffer

DSPBUF:	DS	800H

	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END
