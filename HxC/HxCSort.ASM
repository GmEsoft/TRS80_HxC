;
;	HXCSORT/ASM	Sorting algorithms
;

*MOD

;++++++++++++++++++++++++++++++++++++++++++++++++
	IFEQ	$SEG,$CODE	; CODE segment

	IF	0		; XCHSORT not used...
	
;-----	Sort files - Simple Exchange Sort Algorithm
;	Original version, slow: up to N*(N-1)/2 swaps
;	IN	C	Number of items
;		HL	Items table
;		DE	Item size
;		HL'	Comparator address - C flag set if *IX < *IY
XCHSORT:
	INC	C		; Table empty ?
	DEC	C		;
	RET	Z		; return if yes
	PUSH	HL		; First item to IX
	POP	IX		;
$?XCHS1:
	PUSH	IX		; First remaining item to IY
	POP	IY		;
	LD	B,C		; Counter of remaining items
	DEC	B		; Scanner of remaining item
	JR	Z,$?XCHSNC	; Jump if no remaining item
$?XCHS2:
	ADD	IY,DE		; Next remaining item

	CALL	COMPIXIY	; Test if *IX < *IY
	CALL	NC,SWAPIXIY	; Swap if not

	DJNZ	$?XCHS2		; Next remaining item to scan
	ADD	IX,DE		; Next item to check
	DEC	C		;
	JR	NZ,$?XCHS1	; Jump until all items ordered
$?XCHSNC:
	RET			; Done
	
	ENDIF			; XCHSORT Not used...

;-----	Sort files - Selection Sort Algorithm
;	Improved version of Exchange Sort, faster: up to N-1 swaps
;	Get minimum of remaining items, then swap if needed
;	IN	C	Number of items
;		HL	Items table
;		DE	Item size
;		HL'	Comparator address - C flag set if *IX < *IY
SELSORT:
	INC	C		; Table empty ?
	DEC	C		;
	RET	Z		; return if yes
	PUSH	HL		; First item to IX
	POP	IX		;
$?SELS1:			; Outer swap loop
	LD	B,C		; Counter of remaining items
	DEC	B		; Scanner of remaining item
	JR	Z,$?SELSXT	; Exit if no remaining item
	DEC	B
	JR	Z,$?SELSNC	; Jump if only 1 remaining item

	PUSH	IX		; Save remaining item

	ADD	IX,DE		; *IX = First minimum candidate
	PUSH	IX		;
	POP	IY		;
$?SELS2:			; Inner Minimum scan loop
	ADD	IY,DE		; *IY Next min candidate
	CALL	COMPIXIY	; Test if *IX < *IY
	JR	C,$?SELS3	; Jump if yes

	PUSH	IY		; New minimum candidate
	POP	IX		; to IX

$?SELS3:
	DJNZ	$?SELS2		; Next remaining item to scan
	PUSH	IX		; Minimum of remaining items
	POP	IY		; to IY

	POP	IX		; Restore remaining item

$?SELSNC:
	CALL	COMPIXIY	; Test if *IX < *IY
	CALL	NC,SWAPIXIY	; Swap items if not

	ADD	IX,DE		; Next item to check
	DEC	C		;
	JR	NZ,$?SELS1	; Jump until all items ordered

$?SELSXT:
	RET			; Done

;-----	Compare items *IX and *IY
;	IN	IX	First item pointer
;		IY	Second item pointer
;		HL'	Comparator address - C flag set if *IX < *IY
;	OUT	C flag	Set if *IX < *IY
COMPIXIY:
	EXX			; Bring up comparator address
	PUSH	HL		; Save it
	PUSH	HL		; Push comparator
	LD	HL,$?XCOMPXY	; Load return address
	EX	(SP),HL		; Swap both addresses
	JP	(HL)		; Go to comparator
$?XCOMPXY:
	POP	HL		; restore comparator
	EXX			; But it back to alt reg set
	RET

;-----	Swap items *IX and *IY with length DE
;	IN	IX	First item pointer
;		IY	Second item pointer
;		DE	Number of bytes to swap
SWAPIXIY:
	PUSH	DE		; Save item length
	EXX			; Use alt reg set
	POP	DE		; entry length
	DEC	DE		; decrement it
	LD	B,E		; LSB inner loop
	INC	B		; increment it
	LD	C,D		; MSB outer loop
	INC	C		; at least one outer loop
	PUSH	HL		; save comparator
	PUSH	IX		; First item address
	POP	HL		; to HL
	PUSH	IY		; Second item address
	POP	DE		; to DE
$?SWAPXY:
	LD	A,(HL)		; Swap bytes between items
	EX	AF,AF'		;
	LD	A,(DE)		;
	LD	(HL),A		;
	EX	AF,AF'		;
	LD	(DE),A		;
	INC	HL		; Bump pointers
	INC	DE		;
	DJNZ	$?SWAPXY	; Loop using inner loop counter
	DEC	C		; Decr outer loop counter
	JR	NZ,$?SWAPXY	; Loop until 0
	POP	HL		; restore comparator
	EXX			; Use main reg set
	RET

	ENDIF			; CODE segment
;++++++++++++++++++++++++++++++++++++++++++++++++

	END

;------------------------------------------------------------------------------
