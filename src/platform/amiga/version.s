| AmigaOS version string for Vette!.
|
| AmigaDOS Version and archive-inspection tools find this by scanning the load
| image for the "$VER: " marker; no code references it.  SHF_GNU_RETAIN keeps
| the otherwise unreferenced section alive through --gc-sections.
|
| Keep the date hardcoded so identical source trees produce identical builds.
	.section .rodata.version,"aR"
	.balign 2
	.asciz "$VER: Vette! 0.90 (23.09.2026)"
	.balign 2
