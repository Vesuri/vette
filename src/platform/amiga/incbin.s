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
	.section .rodata
	.align 4

| Stage B: all eleven Color-build CODE resources.  CODE 0 is metadata/the jump
| table rather than executable code, but remains resident with the ten code segments.
	.macro VETTE_CODE number, file
	.align 4
	.global vette_code_\number
	.global vette_code_\number\()_end
vette_code_\number:
	.incbin "\file"
vette_code_\number\()_end:
	.endm

	VETTE_CODE 0,  ../tmp/seg_color/CODE_00.bin
	VETTE_CODE 1,  ../tmp/seg_color/CODE_01_Main.bin
	VETTE_CODE 2,  ../tmp/seg_color/CODE_02_Initialize.bin
	VETTE_CODE 3,  ../tmp/seg_color/CODE_03_Communication.bin
	VETTE_CODE 4,  ../tmp/seg_color/CODE_04_load.bin
	VETTE_CODE 5,  ../tmp/seg_color/CODE_05_Score.bin
	VETTE_CODE 6,  ../tmp/seg_color/CODE_06_Traffic.bin
	VETTE_CODE 7,  ../tmp/seg_color/CODE_07_FRED.bin
	VETTE_CODE 8,  ../tmp/seg_color/CODE_08_Intro.bin
	VETTE_CODE 9,  ../tmp/seg_color/CODE_09_sound.bin
	VETTE_CODE 10, ../tmp/seg_color/CODE_10__A5Init.bin

| Both resource forks in tools/rsrc_pack.py's pointer-free, big-endian archive.
	.align 4
	.global vette_resources
	.global vette_resources_end
vette_resources:
	.incbin "assets/vette.resources"
vette_resources_end:
