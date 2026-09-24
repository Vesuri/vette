-- Snapshot helper for the Macintosh reference loop.
--
-- MAME takes no screenshot of its own when -seconds_to_run expires, so a headless
-- run that is supposed to PROVE something needs this: it writes a PNG into
-- -snapshot_directory at given frame counts.
--
--   VETTE_SNAP_FRAMES=900,1500 \
--   timeout -k 5 180 env SDL_VIDEODRIVER=dummy \
--     mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
--       -video none -sound none -window -skip_gameinfo -nothrottle \
--       -seconds_to_run 27 -snapshot_directory ref/mame/snap \
--       -autoboot_script tools/mame_snap.lua
--
-- Frames are 60/s of EMULATED time (the Mac II's own field rate), not wall clock;
-- -nothrottle runs ~10x faster than real time and does not change the count.
-- Default 900,1500 = ~15 s and ~25 s in, which is past the ROM's boot-device hunt.
--
-- WHY frame counts and not seconds: this is the only clock that is a ratio of
-- emulated quantities, so a capture stays reproducible across host speeds
-- (see docs/mac-reference-loop.md; FS-UAE warp also advances emulated time).

local frames = {}
local spec = os.getenv("VETTE_SNAP_FRAMES") or "900,1500"
for n in spec:gmatch("%d+") do frames[tonumber(n)] = true end

local n = 0
emu.register_frame_done(function()
	n = n + 1
	if frames[n] then manager.machine.video:snapshot() end
end)
