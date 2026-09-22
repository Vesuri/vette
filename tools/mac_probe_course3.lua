-- System 6 oracle for Course Three's accepted and first live driving state.
-- Coordinates are Macintosh globals for the fixed 512x320 VETTE! window.
local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")
local prog = manager.machine.devices[":maincpu"].spaces["program"]
local cpu = manager.machine.devices[":maincpu"]
local keep = {}

local function arm_course_normalize_trace()
	local a5 = prog:read_u32(0x904) & 0x00ffffff
	local traffic = (prog:read_u32(a5 + 32 + 172 * 8 + 4) - 0x09ae) & 0x00ffffff
	for _, offset in ipairs({ 0x0794, 0x079e, 0x07a8, 0x07b4 }) do
		local target = traffic + offset
		keep[#keep + 1] = prog:install_read_tap(target & ~3, (target & ~3) + 3,
			"course3_" .. string.format("%04x", offset), function(_, data, _)
				if (cpu.state["PC"].value & 0x00ffffff) == target then
					print(string.format("COURSE3_D0 offset=%04x d0=%08x course=%d long=%d",
						offset, cpu.state["D0"].value, prog:read_u8(a5 - 0x555a),
						prog:read_i16(a5 - 0x5082)))
				end
				return data
			end)
	end
end

local function click(h, v, wait)
	mac.mouse_to(h, v)
	mac.click(1)
	mac.wait(wait or 90)
	mac.step(string.format("clicked %d,%d", h, v))
end

mac.run(function()
	if not mac.launch() then return end
	mac.wait(1200)

	click(357, 252) -- garage ACCEPT
	click(477, 160) -- top plate
	click(508, 247) -- Corvette ZR-1
	click(354, 252) -- vehicle ACCEPT
	click(477, 158) -- TRAINEE
	click(354, 252) -- difficulty ACCEPT
	click(276, 245) -- opponent ACCEPT
	mac.shot()
	click(322, 399) -- COURSE 3
	arm_course_normalize_trace()
	click(509, 399) -- course ACCEPT
	mac.shot()
	click(276, 284, 30) -- copy-protection edit field
	mac.type("16") -- manual page 32: Chinatown
	click(451, 284, 180) -- copy-protection OK

	for _ = 1, 900 do
		local a5 = prog:read_u32(0x904)
		if a5 ~= 0 then
			local car = prog:read_u32(a5 - 13944)
			if car ~= 0 and prog:read_u16(car + 0x3e) ~= 0 then
				print(string.format(
					"COURSE3_ORACLE a5=%08x course=%d long=%d world=(%08x,%08x) cell=(%d,%d) heading=%04x",
					a5, prog:read_u8(a5 - 0x555a), prog:read_i16(a5 - 0x5082),
					prog:read_u32(car), prog:read_u32(car + 8),
					prog:read_u16(car + 0x3e), prog:read_u16(car + 0x40),
					prog:read_u16(car + 0x66)))
				return
			end
		end
		mac.wait(1)
	end
	local a5 = prog:read_u32(0x904)
	local car = a5 ~= 0 and prog:read_u32(a5 - 13944) or 0
	print(string.format("COURSE3_ORACLE timeout a5=%08x car=%08x course=%d long=%d",
		a5, car, a5 ~= 0 and prog:read_u8(a5 - 0x555a) or -1,
		a5 ~= 0 and prog:read_i16(a5 - 0x5082) or -1))
end)
