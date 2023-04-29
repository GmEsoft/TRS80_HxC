;Montezuma Micro CP/M Loader for TRS-80 Model 4/4p
;
;	Disassembled & commented Wed Mar 25 13:21:36 2020

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	;CODE Segment

MSGLEN	EQU	000BH		;"BOOT ERROR!" length
NMIJP	EQU	0066H		;NMI JP instr
NMIJP1	EQU	0067H		;NMI JP addr
SECTSIZ	EQU	0100H		;Sector Size
SELMASK	EQU	0C102H		;D=drive select, E=status mask
BDOS	EQU	00100H		;BDOS entry point
BIOS	EQU	00100H		;BIOS entry point
VIDEO	EQU	0F800H		;Video RAM


	PHASE	4300H
BOOT	LD	BC,MBDOS	;BDOS area ptr
	DI			;Disable maskable interrupts
	LD	A,82H		;Bring Video RAM
	OUT	(84H),A		;
	LD	HL,VIDEO	;Video RAM
LDOCLS	LD	(HL),20H	;Fill ' ' in Video RAM
	INC	HL		;
	LD	A,H		;
	OR	L		;
	JR	NZ,LDOCLS	;Loop until done
	LD	SP,HL		;Stack ptr = 0000h
	OUT	(0E0H),A	;out 0
	LD	A,40H		;
	OUT	(0ECH),A	;
	LD	A,03H		;
	OUT	(84H),A		;Memory mapping=64k DRAM
	LD	A,0C3H		;Set up NMI vector
	LD	HL,NMIHDLR	;NMI hdlr, end sct reading & get status
	LD	(NMIJP),A	;NMI JP instr
	LD	(NMIJP1),HL	;NMI JP addr
	LD	HL,(MSECTSZ)	;Sector size ptr
	LD	A,(MSECTS)	;Num sectors ptr
	LD	B,A		;To DJNZ counter
	EX	DE,HL		;sect size to DE
	LD	HL,(MBDOS)	;BDOS area ptr
;	SBC	HL,DE		;memory 1 sector back for boot sector
	;loop to load sectors
LLDSECT	EXX			;save regs
	CALL	LDSECT		;Load one sector
	EXX			;rest regs
	JP	NZ,BOOTERR	;Display boot error message
	ADD	HL,DE		;bump memory ptr
	DJNZ	LLDSECT		;load next sector
	LD	HL,(MBIOS)	;BIOS area ptr
	JP	(HL)		;Jump to BIOS Bootstrap

	;Load one sector
LDSECT	LD	HL,(MPINTRL)	;get Sector interleave ptr
	LD	A,(HL)		;get sector number from interl table
	INC	A		;check if end of interleave table
	JR	NZ,LDSECT1	;go read sector if yes
	LD	HL,MINTERL	;reset Sector interleave table ptr
	LD	A,(MSIDE)	;get current side
	LD	C,A		;
	LD	A,(MSIDES)	;number of sides - 1
	XOR	C		;switch side if 2-sided
	LD	(MSIDE),A	;current side
	JR	NZ,LDSECT1	;go if side 2
	LD	A,54H		;else step in
	CALL	SENDCMD		;send FDC command and wait !busy
	;wait step-in complete
WSTEPIN	LD	A,81H		;select drive
	OUT	(0F4H),A	;
	IN	A,(0F0H)	;get FDC status
	AND	01H		;busy flag
	JR	NZ,WSTEPIN	;wait step-in complete
	;track sectors loop
LDSECT1	LD	A,(HL)		;get sector number from interl table
	INC	HL		;bump interleave table ptr
	LD	(MPINTRL),HL	;save it
	OUT	(0F2H),A	;Write FDC Sector register
	CALL	RDSECTB		;Read sector (1st try)
	RET	Z		;return if OK
	CALL	RDSECTB		;Read sector (2nd try)
	RET	Z		;return if OK
	;Read sector (try 3 times)
RDSECTB	LD	C,0F3H		;FDC Data register for INI
	LD	DE,SELMASK	;D=drive select byte, E=status mask
	EXX			;Get DRAM dest ptr
	PUSH	HL		;
	EXX			;
	POP	HL		;
	LD	A,(MSIDE)	;current side
	RLCA			;move to bit 4
	RLCA			;
	RLCA			;
	RLCA			;
	OR	D		;OR with drive select byte
	LD	D,A		;
	AND	0BFH		;
	OUT	(0F4H),A	;send drive select
	LD	A,80H		;CMD = read
	CALL	SENDCMD		;send FDC command and wait !busy
	LD	A,0C0H		;enable FDC NMI
	OUT	(0E4H),A	;send NMI mask
	;wait sector ready to read
WREADY	IN	A,(0F0H)	;get FDC status
	AND	E		;keep busy flag
	JR	Z,WREADY	;wait sector ready to read
	INI			;read one byte
	LD	A,D		;drive select byte
	;loop to read bytes until NMI
LRDBYTE	OUT	(0F4H),A	;acknowledge byte
	INI			;read next byte
	JR	LRDBYTE		;loop until NMI

	;NMI hdlr, end sct reading & get status
NMIHDLR	POP	HL		;discard NMI ret address
	XOR	A		;disable all NMI
	OUT	(0E4H),A	;send NMI mask
	IN	A,(0F0H)	;get FDC status byte
	AND	9CH		;keep error flags
	RET			;sector done

	;send FDC command and wait !busy
SENDCMD	OUT	(0F0H),A	;send FDC command
WAITOK	IN	A,(0F0H)	;get FDC status
	AND	01H		;keep busy flag
	JR	Z,WAITOK	;loop while busy
	RET			;done

	;Display boot error message
BOOTERR	LD	A,02H		;Bring video RAM
	OUT	(84H),A		;
	LD	HL,MBOOTER	;Boot error message
	LD	DE,VIDEO	;Video RAM
	LD	BC,MSGLEN	;"BOOT ERROR!" length
	LDIR			;display message
FOREVER	JR	FOREVER		;loop forever

	;BDOS area ptr
MBDOS	DW	BDOS
	;BIOS area ptr
MBIOS	DW	BIOS
	;Sector size ptr
MSECTSZ	DW	SECTSIZ
	;Number of sides - 1
MSIDES	DB	00H
	;Num sectors ptr
MSECTS	DB	.HIGH.$ENDCODE-1 ;end of HxC-DOS
	;Sector interleave table
MINTERL	DB	01H,02H,03H,04H,05H,06H,07H,08H
	DB	09H,0AH,0BH,0CH,0DH,0EH,0FH,10H
	DB	11H,12H,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
	DB	0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
	;Sector interleave ptr
MPINTRL	DW	MINTERL+1
	;current side
MSIDE	DB	00H
	;Boot error message
MBOOTER	DB	'BOOT error!',00H

	DEPHASE

	DC	100H-$,0

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END

