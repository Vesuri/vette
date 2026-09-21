	.text
	.even
	.globl vetteDrivingCopyAsm

| Copy the visible 512x320 packed window from Vette's faithful 260-byte
| offscreen rows to the port's 256-byte logical-screen rows.  Eight unrolled
| longword moves per inner iteration cover 32 bytes; eight iterations cover a
| row, then the source skips its four-byte QuickDraw slop word.
vetteDrivingCopyAsm:
	move.l	4(sp),a0
	move.l	8(sp),a1
	move.w	#319,d0
1:
	moveq	#7,d1
2:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d1,2b
	addq.l	#4,a0
	dbf	d0,1b
	rts
