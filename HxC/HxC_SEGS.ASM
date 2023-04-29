DBG	EQU	0

*GET	HXCDEF			; Defines and macros

$CODE	EQU	1		; CODE segment ID
$DATA	EQU	2		; DATA segment ID
$RELO	EQU	3		; Relocatable zone macros segment ID

;++++++++++++++++++++++++++++++++++++++++++++++++
;	CODE segment
$SEG	DEFL	$CODE		; Begin CODE segment

*GET	HXC_MODS		; Assemble CODE segments

	DC	4,0		; Stack guard
	DC	-$.AND.00FFH,0	; Page filler

$ENDCODE:			; End CODE segment

;++++++++++++++++++++++++++++++++++++++++++++++++
;	STACK segment
;
;	Stack and end of program code
STKCHK	EQU	$		; Ensure that the 4 prev bytes are always null
	DS	80H		; 64 stack entries
STKORG	EQU	$		; Stack origin

;++++++++++++++++++++++++++++++++++++++++++++++++
;	DATA segment
$SEG	DEFL	$DATA		; Begin DATA segment

*GET	HXC_MODS		; Assemble DATS segments

$ENDDATA:			; End DATA segment

;++++++++++++++++++++++++++++++++++++++++++++++++
;	HEAP segment
	DS	-$.AND.000FH	; Align

HEAP	EQU	$		; Files list

;++++++++++++++++++++++++++++++++++++++++++++++++


	END
