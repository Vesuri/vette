	.text
	.even
	.globl vetteC2PSpanAsm

	.macro load8 result
	moveq	#0,d0
	move.w	(a0)+,d0
	move.l	0(a2,d0.l*4),\result
	moveq	#0,d0
	move.w	(a0)+,d0
	move.l	0(a2,d0.l*4),d4
	lsr.l	#4,d4
	or.l	d4,\result
	.endm

	.macro interleave2 first, second
	move.l	\second,d4
	lsr.l	#8,d4
	eor.l	\first,d4
	and.l	#0x00ff00ff,d4
	eor.l	d4,\first
	lsl.l	#8,d4
	eor.l	d4,\second
	.endm

| void vetteC2PSpanAsm(const uint8_t* source, uint8_t* destination,
|                      const uint32_t* table, uint16_t groups)
|
| Four groups are 16 packed Macintosh bytes (32 pixels) and produce one long
| in each of the four Amiga planes.  A final two-group/16-pixel tail uses word
| writes, so callers retain their natural 16-pixel dirty-rectangle alignment.
| The 256 KiB fast-RAM table maps four packed pixels to the high nibble of four
| plane bytes. Two lookups and one shift/OR therefore transpose eight pixels,
| halving the former 8-bit table's lookup traffic. This keeps Vette's native
| packed-nibble source while extending the wide-write strategy of Mikael
| Kalms' public-domain c2p1x1_4_c5_word. The supported A1200 target uses its
| 68020 scaled long index here instead of shifting and adding each table
| address by hand; this is the only 68020-only port assembly.
vetteC2PSpanAsm:
	movem.l	d2-d7/a2,-(sp)
	move.l	32(sp),a0
	move.l	36(sp),a1
	move.l	40(sp),a2
	| GCC reserves a four-byte argument slot for uint16_t; on big-endian 68k
	| the value occupies its low word. Dirty spans make it an even number.
	move.w	46(sp),d3
	beq	9f
	move.w	d3,d7
	and.w	#2,d3			| one 16-pixel tail after 32-pixel batches?
	lsr.w	#2,d7			| number of 32-pixel batches
	tst.w	d7
	beq	5f
	subq.w	#1,d7
1:
	load8	d1
	load8	d2
	interleave2 d1,d2		| [p0a,p0b,p2a,p2b], [p1a,p1b,p3a,p3b]
	load8	d5
	load8	d6
	interleave2 d5,d6		| same for pixels 16..31

	| Join corresponding 16-bit halves into four 32-pixel plane longs.
	move.l	d1,d4
	swap	d4
	move.w	d5,d4			| plane 2
	swap	d5
	move.w	d5,d1			| plane 0
	move.l	d2,d5
	swap	d5
	move.w	d6,d5			| plane 3
	swap	d6
	move.w	d6,d2			| plane 1

	move.l	d4,128(a1)
	move.l	d5,192(a1)
	move.l	d2,64(a1)
	move.l	d1,(a1)+
	dbf	d7,1b

5:
	tst.w	d3
	beq	9f
	load8	d1
	load8	d2
	interleave2 d1,d2
	move.w	d1,128(a1)
	move.w	d2,192(a1)
	swap	d1
	swap	d2
	move.w	d2,64(a1)
	move.w	d1,(a1)
9:
	movem.l	(sp)+,d2-d7/a2
	rts
