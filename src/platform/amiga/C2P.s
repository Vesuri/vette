	.text
	.even
	.globl vetteC2PSpanAsm

| void vetteC2PSpanAsm(const uint8_t* source, uint8_t* destination,
|                      const uint32_t* table, uint16_t groups)
|
| Two groups are eight packed Macintosh bytes (16 pixels) and produce one word
| in each of the four Amiga planes.  The four 1 KiB table quarters encode the
| pixel-pair positions.  This keeps Vette's native packed-nibble source while
| adopting the word-write strategy of Mikael Kalms' public-domain
| c2p1x1_4_c5_word, which is explicitly intended for OCS/ECS chip RAM.
vetteC2PSpanAsm:
	movem.l	d2-d4/a2-a5,-(sp)
	move.l	32(sp),a0
	move.l	36(sp),a1
	move.l	40(sp),a2
	| GCC reserves a four-byte argument slot for uint16_t; on big-endian 68k
	| the value occupies its low word.  The caller always supplies a multiple
	| of two groups because dirty spans are aligned to 16 pixels.
	move.w	46(sp),d3
	beq	3f
	lsr.w	#1,d3
	beq	3f
	subq.w	#1,d3
	lea	1024(a2),a3
	lea	2048(a2),a4
	lea	3072(a2),a5
1:
	| First eight pixels -> four plane bytes in d1.
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

	| Second eight pixels -> four plane bytes in d2.
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	move.l	0(a2,d0.w),d2
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	or.l	0(a3,d0.w),d2
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	or.l	0(a4,d0.w),d2
	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.w	#2,d0
	or.l	0(a5,d0.w),d2

	| Byte-interleave [p0a,p1a,p2a,p3a] and [p0b,p1b,p2b,p3b]
	| into [p0a,p0b,p2a,p2b] and [p1a,p1b,p3a,p3b].
	move.l	d2,d4
	lsr.l	#8,d4
	eor.l	d1,d4
	and.l	#0x00ff00ff,d4
	eor.l	d4,d1
	lsl.l	#8,d4
	eor.l	d4,d2

	move.w	d1,128(a1)
	move.w	d2,192(a1)
	swap	d1
	swap	d2
	move.w	d2,64(a1)
	move.w	d1,(a1)+
	dbf	d3,1b
3:
	movem.l	(sp)+,d2-d4/a2-a5
	rts
