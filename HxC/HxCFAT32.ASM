;
;	HXCFAT32/ASM	FAT32 Routines
;
;	MVPART		Move to partition A (1-4)
;	MVDIR		Select Directory Entry A in curr page (0-7)
;	INDIR		Enter Directory Entry (HL=dir entry ptr, DE=LBA ptr)
;	CLU2LBA		convert cluster # to LBA (HL=Cluster ptr (in)/LBA ptr (out))
;	FCBOENT		Open FCB from Directory Entry (HL=FCB ptr, DE=dir entry ptr)
;	FCBINIT		Init FCB from Directory Entry (HL=FCB ptr->1st cluster, DE=dir entry ptr)
;	FCBOPEN		(Re)open FCB by cluster (HL=FCB, 1st cluster at beginning of FCB)
;	GETCSEG		Get next cluster chain segment (IX=FCB)
;	LEAIX		Load effective address HL=IX+HL
;	SEEKFRS		Seek Set ((HL)=FCB, DE=FRS)
;	SEEKNSEC	Seek next sector (in:(HL)=FCB, out:(HL)=LBA)
;	READNSEC	Read next sector (in:(HL)=FCB, out:A,Z=Error code)
;	WRITENSEC	Write next sector (in:(HL)=FCB, out:A,Z=Error code)
;	GETNBYTES	Get # of bytes in current sector to BC
;	GETFMASK	Extract file name to fmask ((HL)=file name, (DE)=fmask (11 bytes))
;	FINDFILE	Find filespec
;	READLBA		Read LBA sector
;	WRITELBA	Write LBA sector

*MOD
BRK	DEFL	0		;Enable breakpoints


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

LAST$	DEFL	$

;-----	closed FCB struct
	ORG	0
FCBNAM	DS	8		;file name, space padded
FCBEXT	DS	3		;file ext, space padded
FCBATT	DS	1		;file attr

;-----	opened FCB struct
	ORG	0
FCBCLU0	DS	4		;00 = first cluster
FCBLBA0	DS	4		;04 = current chain seg first LBA
FCBSEGS	DS	4		;08 = current chain seg start clus
FCBSEGN	DS	4		;0C = next chain seg start clus
FCBSEGO	DS	2		;10 = curr chain clus offset
FCBSEGL	DS	2		;12 = curr chain seg length
FCBSEGB	DS	4		;14 = curr chain seg begin (frs)
FCBSEGE	DS	4		;18 = curr chain seg end (frs)
FCBCFRS	DS	4		;1C = file current sect
FCBNFRS	DS	4		;20 = next file sect ptr
FCBNSEC	DS	4		;24 = number of 512-byte sects in file
FCBEOF	DS	2		;28 = last sect EOF ptr
FCBFLGS	DS	2		;2A = Flags
FCBEND	EQU	$		;2B
;FCBSIZE	EQU	30H
FCBSIZE	EQU	FCBEND

;-----	FCB flags
FCB$FRG	EQU	0		;0 = file is fragmented

;	FCBLBA0	SECPCLU	FCBNSEC
;	01AC38	08	020201

;	STACLU	ENDCL+1	NCLUS	STAFRS	ENDFRS	STALBA
;	3288	59E9	2761	000000	013B08	01A438
;	955D	AE46	18E0	013B08	020208


;	FRS	STAFRS	FCBLBA0	LBA
;	000000	000000	01AC38	01AC38
;	015401	013B08	O1AC38	01C531
;	01DF80	013B08	01AC38	0250B0



	IF	FCBCLU0+FCBSIZE.LT.FCBEND
	ERR	FCB Size overflow
	ENDIF

;===============================
	ORG	LAST$

	$MSG	HxCFAT32

FAT32_BEGIN:

;-----	Move to partition A
;	IN:	A = selected partition (1-4)
MVPART:	$BREAK	MVPART
	OR	A
	LD	H,A
	LD	L,A
	LD	E,A
	LD	D,A
	LD	(XLBA0),HL	;Clear part base LBA
	LD	(XLBA0+2),DE
	RET	Z		;exit if MBR (0)

	PUSH	AF
	LD	HL,0
	LD	(XLBA),HL	;select LBA 0
	LD	(XLBA+2),HL

	;$BREAK
	LD	HL,XLBA		;read MBR
	CALL	READLBA

	LD	HL,BUF512+1BEH-10H ;Part table - 10H
	POP	AF

	RLCA			;seek part table entry
	RLCA
	RLCA
	RLCA
	ADD	A,L
	LD	L,A
	LD	A,H
	ADC	A,0
	LD	H,A

;MVPAR1:
	PUSH	HL
	POP	IX
	LD	A,(IX+4)	;get part type
	CP	0CH		;FAT32 LBA ?
	JR	Z,MVPAR1	;go on if yes
	LD	HL,MNOFAT32	;'No FAT32 LBA partition'
;	$SVC	@DSPLY
	CALL	DISM
	LD	A,8		;ERROR: "device not found"
	$BREAK	/MVPART!08
	OR	A
	RET

MVPAR1:	LD	L,(IX+8)	;get part base LBA
	LD	H,(IX+9)
	LD	E,(IX+10)
	LD	D,(IX+11)

	LD	(XLBAPAR),HL	;Part base LBA
	LD	(XLBAPAR+2),DE

	LD	(XLBA0),HL	;base LBA
	LD	(XLBA0+2),DE

	LD	(XLBA),HL	;Abs LBA
	LD	(XLBA+2),DE

;	$BREAK

	LD	HL,XLBA		;read PBR
	CALL	READLBA

	LD	IX,BUF512	;get PBR info

	LD	A,(IX+0DH)	;sectors per cluster
	LD	(XNSECCL),A

	LD	L,(IX+0EH)	;FAT relative LBA
	LD	H,(IX+0FH)
	LD	DE,(XLBA0)
	ADD	HL,DE
	LD	(XLBAFAT),HL	;FAT base LBA
	LD	HL,0
	LD	DE,(XLBA0+2)
	ADC	HL,DE
	LD	(XLBAFAT+2),HL

	;$BREAK
	LD	DE,XLBAFAT	;FAT base LBA
	LD	HL,XLBARCL	;root cluster LBA
	CALL	MOV32		;(HL) := (DE)

	EX	DE,HL
	LD	HL,0024H	;# of sectors per fat
	CALL	LEAIX
	EX	DE,HL

MVPAR0:	CALL	ADD32		;(HL) += (DE)
	DEC	(IX+10H)	;# of copies of FAT
	JR	NZ,MVPAR0

	LD	HL,2CH		;root cluster #
	CALL	LEAIX
	LD	DE,XROOTCL
	CALL	STO32

	XOR	A

	$BREAK	/MVPART
MVPARX:	OR	A		;clear CF
	RET


;-----	Select Directory Entry (not used by HxCHard)
;	IN	A = entry # in current page (0-7)
MVDIR:	LD	L,A
	LD	H,0
	ADD	HL,HL		;mul by 0x20
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	LD	DE,BUF512	;1st cluster
	ADD	HL,DE
	LD	DE,XLBA0
;fall thru


;-----	Enter Directory Entry
;	IN	HL = dir entry ptr
;		DE = LBA ptr
;	OUT	HL, DE unchanged
INDIR:
	PUSH	HL
	PUSH	DE
	PUSH	HL
	POP	IX
	EX	DE,HL		;1st cluster to LBA ptr
	LD	A,(IX+1AH)
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
	DEC	HL
	DEC	HL
	DEC	HL
	CALL	CLU2LBA		;convert cluster # to LBA
	POP	DE
	POP	HL
	RET


;-----	convert cluster # to LBA
;	IN/OUT:	HL = Cluster ptr (in) / LBA ptr (out)
;	USED:	A
CLU2LBA:
	PUSH	DE
	LD	DE,XROOTCL
	CALL	SUB32		;subtract root cluster #
	LD	A,(XNSECCL)	;cluster size
	CALL	MUL328
	LD	DE,XLBARCL	;root cluster
	CALL	ADD32
	POP	DE
	RET


;-----	Init FCB from Directory Entry (HL=FCB ptr->1st cluster, DE=dir entry ptr)
;	IN	HL = FCB ptr
;		DE = dir entry ptr
;	OUT	HL,IX = FCB ptr
;		HL->FCBCLU0 = 00 = first cluster
;		HL->FCBNSEC = 24 = number of 512-byte sects in file
;		HL->FCBEOF  = 28 = last sect EOF ptr
;	USED	A,DE,IX
FCBINIT:
;	$BREAK	FCBINIT
	PUSH	DE		;dir ent
	POP	IX
	PUSH	HL		;FCB ptr
	LD	A,(IX+1AH)
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
	LD	A,(IX+0BH)	;attribs
	AND	10H		;is dir?
	LD	DE,XMIN512L	;constant -512
	JR	NZ,BFOENT1
	LD	HL,001CH	;file size offs
	CALL	LEAIX
	EX	DE,HL		;to DE
BFOENT1:
	POP	IX
	PUSH	IX		;FCB

	LD	HL,FCBNSEC	;# of sectors
	CALL	LEAIX
	CALL	MOV32		; := file size
	LD	E,(HL)		;get EOF
	INC	HL
	LD	A,(HL)
	DEC	HL
	AND	1
	LD	D,A
	PUSH	DE
	LD	DE,X511L	; constant 511
	CALL	ADD32		; +=511 -> full sector
	LD	A,9
	CALL	SHR32		; /=512 -> # of sectors
	POP	DE
	LD	HL,FCBEOF	;last sector EOF
	CALL	LEAIX
	LD	(HL),E
	INC	HL
	LD	(HL),D

	POP	HL

	RET

;-----	Open FCB from Directory Entry
;	IN	HL = FCB ptr
;		DE = dir entry ptr
;	OUT	HL,IX = FCB ptr
;		HL->FCBCLU0 = 00 = first cluster
;		HL->FCBSEGS = 08 = current chain seg start clus
;		HL->FCBSEGN = 0C = next seg start clus
;		HL->FCBSEGO = 10 = curr chain clus offset
;		HL->FCBSEGL = 12 = curr chain seg length
;		HL->FCBSEGE = 18 = curr chain seg end (frs)
;		HL->FCBCFRS = 1C = file current sect
;		HL->FCBNFRS = 20 = next file sect ptr
;		HL->FCBNSEC = 24 = number of 512-byte sects in file
;		HL->FCBEOF  = 28 = last sect EOF ptr
;	USED	A,HL,DE,IX
FCBOENT:
	CALL	FCBINIT
	; go through

;-----	Open FCB by cluster
;	IN	HL = FCB (1st cluster at beginning of FCB)
;	OUT	Z, A = 0
FCBOPEN:
	$BREAK	FCBOPEN
	PUSH	BC
	PUSH	DE
	PUSH	HL
	PUSH	HL
	POP	IX
	EX	DE,HL		;clus1 ptr to DE

	LD	HL,FCBSEGS	;curr chain seg start clus
	CALL	LEAIX
	CALL	MOV32		; := FCBCLU0 = first cluster

	LD	HL,FCBSEGO	;zero offs
	CALL	LEAIX
	XOR	A
	LD	(HL),A
	INC	HL
	LD	(HL),A

	LD	(IX+FCBFLGS),A	;clear flags

	LD	HL,FCBSEGE	;segment end frs
	CALL	LEAIX
	CALL	ZERO32		; := 0

	LD	HL,FCBNFRS	;next file sector
	CALL	LEAIX
	CALL	ZERO32		; := 0

	LD	HL,FCBCFRS	;current file sector
	CALL	LEAIX
	CALL	ZERO32
	CALL	DEC32		; := -1

	CALL	GETCSEG		;get chain seg

	POP	HL
	POP	DE
	POP	BC
	$BREAK	/FCBOPEN
	RET
;
;
;-----	Get next cluster chain segment
;	IN	IX = FCB
;		FCBSEGS = seg start clus
;	OUT	FCBSEGN = next seg start clus
;		FCBSEGL = curr chain seg length
;		Z, A = 0
;	USED	A,BC,DE
GETCSEG:
;	LBA=Clus*4/512=Clus*2/256
; get FAT offset (LBA+sector byte)
;	$$BREAK
	PUSH	HL

	LD	HL,FCBSEGE	;seg end frs
	CALL	LEAIX
	EX	DE,HL

	LD	HL,FCBSEGB	;seg beg frs
	CALL	LEAIX
	CALL	MOV32		; := seg end frs

	LD	HL,FCBSEGS
	CALL	LEAIX		;HL=seg start clus
	EX	DE,HL		;to DE

	LD	HL,FCBLBA0
	CALL	LEAIX		;LBA0 ptr
	CALL	MOV32		;(HL)=(DE)
	CALL	CLU2LBA		;get start LBA

	LD	HL,FCBSEGN
	CALL	LEAIX		;HL=next seg start clus
	LD	(XFCBSN),HL	;store to FCBSEGN ptr
	CALL	MOV32		;store start clus

	LD	HL,FCBSEGL	;zero seg len
	CALL	LEAIX
	LD	(XFCBSL),HL
	XOR	A
	LD	(HL),A
	INC	HL
	LD	(HL),A

	LD	HL,XVAR1	;FAT sect LBA
	CALL	MOV32		;(HL)=(DE) (=start clus)
	LD	A,2		;*= 4 bytes
	CALL	SHL32
	LD	E,(HL)		;DE = FAT offs
	INC	HL
	LD	A,(HL)
	DEC	HL
	AND	1
	LD	D,A
	PUSH	DE		;save byte offs
	LD	A,9		;/= 512
	CALL	SHR32
	LD	DE,XLBAFAT	;+= FAT LBA
	CALL	ADD32
	POP	DE		;byte offs
BGCSE0:				;loop on FAT sectors
	CALL	READLBA		;read at LBA @ HL
	LD	HL,BUF512
	ADD	HL,DE
BGCSE1:				;loop on FAT entries
;	$BREAK
	PUSH	HL
	PUSH	DE
	EX	DE,HL
	PUSH	DE
	LD	DE,XNSECCL
	LD	HL,FCBSEGE
	CALL	LEAIX
	CALL	ADD32		;fcb end frs += sects per cluster
	POP	DE
	LD	HL,(XFCBSL)	;count 1 clus
	INC	(HL)		;inc lsb
	JR	NZ,$+4		;if lsb not null skip next 2 instr
	INC	HL
	INC	(HL)		;inc msb
	LD	HL,(XFCBSN)	;bump next seg start clus
	CALL	INC32
	CALL	CMP32		;next clus in same seg?
	POP	DE		;byte offs to DE
	POP	HL		;FAT byte ptr

	JR	NZ,BGCSE2	;exit loop if not

	LD	BC,4		;bump ptr & offs
	ADD	HL,BC
	EX	DE,HL
	ADD	HL,BC
	EX	DE,HL

	BIT	1,D		;end of FAT sector?
	JR	Z,BGCSE1	;loop if not

	LD	HL,XVAR1
	CALL	INC32		;next sector
	LD	DE,0		;reset offset
	JR	BGCSE0		;loop

BGCSE2:
;	$$BREAK
	PUSH	HL		;FAT entry ptr
	INC	HL
	INC	HL
	INC	HL
	LD	A,(HL)
	OR	A		;end of file
	JR	NZ,BGCSE3	;jump if yes
				;else set 'fragmented' flag
	SET	FCB$FRG,(IX+FCBFLGS)
BGCSE3:
	POP	DE		;FAT entry ptr
	LD	HL,(XFCBSN)
	CALL	MOV32		;as next seg start clus

	POP	HL

	XOR	A		; success
	RET


;-----	Load effective address HL=IX+HL
;	IN	IX = base ptr
;		HL = offset
;	OUT	HL = IX + HL
LEAIX:
	EX	DE,HL
	PUSH	IX
	EX	(SP),HL
	ADD	HL,DE
	POP	DE
	RET


;-----	Seek Set
;	IN	(HL) = FCB
;		DE = FRS
SEEKFRS:
;	$BREAK
	PUSH	BC
	PUSH	HL

	PUSH	DE
	PUSH	HL
	POP	IX
	EX	DE,HL		;1st clus to DE (FCBCLU0)

	LD	HL,FCBNFRS	;set next frs
	CALL	LEAIX
	POP	DE		;frs
	CALL	MOV32

	POP	HL
	POP	BC
	XOR	A
	RET


;-----	Sub to Seek next sector
;	IN:	(HL) = FCB
;	OUT:	(HL) = LBA
SEEKNSEC:
	$BREAK	SEEKNSEC
	PUSH	HL
	POP	IX
	LD	HL,FCBNSEC	;total sectors
	CALL	LEAIX
	EX	DE,HL
	LD	HL,FCBNFRS	;next frs ptr
	CALL	LEAIX
	CALL	CMP32		;next>=total?
	JR	C,BSEEKNSEC1	;jump if no

BSEEKNSEC0:
	$BREAK	/SEEKNSEC!28
	LD	A,28		;reading past EOF
	OR	A
	RET

BSEEKNSEC1:			;loop to find segment
	EX	DE,HL
	LD	HL,FCBSEGE	;seg end frs ?
	CALL	LEAIX
	EX	DE,HL
	CALL	CMP32		;next >= seg end?
	JR	NC,BSEEKNSEC2	;jump if yes: load next chain

	EX	DE,HL
	LD	HL,FCBSEGB	;seg begin frs ?
	CALL	LEAIX
	EX	DE,HL
	CALL	CMP32		;next >= seg start?
	JR	NC,BSEEKNSECR	;jump if yes: get sector

				;load 1st chain
;	$$BREAK
	PUSH	IX
	POP	DE		;FCBCLU0
	LD	HL,FCBSEGS	;seg 1st clus
	CALL	LEAIX
	CALL	MOV32		;reset seg 1st clus

	LD	HL,FCBSEGO	;zero offs
	CALL	LEAIX
	XOR	A
	LD	(HL),A
	INC	HL
	LD	(HL),A

	LD	HL,FCBSEGE	;segment end frs
	CALL	LEAIX
	CALL	ZERO32		; := 0
	JR	BSEEKNSEC3	;reload 1st chain

BSEEKNSEC2:
	LD	HL,FCBSEGN	;next seg clus
	CALL	LEAIX
	INC	HL
	INC	HL
	INC	HL
	LD	A,(HL)		;get MSB
	DEC	HL
	DEC	HL
	DEC	HL
	OR	A
	JR	NZ,BSEEKNSEC0	;eof exit

	;$BREAK	CALL GETCSEG
	EX	DE,HL		;next seg clus to DE
	LD	HL,FCBSEGS
	CALL	LEAIX		;HL = seg start clus
	CALL	MOV32		; := next seg clus
BSEEKNSEC3:
	CALL	GETCSEG		;get next chain seg

	LD	HL,FCBNFRS
	CALL	LEAIX
	JR	BSEEKNSEC1	;loop

BSEEKNSECR:			;segment OK
	EX	DE,HL		;next FRS to DE
	LD	HL,FCBCFRS	;curr FRS
	CALL	LEAIX
	CALL	MOV32		; := next FRS
	EX	DE,HL
	CALL	INC32		;++next FRS
	LD	HL,XVAR1
	CALL	MOV32		;xvar1 := curr frs
;	$$BREAK
	EX	DE,HL
	LD	HL,FCBSEGB	;curr chain seg begin (frs)
	CALL	LEAIX
	EX	DE,HL
	CALL	SUB32		; -= seg beg frs
	EX	DE,HL
	LD	HL,FCBLBA0	;first LBA
	CALL	LEAIX
	EX	DE,HL
	CALL	ADD32		; += seg beg lba
	$BREAK	/SEEKNSEC
	XOR	A
	RET


;-----	Read next sector
;	IN	(HL) = FCB
;	OUT	A,Z = Error code
READNSEC:
;	$BREAK	READNSEC
	IF	DBG
	CALL	FCBDEBUG
	ENDIF
	PUSH	BC
	PUSH	DE
	PUSH	HL

	CALL	SEEKNSEC
	CALL	Z,READLBA

BREADNSECX:
	POP	HL
	POP	DE
	POP	BC
	OR	A
	RET


;-----	Write next sector
;	IN	(HL) = FCB
;	OUT	A,Z = Error code
WRITENSEC:
	$BREAK	WRITENSEC
	IF	DBG
	CALL	FCBDEBUG
	ENDIF
	PUSH	BC
	PUSH	DE
	PUSH	HL

	CALL	SEEKNSEC
	CALL	Z,WRITELBA

BWRITENSECX:
	POP	HL
	POP	DE
	POP	BC
	OR	A
	$BREAK	/WRITENSEC
	RET


;-----	Get # of bytes in current sector (not used by HxCHARD)
;	IN	(HL) = FCB
;	OUT	BC = # bytes (0=EOF)
;		Z,!A = past EOF
GETNBYTES:
	$BREAK	GETNBYTES
	PUSH	DE
	PUSH	HL
	PUSH	HL
	POP	IX
	LD	HL,FCBNSEC	;total # sect
	CALL	LEAIX
	EX	DE,HL
	LD	HL,FCBNFRS	;next frs
	CALL	LEAIX
	CALL	CMP32		;next frs < # sect ?
	JR	C,BGETNB2	;not last sect
	LD	BC,0
	JR	NZ,BGETNBX	;past EOF
	LD	C,(IX+FCBEOF)
	LD	B,(IX+FCBEOF+1)
	LD	A,C
	OR	B
	JR	NZ,BGETNBX
BGETNB2:
	LD	BC,0200H
BGETNBX:
	LD	A,B
	OR	C
	POP	HL
	POP	DE
	RET


;-----	Extract MS-DOS file name to fmask
;	IN	(HL) = input file name
;		(DE) = fmask (11 bytes)
GETFMASK:
;	$BREAK	GETFMASK
	PUSH	BC
	PUSH	DE
;	PUSH	HL
;
;	get 8-char name part
;
	LD	BC,0803H	;8+3 chars
BGETFM0:
	LD	A,(HL)		;get name char
	INC	HL		;bump input ptr
	CP	'.'		;if dot
	JR	Z,BGETFM00	;  pad name and parse ext
	CP	','		;if comma
	JR	Z,BGETFMX	;  pad name+ext
	CP	'!'		;if space or ctrl char
	JR	C,BGETFMX	;  pad name+ext
	LD	(DE),A		;put char
	INC	DE		;  into fmask
	DJNZ	BGETFM0		;8 times
;
;	skip remaining chars of name part
;
BGETFM000:
	LD	A,(HL)		;get name char
	INC	HL		;bump input ptr
	CP	'.'		;if dot
	JR	Z,BGETFM02	;  parse ext
	CP	','		;if comma
	JR	Z,BGETFMX	;  pad name+ext
	CP	'!'		;if space or ctrl char
	JR	C,BGETFMX	;  pad name+ext
	JR	BGETFM000	;loop
;
;	pad name part
;
BGETFM00:
	LD	A,B		;positions to pad?
	OR	A		;
	JR	Z,BGETFM02	;go if not
	LD	A,' '		;pad with space
BGETFM01:
	LD	(DE),A		;put space
	INC	DE		;next pos
	DJNZ	BGETFM01	;loop
;
;	get 3-char ext part
;
BGETFM02:
	LD	BC,0300H	;3 chars to get
BGETFM1:
	LD	A,(HL)		;get ext char
	INC	HL		;bump
	CP	'.'		;dot ?
	JR	Z,BGETFMX	;if yes, pad remaining pos
	CP	','		;comma ?
	JR	Z,BGETFMX	;if yes, pad remaining pos
	CP	'!'		;space or ctrl char?
	JR	C,BGETFMX	;if yes, pad remaining pos
	LD	(DE),A		;put char into fmask
	INC	DE		;bump output ptr
	DJNZ	BGETFM1		;3 times max
;
;	pad remaining pos
;
BGETFMX:
	LD	A,B		;remaining name or ext chars
	ADD	A,C		;add remaining ext chars or 0
	JR	Z,BGETFMX2	;go if no position to pad
	LD	B,A		;loop ctr
	LD	A,' '		;pad with space
BGETFMX1:
	LD	(DE),A		;put space
	INC	DE		;next pos
	DJNZ	BGETFMX1	;loop
BGETFMX2:
	DEC	HL
	;POP	HL		;restore regs and exit
	POP	DE
	POP	BC
	RET



;-----	Find filespec
;	IN	(HL) = dir fcb
;		(DE) = fmask
;	OUT	(HL) = (IX) = dir ent if found
;		(HL) = dir fcb if not found
;		Z = found
;		A = error code
FINDFILE:
;	$BREAK	FINDFILE
	PUSH	DE
	LD	DE,X0L
	CALL	SEEKFRS		;start of dir
	POP	DE
BFFIL00:
	CALL	READNSEC	;read next sector
	JR	Z,BFFILE0	;go if no error
	CP	28		;EOF?
	RET	NZ		;return if not
	ADD	A,24-28		;file not found & NZ
	RET
BFFILE0:
	PUSH	HL		;save dir FCB
	LD	B,16
	LD	HL,BUF512
BFFILE1:
	PUSH	BC
	PUSH	DE
	PUSH	HL		;save dir entry
	PUSH	HL
	POP	IX
	LD	A,(HL)
	OR	A		;null?
	JR	Z,BFFILEE	;exit if yes
	CP	0E5H		;deleted?
	JR	Z,BFFILEN	;next if yes
	LD	A,(IX+0BH)	;attrib
	CP	0FH		;Long name?
	JR	Z,BFFILEN	;next if yes

	LD	B,11
BFFILE2:
	LD	A,(DE)
	INC	DE
	CP	(HL)
	INC	HL
	JR	NZ,BFFILEN	;next if mismatch
	DJNZ	BFFILE2
	XOR	A
	JR	BFFILEX		;found !!

BFFILEN:
	POP	HL		;rest dir entry
	LD	DE,20H		;bump to next
	ADD	HL,DE
	POP	DE
	POP	BC
	DJNZ	BFFILE1		;loop
	POP	HL		;rest dir fcb
	JR	BFFIL00

BFFILEE:
	LD	A,24		;file not found
BFFILEX:
	POP	HL		;DIR normal exit
	POP	DE
	POP	BC
	INC	SP
	INC	SP
	OR	A
	RET


;-----	Sub to set LBA block address and relative sector
RWSETLBA:
	$BREAK	RWSETLBA
	CALL	DAMON
	JR	NZ,$?ALARM		;nasty !!
	EX	DE,HL
	LD	HL,XLBA8
	CALL	MOV32
	LD	A,(HL)
	PUSH	AF
	AND	100H-BLKSIZE		;FF,FE,FC,F8
	LD	(HL),A
	CALL	SETLBA
	POP	AF
	AND	BLKSIZE-1		;00,01,03,07
	INC	A
	LD	HL,BUF512
	RET
;
;	FAULT ALARM
;
$?ALARM:
	INC	A
	OUT	(90H),A
	LD	B,C
	DJNZ	$
	INC	C
	JR	$?ALARM

;-----	Read LBA sector
;	IN	(HL) = LBA
;	USED	A,BC
READLBA:
	IF	CACHE
	CALL	CACHE_GET
	RET	Z
	ENDIF

	$BREAK	READLBA
	PUSH	DE
	PUSH	HL
	CALL	RWSETLBA
	PUSH	DE
	CALL	RDSECT
	POP	DE
	POP	HL

	IF	CACHE
	CALL	CACHE_PUT
	ENDIF

	LD	A,(XERROR)
	IF	DBG
	CALL	LBADEBUG
	ENDIF
	$BREAK	/READLBA
	POP	DE
	OR	A
	RET


;-----	Write LBA sector
;	IN	(HL) = LBA
;	USED	A,BC
WRITELBA:
	$BREAK	WRITELBA
	PUSH	DE
	PUSH	HL
	CALL	RWSETLBA
	PUSH	DE
	CALL	WRSECT
	POP	DE
	POP	HL

	IF	CACHE
	CALL	CACHE_PUT
	ENDIF

	LD	A,(XERROR)
	IF	DBG
	CALL	LBADEBUG
	ENDIF
	POP	DE
	OR	A
	$BREAK	/WRITELBA
	RET


;-----	Debug LBA
	IF	DBG
LBADEBUG:
	PUSH	AF
	PUSH	HL
	CALL	BUFCLS
	LD	HL,BUF512
	LD	D,'a'
	CALL	LBADBG1
	LD	HL,BUF512+100H
	LD	D,'b'
	CALL	LBADBG1
	POP	HL
	POP	AF
	RET

LBADBG1:
	LD	IY,DSPBUF+6
	CALL	PUTPAG
	LD	IY,DSPBUF
	CALL	PUTMPC
	DB	'LBA',0
	LD	IY,DSPBUF+1280
	CALL	PUTMPC
	DB	'      LBA:',0
	POP	BC
	POP	HL
	PUSH	HL
	PUSH	BC
	CALL	PUTHEX4
	LD	A,D
	CALL	PUTCHR
	CALL	SCRSAVE
	CALL	PUTDSP
	CALL	WAITKI
	CALL	SCRREST
	RET

FCBDEBUG:
	PUSH	HL
	PUSH	DE
	CALL	BUFCLS
	LD	IY,DSPBUF+6
	CALL	PUTPAG
	LD	IY,DSPBUF
	CALL	PUTMPC
	DB	'FCB',0
	CALL	SCRSAVE
	CALL	PUTDSP
	CALL	WAITKI
	CALL	SCRREST
	POP	DE
	POP	HL
	RET

;-----	Save screen
SCRSAVE:
;	$BREAK
	PUSH	HL
	PUSH	BC
	LD	HL,XSCRSAVE
	LD	B,6		;Video To Buffer
	$SVC	@VDCTL
	POP	BC
	POP	HL
	RET

;-----	Restore screen
SCRREST:
	PUSH	HL
	PUSH	BC
	LD	HL,XSCRSAVE
	LD	B,5		;Buffer To Video
	$SVC	@VDCTL
	POP	BC
	POP	HL
	RET

	ENDIF

;=====	BEGIN CACHE CODE PART
	IF	CACHE

;-----	Initialize cache ptrs
CACHE_INIT:
	LD	A,(XBANK)
	OR	A
	RET	Z
	$BREAK	CACHE_INIT
	PUSH	HL
	LD	HL,XCINIT
	LD	A,(HL)
	OR	A
	JR	NZ,$CACHE_INIT3
	$BREAK	CACHE_INIT:DO
	DEC	(HL)
	PUSH	DE
	PUSH	BC
	LD	B,CACHE_NSECS
	LD	DE,CACHE_SECS
	LD	HL,CACHE_STACK
	LD	A,0FFH
$CACHE_INIT1:
	LD	(HL),E		;write LBA buffer address in stack
	INC	HL
	LD	(HL),D
	INC	HL
	LD	C,4
$CACHE_INIT2:
	LD	(DE),A		;write LBA = 0FFFFFFFFH
	INC	DE
	DEC	C
	JR	NZ,$CACHE_INIT2
	INC	D		;DE += LBA sector size = 200H
	INC	D
	DJNZ	$CACHE_INIT1
	POP	BC
	POP	DE
$CACHE_INIT3:
	$BREAK	/CACHE_INIT
	POP	HL
	XOR	A
	RET

;-----	Seek cache
;	IN:	HL = (LBA)
;	OUT:	DE = Sector buffer (if Z)
;		HL = stack entry ptr
;		Z if found
CACHE_SEEK:
	PUSH	HL		;LBA ptr
	LD	BC,CACHE_NSECS<8
	LD	HL,CACHE_STACK
$CACHE_SEEK1:
	INC	C
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	INC	HL
	EX	(SP),HL
	CALL	CMP32
	EX	(SP),HL
	LD	A,0		;exit code OK
	JR	Z,$CACHE_SEEK2
	DJNZ	$CACHE_SEEK1
	DEC	A		;exit code NOK, NZ
$CACHE_SEEK2:
	PUSH	AF		;save Z/NZ
	DEC	HL
	PUSH	DE		;save buf ptr
	LD	D,H
	LD	E,L
	DEC	HL
	DEC	HL
	DEC	C
	JR	Z,$CACHE_SEEK3	;go if first ptr
	SLA	C		;move stack
	LD	B,0		;
	LDDR			;
$CACHE_SEEK3:
	INC	HL
	POP	DE		;rest buf ptr
	LD	(HL),E		;insert most recent ptr
	INC	HL
	LD	(HL),D
	DEC	HL
	POP	AF		;rest Z/NZ
	EX	(SP),HL		;stk ptr <-> LBA ptr
	LD	BC,4		;save LBA
	LDIR			;
	POP	HL		;stk ptr
	RET

CACHE_GET:
	LD	A,(XBANK)
	OR	A
	JR	NZ,$CACHE_GET1
	DEC	A		;set NZ and exit
	RET
$CACHE_GET1:
;	$$BREAK
	PUSH	HL
	PUSH	DE
	PUSH	BC
	CALL	CACHE_SEEK
	JR	NZ,$CACHE_GETX
	LD	HL,BUF512
	EX	DE,HL
$CACHE_GET2:
	LD	BC,200H
	LDIR
$CACHE_GETX:
	POP	BC
	POP	DE
	POP	HL
	RET

CACHE_PUT:
	LD	A,(XBANK)
	OR	A
	JR	NZ,$CACHE_PUT1
	DEC	A		;set NZ and exit
	RET
$CACHE_PUT1:
;	$$BREAK
	PUSH	HL
	PUSH	DE
	PUSH	BC
	CALL	CACHE_SEEK
	LD	HL,BUF512
	JR	$CACHE_GET2

	ENDIF			;end IF CACHE
;=====	END CACHE CODE PART

;-----	End code part
FAT32_END:
	$MSG	/HxCFAT32

;-----	Begin data part

;=====	CACHE Data Section
	IF	CACHE
	IF	TRC+DBG+BRK+TER
CACHE_NSECS	EQU	44
	ELSE
CACHE_NSECS	EQU	55	;55
	ENDIF
CACHE_LIMIT	EQU	0F000H
CACHE_SECS	EQU	8000H
CACHE_STACK	EQU	204H*CACHE_NSECS+CACHE_SECS
CACHE_END	EQU	2*CACHE_NSECS+CACHE_STACK
XCINIT	DB	0		;255 when initialized
;	IF	CACHE_LIMIT.LT.CACHE_END
;	ERR	CACHE Size Overflow
;	ENDIF
	ENDIF
;=====	END Cache Data Section

	IF	DBG
XSCRSAVE:
	DS	2048
	ENDIF

MNOFAT32:
	DB	'**No FAT32/LBA**',0DH

XMIN512L:
	DW	-512,-1		;constant -1
XMIN1L	DW	-1,-1		;constant -1
X511L	DW	511,0		;constant 511L
X2L	DW	2,0		;constant 2L
X0L	DW	0,0		;constant 0L
XFCBSN	DW	0		;FCBSEGN ptr
XFCBSL	DW	0		;FCBSEGL ptr
XVAR1	DC	4,0		;Variable 1
XLBA0	DC	4,0		;Base LBA
XLBA8	DC	4,0		;Aligned Base LBA
XLBAPAR	DC	4,0		;Partition Base LBA
XLBAFAT	DC	4,0		;FAT Base LBA
XLBARCL	DC	4,0		;Root Cluster LBA
XROOTCL	DW	2,0		;Root Cluster #
XNSECCL	DW	64,0		;number of sectors per cluster (cluster size)

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$RELO	; RELO segment

CSEG_FAT32 	MACRO
	DW	FAT32_BEGIN,FAT32_END
	ENDM

	ENDIF			; RELO segment
;++++++++++++++++++++++++++++++++++++++++++++++++


	END
