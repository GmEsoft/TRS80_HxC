;
;	HXCLBA/ASM	HXC LBA Routines
;
;	SETLBA		HXC Set Base LBA ((HL)=new LBA, out: A=(XERROR)=exit status)
;	CPYLBA		Copy LBA (HL=Source LBA ptr, out: HL=XLBA)

*MOD
BRK	DEFL	0		;Enable breakpoints

BLKSIZE	EQU	2		;DAM block size (1,2,4,8) - optimum=2
WRFLAG	EQU	0A5H		;write flag (0=RD,A5=RD+WR,5A=WR)

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

	$MSG	HxCLBA

LBA_BEGIN:

;-----	HXC Set Base LBA
;	IN:	(HL) = new LBA
;	OUT:	A = (XERROR) = exit status
SETLBA:
	;$BREAK	SETLBA
	PUSH	HL
	PUSH	DE
	PUSH	BC
	EX	DE,HL
	LD	HL,XLSLBA	;Active LBA
	LD	BC,4
	CALL	MEMCMP		;Compare
	LD	A,0		;Ret status = OK
	JP	Z,BSLBAX	;Skip if same LBA

	PUSH	DE		;Save LBA
	LD	DE,XHCMDC	;command buffer: cmd_code
	LD	A,01H		;Change LBA address
	LD	(DE),A
	INC	DE
	POP	HL		;LBA
	PUSH	HL
	LD	BC,4
	LDIR
	LD	A,WRFLAG	;A5,5A=Write Enable; 5A=Read Disable
	LD	(DE),A
	INC	DE
	LD	A,BLKSIZE	;Sectors Count (0=8)
	LD	(DE),A

	LD	HL,XHPAR0	;Parameters Start: parameter_0
	NOP			;skip reloc
	LD	BC,0800H	;B=8 loops, C=0(init checksum)
BCKSUM:	LD	A,(HL)
	INC	HL
	ADD	A,C
	LD	C,A
	DJNZ	BCKSUM
	LD	(HL),A		;store checksum

	POP	HL		;LBA Base
	LD	DE,XLSLBA	;Last LBA Base
	LD	BC,4
	LDIR

	IF	DBG.GT.1
	CALL	DIS
	CALL	WAITKI
	ENDIF

	IF	DBG
	LD	HL,XPAGE	;Save and reset page #
	LD	A,(HL)
	LD	(HL),0
	PUSH	AF
	ENDIF

	CALL	WRCMND		;Send command to HxC

	IF	DBG.GT.1
	CALL	DIS
	CALL	WAITKI
	ENDIF

	IF	DBG
	POP	AF		;Restore page #
	LD	(XPAGE),A
	ENDIF

	CALL	RDSTAT		;Read HxC Status
	LD	A,(XHSLCS)	;Command status

BSLBAX:
	LD	(XERROR),A
	POP	BC
	POP	DE
	POP	HL

	RET


;-----	Copy LBA (not used by HxCHard?)
;	IN:	HL = Source LBA ptr
;	OUT:	HL = XLBA
CPYLBA	PUSH	DE
	PUSH	BC
	LD	DE,XLBA
	PUSH	DE
	LD	BC,4
	LDIR
	POP	HL
	POP	BC
	POP	DE
	RET


;-----	End code part
LBA_END:
	$MSG	/HxCSYS

;-----	Begin data part

XLSLBA	DC	4,255	;Last LBA
XLBA	DC	4,0	;Current LBA

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$RELO	; RELO segment

CSEG_LBA 	MACRO
	DW	LBA_BEGIN,LBA_END
	ENDM

	ENDIF			; RELO segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END
