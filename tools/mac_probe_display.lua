-- ⭐ Measure the Color build's DISPLAY SURFACE from the running original.
--
-- open-work #16/#18 ask what the port has to draw: how many pixels, how many
-- bitplanes' worth of depth, what packing, and which 16 colours.  Those answers
-- exist in the Mac's own data structures while the game is running, so read them
-- there rather than inferring from `pltt` counts or PICT headers (a naive PICT
-- opcode scan already produced garbage -- 49151 bpp -- and must not be re-trusted).
--
-- What is read, and why it is the authority:
--   MainDevice ($8A4)  -> GDevice -> gdPMap -> PixMap   the SCREEN: bounds, depth,
--                         rowBytes, pixelType, and the live 16-entry colour table.
--   CurrentA5 ($904)   -> (A5) -> QDGlobals -> thePort   the port the game is
--                         DRAWING INTO at the moment of the probe.  A CGrafPort
--                         carries its own PixMap, so this is the game's own
--                         surface depth, not the screen's.
--   WindowList ($9D6)  -> the front window's portRect: how much of the screen the
--                         game actually owns.
--
-- ⚠ GrafPort vs CGrafPort is decided by portVersion: a CGrafPort has the top two
-- bits of the word at +6 set (0xC000).  An old GrafPort has a BitMap at +2 and NO
-- pixelSize at all -- reading +32 of it would return a plausible-looking number
-- from unrelated fields, which is exactly the silent-wrong-value failure this
-- project treats as the expensive one.  So the type is checked, not assumed.

local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")

local prog = manager.machine.devices[":maincpu"].spaces["program"]
local function u8(a)  return prog:read_u8(a)  end
local function u16(a) return prog:read_u16(a) end
local function u32(a) return prog:read_u32(a) end
local function i16(a) return prog:read_i16(a) end

local MainDevice, CurrentA5, WindowList = 0x8A4, 0x904, 0x9D6

local function rect(a)
	return i16(a), i16(a + 2), i16(a + 4), i16(a + 6)   -- top, left, bottom, right
end

local function pixmap(pm, label)
	local base    = u32(pm + 0)
	local rowB    = u16(pm + 4)
	local t, l, b, r = rect(pm + 6)
	local ver     = u16(pm + 14)
	local pkType  = u16(pm + 16)
	local hRes    = u32(pm + 22) / 65536
	local vRes    = u32(pm + 26) / 65536
	local pxType  = u16(pm + 30)
	local pxSize  = u16(pm + 32)
	local cmpCnt  = u16(pm + 34)
	local cmpSize = u16(pm + 36)
	local table_  = u32(pm + 42)
	print(string.format("VP %s PixMap @%08X", label, pm))
	print(string.format("VP   bounds   = (%d,%d)-(%d,%d)  -> %d x %d px", l, t, r, b, r - l, b - t))
	print(string.format("VP   pixelSize= %d bpp   pixelType=%d (%s)   cmpCount=%d cmpSize=%d",
		pxSize, pxType, pxType == 0 and "chunky/indexed" or "direct RGB", cmpCnt, cmpSize))
	print(string.format("VP   rowBytes = %d (flags %04X, %d bytes of pixels)",
		rowB & 0x3FFF, rowB & 0xC000, (rowB & 0x3FFF) * (b - t)))
	print(string.format("VP   baseAddr = %08X  version=%d packType=%d  res=%gx%g dpi",
		base, ver, pkType, hRes, vRes))
	-- ⭐ The live colour table IS the palette the Amiga has to reproduce.
	if table_ ~= 0 and pxSize <= 8 then
		local ct = u32(table_)                    -- it is a handle
		if ct ~= 0 then
			local size = i16(ct + 6)              -- ctSize: LAST index, not a count
			print(string.format("VP   CLUT     = %d entries (seed %08X)", size + 1, u32(ct)))
			for i = 0, math.min(size, 255) do
				local e = ct + 8 + i * 8
				local red, green, blue = u16(e + 2), u16(e + 4), u16(e + 6)
				print(string.format("VP     %3d  value=%3d  %04X %04X %04X   -> Amiga $%X%X%X",
					i, u16(e), red, green, blue,
					red >> 12, green >> 12, blue >> 12))
			end
		end
	end
end

local function probe(when)
	print("VP ================ display probe: " .. when)
	local gd = u32(u32(MainDevice))
	print(string.format("VP MainDevice GDevice @%08X  gdType=%d gdFlags=%04X",
		gd, i16(gd + 4), u16(gd + 20)))
	pixmap(u32(u32(gd + 22)), "SCREEN")

	local a5 = u32(CurrentA5)
	local qd = u32(a5)
	local port = u32(qd)
	print(string.format("VP CurrentA5=%08X  QDGlobals=%08X  thePort=%08X", a5, qd, port))
	if port ~= 0 then
		local ver = u16(port + 6)
		local t, l, b, r = rect(port + 16)
		print(string.format("VP thePort portRect=(%d,%d)-(%d,%d) -> %d x %d   portVersion=%04X (%s)",
			l, t, r, b, r - l, b - t, ver,
			(ver & 0xC000) == 0xC000 and "CGrafPort" or "old GrafPort"))
		if (ver & 0xC000) == 0xC000 then
			pixmap(u32(u32(port + 2)), "thePort")
		else
			-- old GrafPort: a 1-bit BitMap at +2, and there is no pixelSize field.
			local t2, l2, b2, r2 = rect(port + 2 + 6)
			print(string.format("VP thePort BitMap rowBytes=%d bounds=(%d,%d)-(%d,%d) -> 1 bpp",
				u16(port + 2 + 4), l2, t2, r2, b2))
		end
	end

	local w = u32(WindowList)
	while w ~= 0 do
		local t, l, b, r = rect(w + 16)
		print(string.format("VP window @%08X portRect=(%d,%d)-(%d,%d) -> %d x %d  visible=%d",
			w, l, t, r, b, r - l, b - t, u8(w + 0x6C)))
		w = u32(w + 0x90)                          -- nextWindow
	end
end

mac.run(function()
	mac.launch()
	mac.wait(1500)                                 -- past the intro, on the garage screen
	mac.shot()
	probe("garage screen")
end)
