; ----------------------------------------------------------------------
; Mega CD Mode 1 Library
; ----------------------------------------------------------------------
; Mega CD/Mode 1 functions
; ----------------------------------------------------------------------
; Copyright (c) 2024 Devon Artmeier
;
; Permission to use, copy, modify, and/or distribute this software
; for any purpose with or without fee is hereby granted.
;
; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
; WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIE
; WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
; AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
; DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
; PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER 
; TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
; PERFORMANCE OF THIS SOFTWARE.
; ----------------------------------------------------------------------

; ----------------------------------------------------------------------
; Initialize the Mega CD
; ----------------------------------------------------------------------
; PARAMETERS:
;	a0.l  - Pointer to Sub CPU program
;	d0.l  - Size of Sub CPU program
; RETURNS:
;	d0.b  - Error code
;	        0 - Success
;	        1 - No BIOS found
;	        2 - Program load failed
;	        3 - Hardware failure
;	eq/ne - Success/Failure
; ----------------------------------------------------------------------

InitMcd:
	movem.l	d0/a0,-(sp)				; Save registers
	
	bsr.w	CheckMcdBios				; Check for a BIOS
	bne.s	InitMcd_NoBIOS				; If no BIOS was found, branch
	
	bsr.w	ResetMcdGateArray			; Reset the Gate Array
	
	moveq	#0,d0					; Clear communication registers
	lea	$A12010,a1
	move.b	d0,-2(a1)
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	
	move.l	#$100,d0				; Hold Sub CPU reset
	bsr.w	HoldMcdResetTimed
	bne.s	InitMcd_HardwareFail			; If it failed, branch
	
	bsr.w	RequestMcdBusTimed			; Request Sub CPU bus access
	bne.s	InitMcd_HardwareFail			; If it failed, branch
	
	move.b	#0,$A12002				; Disable write protection
	
	lea	$420000,a1				; Decompress Sub CPU BIOS
	jsr	SubCpuKosDec
	
	movem.l (sp),d0/a0				; Load Sub CPU program
	move.l	#$6000,d1
	bsr.w	CopyMcdPrgRamData
	bne.s	InitMcd_ProgramLoadFail			; If it failed, branch
	
	move.b	#$2A,$A12002				; Enable write protection	

	move.l	#$100,d0				; Release Sub CPU reset
	bsr.w	ReleaseMcdResetTimed
	bne.s	InitMcd_HardwareFail			; If it failed, branch
	
	bsr.w	ReleaseMcdBusTimed		; Release Sub CPU bus
	bne.s	InitMcd_HardwareFail			; If it failed, branch
	
	movem.l (sp)+,d0/a0				; Success
	moveq	#0,d0
	rts

InitMcd_NoBIOS:
	movem.l (sp)+,d0/a0				; No BIOS found
	moveq	#1,d0
	rts

InitMcd_ProgramLoadFail:
	movem.l (sp)+,d0/a0				; Program load failed
	moveq	#2,d0
	rts

InitMcd_HardwareFail:
	move.b	#%00000010,$A12001			; Halt the Sub CPU
	
	movem.l (sp)+,d0/a0				; Hardware failure
	moveq	#3,d0
	rts

; ----------------------------------------------------------------------
; Check if there's a Mega CD BIOS available
; ----------------------------------------------------------------------
; RETURNS:
;	eq/ne - Found/Not found
;	a0.l  - Pointer to compress Sub CPU BIOS, if found
; ----------------------------------------------------------------------

CheckMcdBios:
	cmpi.l	#"SEGA",$400100				; Is the "SEGA" signature present?
	bne.s	CheckMcdBios_End			; If not, branch
	cmpi.w	#"BR",$400180				; Is the "Boot ROM" software type present?
	bne.s	CheckMcdBios_End			; If not, branch
	
	lea	McdBiosSignatures(pc),a1		; Get known signature location list

CheckMcdBios_FindLoop:
	move.l	(a1)+,d0				; Get pointer to signature data to check
	movea.l	d0,a2
	beq.s	CheckMcdBios_NotFound			; If we are at the end of the list, branch
	
	movea.l	(a2)+,a0				; Get pointer to Sub CPU BIOS
	movea.l	(a2)+,a3				; Get pointer to signature

CheckMcdBios_CheckSignature:
	move.b	(a2)+,d0				; Get character
	beq.s	CheckMcdBios_End			; If we are done checking, branch
	cmp.b	(a3)+,d0				; Does the signature match so far?
	bne.s	CheckMcdBios_FindLoop			; If not, check the next BIOS
	bra.s	CheckMcdBios_CheckSignature		; Loop until signature is fully checked

CheckMcdBios_NotFound:
	andi	#%11111011,ccr				; BIOS not found

CheckMcdBios_End:
	rts

; ----------------------------------------------------------------------

McdBiosSignatures:
	dc.l	McdBios_Sega15800
	dc.l	McdBios_Sega16000
	dc.l	McdBios_Sega1AD00
	dc.l	McdBios_Wonder16000
	dc.l	0
	
McdBios_Sega15800:
	dc.l	$415800
	dc.l	$41586D
	dc.b	"SEGA", 0
	even
	
McdBios_Sega16000:
	dc.l	$416000
	dc.l	$41606D
	dc.b	"SEGA", 0
	even
	
McdBios_Sega1AD00:
	dc.l	$41AD00
	dc.l	$41AD6D
	dc.b	"SEGA", 0
	even
	
McdBios_Wonder16000:
	dc.l	$416000
	dc.l	$41606D
	dc.b	"WONDER", 0
	even

; ----------------------------------------------------------------------
; Sub CPU initialization IRQ2 trigger and delay
; ----------------------------------------------------------------------
; Use this when waiting for the Sub CPU to initialize after loading
; the BIOS and system program and starting the Sub CPU. If this
; doesn't fit your needs, then you can manually call TriggerMcdIrq2
; however you please.
; ----------------------------------------------------------------------

McdInitIrq2:
	move.w	d0,-(sp)				; Save d0
	move	sr,-(sp)				; Save interrupt settings
	move	#$2700,sr				; Disable interrupts

	bsr.s	TriggerMcdIrq2				; Trigger the Sub CPU's IRQ2

	move.w	#$2DCE-1,d0				; Delay for a while

McdInitIrq2_Wait:
	dbf	d0,McdInitIrq2_Wait

	move	(sp)+,sr				; Restore interrupt settings
	move.w	(sp)+,d0				; Restore d0
	rts

; ----------------------------------------------------------------------
; Reset the Gate Array
; ----------------------------------------------------------------------

ResetMcdGateArray:
	move.l	d0,-(sp)				; Save d0
	
	move.w	#$FF00,$A12002				; Reset sequence
	move.b	#3,$A12001
	move.b	#2,$A12001
	move.b	#0,$A12001

	moveq	#$80-1,d0				; Wait for a bit to process

ResetMcdGateArray_Wait:
	dbf	d0,ResetMcdGateArray_Wait
	
	move.l	(sp)+,d0				; Restore d0
	rts
	
; ----------------------------------------------------------------------
; Trigger the Sub CPU's IRQ2
; ----------------------------------------------------------------------

TriggerMcdIrq2:
	bset	#0,$A12000				; Trigger the Sub CPU's IRQ2
	rts

; ----------------------------------------------------------------------
; Hold Sub CPU reset
; ----------------------------------------------------------------------

HoldMcdReset:
	bclr	#0,$A12001				; Hold Sub CPU reset
	bne.s	HoldMcdReset
	rts

; ----------------------------------------------------------------------
; Release Sub CPU reset
; ----------------------------------------------------------------------

ReleaseMcdReset:
	bset	#0,$A12001				; Release Sub CPU reset
	beq.s	ReleaseMcdReset
	rts

; ----------------------------------------------------------------------
; Hold Sub CPU reset (timed)
; ----------------------------------------------------------------------
; PARAMETERS:
;	d0.l  - Time to wait
; RETURNS:
;	eq/ne - Success/Failure
; ----------------------------------------------------------------------

HoldMcdResetTimed:
	move.l	d0,-(sp)				; Save d0

HoldMcdResetTimed_Wait:
	bclr	#0,$A12001				; Hold Sub CPU reset
	beq.s	HoldMcdResetTimed_Success		; If it was successful, branch
	subq.l	#1,d0					; Decrement time left
	bne.s	HoldMcdResetTimed_Wait			; Loop if we should try again
	
	move.l	(sp)+,d0				; Restore d0
	andi	#%11111011,ccr				; Failure
	rts
	
HoldMcdResetTimed_Success:
	move.l	(sp)+,d0				; Restore d0
	ori	#%00000100,ccr				; Success
	rts

; ----------------------------------------------------------------------
; Release Sub CPU reset (timed)
; ----------------------------------------------------------------------
; PARAMETERS:
;	d0.l  - Time to wait
; RETURNS:
;	eq/ne - Success/Failure
; ----------------------------------------------------------------------

ReleaseMcdResetTimed:
	move.l	d0,-(sp)				; Save d0

ReleaseMcdResetTimed_Wait:
	bset	#0,$A12001				; Release Sub CPU reset
	bne.s	ReleaseMcdResetTimed_Success		; If it was successful, branch
	subq.l	#1,d0					; Decrement time left
	bne.s	ReleaseMcdResetTimed_Wait		; Loop if we should try again
	
	move.l	(sp)+,d0				; Restore d0
	andi	#%11111011,ccr				; Failure
	rts
	
ReleaseMcdResetTimed_Success:
	move.l	(sp)+,d0				; Restore d0
	ori	#%00000100,ccr				; Success
	rts

; ----------------------------------------------------------------------
; Request access to the Sub CPU bus
; ----------------------------------------------------------------------

RequestMcdBus:
	bset	#1,$A12001				; Request Sub CPU bus access
	beq.s	RequestMcdBus
	rts

; ----------------------------------------------------------------------
; Release the Sub CPU bus
; ----------------------------------------------------------------------

ReleaseMcdBus:
	bclr	#1,$A12001				; Release Sub CPU bus
	bne.s	ReleaseMcdBus
	rts

; ----------------------------------------------------------------------
; Request access to the Sub CPU bus (timed)
; ----------------------------------------------------------------------
; PARAMETERS:
;	d0.l  - Time to wait
; RETURNS:
;	eq/ne - Success/Failure
; ----------------------------------------------------------------------

RequestMcdTimed:
	move.l	d0,-(sp)				; Save d0

RequestMcdBusTimed_Wait:
	bset	#1,$A12001				; Request Sub CPU bus access
	bne.s	RequestMcdBusTimed_Success		; If it was successful, branch
	subq.l	#1,d0					; Decrement time left
	bne.s	RequestMcdBusTimed_Wait			; Loop if we should try again
	
	move.l	(sp)+,d0				; Restore d0
	andi	#%11111011,ccr				; Failure
	rts
	
RequestMcdBusTimed_Success:
	move.l	(sp)+,d0				; Restore d0
	ori	#%00000100,ccr				; Success
	rts

; ----------------------------------------------------------------------
; Release the Sub CPU bus (timed)
; ----------------------------------------------------------------------
; PARAMETERS:
;	d0.l  - Time to wait
; RETURNS:
;	eq/ne - Success/Failure
; ----------------------------------------------------------------------

ReleaseMcdBusTimed:
	move.l	d0,-(sp)				; Save d0

ReleaseMcdBusTimed_Wait:
	bclr	#1,$A12001				; Release Sub CPU bus
	beq.s	ReleaseMcdBusTimed_Success		; If it was successful, branch
	subq.l	#1,d0					; Decrement time left
	bne.s	ReleaseMcdBusTimed_Wait			; Loop if we should try again
	
	move.l	(sp)+,d0				; Restore d0
	andi	#%11111011,ccr				; Failure
	rts
	
ReleaseMcdBusTimed_Success:
	move.l	(sp)+,d0				; Restore d0
	ori	#%00000100,ccr				; Success
	rts
	
; ----------------------------------------------------------------------
; Copy data to the Sub CPU's Program RAM
; ----------------------------------------------------------------------
; You should get access to the Sub CPU's bus before calling this.
; ----------------------------------------------------------------------
; PARAMETERS:
;	a0.l  - Pointer to data to copy
;	d0.l  - Length of data to copy
;	d1.l  - Program RAM offset
; RETURNS:
;	eq/ne - Success/Failure
;	d1.l  - Advanced Program RAM offset
;	a0.l  - End of data
; ----------------------------------------------------------------------

CopyMcdPrgRamData:
	movem.l	d0/d2/a1,-(sp)				; Save registers	

	move.l	d1,d2					; Set Program RAM bank ID
	swap	d2
	ror.b	#3,d2
	andi.b	#%11000000,d2
	andi.b	#%00111111,$A12003
	or.b	d2,$A12003
	
	lea	$420000,a1				; Get initial copy destination
	move.l	d1,d2
	andi.l	#$1FFFF,d2
	adda.l	d2,a1
	
	add.l	d0,d1					; Advance Program RAM offset
	
CopyMcdPrgRamData_CopyData:
	move.b	(a0),(a1)				; Copy byte
	cmpm.b	(a0)+,(a1)+				; Did it copy correctly?
	bne.s	CopyMcdPrgRamData_Fail			; If not, branch
	
	subq.l	#1,d0					; Decrement number of bytes left to copy
	beq.s	CopyMcdPrgRamData_Success			; If we are finished, branch
	
	cmpa.l	#$440000,a1				; Have we reached the end of the bank?
	bcs.s	CopyMcdPrgRamData_CopyData			; If not, branch

	addi.b	#$40,$A12003				; Go to next bank
	lea	$420000,a1
	bra.s	CopyMcdPrgRamData_CopyData

CopyMcdPrgRamData_Fail:
	movem.l	(sp)+,d0/d2/a1				; Restore registers
	andi	#%11111011,ccr				; Failure
	rts
	
CopyMcdPrgRamData_Success:
	movem.l	(sp)+,d0/d2/a1				; Restore registers
	ori	#%00000100,ccr				; Success
	rts

; ----------------------------------------------------------------------