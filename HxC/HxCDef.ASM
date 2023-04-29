

NOREL	DEFL	0		;don't relocate code (debug)
ASSERT	DEFL	0		;enable assertions
EIBRK	DEFL	0		;enable break on EI

	IF	@@1
MODEL	EQU	@@1
	ELSE
MODEL	EQU	4
	ENDIF

	IF	@@2
INCBOOT	EQU	@@2
	ELSE
INCBOOT	EQU	0
	ENDIF

	IFEQ	MODEL,3
SVCS	EQU	0		;using SVCs		  [0]
FREHD	EQU	1		;support for multiple partitions
				;(FreHD image support)	  [1]
BANKS	EQU	0		;support memory banks	  [0]
NOCLK	EQU	0		;disable clock display	  [0]
CACHE	EQU	0		;enable LBA sectors cache [0]
MVOUT	EQU	1		;move code out resid part [1]
LOGO	EQU	1		;enable hxc2001 logo	  [1]
	ENDIF

	IFEQ	MODEL,4
SVCS	EQU	1		;using SVCs		  [1]
FREHD	EQU	1		;support for multiple partitions
				;(FreHD image support)	  [1]
BANKS	EQU	0		;support memory banks	  [1]
NOCLK	EQU	1		;disable clock display	  [1]
CACHE	EQU	0		;enable LBA sectors cache [1]
MVOUT	EQU	0		;move code out resid part [1]
LOGO	EQU	1		;enable hxc2001 logo	  [1]
	ENDIF

LRU	EQU	1
JPBEG	EQU	0		;JR BEGIN0/JP BEGIN vs. JR BEGIN

$VER	MACRO
	DB	'0.1.2a'
	IFEQ	MODEL,4
	DB	' M4/4p'
	ENDIF
	IFEQ	MODEL,3
	DB	' M3'
	ENDIF
	ENDM

;TER	EQU	BRK+TRC+ASSERT
TER	EQU	1

	IF	0

@IPL	EQU	00H	; reboot the system
@KEY	EQU	01H	; wait for key press
@DSP	EQU	02H	; display character
@GET	EQU	03H	; get byte from device
@PUT	EQU	04H	; write byte to device
@CTL	EQU	05H	; make control request
@PRT	EQU	06H	; send character to printer
@KBD	EQU	08H	; scan keyboard
@KEYIN	EQU	09H	; accept line of input
@DSPLY	EQU	0AH	; display message line
@MSG	EQU	0DH	; message line handler
@VDCTL	EQU	0FH	; control video display
@ABORT	EQU	15H	; abort program execution
@EXIT	EQU	16H	; return to LS-DOS
@ERROR	EQU	1AH	; post error message
@INIT	EQU	3AH	; open new or existing file
@OPEN	EQU	3BH	; open existing file
@CLOSE	EQU	3CH	; close file
@FSPEC	EQU	4EH	; parse filename
@FEXT	EQU	4FH	; set up default extension
@FNAME	EQU	50H	; get filename/extension
@HIGH$	EQU	64H	; get or set HIGH$
@FLAGS	EQU	65H	; get system flags
@VDCLS	EQU	69H	; clear video screen

	ENDIF

$STRUCT	MACRO	#NAME
$#NAME	DEFL	0
LAST$	DEFL	0
	ENDM

$CHAR	MACRO	#NAME
#NAME	EQU	LAST$
LAST$	DEFL	LAST$+1
	ENDM

$CHARS	MACRO	#NAME,#LEN
#NAME	EQU	LAST$
LAST$	DEFL	LAST$+#LEN
	ENDM

$BYTE	MACRO	#NAME
#NAME	EQU	LAST$
LAST$	DEFL	LAST$+1
	ENDM

$WORD	MACRO	#NAME
#NAME	EQU	LAST$
LAST$	DEFL	LAST$+2
	ENDM

$DWORD	MACRO	#NAME
#NAME	EQU	LAST$
LAST$	DEFL	LAST$+4
	ENDM

$ENDSTRUCT MACRO #NAME
#NAME	EQU	LAST$-$#NAME
$LAST	DEFL	-1
	ENDM




$MSG	MACRO	#MSG
	IF	BRK
	DB	'<#MSG>'
	ENDIF
	ENDM

$BREAK	MACRO	#CMT
	IF	BRK
	IF	%%		;num of macro params
	CALL	DISTRC
	HALT
	DB	'<#CMT>'
;	REPT	%#CMT+3
;	DB	24
;	ENDM
	DB	0
	ENDIF
	DB	0EDH,0F5H	;$BREAK
	ENDIF
	ENDM

$TRACENL MACRO
	IF	TRC
	CALL	DISMPC
	HALT
	DB	0DH
	DB	0
	DB	0EDH,0F5H	;$BREAK
	ENDIF
	ENDM

$TRACE	MACRO	#CMT
	IF	TRC
	IF	%%		;num of macro params
	CALL	DISTRC
	HALT
	DB	'<#CMT>'
	DB	0
	ENDIF
	ENDIF
	ENDM

$TRACE4 MACRO
	IF	TRC
	CALL	DHEX4
	ENDIF
	ENDM

$$BREAK	MACRO
;	IFEQ	BRK,0
	DB	0EDH,0F5H	;$BREAK
;	ENDIF
	ENDM

$ALIGN	MACRO	#N
	IF	DBG
$?0	EQU	$
$?1	EQU	$?0-ORIGIN
$?2	EQU	$?1-1<-#N+1<#N
	ORG	ORIGIN+$?2
	ENDIF
	ENDM

$SVC	MACRO	#NUM
	IF	SVCS
	LD	A,#NUM
	RST	28H
	ELSE
	LD	A,C
	CALL	#NUM%&3		;#NUM + "3"
	ENDIF
	ENDM

$MODEL4	MACRO
	IF	MODEL.NE.4
	ERR	Model 4 Only
	ENDIF
	ENDM

$DI	MACRO
	DI
	IF	EIBRK
	DB	0EDH,0F8H	;$EIBON = Enable Break on EI
	ENDIF
	ENDM

$EI	MACRO
	IF	EIBRK
	DB	0EDH,0F9H	;$EIBOFF = Disable Break on EI
	ENDIF
	EI
	ENDM

; DOS temp buffer
BUFFER$	EQU	2300H
; Number of drives to allow
NDRIVE	EQU	8		;!!TODO currently only 1 out of 8
; ASCII chars
LF	EQU	10
CR	EQU	13
ETX	EQU	3

	IF	SVCS
; Model 4 SVC numbers
@IPL	EQU	00H	; reboot the system
@EXIT	EQU	16H	; return to LS-DOS
@KBD	EQU	08H	; scan keyboard
@KEY	EQU	01H	; wait for key press
@DSP	EQU	02H	; display character
@VDCTL	EQU	0FH	; control video display
@HIGH	EQU	100
@DSPLY	EQU	10
@FLAGS	EQU	101
@LOGOT	EQU	12
@ERROR	EQU	26
@GTDCT	EQU	81
@GTDCB	EQU	82
@GTMOD	EQU	83
@DIV8	EQU	93
@MUL16	EQU	91
@DECHEX	EQU	96
@KEYIN	EQU	9
@BANK	EQU	66H
	ELSE
; Model III hard addresses
@IPL3	EQU	0000H
@EXIT3	EQU	402DH
@KBD3	EQU	002BH
@KEY3	EQU	0049H
M3FLAG$ EQU     0125H   	; 'I' in ROM on Model III
@LOGOT3 EQU     428AH
@DSPLY3 EQU     4467H
HIGH$3  EQU     4411H
CFLAG$3 EQU     4758H
@ICNFG3 EQU     421DH
@MULT3  EQU     444EH
@DIVEA3 EQU     4B7AH
@KEYIN3 EQU     0040H
@GTDCT3	EQU	478FH		;=GETDCT
@DSP3	EQU	0033H
@ERROR3	EQU	4409H
HIGH$3  EQU     4411H
CFLAG$3 EQU     4758H
	ENDIF

	END
