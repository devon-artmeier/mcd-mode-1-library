; ----------------------------------------------------------------------
; Mega CD Mode 1 Library
; ----------------------------------------------------------------------
; Kosinski decompression
; Format details: https://segaretro.org/Kosinski_compression
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
; Decompress Kosinski data
; ----------------------------------------------------------------------
; PARAMETERS:
;	a0.l - Pointer to source data
;	a1.l - Pointer to destination buffer
; ----------------------------------------------------------------------
; RETURNS:
;	a0.l - Pointer to end of source data
;	a1.l - Pointer to end of destination buffer
; ----------------------------------------------------------------------

McdKosDec:
	movem.l	d0-d3/a2,-(sp)				; Save registers
	
	move.b	(a0)+,-(sp)				; Read from data stream
	move.b	(a0)+,-(sp)
	move.w	(sp)+,d1
	move.b	(sp)+,d1
	moveq	#16-1,d0				; 16 bits to process

; ----------------------------------------------------------------------

McdKosDec_GetCode:
	lsr.w	#1,d1					; Get code
	bcc.s	McdKosDec_Code0x			; If it's 0, branch

; ----------------------------------------------------------------------

McdKosDec_Code1:
	dbf	d0,McdKosDec_CopyUncByte		; Decrement bits left to process
	move.b	(a0)+,-(sp)				; Read from data stream
	move.b	(a0)+,-(sp)
	move.w	(sp)+,d1
	move.b	(sp)+,d1
	moveq	#16-1,d0				; 16 bits to process

McdKosDec_CopyUncByte:
	move.b	(a0)+,(a1)+				; Copy uncompressed byte
	bra.s	McdKosDec_GetCode			; Process next code

; ----------------------------------------------------------------------

McdKosDec_Code0x:
	dbf	d0,McdKosDec_PrepareCopy		; Decrement bits left to process
	move.b	(a0)+,-(sp)				; Read from data stream
	move.b	(a0)+,-(sp)
	move.w	(sp)+,d1
	move.b	(sp)+,d1
	moveq	#16-1,d0				; 16 bits to process

McdKosDec_PrepareCopy:
	moveq	#$FFFFFFFF,d2				; Copy offsets are always negative
	moveq	#0,d3					; Reset copy counter

	lsr.w	#1,d1					; Get 2nd code bit
	bcs.s	McdKosDec_Code01			; If the full code is 01, branch

; ----------------------------------------------------------------------

McdKosDec_Code00:
	dbf	d0,McdKosDec_GetNumBytesH		; Decrement bits left to process
	move.b	(a0)+,-(sp)				; Read from data stream
	move.b	(a0)+,-(sp)
	move.w	(sp)+,d1
	move.b	(sp)+,d1
	moveq	#16-1,d0				; 16 bits to process

McdKosDec_GetNumBytesH:
	lsr.w	#1,d1					; Get number of bytes to copy (upper)
	addx.w	d3,d3
	
	dbf	d0,McdKosDec_GetNumBytesL		; Decrement bits left to process
	move.b	(a0)+,-(sp)				; Read from data stream
	move.b	(a0)+,-(sp)
	move.w	(sp)+,d1
	move.b	(sp)+,d1
	moveq	#16-1,d0				; 16 bits to process

McdKosDec_GetNumBytesL:
	lsr.w	#1,d1					; Get number of bytes to copy (lower)
	addx.w	d3,d3
	
	dbf	d0,McdKosDec_GetCopyOffset00	; Decrement bits left to process
	move.b	(a0)+,-(sp)				; Read from data stream
	move.b	(a0)+,-(sp)
	move.w	(sp)+,d1
	move.b	(sp)+,d1
	moveq	#16-1,d0				; 16 bits to process

McdKosDec_GetCopyOffset00:
	move.b	(a0)+,d2				; Get copy offset

; ----------------------------------------------------------------------

McdKosDec_Copy:
	lea	(a1,d2.w),a2				; Get copy address
	move.b	(a2)+,(a1)+				; Copy a byte

McdKosDec_CopyLoop:
	move.b	(a2)+,(a1)+				; Copy a byte
	dbf	d3,McdKosDec_CopyLoop		; Loop until bytes are copied

	bra.w	McdKosDec_GetCode			; Process next code

; ----------------------------------------------------------------------

McdKosDec_Code01:
	dbf	d0,McdKosDec_GetCopyOffset01	; Decrement bits left to process
	move.b	(a0)+,-(sp)				; Read from data stream
	move.b	(a0)+,-(sp)
	move.w	(sp)+,d1
	move.b	(sp)+,d1
	moveq	#16-1,d0				; 16 bits to process

McdKosDec_GetCopyOffset01:
	move.b	(a0)+,-(sp)				; Get copy offset
	move.b	(a0)+,d2
	move.b	d2,d3
	lsl.w	#5,d2
	move.b	(sp)+,d2

	andi.w	#7,d3					; Get 3-bit copy count
	bne.s	McdKosDec_Copy			; If this is a 3-bit copy count, branch

	move.b	(a0)+,d3				; Get 8-bit copy count
	beq.s	McdKosDec_End			; If it's 0, we are done decompressing
	subq.b	#1,d3					; Is it 1?
	bne.s	McdKosDec_Copy			; If not, start copying
	
	bra.w	McdKosDec_GetCode			; Process next code

McdKosDec_End:
	movem.l	(sp)+,d0-d3/a2				; Restore registers
	rts
	
; ----------------------------------------------------------------------