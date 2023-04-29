;
;	HXCFDC/ASM	HxC low level FDC routines
;
;	RESTOR		Restore to Track 0
;	SEEK		Seek track to A w/o verify
;	RDADDR		Read Address (HL=buffer)
;	RDSECT		Read sector (HL=buffer, A=sect#)
;	RDSTAT		Read status buffer
;	WRSECT		Write sector (HL=buffer, A=sect#)
;	WRCMND		Write command buffer

*MOD
BRK	DEFL	0		;Enable breakpoints

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

	IFEQ	MODEL,4
VECNMI	EQU	0066H		;NMI vector
	ENDIF
	IFEQ	MODEL,3
VECNMI	EQU	4049H		;NMI vector
	ENDIF

DAMTRK	EQU	255

	$MSG	HxCFDC

FDC_BEGIN:

;-----	Save NMI Vector
SAVNMI:
	LD	HL,VECNMI	;system NMI vector
	LD	DE,XVCNMI	;location to save
	LD	A,(DE)		;initially 0
	OR	A
	RET	NZ		;return if already saved
	$BREAK	!SAVNMI
	JR	MOV3		;move NMI vector

;-----	Restore NMI Vector
RESNMI:
	LD	HL,XVCNMI	;from saved NMI
	LD	DE,VECNMI	;to system NMI vector
MOV3:	LD	BC,3		;move
	LDIR
	RET

;-----	Set NMI Vector to HL
SETNMI:
	LD	A,0C3H		;C3 = JP nnnn
	LD	(VECNMI),A
	LD	(VECNMI+1),HL
	RET

;-----	Restore to Track 0
RESTOR:
	NOP			;skip reloc
	LD	DE,'Rs'
	LD	(XLSCMD),DE	;last command label
	LD	A,(XDRIVE)
	OUT	(0F4H),A
	XOR	A
	OUT	(0E4H),A	;disable NMI
	CALL	WAIT8
	LD	A,08H		;Restore
	OUT	(0F0H),A
	CALL	WNOTB0
	XOR	A
	LD	(XLSTRK),A	;init current physical track
	RET

;------	Seek track w/o verify
;	IN	A = dest track #
SEEK:
	NOP			;skip reloc
	LD	DE,'Sk'
	LD	(XLSCMD),DE	;last command label
	PUSH	AF
	OUT	(0F3H),A	;new track
	LD	A,(XLSTRK)
	OUT	(0F1H),A	;FDC track reg
	POP	AF
	LD	(XLSTRK),A
	LD	A,(XDRIVE)	;drive + side
	OUT	(0F4H),A	;FDC drive/side/density select
	XOR	A
	OUT	(0E4H),A	;disable NMI
	CALL	WAIT8
	LD	A,18H		;SEEK command
	OUT	(0F0H),A
	CALL	WNOTB0
	RET

;-----	Retry I/O
;	Call this routine at the beginning of the I/O
;	routine. If I/O failed, force Direct Access mode
;	and try again.
IORETRY:
	$BREAK	IORETRY
	EX	(SP),HL		;get ret addr in HL
	LD	($?IORCL),HL	;save to below CALL vector
	EX	(SP),HL		;get back HL
	LD	($?IORHL),HL	;save HL to below LD HL,nnnn
	LD	($?IORA),A	;save A to below LD A,nn
	CALL	$-$		;call original I/O routine
$?IORCL	EQU	$-2
	LD	C,A		;save acc
	LD	A,(XERROR)	;get error flag
	OR	A
	JR	Z,$?IOROK	;if no error, restore acc and exit
	$BREAK	IORETRY!
	XOR	A		;otherwise,
	LD	(XDAINIT),A	;force Direct Access mode
	CALL	DAMON
	LD	A,0		;restore acc before 1st call
$?IORA	EQU	$-1
	LD	HL,0		;idem for HL
$?IORHL	EQU	$-2
	RET			;and try again

$?IOROK	LD	A,C		;restore acc
	INC	SP		;return to the original caller
	INC	SP		;of the I/O routine
	$BREAK	/IORETRY
	RET


;-----	Read Address (not used by HxCHARD ?)
;	IN	HL = Buffer address
;	OUT	HL = Same Buffer address
;	USED	A,BC,DE
RDADDR:	CALL	IORETRY
	PUSH	HL
	LD	DE,ENDFDC	;return address: POP HL - EI - RET
	PUSH	DE
	PUSH	HL
	LD	(SAVSP),SP
	PUSH	HL
	NOP			;skip reloc
	LD	DE,'Ad'
	LD	HL,RD0
	LD	C,0C8H		;read address command
	JR	RWSECT

;-----	Write sector
;	IN	A  = Sector #
;		HL = Buffer address
;	OUT	A  = Number of 256-byte pages written
;		HL = Next sector's Buffer address
;	USED	A,BC,DE
WRSECT:	CALL	IORETRY
	PUSH	HL
	LD	(SAVSP),SP
	PUSH	HL
	NOP			;skip reloc
	LD	DE,'Wr'
	LD	HL,WR0
	LD	C,0A8H		;write sector command
	JR	RWSECT

;-----	Write command buffer
;	OUT	A  = Number of 256-byte pages written
;		HL = Next sector's Buffer address
;	USED	A,BC,DE
WRCMND:	;$BREAK	WRCMND
	CALL	IORETRY
	XOR	A		;sector 0
	LD	HL,XHXCCMD	;HxCFE direct access command buffer
	PUSH	HL
	LD	(SAVSP),SP
	PUSH	HL
	NOP			;skip reloc
	LD	DE,'Wc'
	LD	HL,WRC0
	LD	C,0A8H		;write sector command
	JR	RWSECT

;-----	Read status buffer
;	OUT:	A  = Number of 256-byte pages read
;		HL = Next sector's buffer address
;	USED	A,BC,DE
RDSTAT:	$BREAK	RDSTAT
	CALL	IORETRY
	XOR	A		;sector 0
	LD	HL,XHXCSTA	;HxCFE direct access status buffer
	PUSH	HL		;Save buffer address (restored in ENDSCT)
	LD	(SAVSP),SP
	PUSH	HL
	NOP			;skip reloc
	LD	DE,'Rs'
	LD	HL,RDS0
	LD	C,088H		;read sector command
	JR	RWSECT

;-----	Read sector
;	IN:	A  = Sector #
;		HL = Buffer address
;	OUT:	A  = Number of 256-byte pages read
;		HL = Next sector's buffer address
;	USED	A,BC,DE
RDSECT:	CALL	IORETRY
	PUSH	HL		;Save buffer address (restored in ENDSCT)
	LD	(SAVSP),SP
	PUSH	HL
	NOP			;skip reloc
	LD	DE,'Rd'

	IF	ASSERT		;assert dirty flag off
	PUSH	AF
	LD	A,(XSECDIRTY)
	OR	A
	JR	Z,$RDSECTOK
	$$BREAK
	CALL	DISMPC
	DB	76H,'RDSECT:XSECDIRTY',0
	JR	$
$RDSECTOK:
	POP	AF
	ENDIF			;end assert

	LD	HL,RD0
	LD	C,088H		;read sector command

;-----	Common FDC i/o code
RWSECT:	LD	(XLSCMD),DE	;Save last command
	EX	(SP),HL
	PUSH	AF
	CALL	HDSLOW
	POP	AF
	PUSH	HL
	OUT	(0F2H),A	;sector #
	LD	A,(XLSTRK)
	OUT	(0F1H),A	;track # (255)
	LD	A,(XDRIVE)
	OUT	(0F4H),A	;drive/side/density
	OR	40H		;to enable wait state (sync Z80-FDC)
	LD	E,A
	LD	D,2		;status bit mask
	IN	A,(0F0H)
	$DI
	LD	HL,ENDSCT	;NMI vector for end of sector
	CALL	SETNMI
	LD	A,0C0H		;Enable MOTOROFF and FDC INTRQ
	OUT	(0E4H),A	;Enable
	LD	A,C		;FDC command
	OUT	(0F0H),A	;FDC Status/Command reg
	POP	HL		;sector buffer
	LD	BC,0F3H		;C = FDC data-in port #, B = byte count
	JP	WAIT8

;-----	Read 512 bytes from disk
RD0:	LD	B,02H		;set Delay
	IN	A,(0F0H)	;wait bit 1
	AND	D
	JR	Z,RD0
	INI			;get 1st byte
	DJNZ	$		;do delay
	DEC	B		;Remaining bytes count
	LD	A,E
RD1:	OUT	(0F4H),A	;wait FDC
	INI			;get remaining bytes
	JR	NZ,RD1		;end with NMI
RD2:	OUT	(0F4H),A	;wait FDC
	INI			;get remaining bytes
	JR	NZ,RD2		;end with NMI
	JR	$

;-----	Write 512 bytes to disk
WR0:	LD	B,40H		;set delay
	IN	A,(0F0H)	;wait bit 1
	AND	D
	JR	Z,WR0
	OUTI			;put 1st byte
	DJNZ	$		;do delay
	DEC	B		;remaining bytes count
	LD	A,E
WR1:	OUT	(0F4H),A	;wait FDC
	OUTI			;put remaining bytes
	JR	NZ,WR1		;end with NMI
WR2:	OUT	(0F4H),A	;wait FDC
	OUTI			;put remaining bytes
	JR	NZ,WR2		;end with NMI
	JR	$

;-----	Read status record from HxCFE
RDS0:	LD	B,02H		;set Delay
	IN	A,(0F0H)	;wait bit 1
	AND	D
	JR	Z,RDS0
	INI			;get 1st byte
	DJNZ	$		;do delay
	LD	B,XHSTAL-1	;remaining bytes count
	LD	A,E
RDS1:	OUT	(0F4H),A	;wait FDC
	INI			;get remaining bytes
	JR	NZ,RDS1		;end with NMI
	LD	B,256-XHSTAL
RDS2:	OUT	(0F4H),A	;wait FDC
	INI			;get remaining bytes
	DEC	HL
	JR	NZ,RDS2		;end with NMI
RDS3:	OUT	(0F4H),A	;wait FDC
	INI			;get remaining bytes
	DEC	HL
	JR	NZ,RDS3		;end with NMI
	JR	$

;-----	Write command buffer to HxCFE
WRC0:	LD	B,40H		;set delay
	IN	A,(0F0H)	;wait bit 1
	AND	D
	JR	Z,WRC0
	OUTI			;put 1st byte
	DJNZ	$		;do delay
	LD	B,XHCMDL	;remaining bytes count
	LD	A,E
WRC1:	OUT	(0F4H),A	;wait FDC
	OUTI			;put remaining bytes
	JR	NZ,WRC1		;end with NMI
	LD	B,255-XHCMDL
WRC2:	OUT	(0F4H),A	;wait FDC
	OUTI			;put remaining bytes
	DEC	HL
	JR	NZ,WRC2		;end with NMI
WRC3:	OUT	(0F4H),A	;wait FDC
	OUTI			;put remaining bytes
	DEC	HL
	JR	NZ,WRC3		;end with NMI
	JR	$

;-----	NMI handler - end of sector
ENDSCT:	XOR	A
	OUT	(0E4H),A	;disable NMI
	CALL	WAIT8
	IN	A,(0F0H)	;read FDC status
	LD	(XERROR),A
	LD	SP,(SAVSP)
	POP	DE		;restore sector buffer address
	OR	A
	SBC	HL,DE
	DEC	HL
	INC	H
	LD	A,H
	LD	(XNPAG),A
	PUSH	DE		;buffer address
	CALL	RESNMI
	CALL	HDREST		;restore HD64180 mode
ENDFDC:	POP	HL
	$BREAK	/ENDSCT
	RET

;-----	Wait reset of busy flag
WNOTB0:	CALL	WAIT8
$?ABX:	IN	A,(0F0H)
	RRCA
	JR	C,$?ABX
	IN	A,(0F0H)
	LD	(XERROR),A
	OR	A
	RET

;-----	8-loops delay
WAIT8:	LD	A,8
$?ABZ:	DEC	A
	JR	NZ,$?ABZ
	RET



;-----	Direct Access Mode ON
DAMON:
	PUSH	HL
	LD	HL,(XPTRACK)	;Ptr to host DCT
	LD	A,H		;Initialized?
	OR	L
	LD	A,2		;'Seek error during read'
	JR	Z,$DAMONX	;Exit if not
	LD	A,(XDAINIT)	;Direct Access initialized?
	OR	A
	JR	Z,$?DAMON1	;force seek if not
	LD	A,(HL)		;current cyl
	INC	A
	JR	Z,$DAMONX	;ret if 255
$?DAMON1:
	$BREAK	DAMON_SET
	CALL	HDSLOW		;slow down XLR8er
	PUSH	DE
	CALL	WNOTB0		;wait not busy
	CALL	RESTOR		;restore to trk 0
	CALL	WNOTB0		;wait not busy
	LD	A,DAMTRK	;direct access mode trk
	LD	(HL),A		;set curr cyl
	LD	(XLSLBA+3),A	;reset last LBA in HXCLBA/ASM
	LD	(XDAINIT),A	;set as initialized
	CALL	SEEK		;seek track
	POP	DE
	CALL	HDREST		;restore XLR8er speed
	XOR	A		;good
	$BREAK	/DAMON_SET
$DAMONX:
	POP	HL
	OR	A		;check ret code
	RET


;-----	Set HD64180 slow mode
HDSLOW:	;$BREAK	HDSLOW
	LD	A,(X64180)	;get XLR8er flag
	OR	A		;Z80 or slowed down?
	RET	NZ		;ret if true
	LD	(X64180S),A	;save old flag (false)
	INC	A
	LD	(X64180),A	;save new flag (true)
	PUSH	BC
	LD	B,0
	LD	C,32H
	IN	A,(C)
	LD	(XIO32),A
	AND	00001111B	;keep bits 0-3
	OR	10010000B	;IIMM----
	OUT	(C),A
	LD	C,36H
	IN	A,(C)
	LD	(XIO36),A
	AND	00111100B	;keep bits 2-5
	OR	11000010B	;11----RR
	OUT	(C),A
	POP	BC
	RET

;-----	Restore HD64180 mode
HDREST:	;$BREAK	HDREST
	LD	A,(X64180S)	;get old XLR8er flag
	LD	(X64180),A	;restore
	OR	A
	RET	NZ		;ret if Z80
	PUSH	BC
	LD	B,0
	LD	C,32H
	LD	A,(XIO32)
	OUT	(C),A
	LD	C,36H
	LD	A,(XIO36)
	OUT	(C),A
	POP	BC
	RET


FDC_END:
	$MSG	/HxCFDC

XVCNMI	DC	3,0		;original NMI vector
XLSCMD	DW	'  '		;last command label
XDRIVE	DB	81H		;drive/side/density
XLSTRK	DB	0		;last track
SAVSP	DW	0		;Save SP
XERROR	DB	0		;error flags
XNPAG	DB	1		;number of pages per sector
XPTRACK	DW	0		;pointer to current host track
XDAINIT	DW	0		;direct access mode initialized
X64180	DB	255		;CPU type HD64180 if 0
X64180S	DB	255		;save CPU type
XIO32	DB	0		;save HD64180 port 32
XIO36	DB	0		;save HD64180 port 36

	$MSG	XHXCCMD
XHXCCMD:			;Command buffer
MSIG:	DB	'HxCFEDA',0	;HxC Floppy Emulator Direct Access Signature
XHCMDC:	DB	0		;Command code
XHPAR0:	DB	0		;Parameter 0
XHPAR1:	DB	0		;Parameter 1
XHPAR2:	DB	0		;Parameter 2
XHPAR3:	DB	0		;Parameter 3
XHPAR4:	DB	0		;Parameter 4
XHPAR5:	DB	0		;Parameter 5
XHPAR6:	DB	0		;Parameter 6
XHPAR7:	DB	0		;Parameter 7
XHCKSM:	DB	0		;Checksum
XHCMDL	EQU	$-XHXCCMD	;Command buffer length
	DB	0		;Command terminator (written 512-XHCMDL times)
	$MSG	/XHXCCMD

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$DATA	; DATA segment

	$ALIGN	4
	$MSG	BUF512
	$ALIGN	8
BUF512	DS	200H		;512 bytes FDC I/O buffer
	$MSG	/BUF512

	$MSG	XHXCSTA
XHXCSTA:			;Status buffer
XHSSIG:	DS	8		;contains "HxCFEDA\0"
XHSFWV:	DS	12		;firmware version
XHSLBA:	DS	4		;lba_base
XHSCDC:	DS	1		;cmd_cnt
XHSRDC:	DS	1		;read_cnt
XHSWRC:	DS	1		;write_cnt
XHSLCS:	DS	1		;last_cmd_status
XHSWLK:	DS	1		;write_locked
XHSKYS:	DS	1		;keys_status
XHSSDS:	DS	1		;sd_status
XHSSDW:	DS	1		;SD_WP
XHSSDC:	DS	1		;SD_CD
XHSNSC:	DS	1		;number_of_sectors
XHSCID:	DS	2		;current_index
XHSTAL	EQU	$-XHXCSTA	;Status length
	DS	1		;byte bucket
	$MSG	/XHXCSTA

	ENDIF			; DATA segment
;++++++++++++++++++++++++++++++++++++++++++++++++


;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$RELO	; RELO segment

CSEG_FDC 	MACRO
	DW	FDC_BEGIN,FDC_END
	ENDM

	ENDIF			; RELO segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END
