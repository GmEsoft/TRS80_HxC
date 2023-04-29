;	HxCSec 6.0 -- HxC Floppy Emulator Sector Display
;	Created Feb 21, 1987 by M. Bernard
;	LS-DOS 6 version created Jan 25, 2016



TRC	DEFL	0		;trace
BRK	DEFL	0		;debug


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment
ORIGIN:

*MOD

	DB	' HxCSec6>'

;=====	Entry point
START:	LD	SP,STKORG
	CALL	SAVNMI
	LD	HL,START
	LD	(VBREAK+1),HL
	LD	HL,EXIT
	LD	(VABORT+1),HL
	LD	HL,MINIT	; Startup title
	CALL	DISM
	LD	A,0EH		; Cursor on
	CALL	DDISA
	LD	A,1
	LD	(XPHOST),A

;-----	Try host drive
START1:	LD	SP,STKORG
	LD	A,0FH
	CALL	DDISA

	LD	HL,0
	LD	(XLBA),HL
	LD	(XLBA+2),HL

	XOR	A		;clear error status
	CALL	HXC_RSLCT	;select drive
	JR	NZ,CKSIGN

	CALL	DAMON		;Enable DAM
	JR	NZ,CKSIGN

	LD	HL,BUF512
	CALL	RDSECT

	CALL	RDSTAT
	PUSH	HL

	IF	DBG
	CALL	DIS
	CALL	WAITKI
	CALL	CLS
	ENDIF	;DBG

	POP	HL

	LD	DE,MSIG
	LD	B,8
CKSIGL:	LD	A,(DE)
	CP	(HL)
	INC	DE
	INC	HL
	JR	NZ,CKSIGN
	DJNZ	CKSIGL
	JR	CKSIGZ
CKSIGN:	LD	HL,MSIG
	CALL	DISM
	LD	A,'?'
	CALL	DDISA
	CALL	WAITKI
	LD	A,0DH
	CALL	DDISA

;	Ask HxC host drive number
HDRIVE:	CALL	DISMPC
	DB	0AH,'Drive: ',3
	CALL	WAITKI
	CP	0DH
	JR	Z,START1
	CALL	DDISA
	CP	'0'
	JR	C,HDRIVE
	CP	'4'
	JR	NC,HDRIVE
	LD	L,A
	CALL	WAITKI
	CP	0DH
	JR	NZ,HDRIVE
	LD	A,L
	LD	L,80H
	SUB	2FH
HDRIVE0	RLC	L
	DEC	A
	JR	NZ,HDRIVE0
	LD	A,(XDRIVE)
	AND	0F0H
	OR	L
	LD	(XDRIVE),A
	LD	A,L
	LD	(XPHOST),A

	JP	START1

;-----	Autoexec command in boot mode
$MSELCMD:
	DB	'HXC',0DH,0

;-----	Get auto command
GETAUTOCMD:
	LD	HL,$-$
	LD	A,H
	OR	L
	RET	Z
GACMD1:	PUSH	HL
	LD	B,-1
GACMD2	INC	B
	LD	A,(HL)
	INC	HL
	CP	' '
	JR	NC,GACMD2
	LD	HL,0
	LD	(GETAUTOCMD+1),HL
	POP	HL
	RET

;-----	Set auto command
SETAUTOCMD:
	LD	(GETAUTOCMD+1),HL
	RET


;-----	HxCFEDA signature ok
CKSIGZ:
	LD	HL,XHSFWV	; HxC Firmware version from HxCFDC
	CALL	DISM		; Display it

	IF	DBG		; Debugging
	LD	HL,BUF512
	CALL	DISM
	CALL	WAITKI
	ENDIF			; End Debugging

	LD	HL,$MSELCMD	; "HXC\r"
	CALL	SETAUTOCMD

	LD	A,1		;select part 1 (C:)
	CALL	MVPART		;
	CALL	OPENDIR		;open root dir

;=====	Main loop

;-----	Return here after <Break>
RCMD:
	LD	SP,STKORG	; Stack origin

	LD	HL,RCMD		; Return here after <Break>
	LD	(VBREAK+1),HL	;
	LD	A,0DH		; Go to new line
	CALL	DDISA		;

;-----	Read command from keyboard
CMD:
	LD	HL,STKCHK	; Check if stack overflowed
	LD	B,4
	XOR	A
	LD	C,A
$SKCK0:	DEC	HL
	OR	(HL)
	LD	(HL),C
	DJNZ	$SKCK0
	OR	A
	JR	Z,$SKCK1
	CALL	DISMPC
	DB	0AH,'** STACK OVERFLOW! **',0DH
$SKCK1:				; End check

	LD	HL,CMD		;RET here
	PUSH	HL
	LD	HL,XPART	; Display host partition letter
	CALL	DISM		;
	LD	HL,XPWD		; Display current directory
	CALL	DISM		;
	LD	A,'>'		; '>' prompt
	CALL	DDISA		;
	LD	HL,XCMDBUF	;
	LD	BC,CMDLEN<8+1	;
	XOR	A
	CALL	GETAUTOCMD
	JR	NZ,BCMD0
	$SVC	@KEYIN		; read cmd
	RET	C		; redo if break pressed
	LD	A,0FH		; cursor off
	CALL	DDISA		;

	CALL	TOUPPER		; convert to UC

BCMD0:	LD	A,0FH		; cursor off
	CALL	DDISA		;
	LD	A,B		; d: = change drive
	OR	A
	RET	Z
	CP	2
	JR	NZ,BCMD1
	INC	HL
	LD	A,(HL)
	DEC	HL
	CP	':'
	JR	NZ,BCMD1
	CALL	CHDRIVE
	JR	NZ,CMDERR
	RET

;
BCMD1:
	LD	DE,CMDLIST
	CALL	EXECCMD
	JR	NZ,CMDERR
	RET	NC
	CALL	DISMPC
	DB	'Illegal Command',0DH
	RET

;-----	Display error message
CMDERR:
	PUSH	AF
	CALL	DISMPC
	DB	'Error ',0
	POP	AF
	CALL	DISDA

;	Display newline
BCMDNL:	LD	A,0DH
	JP	DDISA

;-----	Return here to display newline
CMDXNL:	PUSH	AF
	CALL	BCMDNL
	POP	AF
	RET

;-----	Parse and Exec Command
EXECCMD:
	LD	A,(DE)
	OR	A
	SCF
	RET	Z
	PUSH	HL
BXCMD0:	LD	A,(DE)
	OR	A
	JR	Z,BXCMD3	;match found
	INC	DE
	CP	(HL)
	JR	NZ,BXCMD2	;mismatch
	INC	HL
	JR	BXCMD0
BXCMD2:	LD	A,(DE)
	INC	DE
	OR	A
	JR	NZ,BXCMD2
	INC	DE
	INC	DE
	POP	HL
	JR	EXECCMD		;try next keyword
BXCMD3:	LD	A,(HL)
	CP	'A'
	JR	NC,BXCMD2	;keyword too long
BXCMD4:	LD	A,(HL)
	INC	HL
	CP	' '
	JR	Z,BXCMD4
	DEC	HL
	INC	DE
	LD	A,(DE)
	LD	C,A
	INC	DE
	LD	A,(DE)
	LD	B,A
	POP	DE
	LD	DE,BXCMDX
	PUSH	DE
	PUSH	BC
	RET

BXCMDX:	OR	A		;Z:=(A!=0), CF:=0
	RET


;=====	Clear Screen
DOCLS:	CALL	CLS
	XOR	A
	RET


;=====	List Catalog (short names)
DOCAT:
	LD	HL,CMDXNL	;return with NL
	PUSH	HL
;	$BREAK	DOCAT
	LD	HL,XDIRFCB
	LD	DE,X0L
	CALL	SEEKFRS		;reset to BOF
BDOCAT0:
;	$BREAK
	LD	HL,XDIRFCB
	CALL	READNSEC	;read next sector
	LD	C,A
	SUB	28		;EOF?
	RET	Z		;exit if yes
	LD	A,C
	OR	A		;error?
	RET	NZ		;exit if yes
	LD	B,16
	LD	HL,BUF512
BDOCAT1:
	PUSH	BC
	PUSH	HL		;read dir entry
	PUSH	HL
	POP	IX
	LD	A,(HL)
	OR	A		;null?
	JR	Z,BDOCATX	;exit if yes
	CP	0E5H		;deleted?
	JR	Z,BDOCATN	;next if yes
	LD	A,(IX+0BH)	;attrib
	CP	0FH		;Long name?
	JR	Z,BDOCATN	;next if yes
	LD	C,16		;tab 16 chars
	AND	10H		;is directory?
	LD	A,'['
	CALL	NZ,DOCATCH	;output '[' if yes
	LD	B,8
BDOCAT2:
	LD	A,(HL)
	INC	HL
	CP	' '
	CALL	NZ,DOCATCH	;output name
	DJNZ	BDOCAT2
	LD	A,(HL)
	CP	' '
	LD	A,'.'
	CALL	NZ,DOCATCH	;output '.' if ext present
	LD	B,3
BDOCAT3:
	LD	A,(HL)
	INC	HL
	CP	' '
	CALL	NZ,DOCATCH	;output ext.
	DJNZ	BDOCAT3
	LD	A,(IX+0BH)	;is DIR?
	AND	10H
	LD	A,']'		;output ']' if yes
	CALL	NZ,DOCATCH
BDOCAT4:
	LD	A,' '		;tabulate
	CALL	DOCATCH
	JR	NZ,BDOCAT4
BDOCATN:
	POP	HL		;next entry
	POP	BC
	LD	DE,20H
	ADD	HL,DE
	DJNZ	BDOCAT1
;	CALL	WAITKI
	JR	BDOCAT0

BDOCATX:
	POP	HL		;DIR normal exit
	POP	BC
	XOR	A
	RET

DOCATCH:
	CALL	DDISA
	DEC	C
	RET


;=====	List Directory (long names)
DODIR:
	LD	HL,CMDXNL	;return with NL
	PUSH	HL
;	$BREAK	DODIR
	LD	IY,0		;set "no long name"
	LD	HL,XDIRFCB
	LD	DE,X0L
	CALL	SEEKFRS		;reset to BOF
	EXX
	LD	C,22
	EXX
BDODIR0:
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
BDODIR1:
	EXX
	LD	A,C
	EXX
	OR	A
	JR	NZ,BDODIR10
	LD	A,'?'
	CALL	DDISA
	CALL	WAITKI
	LD	A,08H
	CALL	DDISA
	EXX
	LD	C,22
	EXX
BDODIR10:
	PUSH	BC
	PUSH	HL		;read dir entry
	PUSH	HL
	POP	IX
	LD	A,(HL)
	OR	A		;null?
	JP	Z,BDODIRX	;exit if yes
	CP	0E5H		;deleted?
	JP	Z,BDODIRN0	;next if yes
	CALL	GETLFN		;Get long/short filename
	LD	A,D
	OR	E
	JR	Z,BDODIRN0
	EX	DE,HL
	LD	A,'['
	BIT	4,(IX+0BH)
	CALL	NZ,DDISA
	CALL	DISM
	LD	A,']'
	BIT	4,(IX+0BH)
	CALL	NZ,DDISA
	LD	A,0DH
	CALL	DDISA
	EXX
	DEC	C
	EXX
BDODIRN0:
	POP	HL
	POP	BC
BDODIRN1:
	LD	DE,20H
	ADD	HL,DE
	DEC	B
	JP	NZ,BDODIR1
	JP	BDODIR0

BDODIRX:
	POP	HL		;DIR normal exit
	POP	BC
	XOR	A
	RET


;=====	List file (ASCII)
DOLIST:
	LD	DE,XFSPEC
	CALL	GETFMASK
	LD	HL,XDIRFCB
	CALL	FINDFILE
	RET	NZ
	BIT	4,(IX+0BH)	;is DIR?
	JR	Z,DOLIST0	;if not
	CALL	DISMPC
	DB	'Is directory',0DH
	LD	A,63		;extended error
	RET
DOLIST0:
	EX	DE,HL		;dir ent to DE
	LD	HL,CMDXNL	;exit with new line
	PUSH	HL
	LD	HL,XFILEFCB
	CALL	FCBOENT
DOLIST1:
;	$BREAK	DOLIST1
	EXX
	LD	C,0		;last char
	EXX
	LD	HL,XFILEFCB
	CALL	READNSEC	;read sector
	LD	C,A
	SUB	28		;eof?
	RET	Z

	CALL	GETNBYTES
	LD	HL,BUF512
DOLIST2:
	LD	A,(HL)
	INC	HL
	CP	0DH
	JR	NZ,DOLIST3
	EXX
	LD	A,C
	EXX
	CP	0AH
	LD	A,0DH
	JR	NZ,DOLISTX
	XOR	A
DOLIST3:
	CP	0AH
	JR	NZ,DOLISTX
	EXX
	LD	A,C
	EXX
	CP	0DH
	LD	A,0DH
	JR	NZ,DOLISTX
	XOR	A
DOLISTX:
	EXX
	LD	C,A
	EXX
	OR	A
	CALL	NZ,DDISA
	CP	0DH
	CALL	Z,GETKEY
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,DOLIST2
	JR	DOLIST1

	XOR	A		;!!temp
	RET


;=====	Config

DOCONFIG:
	LD	HL,CMDXNL	; exit with new line
	PUSH	HL

	CALL	OPENHXCCFG	; Open HXCSDFE.CFG
	RET	NZ

	CALL	READNSEC	; read sector
	RET	NZ

	PUSH	HL		; push FCB

	CALL	GETNBYTES

	LD	HL,BUF512
	PUSH	HL
	POP	IX
	CALL	DISMPC
	DB	'Signature:  ',3
	CALL	DISM

	CALL	DISMPC
	DB	0AH
	DB	'Step sound: ',3
	LD	HL,16
	CALL	LEAIX
	LD	A,(HL)
	CALL	$DISONOFFVAL

	CALL	DISMPC
	DB	0AH
	DB	'IHM sound:  ',3
	INC	HL
	LD	A,(HL)
	CALL	$DISONOFFVAL

	CALL	DISMPC
	DB	0AH
	DB	'BkLight (s):',3
	INC	HL
	LD	A,(HL)
	CALL	$DISONOFFVAL

	CALL	DISMPC
	DB	0AH
	DB	'StdBy (s):  ',3
	INC	HL
	LD	A,(HL)
	CALL	$DISONOFFVAL

	CALL	DISMPC
	DB	0AH
	DB	'Disab DvSel:',3
	INC	HL
	LD	A,(HL)
	CALL	$DISONOFFVAL

	CALL	DISMPC
	DB	0AH
	DB	'Buzz DtyCyc:',3
	INC	HL
	LD	A,(HL)
	CALL	DISDA

	CALL	DISMPC
	DB	0AH
	DB	'# of slots: ',3
	INC	HL
	LD	A,(HL)
	EXX
	LD	B,A		; B' = # of slots
	EXX
	CALL	$DISOFFVAL

	CALL	DISMPC
	DB	0AH
	DB	'Slot index: ',3
	INC	HL
	LD	A,(HL)
	EXX
	LD	C,A		; C' = # of slots
	EXX
	CALL	DISDA

	CALL	DISMPC
	DB	0AH
	DB	'Update Ctr: ',3
	INC	HL
	LD	C,(HL)
	INC	HL
	LD	A,(HL)
	CALL	DHEXA
	LD	A,C
	CALL	DHEXA
	LD	A,'H'
	CALL	DDISA

	CALL	DISMPC
	DB	0AH
	DB	'Ld Last Dsk:',3
	INC	HL
	LD	A,(HL)
	CPL
	CALL	$DISONOFFVAL

	CALL	DISMPC
	DB	0AH
	DB	'Buzz StpDur:',3
	INC	HL
	LD	A,(HL)
	CALL	DISDA

	CALL	DISMPC
	DB	0AH
	DB	'LCD Scroll: ',3
	INC	HL
	LD	A,(HL)
	CALL	DISDA

	POP	HL

	CALL	READNSEC	;read sector
	RET	NZ

	LD	HL,BUF512
	LD	C,'A'

DOCFG1:	LD	A,(HL)
	OR	A
	JR	Z,DOCFG2
	PUSH	BC
	CALL	DISMPC
	DB	0AH
	DB	'Drive ',3
	LD	A,C
	CALL	DDISA
	CALL	DISMPC
	DB	':    ',3

	PUSH	HL
	LD	B,12
	CALL	DISMB
	CALL	DISMPC
	DB	' = ',3
	POP	HL

	PUSH	HL
	LD	BC,21
	ADD	HL,BC
	LD	B,17
	CALL	DISMB
	POP	HL

	LD	BC,40H
	ADD	HL,BC
	POP	BC

DOCFG2:	INC	C
	LD	A,C
	CP	'C'
	JR	NZ,DOCFG1

	XOR	A		;!!temp
	RET

$DISONOFFVAL:
	INC	A
	JR	Z,$DISON
	DEC	A
$DISOFFVAL:
	OR	A
	JP	NZ,DISDA
	CALL	DISMPC
	DB	'OFF',3
	RET
$DISON:
	CALL	DISMPC
	DB	'ON',3
	RET


;=====	HFE File Selector
DOSELHFE:
	CALL	PUSHCLS		; Push CLS and intercept <Break>

	LD	HL,BROWNOKEY
	LD	(VBROWKEYS+1),HL
	LD	HL,0		; reset selection indexes
	LD	(LASTSEL),HL
	LD	HL,SELHFEFILT	; .HFE filter routine
	LD	(VSETFLT),HL
	LD	HL,MHFEKYS	; .HFE keys help
	LD	DE,MMEDFLS	; "SD/USB Media Files"
	CALL	DOSELALL1	; call file selector
	RET	NZ		; <Break> or Error

;	$$BREAK

	PUSH	HL		; copy selected file entry
	EXX
	POP	HL		; to HL'
	EXX

	CALL	CLS
	CALL	DISMPC
	DB	'Selected media file: ',3
	LD	DE,DE$LNAM
	ADD	HL,DE
	CALL	DISM
	CALL	DISMPC
	DB	0AH,'Saving config .',3

	CALL	OPENHXCCFG	; Open HXCSDFE.CFG
	RET	NZ

	XOR	A
	LD	(XNUMSLT),A	; Num slots = 0
	LD	(XLSTSLT),A	; Last slot = 0
	CALL	UPDHXCCFG	; Update config page 0
	RET	NZ

	EX	DE,HL
	INC	(HL)		; Increment sector
	EX	DE,HL

	CALL	SEEKFRS		; seek sector 1
	RET	NZ		; exit on error
	CALL	READNSEC	; read 3rd sector
	RET	NZ		; exit on error

	LD	A,'.'		; show progress
	CALL	DDISA		;

	EXX			; use alt set (HL=selected file)
	LD	DE,BUF512	; sector buffer
	PUSH	DE		; save it
	LD	BC,12+1+4+4+16	; copy selected file to drive A: image
	LDIR			;
	XOR	A		;
	LD	(DE),A		; Truncate the long file name
	LD	HL,-16		; point to long file name
	ADD	HL,DE		;
	LD	BC,16		; seek '.' to remove extension
	LD	A,'.'		;
	CPIR			;
	JR	NZ,$?SELHFE1	; jump if not found
	DEC	HL		;
	LD	(HL),0		; truncate at '.' position
$?SELHFE1:
	POP	HL		; point to short file name
	LD	BC,12		; seek '.' to remove extension
	LD	A,'.'		;
	CPIR			;
	JR	NZ,$?SELHFE2	;
	DEC	HL		;
	LD	(HL),0		;
$?SELHFE2:
	EXX			; use main reg set

	LD	DE,SDCFGFRS	; seek sector 2
	CALL	SEEKFRS		;
	RET	NZ		; exit on error
	CALL	WRITENSEC	; write updated sector
	RET	NZ		; exit on error

	JP	DOBOOT		; reboot

;-----	.HFE Files Filter
SELHFEFILT:
	LD	A,(IX+08H)	;test for ext '.HFE'
	CP	'H'
	RET	NZ
	LD	A,(IX+09H)
	CP	'F'
	RET	NZ
	LD	A,(IX+0AH)
	CP	'E'
	RET


;=====	File Browser
DOSELALL:
	LD	HL,DOSELALLX
	PUSH	HL

	CALL	PUSHCLS		; Push CLS and intercept <Break>

	LD	HL,BROWNOKEY
	LD	(VBROWKEYS+1),HL
	LD	HL,0		; File filter address
	LD	(VSETFLT),HL
	LD	HL,MFILKYS
	LD	DE,MALLFLS
	JP	DOSELALL1	; call file selector

DOSELALLX:
	RET	NZ		; <Break> or Error

;	$$BREAK
	PUSH	HL
	POP	IX
	LD	(IX+12),0

	JP	DOLIST


DOSELALL1:
	PUSH	HL
	CALL	BROWSCREEN

	LD	IY,80+DSPBUF
	EX	DE,HL
	CALL	BUFCENTER

	LD	IY,22*80+DSPBUF
	POP	HL
	CALL	BUFCENTER

	EXX

	JP	DOSELWFILT


;=====	Reset Slot Mode in HXCSDFE.CFG
DORESET:
	LD	HL,CMDXNL	; return with new line
	PUSH	HL		;

	CALL	OPENHXCCFG	; Open HXCSDFE.CFG
	RET	NZ

	CALL	READNSEC	; read sector 0
	RET	NZ		; exit on error

	LD	A,'.'		; show progress
	CALL	DDISA		;

	PUSH	HL		; save FCB

	LD	HL,BUF512	; get sector buffer
	PUSH	HL
	POP	IX

	;TODO: any change in config
	LD	(IX+22),0	; total # of slots
	LD	(IX+23),0	; Last selected slot
	LD	(IX+26),0	; Disable loading of last image
	LD	(IX+29),0	; Force autoboot at power-on

	POP	HL		; restore FCB

	CALL	SEEKFRS		;
	RET	NZ		; exit on error
	CALL	WRITENSEC	; write updated sector
	RET	NZ		; exit on error

	LD	A,'.'		; show progress
	CALL	DDISA		;

	XOR	A		; No error
	RET			; done


;=====	Signoff and exit to DOS
EXIT:
	CALL	RESTOR
	JP	DOSEXIT


;=====	Reboot
DOBOOT:
	CALL	DISMPC
	DB	0AH,'Booting ...',3
	DI			;Obvious...
	CALL	RESTOR
	$SVC	@IPL


;=====	About
DOVER:	LD	HL,MABOUT
	CALL	DISM
	LD	HL,XHSFWV
	CALL	DISM
	XOR	A
	JP	CMDXNL

;=====	Help
DOHELP:	CALL	DISMPC
	DB	'HELP',9,'F1',9,'This help',0AH
	DB	'FILES',9,'F2',9,'Browse all files',0AH
	DB	'HXC',9,'F3',9,'Select HFE Image file',0AH
	DB	'CONFIG',9,'Shft-F1',9,'Show HxC Floppy Emulator config',0AH
	DB	'RESET',9,9,'Deactivate Slot Mode',0AH
	DB	'ZAP',9,'Ctrl-F1',9,'ZAP mode',0AH
	DB	'd:',9,9,'Mount drive d:',0AH
;	DB	'VOL',9,9,'*Show volume name',0AH
	DB	'CD dir',9,9,'Change directory',0AH
	DB	'CAT',9,9,'List directory (wide)',0AH
	DB	'DIR',9,9,'List directory (long)',0AH
;	DB	'PWD',9,9,'*Show current directory',0AH
	DB	'LIST file',9,'List file',0AH
	DB	'CLS',9,9,'Clear screen',0AH
	DB	'VER',9,9,'Show version',0AH
	DB	'BOOT',9,9,'Reboot system',0AH
	DB	'EXIT',9,9,'Exit program',0AH
	DB	0
	XOR	A
	RET




;======================================================

	DB	' HxC:'

	$ALIGN	4
	DB	'### FCB ###'

	$ALIGN	5
XFILEFCB:
	DC	FCBSIZE,0FFH	;File FCB

	$ALIGN	5
XFSPEC	DC	11,0AAH		;aligned file spec

	DB	' MSGS:'

MINIT	DW	1F1CH
MABOUT	DB	'HxC '
	$VER
	DB	0AH
	DB	'Build: '
	DATE
	DB	' '
	TIME
	IF	DBG
	DB	' - Debug'
	ENDIF
	DB	0AH
	DB	'HxC Firmware: ',03H

MSELVER	DB	'HxC Floppy Emulator File Selector v'
	$VER
	DB	0


CMDLIST:
	DB	'CLS',0
	DW	DOCLS
	DB	'CD',0
	DW	DOCHDIR
	DB	'CHDIR',0
	DW	DOCHDIR
	DB	'ZAP',0
	DW	DOZAP
	DB	'CAT',0
	DW	DOCAT
	DB	'DIR',0
	DW	DODIR
	DB	'LIST',0
	DW	DOLIST
	DB	'TYPE',0
	DW	DOLIST
	DB	'SLOT',0
	DW	DOSLOT
	DB	'HXC',0
	DW	DOSLOT
	DB	'SEL',0
	DW	DOSELHFE
	DB	'FILES',0
	DW	DOSELALL
	DB	'CONFIG',0
	DW	DOCONFIG
	DB	'RESET',0
	DW	DORESET
	DB	'CFG',0
	DW	DOCONFIG
	DB	'EXIT',0
	DW	EXIT
	DB	'BOOT',0
	DW	DOBOOT
	DB	'VER',0
	DW	DOVER
	DB	'HELP',0
	DW	DOHELP
	DB	'?',0
	DW	DOHELP
	DB	0


	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA segment


CMDLEN	EQU	80		;cmd buffer length
XCMDBUF:
	DS	CMDLEN+1

	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END

;------------------------------------------------------------------------------
