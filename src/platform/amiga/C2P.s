	.text
	.even
	.globl vetteC2PSpanAsm

| void vetteC2PSpanAsm(const uint8_t* source, uint8_t* destination,
|                      const uint32_t* table, uint16_t groups)
|
| One group is four packed Macintosh bytes (eight pixels) and produces one
| byte in each of the four Amiga planes.  The four 1 KiB table quarters encode
| the pixel-pair positions. Keeping their bases in address registers removes
| the repeated +1024/+2048/+3072 address arithmetic emitted by GCC.
vetteC2PSpanAsm:
	movem.l	d2-d3/a2-a5,-(sp)
	move.l	28(sp),a0
	move.l	32(sp),a1
	move.l	36(sp),a2
	| GCC reserves a four-byte argument slot for uint16_t; on big-endian 68k
	| the value occupies its low word at +42, not the high word at +40.
	move.w	42(sp),d3
	beq.s	3f
	subq.w	#1,d3
	lea	1024(a2),a3
	lea	2048(a2),a4
	lea	3072(a2),a5
1:
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	move.l	0(a2,d0.w),d1
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	or.l	0(a3,d0.w),d1
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	or.l	0(a4,d0.w),d1
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	or.l	0(a5,d0.w),d1
	move.b	d1,192(a1)
	lsr.l	#8,d1
	move.b	d1,128(a1)
	lsr.l	#8,d1
	move.b	d1,64(a1)
	lsr.l	#8,d1
	move.b	d1,(a1)+
	dbf	d3,1b
3:
	movem.l	(sp)+,d2-d3/a2-a5
	rts
