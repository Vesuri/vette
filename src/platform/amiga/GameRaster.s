	.section .text.vetteGameCopyRow,"ax"
	.even
	.globl vetteGameCopyRow
| Replacement for Traffic+$67E6..+$67ED (the inner copy row only).
| D2.w = byte count minus one, always 3 mod 4 after the original ASL/SUBQ.
| Preserve every original output: D0 upper word, D0.w=-1, advanced A2/A3,
| other registers, and all five CCR bits. The caller retains row stepping.
| A1200's 68020 permits unaligned longword accesses. For forward overlaps of
| 1..3 bytes keep byte propagation; wider moves would change their semantics.
vetteGameCopyRow:
	move.w ccr,-(sp)
	move.l a2,d0
	sub.l a3,d0
	cmpi.l #4,d0
	blo.s 2f
	move.l d2,d0
	lsr.w #2,d0
1:
	move.l (a3)+,(a2)+
	dbf d0,1b
	move.w (sp)+,ccr
	tst.b -1(a3)
	rts
2:
	move.w (sp)+,ccr
	move.l d2,d0
3:
	move.b (a3)+,(a2)+
	dbf d0,3b
	rts

	.section .text.vetteGameCopyRowOriginal,"ax"
| Exact byte-loop oracle corresponding to the four verified original words.
	.globl vetteGameCopyRowOriginal
vetteGameCopyRowOriginal:
	move.l d2,d0
4:
	move.b (a3)+,(a2)+
	dbf d0,4b
	rts

| Diagnostic C ABI bridge: run either row body with all game registers/CCR
| supplied in state[0..15], then capture every output, including untouched ones.
	.section .text.vetteTestGameCopyRow,"ax"
	.globl vetteTestGameCopyRow
vetteTestGameCopyRow:
	movem.l d2-d7/a2-a6,-(sp)
	move.l 48(sp),a0
	move.l 52(sp),a1
	move.l a0,-(sp)
	pea 5f
	move.l a1,-(sp)
	move.w 62(a0),ccr
	movem.l (a0),d0-d7/a0-a6
	rts
5:
	movem.l d0-d7/a0-a6,-(sp)
	move.w ccr,d0
	move.l 60(sp),a0
	move.w d0,62(a0)
	move.l sp,a1
	moveq #14,d0
6:
	move.l (a1)+,(a0)+
	dbf d0,6b
	lea 64(sp),sp
	movem.l (sp)+,d2-d7/a2-a6
	rts
