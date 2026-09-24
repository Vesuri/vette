; Minimal host-assembled WHDLoad test: no ROM, DOS, game or game data.
        INCLUDE whdload.i
        INCLUDE whdmacros.i
_base   SLAVE_HEADER
        dc.w 17,0
        dc.l $10000,0
        dc.w _start-_base,0,0
        dc.b 0,$59
        dc.l 0
        dc.w _name-_base,_copy-_base,_info-_base
        dc.w 0
        dc.l 0
        dc.w 0,0
_name   dc.b "Vette slave smoke test",0
_copy   dc.b "2026",0
_info   dc.b "No game code is loaded",0
_file   dc.b "smoke-passed",0
_data   dc.b "PASS"
        EVEN
_start  move.l a0,a2
        lea (_file,pc),a0
        lea (_data,pc),a1
        moveq #4,d0
        jsr (resload_SaveFile,a2)
        pea TDREASON_OK
        jmp (resload_Abort,a2)
