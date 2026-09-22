# Prove the original garage index-4 dynamometer path from its real mouse
# control through its fixed animation and common garage-loop return.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_DYNO=1.
set pagination off
set confirm off
# Common post-control tail: the dynamometer has restored its backing images
# and is returning to the ordinary garage event pump.  GARAGE_DYNO supplies
# no other control click, so its first arrival here is the complete index-4
# branch.  Keep this a single breakpoint: some FS-UAE versions leave the CPU
# trace bit set when continuing from a resident CODE software breakpoint.
break *vette_code_2+0x14d8
commands 1
  silent
  printf "garage dynamometer return tick=%u mode=%d car=%d gauge=%d phase=%d result=$%08x\n", g_macTicks, *(signed short*)($a5-21546), *(signed short*)($a5-21810), *(signed short*)($a5-21696), *(signed short*)($a5-21562), *(unsigned int*)($a5-23116)
  detach
  quit
end

continue
