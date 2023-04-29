;
;	HXCFILE/ASM	HxC File Handling Primitives
;
;	HXC_READ	READ (DE=handle, HL=dest ptr, BC=bytes count)
;	HXC_WRITE	WRITE (DE=handle, HL=src ptr, BC=bytes count)
;	HXC_FLUSH	FLUSH to disk
;	HXC_LSEEK	LSEEK (DE=handle, (HL)=long *offset)
;	HXC_OPENDISK	OPENDISK - Open disk file (HL=filename, DE=FCB)
;	HXC_STRERROR	STRERROR - Get error message
;	HXC_INIT	INIT - open FAT32 file system and root dir
;	HXC_RSLCT	Reselect hard drive (seek track 255)
;	HXC_VERSION	VERSION - Show HxC Firmware Version
;	TOUPPER		String to upper case (HL=char*, B=len)

*MOD
BRK	DEFL	0		;Enable breakpoints

NFCBS	EQU	8

DOFLUSH	EQU	0		;force flush after write [0]

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

FILE_BEGIN:

;-----	SETSP
;	switch to local stack
;	to call at proc entry
	IF	BANKS
$HXC_SETSP:
;	$$BREAK
	DI			;to be sure...
	POP	AF		;ret addr in AF
	LD	($HXC_SAVSP),SP	;save old SP
	LD	SP,HXC_STACK	;local stack
	PUSH	HL		;push $HXC_EXIT ret addr
	LD	HL,$HXC_EXIT	;
	EX	(SP),HL		;
	PUSH	AF		;push ret addr
	RET			;ret
$HXC_EXIT:
	LD	SP,$-$		;old SP
$HXC_SAVSP EQU	$-2
	RET			;return to caller
	ENDIF

;-----	READ
;	IN	DE = handle
;		HL = dest ptr
;		BC = bytes count
HXC_READ:
	$BREAK	HXC_READ
	IF	BANKS
	CALL	$HXC_SETSP
	ENDIF
	XOR	A		;clear error status
	CALL	HXC_RSLCT	;select drive
	RET	NZ		;exit on error
	PUSH	IX
	PUSH	BC		;count
	PUSH	DE		;hndl

	CALL	RWLOADLBA

	PUSH	DE		;dest
	PUSH	DE
	LDIR
;TODO: read next sect if necessary
	XOR	A
BRFRDX:	POP	DE		;drop
	POP	HL		;dest
	POP	DE		;hndl
	POP	BC		;count
	POP	IX
	OR	A
	$BREAK	/HXC_READ
	RET

;-----	WRITE
;	IN	DE = handle
;		HL = src ptr
;		BC = bytes count
HXC_WRITE:
	$BREAK	HXC_WRITE
	IF	BANKS
	CALL	$HXC_SETSP
	ENDIF
	XOR	A		;clear error status
	CALL	HXC_RSLCT	;select drive
	RET	NZ		;exit on error
	PUSH	IX
	PUSH	BC		;count
	PUSH	DE		;hndl

	CALL	RWLOADLBA

	PUSH	DE		;dest
	PUSH	DE
	EX	DE,HL
	LDIR
	;$BREAK
	LD	A,1
	LD	(XSECDIRTY),A

	IF	DOFLUSH
	CALL	$HXC_FLUSH	;force flush after write
	ENDIF

	XOR	A
BRFWRX:	POP	DE		;drop
	POP	HL		;dest
	POP	DE		;hndl
	POP	BC		;count
	POP	IX
	OR	A
	$BREAK	/HXC_WRITE
	RET

;-----	Sub to flush current LBA and load new LBA
RWLOADLBA:
	LD	(XHNDL),DE	;save
	PUSH	HL		;dest
	LD	DE,XOFFSET
	LD	HL,XNEWFRS
	CALL	MOV32
	LD	E,(HL)
	INC	HL
	LD	A,(HL)
	DEC	HL
	AND	1
	LD	D,A
	LD	A,9
	CALL	SHR32
	PUSH	DE		;sec offs
	LD	DE,XCURFRS
	CALL	CMP32
	JR	NZ,BRFRDR	;if diff frs
	PUSH	HL
	PUSH	DE
	LD	HL,(XCURHNDL)
	LD	DE,(XHNDL)
	CALL	CPHLDE
	POP	DE
	POP	HL
	JR	Z,BRFRD1	;same hndl
BRFRDR:	EX	DE,HL
	CALL	$HXC_FLUSH	;flush current sec if dirty
	CALL	MOV32
	EX	DE,HL
	LD	HL,(XHNDL)
	LD	(XCURHNDL),HL
	CALL	SEEKFRS
	CALL	Z,READNSEC
	JR	NZ,BRWLLX
;TODO:
;xfer bc bytes to (hl)
BRFRD1:	LD	HL,(XOFFSET)
	LD	DE,0
	ADD	HL,BC		;count
	LD	(XOFFSET),HL
	LD	HL,(XOFFSET+2)
	ADC	HL,DE
	LD	(XOFFSET+2),HL
BRWLLX:	POP	DE		;sec offs
	LD	HL,BUF512
	ADD	HL,DE
	POP	DE		;dest
	RET

;-----	FLUSH
HXC_FLUSH:
	IF	BANKS
	CALL	$HXC_SETSP
	ENDIF
$HXC_FLUSH:
	LD	A,(XSECDIRTY)
	OR	A
	RET	Z
	$BREAK	$HXC_FLUSH
	PUSH	DE
	PUSH	HL
	PUSH	IX
	XOR	A
	LD	(XSECDIRTY),A
	LD	DE,XCURFRS
	LD	HL,(XCURHNDL)
	CALL	SEEKFRS
	CALL	Z,WRITENSEC
	POP	IX
	POP	HL
	POP	DE
	$BREAK	/HXC_FLUSH
	RET


;-----	LSEEK
;	IN	DE = handle
;		(HL) = long *offset
;		BC = ?
HXC_LSEEK:
	$BREAK	HXC_LSEEK
	PUSH	DE
	LD	DE,XOFFSET
	CALL	STO32
	POP	DE
	XOR	A
	$BREAK	/HXC_LSEEK
	RET

;-----	FTRUNCATE - not implemented (not used by HxCHARD)
HXC_FTRUNCATE:
	$BREAK	HXC_FTRUNCATE
	LD	A,33
	OR	A
	RET

;-----	CLOSEDISK - not implemented (not used by HxCHARD)
HXC_CLOSEDISK:
	$BREAK	HXC_CLOSEDISK
	LD	A,33
	OR	A
	RET

;-----	Open disk file
;	IN:	HL = filename
;	OUT:	DE = FCB
HXC_OPENDISK:
;	$BREAK
	$BREAK	HXC_OPENDISK

	IF	BANKS
	CALL	$HXC_SETSP	;switch to internal stack
	ENDIF

	PUSH	IX		;save regs
	PUSH	BC
	PUSH	HL		;save filename

	XOR	A
	CALL	$HXC_INIT	;open partition and root dir
	JR	NZ,BHXCODX	;exit on error
	POP	HL		;rest filename
	PUSH	HL		;save
	LD	DE,XFMASK	;file mask to
	CALL	GETFMASK	;  extract MS-DOS fspec
	EX	DE,HL
	LD	B,11		;convert 11 chars of fmask
	CALL	TOUPPER		;  to uppercase
	EX	DE,HL		;fmask to DE
	LD	HL,(XNXFCB)	;get next fcb
	PUSH	DE
	LD	DE,XFCBEND	;test if end of fcbs
	CALL	CPHLDE
	POP	DE
	LD	A,44		;parameter error code
	JR	Z,BHXCODX	;exit if out of FCBs
	CALL	FINDFILE	;find file in directory
	JR	NZ,BHXCODX	;exit if error
	EX	DE,HL		;dir ent to DE
	LD	HL,(XNXFCB)	;next FCB to HL
	CALL	FCBOENT		;open directory entry
	EX	DE,HL		;FCB in DE as handle
	LD	HL,FCBSIZE	;bump FCB ptr to next FCB
	ADD	HL,DE		;
	LD	(XNXFCB),HL	;save new next FCB

	XOR	A		;exit code OK
BHXCODX:
	POP	HL		;rest regs
	POP	BC
	POP	IX
	OR	A		;set Z flag to A
	RET

;-----	STRERROR - get error message (not used by HxCHARD after init)
HXC_STRERROR:
	$BREAK	STRERROR
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	(HL),3
	OR	0C0H
	LD	C,A
	$SVC	@ERROR
	POP	HL
	POP	DE
	POP	BC
	RET

;-----	INIT - open FAT32 file system and root dir
HXC_INIT:

	IF	BANKS
	CALL	$HXC_SETSP	;switch to internal stack
	ENDIF

$HXC_INIT:
	$BREAK	$HXC_INIT
	CALL	$HXC_FLUSH	;flush any dirty sector
	IF	CACHE
;	$$BREAK
	CALL	CACHE_INIT	;initialize cache buffers
	ENDIF

	CALL	SAVNMI		;save NMI vector
	XOR	A		;clear error status
	CALL	HXC_RSLCT	;select drive
	RET	NZ		;exit on error

	CALL	DAMON		;enable HxC direct access mode
	RET	NZ		;exit on seek error
	CALL	RDSTAT		;get HxC status
;
;	verify HxCFEDA signature
;
	$BREAK	HxCFEDA
	LD	HL,XHXCSTA
	LD	DE,MSIG
RFIN04	EQU	$-2
	LD	B,8
CKSIG0:	LD	A,(DE)
	CP	(HL)
	INC	DE
	INC	HL
	JR	NZ,CKSIG1
	DJNZ	CKSIG0
	JR	CKSIGX
CKSIG1:	$BREAK	/HXC_INIT!08
	LD	A,8		;"Device not available"
	LD	(XNOHXC),A
	OR	A
	RET
;
;	Signature OK; select SD partition 1
;
CKSIGX:
	LD	A,1		;select part 1 (C:)
	CALL	MVPART
;
;	XFCB init here for relocation
;
	LD	HL,(XNXFCB)	;next FCB ptr
	LD	A,H		;
	AND	L		;
	INC	A		;-1?
	JR	NZ,CKSIGY	;if yes,
	$BREAK	INIT_XFCB
	LD	HL,XFCB		;   initialize
	LD	(XNXFCB),HL	;   to first FCB
CKSIGY:
	CALL	$HXC_OPENDIR	;open root dir
	XOR	A		;
	LD	(XNOHXC),A	;status OK
	$BREAK	/HXC_INIT
	RET
;
;
;-----	VERSION - Show HxC Firmware Version  (not used by HxCHARD after init)
HXC_VERSION:
	$BREAK	HXC_VERSION
	LD	HL,XHSFWV	;firmware version
	RET
;
;
;-----	OPENDIR - Open directory
$HXC_OPENDIR:
	LD	DE,XDIRCLU	;current dir start cluster
	LD	HL,(XNXFCB)	;next FCB
	CALL	MOV32		;move dir start clus to FCB
	CALL	FCBOPEN		;open dir

	IF	DBG
	CALL	FCBDEBUG	;debug FCB
	ENDIF

	RET


;-----	String to upper case
;	IN	HL = char*
;		B = char count
TOUPPER:
	DEC	B
	INC	B
	RET	Z
	PUSH	BC
	PUSH	HL
BTOUP1:	LD	A,(HL)
	CP	'a'
	JR	C,BTOUPN
	CP	'z'+1
	JR	NC,BTOUPN
	SUB	20H
	LD	(HL),A
BTOUPN:	INC	HL
	DJNZ	BTOUP1
	POP	HL
	POP	BC
	RET


;-----	Reselect hard drive (seek track 255)
HXC_RSLCT:
	$BREAK	HXC_RSLCT
	PUSH	AF
	PUSH	BC
	PUSH	IY
	LD	A,(XNOHXC)	;is HxC there?
	OR	A
	JR	NZ,BRSLCTE	;exit if error
	LD	BC,(XHOSTDCT)	;known host dct
	PUSH	BC
	POP	IY		;DCT to IY
	LD	A,B		;check if known (BC != 0xFFFF)
	AND	C
	INC	A
	JR	Z,BRSLCT00	;search if not known (DCT == -1)
	BIT	3,(IY+3)	;hard drive?
	JR	NZ,BRSLCT00	;re-search if yes (swapped)
	LD	A,(XPHOST)	;check phys host
	SUB	(IY+4)
	AND	0FH
	JR	Z,BRSLCT1	;jump if phys host OK
BRSLCT00:
	LD	C,0H		;search DCT of host FDC
BRSLCT0:
	BIT	3,C		;error if C > 7
	LD	A,32H		;'illegal drive number'
	JR	NZ,BRSLCTE	;error: host drv not found

	IF	BANKS
	CALL	$HXC_GTDCT	;get DCT in IY
	ELSE
	$SVC	@GTDCT
	ENDIF

	INC	C		;for next drive check
	LD	A,(IY)		;get enabled flag (JP/RET)
	CP	0C9H		;disabled (RET)?
	JR	Z,BRSLCT0	;next if yes
	BIT	3,(IY+3)	;hard drive?
	JR	NZ,BRSLCT0	;next if yes
	LD	A,(XPHOST)	;check phys host
	SUB	(IY+4)
	AND	0FH
	JR	NZ,BRSLCT0	;next if not OK
	LD	(XHOSTDCT),IY	;save host DCT
BRSLCT1:
	LD	BC,5
	ADD	IY,BC
	LD	(XPTRACK),IY	;ptr to current track
	LD	A,(XPHOST)
	OR	80H		;DDEN flag on
	LD	(XDRIVE),A
	LD	A,255
	CP	(IY)		;check if DBA mode active
	JR	Z,BRSLCTX	;skip last LBA resetting if yes

	CALL	$HXC_FLUSH	;flush any dirty LBA sector
;	LD	A,255		;reset last LBA in HxCLBA.ASM
;	LD	(XLSLBA+3),A	;

BRSLCTX:			;$HXC_RSLCT good exit
	$BREAK	/$HXC_RSLCT
	POP	IY
	POP	BC
	POP	AF
	RET

BRSLCTE:			;$HXC_RSLCT error exit
	$BREAK	/$HXC_RSLCT!
	LD	(XNOHXC),A
	OR	A
	POP	IY
	POP	BC
	EX	(SP),HL
	POP	HL
	RET


;-----	GTDCT - Get DCT
;	IN:	C = Drive #
;	OUT:	IY = &DCT[C]
	IF	BANKS
$HXC_GTDCT:
;	$$BREAK
	PUSH	HL
	LD	HL,XPDCTS
	LD	A,C
	ADD	A,A
	ADD	A,L
	LD	L,A
	ADC	A,H
	SUB	L
	LD	H,A
	LD	A,(HL)
	INC	HL
	LD	H,(HL)
	LD	L,A
	EX	(SP),HL
	POP	IY
	RET
	ENDIF

;-----	END CODE SEG ADDRESS
FILE_END:

;==============================================================

	$ALIGN	6
	IF	BANKS
	DC	128,'$'		; stack space
HXC_STACK:			; top of stack
	DB	'[HXCSTACK]'
	ENDIF

XPHOST:	DB	0FFH		; physical host drive
XHOSTDCT:
	DW	-1		; logical host drive DCT
XHNDL:	DW	0		; current handle
XNXFCB:	DW	-1		; not XFCB because of relocation!!

	$MSG	FMASK
XFMASK:	DS	11
	$MSG	/FMASK
XDIRCLU:
	DW	2,0		; current dir 1st clus (root dir)
XOFFSET:
	DC	4,0		; file offset (LSEEK)
XSECREADY:
	DB	0		; sector ready
XSECDIRTY:
	DB	0		; sector dirty
XCURHNDL:
	DW	0		; current handle
XCURFRS:
	DC	4,0BDH		; cur frs
XNEWFRS:
	DC	4,0		; new frs
XNOHXC:
	DB	0		; not 0 if no HxC found

MERR_NOHXCFEDA:
	DB	'No HxC2001'
	DB	0DH

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA Segment

	$MSG	XFCB
XFCB:	DS	FCBSIZE*NFCBS
XFCBEND	EQU	$
	$MSG	/XFCB

	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$RELO	; RELO segment

CSEG_FILE 	MACRO
	DW	FILE_BEGIN,FILE_END
	ENDM

	ENDIF			; RELO segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END
