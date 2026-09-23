# Verify the unchanged Shell/WHDLoad startup branch.  A CLI process must not
# wait for or remove a Workbench startup message from its Process port.
set pagination off
set confirm off

# diag_run.sh sources observers while stopped at MacLoader::run. Reaching this
# point already proves getWorkbenchStartupMessage did not wait on a CLI launch.
set $process = *(unsigned long *)((*(unsigned long *)0x4) + 276)
set $cli = *(unsigned long *)($process + 172)
set $empty = (*(unsigned long *)($process + 112) == ($process + 116))
if $cli != 0 && $empty == 1
  printf "workbench-startup PASS: CLI reached game pr_CLI=$%08x port-empty=%u\n", $cli, $empty
else
  printf "workbench-startup FAIL: CLI=$%08x port-empty=%u\n", $cli, $empty
end
detach
quit
