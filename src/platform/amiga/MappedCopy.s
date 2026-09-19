	.text
	.even
	.globl vetteMappedCopyRowsAsm

| void vetteMappedCopyRowsAsm(const uint8_t* source, uint8_t* destination,
|     const uint8_t* map, uint32_t rowBytes, uint32_t height,
|     uint32_t sourceModulo, uint32_t destinationModulo)
|
| Translate each packed-pixel byte through a 256-entry table.  Four independent
| lookups amortise DBF while the table stays in a2.  The source and destination
| pointers already advance by rowBytes in the inner loop; the two modulos move
| them to the next row.  Vette's largest row/group counts fit DBF's 16-bit
| counters, avoiding 32-bit tests in either hot loop.
vetteMappedCopyRowsAsm:
	movem.l	d2-d7/a2-a4,-(sp)
	move.l	40(sp),a0
	move.l	44(sp),a1
	move.l	48(sp),a2
	move.l	52(sp),d6
	move.l	56(sp),d7
	move.l	60(sp),a3
	move.l	64(sp),a4
	tst.l	d7
	beq.s	5f
	subq.l	#1,d7
1:
	move.l	d6,d1
	move.l	d1,d0
	andi.w	#3,d0
	lsr.l	#2,d1
	beq.s	3f
	subq.l	#1,d1
2:
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
	dbf	d1,2b
3:
	tst.w	d0
	beq.s	4f
	subq.w	#1,d0
6:
	moveq	#0,d2
	move.b	(a0)+,d2
	move.b	0(a2,d2.w),(a1)+
	dbf	d0,6b
4:
	adda.l	a3,a0
	adda.l	a4,a1
	dbf	d7,1b
5:
	movem.l	(sp)+,d2-d7/a2-a4
	rts
