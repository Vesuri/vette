-- ⭐⭐ THE TRAP LOG: every A-line trap the game executes, in order, with counts.
--
-- WHY: this port keeps the original 68000 instructions (option A), so the set of
-- traps the game executes IS the port's work list, and the order it first needs
-- them in is the order to implement them.  That is a measurement, not an estimate.
--
-- HOW, and the three things that had to be measured to get here:
--
--  1. ⛔ A read tap on the Line-A exception VECTOR ($28) never fires -- MAME's
--     m68k core does not route vector fetches through the tapped accessor.  Nor
--     do RAM reads, nor Lua's own reads (a tap on Ticks $168 counted 0 in 25 s).
--     ⭐ But a tap on the ROM dispatcher's OPCODES does fire, once per dispatch.
--     So we tap where the vector POINTS, not the vector.
--  2. ⚠⚠ The dispatcher MOVES.  $28 was re-pointed three times during boot
--     ($40802950 -> $4080210A -> $408064BA) as the ROM, the System and MacsBug
--     each patched it.  A tap armed once at boot stops seeing anything later,
--     which looks exactly like "the game takes no traps".  So the vector is
--     polled every frame and the tap re-armed whenever it changes.
--  3. ⚠ install_read_tap needs a 4-byte-ALIGNED start (it rejects $16A by name),
--     so the range is aligned down and the dispatcher's own address is not.
--  4. ⚠⚠ THE TAP MUST BE KEPT IN A LUA VARIABLE OR IT DIES.  install_read_tap's
--     return value owns the tap; drop it and the collector removes the tap at
--     the next GC.  [MEASURED]: discarding it counted 2 306 hits over 12 frames
--     and then exactly 0 for the next 1 900 -- i.e. it looks like "the game
--     takes no traps", the same false negative as 2. above, from a different
--     cause.  Keeping the handle in `keep` counted 58 419 and still rising.
--
-- The stacked frame is a 68000 group-2 exception: SR:w then PC:l, and
-- ⭐ [MEASURED] the stacked PC points AT the A-trap word, not past it -- verified
-- because the word there is $Axxx on every hit and decodes to sane traps.
--
-- ⚠ Early in boot the ROM is OVERLAID at $00000000, so a low stacked PC is ROM
-- too; those rows are tagged phase=boot and are not the game.  The game's own
-- calls are the RAM ones from phase=launched onwards.
--
-- ⚠ PC-in-ROM vs PC-in-RAM is the split that matters: a trap taken from ROM is
-- the Toolbox calling itself internally and the port never sees it.  Only the
-- RAM ones are the game's own calls, and those are the work list.

local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")
local prog = manager.machine.devices[":maincpu"].spaces["program"]
local cpu  = manager.machine.devices[":maincpu"]

local ROM_LO, ROM_HI = 0x40000000, 0x4FFFFFFF
local count, order, seen = {}, {}, {}
local n_rom, n_ram, n_hits = 0, 0, 0
local phase = "boot"
local cur, taps = 0, 0
local keep = {}   -- ⚠⚠ see note 4: this is not bookkeeping, it is the tap's owner

local function on_trap()
	n_hits = n_hits + 1
	local sp = cpu.state["SP"].value
	local pc = prog:read_u32(sp + 2)
	local w  = prog:read_u16(pc)
	if (w & 0xF000) ~= 0xA000 then return end
	local rom = pc >= ROM_LO and pc <= ROM_HI
	if rom then n_rom = n_rom + 1 else n_ram = n_ram + 1 end
	local key = string.format("%04X", w)
	local c = count[key]
	if not c then
		c = { rom = 0, ram = 0, first_pc = pc, first_frame = mac.frames(), first_phase = phase }
		count[key] = c
		order[#order + 1] = key
	end
	if rom then c.rom = c.rom + 1 else c.ram = c.ram + 1 end
	-- ⭐ First time this trap is called FROM THE GAME (not from ROM) is the
	-- number that orders the work list, so it is recorded separately.
	if not rom and not c.ram_first then
		c.ram_first = { frame = mac.frames(), pc = pc, phase = phase }
		seen[#seen + 1] = key
	end
end

local function arm(h)
	cur, taps = h, taps + 1
	keep[#keep + 1] = prog:install_read_tap(h & ~3, (h & ~3) + 3, "disp" .. taps,
		function(o, d, m) on_trap(); return d end)
	print(string.format("VP ARM dispatcher #%d at %08X (frame %d)", taps, h, mac.frames()))
end

-- forward-declared: the segment map needs the tap installed first
local map_hook

emu.register_frame_done(function()
	local h = prog:read_u32(0x28)
	if h ~= cur and h > 0x1000 then arm(h) end
	if map_hook and mac.frames() % 60 == 0 then map_hook() end
end)

-- ---------------------------------------------------- names + segments -----

-- ⚠⚠ NO HAND-WRITTEN TRAP NAMES.  A first pass had them and got several wrong
-- in a way that reads as fact: $A8B5 was labelled a QuickDraw call and is
-- ScriptUtil, $A893 is MoveTo, $A885 is DrawText.  A wrong name here becomes a
-- wrong entry in the port's work list, so the table is GENERATED from cxmon's
-- full 1 178-trap list by tools/gen_trap_names.py into tmp/ (local only).
local NAMES, BYNUM = {}, {}
do
	local f = loadfile("tmp/trap_names.lua")
	if f then NAMES = f() else
		print("VP ⚠⚠ tmp/trap_names.lua MISSING -- run tools/gen_trap_names.py. Names will be raw hex.")
	end
	-- ⚠ The table is keyed the way Apple's own Traps.h is keyed: by the word a
	-- compiler EMITS, flag bits included -- _NewPtr is listed as $A11E, not
	-- $A01E.  So a straight lookup of the flag-stripped base misses NewPtr,
	-- NewHandle, GetTrapAddress and PurgeSpace, which is exactly the set that
	-- came out as "?OS_1E / ?OS_22 / ?OS_46 / ?OS_62" on the first run.  Index
	-- every entry by its trap NUMBER as well, so any flag combination resolves.
	for k, v in pairs(NAMES) do
		local num = ((k & 0x0800) ~= 0) and (0x0800 | (k & 0x03FF)) or (k & 0x00FF)
		if not BYNUM[num] then BYNUM[num] = v end
	end
end

local function name(w)
	if (w & 0x0800) ~= 0 then      -- Toolbox: 10-bit number, $0400 = auto-pop
		local num = 0x0800 | (w & 0x03FF)
		return (NAMES[w] or BYNUM[num] or string.format("?TB_%03X", w & 0x03FF)),
		       ((w & 0x0400) ~= 0 and "autopop" or "")
	end
	local num = w & 0x00FF               -- OS: 8-bit number, $0400/$0200/$0100 = flags
	local fl = {}
	if (w & 0x0400) ~= 0 then fl[#fl+1] = "trashA0" end
	if (w & 0x0200) ~= 0 then fl[#fl+1] = "sys"     end
	if (w & 0x0100) ~= 0 then fl[#fl+1] = "clear"   end
	return (NAMES[w] or BYNUM[num] or string.format("?OS_%02X", num)), table.concat(fl, "+")
end

-- ⭐⭐ Resolving a caller PC to (segment, offset) -- the whole point of the log.
--
-- ⚠ [MEASURED] the LOADED jump-table entry is `[segnum:w][4EF9][addr:l]`, NOT
-- `[offset:w][4EF9][addr:l]`.  A first pass assumed the routine offset survived
-- in word 0 and derived `base = addr - word0`, which produced 240 distinct
-- "segment bases" one entry apiece -- i.e. the addresses themselves, each shifted
-- by a small segment number.  The segment number is what survives (UnloadSeg
-- needs it); the routine offset is what the JMP overwrote.
--
-- So the segment NUMBER is free, and the BASE is then pinned by measurement
-- rather than assumed: the resident image of a segment is byte-identical to the
-- extracted CODE resource, so the base is the one address in
-- (lowest exported address - segment length, lowest exported address] where the
-- resource's first 8 bytes appear.  ⭐ That doubles as the check Stage B needs
-- anyway -- that a near-model segment really is loaded verbatim with nothing
-- relocated.
local SEGS = {   -- segnum -> {name, extracted resource}.  Color VETTE! only.
	[1]={"Main","CODE_01_Main.bin"},[2]={"Initialize","CODE_02_Initialize.bin"},
	[3]={"Communication","CODE_03_Communication.bin"},[4]={"load","CODE_04_load.bin"},
	[5]={"Score","CODE_05_Score.bin"},[6]={"Traffic","CODE_06_Traffic.bin"},
	[7]={"FRED","CODE_07_FRED.bin"},[8]={"Intro","CODE_08_Intro.bin"},
	[9]={"sound","CODE_09_sound.bin"},[10]={"%A5Init","CODE_10__A5Init.bin"},
}
local SEGDIR = "tmp/seg_color/"
-- ⚠⚠ Segments come and go.  [MEASURED] only 6 of the 10 were resident 2 s after
-- launch and Score appeared later; %A5Init runs at startup and is then purged.
-- A snapshot therefore misfiles every trap called from a segment that was not
-- resident when the snapshot was taken -- as "the System", silently, which is
-- the wrong direction to be wrong in.  So the map is ACCUMULATED over the whole
-- run, keyed by base, and a base that is later claimed by a different segment
-- is reported instead of overwritten.
local bases = {}      -- list of {base=, len=, seg=, name=}
local byaddr = {}     -- base -> entry, the accumulator

local function seg_head(file)
	local f = io.open(SEGDIR .. file, "rb")
	if not f then return nil end
	local d = f:read("a"); f:close()
	local function be32(i)
		local a,b,c,e = d:byte(i, i+3); return ((a<<24)|(b<<16)|(c<<8)|e) & 0xFFFFFFFF
	end
	return be32(1), be32(5), #d
end

local function map_segments()
	local a5 = prog:read_u32(0x904) & 0x00FFFFFF
	if a5 == 0 then print("VP ⚠ CurrentA5 is 0 -- no app"); return end
	local jt, lo = a5 + 32, {}
	local resident = 0
	for i = 0, 508 do
		local e = jt + i * 8
		if prog:read_u16(e + 2) == 0x4EF9 then
			resident = resident + 1
			local seg  = prog:read_u16(e)
			local addr = prog:read_u32(e + 4) & 0x00FFFFFF
			if addr > 0x1000 and (not lo[seg] or addr < lo[seg]) then lo[seg] = addr end
		end
	end
	local segl = {}
	for seg, addr in pairs(lo) do segl[#segl+1] = seg end
	table.sort(segl)
	local fresh = {}
	for _, seg in ipairs(segl) do
		local info = SEGS[seg]
		local h0, h1, len = nil, nil, nil
		if info then h0, h1, len = seg_head(info[2]) end
		local base, matches = nil, 0
		if h0 then
			for c = lo[seg], lo[seg] - len, -2 do
				if c > 0x1000 and prog:read_u32(c) == h0 and prog:read_u32(c + 4) == h1 then
					matches = matches + 1; if not base then base = c end
				end
			end
		end
		if base then
			local old = byaddr[base]
			if old and old.seg ~= seg then
				print(string.format("VP ⚠⚠ base %06X claimed by seg %d (%s) AND seg %d (%s)"
					.. " -- PCs in it are AMBIGUOUS", base, old.seg, old.name, seg, info[1]))
			elseif not old then
				byaddr[base] = {base = base, len = len, seg = seg, name = info[1]}
				fresh[#fresh+1] = string.format("seg %d %s @%06X", seg, info[1], base)
			end
			if matches > 1 then
				print(string.format("VP ⚠ seg %d %s: %d candidate bases matched the resource's"
					.. " first 8 bytes -- attribution is not unique", seg, info[1], matches))
			end
		elseif h0 then
			print(string.format("VP ⚠⚠ seg %2d %-14s BASE NOT FOUND (lowest export %06X)"
				.. " -- resident image differs from the extracted resource?",
				seg, info and info[1] or "?", lo[seg]))
		else
			print(string.format("VP ⚠⚠ seg %2d: no extracted resource, run hfs_extract", seg))
		end
	end
	bases = {}
	for _, e in pairs(byaddr) do bases[#bases+1] = e end
	table.sort(bases, function(x, y) return x.base < y.base end)
	if #fresh > 0 then
		print(string.format("VP MAP frame %-6d JT %d/509 resident, now mapped: %s",
			mac.frames(), resident, table.concat(fresh, ", ")))
	end
end

-- ⚠ A PC outside every mapped segment is printed as a bare address, never
-- attributed to the nearest segment: $007Cxxxx PCs are System-heap patch code
-- calling on the game's behalf, and labelling those as game code would put
-- traps on the work list that the port never has to service.
local function where(pc)
	for _, e in ipairs(bases) do
		if pc >= e.base and pc < e.base + e.len then
			return string.format("%s+%04X", e.name, pc - e.base)
		end
	end
	return string.format("(%06X)", pc)
end

local function report()
	local out = io.open("ref/mame/traps.txt", "w")
	local function p(s) print(s); if out then out:write(s .. "\n") end end
	-- ⚠⚠ "in RAM" is NOT "the game".  [MEASURED] the callers split into three
	-- regions, and only one of them is the game:
	--   * the mapped CODE segments                        -> THE GAME
	--   * $7Cxxxx, just under the top of the 8 MB          -> the System's ROM
	--     patch block (Memory/Resource/Palette Manager patches)
	--   * $00xxxx-$01xxxx, the low system heap             -> System file code
	--     (Window/Dialog/Script Managers, drivers)
	--   * $408xxxxx                                        -> ROM
	-- The last three are the Toolbox calling itself on the game's behalf.  A
	-- first pass called every non-ROM caller "the game" and put SetHandleSize
	-- (9 088 calls from the Memory Manager patch), EraseRect (8 961 from the
	-- system heap) and SCSIDispatch on the port's work list.  They are not on it.
	local g_first, g = {}, {}
	for _, k in ipairs(seen) do
		local c = count[k]
		local w = where(c.ram_first.pc)
		if not w:match("^%(") then g_first[#g_first+1] = k; g[k] = w end
	end
	p(string.format("VP ==== %d dispatches, %d decoded: %d from ROM, %d from RAM",
		n_hits, n_rom + n_ram, n_rom, n_ram))
	p(string.format("VP ==== %d distinct traps called BY THE GAME's own segments -- THIS is the work list",
		#g_first))
	p("")
	p("VP ---- THE GAME, in FIRST-USE ORDER = the order the port must implement ----")
	p(string.format("VP %-4s %-18s %-9s %8s %8s %7s %-14s %s",
		"word", "name", "flags", "from-RAM", "from-ROM", "frame", "base+off", "phase"))
	for _, k in ipairs(g_first) do
		local c = count[k]
		local nm, enc = name(tonumber(k, 16))
		p(string.format("VP %-4s %-18s %-9s %8d %8d %7d %-14s %s",
			k, nm, enc, c.ram, c.rom, c.ram_first.frame, g[k], c.ram_first.phase))
	end
	p("")
	p("")
	p("VP ---- called ONLY by the System (ROM, the $7Cxxxx patch block, the system")
	p("VP      heap): the port implements these traps itself or not at all ----")
	local rest = {}
	for k, c in pairs(count) do if not g[k] then rest[#rest + 1] = k end end
	table.sort(rest, function(a, b) return count[a].rom > count[b].rom end)
	local line = {}
	for _, k in ipairs(rest) do line[#line + 1] = string.format("%s(%s)=%d", k, (name(tonumber(k, 16))), count[k].rom + count[k].ram) end
	p("VP " .. table.concat(line, " "))
	if out then out:close(); print("VP wrote ref/mame/traps.txt") end
end

mac.run(function()
	phase = "boot"
	mac.launch()
	-- ⭐ Everything before this point is System + Finder, ~100 k dispatches of
	-- noise.  The work list is what the GAME calls, so the accumulators are
	-- cleared here and the boot totals reported separately.
	print(string.format("VP boot cost %d dispatches, %d distinct -- DISCARDED", n_hits, #order))
	count, order, seen = {}, {}, {}
	n_rom, n_ram, n_hits = 0, 0, 0
	phase = "launched"
	map_hook = map_segments   -- ⭐ from here the map refreshes every 60 frames
	for i = 1, 12 do
		mac.wait(240)
		phase = "t+" .. (i * 4) .. "s"
		print(string.format("VP %-8s frame=%-6d hits=%-8d ram=%-7d distinct=%d",
			phase, mac.frames(), n_hits, n_ram, #seen))
	end
	mac.shot()
	map_hook = nil
	map_segments()
	local n = 0
	for _ in pairs(byaddr) do n = n + 1 end
	print(string.format("VP %d segment placements mapped over the run:", n))
	for _, e in ipairs(bases) do
		print(string.format("VP    seg %2d %-14s base %06X len %6d", e.seg, e.name, e.base, e.len))
	end
	report()
end)
