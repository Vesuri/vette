	.text
	.even
	.globl vetteMappedCopyAsm

| void vetteMappedCopyAsm(const uint8_t* source, uint8_t* destination,
|                         const uint8_t* map, uint32_t count)
|
| Translate each packed-pixel byte through a 256-entry table.  Four independent
| lookups amortise DBF while the table stays in a2.  count is reduced to groups
| of four, which is at most 21,888 for Vette's 512x342 GWorld and therefore fits
| DBF's 16-bit counter without a 32-bit test in the hot loop.
vetteMappedCopyAsm:
	movem.l	d2-d5/a2,-(sp)
	move.l	24(sp),a0
	move.l	28(sp),a1
	move.l	32(sp),a2
	move.l	36(sp),d1
	move.l	d1,d0
	andi.w	#3,d0
	lsr.l	#2,d1
	beq.s	2f
	subq.l	#1,d1
1:
	moveq	#0,d2
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
	move.b	(a0)+,d2
	move.b	(a0)+,d3
	move.b	(a0)+,d4
	move.b	(a0)+,d5
	move.b	0(a2,d2.w),(a1)+
	move.b	0(a2,d3.w),(a1)+
	move.b	0(a2,d4.w),(a1)+
	move.b	0(a2,d5.w),(a1)+
	dbf	d1,1b
2:
	tst.w	d0
	beq.s	4f
	subq.w	#1,d0
3:
	moveq	#0,d2
	move.b	(a0)+,d2
	move.b	0(a2,d2.w),(a1)+
	dbf	d0,3b
4:
	movem.l	(sp)+,d2-d5/a2
	rts
