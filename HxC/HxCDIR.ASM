;
;	HXCDir/ASM	FAT Directory routines
;

BRK	DEFL	0		; Enable Breakpoints
TRC	DEFL	0		; trace

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

*MOD

;-----	Open directory
;
OPENDIR:
	LD	DE,XDIRCLU	;current dir start cluster
	LD	HL,XDIRFCB
	CALL	MOV32
	CALL	FCBOPEN
	IF	DBG
	CALL	FCBDEBUG
	ENDIF
	RET


;=====	GETLFN
;
;-----	Put char in A as uppercase to (DE)
GETLFCH:
	CP	'a'
	JR	C,BGETLFCH
	CP	'z'+1
	JR	NC,BGETLFCH
	SUB	20H		;to UC
BGETLFCH:
	EX	DE,HL
	LD	(HL),A
	INC	HL
	LD	(HL),0
	EX	DE,HL
	RET

;-----	Copy up to B wide chars from (HL) to (IY)
GETLFCPB:
	CALL	GETLFCP
	DJNZ	GETLFCPB
	RET

;-----	Copy wide char from (HL) to (IY)
;	non-ASCII chars converted to '?'
GETLFCP:
	LD	A,(HL)
	INC	HL
	LD	(IY),A
	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,BGETLFCPX
	LD	(IY),'?'
BGETLFCPX:
	INC	IY
	RET

;-----	Sub: Get long/short file name
;	IN:	HL	Dir entry
;		IY	0 if no LFN, or LFN buffer ptr
;	OUT:	DE	Long/Short file name
GETLFN:
	LD	A,(IX+0BH)	;attrib
	CP	0FH		;Long name?
	JR	NZ,BGETLF19	;jump if not

	;----- LFN entry
	BIT	6,(HL)		;test if 1st LFN entry
	JR	Z,BGETLF11	;skip if not
	LD	IY,XLFNBUF+0FFH	;init LFN buf ptr
	LD	(IY),0		;terminator
BGETLF11:
	LD	DE,-13		;move LFN buf ptr 13 bytes bwds
	ADD	IY,DE		;(preserve DE!)
	INC	HL
	LD	B,5
	CALL	GETLFCPB	;copy 5 chars
	INC	HL		;skip attrs
	INC	HL		;skip type
	INC	HL		;skip cksum
	LD	B,6
	CALL	GETLFCPB	;copy 6 chars
	INC	HL		;skip 1st cluster
	INC	HL
	LD	B,2
	CALL	GETLFCPB	;copy last 2 chars
	ADD	IY,DE		;restore IY
	LD	DE,0		;no filename
	JR	BGETLFN		;next entry

	;----- normal dir entry
BGETLF19:
	PUSH	IY
	POP	DE
	LD	IY,0		;set "no long name"
	LD	A,D
	OR	E
	JR	NZ,BGETLFN
	LD	DE,XLFNBUF
	PUSH	DE
	LD	B,8
BGETLF2:
	LD	A,(HL)
	INC	HL
	CP	' '
	CALL	NZ,GETLFCH	;output name
	DJNZ	BGETLF2
	LD	A,(HL)
	CP	' '
	LD	A,'.'
	CALL	NZ,GETLFCH	;output '.' if ext present
	LD	B,3
BGETLF3:
	LD	A,(HL)
	INC	HL
	CP	' '
	CALL	NZ,GETLFCH	;output ext.
	DJNZ	BGETLF3
	POP	DE
BGETLFN:
	RET

;=====	Change directory
DOCHDIR:
;	TODO: refactor to call CHDIR
;	$BREAK	DOCHDIR
	PUSH	HL		;start fname
	LD	DE,XFSPEC
	CALL	GETFMASK
	PUSH	HL		;end fname
	LD	HL,XDIRFCB
	CALL	FINDFILE	;HL=IX=dirent
	POP	DE		;end fname
	POP	BC		;start fname
	RET	NZ

	BIT	4,(IX+0BH)	;is DIR?
	JR	NZ,BDOCHDIR0	;if yes
	CALL	DISMPC
	DB	'Not a directory',0DH
	LD	A,63		;extended error
	RET

BDOCHDIR0:
	PUSH	HL		;dirent
	EX	DE,HL		;hl=end fname; de=dirent
	OR	A
	SBC	HL,BC		;len
	PUSH	HL		;swap HL & BC
	PUSH	BC
	POP	HL		;fname to HL
	POP	BC		;len to BC
	EX	DE,HL
	LD	HL,XPWD
	XOR	A
	CP	(HL)		;pwd empty?
	JR	Z,BDOCHDIR2	;jump if yes
BDOCHDIR1:
	CP	(HL)
	INC	HL
	JR	NZ,BDOCHDIR1
	DEC	HL
	LD	(HL),'\'
	INC	HL
BDOCHDIR2:
	EX	DE,HL
BDOCHDIR3:
	LDIR
	XOR	A
	LD	(DE),A
	POP	DE		;dir ent to DE
	LD	HL,XDIRFCB
	CALL	FCBOENT
	XOR	A
	RET


;-----	Change directory
CHDIR:
;	$BREAK	CHDIR
	PUSH	HL		;start fname
	LD	DE,XFSPEC
	CALL	GETFMASK
	PUSH	HL		;end fname
	LD	HL,XDIRFCB
	CALL	FINDFILE	;HL=IX=dirent
	POP	DE		;end fname
	POP	BC		;start fname
	RET	NZ

	BIT	4,(IX+0BH)	;is DIR?
	JR	NZ,CHDIR1	;jump if ok
	LD	A,63		;extended error
	OR	A		;ret if not
	RET

CHDIR1:	EX	DE,HL		;dir ent to DE
	LD	HL,XDIRFCB
	CALL	FCBOENT
	XOR	A
	RET


;=====	Change Drive
CHDRIVE:
;	$BREAK
	LD	A,(HL)
	CP	'C'
	JR	C,ERCHDRV
	CP	'G'
	JR	NC,ERCHDRV
	PUSH	AF
	SUB	'C'-1
	CALL	MVPART
	LD	E,A
	POP	AF
	LD	D,A
	LD	A,E
	OR	A
	RET	NZ
	LD	(XPWD),A	;reset PWD
	LD	A,D
	LD	(XPART),A	;store drive letter
	LD	DE,X2L
	LD	HL,XDIRCLU
	CALL	MOV32
	CALL	OPENDIR
	XOR	A
	RET
ERCHDRV:
	LD	A,32
	OR	A
	RET


;-----	Change to Up-Dir
CHDIRUP:
	;;$$BREAK
	LD	HL,XPWD
	LD	DE,XPWD
BCDUP0:
	LD	A,(HL)
	CP	'\'
	JR	NZ,BCDUP1
	LD	D,H
	LD	E,L
BCDUP1:	INC	HL
	OR	A
	JR	NZ,BCDUP0
	LD	(DE),A
	LD	HL,XPWD
	LD	A,(HL)
	EX	AF,AF'
	LD	HL,XPART
	CALL	CHDRIVE
	RET	NZ
	LD	HL,XPWD
	EX	AF,AF'
	LD	(HL),A
BCDUP2:	LD	A,(HL)
	OR	A
	RET	Z
	LD	D,H
	LD	E,L
BCDUP3:	INC	HL
	LD	A,(HL)
	OR	A
	JR	Z,BCDUP4
	CP	'\'
	JR	NZ,BCDUP3
BCDUP4:	PUSH	AF
	PUSH	HL
	LD	(HL),0
	EX	DE,HL
	CALL	CHDIR
	POP	HL
	POP	AF
	LD	(HL),A
	INC	HL
	OR	A
	JR	NZ,BCDUP2
	RET

;======================================================

	DB	' HxCDir:'

	$ALIGN	4
	DB	'### FCB ###'

	$ALIGN	5
XDIRFCB:
	DC	FCBSIZE,0DDH	;Directory FCB

XPART:	DB	'C'
XCOLBS:	DB	':\',14,3

PWDLEN	EQU	80
XPWD:	DB	0		;initially root
	DS	PWDLEN

	ENDIF
;++++++++++++++++++++++++++++++++++++++++++++++++

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA segment


LFNLEN	EQU	100H		; LFN buffer length
XLFNBUF:
	DS	LFNLEN

	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END
