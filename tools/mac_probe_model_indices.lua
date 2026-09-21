-- Capture the authoritative indexed-PixMap state at Vette's rotating-model
-- CopyBits call on the original Macintosh execution under MAME.
--
-- The capture records source/destination PixMap geometry and both ColorTables,
-- including ColorSpec.value.  Those values—not screenshot RGB guesses—define
-- how the model's four-bit pixels are realized on the destination device.

local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")
local cpu = manager.machine.devices[":maincpu"]
local prog = cpu.spaces["program"]
local keep, dispatcher = {}, 0
local captures = 0
local last_key = ""
local raw_calls = 0
local palette_calls = 0
local stage = "startup"
local stage_captured = {}
local device_seeds = {}
local inverse_seeds = {}
local pending_selector_pixmap = 0
local protection_prompt = false
local driving_ports = {}
local driving_copy_captures = 0
local driving_capture_armed = false
local driving_sequence_manifest = nil
local driving_motion = os.getenv("VETTE_DRIVING_MOTION") == "1"
local driving_capture_limit = driving_motion and 40 or 4
local driving_capture_stem = driving_motion and "driving-motion-source" or "driving-copy-source"
local driving_manifest_path = driving_motion and
	"ref/mame/driving-motion-sequence.tsv" or "ref/mame/driving-sequence.tsv"
local last_driving_state = nil
local driving_frame_ready = false
local driving_a5 = 0
if driving_motion then
	os.remove(driving_manifest_path)
	for i = 1, driving_capture_limit do
		os.remove(string.format("ref/mame/%s-%u.raw", driving_capture_stem, i))
		os.remove(string.format("ref/mame/driving-motion-globals-%u.bin", i))
		os.remove(string.format("ref/mame/driving-motion-car-%u.bin", i))
		for object = 0, 31 do
			os.remove(string.format("ref/mame/driving-motion-object-%u-%u.bin", i, object))
		end
	end
end
local palette_for_window = {}
local last_activate_window = 0
local mirror_write_armed = false
local trace_mirror_writer = os.getenv("VETTE_MIRROR_WRITER") == "1"
local mirror_write_count = 0
local dashboard_write_armed = false
local trace_dashboard_writer = os.getenv("VETTE_DASHBOARD_WRITER") == "1"
local dashboard_write_count = 0
local traffic_raster_dumped = false
local mirror_source_write_count = 0

local function a24(v) return v & 0x00FFFFFF end
local function u16(a) return prog:read_u16(a24(a)) end
local function u32(a) return prog:read_u32(a24(a)) end
local function s16(v) return v >= 0x8000 and v - 0x10000 or v end

local function rect(a)
	return s16(u16(a)), s16(u16(a + 2)), s16(u16(a + 4)), s16(u16(a + 6))
end

local function dump_ctab(label, pixmap)
	local table_handle = a24(u32(pixmap + 42))
	local table = table_handle ~= 0 and a24(u32(table_handle)) or 0
	if table == 0 then
		print(string.format("VP %s pmTable=nil", label)); return
	end
	local last = math.min(u16(table + 6), 15)
	print(string.format("VP %s pmTable=%06X table=%06X seed=%08X flags=%04X size=%u",
		label, table_handle, table, u32(table), u16(table + 4), last))
	for i = 0, last do
		local p = table + 8 + i * 8
		print(string.format("VP %s[%02u] value=%04X rgb=%04X/%04X/%04X",
			label, i, u16(p), u16(p + 2), u16(p + 4), u16(p + 6)))
	end
end

local function ctab_address(pixmap)
	local table_handle = a24(u32(pixmap + 42))
	return table_handle ~= 0 and a24(u32(table_handle)) or 0
end

local function dump_palette(label, palette_handle)
	local palette = palette_handle ~= 0 and a24(u32(palette_handle)) or 0
	if palette == 0 then
		print(string.format("VP %s palette=nil handle=%06X", label, palette_handle))
		return
	end
	local count = math.min(u16(palette), 16)
	print(string.format("VP %s palette=%06X handle=%06X entries=%u", label,
		palette, palette_handle, count))
	for i = 0, count - 1 do
		local p = palette + 16 + i * 16
		print(string.format("VP %s[%02u] rgb=%04X/%04X/%04X usage=%04X tolerance=%04X private=%04X/%04X/%04X",
			label, i, u16(p), u16(p + 2), u16(p + 4), u16(p + 6), u16(p + 8),
			u16(p + 10), u16(p + 12), u16(p + 14)))
	end
end

local function dump_pixmap(label, pixmap)
	local top, left, bottom, right = rect(pixmap + 6)
	print(string.format("VP %s pixmap=%06X base=%06X rowBytes=%04X bounds=(%d,%d)-(%d,%d) depth=%u",
		label, pixmap, a24(u32(pixmap)), u16(pixmap + 4), top, left, bottom, right,
		u16(pixmap + 32)))
	dump_ctab(label, pixmap)
end

local function arm_mirror_writer(pixmap)
	if not trace_mirror_writer or mirror_write_armed or pixmap == 0
		or (u16(pixmap + 4) & 0x8000) == 0 or u16(pixmap + 32) ~= 4 then return end
	local top, left, bottom, right = rect(pixmap + 6)
	if top ~= 0 or left ~= 0 or bottom ~= 512 or right ~= 512 then return end
	local byte = a24(u32(pixmap)) + 433
	local aligned = byte & ~3
	mirror_write_armed = true
	keep[#keep + 1] = prog:install_write_tap(aligned, aligned + 3,
		"driving_mirror_writer", function(_, data, mask)
			if driving_capture_armed then
				mirror_write_count = mirror_write_count + 1
				local a5 = a24(cpu.state["A5"].value)
				local car = a24(u32(a5 - 13944))
				if mirror_write_count <= 8 then print(string.format(
					"VP MIRROR WRITE #%u frame=%u pc=%06X byte=%06X data=%08X mask=%08X old=%02X d1=%08X d2=%08X d3=%08X d4=%08X a0=%06X a1=%06X height=%04X subtract20=%04X viewportBottom=%04X stride=%08X skew=%04X car=%06X car26=%04X buffers=%06X/%06X/%06X",
					mirror_write_count, mac.frames(), a24(cpu.state["PC"].value), byte,
					data, mask, prog:read_u8(byte), cpu.state["D1"].value,
					cpu.state["D2"].value, cpu.state["D3"].value,
					cpu.state["D4"].value, a24(cpu.state["A0"].value),
					a24(cpu.state["A1"].value), u16(a5 - 14970), u16(a5 - 964),
					u16(a5 - 848), u32(a5 - 960), u16(a5 - 13310),
					car, car ~= 0 and u16(car + 26) or 0, a24(u32(a5 - 20450)),
					a24(u32(a5 - 20446)), a24(u32(a5 - 20442)))) end
				-- The watch byte lies on row one of the 78x84-byte raster.  At this
				-- point A1 has advanced by one 260-byte source row, while D2 has
				-- already been expanded from 21 longwords to the 83 DBF count.
				if not traffic_raster_dumped and cpu.state["D2"].value == 83
					and cpu.state["D3"].value == 172 then
					traffic_raster_dumped = true
					local source = a24(cpu.state["A1"].value - 260)
					print(string.format("VP Traffic raster source=%06X rows=78 rowBytes=260", source))
					local out = assert(io.open("ref/mame/driving-mirror-source.raw", "wb"))
					for i = 0, 20279 do out:write(string.char(prog:read_u8(source + i))) end
					out:close()
				end
			end
		end)
	print(string.format("VP armed mirror writer byte=%06X frame=%u", byte, mac.frames()))
end

local function arm_dashboard_writer(pixmap)
	if not trace_dashboard_writer or dashboard_write_armed or pixmap == 0
		or (u16(pixmap + 4) & 0x8000) == 0 or u16(pixmap + 32) ~= 4 then return end
	local top, left, bottom, right = rect(pixmap + 6)
	if top ~= 0 or left ~= 0 or bottom < 342 or right ~= 512 then return end
	local stride = u16(pixmap + 4) & 0x3FFF
	local byte = a24(u32(pixmap)) + 310 * stride + 162
	local aligned = byte & ~3
	dashboard_write_armed = true
	keep[#keep + 1] = prog:install_write_tap(aligned, aligned + 3,
		"driving_dashboard_writer", function(_, data, mask)
			dashboard_write_count = dashboard_write_count + 1
			if dashboard_write_count <= 32 then
				local sp = a24(cpu.state["SP"].value)
				local return_pc = a24(u32(sp))
				local a5 = a24(cpu.state["A5"].value)
				print(string.format(
					"VP DASHBOARD WRITE #%u frame=%u ticks=%u pc=%06X return=%06X state[-340C]=%d byte=%06X data=%08X mask=%08X old=%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X a0=%06X a1=%06X a2=%06X",
					dashboard_write_count, mac.frames(), u32(0x016A),
					a24(cpu.state["PC"].value), return_pc, s16(u16(a5 - 0x340C)),
					byte, data, mask, prog:read_u32(aligned), cpu.state["D0"].value,
					cpu.state["D1"].value, cpu.state["D2"].value,
					cpu.state["D3"].value, cpu.state["D4"].value,
					a24(cpu.state["A0"].value), a24(cpu.state["A1"].value),
					a24(cpu.state["A2"].value)))
			end
		end)
	print(string.format("VP armed dashboard writer byte=%06X frame=%u", byte, mac.frames()))
end

local function arm_mirror_source_writer()
	if not trace_mirror_writer then return end
	local a5 = a24(cpu.state["A5"].value)
	local owner = a24(u32(a5 - 31234))
	local field = owner ~= 0 and a24(u32(owner + 2)) or 0
	local first = field ~= 0 and a24(u32(field)) or 0
	local base = first ~= 0 and a24(u32(first)) or 0
	local row = u32(a5 - 11922 + 388 * 4)
	local source = a24(base + row)
	local byte = source + 262
	print(string.format("VP mirror source owner=%06X field=%06X first=%06X base=%06X row=%08X byte=%06X",
		owner, field, first, base, row, byte))
	if source == 0 then return end
	local aligned = byte & ~3
	keep[#keep + 1] = prog:install_write_tap(aligned, aligned + 3,
		"driving_mirror_source_writer", function(_, data, mask)
			mirror_source_write_count = mirror_source_write_count + 1
			if mirror_source_write_count <= 16 then
				local writer_pc = a24(cpu.state["PC"].value)
				print(string.format(
					"VP MIRROR SOURCE WRITE #%u frame=%u pc=%06X byte=%06X data=%08X mask=%08X old=%02X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X a0=%06X a1=%06X",
					mirror_source_write_count, mac.frames(), writer_pc, byte, data, mask,
					prog:read_u8(byte), cpu.state["D0"].value,
					cpu.state["D1"].value, cpu.state["D2"].value,
					cpu.state["D3"].value, cpu.state["D4"].value,
					a24(cpu.state["A0"].value), a24(cpu.state["A1"].value)))
			end
		end)
end

local function main_device_pixmap()
	local device_handle = a24(u32(0x08A4)) -- MainDevice low-memory global
	local device = device_handle ~= 0 and a24(u32(device_handle)) or 0
	local pixmap_handle = device ~= 0 and a24(u32(device + 22)) or 0
	return pixmap_handle ~= 0 and a24(u32(pixmap_handle)) or 0
end

local function dump_bytes(path, address, count)
	local out = assert(io.open(path, "wb"))
	local chunk = {}
	for i = 0, count - 1 do
		chunk[#chunk + 1] = string.char(prog:read_u8(a24(address + i)))
		if #chunk == 4096 then out:write(table.concat(chunk)); chunk = {} end
	end
	if #chunk > 0 then out:write(table.concat(chunk)) end
	out:close()
end

local function dump_bus_bytes(path, address, count)
	local out = assert(io.open(path, "wb"))
	local chunk = {}
	for i = 0, count - 1 do
		chunk[#chunk + 1] = string.char(prog:read_u8(address + i))
		if #chunk == 4096 then out:write(table.concat(chunk)); chunk = {} end
	end
	if #chunk > 0 then out:write(table.concat(chunk)) end
	out:close()
end

local function on_copybits(pb)
	local destination_rect = a24(u32(pb + 6))
	local top, left, bottom, right = rect(destination_rect)
	local source_rect = a24(u32(pb + 10))
	local destination_field = a24(u32(pb + 14))
	local source_field = a24(u32(pb + 18))
	-- Color QuickDraw callers pass the address of portPixMap, i.e. a
	-- PixMapHandle field.  The field contains the Handle (master-pointer
	-- address), whose first longword is the movable PixMap itself.
	local destination_handle = a24(u32(destination_field))
	local source_handle = a24(u32(source_field))
	local destination = destination_handle ~= 0 and a24(u32(destination_handle)) or 0
	local source = source_handle ~= 0 and a24(u32(source_handle)) or 0
	raw_calls = raw_calls + 1
	if raw_calls == 1 then
		print(string.format("VP RAW COPY chain src=%06X->%06X->%06X dst=%06X->%06X->%06X",
			source_field, source_handle, source, destination_field, destination_handle, destination))
	end
	if source == 0 or destination == 0 then return end
	if (u16(source + 4) & 0x8000) == 0 or (u16(destination + 4) & 0x8000) == 0 then return end
	if u16(source + 32) ~= 4 or u16(destination + 32) ~= 4 then return end
	local st, sl, sb, sr = rect(source_rect)
	local source_base = a24(u32(source))
	local source_stride = u16(source + 4) & 0x3FFF
	local viewport_sample = prog:read_u8(source_base + source_stride * 10)
	local a5 = a24(cpu.state["A5"].value)
	local car = a5 ~= 0 and a24(u32(a5 - 0x3678)) or 0
	local object_count = a5 ~= 0 and u16(a5 - 0x3696) or 0
	local state_key = car ~= 0 and string.format("%d/%d/%d/%08X/%08X/%u/%08X/%08X",
		s16(u16(car + 0x44)), s16(u16(car + 0x1C)), s16(u16(car + 0x1A)),
		u32(car), u32(car + 8), u16(car + 0x66), u32(car + 0x6E), u32(car + 0x72)) or nil
	if stage == "driving" and st == 0 and sl == 0 and sb == 342 and sr == 512
		and top == 0 and left == 0 and bottom == 342 and right == 512
		and viewport_sample ~= 0x00 and viewport_sample ~= 0xFF then
		driving_a5 = a5
		driving_frame_ready = true
	end
	if driving_capture_armed and driving_copy_captures < driving_capture_limit
		and st == 0 and sl == 0 and sb == 342 and sr == 512
		and top == 0 and left == 0 and bottom == 342 and right == 512
		and viewport_sample ~= 0x00 and viewport_sample ~= 0xFF
		and (not driving_motion or state_key ~= last_driving_state) then
		driving_copy_captures = driving_copy_captures + 1
		last_driving_state = state_key
		print(string.format("VP DRIVING COPY #%u frame=%u mode=%u",
			driving_copy_captures, mac.frames(), u16(pb + 4)))
		if driving_sequence_manifest == nil then
			driving_sequence_manifest = assert(io.open(driving_manifest_path, "w"))
			driving_sequence_manifest:write(driving_motion and
				"capture\tticks\trpm\tgear\tspeed\tx\ty\theading\tphysics_x\tphysics_y\tobjects\n" or
				"capture\tticks\trpm\tgear\tspeed\tx\ty\theading\n")
		end
		local row = string.format(
			"%u\t%u\t%d\t%d\t%d\t%08X\t%08X\t%u",
			driving_copy_captures, u32(0x016A), s16(u16(car + 0x44)),
			s16(u16(car + 0x1C)), s16(u16(car + 0x1A)), u32(car),
			u32(car + 8), u16(car + 0x66))
		if driving_motion then
			row = row .. string.format("\t%08X\t%08X\t%u",
				u32(car + 0x6E), u32(car + 0x72), object_count)
		end
		driving_sequence_manifest:write(row .. "\n")
		driving_sequence_manifest:flush()
		local source_top, _, source_bottom, _ = rect(source + 6)
		dump_bytes(string.format("ref/mame/%s-%u.raw", driving_capture_stem, driving_copy_captures),
			a24(u32(source)),
			(u16(source + 4) & 0x3FFF) * (source_bottom - source_top))
		if driving_motion then
			dump_bytes(string.format("ref/mame/driving-motion-globals-%u.bin",
				driving_copy_captures), a5 - 31272, 31272)
			dump_bytes(string.format("ref/mame/driving-motion-car-%u.bin",
				driving_copy_captures), car, 0xC8)
			local object_end = a24(u32(a5 - 0x367C))
			local object_base = object_end - object_count * 4
			for object = 0, math.min(object_count, 32) - 1 do
				local record = a24(u32(object_base + object * 4))
				dump_bytes(string.format("ref/mame/driving-motion-object-%u-%u.bin",
					driving_copy_captures, object), record, 0xC8)
			end
		end
		if driving_copy_captures == 1 and not driving_motion then
			arm_dashboard_writer(source)
			dump_pixmap("DRIVING-SRC", source)
			dump_pixmap("DRIVING-DST", destination)
			dump_bytes("ref/mame/driving-copy-source.raw", a24(u32(source)),
				(u16(source + 4) & 0x3FFF) * (source_bottom - source_top))
			local source_table = ctab_address(source)
			local destination_table = ctab_address(destination)
			if source_table ~= 0 then dump_bytes("ref/mame/driving-copy-source.ctab", source_table, 136) end
			if destination_table ~= 0 then dump_bytes("ref/mame/driving-copy-destination.ctab", destination_table, 136) end
		end
	end
	if top ~= 165 or left ~= 177 or bottom ~= 316 or right ~= 505 then return end

	local st, sl, sb, sr = rect(source_rect)
	local source_table = ctab_address(source)
	local destination_table = ctab_address(destination)
	local key = string.format("%s/%06X/%08X/%06X/%08X", stage, source,
		source_table ~= 0 and u32(source_table) or 0, destination,
		destination_table ~= 0 and u32(destination_table) or 0)
	if key == last_key then return end
	last_key = key
	captures = captures + 1
	print(string.format("VP MODEL COPY #%u stage=%s frame=%u mode=%u sourceRect=(%d,%d)-(%d,%d)",
		captures, stage, mac.frames(), u16(pb + 4), st, sl, sb, sr))
	-- The renderer first copies into an intermediate GWorld and then to the
	-- screen.  Capture the latter: it records the exact translation boundary.
	if a24(u32(destination)) ~= 0x000A00 or stage_captured[stage] then return end
	stage_captured[stage] = true
	dump_pixmap("SRC", source)
	dump_pixmap("DST", destination)
	local row_bytes = u16(source + 4) & 0x3FFF
	local bt, _, bb, _ = rect(source + 6)
	dump_bytes(string.format("ref/mame/model-%s-pixels.raw", stage),
		a24(u32(source)), row_bytes * (bb - bt))
	if source_table ~= 0 then
		dump_bytes(string.format("ref/mame/model-%s-source.ctab", stage), source_table, 136)
	end
	if destination_table ~= 0 then
		dump_bytes(string.format("ref/mame/model-%s-destination.ctab", stage),
			destination_table, 136)
	end
	mac.shot()
end

local function on_trap()
	local sp = cpu.state["SP"].value
	local pc = u32(sp + 2)
	local trap = u16(pc)
	local pb = a24(sp + 8)                     -- 68020 exception frame is eight bytes
	if pending_selector_pixmap ~= 0 and trap == 0xA9BC then
		local pixmap = pending_selector_pixmap
		pending_selector_pixmap = 0
		local top, _, bottom, _ = rect(pixmap + 6)
		dump_bytes("ref/mame/selector-picture-gworld.raw", a24(u32(pixmap)),
			(u16(pixmap + 4) & 0x3FFF) * (bottom - top))
	end
	if trap == 0xA8EC then on_copybits(pb); return end
	if trap == 0xA97C then protection_prompt = true end -- GetNewDialog
	if trap == 0xA9BC then
		print(string.format("VP GetPicture frame=%u stage=%s id=%d",
			mac.frames(), stage, s16(u16(pb))))
		return
	end
	if trap == 0xA8F6 then
		local r = a24(u32(pb))
		local t, l, b, rr = rect(r)
		local device = main_device_pixmap()
		local table = device ~= 0 and ctab_address(device) or 0
		print(string.format("VP DrawPicture frame=%u stage=%s rect=(%d,%d)-(%d,%d) deviceSeed=%08X",
			mac.frames(), stage, t, l, b, rr, table ~= 0 and u32(table) or 0))
		if t == 0 and l == 0 and b == 322 and rr == 512 then
			local qd = a24(u32(a24(u32(0x0904))))
			local port = qd ~= 0 and a24(u32(qd)) or 0
			local pixmap_handle = port ~= 0 and a24(u32(port + 2)) or 0
			local pixmap = pixmap_handle ~= 0 and a24(u32(pixmap_handle)) or 0
			if pixmap ~= 0 then
				dump_pixmap("DRAWPICTURE-DST", pixmap)
				arm_mirror_writer(pixmap)
				pending_selector_pixmap = pixmap
			end
		end
		return
	end
	if trap == 0xAA92 then
		palette_calls = palette_calls + 1
		print(string.format("VP GetNewPalette #%u frame=%u id=%d", palette_calls,
			mac.frames(), s16(u16(pb))))
	elseif trap == 0xAA95 then
		palette_calls = palette_calls + 1
		local palette_handle = a24(u32(pb + 2))
		local window = a24(u32(pb + 6))
		palette_for_window[window] = palette_handle
		print(string.format("VP SetPalette #%u frame=%u stage=%s window=%06X update=%u",
			palette_calls, mac.frames(), stage, window, prog:read_u8(pb)))
		dump_palette("REQUEST", palette_handle)
	elseif trap == 0xAA94 then
		palette_calls = palette_calls + 1
		local window = a24(u32(pb))
		local pixmap_handle = window ~= 0 and a24(u32(window + 2)) or 0
		local pixmap = pixmap_handle ~= 0 and a24(u32(pixmap_handle)) or 0
		last_activate_window = window
		print(string.format("VP ActivatePalette #%u frame=%u stage=%s window=%06X",
			palette_calls, mac.frames(), stage, window))
		arm_mirror_writer(pixmap)
		if stage == "driving" and not driving_ports[window] then
			if pixmap ~= 0 and (u16(pixmap + 4) & 0x8000) ~= 0 and u16(pixmap + 32) == 4 then
				driving_ports[window] = true
				dump_pixmap(string.format("DRIVING-PORT-%06X", window), pixmap)
				local table = ctab_address(pixmap)
				if table ~= 0 then
					dump_bytes(string.format("ref/mame/driving-port-%06X.ctab", window), table, 136)
				end
			end
		end
	end
end

local function arm(address)
	dispatcher = address
	keep[#keep + 1] = prog:install_read_tap(address & ~3, (address & ~3) + 3,
		"model_palette_dispatch", function(_, data, _) on_trap(); return data end)
	print(string.format("VP armed Line-A dispatcher at %08X", address))
end

emu.register_frame_done(function()
	local address = u32(0x28)
	if address ~= dispatcher and address > 0x1000 then arm(address) end
	local pixmap = main_device_pixmap()
	local table = pixmap ~= 0 and ctab_address(pixmap) or 0
	if table ~= 0 then
		local seed = u32(table)
		if not device_seeds[seed] then
			device_seeds[seed] = true
			print(string.format("VP DEVICE TABLE frame=%u stage=%s seed=%08X",
				mac.frames(), stage, seed))
			dump_pixmap("DEVICE", pixmap)
			dump_bytes(string.format("ref/mame/device-%08X.ctab", seed), table, 136)
			if stage == "driving" and palette_for_window[last_activate_window] then
				dump_palette("ACTIVE-PALETTE", palette_for_window[last_activate_window])
			end
		end
		local device_handle = a24(u32(0x08A4))
		local device = device_handle ~= 0 and a24(u32(device_handle)) or 0
		local inverse_handle = device ~= 0 and a24(u32(device + 6)) or 0
		local inverse = inverse_handle ~= 0 and a24(u32(inverse_handle)) or 0
		if inverse ~= 0 and u32(inverse) == seed and not inverse_seeds[seed] then
			inverse_seeds[seed] = true
			dump_bytes(string.format("ref/mame/device-%08X.itab", seed), inverse, 4102)
		end
	end
end)

local function click(h, v, wait)
	mac.mouse_to(h, v); mac.click(1); mac.wait(wait or 180)
end

mac.run(function()
	if not mac.launch() then return end
	mac.wait(90)
	click(560, 400, 360)     -- first Button poll: leave the intro
	mac.step("after intro skip"); mac.shot()
	click(357, 252, 240)     -- garage ACCEPT
	mac.step("after garage accept"); mac.shot()
	stage = "porsche"
	click(477, 160, 600)     -- upper vehicle plate; retain a complete Porsche rotation
	mac.step("after upper plate"); mac.shot()
	mac.mouse_to(508, 215)
	stage = "f40"            -- label the state changed by this click, not its approach
	mac.click(1); mac.wait(480) -- F40 car image
	mac.step("after F40"); mac.shot()
	local screen = main_device_pixmap()
	if screen ~= 0 then
		local top, _, bottom, _ = rect(screen + 6)
		dump_bus_bytes("ref/mame/selector-f40-screen.raw", u32(screen),
			(u16(screen + 4) & 0x3FFF) * (bottom - top))
	end
	stage = "corvette"
	click(508, 247, 480)     -- Corvette ZR-1, matching VETTE_GARAGE_CLICK
	mac.step("after Corvette"); mac.shot()
	click(276, 245, 360)     -- vehicle selector ACCEPT
	mac.step("after vehicle accept"); mac.shot()
	click(509, 399, 180)     -- Course One ACCEPT; first drive opens copy protection
	stage = "driving"
	if protection_prompt then
		click(276, 284, 30)  -- focus the password edit field
		mac.type("16")       -- manual's copy-protection table: Chinatown has 16 blocks
		click(451, 284, 180) -- protection OK; the accepted course continues
	end
	-- Match the deterministic Amiga route.  Traffic+$51FE rejects shifts before
	-- countdown state 3, so wait for that original-game state, pulse top-row +
	-- until gear 1 is visible, and only then hold keypad 8.  The older stationary
	-- capture deliberately retains its neutral behavior.
	if driving_motion then
		local function car_address()
			local a5 = driving_a5
			return a5 ~= 0 and a24(u32(a5 - 0x3678)) or 0, a5
		end
		if not mac.wait_for("first complete driving frame", function()
			return driving_frame_ready
		end, 2400) then return end
		if not mac.wait_for("driving countdown state 3", function()
			local car, a5 = car_address()
			return car ~= 0 and s16(u16(a5 - 13296)) >= 3
		end, 1800) then return end
		-- The Amiga harness asserts accelerator in the same GetKeys refresh that
		-- first observes gear 1.  Have it waiting before the shift so MAME cannot
		-- lose one physics iteration to its once-per-video-frame Lua poll.
		mac.key_down("Keypad 8")
		-- GetKeys is sampled by the driving loop, not the Event Manager.  Keep the
		-- bit down until that scanner observes it; a short ADB press can begin and
		-- end while the slow renderer owns the CPU and is therefore not an input.
		mac.key_down("=  +")
		local shifted = mac.wait_for("gear 1", function()
			local car = car_address()
			return car ~= 0 and s16(u16(car + 0x1C)) == 1
		end, 600)
		mac.key_up("=  +")
		if not shifted then return end
	end
	mac.key_down("Keypad 8")
	driving_capture_armed = true
	arm_mirror_source_writer()
	mac.wait(driving_motion and 500 or 1200)
	mac.key_up("Keypad 8")
	mac.step("driving"); mac.shot()
	screen = main_device_pixmap()
	if screen ~= 0 then
		local top, _, bottom, _ = rect(screen + 6)
		local table = ctab_address(screen)
		dump_bus_bytes("ref/mame/driving-screen.raw", u32(screen),
			(u16(screen + 4) & 0x3FFF) * (bottom - top))
		if table ~= 0 then dump_bytes("ref/mame/driving-device.ctab", table, 136) end
	end
	print(string.format("VP model CopyBits captures=%u", captures))
	if driving_motion then manager.machine:exit() end
end)
