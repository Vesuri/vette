-- Drive Color VETTE! past its front end, to find out whether the copy-protection
-- password prompt appears at all on this copy.
--
-- ⚠ The prompt is documented (readme.txt: "asks for a password only once, upon
-- first running the program") but the garage screen came up without one, so the
-- question is whether the check fires LATER -- when a drive actually starts --
-- or whether this copy is already registered.  That is an empirical question and
-- this script is the experiment: click through to a drive and snapshot each step.
--
-- Coordinates are read off ref/mame/snap captures at 640x480, 16 colours.

local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")

local ACCEPT = { 357, 252 }    -- "ACCEPT" button on the garage screen

mac.run(function()
	mac.launch()
	mac.wait(1200)                             -- let the intro animation finish
	mac.mouse_to(560, 440); mac.shot(); mac.step("front end")

	mac.mouse_to(ACCEPT[1], ACCEPT[2]); mac.click(1)
	mac.wait(180); mac.shot(); mac.step("after ACCEPT")

	for i = 1, 8 do
		mac.wait(240)
		mac.step("accept+" .. (i * 4) .. "s"); mac.shot()
	end
end)
