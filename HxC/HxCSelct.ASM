;
;	HXCSelct/ASM	File Selector
;

BRK	DEFL	0		; Enable Breakpoints
TRC	DEFL	0		; trace

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

*MOD


;=====	File Browser/Selector
DOSELWFILT:
	CALL	SPLASH		; One-time splash screen

DOSELLOOP:

;	LD	HL,CMDXNL	; return with NL
;	PUSH	HL
;	$BREAK	DOSEL
	LD	IY,0		;set "no long name"
	LD	HL,XDIRFCB
	LD	DE,X0L
	CALL	SEEKFRS		;reset to BOF
	EXX
	LD	DE,FILES
	LD	BC,0
	EXX
BDOSEL0:
	LD	HL,XDIRFCB
	CALL	READNSEC	;read next sector
	LD	E,A
	SUB	28		;EOF?
	RET	Z		;exit if yes
	LD	A,E
	OR	A		;error?
	RET	NZ		;exit if yes
	LD	B,16
	LD	HL,BUF512
BDOSEL1:
	PUSH	BC		; S+1: Dir entry counter
	PUSH	HL		; S+2: Dir entry
	PUSH	HL
	POP	IX		; read dir entry
	LD	A,(HL)
	OR	A		; null?
	JP	Z,BDOSELX	; exit if yes
	CP	0E5H		; deleted?
	JP	Z,BDOSELN0	; next if yes
	CALL	GETLFN		; Get long/short filename
	LD	A,D		; Got filename ?
	OR	E		;
	JP	Z,BDOSELN0	; next if not
	LD	A,(IX+0BH)	; attributes
	AND	06H		; hidden/system?
	JR	NZ,BDOSELN0	; next if yes

	BIT	4,(IX+0BH)	; Directory?
	JR	NZ,BDOSELDIR	; copy name if yes

	CALL	SELFILTER	; Call filter routine in HL'
	JR	NZ,BDOSELN0
	JR	SELNAME

BDOSELDIR:
	LD	A,'.'
	CP	(IX+00H)
	JR	NZ,SELNAME
	CP	(IX+01H)
	JR	NZ,BDOSELN0


SELNAME:
	;$$BREAK
	PUSH	DE		; S+3: long file name
	EXX

	PUSH	IX		; Short name
	POP	HL		; to HL

	PUSH	BC		; S+4: save files counter
	PUSH	DE		; S+5: save file entry

	LD	BC,8
	LDIR
SELNAME0:
	DEC	DE
	LD	A,(DE)
	CP	' '
	JR	Z,SELNAME0
	INC	DE
	LD	A,(HL)
	SUB	' '
	JR	Z,SELNAME1
	LD	A,'.'
	LD	(DE),A
	INC	DE
	LD	C,3
	LDIR
SELNAME2:
	DEC	DE
	LD	A,(DE)
	CP	' '
	JR	Z,SELNAME2
	INC	DE
SELNAME1:
	XOR	A
	LD	(DE),A

	POP	HL		; S+5: rest file entry
	LD	DE,12
	ADD	HL,DE

	LD	A,(IX+0BH)	; Attributes
	LD	(HL),A
	INC	HL

	LD	A,(IX+1AH)	; First cluster
	LD	(HL),A
	INC	HL
	LD	A,(IX+1BH)
	LD	(HL),A
	INC	HL
	LD	A,(IX+14H)
	LD	(HL),A
	INC	HL
	LD	A,(IX+15H)
	LD	(HL),A
	INC	HL

	EX	DE,HL

	PUSH	IX		; File size
	POP	HL

	LD	BC,001CH	; Offset in DIR entry
	ADD	HL,BC
	LD	BC,4
	LDIR

	POP	BC		; S+4: rest files counter
	POP	HL		; S+3: long file name

	PUSH	BC		; S+3: save files counter
	LD	BC,FILENT$-DE$LNAM-1  ;length
	LDIR
	POP	BC		; S+3: rest files counter

	XOR	A
	LD	(DE),A		; null terminator
	INC	DE

	INC	BC		; inc files counter

	EXX

BDOSELN0:
	POP	HL		; S+2: dir entry
	POP	BC		; S+1: dir entry counter

BDOSELN1:
	LD	DE,20H		; bump to next dir entry
	ADD	HL,DE		;
	DEC	B		; decr dir entry ctr
	JP	NZ,BDOSEL1	; loop until no more entry
	JP	BDOSEL0		; read next dir sector

BDOSELX:			; DIR normal exit
	POP	HL		; S+2: dir entry
	POP	BC		; S+1: dir entry counter

	LD	HL,CMPDIRENT	; sort entry comparator
	EXX			; Switch to alt set
	PUSH	BC		; S+1: Number of files in array
	LD	HL,FILES	; files to sort
	LD	DE,FILENT$	; sort entry size
	INC	B		; More than 255 files ?
	DEC	B		;
	CALL	Z,SELSORT	; If not, do Selection Sort
	EXX			; Back to main reg set
	POP	BC		; S+1: Number of files in array
DOSELEXIT:
	LD	HL,BROWFILE	;
	LD	(VBROWITEM+1),HL

	LD	DE,$-$		; D=1st displayed file, E=Cur file
LASTSEL	EQU	$-2
	CALL	BROWSE
	JR	C,DOSELEXIT	; Aborted

	LD	(LASTSEL),DE

	PUSH	HL
	POP	IX

	PUSH	AF		; hotkey

	BIT	4,(IX+DE$ATTR)	; is a directory ?
	JR	Z,DOSELFIL	; if not, return selected file entry in HL

	POP	AF		; hotkey
	JR	NZ,DOSELEXIT	; ignore hotkey on directory

	LD	DE,0		; reset selection indexes
	LD	(LASTSEL),DE

	LD	A,'.'
	CP	(IX+00H)
	JR	NZ,DOSELCD
	CP	(IX+01H)
	JR	NZ,DOSELCD

	CALL	CHDIRUP

	JR	DOSELCD1
DOSELCD:
	CALL	DOCHDIR
DOSELCD1:
	RET	NZ
	CALL	BROWPWD		; Update current dir display
	JP	DOSELLOOP

DOSELFIL:
	CALL	CLS
	POP	AF
	RET


;-----	Selector Files Filter (call HL')
SELFILTER:
	PUSH	HL
	LD	HL,$-$
VSETFLT	EQU	$-2
	LD	A,H
	OR	L
	JR	Z,SELNOFILT
	EX	(SP),HL
	RET
SELNOFILT:
	POP	HL
	RET

;-----	Compare directory entries IX, IY
CMPDIRENT:
	LD	A,(IY+DE$ATTR)	; attrib 2nd entry
	AND	10H		; directory bit
	LD	B,A		;
	LD	A,(IX+DE$ATTR)	; attrib 1st entry
	AND	10H		; directory bit
	CP	B		;
	CCF			; DIR entries come before
	RET	NZ		; ret if dir bits not same
	LD	BC,DE$LNAM	; long name
	PUSH	IX
	POP	HL
	ADD	HL,BC		; long name 1
	EX	DE,HL
	PUSH	IY
	POP	HL
	ADD	HL,BC
	LD	B,FILENT$-DE$LNAM
LCMPDE0:
	LD	A,(HL)		; lfn 2 char
	AND	5FH		; to Upper case
	LD	B,A
	LD	A,(DE)		; lfn 2 char
	AND	5FH		; to Upper case
	CP	B
	RET	NZ		; ret if not same
	OR	A
	RET	Z		; ret if end of string
	INC	DE
	INC	HL
	DJNZ	LCMPDE0
	RET

;=====	Display one displayable file
BROWFILE:
	LD	DE,FILENT$
	LD	HL,FILES-FILENT$
	INC	A
BROWFIL6:
	ADD	HL,DE
	DEC	A
	JR	NZ,BROWFIL6
	PUSH	HL
	POP	IX
	LD	DE,DE$LNAM
	ADD	HL,DE
;	LD	B,BROWCOLS
	BIT	4,(IX+DE$ATTR)	; directory ?
	LD	A,'['
	CALL	NZ,BUFPUTCHRB
BROWFIL7:
	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,BROWFIL71
	CALL	BUFPUTCHR
	DJNZ	BROWFIL7
	RET

BROWFIL71:
	BIT	4,(IX+DE$ATTR)	; directory ?
	LD	A,']'
	CALL	NZ,BUFPUTCHRB
	RET


MMEDFLS	DB	'--- SD/USB Media Files ---',0

MALLFLS	DB	'--- All Files ---',0


	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END

;------------------------------------------------------------------------------
