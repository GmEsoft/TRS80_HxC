;	HxCSec 6.0 -- HxC Floppy Emulator Sector Display
;	Created Feb 21, 1987 by M. Bernard
;	LS-DOS 6 version created Jan 25, 2016



BRK	DEFL	0
TRC	DEFL	0		;trace



;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

*MOD

	DB	' HxCSlot>'

;=====	Sub to open HXCSDFE.CFG
;
;	OUT	HL	FCB*
;		DE	SDCFGFRS = FRS* for seek
OPENHXCCFG:
;	$$BREAK
	LD	HL,$?CFGFCB	; select HXCSDFE.CFG FCB
	CALL	ISNUL32		; Already opened ?
	JR	Z,$?OHXCC0	; open if not
	CALL	FCBOPEN		; else re-open (reset ptrs)
	JR	$?OHXCCX	; reset seek sector number
$?OHXCC0:
	LD	HL,XPART	; Change to root folder
	CALL	CHDRIVE		;
	LD	HL,MHXCSDFE	; "HXCSDFE.CFG"
	LD	DE,XFSPEC	; file mask
	CALL	GETFMASK	; get file mask
	LD	HL,XDIRFCB	; select current directory FCB
	CALL	FINDFILE	; find the config file
	RET	NZ		; exit on error
	EX	DE,HL		; dir ent to DE
	LD	HL,$?CFGFCB	; select HXCSDFE.CFG FCB
	CALL	FCBOENT		; open file using dir entry

$?OHXCCX:
	EX	DE,HL
	LD	HL,SDCFGFRS	; config file sector
	CALL	ZERO32		; set to FRS 0
	EX	DE,HL		; FRS to DE
	XOR	A		; success
	RET


;=====	Sub to update HXCSDFE.CFG config page 0
;
UPDHXCCFG:
	CALL	READNSEC	; read sector 0
	RET	NZ		; exit on error

	LD	A,'.'		; show progress
	CALL	DDISA		;

	PUSH	HL		; save FCB

	LD	HL,BUF512	; get sector buffer
	PUSH	HL
	POP	IX

	LD	B,1
XLSTSLT	EQU	$-1
	LD	(IX+23),B	; Last selected slot
	INC	B
	LD	A,2
XNUMSLT	EQU	$-1
	CP	B
	ADC	A,0
	LD	(IX+22),A	; total # of slots
	LD	(IX+26),0	; Disable loading of last image
	LD	(IX+29),4	; Force autoboot at power-on

	POP	HL		; restore FCB

	CALL	SEEKFRS		;
	RET	NZ		; exit on error
	CALL	WRITENSEC	; write updated sector
	RET	NZ		; exit on error

	LD	A,'.'		; show progress
	CALL	DDISA		;
	RET

;======================================================

	DB	' HxCFECFG:'

	;$ALIGN	6
	DB	'$?CFGFCB:'
	DC	-$.AND.001FH,'=';
$?CFGFCB:
	DC	FCBSIZE,0H	; HXCSDFE.CFG FCB, Initialized with 0s

	DC	-$.AND.000FH,'=';
SDCFGFRS:
	DEFD	0		; HXCSDFE.CFG sector number



MHXCSDFE:
	DB	'HXCSDFE.CFG',0


	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA segment


	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END

;------------------------------------------------------------------------------
