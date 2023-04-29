;	HxCSec 6.0 -- HxC Floppy Emulator Sector Display
;	Created Feb 21, 1987 by M. Bernard
;	LS-DOS 6 version created Jan 25, 2016



BRK	DEFL	0
TRC	DEFL	0		;trace



;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

*MOD

	DB	' HxCSlot>'

;=====	SLOT selector
DOSLOT:
	CALL	PUSHCLS		; Push CLS and intercept <Break>
	CALL	SPLASH
	LD	HL,0
	LD	(SLOTSAVPOS),HL	; reset slot selection indexes
	LD	(LASTSEL),HL	; reset file selection indexes
	;$$BREAK
DOSLOTR:
	CALL	OPENHXCCFG	; Open HXCSDFE.CFG
	RET	NZ

	CALL	READNSEC	; read sector 0
	RET	NZ

	LD	A,(BUF512+23)	; Last active slot
	LD	(XLSTSLT),A	; Save it
	SUB	1		; Decrement
	ADC	A,0		; Increment if < 0
	LD	(SLOTSAVPOS),A	; Last slot position for browser

	CALL	READNSEC	; read sector 1
	RET	NZ

	EXX
	LD	BC,0000H	; B=used slots, c=available slots
	LD	DE,FILES
	EXX

SLOTL1:
	CALL	READNSEC	; read next slot sector
	CP	28		; EOF ?
	JR	Z,SLOTOK	; Exit loop if yes
	OR	A		; Another error ?
	RET	NZ		; Exit if yes

	EXX

	LD	A,B
	CP	C
	JR	C,SLOT11

	INC	B
	DEC	C
	INC	C
	JR	Z,SLOT01
	DEC	B

	XOR	A

	LD	HL,BUF512+00H	; sector's 1st slot
	CP	(HL)
	JR	Z,SLOT11
	INC	B
SLOT01:
	LD	HL,BUF512+80H	; sector's 2nd slot
	CP	(HL)
	JR	Z,SLOT11
	INC	B

	LD	HL,BUF512+100H	; sector's 3rd slot
	CP	(HL)
	JR	Z,SLOT11
	INC	B

	LD	HL,BUF512+180H	; sector's 4th slot
	CP	(HL)
	JR	Z,SLOT11
	INC	B


SLOT11:
	INC	C		; If sector ok, 4 more slots
	INC	C
	INC	C
	INC	C
	PUSH	DE		; Files ptr
	EXX
	POP	DE

	PUSH	HL		; push HXCSDFE.CFG FCB
	LD	HL,BUF512
	LD	BC,0200H
	LDIR
	POP	HL

	PUSH	DE
	EXX
	POP	DE
	EXX

	JR	NZ,SLOTL1

	EXX
	DEC	C
	EXX

SLOTOK:
	EXX			;
	LD	A,B		; save # of used slots
	LD	(XNUMSLT),A	;
	CP	C
	JR	C,SLOT101
	DEC	A
SLOT101:
	EXX			;

	LD	C,A
	LD	HL,BROWSLOT
	LD	(VBROWITEM+1),HL

;-----	Slot selection loop
SLOT10:				; Loop to browse slots
	CALL	SPLASH		; Display one-time splash screen
	CALL	BROWSCREEN	; Setup Browse screen

	LD	IY,80+DSPBUF
	LD	HL,MSLOTAB	;
	CALL	BUFCENTER	;

	LD	IY,22*80+DSPBUF	;
	LD	HL,MSLTKYS	; MSlot help for keys
	CALL	BUFCENTER	;

	LD	HL,BROWKEYSSLOT
	LD	(VBROWKEYS+1),HL
	LD	DE,$-$
SLOTSAVPOS EQU	$-2
BB:
	CALL	BROWSE		; Browse the slots
	LD	(SLOTSAVPOS),DE

	PUSH	AF
	LD	A,E		; Selected item #
	INC	A		; to 1-based
	LD	(XLSTSLT),A	; Last selected slot

	LD	IY,22*80+DSPBUF
	CALL	BUFNORMAL
	CALL	BUFCLRLINE

	LD	HL,MSLTKYS
	CALL	BUFCENTER

	CALL	BUFREVERSE	; hilight 'REBOOT'
	LD	IY,22*80+70+DSPBUF ;
	LD	HL,MREBOOT
	CALL	BUFMSG

	CALL	PUTDSP
	POP	AF
	DB	06H		; LD B,0

;-----	Slot commands
SLOTL11:
	XOR	A
	OR	A
	CALL	Z,WAITKI
	LD	B,A
	AND	5FH		; to upper-case

	CP	'C'		; Change slot
	JR	Z,SLOT10

	CP	'A'		; Select image for drive A:
	JR	Z,SLOTHFE

	CP	'B'		; Select image for drive B:
	JR	Z,SLOTHFE

	CP	0DH		; Select this slot and boot
	JP	Z,SLOTSELBOOT	;

	CP	'Q'		; 'A' on AZERTY kbds -> drive A:
	LD	A,'A'
	JR	Z,SLOTHFE

	LD	A,B
	AND	5FH		; to upper-case
	CP	'S'		; Select image for drive A:
	CALL	Z,POSTKI
	LD	A,'A'
	JR	Z,SLOTHFE

	LD	A,B
	AND	5FH		; to upper-case
	CP	'D'		; Selete
	CALL	Z,POSTKI
	LD	A,'A'
	JR	Z,SLOTHFE

	LD	A,B		; Arrows: change slot
	CP	8
	JR	C,SLOTL11
	CP	12
	JR	NC,SLOTL11	; re-read KI if not an arrow

	CALL	POSTKI		; otherwise unget arrow

	JP	SLOT10		; and browse slots

;-----	Select .HFE file for this slot
SLOTHFE:
	;$$BREAK
	LD	(SLTHFED1),A	; for delete
	LD	(SLTHFED2),A	; for sub-menu
	SUB	'A'		; 00=A: 01=B:
	RRCA
	RRCA			; 00=A: 40=B:
	LD	(XSLTDRV),A	; Drive A/B offset

	LD	IY,22*80+DSPBUF
	CALL	BUFCLRLINE
	CALL	BUFNORMAL
	LD	HL,MSLTIMG
	CALL	BUFCENTER
	CALL	PUTDSP

;-----	Drive commands
SLOTHFE1:			; loop to read keyboard commands
	CALL	WAITKI		; read keyboard
	LD	B,A		;
	AND	5FH		; to upper-case
	CP	'S'		; Select image ?
	JR	Z,SLOTHFE3	; if yes
	CP	'D'		; Delete entry ?
	JR	Z,SLOTHFE2	; if yes
	CP	'C'		; Change slot ?
	JP	Z,SLOT10	; if yes
	LD	A,B		;
	CP	8		; arrows ?
	JR	C,SLOTHFE1	;
	CP	12		;
	JR	NC,SLOTHFE1	; if not, loop again
	CALL	POSTKI		; if yes, post to KI
	JP	SLOT10		; and browse slots

;-----	Delete drive entry
SLOTHFE2:			; Delete drive entry
	LD	IY,22*80+DSPBUF
	CALL	BUFCLRLINE
	CALL	BUFNORMAL
	LD	HL,MDELETE
	CALL	BUFCENTER
	CALL	PUTDSP
	CALL	WAITKI		; read keyboard
	LD	B,A
	AND	5FH		; to upper-case
	CP	'Y'
	JR	Z,SLOTHFE21
	LD	A,B
	CALL	POSTKI		; post to KI
	JP	SLOT10		; and browse slots

SLOTHFE21:
	LD	HL,FILES
	LD	DE,FILES+1
	LD	BC,FILENT$-1
	LD	(HL),0
	PUSH	HL		; copy selected file entry
	EXX
	POP	HL		; to HL'
	EXX
	LDIR
	CALL	CLS
	CALL	DISMPC
	DB	'Deleted Drive '
SLTHFED1:
	DB	'A: Entry',3
	JR	SLOTHFE4	; Save config

;-----	Select disk image for drive entry
SLOTHFE3:			; Select image
	LD	HL,BROWKEYSHFE
	LD	(VBROWKEYS+1),HL
	LD	HL,SELHFEFILT	; .HFE filter routine
	LD	(VSETFLT),HL
	LD	HL,MHFEKYS	; .HFE keys help
	LD	DE,MMEDFLS	; "SD/USB Media Files"
	CALL	DOSELALL1	; call file selector
;	RET	C		;NZ		; <Break> or Error
	JR	Z,SLOTHFE3S	; <Enter> Select image
;	$$BREAK			; TODO: I and W commands
	CP	'I'		; <I>: get information
	JP	Z,SLOTHFE5	;
	CP	'W'		; <W>: toggle write-protect
	JP	Z,SLOTHFE6	;
	CP	'Z'		; <W> (azerty): toggle write-protect
	JP	Z,SLOTHFE6	;
	JR	SLOTHFE3	; unexpected...
SLOTHFE3S:
	PUSH	HL		; copy selected file entry
	EXX
	POP	HL		; to HL'
	EXX

	CALL	CLS
	CALL	DISMPC
	DB	'Selected Media File: ',3
	LD	DE,DE$LNAM
	ADD	HL,DE
	CALL	DISM

;-----	Save updated config
SLOTHFE4:
	CALL	DISMPC
	DB	0AH,'Saving config .',3

	CALL	OPENHXCCFG	; Open HXCSDFE.CFG
	RET	NZ

	CALL	UPDHXCCFG	; Update config page 0
	RET	NZ

	LD	A,(XLSTSLT)	; Last slot #
	SRL	A
	SRL	A		; Divide by 4
	INC	A
	INC	A
	LD	(DE),A

	CALL	SEEKFRS		; seek sector A
	RET	NZ		; exit on error
	CALL	READNSEC	; read 3rd sector
	RET	NZ		; exit on error

	LD	A,'.'		; show progress
	CALL	DDISA		;

	EXX			; use alt set (HL=selected file)
	PUSH	HL
	LD	DE,BUF512	; sector buffer
	LD	A,(XLSTSLT)	; Last slot #
	LD	HL,0
XSLTDRV	EQU	$-2		; Slot drive offset
	ADD	HL,HL
	RRCA
	RR	L
	RRCA
	RL	H
	ADD	HL,DE
	EX	DE,HL
	POP	HL
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
	JR	NZ,$?SLTHFE1	; jump if not found
	DEC	HL		;
	LD	(HL),0		; truncate at '.' position
$?SLTHFE1:
	POP	HL		; point to short file name
	LD	BC,12		; seek '.' to remove extension
	LD	A,'.'		;
	CPIR			;
	JR	NZ,$?SLTHFE2	;
	DEC	HL		;
	LD	(HL),0		;
$?SLTHFE2:
	EXX			; use main reg set

	LD	DE,SDCFGFRS	; seek sector 2
	CALL	SEEKFRS		;
	RET	NZ		; exit on error
	CALL	WRITENSEC	; write updated sector
	RET	NZ		; exit on error

	JP	DOSLOTR		; show slots

;-----	Get .HFE file info
SLOTHFE5:
	PUSH	HL
	LD	IY,22*80+DSPBUF
	CALL	BUFCLRLINE
	CALL	BUFNORMAL
	LD	A,10H		; Enable reverse mode
	CALL	DDISA		;
	CALL	PUTDSP
	LD	IY,22*80+10+DSPBUF
	LD	A,'['
	CALL	PUTCHR
	LD	DE,15H
	ADD	HL,DE
	CALL	BUFMSG
	POP	HL

	LD	DE,0DH		; point to 1st cluster
	ADD	HL,DE		;
	EX	DE,HL		; to DE
	LD	HL,XFILEFCB	; File FCB
	CALL	MOV32		; 1st cluster to FCB
	CALL	FCBOPEN		; Open file from 1st cluster
	RET	NZ		; exit on error
	CALL	READNSEC	; Read 1st sector
	RET	NZ		; on error
	LD	IX,BUF512
;	$$BREAK

	CALL	PUTMPC		; Display cylinders
	DB	']: Cyls=',3
	LD	A,(IX+09H)
	CALL	BUFDECA

	CALL	PUTMPC		; Display density
	DB	', ',3
	LD	A,(IX+0BH)
	OR	A
	LD	A,'D'
	JR	Z,SLOTHFE51
	LD	A,'S'
SLOTHFE51:
	CALL	PUTCHR

	CALL	PUTMPC		; Display sides
	DB	'den, Sides=',3
	LD	A,(IX+0AH)
	ADD	A,'0'
	CALL	PUTCHR

	CALL	PUTMPC
	DB	', Steps=',3
	LD	A,'2'
	ADD	A,(IX+15H)
	CALL	PUTCHR

	CALL	PUTMPC
	DB	', WP=',3
	LD	A,(IX+14H)
	CALL	PUTYN

	CALL	PUTDSP

	CALL	WAITKI

	JP	SLOTHFE3	; browse slots

;-----	Toggle write-protect
SLOTHFE6:
	PUSH	HL
	LD	IY,22*80+DSPBUF
	CALL	BUFCLRLINE
	CALL	BUFNORMAL
	LD	A,10H		; Enable reverse mode
	CALL	DDISA		;
	CALL	PUTDSP
	LD	IY,22*80+10+DSPBUF
	LD	A,'['
	CALL	PUTCHR
	LD	DE,15H
	ADD	HL,DE
	CALL	BUFMSG
	LD	A,']'
	CALL	PUTCHR
	POP	HL

	LD	DE,0DH		; point to 1st cluster
	ADD	HL,DE		;

	EX	DE,HL		; to DE
	LD	HL,XFILEFCB	; File FCB
	CALL	MOV32		; 1st cluster to FCB
	CALL	FCBOPEN		; Open file from 1st cluster
	RET	NZ		; exit on error
	CALL	READNSEC	; Read 1st sector
	RET	NZ		; on error
	LD	IX,BUF512

	CALL	PUTMPC		; Display current WP status
	DB	': WP=',3
	LD	A,(IX+14H)
	CALL	PUTYN

	CALL	PUTMPC		; Display cylinders
	DB	' - Change to WP=_',3


SLOTHFE53
	CALL	PUTDSP
	CALL	WAITKI

	CP	0DH
	JR	Z,SLOTHFE55

	AND	5FH
	CP	'Y'
	JR	Z,SLOTHFE54

	CP	'N'
	SCF
	JR	NZ,SLOTHFE53

SLOTHFE54:
	DEC	IY
	CALL	PUTCHR
	LD	A,0
	SBC	A,A
	LD	(IX+14H),A
	JR	SLOTHFE53

SLOTHFE55:
	LD	A,(IX+14H)
	DEC	IY
	CALL	PUTYN
	CALL	PUTDSP
	LD	DE,HFEFRS	;
	CALL	SEEKFRS
	RET	NZ
	CALL	WRITENSEC
	RET	NZ

	JP	SLOTHFE3	; browse slots


;-----	Save config and reboot
SLOTSELBOOT:
	CALL	OPENHXCCFG	; Open HXCSDFE.CFG
	RET	NZ

	CALL	UPDHXCCFG	; Update config page 0
	RET	NZ

	CALL	CLS
	JP	DOBOOT		; Reboot


;=====	Slot Selector Hot keys filter
BROWKEYSSLOT:
	AND	5FH		; to upper case
	CP	'A'		; Select drive A: entry
	RET	Z
	CP	'Q'		; Select drive A: entry (azerty)
	RET	Z
	CP	'B'		; Select drive B: entry
	RET	Z
	CP	'C'		; Change slot
	RET	Z
	CP	'D'		; Delete drive A: entry (shortcut)
	RET	Z
	CP	'S'		; Select drive image for A: (shortcut)
	RET	Z
;BROWKEYSLOT0:
	XOR	A
	RET

;=====	HFR Selector Hot keys filter
BROWKEYSHFE:
	AND	5FH		; to upper case
	CP	'I'		; Get info
	RET	Z
	CP	'W'		; Toggle write-protect
	RET	Z
	CP	'Z'		; Toggle write-protect (azerty)
	RET	Z
BROWKEYSHFR0:
	XOR	A
	RET

;=====	Display one displayable slot
BROWSLOT:
	LD	DE,80H
	LD	HL,FILES
	PUSH	AF		; Item #
	INC	A
BROWSLT6:
	ADD	HL,DE
	DEC	A
	JR	NZ,BROWSLT6
	LD	A,' '
	CALL	BUFPUTCHRB
	POP	AF		; Item #
	INC	A
	CALL	BUFDECA
	DEC	B
	DEC	B
	DEC	B
	CALL	BROWSLTDRV
	LD	DE,40H
	ADD	HL,DE
	JP	BROWSLTDRV

BROWSLTDRV:
	PUSH	HL

	LD	A,' '
	LD	C,4
BROWSLT60:
	CALL	BUFPUTCHRB
	DEC	C
	JR	NZ,BROWSLT60

	LD	DE,DE$LNAM
	ADD	HL,DE
	LD	C,20
BROWSLT7:
	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,BROWSLT71
	CALL	BUFPUTCHRB
	DEC	C
	JR	BROWSLT7
BROWSLT71:
	INC	C
	INC	C
BROWSLT72:
	LD	A,' '
	CALL	BUFPUTCHRB
	DEC	C
	JR	NZ,BROWSLT72
	POP	HL
	RET


;======================================================

	DB	' HxCSlot:'

MSLOTAB	DB	'Slot    Drive A                   Drive B                  ',0

MSLTKYS	DB	'A(drive  B(drive  S(elect file  D(elete entry - '
MFILKYS	DB	'Arrows=Move  Enter=Select',0
MHFEKYS	DB	'I(nformation  W(rite protect  Arrows=Move  Enter=Select',0

MSLTIMG	DB	'Drive '
SLTHFED2:
	DB	'A:  S(elect file  D(elete entry  C(hange slot',0

MREBOOT	DB	'REBOOT',0

MDELETE	DB	'Delete selected entry [Y/N]?',0

HFEFRS:
	DEFD	0		; .HFE sector number (constant)

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA segment

;-----	DIR ENTRY BUFFER

	$STRUCT	DIRENT$		; Struct ShortDirectoryEntry
	$CHARS	DE$NAME,12	; Short name
	$BYTE	DE$ATTR		; File attributes
	$DWORD	DE$FCLS		; First cluster
	$DWORD	DE$SIZE		; File size
	$CHARS	DE$LNAM,17	; Long name (truncated)
	$ENDSTRUCT DIRENT$

;-----	FILES LIST

FILES	EQU	HEAP		; Files table
FILENT$	EQU	50H		; Length of file entry

	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END

;------------------------------------------------------------------------------
