;==========================================================
; ClockMod.asm
;----------------------------------------------------------
; Project using an 8-pin 12F509, programmed to make a stage
; clock run twice as fast as normal.
;----------------------------------------------------------
; Created by:  Miki R. Marshall
;----------------------------------------------------------
;	Chip:	12F509	
;	OscCal:	0CE8 @ 03FF  (0C = movlw, E8 = OscCal)
;==========================================================

;----------------------------------------------------------
;Compile options

	title		"ClockMod"
	list 		p=12C509
	
	;Include files
	include	 	"p12C509.inc"
	include	 	"macros.inc"
	include		"register.inc"

	;Turn off annoying messages
	ERRORLEVEL	-306, -302, -202, -227

;==========================================================
;	Configuration word and Chip ID for _this_ chip

	__CONFIG		_CP_OFF&_IntRC_OSC&_MCLRE_OFF&_WDT_OFF
	
	__IDLOCS		h'0001'

;==========================================================
	ORG	h'0000'

;----------------------------------------------------------
;PAGE 0 -- The Main Program Page (Reset/power-up vector)
;----------------------------------------------------------
;NOTE:	The reset vector for the 12F509 is actually 03FFh,
;	where the internal oscillator calibration value is
;	factory set (don't bulk erase without saving this)
;	into the W register (with a MOVLW).
;	When using the internal oscillator, the first line
;	of code must then always be:
;
	movwf	OSCCAL		;Set osc. calib. constant
;
;.........................................................;

Setup

	bcf	STATUS,PA0	;Page0
	bcf	FSR,5		;Bank0
	
	clrf	RUNSTAT		;Clear run statuses
	
	movlw	b'00001000'	;Wake on pin chg, input pullups,
	OPTION			;int. clock, prescaler=off
	
	movlw	b'00001001'	;TRIS: GP0,3     = inputs,
	TRIS	GPIO		;      GP1,2,4,5 = outputs
	
	movlw	d'05'		;Set debounce delays to 1:5
	movwf	BTN0DB
	movwf	BTN1DB
	
InitDisplay
	clrf	GPIO		;Clear output pins
	
	btfss	RUNMODE,FAST	;Fast mode? (Persists thru sleep)
	goto	SlowMode		;No
	
FastMode
	bsf	GPIO,2		;Yes, display fast mode
	goto	StartLoop
	
SlowMode
	bsf	GPIO,1		;Display slow mode

;..........................................................
;Main program loop

StartLoop
	movlw	d'125'		;Set postscalers to 1:125
	movwf	TMRPS0
	movwf	TMRPS1
	
MainLoop
	btfsc	RUNSTAT,BUTTON0	;Button 0 pressed?
	goto	DoButton0	;Yes, set run/stby mode
	
	btfsc	RUNSTAT,BUTTON1	;Button 1 pressed?
	goto	DoButton1	;Yes, set speed mode

TimerCheck
	btfsc	TMR0,6		;Timer bit (64) set?
	goto	TimerHigh	;Yes, handle it
	
TimerLow
	btfss	RUNSTAT,TMRLAST	;Last timer high?
	goto	MainLoop		;No, both low, nevermind
	
	bcf	RUNSTAT,TMRLAST	;Yes, save current status
	goto	Postscaler0	;Handle timer cycle
	
TimerHigh
	btfsc	RUNSTAT,TMRLAST	;Last timer low?
	goto	MainLoop		;No, both high, nevermind
	
	bsf	RUNSTAT,TMRLAST	;Yes, save current status

Postscaler0

	;64 usecs just passed...
	
	decfsz	TMRPS0,F		;Decrement postscaler0; Zero?
	goto	MainLoop		;No, main loop
	
	;8 msecs just passed...
	
	movlw	d'125'		;Yes, reset first postscaler
	movwf	TMRPS0
	
	call	ButtonCheck	;Check buttons for activity

FastModeCheck	
	btfss	RUNMODE,FAST	;Fast mode?
	goto	Postscaler1	;No, continue to postscaler1
	
	movfw	TMRPS1		;Postscaler1 ~= 1/2 sec?
	xorlw	d'62'
	btfsc	STATUS,Z
	
	call	Toggle		;Yes, toggle output
	
Postscaler1	
	decfsz	TMRPS1,F		;Decrement second postscaler
	goto	MainLoop		;Not zero, continue
	
	;1 second just passed...
	
	call	Toggle		;Normal speed output toggle
	
	goto	StartLoop	;Next cycle
	

DoButton0
	bcf	RUNSTAT,BUTTON0	;Clear flag
	
	btfsc	STATUS,GPWUF	;Just woke up from sleep?
	goto	IgnoreBtn0	;Yes, ignore (still waking)
	
	clrf	GPIO		;Clear all I/O pins
	nop			;Wait for port to set
	
	sleep			;Put MCU to sleep
				;(Resets on waking)
	
IgnoreBtn0
	bcf	STATUS,GPWUF	;Clear waking up flag
	goto	MainLoop		;Continue
	

DoButton1
	bcf	RUNSTAT,BUTTON1	;Clear flag
	
	btfsc	RUNMODE,FAST	;Fast mode?
	goto	SetSpeedSlow	;Yes, turn it off
	
	bsf	RUNMODE,FAST	;No, turn it on
	
	bsf	GPIO,2		;Display fast mode
	nop
	bcf	GPIO,1		;Clear slow mode
	
	goto	MainLoop		;Continue
	
SetSpeedSlow
	bcf	RUNMODE,FAST	;Turn it off

	bcf	GPIO,2		;Clear fast mode
	nop
	bsf	GPIO,1		;Display slow mode
	
	goto	MainLoop		;Continue


;==========================================================
;Called Subroutines  (Place in Page1, when space is needed)

;Check for ButtonX pressed
;	This subroutine imposes a 24 msec. delay to ensure
;	the input is debounced.  (Down completely for 10ms,
;	then up before the RUNSTAT,BUTTONx flag is set.)
;
ButtonCheck
	btfsc	GPIO,0		;Is button0 pressed (low)
	goto	Button0Up	;No, check if it was
	
	decfsz	BTN0DB,F		;Yes, decr. debounce delay.  Zero?
	goto	NextButton	;No, wait for debounce delay
	
	bsf	RUNSTAT,BTN0DN	;Yes, debounced, wait for release
	goto	NextButton	;Til next time...
	
Button0Up
	btfss	RUNSTAT,BTN0DN	;Was it down before this?
	goto	Button0Clear	;No, nothing to do
	
	bsf	RUNSTAT,BUTTON0	;Yes, we got a button push
	bcf	RUNSTAT,BTN0DN	;Clear debounced-and-down flag

Button0Clear
	movlw	h'05'		;Reset debounce delay, when up
	movwf	BTN0DB		; (3 x 8msec = 24 msec delay)
	
NextButton
	btfsc	GPIO,3		;Is button1 pressed (low)
	goto	Button1Up	;No, check if it was
	
	decfsz	BTN1DB,F		;Yes, decr. debounce delay.  Zero?
	goto	Button1Done	;No, wait for debounce delay
	
	bsf	RUNSTAT,BTN1DN	;Yes, debounced, wait for release
	goto	Button1Done	;Til next time...
	
Button1Up
	btfss	RUNSTAT,BTN1DN	;Was it down before this?
	goto	Button1Clear	;No, nothing to do
	
	bsf	RUNSTAT,BUTTON1	;Yes, we got a button push
	bcf	RUNSTAT,BTN1DN	;Clear debounced-and-down flag

Button1Clear
	movlw	h'05'		;Reset debounce delay, when up
	movwf	BTN1DB		; (3 x 8msec = 24 msec delay)
	
Button1Done
	return


;Toggle reversing coil outputs on GP4 and 5
Toggle
	btfss	RUNSTAT,TGLDIR	;Output currently "forward"?
	goto	ToggleFwd	;No, toggle forward
	
ToggleRev
	bsf	GPIO,4		;GP4=1
	nop			;Wait for pin to set
	bcf	GPIO,5		;GP5=0
	
	bcf	RUNSTAT,TGLDIR	;Set "reverse" flag
	
	return
	
ToggleFwd
	bcf	GPIO,4		;GP4=0
	nop			;Wait for pin to set
	bsf	GPIO,5		;GP5=1
	
	bsf	RUNSTAT,TGLDIR	;Set "forward" flag
	
	return

;==========================================================
;	Restore internal oscillator callibration for this chip

	ORG	h'03FF'
	
	movlw	h'E8'		;Chip ID 0001h

;==========================================================
	END			;End of program
;==========================================================
