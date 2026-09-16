-- Boot the reference volume and launch Color VETTE! with no window and no human.
-- The launch itself lives in the library (mac.launch); this driver only adds the
-- periodic snapshots that show what the game does once it owns the screen.

local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")

mac.run(function()
	mac.launch()
	mac.mouse_to(560, 440)                        -- park the cursor off the action
	mac.shot()

	for i = 1, 4 do
		mac.wait(300)
		mac.step("+" .. (i * 5) .. "s"); mac.shot()
	end
end)
