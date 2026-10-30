| uint16_t vette_cd32_read(void): the CD32 pad's seven buttons from port 1.
|
| Rescue on Fractalus' rof_cd32_read (docs/controls.md there), itself Attack
| of the PETSCII Robots' readCD32Pad, the version known to work across real
| pads. The pad's stick reads through JOY1DAT like a joystick; its buttons
| use a shift register on three pins:
|
|   pin 6 (FIR1) CIA-A PRA bit 7, direction in DDRA   CLOCK, driven here
|   pin 5 (POTX) POTGO bits 13/12 (OUTRX/DATRX)        driven low: shift mode
|   pin 9 (POTY) POTGOR bit 14 (DATRY)                 serial data, active low
|
| Result, bit set = pressed: $0200 blue, $0100 red, $0080 yellow, $0040 green,
| $0020 forward, $0010 reverse, $0008 play; $0003 are the pad's marker bits.
|
| The tst.b (a0) CIA accesses are the protocol: each is synchronised to the
| E clock and gives the pad's shift register ~1.4 us to settle (six before the
| first bit, eight before each later one). Do not replace them with a counted
| delay. Call with interrupts disabled. DDRA bit 7 and POTGO are restored.

	.text
	.even
	.globl vette_cd32_read
vette_cd32_read:
	movem.l d2-d5,-(sp)
	lea 0xbfe001,a0			| CIA-A PRA (+$200 = DDRA)
	lea 0xdff000,a1
	move.w 0x16(a1),d2		| POTGOR, written back to POTGO at the end
	moveq #7,d3			| clock: port 1 fire
	moveq #14,d4			| data: DATRY
	bset d3,0x200(a0)		| clock pin to output
	bclr d3,(a0)			| clock low
	move.w d2,d1
	and.w #0xcfff,d1
	or.w #0x2000,d1			| OUTRX=1, DATRX=0: pin 5 low, shift mode
	move.w d1,0x34(a1)		| POTGO
	moveq #0,d0
	moveq #10-1,d5			| ten bits, bit 9 first
	bra.s 2f
1:	tst.b (a0)
	tst.b (a0)
2:	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	move.w 0x16(a1),d1		| POTGOR: DATRY holds this bit
	bset d3,(a0)			| clock pulse
	bclr d3,(a0)
	btst d4,d1
	bne.s 3f			| high: not pressed
	bset d5,d0
3:	dbra d5,1b
	bclr d3,0x200(a0)		| clock pin back to input (fire)
	move.w d2,0x34(a1)		| restore POTGO
	movem.l (sp)+,d2-d5
	rts
