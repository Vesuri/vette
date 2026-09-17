| Asset embedding for the Vette! Amiga build (the equivalent of Bin2Hunk).
|
| Paths are resolved relative to the amiga/ build directory (ASFLAGS -I"$(CURDIR)").
|
| ⚠ .incbin dependencies are INVISIBLE to `gcc -MMD`, so every file listed here must also
| be listed in the Makefile's INCBIN_DEPS.  Without that, regenerating an embedded blob
| leaves a STALE copy in the binary while the on-disk file looks correct.  On the Atari
| port this exact trap shifted an embedded data block by one byte and cost a long
| debugging session.
|
| ⚠⚠ THESE FILES ARE DERIVED FROM THE COPYRIGHTED GAME AND ARE NOT COMMITTED
| (.gitignore).  Regenerate them from a local MAME capture with:
|   python3 tools/mac_fb_to_amiga.py ref/mame/snap/intro/fb_screen.raw \
|       ref/mame/snap/intro/fb_screen.clut 320 480 amiga/assets/intro \
|       --crop 64,92,512,320 --reference ref/mame/snap/intro/mac2fdhd/0000.png
| docs/toolchain.md has the capture recipe that produces the .raw/.clut.

	.section .rodata
	.align 4

| intro.planes — Target 1's Macintosh frame (frame 1770, the intro art complete and
| before the first overlay DrawPicture at 1782), 512x320 as 4 INTERLEAVED bitplanes.
| 256 bytes per row: all four planes of row y, then all four of row y+1.
	.global vette_intro_planes
	.global vette_intro_planes_end
vette_intro_planes:
	.incbin "assets/intro.planes"
vette_intro_planes_end:

| intro.palbin — the same frame's 16 Amiga COLORxx words, big-endian.  ⭐ Derived from
| the DISPLAYED Macintosh colours (pmTable through the measured gamma of 1.435), not from
| pmTable directly; docs/mac-hardware.md says why, and the acceptance floor that follows
| from the 4-bit quantisation is 8/255 worst channel, 1.52/255 mean.
	.global vette_intro_palette
vette_intro_palette:
	.incbin "assets/intro.palbin"
