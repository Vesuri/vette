-- ⭐⭐ WHERE the pixels are and HOW they are packed -- proved, not read off a field.
--
-- ⚠⚠ THE TRAP THIS SCRIPT EXISTS TO DOCUMENT: the Mac II boots in 24-BIT MODE, so
-- a Memory Manager master pointer carries FLAG BITS IN ITS HIGH BYTE (bit 7 =
-- locked, 6 = purgeable, 5 = resource).  Dereferencing a handle without masking
-- to 24 bits does not fail -- it reads a wild address and formats whatever is
-- there.  The first version of this probe printed "12730 x -17543 px, 18923 bpp"
-- with total confidence.  MASK EVERY POINTER THAT CAME OUT OF A HANDLE.
--
-- Proof strategy: dump the live framebuffer and the live CLUT to files, snapshot
-- the same frame, and let tools/fb_to_png.py re-render the dump and diff it
-- against MAME's screenshot.  A pixel-exact match proves the base address, the
-- rowBytes, the 2-pixels-per-byte packing, the nibble order AND the palette all
-- at once; any guess that is wrong shows up as a mangled image.

local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")

local prog = manager.machine.devices[":maincpu"].spaces["program"]
local function u8(a) return prog:read_u8(a) end
local function u16(a) return prog:read_u16(a) end
local function u32(a) return prog:read_u32(a) end
local function i16(a) return prog:read_i16(a) end
local M = 0xFFFFFF                                  -- 24-bit mode: mask master pointers
local function deref(h) return u32(h) & M end

local OUT = os.getenv("VETTE_FB_OUT") or "ref/mame/snap/fb"

local function dump_clut(pm, path)
	local cth = u32(pm + 42) & M
	if cth == 0 then print("VP no CLUT"); return end
	local ct = deref(cth)
	local size = i16(ct + 6)                        -- ctSize is the LAST index
	local f = assert(io.open(path, "wb"))
	print(string.format("VP CLUT %d entries (seed %08X) -> %s", size + 1, u32(ct), path))
	for i = 0, size do
		local e = ct + 8 + i * 8
		local r, g, b = u16(e + 2), u16(e + 4), u16(e + 6)
		f:write(string.format("%d %d %d %d %d\n", i, u16(e), r, g, b))
		print(string.format("VP   %2d value=%5d  %04X %04X %04X   8-bit %3d,%3d,%3d   Amiga $%X%X%X",
			i, u16(e), r, g, b, r >> 8, g >> 8, b >> 8, r >> 12, g >> 12, b >> 12))
	end
	f:close()
end

local function dump_pixels(base, rowB, rows, path)
	local f = assert(io.open(path, "wb"))
	for y = 0, rows - 1 do
		local row, a = {}, base + y * rowB
		for x = 0, rowB - 1 do row[#row + 1] = string.char(u8(a + x)) end
		f:write(table.concat(row))
	end
	f:close()
	print(string.format("VP pixels %08X %d rows x %d bytes -> %s", base, rows, rowB, path))
end

mac.run(function()
	mac.launch()
	-- ⚠ Wait past the INTRO ANIMATION, not just "a while": a dump taken during the
	-- wipe differs from the snapshot beside it by 40% of the screen, and that reads
	-- as a broken pixel-format guess rather than as two different moments in time.
	-- The garage screen is static, so snapshotting either side of the dump proves
	-- nothing moved while it was being read.
	mac.wait(2700)
	mac.shot()                                       -- the frame we will diff against

	local gd = deref(u32(0x8A4))                     -- MainDevice
	local pm = deref(u32(gd + 22) & M)               -- gdPMap
	local rowB = u16(pm + 4) & 0x3FFF
	local t, l, b, r = i16(pm + 6), i16(pm + 8), i16(pm + 10), i16(pm + 12)
	local base, px = u32(pm), u16(pm + 32)
	print(string.format("VP SCREEN GDevice@%06X gdType=%d PixMap@%06X", gd, i16(gd + 4), pm))
	print(string.format("VP SCREEN %dx%d  pixelSize=%d bpp  pixelType=%d  rowBytes=%d  baseAddr=%08X",
		r - l, b - t, px, u16(pm + 30), rowB, base))
	print(string.format("VP SCREEN ScrnBase($824)=%08X  (%d bytes/row for %d px = %d px/byte)",
		u32(0x824), rowB, r - l, (r - l) // rowB))
	dump_clut(pm, OUT .. "_screen.clut")
	dump_pixels(base, rowB, b - t, OUT .. "_screen.raw")
	print(string.format("VP GEOM %d %d %d %d", r - l, b - t, rowB, px))

	-- The game's own drawing surface, for comparison with the screen.
	local port = u32(u32(u32(0x904)))                -- CurrentA5 -> QD globals -> thePort
	if (u16(port + 6) & 0xC000) == 0xC000 then
		local gpm = deref(u32(port + 2) & M)
		local growB = u16(gpm + 4) & 0x3FFF
		local gt, gl, gb, gr = i16(gpm + 6), i16(gpm + 8), i16(gpm + 10), i16(gpm + 12)
		print(string.format("VP GAME PORT %dx%d pixelSize=%d rowBytes=%d baseAddr=%08X (offscreen=%s)",
			gr - gl, gb - gt, u16(gpm + 32), growB, u32(gpm),
			tostring((u32(gpm) & M) ~= (base & M))))
		dump_clut(gpm, OUT .. "_port.clut")
		dump_pixels(u32(gpm) & M, growB, gb - gt, OUT .. "_port.raw")
		print(string.format("VP PORTGEOM %d %d %d %d", gr - gl, gb - gt, growB, u16(gpm + 32)))
	end
	mac.shot()                                       -- second bracket: still the same frame?
end)
