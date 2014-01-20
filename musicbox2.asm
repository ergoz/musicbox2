;=====================================================
;==    MZ208.1 "Musicbox-2" Control program         ==
;==  (c) 2013, Michael Borisov                      ==
;=====================================================

	LIST	p=16F753
	#include <p16f753.inc>
	radix	dec

 __CONFIG _FOSC0_INT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _BOREN_EN & _WRT_ALL & _CLKOUTEN_OFF

;============ DATA MEMORY =========================
		CBLOCK	H'20'
; Per-channel state blocks, must match the procpat structure
c0d0:	1	;Ch0 upper half-period
c0d1:	1	;Ch0 lower half-period
c0vol:	1	;Ch0 volume
patp0l:	1	;Ch0 Pattern pointer (current state)
patp0h:	1
nlen0:	1	;Note length (rows per note)
skew0:	1	;Skew (duty cycle)

c1d0:	1
c1d1:	1
c1vol:	1
patp1l:	1
patp1h:	1
nlen1:	1
skew1:	1

c2d0:	1
c2d1:	1
c2vol:	1
patp2l:	1
patp2h:	1
nlen2:	1
skew2:	1

c3d0:	1
c3d1:	1
c3vol:	1
patp3l:	1
patp3h:	1
nlen3:	1
skew3:	1

; Remaining channel state variables that are not processed in procpat
c0c:	1	;Ch0 counter (working register)
c0stat:	1	;Ch0 period state (upper/lower)

c1c:	1
c1stat:	1

c2c:	1
c2stat:	1

c3c:	1
c3stat:	1

ovol:	1	;Output volume to the DAC

; Audio player state variables
qntcnt:	1	;Row counter (ticks until next row)
ncnt0:	1	;Note counters (rows until next note)
ncnt1:	1
ncnt2:	1
ncnt3:	1

pospl:	1	; List of positions pointer
posph:	1

; Inputs and outputs of the pattern processing subroutine
tfd0:	1	;Phase 0 duration
tfd1:	1	;Phase 1 duration
tvol:	1	;Volume (to generator)
tpatpl:	1	;Pattern pointer (L and H)
tpatph:	1
tnlen:	1	;Note length (in rows).
tskew:	1	;Skew

; Temporary variables
tmp0:	1
tmp1:	1
tmp2:	1
		ENDC

; Common RAM (shared with ISR)
		CBLOCK	H'70'
save_w:			1
save_status:	1
		ENDC
;============ RESET ENTRY POINT ===================

	ORG	0
	clrf	STATUS
	clrf	PCLATH
	call	init_clock
	goto	main
;============ INTERRUPT ENTRY POINT ===============
	ORG	4
    movwf   save_w
    swapf   STATUS,W
    movwf   save_status
	bcf		PIR1,TMR2IF

; Output DAC value generated in previous ISR
	clrf	STATUS		;Select Bank 0
	movf	ovol,W
	bsf		STATUS,RP0	;Select Bank 1 for DAC1REFL/H
	ERRORLEVEL -302
	movwf	DAC1REFH
	ERRORLEVEL +302
	bcf		STATUS,RP0	;Select Bank 0 for further operations

; Update channel generators
	decfsz  c0c,F
	goto	c1proc
	comf	c0stat,F
	movf	c0d0,W
	btfsc	c0stat,0		;Select primary or alternate delay
	movf	c0d1,W
	movwf	c0c
c1proc:
	decfsz	c1c,F
	goto	c2proc
	comf	c1stat,F
	movf	c1d0,W
	btfsc	c1stat,0		;Select primary or alternate delay
	movf	c1d1,W
	movwf	c1c
c2proc:
	decfsz	c2c,F
	goto	c3proc
	comf	c2stat,F
	movf	c2d0,W
	btfsc	c2stat,0
	movf	c2d1,W
	movwf	c2c
c3proc:
	decfsz	c3c,F
	goto	caproc
	comf	c3stat,F
	movf	c3d0,W
	btfsc	c3stat,0
	movf	c3d1,W
	movwf	c3c

caproc:
;Sum up channel volumes
	clrw
	btfsc	c0stat,0
	addwf	c0vol,W
	btfsc	c1stat,0
	addwf	c1vol,W
	btfsc	c2stat,0
	addwf	c2vol,W
	btfsc	c3stat,0
	addwf	c3vol,W
	movwf	ovol

    swapf   save_status,W
    movwf   STATUS
    swapf   save_w,F
    swapf   save_w,W
	retfie

;============ Note frequency table ======
getnotefrq:
	addwf	PCL,F
	retlw	H'FD'
	retlw	H'EE'
	retlw	H'E1'
	retlw	H'D4'
	retlw	H'C8'
	retlw	H'BD'
	retlw	H'B3'
	retlw	H'A9'
	retlw	H'9F'
	retlw	H'96'
	retlw	H'8E'
	retlw	H'86'
	retlw	H'7E'
	retlw	H'77'
	retlw	H'70'
	retlw	H'6A'
	retlw	H'64'
	retlw	H'5F'
	retlw	H'59'
	retlw	H'54'
	retlw	H'50'
	retlw	H'4B'
	retlw	H'47'
	retlw	H'43'
	retlw	H'3F'
	retlw	H'3C'
	retlw	H'38'
	retlw	H'35'
	retlw	H'32'
	retlw	H'2F'
	retlw	H'2D'
	retlw	H'2A'
	retlw	H'28'
	retlw	H'26'
	retlw	H'23'
	retlw	H'21'
	retlw	H'20'
	retlw	H'1E'
	retlw	H'1C'
	retlw	H'1B'
	retlw	H'19'
	retlw	H'18'
	retlw	H'16'
	retlw	H'15'
	retlw	H'14'
	retlw	H'13'
	retlw	H'12'
	retlw	H'11'
	retlw	H'10'
	retlw	H'0F'
	retlw	H'0E'

main:
	call	init_pins
	call	init_dac

;--- Initialize position and pattern pointers
	call	init_song

;--- Initialize generator state variables
	clrf	c0stat
	clrf	c1stat
	clrf	c2stat
	clrf	c3stat
	movlw	1
	movwf	c0c
	movwf	c0d0
	movwf	c0d1
	movwf	c1c
	movwf	c1d0
	movwf	c1d1
	movwf	c2c
	movwf	c2d0
	movwf	c2d1
	movwf	c3c
	movwf	c3d0
	movwf	c3d1
	clrf	ovol

;--- Initialize player variables sufficient enough that it could pick up song
	movlw	1
	movwf	qntcnt
	movwf	ncnt0
	movwf	ncnt1
	movwf	ncnt2
	movwf	ncnt3

; Initialize Timer 1 to generate ticks
	clrf	T1CON
	movlw	H'40'
	movwf	TMR1L
	movlw	H'63'		;40000 constant (50Hz tick rate)
	movwf	TMR1H
	bcf		PIR1,TMR1IF
	bsf		T1CON,TMR1ON

; Initialize Timer 2 to generate ~28kHz interrupts for signal generation
	BANKSEL	T2CON
	ERRORLEVEL -302
	movlw	B'00000000'
	movwf	T2CON
	movlw	71
	movwf	PR2
	BANKSEL	PIR1
	bcf		PIR1,TMR2IF
	BANKSEL	PIE1
	bsf		PIE1,TMR2IE
	BANKSEL	T2CON
	bsf		T2CON,TMR2ON
	ERRORLEVEL +302
	BANKSEL	PORTA

	bsf		INTCON,PEIE
	bsf		INTCON,GIE	;Enable timer interrupts


lpwait:
	btfss	PIR1,TMR1IF
	goto	lpwait
	bcf		T1CON,TMR1ON
	movlw	H'40'
	movwf	TMR1L
	movlw	H'63'		;40000 constant (50Hz tick rate)
	movwf	TMR1H
	bcf		PIR1,TMR1IF
	bsf		T1CON,TMR1ON
; Check if row has finished
	decfsz	qntcnt,F
	goto	lpwait
	movlw	3			;default row length(3)
	movwf	qntcnt
; Process each channel's note update
	decfsz	ncnt0,F
	goto	ont0
; New note on channel 0
	movlw	c0d0
	movwf	FSR			;source for LDIR
	movlw	tfd0-c0d0	;destination for LDIR
	movwf	tmp2
	call	ldir_channel_state
	call	procpat	;Process pattern data via a generic subroutine
	movlw	tfd0
	movwf	FSR			;source for LDIR
	movlw	c0d0-tfd0
	movwf	tmp2
	call	ldir_channel_state
	movf	nlen0,W
	movwf	ncnt0
;---
ont0:
	decfsz	ncnt1,F
	goto	ont1
; New note on channel 1
	movlw	c1d0
	movwf	FSR			;source for LDIR
	movlw	tfd0-c1d0	;destination for LDIR
	movwf	tmp2
	call	ldir_channel_state
	call	procpat	;Process pattern data via a generic subroutine
	movlw	tfd0
	movwf	FSR			;source for LDIR
	movlw	c1d0-tfd0
	movwf	tmp2
	call	ldir_channel_state
	movf	nlen1,W
	movwf	ncnt1
;---
ont1:
	decfsz	ncnt2,F
	goto	ont2
; New note on channel 2
	movlw	c2d0
	movwf	FSR			;source for LDIR
	movlw	tfd0-c2d0	;destination for LDIR
	movwf	tmp2
	call	ldir_channel_state
	call	procpat	;Process pattern data via a generic subroutine
	movlw	tfd0
	movwf	FSR			;source for LDIR
	movlw	c2d0-tfd0
	movwf	tmp2
	call	ldir_channel_state
	movf	nlen2,W
	movwf	ncnt2
;---
ont2:
	decfsz	ncnt3,F
	goto	lpwait
; New note on channel 3
	movlw	c3d0
	movwf	FSR			;source for LDIR
	movlw	tfd0-c3d0	;destination for LDIR
	movwf	tmp2
	call	ldir_channel_state
	call	procpat	;Process pattern data via a generic subroutine
	movlw	tfd0
	movwf	FSR			;source for LDIR
	movlw	c3d0-tfd0
	movwf	tmp2
	call	ldir_channel_state
	movf	nlen3,W
	movwf	ncnt3
;--- end of note processing
	goto	lpwait

;====== General (for all channels) pattern processing routine
procpat:
; pattern processing loop
patlop:
	call	getpatbyte
	call	incpatptr
	addlw	52			;we have 51 notes (codes CD-FF), pause is CC
	btfsc	STATUS,C
	goto	patnote
	addlw	16			;we have 16 volume levels (codes BC-CB)
	btfsc	STATUS,C
	goto	patvolume
	addlw	64			;we have 64 note lengths (1-64, 256), codes 7C-BB
	btfsc	STATUS,C
	goto	patnlen
	addlw	16			;we have 16 skew values (0-15), codes 6C-7B
	btfsc	STATUS,C
	goto	patskew
	; 0-7B is end of pattern. Codes 1-7B are free (reserved)
	; fetch pattern data for channel 0 from list of positions
poslop:
	call	getposbyte
	movwf	tpatpl		;This value may be overwritten on song end
	call	getposbyte
	movwf	tpatph		;This value may be overwritten on song end
	iorwf	tpatpl,W	;Check for zero
	btfss	STATUS,Z
	goto	patnpat
	; A song end has been reached (code 0000 in list of positions). Loop the song
	call	init_song
	goto	patlop		;process pattern data from the start of song
patnpat:
	call	init_pattern0	;fetch data for other channels
	goto	patlop
; Process note length
patnlen:
	movwf	tnlen		;store the new note length
	goto	patlop		;process next byte
; Process note volume
patvolume:
	movwf	tvol		;store the new volume
	goto	patlop		;process next byte
; Process skew
patskew:
	movwf	tskew		;store the new skew
	goto	patlop
; Process new note
patnote:
	btfsc	STATUS,Z	;code 80H is a pause
	goto	patpause
; Get note frequency
	movwf	tfd0		;store the note index while W is used
	movlw	HIGH getnotefrq
	movwf	PCLATH
	decf	tfd0,W		;code 81H is the first note in the table
	call	getnotefrq	;fetch period duration
	movwf	tfd0		;Temporarily store the complete period here
; Skew processing (duty cycle). Split the complete period in two parts by skew
; Multiply period with skew (5x8 multiplication)
	movf	tskew,W
	iorlw	H'10'		;Set MSB to 1 to divide period by 2 when skew=0
	movwf	tmp0		;Low byte of the product, starts with a copy of the multiplicand
	clrf	tfd1		;High byte of the product
	movlw	5
	movwf	tmp1		;5 bits to multiply
	movf	tfd0,W		;Complete period (multiplicand)
	rrf		tmp0,F		;Shift out the first bit
patnote0:
	btfsc	STATUS,C
	addwf	tfd1,F
	rrf		tfd1,F
	rrf		tmp0,F
	decfsz	tmp1,F
	goto	patnote0
; tfd1 already holds the proper proportion. Adjust tfd0. tfd1 will be always
; less than tfd0 because we don't round up the multiplication result.
; So no need to check for equality of tfd0 and tfd1.
	movf	tfd1,W
	subwf	tfd0,F
; Temporary measure - ensure that the volume is nonzero
	movf	tvol,W
	btfsc	STATUS,Z
	movlw	15
	movwf	tvol
	return
patpause:
	clrf	tvol
	return			;no need to update note frequency (pause)


;------ Initialize position and pattern pointers
init_song:
	movlw	LOW (posdata-1)
	movwf	pospl
	movlw	HIGH (posdata-1)
	movwf	posph

	call	getposbyte
	movwf	patp0l
	movwf	tpatpl
	call	getposbyte
	movwf	patp0h
	movwf	tpatph
; entry point for advancement of patterns
init_pattern0:
	call	getposbyte
	movwf	patp1l
	call	getposbyte
	movwf	patp1h
	call	getposbyte
	movwf	patp2l
	call	getposbyte
	movwf	patp2h
	call	getposbyte
	movwf	patp3l
	call	getposbyte
	movwf	patp3h
	return

; Increment pattern pointer (2-byte inc)
incpatptr:
	incfsz	tpatpl,F	;update pattern pointer
	decf	tpatph,F
	incf	tpatph,F
	return

; Fetch next pattern byte (table read)
getpatbyte:
	movf	tpatph,W
	movwf	PCLATH
	movf	tpatpl,W
	movwf	PCL

; Increment position pointer and fetch next position byte (table read)
getposbyte:
	incfsz	pospl,F
	decf	posph,F
	incf	posph,F
	movf	posph,W
	movwf	PCLATH
	movf	pospl,W
	movwf	PCL

;---- Calls LDIR with the length of channel state block
ldir_channel_state:
	movlw	7
	movwf	tmp0

;------- LDIR routine: copy a memory block
; < FSR - source
; < tmp2 - destination-source
; < tmp0 - length
; uses tmp1
ldir:
	movf	INDF,W
	movwf	tmp1
	movf	tmp2,W
	addwf	FSR,F
	movf	tmp1,W
	movwf	INDF
	movf	tmp2,W
	subwf	FSR,F
	incf	FSR,F
	decfsz	tmp0,F
	goto	ldir
	return


init_dac:
	BANKSEL	DAC1CON0
	ERRORLEVEL -302
	movlw	B'10000000'
	movwf	DAC1CON0
	BANKSEL	OPA1CON
	movlw	B'10011010'
	movwf	OPA1CON
	ERRORLEVEL +302
	BANKSEL	PORTA
	return

init_pins:
	BANKSEL	TRISA
	ERRORLEVEL -302
	movlw	0	;all pins = digital outputs
	movwf	TRISA
	movlw	B'00000100'	;all pins = digital outputs except RC2
	movwf	TRISC
	BANKSEL	ANSELA
	clrf	ANSELA	;all pins = digital outputs
	movlw	B'00000100' ;RC2 - analog pin
	movwf	ANSELC
	BANKSEL	WPUA
	clrf	WPUA
	clrf	WPUC
	ERRORLEVEL +302
	BANKSEL	PORTA
	clrf	PORTA
	clrf	PORTC
	return

init_clock:
	BANKSEL	OSCCON
	ERRORLEVEL -302
	movlw	B'00110000'
	movwf	OSCCON
	ERRORLEVEL +302
	BANKSEL	PORTA
	return



;============== SONG DATA ===============
posdata:
	retlw	LOW	pattern_1_0
	retlw	HIGH	pattern_1_0
	retlw	LOW	pattern_1_1
	retlw	HIGH	pattern_1_1
	retlw	LOW	pattern_1_2
	retlw	HIGH	pattern_1_2
	retlw	LOW	pattern_1_3
	retlw	HIGH	pattern_1_3
	retlw	LOW	pattern_0_0
	retlw	HIGH	pattern_0_0
	retlw	LOW	pattern_0_1
	retlw	HIGH	pattern_0_1
	retlw	LOW	pattern_0_2
	retlw	HIGH	pattern_0_2
	retlw	LOW	pattern_0_3
	retlw	HIGH	pattern_0_3
	retlw	LOW	pattern_1_0
	retlw	HIGH	pattern_1_0
	retlw	LOW	pattern_1_1
	retlw	HIGH	pattern_1_1
	retlw	LOW	pattern_1_2
	retlw	HIGH	pattern_1_2
	retlw	LOW	pattern_1_3
	retlw	HIGH	pattern_1_3
	retlw	LOW	pattern_3_0
	retlw	HIGH	pattern_3_0
	retlw	LOW	pattern_3_1
	retlw	HIGH	pattern_3_1
	retlw	LOW	pattern_3_2
	retlw	HIGH	pattern_3_2
	retlw	LOW	pattern_3_3
	retlw	HIGH	pattern_3_3
	retlw	LOW	pattern_4_0
	retlw	HIGH	pattern_4_0
	retlw	LOW	pattern_4_1
	retlw	HIGH	pattern_4_1
	retlw	LOW	pattern_4_2
	retlw	HIGH	pattern_4_2
	retlw	LOW	pattern_4_3
	retlw	HIGH	pattern_4_3
	retlw	LOW	pattern_5_0
	retlw	HIGH	pattern_5_0
	retlw	LOW	pattern_5_1
	retlw	HIGH	pattern_5_1
	retlw	LOW	pattern_5_2
	retlw	HIGH	pattern_5_2
	retlw	LOW	pattern_5_3
	retlw	HIGH	pattern_5_3
	retlw	LOW	pattern_6_0
	retlw	HIGH	pattern_6_0
	retlw	LOW	pattern_6_1
	retlw	HIGH	pattern_6_1
	retlw	LOW	pattern_6_2
	retlw	HIGH	pattern_6_2
	retlw	LOW	pattern_6_3
	retlw	HIGH	pattern_6_3
	retlw	LOW	pattern_1_0
	retlw	HIGH	pattern_1_0
	retlw	LOW	pattern_1_1
	retlw	HIGH	pattern_1_1
	retlw	LOW	pattern_1_2
	retlw	HIGH	pattern_1_2
	retlw	LOW	pattern_1_3
	retlw	HIGH	pattern_1_3
	retlw	LOW	pattern_0_0
	retlw	HIGH	pattern_0_0
	retlw	LOW	pattern_0_1
	retlw	HIGH	pattern_0_1
	retlw	LOW	pattern_0_2
	retlw	HIGH	pattern_0_2
	retlw	LOW	pattern_0_3
	retlw	HIGH	pattern_0_3
	retlw	LOW	pattern_1_0
	retlw	HIGH	pattern_1_0
	retlw	LOW	pattern_1_1
	retlw	HIGH	pattern_1_1
	retlw	LOW	pattern_1_2
	retlw	HIGH	pattern_1_2
	retlw	LOW	pattern_1_3
	retlw	HIGH	pattern_1_3
	retlw	LOW	pattern_3_0
	retlw	HIGH	pattern_3_0
	retlw	LOW	pattern_3_1
	retlw	HIGH	pattern_3_1
	retlw	LOW	pattern_3_2
	retlw	HIGH	pattern_3_2
	retlw	LOW	pattern_3_3
	retlw	HIGH	pattern_3_3
	retlw	LOW	pattern_7_0
	retlw	HIGH	pattern_7_0
	retlw	LOW	pattern_7_1
	retlw	HIGH	pattern_7_1
	retlw	LOW	pattern_7_2
	retlw	HIGH	pattern_7_2
	retlw	LOW	pattern_7_3
	retlw	HIGH	pattern_7_3
	retlw	LOW	pattern_8_0
	retlw	HIGH	pattern_8_0
	retlw	LOW	pattern_8_1
	retlw	HIGH	pattern_8_1
	retlw	LOW	pattern_8_2
	retlw	HIGH	pattern_8_2
	retlw	LOW	pattern_8_3
	retlw	HIGH	pattern_8_3
	retlw	LOW	pattern_7_0
	retlw	HIGH	pattern_7_0
	retlw	LOW	pattern_7_1
	retlw	HIGH	pattern_7_1
	retlw	LOW	pattern_7_2
	retlw	HIGH	pattern_7_2
	retlw	LOW	pattern_7_3
	retlw	HIGH	pattern_7_3
	retlw	LOW	pattern_9_0
	retlw	HIGH	pattern_9_0
	retlw	LOW	pattern_9_1
	retlw	HIGH	pattern_9_1
	retlw	LOW	pattern_9_2
	retlw	HIGH	pattern_9_2
	retlw	LOW	pattern_9_3
	retlw	HIGH	pattern_9_3
	retlw	LOW	pattern_9_0
	retlw	HIGH	pattern_9_0
	retlw	LOW	pattern_9_1
	retlw	HIGH	pattern_9_1
	retlw	LOW	pattern_9_2
	retlw	HIGH	pattern_9_2
	retlw	LOW	pattern_9_3
	retlw	HIGH	pattern_9_3
	retlw	LOW	pattern_10_0
	retlw	HIGH	pattern_10_0
	retlw	LOW	pattern_10_1
	retlw	HIGH	pattern_10_1
	retlw	LOW	pattern_10_2
	retlw	HIGH	pattern_10_2
	retlw	LOW	pattern_10_3
	retlw	HIGH	pattern_10_3
	retlw	0
	retlw	0
pattern_0_0:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'ED'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'ED'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'E7'
	retlw	H'83'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'E8'
	retlw	H'EA'
	retlw	H'EC'
	retlw	H'E8'
	retlw	H'E5'
	retlw	H'E7'
	retlw	H'E8'
	retlw	H'E9'
	retlw	H'EA'
	retlw	H'EC'
	retlw	H'ED'
	retlw	H'EA'
	retlw	H'E8'
	retlw	H'E7'
	retlw	H'E5'
	retlw	H'E3'
	retlw	0
pattern_0_1:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'EA'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EA'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EA'
	retlw	H'A3'
	retlw	H'CC'
pattern_0_2:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D9'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'DB'
	retlw	H'CC'
	retlw	H'DB'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D5'
	retlw	H'86'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D2'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'82'
	retlw	H'CC'
pattern_0_3:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D5'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D4'
	retlw	H'9A'
	retlw	H'CC'
pattern_1_0:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'EC'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EC'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EC'
	retlw	H'83'
	retlw	H'CC'
	retlw	0
pattern_1_1:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'EF'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EF'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'E8'
	retlw	H'83'
	retlw	H'CC'
pattern_1_2:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'DC'
	retlw	H'CC'
	retlw	H'DC'
	retlw	H'CC'
pattern_1_3:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D9'
	retlw	H'CC'
	retlw	H'D9'
	retlw	H'CC'
pattern_2_0:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'EC'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EC'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'DC'
	retlw	H'CC'
	retlw	H'DC'
	retlw	H'CC'
	retlw	0
pattern_2_1:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'EF'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EF'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D9'
	retlw	H'CC'
	retlw	H'D9'
	retlw	H'CC'
pattern_2_2:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'EC'
	retlw	H'83'
	retlw	H'CC'
pattern_2_3:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'E8'
	retlw	H'83'
	retlw	H'CC'
pattern_3_0:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'ED'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'ED'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EA'
	retlw	H'83'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'F1'
	retlw	H'EF'
	retlw	H'ED'
	retlw	H'EC'
	retlw	H'E9'
	retlw	H'EA'
	retlw	H'EC'
	retlw	H'ED'
	retlw	H'F1'
	retlw	H'E8'
	retlw	H'E7'
	retlw	H'EA'
	retlw	H'84'
	retlw	H'E8'
	retlw	0
pattern_3_1:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'F1'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F1'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'E7'
	retlw	H'A3'
	retlw	H'CC'
pattern_3_2:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D5'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'DB'
	retlw	H'CC'
	retlw	H'DB'
	retlw	H'CC'
	retlw	H'D4'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D9'
	retlw	H'86'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'E1'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'D0'
	retlw	H'CC'
pattern_3_3:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D2'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D0'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D5'
	retlw	H'86'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'DC'
	retlw	H'82'
	retlw	H'CC'
pattern_4_0:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'DC'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'DB'
	retlw	H'CC'
	retlw	H'DE'
	retlw	H'CC'
	retlw	H'D6'
	retlw	H'CC'
	retlw	H'D9'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'DB'
	retlw	H'CC'
	retlw	H'CF'
	retlw	H'D7'
	retlw	H'D2'
	retlw	H'D7'
	retlw	H'D0'
	retlw	H'D9'
	retlw	H'D4'
	retlw	H'D9'
	retlw	H'D1'
	retlw	H'D9'
	retlw	H'D4'
	retlw	H'D9'
	retlw	H'D2'
	retlw	H'82'
	retlw	H'CC'
	retlw	0
pattern_4_1:
	retlw	H'9C'
	retlw	H'CC'
	retlw	H'CC'
pattern_4_2:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'E0'
	retlw	H'EE'
	retlw	H'80'
	retlw	H'EF'
	retlw	H'7E'
	retlw	H'F1'
	retlw	H'EF'
	retlw	H'EE'
	retlw	H'EC'
	retlw	H'84'
	retlw	H'EA'
	retlw	H'7E'
	retlw	H'EC'
	retlw	H'EA'
	retlw	H'E8'
	retlw	H'E7'
	retlw	H'F8'
	retlw	H'F6'
	retlw	H'F4'
	retlw	H'F3'
	retlw	H'F0'
	retlw	H'F1'
	retlw	H'F3'
	retlw	H'F4'
	retlw	H'EC'
	retlw	H'EE'
	retlw	H'EF'
	retlw	H'F1'
	retlw	H'EF'
	retlw	H'EE'
	retlw	H'EC'
	retlw	H'EA'
pattern_4_3:
	retlw	H'7E'
	retlw	H'CC'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'E3'
	retlw	H'E0'
	retlw	H'E3'
	retlw	H'CC'
	retlw	H'E3'
	retlw	H'CC'
	retlw	H'E3'
	retlw	H'CC'
	retlw	H'82'
	retlw	H'DE'
	retlw	H'7E'
	retlw	H'CC'
	retlw	H'DE'
	retlw	H'CC'
	retlw	H'DE'
	retlw	H'9C'
	retlw	H'CC'
pattern_5_0:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'F3'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F3'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'DE'
	retlw	H'CC'
	retlw	H'DE'
	retlw	H'CC'
	retlw	H'80'
	retlw	H'DE'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D2'
	retlw	H'CC'
	retlw	H'D6'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	0
pattern_5_1:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'F6'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F6'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'E3'
	retlw	H'CC'
	retlw	H'E3'
	retlw	H'CC'
	retlw	H'E3'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'E2'
	retlw	H'CC'
	retlw	H'E2'
	retlw	H'CC'
	retlw	H'80'
	retlw	H'DB'
	retlw	H'CC'
	retlw	H'D0'
	retlw	H'90'
	retlw	H'CC'
pattern_5_2:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'F3'
	retlw	H'83'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F1'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F1'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EE'
	retlw	H'83'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'EF'
	retlw	H'F1'
	retlw	H'F3'
	retlw	H'EF'
	retlw	H'EB'
	retlw	H'EC'
	retlw	H'EF'
	retlw	H'EC'
	retlw	H'EA'
	retlw	H'E7'
	retlw	H'E8'
	retlw	H'E5'
	retlw	H'E3'
	retlw	H'82'
	retlw	H'CC'
pattern_5_3:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'6C'
	retlw	H'EF'
	retlw	H'83'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F4'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F4'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'F1'
	retlw	H'A3'
	retlw	H'CC'
pattern_6_0:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'86'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'9E'
	retlw	H'CC'
	retlw	0
pattern_6_1:
	retlw	H'84'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'DB'
	retlw	H'8A'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'DB'
	retlw	H'A2'
	retlw	H'CC'
pattern_6_2:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'E3'
	retlw	H'E5'
	retlw	H'E7'
	retlw	H'E8'
	retlw	H'EA'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'E7'
	retlw	H'E8'
	retlw	H'EA'
	retlw	H'EC'
	retlw	H'ED'
	retlw	H'82'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'EA'
	retlw	H'EC'
	retlw	H'ED'
	retlw	H'EF'
	retlw	H'F1'
	retlw	H'CC'
	retlw	H'F0'
	retlw	H'CC'
	retlw	H'EF'
	retlw	H'CC'
	retlw	H'EE'
	retlw	H'CC'
	retlw	H'ED'
	retlw	H'82'
	retlw	H'CC'
pattern_6_3:
	retlw	H'9C'
	retlw	H'CC'
	retlw	H'CC'
pattern_7_0:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D5'
	retlw	H'DB'
	retlw	H'D7'
	retlw	H'DB'
	retlw	H'D4'
	retlw	H'DC'
	retlw	H'D7'
	retlw	H'DC'
	retlw	H'D5'
	retlw	H'DB'
	retlw	H'D7'
	retlw	H'DB'
	retlw	H'D4'
	retlw	H'DC'
	retlw	H'D7'
	retlw	H'DC'
	retlw	H'D5'
	retlw	H'DE'
	retlw	H'D9'
	retlw	H'DE'
	retlw	H'D7'
	retlw	H'E0'
	retlw	H'DC'
	retlw	H'E0'
	retlw	H'D7'
	retlw	H'E1'
	retlw	H'DE'
	retlw	H'E1'
	retlw	0
pattern_7_1:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'E7'
	retlw	H'ED'
	retlw	H'EA'
	retlw	H'E7'
	retlw	H'F1'
	retlw	H'EF'
	retlw	H'ED'
	retlw	H'EC'
	retlw	H'EA'
	retlw	H'ED'
	retlw	H'EA'
	retlw	H'E7'
	retlw	H'F1'
	retlw	H'EF'
	retlw	H'ED'
	retlw	H'EC'
	retlw	H'F6'
	retlw	H'F4'
	retlw	H'F3'
	retlw	H'80'
	retlw	H'F1'
	retlw	H'7E'
	retlw	H'EF'
	retlw	H'ED'
	retlw	H'80'
	retlw	H'EC'
	retlw	H'7E'
	retlw	H'EA'
	retlw	H'E8'
	retlw	H'E7'
pattern_7_2:
	retlw	H'B4'
	retlw	H'CC'
pattern_7_3:
	retlw	H'B4'
	retlw	H'CC'
pattern_8_0:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'DC'
	retlw	H'E3'
	retlw	H'E0'
	retlw	H'E3'
	retlw	0
pattern_8_1:
	retlw	H'80'
	retlw	H'CB'
	retlw	H'77'
	retlw	H'EA'
	retlw	H'E8'
pattern_8_2:
	retlw	H'84'
	retlw	H'CC'
pattern_8_3:
	retlw	H'84'
	retlw	H'CC'
pattern_9_0:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'DC'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'DC'
	retlw	H'CC'
	retlw	H'D4'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D0'
	retlw	H'CC'
	retlw	H'D4'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'E8'
	retlw	H'CC'
	retlw	H'E8'
	retlw	H'CC'
	retlw	H'EF'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'EF'
	retlw	H'7D'
	retlw	H'ED'
	retlw	H'CC'
	retlw	H'EC'
	retlw	H'CC'
	retlw	H'EA'
	retlw	H'CC'
	retlw	0
pattern_9_1:
	retlw	H'7D'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'E8'
	retlw	H'CC'
	retlw	H'EC'
	retlw	H'CC'
	retlw	H'E3'
	retlw	H'CC'
	retlw	H'E8'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'E3'
	retlw	H'CC'
	retlw	H'DC'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'E3'
	retlw	H'7F'
	retlw	H'CC'
	retlw	H'7D'
	retlw	H'EC'
	retlw	H'CC'
	retlw	H'EC'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'EC'
	retlw	H'7D'
	retlw	H'DE'
	retlw	H'CC'
	retlw	H'DC'
	retlw	H'CC'
	retlw	H'E7'
	retlw	H'CC'
pattern_9_2:
	retlw	H'94'
	retlw	H'CC'
	retlw	H'84'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D7'
pattern_9_3:
	retlw	H'9C'
	retlw	H'CC'
pattern_10_0:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'D0'
	retlw	H'CC'
	retlw	H'D4'
	retlw	H'CC'
	retlw	H'D7'
	retlw	H'CC'
	retlw	H'D4'
	retlw	H'CC'
	retlw	H'84'
	retlw	H'D0'
	retlw	H'A4'
	retlw	H'CC'
	retlw	0
pattern_10_1:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'DC'
	retlw	H'CC'
	retlw	H'EC'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'E0'
	retlw	H'CC'
	retlw	H'80'
	retlw	H'E0'
	retlw	H'A8'
	retlw	H'CC'
pattern_10_2:
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'E8'
	retlw	H'CC'
	retlw	H'EF'
	retlw	H'CC'
	retlw	H'E8'
	retlw	H'CC'
	retlw	H'E8'
	retlw	H'CC'
	retlw	H'80'
	retlw	H'E8'
	retlw	H'A8'
	retlw	H'CC'
pattern_10_3:
	retlw	H'80'
	retlw	H'CC'
	retlw	H'7E'
	retlw	H'CB'
	retlw	H'72'
	retlw	H'F4'
	retlw	H'B6'
	retlw	H'CC'

	END
