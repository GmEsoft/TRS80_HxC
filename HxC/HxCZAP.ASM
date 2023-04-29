;	HxCSec 6.0 -- HxC Floppy Emulator Sector Display
;	Created Feb 21, 1987 by M. Bernard
;	LS-DOS 6 version created Jan 25, 2016



TRC	DEFL	0		;trace
BRK	DEFL	0		;debug


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

*MOD

	DB	' HxCZap>'

;=====	ZAP mode
DOZAP:
	XOR	A
	LD	(XPAGE),A
	LD	(XSECT),A
	LD	(XTRACK),A
	LD	HL,(VBREAK+1)
	LD	(DOZAPRET+2),HL
	LD	HL,DOZAPBK
	LD	(VBREAK+1),HL
	LD	(DOZAPERR+1),SP

	CALL	DAMON
READ:
	LD	HL,XLBA		;Base LBA
	CALL	SETLBA		;HxC Set Base LBA
	LD	A,(XSECT)
	INC	A		;fdc sector = phys sector + 1
	LD	HL,BUF512
	CALL	RDSECT		;read sector

NOREAD:	CALL	DIS		;Display page
	CALL	ZAPCMD		;Do command
	JR	C,NOREAD	;Display next page of same sector

	LD	HL,(XTRACK)	;Convert track# to relative LBA
	LD	H,0
	ADD	HL,HL
;	ADD	HL,HL
;	ADD	HL,HL

	LD	DE,(XLBA0)	;convert to absolute LBA
	ADD	HL,DE
	LD	(XLBA),HL
	LD	HL,0
	LD	DE,(XLBA0+2)
	ADC	HL,DE
	LD	(XLBA+2),HL
;	LD	A,L
;	LD	(XLBA+3),A
	JR	READ		;Read next/prev sector



;-----	Display sector's page
;	(XPAGE) = page #
;	(XNPAG) = pages count
DIS:	LD	A,(XNPAG)	;Adjust page #
	LD	B,A
	LD	A,(XPAGE)
	INC	A
	SUB	1
	JR	NC,DDIS0
	LD	A,B
	DEC	A
	JR	DIS0
DDIS0	CP	B
	JR	C,DIS0
	XOR	A

DIS0:	LD	(XPAGE),A
	LD	HL,BUF512
	ADD	A,H		;select page
	LD	H,A
	LD	IY,DSPBUF+6
	CALL	BUFCLS
	CALL	PUTPAG		;display page's bytes
	LD	IY,DSPBUF    	;DRV
	CALL	PUTMPC
	DB	'Drv',0
	LD	IY,DSPBUF+320	;SID
	CALL	PUTMPC
	DB	'Sid',0
	LD	IY,DSPBUF+640	;TRK
	CALL	PUTMPC
	DB	'Trk',0
	LD	IY,DSPBUF+960	;SCT
	CALL	PUTMPC
	DB	'Sct',0
	LD	IY,DSPBUF+1120	;Last FDC Cmd
	LD	HL,(XLSCMD)
	LD	(IY),L
	LD	(IY+1),H
	LD	A,(XERROR)	;Last FDC Error
	OR	A
	JR	Z,NOERR
	LD	IY,DSPBUF+1200
	CALL	PUTHEX
NOERR:	LD	A,(XDRIVE)
	LD	L,A
	LD	A,'0'
	PUSH	HL
DIS1	SRL	L
	JR	C,DIS2
	INC	A
	JR	DIS1
DIS2:	POP	HL
	LD	(DSPBUF+80),A	;put drive #
	LD	A,L
	AND	80H
	JR	NZ,DIS3
	LD	A,'S'
	JR	DIS4
DIS3	LD	A,'D'
DIS4	LD	(DSPBUF+81),A	;put SD/DD
	LD	A,'D'
	LD	(DSPBUF+82),A
	LD	A,L
	AND	10H
	LD	A,30H
	JR	Z,DIS5
	INC	A
DIS5	LD	(DSPBUF+401),A	;put side

	LD	IY,DSPBUF+720
	LD	A,(XTRACK)
	CALL	PUTHEX		;put track

	LD	IY,DSPBUF+1040
	LD	A,(XSECT)
	CALL	PUTHEX		;put sector
	LD	A,(XPAGE)
	ADD	A,'a'
	LD	(IY),A		;put page (a,b...)
	LD	A,(XNPAG)
	ADD	A,'@'
	LD	(IY+1),A	;put num pages (A,B,...)

	LD	IY,DSPBUF+1280
	CALL	PUTMPC
	DB	'      LBA:',0
	LD	HL,XLBA
	LD	B,(HL)
	LD	A,(XSECT)
	OR	(HL)
	LD	(HL),A
	CALL	PUTHEX4
	LD	(HL),B

	CALL	PUTMPC
	DB	'  PART:',0
	LD	HL,XLBAPAR
	CALL	PUTHEX4

	CALL	PUTMPC
	DB	'  FAT:',0
	LD	HL,XLBAFAT
	CALL	PUTHEX4

	CALL	PUTMPC
	DB	'   ROOT:',0
	LD	HL,XLBARCL
	CALL	PUTHEX4

	LD	IY,DSPBUF+1840	;Last line
	CALL	PUTMPC
	DB	'Pn=Part(0-4) - F=FAT - R=Root - Dn=DirEntry(0-7) - Break=Restart - Ctrl-C=Quit',0

	CALL	PUTDSP		;put buffer to screen
	RET

DOZAPBK:
	OR	A		; Clear Z, indicates <BREAK>
	LD	A,0		; No error
DOZAPERR:
	LD	SP,$-$
	PUSH	AF
	CALL	CLS
	POP	AF
DOZAPRET:
	PUSH	HL
	LD	HL,$-$
	LD	(VBREAK+1),HL
	POP	HL
	RET


;-----	Get and Process ZAP command
;	OUT	CF = don't read
ZAPCMD:
	CALL	WAITKI		;Get command keystroke
	CP	'z'+1		;LC to UC
	JR	NC,KEY0
	CP	'a'
	JR	C,KEY0
	SUB	20H
KEY0:	LD	HL,XNPAG
	LD	B,(HL)
	LD	HL,XPAGE
	LD	C,(HL)
	CP	';'		;';' = next sector/page
	JR	Z,KEY01
	CP	9		; or <Right>
	JR	NZ,KEY1
KEY01:	INC	C		;next page
	LD	(HL),C
	LD	A,C
	CP	B
	RET	C		;display if not past last page
	LD	HL,0001H
	JP	MOVSCT

KEY1:	CP	'-'		;'-' = prev sector/page
	JR	Z,KEY11
	CP	8		;or <Left>
	JR	NZ,KEY2
KEY11:	DEC	C		;prev page
	LD	(HL),C
	SCF
	RET	P		;display if not prev first page
	LD	HL,0FFFFH
	JP	MOVSCT

KEY2:	CP	'.'		;'.' = next track
	JR	Z,KEY21
	CP	10		;or <Down>
	JR	NZ,KEY3
KEY21:	LD	HL,0100H
	LD	C,0
	JP	MOVSCT

KEY3:	CP	'_'		;'_' = prev track
	JR	Z,KEY31
	CP	11		;or <Up>
	JR	NZ,KEY4
KEY31:	LD	HL,0FF00H
	LD	C,0
	JP	MOVSCT

KEY4	CP	'X'		;'X' = change side
	JR	NZ,KEY5
	LD	HL,XDRIVE
	LD	A,(HL)
	XOR	10H
	LD	(HL),A
	LD	HL,0
	LD	C,0
	JP	MOVSCT

KEY5:	CP	'P'		;Sel partition
	JR	NZ,KEY6
	CALL	WAITKI
	CP	'0'		;'0-4' = seek MBR (0) / PBR (1-4)
	JR	C,KEY6
	CP	'5'
	JR	NC,KEY6
	SUB	'0'
	CALL	MVPART
KEYZ:	XOR	A
	LD	(XTRACK),A
	LD	(XSECT),A
	LD	(XPAGE),A
	RET

KEY6:	CP	'F'		;'F' = FAT
	JR	NZ,KEY7
	LD	HL,XLBAFAT
KEYM:	LD	DE,XLBA0
	LD	BC,4
	LDIR
	JR	KEYZ

KEY7:	CP	'R'		;'R' = Root
	JR	NZ,KEY8
	LD	HL,XLBARCL
	JR	KEYM

KEY8:	CP	'D'		;'D' = Sel dir entry
;	$BREAK
	JR	NZ,KEY9
	CALL	WAITKI
	CP	'0'		;'0-7' = Dir Entry
	JR	C,KEY6
	CP	'8'
	JR	NC,KEY6
	SUB	'0'
	LD	E,A
	LD	A,(XPAGE)
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,E
	CALL	MVDIR
	JR	KEYZ

KEY9:	CP	'O'		;'O' = Open dir entry
;	$BREAK
	JR	NZ,KEYA
	CALL	WAITKI
	CP	'0'		;'0-7' = Dir Entry
	JR	C,KEY6
	CP	'8'
	JR	NC,KEY6
	SUB	'0'
	LD	E,A
	LD	A,(XPAGE)
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,E
	CALL	TOPENDIR
	JR	KEYZ

KEYA:	SCF
	RET

MOVSCT	LD	A,C		;save new page #
	LD	(XPAGE),A
	LD	(XMVDIR),HL	;prev track

;-----	move to next/prev sector/page
MOVE:
;	$BREAK
	LD	A,(XTRACK)
	LD	D,A
	LD	A,(XSECT)
	LD	E,A
	LD	HL,(XMVDIR)
	ADD	HL,DE
	EX	DE,HL
	LD	HL,XNSECT
	LD	A,(XSECT0)	;test sector #
	SUB	E
	NEG
	INC	A
	SUB	1
	JR	NC,TSCTOV	;jump if not before 1st sector
	LD	E,(HL)
	DEC	E
	JR	TTRK		;check track #
TSCTOV	LD	A,E
	CP	(HL)
	JR	C,TTRK		;jump if not past last sector
	LD	A,(XSECT0)	;move to 1st sector
	LD	E,A
	INC	D		;  of next track
	JR	TTRKOV
TTRK	LD	HL,XNTRK
	LD	A,D		;test track #
	INC	A
	SUB	1
	JR	NC,TTRKOV	;jump if not before 1st trk
	LD	D,(HL)		;move to last track
	DEC	D
TTRKOV	LD	HL,XNTRK
	LD	A,D
	CP	(HL)
	JR	C,NEXT		;jump if not past last trk
	LD	D,0		;move to track 0
NEXT	LD	A,D
	LD	(XTRACK),A
	LD	A,E
	LD	(XSECT),A
	XOR	A		;reset CF to read next sector
	RET



;-----	Open directory entry
TOPENDIR:
	LD	L,A
	LD	H,0
	ADD	HL,HL		;mul by 0x20
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	LD	DE,BUF512	;1st cluster
	ADD	HL,DE
	LD	DE,XDIRFCB
	EX	DE,HL
	CALL	FCBOENT		;open dir entry
;	CALL	FCBDEBUG
	RET

;======================================================

	DB	' HxCZap:'


	DB	' SIZES:'
XNSECT	DB	2	;number of sectors per track
XNTRK	DB	255	;number of tracks
	DB	' PTRS:'
XTRACK	DB	0	;current track
XSECT	DB	0	;current sector
XPAGE	DB	0	;current sector's page
XMVDIR	DW	0	;current move direction
XSECT0	DB	0	;1st sector
;XDIRCLU	DW	2,0	;current dir 1st clus

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA segment



	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END

;------------------------------------------------------------------------------
