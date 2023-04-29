;
;	HXCSYS/ASM	System routines
;
;	DDISA		Display char in A
;	DISM		Display message @ HL
;	DISMB		Display B chars @ HL
;	CLS		Clear Screen
;	DISDA		Display A in dec
;	DHEXA		Display A in hex
;	DHEX4		DIsplay 4 bytes in hex
;	DISMPC		Display message @ PC
;
;	GETKEY		Poll keyboard - Handle Break, Ctrl-C and Ctrl-S
;	VBREAK		Break Vector (<Break> key)
;	VABORT		Abort Vector (Ctrl-C)
;	WAITKI		Wait 1 character from keyboard
;	POSTKI		Post 1 character to be read by WAITKI
;
;	DOSEXIT		Exit to DOS
;
;	STO32		Store 32b from (HL) to (DE)
;	MOV32		Move 32b from (DE) to (HL)
;	ADD32		Add 32 @ HL by 32 @ DE
;	DEC32		Decrement 32 @ HL
;	INC32		Increment 32 @ HL
;	SUB32		Sub 32 @ HL by 32 @ DE
;	SUB328		Sub 32 @ HL by 8 bits
;	MUL328		Multiply 32 @ HL by 8
;	SHL32		Left shift 32b @HL by A
;	SHR32		Right shift 32b @HL by A
;	ZERO32		Zero 32b @ HL
;	ISNUL32		Test if null 32b @ HL
;	CMP32		Compare 32b @ HL with 32b @ DE
;	MEMCMP		Compare byte arrays
;	MEMCPY		Copy byte array
;	CPHLDE		CP HL,DE

*MOD
BRK	DEFL	0		;Enable Breakpoints

KIDO	DEFL	0

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

	$MSG	HxCSYS
SYS_BEGIN:

;======	SYSTEM CALL ROUTINES ====================

;-----	Display char in A
DDISA:

	PUSH	AF
	PUSH	DE
	PUSH	BC

	IF	INCBOOT
	; do nothing
	ELSE

	; Fix for missing <TAB> handling by *DO in LS-DOS 6
	CP	9		; <TAB> ?
	JR	NZ,$?DDAN09

	PUSH	HL		; Save HL
	LD	B,4		; Obtain video cursor position
	$SVC	@VDCTL		;
	LD	A,L		; Horizontal pos
	CPL			; calculate number of blank spaces
	AND	7		; to emit
	INC	A		;
	LD	B,A		;
	LD	C,' '		; blank space
$?DDA09A:
	$SVC	@DSP		; emit them
	DJNZ	$?DDA09A	;
	POP	HL		; restore HL

	JR	$?DDARET
$?DDAN09:

	ENDIF

	LD	C,A		; character to send to *DO
	$SVC	@DSP		; display it
$?DDARET:
	POP	BC
	POP	DE
	POP	AF

	RET


;-----	Display message @ HL
DISM:	;LD	A,0BFH
	;CALL	DDISA
$?DISM:	LD	A,(HL)
	INC	HL
	OR	A
	RET	Z
	CP	3
	RET	Z
	CALL	DDISA
	CP	0DH
	RET	Z
	JR	$?DISM

;-----	Display B chars @ HL
DISMB:	;LD	A,0BFH
	;CALL	DDISA
$?DSMB:	LD	A,(HL)
	INC	HL
	OR	A
	RET	Z
	CP	3
	RET	Z
	CALL	DDISA
	CP	0DH
	RET	Z
	DJNZ	$?DISM
	RET

;================================================
	IF	TER
;================================================

;-----	Clear Screen
CLS:
	LD	A,1CH
	CALL	DDISA
	LD	A,1FH
	CALL	DDISA
	RET

;-----	Display A in dec
DISDA:	PUSH	AF
	PUSH	BC
	NOP			;skip reloc
	LD	BC,100<8+'0'-1
	CALL	BDISDA1
	NOP			;skip reloc
	LD	BC,10<8+'0'-1
	CALL	BDISDA1
	NOP			;skip reloc
	LD	BC,1<8+'0'-1
	CALL	BDISDA1
	POP	BC
	POP	AF
	RET

BDISDA1	SUB	B
	INC	C
	JR	NC,BDISDA1
	ADD	A,B
	PUSH	AF
	LD	A,C
	CALL	DDISA
	POP	AF
	RET

;-----	Display A in hex
DHEXA:	PUSH	AF
	SRL	A
	SRL	A
	SRL	A
	SRL	A
	CALL	ADJHA
	POP	AF
	AND	0FH
ADJHA:	ADD	A,30H
	CP	3AH
	JR	C,DCHRA
	ADD	A,7

;-----	Put char to disp buffer @ IY
DCHRA:	JP	DDISA

;-----	Put 4 bytes @ HL to disp buffer @ IY
DHEX4:
	PUSH	AF
	LD	A,'['
	CALL	DDISA
	PUSH	BC
	LD	BC,4
	ADD	HL,BC
	LD	B,C
DHEX41:	DEC	HL
	LD	A,(HL)
	CALL	DHEXA
	DJNZ	DHEX41
	POP	BC
	LD	A,']'
	CALL	DDISA
	POP	AF
	RET


;-----	Display trace message @ PC
DISTRC:	EX	(SP),HL
	INC	HL
	JR	$DISPC

;-----	Display message @ PC
DISMPC:	EX	(SP),HL
$DISPC:	PUSH	AF
	CALL	DISM
	POP	AF
	EX	(SP),HL
	RET

;-----	Poll keyboard - Handle Break, Ctrl-C and Ctrl-S
GETKEY:
	$SVC	@KBD
	CP	'S'-40H
	JR	Z,WAITKI
	CP	80H		;Break
	JR	Z,VBREAK
	CP	3		;Ctrl-C = abort
	JR	Z,VABORT
	OR	A
VRET:	RET

;-----	Break Vector
VBREAK:	JP	VRET

;-----	Abort Vector
VABORT:	JP	VRET

;-----	Wait 1 character from keyboard
WAITKI:	;$$BREAK
	PUSH	BC
	LD	C,0
XNEXTKI	EQU	$-1
	XOR	A
	LD	(XNEXTKI),A
	LD	A,C
	OR	A
	JR	NZ,WAITK1
	$SVC	@KEY
WAITK1:	CP	80H		;Break
	JR	Z,VBREAK
	CP	3		;Ctrl-C = abort
	JR	Z,VABORT
	POP	BC
	OR	A
	RET

;-----	Post 1 character to be read by WAITKI
POSTKI:	LD	(XNEXTKI),A
	RET

;-----	Exit to DOS
DOSEXIT:
	$SVC	@EXIT

;================================================
	ENDIF
;================================================

;-----	Compare 32b @ HL with 32b @ DE
;	IN	HL = dword ptr 1
;		DE = dword ptr 2
;	OUT	A == 0 if (HL)==(DE)
;		Z == (HL)==(DE)
;		CF == (HL)<(DE)
CMP32:
	PUSH	HL
	PUSH	DE
	PUSH	BC
	EX	DE,HL
	INC	HL
	INC	DE
	INC	HL
	INC	DE
	INC	HL
	INC	DE
	LD	B,4
BC320:	LD	A,(DE)
	CP	(HL)
	JR	NZ,BC32X
	DEC	HL
	DEC	DE
	DJNZ	BC320
BC32X:
	JR	POPBDHRET

;-----	Store 32b from (HL) to (DE)
STO32:	PUSH	HL
	PUSH	DE
	JR	BMV321

;-----	Move 32b from (DE) to (HL)
;	(HL) := (DE)
;
MOV32:	PUSH	HL
	PUSH	DE
	EX	DE,HL
BMV321:	PUSH	BC
	LD	BC,4
	LDIR
	JR	POPBDHRET

;
;
;-----	Add 32 @ HL by 32 @ DE
;	IN	HL = addend ptr (32b)
;		DE = adder ptr (32b)
;	USED	A
ADD32:	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	B,4
	OR	A
BA320:	LD	A,(HL)
	EX	DE,HL
	ADC	A,(HL)
	INC	HL
	EX	DE,HL
	LD	(HL),A
	INC	HL
	DJNZ	BA320
	JR	POPBDHRET
;
;
;-----	Decrement 32 @ HL
;	IN	HL = dword ptr (32b)
;	USED	A
DEC32:	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	BC,-1
	LD	A,2
	OR	A
BD320:	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	DEC	HL
	EX	DE,HL
	ADC	HL,BC
	EX	DE,HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	DEC	A
	JR	NZ,BD320
	JR	POPBDHRET
;
;
;-----	Increment 32 @ HL
;	IN	HL = dword ptr (32b)
;	USED	A
INC32:	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	BC,1
	LD	A,2
	OR	A
BI320:	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	DEC	HL
	EX	DE,HL
	ADC	HL,BC
	EX	DE,HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	DEC	C
	DEC	A
	JR	NZ,BI320
	JR	POPBDHRET
;
;
;-----	Sub 32 @ HL by 32 @ DE
;	IN	HL = subtrahend ptr (32b)
;		DE = subtractor ptr (32b)
;	USED	A
SUB32:	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	B,4
	OR	A
BS320:	LD	A,(HL)
	EX	DE,HL
	SBC	A,(HL)
	INC	HL
	EX	DE,HL
	LD	(HL),A
	INC	HL
	DJNZ	BS320
POPBDHRET:
	POP	BC
	POP	DE
	POP	HL
	RET
;
;
;-----	Sub 32 @ HL by 8
;	IN	HL = subtrahend ptr (32b)
;		A = subtractor (8b)
;	USED	A
SUB328:	PUSH	HL
	PUSH	BC
	LD	B,A
	LD	A,(HL)
	SUB	B
	LD	(HL),A
	INC	HL
	NOP			;skip reloc
	LD	BC,0300H
BS3280:	LD	A,(HL)
	SBC	A,C
	LD	(HL),A
	INC	HL
	DJNZ	BS3280
	POP	BC
	POP	HL
;
;
;-----	Multiply 32 @ HL by 8
;	IN	HL = multiplicand ptr (32b)
;		A = multiplicator (8b)
;	USED	A
MUL328:	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	DE,0
	LD	B,D
	LD	C,E
	LD	H,A
	LD	L,8
BM3280:	OR	A
	RL	E
	RL	D
	RL	C
	RL	B
	RL	H
	JR	NC,BM3281
	EX	(SP),HL
	LD	A,(HL)
	ADD	A,E
	LD	E,A
	INC	HL
	LD	A,(HL)
	ADC	A,D
	LD	D,A
	INC	HL
	LD	A,(HL)
	ADC	A,C
	LD	C,A
	INC	HL
	LD	A,(HL)
	ADC	A,B
	LD	B,A
	DEC	HL
	DEC	HL
	DEC	HL
	EX	(SP),HL
BM3281:	DEC	L
	JR	NZ,BM3280
	POP	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	LD	(HL),C
	INC	HL
	LD	(HL),B
	DEC	HL
	DEC	HL
	DEC	HL
	POP	DE
	POP	BC
	RET


;-----	Left shift 32b @HL by A
;	IN;	HL = shiftand
;		A = shiftor
SHL32:
BSL320:	OR	A	;also clr CF
	RET	Z
	RL	(HL)
	INC	HL
	RL	(HL)
	INC	HL
	RL	(HL)
	INC	HL
	RL	(HL)
	DEC	HL
	DEC	HL
	DEC	HL
	DEC	A
	JR	BSL320

;-----	Right shift 32b @HL by A
;	IN;	HL = shiftand
;		A = shiftor
SHR32:
BSR320:	OR	A	;also clr CF
	RET	Z
	INC	HL
	INC	HL
	INC	HL
	RR	(HL)
	DEC	HL
	RR	(HL)
	DEC	HL
	RR	(HL)
	DEC	HL
	RR	(HL)
	DEC	A
	JR	BSR320

;-----	Zero 32b @ HL
ZERO32:
	XOR	A
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	DEC	HL
	DEC	HL
	DEC	HL
	RET


;-----	Test if null 32b @ HL
;	IN	HL = dword ptr
;	OUT	A == 0 if null
;		Z == 1 if null
ISNUL32:
	LD	A,(HL)
	INC	HL
	OR	(HL)
	INC	HL
	OR	(HL)
	INC	HL
	OR	(HL)
	DEC	HL
	DEC	HL
	DEC	HL
	RET

;-----	Compare byte arrays
;	IN:	HL = array1
;		DE = array2
;		BC = bytes count
;	OUT:	Z = array1 == array2
;		C = array1 < array2
;	USED:	A,BC
MEMCMP:	PUSH	HL
	PUSH	DE
	EX	DE,HL
BMCMP1:	LD	A,(DE)
	SUB	(HL)
	JR	NZ,BMCMPX
	INC	DE
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,BMCMP1
BMCMPX:	POP	DE
	POP	HL
	RET

;-----	Copy byte array
;	IN:	HL = source
;		DE = dest
;		BC = bytes count
;	USED:	BC
MEMCPY:	PUSH	HL
	PUSH	DE
	LDIR
	POP	DE
	POP	HL
	RET

;-----	CP HL,DE
CPHLDE:	LD	A,H
	CP	D
	RET	NZ
	LD	A,L
	CP	E
	RET

SYS_END:
	$MSG	/HxCSYS

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$RELO	; RELO segment

CSEG_SYS 	MACRO
	DW	SYS_BEGIN,SYS_END
	ENDM

	ENDIF			; RELO segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END
