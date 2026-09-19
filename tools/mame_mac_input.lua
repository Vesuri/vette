-- Driving a Macintosh under MAME headlessly: input injection + state readback.
--
-- WHY a library: every ground-truth capture this project takes has to get from a
-- cold boot to a specific game state with NO window open and NO human, and the
-- two hard parts are the same every time -- synthesising ADB input, and knowing
-- when a step actually completed.
--
-- ⭐ The second part is the important one.  Do NOT sleep a guessed number of
-- frames and hope: read the Mac's own low-memory globals and wait for the state
-- you asked for.  CurApName ($910) says which application is frontmost, which is
-- how "did the game launch?" gets a yes/no answer instead of a screenshot to
-- squint at.  A capture that guesses is a capture that passes when it did nothing.
--
--   TICKS      = frames of EMULATED 60 Hz time, so runs are host-speed independent.
--   mac.run(f) = start a coroutine; mac.wait(n) inside it yields n frames.
--
-- Usage: -autoboot_script a driver that does `local mac = dofile(".../mame_mac_input.lua")`.

local mac = {}

local prog = manager.machine.devices[":maincpu"].spaces["program"]

-- Low memory (Inside Macintosh: Operating System Utilities).
local CurApName = 0x910   -- Str31: frontmost application name
local RawMouse  = 0x82C   -- Point (v, h): the cursor, in global coordinates
local MacJmp    = 0x120   -- non-zero when a debugger is installed

function mac.pstring(addr, max)
	local n = prog:read_u8(addr)
	if n > (max or 31) then return nil end
	local s = ""
	for i = 1, n do s = s .. string.char(prog:read_u8(addr + i)) end
	return s
end

function mac.frontmost()  return mac.pstring(CurApName) end
function mac.mouse()      return prog:read_i16(RawMouse + 2), prog:read_i16(RawMouse) end  -- h, v
function mac.debugger()   return prog:read_u32(MacJmp) end

-- ---------------------------------------------------------------- input ------

-- ⚠ MAME names a letter key by BOTH its legends: the "o" key is the field
-- "o  O" (two spaces).  Accept the bare letter and widen it here, or every
-- caller has to know that.
local function find_field(name)
	local tries = { name }
	if #name == 1 then tries[#tries + 1] = name .. "  " .. name:upper() end
	for _, want in ipairs(tries) do
		for _, port in pairs(manager.machine.ioport.ports) do
			local f = port.fields[want]
			if f then return f end
		end
	end
	error("no ioport field named " .. name)
end

local HOLD, GAP = 4, 4    -- ⚠ ADB is polled, so a 1-frame press can be missed entirely

function mac.press(name, mods)
	local held = {}
	for _, m in ipairs(mods or {}) do
		local f = find_field(m); f:set_value(1); held[#held + 1] = f
	end
	local f = find_field(name)
	mac.wait(2)
	f:set_value(1);  mac.wait(HOLD)
	f:set_value(0)
	for _, h in ipairs(held) do h:set_value(0) end
	mac.wait(GAP)
end

-- Hold/release a physical key across an arbitrary number of emulated frames.
-- Driving reads GetKeys state rather than waiting for keyDown Events, so a
-- bounded press is not equivalent to a held accelerator.
function mac.key_down(name) find_field(name):set_value(1) end
function mac.key_up(name) find_field(name):set_value(0) end

mac.CMD = "Command / Open Apple"

-- ⛔ MEASURED DEAD END: `manager.machine.natkeyboard:post(text)` types NOTHING on
-- this driver, with or without `in_use = true` -- the `macadb` keyboard exposes no
-- natural-keyboard character map, so the call returns quietly and the next step
-- then acts on whatever was selected already.  That reads exactly like a working
-- script, which is why typing goes through the ioport fields below instead.
--
-- ⚠ The Finder's type-select has a timeout: characters must arrive within about a
-- second of each other or the selection restarts, so keep TYPE_HOLD/TYPE_GAP tight.
local TYPE_HOLD, TYPE_GAP = 3, 2

local PUNCT = { [" "] = "Space", ["."] = ".  >", ["!"] = "1  !", ["-"] = "-  _" }

function mac.type(text)
	for i = 1, #text do
		local c = text:sub(i, i)
		local name = PUNCT[c] or (c:match("%a") and c:lower() .. "  " .. c:upper())
			or (c:match("%d") and nil) or nil
		if not name and c:match("%d") then
			-- digits carry their shifted legend: "6  ^", "1  !", ...
			for _, port in pairs(manager.machine.ioport.ports) do
				for fname, _ in pairs(port.fields) do
					if fname:sub(1, 1) == c and fname:sub(2, 2) == " " then name = fname end
				end
			end
		end
		if not name then error("mac.type: no key for " .. c) end
		local f = find_field(name)
		f:set_value(1); mac.wait(TYPE_HOLD)
		f:set_value(0); mac.wait(TYPE_GAP)
	end
end

-- Closed-loop pointer.
--
-- ⚠⚠ Two things about MAME's mouse axes cost real time if not known:
--  1. The axis field is 0..255 and works on the CHANGE between successive reads,
--     so HOLDING a value moves the cursor nowhere.  Values must be accumulated
--     (mod 256) frame by frame.
--  2. The Mac applies its own acceleration curve, so units are NOT pixels --
--     measured here at ~0.3 px/unit, and non-linear with step size.
-- Hence: no calibration constant, no open-loop "move by N".  Read the Mac's own
-- cursor global and iterate until it IS at the target.
local acc_x, acc_y = 0, 0

-- ⚠ Aim for a TOLERANCE, not an exact pixel.  With the acceleration curve in the
-- loop, demanding (h,v) exactly makes the cursor oscillate around the target for
-- ever and then park in a screen corner; an icon is 32 px wide, so +-3 px is
-- ample and it converges in a few dozen frames.
function mac.mouse_to(target_h, target_v, tol, tries)
	tol = tol or 3
	local fx, fy = find_field("Mouse X"), find_field("Mouse Y")
	for _ = 1, tries or 400 do
		local h, v = mac.mouse()
		local dh, dv = target_h - h, target_v - v
		if math.abs(dh) <= tol and math.abs(dv) <= tol then
			-- ⚠⚠ SETTLE before believing it.  The ADB consumes one more delta after
			-- the loop stops writing, so a position read the instant the tolerance
			-- is met is read BEFORE the cursor has finished moving -- which lands a
			-- double-click a dozen pixels off the icon and looks like "the click
			-- did nothing" rather than "the aim was wrong".
			mac.wait(6)
			h, v = mac.mouse()
			if math.abs(target_h - h) <= tol and math.abs(target_v - v) <= tol then
				return true
			end
		end
		local step = function(d)
			if math.abs(d) <= tol then return 0 end
			local mag = math.max(2, math.min(40, math.floor(math.abs(d) * 1.5)))
			return d > 0 and mag or -mag
		end
		acc_x = (acc_x + step(dh)) % 256
		acc_y = (acc_y + step(dv)) % 256
		fx:set_value(acc_x); fy:set_value(acc_y)
		mac.wait(1)
	end
	local h, v = mac.mouse()
	print(string.format("VP WARN mouse_to(%d,%d) ended at (%d,%d)", target_h, target_v, h, v))
	return false
end

-- Pull down a menu and choose an item, by screen coordinate.
--
-- ⚠ Mac menus are press-DRAG-release, not click-then-click: the button must stay
-- down from the title to the item.  Releasing back on the title chooses nothing,
-- which is the safe way to probe a menu's geometry (snapshot while held).
--
-- Finder menu titles (640x480, System 6.0.8): File 44, Edit 78, View 114,
-- Special 200.  Special items: Clean Up Window 28, Erase Disk 60,
-- Set Startup... 74, Restart 107, Shut Down 121.
function mac.menu(title_h, item_v, title_v)
	local b = find_field("Mouse Button 0")
	mac.mouse_to(title_h, title_v or 7)
	b:set_value(1)
	mac.wait(20)
	mac.mouse_to(title_h, item_v)
	mac.wait(20)
	b:set_value(0)
	mac.wait(30)
end

function mac.click(n)
	local b = find_field("Mouse Button 0")
	for _ = 1, n or 1 do
		b:set_value(1); mac.wait(3)
		b:set_value(0); mac.wait(3)      -- ⚠ inside the double-click time, so keep it tight
	end
	mac.wait(GAP)
end

-- ------------------------------------------------------------- scheduling ----

local co
local frames = 0

function mac.wait(n)
	for _ = 1, n or 1 do coroutine.yield() end
end

function mac.frames() return frames end

-- Wait until f() is truthy, or give up.  Returns the value, or nil on timeout.
function mac.wait_for(what, f, limit)
	for _ = 1, limit or 3600 do
		local v = f()
		if v then return v end
		coroutine.yield()
	end
	print("VP TIMEOUT waiting for " .. what)
	return nil
end

function mac.shot() manager.machine.video:snapshot() end

function mac.run(fn)
	co = coroutine.create(fn)
	emu.register_frame_done(function()
		frames = frames + 1
		if co and coroutine.status(co) ~= "dead" then
			local ok, err = coroutine.resume(co)
			if not ok then print("VP ERROR " .. tostring(err)) end
		end
	end)
end

-- ------------------------------------------------------------- launching ----

-- Boot to the Finder and launch Color VETTE!.
--
-- ⚠ Navigation is MOUSE, by coordinate, because System 6's Finder has no
-- type-select (that is a System 7 feature).  The coordinates are only stable
-- because the icons were put on a grid once with Special > Clean Up Window; the
-- positions then live in the volume's own catalog and survive reboots.
--
-- Completion is read from CurApName, never from a screenshot: a launch that
-- silently did nothing shows up as "Finder" where "Color VETTE!" was expected.
local VOLUME_FOLDER = { 135, 160 }   -- "Color VETTE!" folder in the volume window
local APP           = { 104, 105 }   -- "Color VETTE!" application in that folder

function mac.step(label)
	print(string.format("VP %-22s frame=%-6d front=%-16s mouse=(%d,%d)",
		label, mac.frames(), tostring(mac.frontmost()), mac.mouse()))
end

function mac.launch()
	mac.wait_for("Finder", function() return mac.frontmost() == "Finder" end, 3600)
	mac.step("booted")
	mac.wait(240)

	-- ⭐ The Finder reopens whatever windows were open at shutdown, so the folder is
	-- usually already on screen: try the application directly, and only navigate if
	-- that did nothing.  Checking rather than assuming is the whole point -- a blind
	-- double-click into the desktop is indistinguishable from a slow launch.
	mac.mouse_to(APP[1], APP[2]); mac.click(2)
	mac.wait(240)
	if mac.frontmost() ~= "Color VETTE!" then
		mac.step("direct click missed; navigating")
		mac.press("o", { mac.CMD })              -- the volume icon is selected at boot
		mac.wait(180)
		mac.mouse_to(VOLUME_FOLDER[1], VOLUME_FOLDER[2]); mac.click(2)
		mac.wait(240)
		mac.step("folder opened")
		mac.mouse_to(APP[1], APP[2]); mac.click(2)
	end
	local ok = mac.wait_for("Color VETTE! frontmost",
		function() return mac.frontmost() == "Color VETTE!" end, 1800)
	mac.step(ok and "LAUNCHED" or "launch FAILED")
	return ok
end

return mac
