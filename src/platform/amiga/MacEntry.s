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
	tst.l g_macVBLCallbackEntry
	beq.s 2f
	move.l 2(sp),g_macVBLCallbackReturn
	move.l #vette_user_vbl_trampoline,2(sp)
2:
	rte
1:
	bra.s 1b

| Entered by RTE in user mode, with the original application's registers and
| USP restored.  Run one due Macintosh VBLTask and resume at the instruction
| following the trap that provided this safe scheduling point.
	.globl vette_user_vbl_trampoline
vette_user_vbl_trampoline:
	movem.l d0-d7/a0-a6,-(sp)
	move.l g_macVBLCallbackEntry,a1
	clr.l g_macVBLCallbackEntry
	move.l g_macVBLCallbackTask,a0
	move.l g_macVBLCallbackA5,a5
	move.w #1,g_macVBLCallbackActive
	jsr (a1)
	clr.w g_macVBLCallbackActive
	movem.l (sp)+,d0-d7/a0-a6
	move.l g_macVBLCallbackReturn,-(sp)
	rts
