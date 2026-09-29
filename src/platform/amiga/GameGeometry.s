| Exact sparse-matrix paths for the game's 3x3 fixed-point transforms.
| The four tested coefficients must be zero; every other matrix uses the
| disk-loaded original kernel. Keep its rounding sequence and register outputs.
| These renderer call sites use separate matrix and coordinate-output storage.
	.section .text.vetteGeometryTransform,"ax"
	.even
	.globl vetteVertexTransform
vetteVertexTransform:
	addq.w #2,a0

	.macro transform name,translated,original
	.section .text.\name,"ax"
	.even
	.globl \name
\name:
	.ifdef VETTE_GAME_KERNEL_VERIFY
	lea -64(sp),sp
	movem.l d0-d7/a0-a6,(sp)
	move.w ccr,62(sp)
	move.l #\translated,-(sp)
	pea 4(sp)
	jsr vetteVerifyLiveGameKernel
	addq.l #8,sp
	move.w 62(sp),ccr
	movem.l (sp),d0-d7/a0-a6
	lea 64(sp),sp
	rts
	.endif
	.globl \name\()Fast
\name\()Fast:
	move.w 2(a1),d0
	or.w 6(a1),d0
	or.w 10(a1),d0
	or.w 14(a1),d0
	beq.s 1f
	jmp \original
	.if !\translated
	.globl vetteVertexPlanar
vetteVertexPlanar:
	addq.w #2,a0
	.ifdef VETTE_GAME_KERNEL_VERIFY
	jmp vetteGeometryTransform
	.endif
	.endif
1:
	move.w (a0)+,d0
	move.w d0,d2
	muls.w (a1),d0
	move.w (a0)+,d3
	move.w (a0)+,d4
	move.w d4,d1
	muls.w 12(a1),d1
	add.l d1,d0
	clr.w d1
	asl.l #1,d0
	asl.w #1,d0
	swap d0
	addx.w d1,d0
	.if \translated
	add.w 18(a1),d0
	.endif
	move.w d0,(a2)+
	move.w d3,d0
	muls.w 8(a1),d0
	moveq #0,d1
	asl.l #1,d0
	asl.w #1,d0
	swap d0
	addx.w d1,d0
	.if \translated
	add.w 20(a1),d0
	.endif
	move.w d0,(a2)+
	muls.w 4(a1),d2
	moveq #0,d3
	muls.w 16(a1),d4
	add.l d4,d2
	clr.w d4
	asl.l #1,d2
	asl.w #1,d2
	swap d2
	addx.w d4,d2
	.if \translated
	add.w 22(a1),d2
	.endif
	move.w d2,(a2)+
	rts
	.endm
	transform vetteGeometryTransform,0,vetteGeometryOriginal
	transform vettePointTransform,1,vettePointOriginal

| Choose once per model vertex pass, not once per vertex. The cached-coordinate
| branch retains the complete original routine and its incoming D0 upper word.
	.section .text.vetteVertexDispatch,"ax"
	.even
	.globl vetteVertexDispatch
vetteVertexDispatch:
	tst.w d1
	bne.s 1f
	move.w 2(a1),d0
	or.w 6(a1),d0
	or.w 10(a1),d0
	or.w 14(a1),d0
	beq.s 2f
1:
	jmp vetteVertexPassOriginal
2:
	jmp vetteVertexPassFast
