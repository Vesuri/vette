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
local launch_frame = nil
local segcount = {}   -- segment name -> {n, sites}, attributed LIVE at hit time
local regframes = {}  -- 64 KB region -> {first frame, last frame} of any trap from it
local game_order = {}  -- trap keys in order of first call BY THE GAME
local keep = {}   -- ⚠⚠ see note 4: this is not bookkeeping, it is the tap's owner
local protection_prompt = false
local full_intro = os.getenv("VETTE_FULL_INTRO") == "1"

-- ⭐⭐ ARGUMENT CAPTURE.
--
-- Three of these GATE Stage C and two SIZE Stage D:
--  * $A047 SetTrapAddress is register-based (D0 = trap number, A0 = handler).
--    ⚠⚠ The game patches a trap inside Target 1 and option A means it will
--    patch it on the Amiga too, so our dispatcher must route that one trap to
--    the game's own handler.  This says which.
--  * $AB1D QDExtensions is SELECTOR-dispatched -- ⚠⚠ and the selector is in
--    **D0**, not on the stack.  [MEASURED] from the call sites: `moveq #0,d0`
--    then $AB1D is NewGWorld (the push sequence is exactly its signature),
--    `moveq #1,d0` is LockPixels (one PixMapHandle, Boolean result).  Reading a
--    stack "selector" here returns the last PARAMETER and looks like a pointer.
--  * $A9A0 GetResource / $A9BC GetPicture / $A8F6 DrawPicture are Pascal calls,
--    parameters pushed left to right, so the LAST parameter is at USP.
--    GetResource(theType:4, theID:2) -> USP = theID.
--    GetPicture(picID:2)             -> USP = picID.
--    DrawPicture(pic:4, dstRect:4)   -> USP = *Rect, USP+4 = PicHandle.
-- ⚠⚠ [MEASURED] There is only ONE stack.  Classic Mac OS runs the application
-- itself in SUPERVISOR mode -- every trap arrives with SR=$2700 and USP=0 --
-- so the parameters are on the same stack as the exception frame, directly
-- BELOW it.
-- ⚠⚠ [MEASURED] The frame is EIGHT bytes, not six: a Mac II is a 68020 and the
-- 68020 pushes the "normal four word" frame -- SR:w, PC:l, and a FORMAT/VECTOR
-- OFFSET word, which for the Line-A vector reads $0028 (vector 10 x 4).  So the
-- parameter block starts at SP+8.  The giveaway when this is wrong is a
-- constant $0028 at the head of every parameter list.
-- ⚠ The Amiga's 68000 pushes only six bytes.  Nothing in the GAME reads the
-- frame (the ROM returns via RTE), so option A is unaffected -- but OUR Line-A
-- handler is the one place the difference is real.
-- ⛔ Do not read parameters from USP: it is always 0 here, and a read at 0
-- returns low-memory globals that decode as plausible garbage.
local ARGS, arglog = {}, {}
local claimed = function() return false end   -- set once the segment map exists
local function u32(a) return prog:read_u32(a & 0x00FFFFFF) end
local function u16(a) return prog:read_u16(a & 0x00FFFFFF) end
local function s16(v) return v >= 0x8000 and v - 0x10000 or v end
local function ostype(v)
	local o = ""
	for i = 3, 0, -1 do
		local c = (v >> (i * 8)) & 0xFF
		o = o .. ((c >= 32 and c < 127) and string.char(c) or ".")
	end
	return o
end
local function rect(a)
	return string.format("t=%d l=%d b=%d r=%d  %dx%d",
		s16(u16(a)), s16(u16(a+2)), s16(u16(a+4)), s16(u16(a+6)),
		s16(u16(a+6)) - s16(u16(a+2)), s16(u16(a+4)) - s16(u16(a)))
end

local function on_trap()
	n_hits = n_hits + 1
	local sp = cpu.state["SP"].value
	local pc = prog:read_u32(sp + 2)
	local w  = prog:read_u16(pc)
	if (w & 0xF000) ~= 0xA000 then return end
	if w == 0xA97C then protection_prompt = true end -- GetNewDialog
	local rom = pc >= ROM_LO and pc <= ROM_HI
	if rom then n_rom = n_rom + 1 else n_ram = n_ram + 1 end
	local key = string.format("%04X", w)
	local c = count[key]
	if not c then
		c = { rom = 0, ram = 0, first_pc = pc, first_frame = mac.frames(), first_phase = phase }
		count[key] = c
		order[#order + 1] = key
	end
	if rom then c.rom = c.rom + 1 else c.ram = c.ram + 1
		c.pcs = c.pcs or {}; c.pcs[pc] = (c.pcs[pc] or 0) + 1 end
	-- ⭐ First time this trap is called FROM THE GAME (not from ROM) is the
	-- number that orders the work list, so it is recorded separately.
	-- ⚠ Argument capture is bounded: the first 24 of each, or DrawPicture's
	-- 2 600 CopyBits-era calls would bury the log.

	if not rom then
		local r, f = pc >> 16, mac.frames()
		local rf = regframes[r]
		if rf then rf[2] = f else regframes[r] = {f, f} end
	end
	-- ⭐ Live attribution: done HERE, while the segment map is true.
	local mine = rom and nil or claimed(pc)
	if mine then
		local sc = segcount[mine.name]
		if not sc then sc = {n = 0, sites = {}, seg = mine.seg}; segcount[mine.name] = sc end
		sc.n = sc.n + 1
		local site = sc.sites[pc]
		if not site then
			site = {count = 0, word = w, offset = pc - mine.base}
			sc.sites[pc] = site
		elseif site.word ~= w or site.offset ~= pc - mine.base then
			-- A caller word changing while resident would invalidate a static map:
			-- make that visible instead of silently retaining either observation.
			site.changed = true
		end
		site.count = site.count + 1
		if not c.game_first then
			c.game_first = {frame = mac.frames(), phase = phase,
				at = string.format("%s+%04X", mine.name, pc - mine.base)}
			game_order[#game_order + 1] = key
		end
	end
	local fn = ARGS[w]
	if fn then
		local key = string.format("%04X", w) .. (mine and "" or " (unattributed)")
		arglog[key] = arglog[key] or {}
		if #arglog[key] < (mine and 24 or 4) then
			-- parameter block = just past the 8-byte 68020 exception frame
			local ok, str = pcall(fn, (sp + 8) & 0x00FFFFFF)
			arglog[key][#arglog[key]+1] = {frame = mac.frames(), pc = pc,
				text = ok and str or ("⚠ read failed: " .. tostring(str))}
		end
	end
	if not rom and not c.ram_first then
		c.ram_first = { frame = mac.frames(), pc = pc, phase = phase }
		seen[#seen + 1] = key
	end
end

local function click(h, v, wait)
	mac.mouse_to(h, v); mac.click(1); mac.wait(wait or 180)
end

local function report_windows(label)
	local w = u32(0x09D6) & 0x00FFFFFF -- WindowList: front window first
	print("VP ---- " .. label .. " WindowList ----")
	while w ~= 0 do
		local t, l, b, r = s16(u16(w + 16)), s16(u16(w + 18)),
			s16(u16(w + 20)), s16(u16(w + 22))
		print(string.format("VP window @%06X portRect=(%d,%d)-(%d,%d) -> %d x %d visible=%d",
			w, l, t, r, b, r - l, b - t, prog:read_u8(w + 0x6C)))
		w = u32(w + 0x90) & 0x00FFFFFF
	end
end

local function arm(h)
	cur, taps = h, taps + 1
	keep[#keep + 1] = prog:install_read_tap(h & ~3, (h & ~3) + 3, "disp" .. taps,
		function(o, d, m) on_trap(); return d end)
	print(string.format("VP ARM dispatcher #%d at %08X (frame %d)", taps, h, mac.frames()))
end

-- forward-declared: the segment map needs the tap installed first
local map_segments_safe = function() end

emu.register_frame_done(function()
	local h = prog:read_u32(0x28)
	if h ~= cur and h > 0x1000 then arm(h) end
	-- ⚠ %A5Init runs once at startup and is purged, so a 60-frame cadence can
	-- miss it entirely and then every trap it called is misfiled as "the
	-- System".  Poll every frame until it is seen or the window closes.
	-- ⚠ %A5Init runs once at startup and is purged.  Map every frame from well
	-- before launch; before the app exists CurrentA5 is the Finder's and no
	-- base can match one of OUR resources, so this is safe, not noisy.
	if mac.frames() > 800 then map_segments_safe() end
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
ARGS[0xA047] = function(pb)
	local d0 = cpu.state["D0"].value & 0xFFFF
	local w  = (d0 & 0x0800) ~= 0 and (0xA800 | (d0 & 0x3FF)) or (0xA000 | (d0 & 0xFF))
	return string.format("D0=%04X -> patches trap $%04X (%s), handler A0=%06X",
		d0, w, (NAMES[w] or BYNUM[((d0 & 0x0800) ~= 0) and (0x0800 | (d0 & 0x3FF)) or (d0 & 0xFF)]
		or "?"), cpu.state["A0"].value & 0x00FFFFFF)
end
-- ⚠ Only the two selectors PROVEN from the call-site push sequences are named;
-- the rest print as bare numbers on purpose.  Do not paste in the QDOffscreen
-- selector list from memory -- that is how a guess becomes a documented fact.
local QDSEL = { [0] = "NewGWorld", [1] = "LockPixels" }
ARGS[0xAB1D] = function(pb)
	local sel = cpu.state["D0"].value & 0xFFFF
	return string.format("D0 selector=%d (%s)  stack %08X %08X %08X",
		sel, QDSEL[sel] or "[UNIDENTIFIED]", u32(pb), u32(pb+4), u32(pb+8))
end
ARGS[0xA9A0] = function(pb)
	return string.format("id=%d type='%s'", s16(u16(pb)), ostype(u32(pb+2)))
end
-- ⭐ Validated independently: every ID this printed is a real PICT resource in
-- `Color VETTE!` (192 of them, scattered over 68..31884).  The $0000 word above
-- the ID is the Pascal result-space pad the caller pushes because the PicHandle
-- result (4 B) is wider than the picID parameter (2 B).
ARGS[0xA9BC] = function(pb) return string.format("PICT id=%d", s16(u16(pb))) end
ARGS[0xA8F6] = function(pb)
	local r = u32(pb) & 0x00FFFFFF
	local h = u32(pb+4) & 0x00FFFFFF
	return string.format("pic=%06X dstRect@%06X %s", h, r, rect(r))
end


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
	-- ⚠⚠ A segment number can have MORE THAN ONE base.  _UnLoadSeg / _LoadSeg
	-- reload a segment wherever the heap has room, so over a run the same CODE
	-- resource is resident at several addresses -- and the jump table can hold
	-- entries pointing into an OLD copy alongside entries for the new one.
	-- Taking min(addr) per segment number therefore pins a base that no copy
	-- has: that is what "BASE NOT FOUND (lowest export 7772EE)" meant while
	-- 11 980 dispatches from $77xxxx sat unattributed, and $77xxxx turned out to
	-- hold a second copy of `Initialize`.  So CLUSTER the addresses per segment
	-- number and pin one base per cluster.
	local jt, addrs = a5 + 32, {}
	local resident = 0
	for i = 0, 508 do
		local e = jt + i * 8
		if prog:read_u16(e + 2) == 0x4EF9 then
			resident = resident + 1
			local seg  = prog:read_u16(e)
			local addr = prog:read_u32(e + 4) & 0x00FFFFFF
			if addr > 0x1000 then
				addrs[seg] = addrs[seg] or {}
				addrs[seg][#addrs[seg] + 1] = addr
			end
		end
	end
	local segl = {}
	for seg in pairs(addrs) do segl[#segl+1] = seg end
	table.sort(segl)
	-- is OUR app the current one?  seg 1 (Main) pinned is the proof.
	local have_app = false
	for _, e in pairs(byaddr) do if e.seg == 1 then have_app = true end end
	local fresh = {}
	for _, seg in ipairs(segl) do
		local info = SEGS[seg]
		local h0, h1, len = nil, nil, nil
		if info then h0, h1, len = seg_head(info[2]) end
		if not h0 then
			print(string.format("VP ⚠⚠ seg %2d: no extracted resource, run hfs_extract", seg))
			goto next_seg
		end
		-- cluster this segment's export addresses: anything within one segment
		-- length of the cluster's lowest address belongs to the same copy
		table.sort(addrs[seg])
		local clusters = {}
		for _, a in ipairs(addrs[seg]) do
			local cl = clusters[#clusters]
			if cl and a < cl[1] + len then cl[#cl + 1] = a else clusters[#clusters + 1] = {a} end
		end
		for _, cl in ipairs(clusters) do
			local base, matches = nil, 0
			for c = cl[1], cl[1] - len, -2 do
				if c > 0x1000 and prog:read_u32(c) == h0 and prog:read_u32(c + 4) == h1 then
					matches = matches + 1; if not base then base = c end
				end
			end
			-- ⚠⚠ SECOND, INDEPENDENT test, and it is the one that matters: every
			-- export in the cluster must fall INSIDE [base, base+len).  The
			-- 8-byte resource header is low-entropy (a small offset and a small
			-- count), so it chance-matches: a scan of $77xxxx "found" seg 2
			-- Initialize at $77D2FE, and $77xxxx is the FINDER's code.  Before
			-- the app is loaded CurrentA5 is another application's, so its jump
			-- table is what gets scanned -- with ITS segment numbers 1..7, which
			-- collide with ours.  The span test rejects all of it.
			if base and cl[#cl] >= base + len then base = nil end
			if base then
				local old = byaddr[base]
				if old and old.seg ~= seg then
					print(string.format("VP ⚠⚠ base %06X claimed by seg %d (%s) AND seg %d (%s)"
						.. " -- PCs in it are AMBIGUOUS", base, old.seg, old.name, seg, info[1]))
				elseif not old then
					byaddr[base] = {base = base, len = len, seg = seg, name = info[1],
						mapped_frame = mac.frames()}
					fresh[#fresh+1] = string.format("seg %d %s @%06X", seg, info[1], base)
				end
				if matches > 1 then
					print(string.format("VP ⚠ seg %d %s: %d candidate bases matched the"
						.. " resource's first 8 bytes -- not unique", seg, info[1], matches))
				end
			elseif have_app then
				-- ⚠ Only worth reporting once OUR app is known loaded; before
				-- that every miss is just another application's jump table.
				print(string.format("VP ⚠⚠ seg %2d %-14s BASE NOT FOUND below export %06X"
					.. " (%d exports spanning %d bytes) -- resident image differs?",
					seg, info[1], cl[1], #cl, cl[#cl] - cl[1]))
			end
		end
		::next_seg::
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
map_segments_safe = map_segments

-- ⭐⭐ "Is this caller the GAME?" -- a CODE segment that is mapped RIGHT NOW must
-- claim it.  ⚠⚠ Resolve LIVE, never retroactively.  An earlier version resolved
-- every recorded PC against the FINAL map at report time, and so attributed the
-- FINDER's traps to `Main`: the Finder is an application too, its CODE segments
-- occupy the same heap addresses, and its trap profile (menus, windows,
-- GetNextEvent, dialogs, resource files) is exactly what a game's looks like.
-- 30-odd traps were put on the work list that way.  The giveaway was `_Launch`
-- from "Main+4200" -- only the Finder calls _Launch, and it called it to start
-- this very game.  A segment enters `bases` only once its own resource bytes are
-- found resident, so scanning `bases` at hit time cannot see that far back.
claimed = function(pc)
	for _, b in ipairs(bases) do
		if pc >= b.base and pc < b.base + b.len then return b end
	end
	return nil
end

local function where(pc)
	for _, e in ipairs(bases) do
		if pc >= e.base and pc < e.base + e.len then
			return string.format("%s+%04X", e.name, pc - e.base)
		end
	end
	return string.format("(%06X)", pc)
end

local function report()
	-- ⚠ An unattributed caller is either the System or a segment we never
	-- mapped.  Print the regions so the difference is visible instead of assumed.
	local region = {}
	for k, c in pairs(count) do
		for pc, n in pairs(c.pcs or {}) do
			local r = pc >> 16
			region[r] = (region[r] or 0) + n
		end
	end
	-- ⭐ frame range per region: a region whose traps ALL land before the app was
	-- loaded belongs to whatever ran before it, and that is the Finder.
	for r, fr in pairs(regframes) do
		region[r] = region[r] or 0
	end

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
	-- ⚠ Ordered by the first call BY THE GAME, attributed live (see claimed()).
	local g_first, g = {}, {}
	for _, k in ipairs(game_order) do g_first[#g_first+1] = k; g[k] = count[k].game_first.at end
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
			k, nm, enc, c.ram, c.rom, c.game_first.frame, g[k], c.game_first.phase))
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
	p("")
	p("VP ---- ARGUMENTS, first 24 of each ----")
	local ak = {}
	for k in pairs(arglog) do ak[#ak+1] = k end
	table.sort(ak)
	for _, k in ipairs(ak) do
		p(string.format("VP  %s %s:", k, (name(tonumber(k:sub(1, 4), 16)))))
		for _, e in ipairs(arglog[k]) do
			p(string.format("VP      f%-6d %-16s %s", e.frame, where(e.pc), e.text))
		end
	end
	-- ⭐⭐ Dispatches per mapped SEGMENT, resolved against the FINAL map, so a
	-- segment that ran and was purged early (%A5Init) is still counted.  This is
	-- the only way to tell "that segment calls no traps" from "we never saw it".
	-- ⚠ Attribution is by EXACT PC, not by bucket: a coarse bucket double-counts
	-- wherever two mapped ranges share one, which they do (see the overlap check).
	p("")
	p("VP ---- dispatches per mapped CODE segment (attributed LIVE) ----")
	local segnames = {}
	for nm in pairs(segcount) do segnames[#segnames+1] = nm end
	table.sort(segnames, function(a, b) return segcount[a].n > segcount[b].n end)
	local tot = 0
	for _, nm in ipairs(segnames) do
		local sc, sites = segcount[nm], 0
		for _ in pairs(sc.sites) do sites = sites + 1 end
		tot = tot + sc.n
		p(string.format("VP    seg %2d %-14s %8d dispatches from %4d distinct trap sites",
			sc.seg, nm, sc.n, sites))
	end
	p(string.format("VP    %d of %d RAM dispatches are the GAME's; the other %d are the System"
		.. " calling traps on its behalf", tot, n_ram, n_ram - tot))
	p("")
	p("VP ---- exact live trap sites (stable input for the static-map cross-check) ----")
	p(string.format("VP %-14s %6s %4s %-18s %9s %s",
		"segment", "offset", "word", "name", "calls", "notes"))
	for _, nm in ipairs(segnames) do
		local sc, pcs = segcount[nm], {}
		for pc in pairs(sc.sites) do pcs[#pcs + 1] = pc end
		table.sort(pcs, function(a, b)
			local sa, sb = sc.sites[a], sc.sites[b]
			return sa.offset == sb.offset and a < b or sa.offset < sb.offset
		end)
		for _, pc in ipairs(pcs) do
			local site = sc.sites[pc]
			local trapname = name(site.word)
			p(string.format("VP %-14s +%04X %04X %-18s %9d %s",
				nm, site.offset, site.word, trapname, site.count,
				site.changed and "TRAP WORD CHANGED" or ""))
		end
	end
	-- ⚠⚠ Do the mapped ranges overlap?  If they do, a PC in the overlap is
	-- attributed to whichever segment is scanned first and the number is a lie.
	for i = 1, #bases do
		for j = i + 1, #bases do
			local a, b = bases[i], bases[j]
			local lo, hi = math.max(a.base, b.base), math.min(a.base + a.len, b.base + b.len)
			if lo < hi then
				p(string.format("VP ⚠⚠ OVERLAP %s [%06X,%06X) and %s [%06X,%06X) share %d bytes",
					a.name, a.base, a.base + a.len, b.name, b.base, b.base + b.len, hi - lo))
			end
		end
	end
	p("")
	p("VP ---- all RAM caller PCs by 64 KB region (is anything here an unmapped segment?) ----")
	local rs = {}
	for r in pairs(region) do rs[#rs+1] = r end
	table.sort(rs, function(a, b) return region[a] > region[b] end)
	local rl = {}
	for _, r in ipairs(rs) do
		local tag = ""
		for _, e in ipairs(bases) do
			if (e.base >> 16) == r then tag = "=" .. e.name end
		end
		local fr = regframes[r]
		rl[#rl+1] = string.format("%02Xxxxx%s:%d[f%d-%d]", r, tag, region[r],
			fr and fr[1] or -1, fr and fr[2] or -1)
	end
	p("VP " .. table.concat(rl, "  "))
	-- ⭐ Decisive check on the unattributed regions: is any of them an unmapped
	-- GAME segment?  Scan only the 64 KB regions that actually called a trap,
	-- for every segment's own first 8 bytes.  ⚠⚠ A hit is only a SIGNATURE hit:
	-- the 8-byte CODE header is low-entropy and chance-matches inside unrelated
	-- code (it did, in the Finder's $77xxxx).  Treat a hit as "look here", never
	-- as "this is that segment" -- the frame range in the histogram above and
	-- the live map are the evidence that settles it.
	p("")
	p("VP ---- scanning the unattributed regions for ANY segment's signature ----")
	local want = {}
	for seg, info in pairs(SEGS) do
		local h0, h1, len = seg_head(info[2])
		if h0 then want[#want+1] = {seg = seg, name = info[1], h0 = h0, h1 = h1, len = len} end
	end
	for _, r in ipairs(rs) do
		local mapped = false
		for _, e in ipairs(bases) do if (e.base >> 16) == r then mapped = true end end
		if not mapped then
			local found = {}
			for a = r << 16, (r << 16) + 0xFFFE, 2 do
				local v = prog:read_u32(a)
				for _, w in ipairs(want) do
					if v == w.h0 and prog:read_u32(a + 4) == w.h1 then
						found[#found+1] = string.format("seg %d %s @%06X", w.seg, w.name, a)
					end
				end
			end
			p(string.format("VP   %02Xxxxx (%d calls): %s", r, region[r],
				#found > 0 and ("⚠⚠ " .. table.concat(found, ", ")) or "no segment signature -- System code"))
		end
	end
	if out then out:close(); print("VP wrote ref/mame/traps.txt") end
end

mac.run(function()
	phase = "boot"
	if not mac.launch() then return end
	-- ⚠⚠ Do NOT clear the accumulators here.  An earlier version did, to drop
	-- ~56 k dispatches of System + Finder noise -- but attribution is by
	-- SEGMENT now, so that noise is already excluded, and %A5Init runs BEFORE
	-- CurApName flips.  Clearing at launch threw away the one window in which
	-- %A5Init's traps could ever be seen.
	print(string.format("VP launch at frame %d, %d dispatches so far (KEPT)", mac.frames(), n_hits))
	phase = "launched"
	launch_frame = mac.frames()
	if full_intro then
		-- The measured full animation closes its own window about 2 040 frames
		-- after launch.  Keep a small margin so the next click belongs to the
		-- garage, not to the intro's Button polling loop.
		mac.wait(2160)
	else
		mac.wait(90)
		click(560, 400, 360) -- first Button poll: leave the intro
	end
	phase = "garage"
	mac.step("trap run: garage"); mac.shot()
	click(357, 252, 240)     -- garage ACCEPT
	phase = "vehicle"
	click(477, 160, 180)     -- upper vehicle plate
	click(276, 245, 360)     -- vehicle selector ACCEPT
	phase = "course"
	click(509, 399, 180)     -- Course One ACCEPT
	if protection_prompt then
		phase = "protection"
		click(276, 284, 30)  -- focus the password edit field
		mac.type("16")       -- manual's Chinatown entry
		click(451, 284, 180) -- protection OK
	end
	phase = "driving"
	mac.wait(1200)
	mac.step("trap run: driving"); mac.shot()
	report_windows("driving")
	mac.shot()
	map_segments()
	local n = 0
	for _ in pairs(byaddr) do n = n + 1 end
	print(string.format("VP %d segment placements mapped over the run:", n))
	for _, e in ipairs(bases) do
		print(string.format("VP    seg %2d %-14s base %06X len %6d", e.seg, e.name, e.base, e.len))
	end
	report()
end)
