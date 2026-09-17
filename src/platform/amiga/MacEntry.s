	.text
	.even
	.globl vette_call_mac_code
vette_call_mac_code:
	move.l 4(sp),a0
	move.l 8(sp),a1
	movem.l d2-d7/a2-a6,-(sp)
	move.l a1,a5
	jsr (a0)
	movem.l (sp)+,d2-d7/a2-a6
	rts

	.globl vette_line_a_handler
vette_line_a_handler:
	movem.l d0-d7/a0-a6,-(sp)
	move.l sp,a0
	lea 60(sp),a1
	move.l usp,a2
	move.l a2,-(sp)
	move.l a1,-(sp)
	move.l a0,-(sp)
	jsr vetteLineADispatch
	lea 12(sp),sp
	tst.l d0
	beq.s 1f
	subq.l #1,d0
	move.l usp,a0
	adda.w d0,a0
	move.l a0,usp
	movem.l (sp)+,d0-d7/a0-a6
	addq.l #2,2(sp)
	rte
1:
	bra.s 1b
