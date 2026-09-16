-- One-time setup: switch the reference machine's screen to 16 COLOURS.
--
-- ⭐⭐ Why 16: `Color VETTE!` REFUSES TO RUN otherwise -- it puts up "Please change
-- your Monitors setting in the Control Panel to 16 colors." and quits.  That is the
-- game itself stating the depth the port has to match (4 bitplanes), which is
-- stronger evidence than the `pltt` resource inference it replaces.
--
-- The setting lives in PRAM, which MAME keeps in its `nvram/` directory, so this
-- has to be done once per nvram -- not once per run.  ⚠ Verify it stuck by looking
-- at a snapshot from a LATER run, not from this one.
--
-- Coordinates: Apple menu (14,7) > Control Panel (item y=139); the cdev list's
-- scroll-down arrow (177,287) x8 brings Monitors to the top (133,80); then the
-- "Colors:" radio (201,98) and "16" in the depth list (265,108); close box (107,46).

local mac = dofile(os.getenv("VETTE_MAC_LIB") or "tools/mame_mac_input.lua")

mac.run(function()
	mac.wait_for("Finder", function() return mac.frontmost() == "Finder" end, 3600)
	mac.wait(240)

	mac.menu(14, 139)                       -- Apple > Control Panel
	mac.wait(420)
	mac.mouse_to(177, 287)                  -- scroll the cdev list to Monitors
	for _ = 1, 8 do mac.click(1); mac.wait(20) end
	mac.mouse_to(133, 80); mac.click(1)
	mac.wait(240)

	mac.mouse_to(201, 98);  mac.click(1)    -- "Colors:" rather than "Grays:"
	mac.wait(60)
	mac.mouse_to(265, 108); mac.click(1)    -- 16
	mac.wait(180)
	mac.shot()

	mac.mouse_to(107, 46);  mac.click(1)    -- close the Control Panel
	mac.wait(180)
	mac.shot()
	print("VP 16-colour setup done, front=" .. tostring(mac.frontmost()))

	mac.menu(200, 121)                      -- Special > Shut Down: flush PRAM + volume
	mac.wait(600)
	print("VP shut down issued")
end)
