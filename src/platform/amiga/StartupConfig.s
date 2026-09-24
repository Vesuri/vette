| Loader-patchable boolean: magic "VET!HIRE", word value, reserved word.
	.section .data.hires,"awR"
	.balign 4
	.long 0x56455421
	.long 0x48495245
	.globl vette_hires_value
	.type vette_hires_value,@object
vette_hires_value:
	.word VETTE_HIRES
	.size vette_hires_value,2
	.word 0
