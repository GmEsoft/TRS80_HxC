;
;	HXCBrow/ASM	Array Browser
;

*MOD

BRK	DEFL	0		; Enable Breakpoints
TRC	DEFL	0		; trace

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

;=====	Force CLS on ret/break
;	SP must be at the call level of the subroutine !
PUSHCLS:			; >RET0
	;$$BREAK
	LD	(PCLS$SP),SP	; save RET0
	PUSH	HL		; RET0	>HL0

	INC	SP
	INC	SP		; >RET0	HL0
	LD	HL,(VBREAK+1)
	EX	(SP),HL		; >VBK0	HL0	& HL=RET0

	DEC	SP
	DEC	SP		; VBK0	>HL0
	PUSH	HL		; VBK0	HL0	>RET0
	INC	SP
	INC	SP		; VBK0	>HL0	RET0

	LD	HL,PCLS$BREAK	; VBK1 = new VBREAK
	LD	(VBREAK+1),HL
	LD	HL,PCLS$RET	; RET1 = new return address
	EX	(SP),HL		; VBK0	>RET1	RET0
	DEC	SP
	DEC	SP
				; Stack now:
				; SP	RET0	orig ret
				; SP+2	RET1	new ret
				; SP+4	VBK0	old vbreak
				; SP+6		orig caller

	RET			; RET-4


PCLS$BREAK:
	OR	A		; NZ with A=0 indicates <Break>
	LD	A,0		; No error code
PCLS$RET:
	;$$BREAK
	PUSH	AF
	CALL	CLS
	POP	AF
	LD	SP,$-$
PCLS$SP	EQU	$-2
	EX	(SP),HL
	LD	(VBREAK+1),HL
	POP	HL
	RET




;=====	One-time splash screen
SPLASH:
	LD	A,0C9H		; Display only once
	LD	(SPLASH),A	; then return directly
	CALL	BROWSCREEN
	LD	IY,3*80+DSPBUF
	LD	HL,MSELTIT
	CALL	BUFCENTER
	CALL	PUTDSP
	CALL	WAITKI
	RET

;=====	Set browser screen
BROWSCREEN:
	CALL	CLS		; clear screen
	LD	A,10H		; Enable reverse mode
	CALL	DDISA		;

	CALL	BUFCLS

	LD	IY,23*80+DSPBUF
	PUSH	IY
	CALL	BUFREVERSE
	CALL	BUFCLRLINE
	LD	HL,MSELVER	; Selector version
	CALL	BUFCENTER
	POP	IY
	LD	HL,MCOPYRT	; Copyright
	CALL	BUFRIGHT
	LD	HL,MFIRMW	; Firmware
	CALL	BUFMSG
	LD	B,12
	LD	HL,XHSFWV	; Firmware version
BROWFWV	LD	A,(HL)
	OR	A
	JR	Z,BROWPWD
	CALL	BUFPUTCHR
	INC	HL
	DJNZ	BROWFWV
BROWPWD:			; Display current dir
	CALL	BUFREVERSE
	LD	IY,DSPBUF
	CALL	BUFCLRLINE
	LD	HL,MCURFLD	; Current folder:
	CALL	BUFMSG
	LD	HL,XPWD		; Current dir
	CALL	BUFMSG
	CALL	BUFNORMAL

	RET

;=====	Browse files
;	IN	C	Number of items
BROWLINES	EQU	20
BROWLINE1	EQU	2
BROWCOLS	EQU	60
BROWCOL1	EQU	-BROWCOLS/2+40

;-----	Browser
BROWSE:
	DEC	C
	INC	C
	SCF
	RET	Z		; abort if list is empty

;	EXX
;	CALL	BROWSCREEN
;	LD	IY,DSPBUF+80
;	LD	HL,MMEDFLS	; SDCard Media Files
;BROWFLS	EQU	$-2
;	CALL	BUFCENTER
;	EXX

BBROWDSPR:
	; D=1st displayed file, E=Cur file
	; E = min( E, C-1 )
	LD	A,E
	CP	C
	JR	C,$?BBR1

	LD	E,C
	DEC	E

$?BBR1:
	LD	A,D
	CP	E
	LD	D,E
	JR	NC,BBROWDSPA

	LD	D,A
	LD	A,E
	SUB	BROWLINES-1
	LD	B,A
	LD	A,D
	LD	D,0
	JR	C,BBROWDSPA
	LD	D,A
	CP	B
	JR	NC,BBROWDSPA
	LD	D,B

BBROWDSPA:
	CALL	BROWDSPALL

BBROWDSP:
	PUSH	BC
	PUSH	DE
	CALL	PUTDSP
	CALL	WAITKI
	POP	DE
	POP	BC

	CP	0BH		; UP
	JR	NZ,BBROWN0B

	LD	A,E
	OR	A
	JR	Z,BBROWDSP
	DEC	E
	DEC	D
	LD	A,E
	SUB	D
	JR	Z,BBROWDSPA
	INC	D
	DEC	B
	JR	BBROWDSPA

BBROWN0B:
	CP	0AH		; DOWN
	JR	NZ,BBROWN0A

	LD	A,E
	INC	A
	CP	C
	JR	Z,BBROWDSP
	INC	E
	INC	D
	LD	A,E
	SUB	D
	CP	BROWLINES-1
	JR	Z,BBROWDSPA
	DEC	D
	INC	B
	JR	BBROWDSPA

BBROWN0A:
	CP	5BH		; Sh-UP
	JR	Z,BBROW08
	CP	08H		; LEFT
	JR	NZ,BBROWN08

BBROW08:
	LD	A,E
	SUB	BROWLINES
	LD	E,A
	JR	NC,BBROW08A
	LD	E,0

BBROW08A:
	LD	A,D
	SUB	BROWLINES
	LD	D,A
	JR	NC,BBROWDSPA
	LD	D,0

	JR	BBROWDSPA

BBROWN08:
	CP	1AH		; Sh-DOWN
	JR	Z,BBROW09
	CP	09H		; RIGHT
	JR	NZ,BBROWN09

BBROW09:
	LD	B,E		; B = E

	LD	E,C		; E = lines - 1
	DEC	E		;

	LD	A,C		; A = lines - 1 - height
	DEC	A		;
	SUB	BROWLINES	;
	JR	C,BBROWDSPR	; if A < 0 continue

	LD	A,B		; B += lines
	ADD	A,BROWLINES	;
	LD	B,A		;
	SUB	C		; B < C ?
	JR	NC,BBROWDSPR	; if yes continue

	LD	E,B		; E = B

	LD	A,D		; D += lines
	ADD	A,BROWLINES	;
	LD	D,A		;

	ADD	A,BROWLINES	; A = D + lines - C
	SUB	C		;

	JP	C,BBROWDSPR	; if A < 0 continue

	NEG			; D -= D + lines - C
	ADD	A,D		; ( or D = C - lines )
	LD	D,A		;

	JP	BBROWDSPR	; continue

BBROWN09:
	CP	18H		; Sh-LEFT
	JR	NZ,BBROWN18

	LD	DE,0		; 1st entry
	JP	BBROWDSPA	; continue

BBROWN18:
	CP	19H		; Sh-RIGHT
	JR	NZ,BBROWN19

	LD	E,C		; last entry
	DEC	E
	JP	BBROWDSPR	; continue

BBROWN19:
	CP	0DH		; ENTER
	JR	Z,BBROW0D

	CALL	VBROWKEYS
	OR	A
	JP	Z,BBROWDSP

	DB	06H		; LD B,0
BBROW0D:
	XOR	A

BBROWHOTKEY:
	PUSH	AF
	PUSH	DE
	LD	A,E		; current file
	INC	A
	LD	HL,FILES-FILENT$
	LD	DE,FILENT$
BBROWN0A0:
	ADD	HL,DE
	DEC	A
	JR	NZ,BBROWN0A0
	POP	DE
	POP	AF

	OR	A		; Z if ENTER, else A=hotkey
	RET


;-----	Display all displayable files
BROWDSPALL:
	LD	B,0
LBROWDSPALL:
	CALL	BROWDSP
	INC	B
	LD	A,B
	CP	BROWLINES
	JR	NZ,LBROWDSPALL
	RET


;-----	Display one displayable file
BROWDSP:
	PUSH	DE		; file positions
	LD	A,B

	LD	HL,BROWLINE1*80+BROWCOL1+DSPBUF-80
	LD	DE,80
	INC	A

BROWDSP1:
	ADD	HL,DE
	DEC	A
	PUSH	HL
	POP	IY		; buffer position
	JR	NZ,BROWDSP1

	POP	DE		; file positions

	PUSH	BC		; disp row and files count
	PUSH	DE		; file positions

	LD	A,B		; current row
	ADD	A,D		; first item
	LD	D,A		; -> current item
	SUB	E		; selected item
	CALL	BUFREVZ		; Set Reverse Display if A=0
	LD	B,BROWCOLS	; Max width
	LD	A,D		; Current item
	CP	C		; if < # items then non-displayable
	JR	NC,BROWDSP8	; jump if non-displayable => blank line

	CALL	VBROWITEM	; Display item

BROWDSP8:
	LD	A,' '		; fill rest of line
	CALL	BUFPUTCHR	;
	DJNZ	BROWDSP8	;

	POP	DE		; file positions
	POP	BC		; disp row and files count
	RET

;-----	Vector to display one displayable item
VBROWITEM:
	JP	$-$

;-----	Vector to filter hot keys
VBROWKEYS:
	JP	BROWNOKEY
BROWNOKEY:
	XOR	A
	RET


;======================================================


MCURFLD	DB	'Current Folder:\',0

MCOPYRT	DB	'(c)GmEsoft',0

MFIRMW	DB	'FW ',0

MSELTIT	DB	'HxC Floppy Emulator File Selector',0DH
	DB	'v'
	$VER
	DB	' - '
	DATE
	DB	0DH,0DH
	DB	'(c) 2023 GmEsoft / Michel BERNARD',0DH
	DB	'GitHub: https://github.com/GmEsoft',0DH
	DB	0DH
	DB	'TRS-80 Model 4/4D/4p version',0DH
	DB	0DH
	DB	'This software uses the HxC FAT32/LBA Library',0DH
	DB	'(c) 2016-2023 GmEsoft / Michel BERNARD',0DH
	DB	0DH,0DH
	DB	'---Press any key to continue---',0

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END

;------------------------------------------------------------------------------
