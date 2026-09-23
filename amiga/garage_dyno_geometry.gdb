# Capture the repeated dynamometer CopyBits geometry after its setup.
# Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_DYNO=1.
set pagination off
set confirm off

tbreak *s_segments[2].begin+0x0e62
commands
  silent
  printf "dyno alternating source A: "
  x/4hd $a5-0x546e
  printf "dyno alternating source B: "
  x/4hd $a5-0x5466
  printf "dyno alternating destination: "
  x/4hd $a5-0x545e
  printf "dyno gauge source: "
  x/4hd $a5-0x54c6
  printf "dyno gauge destination: "
  x/4hd $a5-0x54be
  printf "screen port / work port: %08x %08x\n", *(unsigned int*)($a5-0x7a12), *(unsigned int*)($a5-0x5b14)
  detach
  quit
end

continue
