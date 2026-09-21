# Capture the first confirmed player/object hull collision in Freeway Map
# cell (6,36).  Traffic+$0202 receives the player in A3 and the other object
# in A2 after the bilateral COLL test.  Requires the Course Two FREEWAY_ROUTE.
set pagination off
set confirm off
set $hit = 0

break *(s_segments[6].begin+0x0202) if *(unsigned short*)($a3+0x3e) == 6 && *(unsigned short*)($a3+0x40) == 36
commands
  silent
  set $hit = 1
end
continue

if $hit
  printf "freeway x6 object collision tick=%u player=$%08x tag=$%08x world=($%08x,$%08x) local=(%u,%u) heading=%u speed=%d class=%u state=$%02x/$%02x/$%02x other=$%08x tag=$%08x world=($%08x,$%08x) local=(%u,%u) cell=(%u,%u) heading=%u class=%u group=%u state=$%02x/$%02x/$%02x vertex=%d\n", g_macTicks, $a3, *(unsigned int*)($a3+0x54), *(unsigned int*)$a3, *(unsigned int*)($a3+8), (*(unsigned int*)$a3)&0x7ff, (*(unsigned int*)($a3+8))&0x7ff, *(unsigned short*)($a3+0x66), *(signed short*)($a3+0x1a), *(unsigned char*)($a3+0x6d), *(unsigned char*)($a3+0x6a), *(unsigned char*)($a3+0x6b), *(unsigned char*)($a3+0x6c), $a2, *(unsigned int*)($a2+0x54), *(unsigned int*)$a2, *(unsigned int*)($a2+8), (*(unsigned int*)$a2)&0x7ff, (*(unsigned int*)($a2+8))&0x7ff, *(unsigned short*)($a2+0x3e), *(unsigned short*)($a2+0x40), *(unsigned short*)($a2+0x0e), *(unsigned char*)($a2+0x6d), *(unsigned char*)($a2+0x2a), *(unsigned char*)($a2+0x6a), *(unsigned char*)($a2+0x6b), *(unsigned char*)($a2+0x6c), *(signed short*)($a5-0x5104)
else
  printf "freeway x6 collision observer ceiling tick=%u\n", g_macTicks
end
detach
quit
