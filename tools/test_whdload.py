#!/usr/bin/env python3
"""Run isolated WHDLoad tests and retain its own core dumps under tmp/.

Source amiga/env.sh first. ROMs and original data are local inputs, never shipped.
The quit mode requires a QUIT_PROBE=1 executable; timed mode runs production.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode', choices=('smoke', 'boot', 'load', 'quit', 'timed'), default='quit')
    p.add_argument('--whdload', type=Path, default=Path.home()/'.local/share/amiga/WHDLoad/C/WHDLoad')
    p.add_argument('--rom', type=Path)
    p.add_argument('--rtb', type=Path)
    p.add_argument('--exe', type=Path, default=ROOT/'amiga/out/Vette.exe')
    p.add_argument('--seconds', type=int, default=90, help='host safety ceiling')
    p.add_argument('--ticks', type=int, default=1500, help='WHDLoad timeout in PAL fields')
    p.add_argument('--cpu', default='68020')
    p.add_argument('--hires', action='store_true', help='enable the slave Custom1 HIRES option')
    p.add_argument('--no-preload', action='store_true')
    args = p.parse_args()
    if args.mode != 'smoke' and (not args.rom or not args.rtb):
        p.error('--rom and --rtb are required except for smoke mode')
    slave = {'smoke':'Smoke.slave', 'boot':'BootTest.slave', 'load':'LoadTest.slave'}.get(args.mode, 'Vette!.slave')
    base = Path(tempfile.mkdtemp(prefix='whdload-test-', dir=ROOT/'tmp'))
    print('Fixture:', base, flush=True)
    boot, game = base/'boot', base/'game'
    for d in (boot/'s', boot/'devs/Kickstarts', game/'data', base/'state'):
        d.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.whdload, game/'WHDLoad')
    shutil.copyfile(ROOT/'build/whdload'/slave, game/'Vette!.slave')
    if args.mode != 'smoke':
        shutil.copyfile(args.rom, boot/'devs/Kickstarts'/args.rom.name)
        shutil.copyfile(args.rtb, boot/'devs/Kickstarts'/(args.rom.name+'.RTB'))
    if args.mode in ('load', 'quit', 'timed'):
        shutil.copyfile(args.exe, game/'data/Vette!')
    if args.mode in ('quit', 'timed'):
        subprocess.run(['bash', '-c', '. ./stage_original_data.sh; stage_vette_original_data "$1"',
                        'stage', str(game/'data')], cwd=ROOT/'amiga', check=True)
    (boot/'s/WHDLoad.prefs').write_text('Expert\nReadDelay=0\n')
    preload = '' if args.no_preload else 'PRELOAD '
    (boot/'s/startup-sequence').write_text(
        'DF0:C/Assign C: DF0:C\nDF0:C/Assign LIBS: DF0:Libs\n'
        'DF0:C/Assign DEVS: DH0:devs\nStack 16384\nFailAt 999\n'
        f'CD DH1:\nWHDLoad Vette!.slave {preload}CUSTOM1={int(args.hires)} SPLASHDELAY=0 NOREQ COREDUMP FILELOG TIMEOUT={args.ticks} >DH0:result\n'
        'If WARN\nEcho failed >DH0:failed\nElse\nEcho passed >DH0:passed\nEndIf\n')
    with (base/'emulator.log').open('w') as log:
        emu = subprocess.Popen(['fs-uae', '--amiga_model=A1200', '--cpu='+args.cpu,
            '--uae_cpu_model='+args.cpu, '--uae_cpu_24bit_addressing=false',
            '--jit_compiler=0', '--chip_memory=2048', '--fast_memory=8192',
            '--kickstart_file='+os.environ['KICKSTART'],
            '--hard_drive_0='+str(boot), '--hard_drive_0_priority=10', '--hard_drive_1='+str(game),
            '--floppy_drive_0='+str(ROOT/'tmp/Workbenchv2.04rev37.67Workbench.adf'),
            '--joystick_port_0=mouse', '--joystick_port_1=nothing', '--warp_mode=1', '--fullscreen=0',
            '--window_width=720', '--window_height=568', '--state_dir='+str(base/'state')], stdout=log, stderr=log)
        try:
            deadline = time.monotonic()+args.seconds
            while time.monotonic()<deadline and not any((boot/n).exists() for n in ('passed','failed')):
                if emu.poll() is not None:
                    raise RuntimeError('FS-UAE exited unexpectedly')
                time.sleep(.25)
            output = (boot/'result').read_text(errors='replace') if (boot/'result').exists() else ''
            report = (game/'.whdl_register').read_text(encoding='latin1') if (game/'.whdl_register').exists() else ''
            assert report, f'No WHDLoad core dump: {base}\n{output}'
            if args.mode == 'timed':
                assert 'DEBUG caused.' in report, report + output
                files = (game/'.whdl_log').read_text(encoding='latin1')
                for name in ('Color VETTE!', 'VETTE!.Data'):
                    assert any('[ReadOff]' in line and 'name='+name in line for line in files.splitlines()), files
                memory = (game/'.whdl_expmem').read_bytes()
                magic = b'VET!HIRE'
                assert memory.count(magic) == 1, 'Expected one loaded HIRES block'
                offset = memory.index(magic) + len(magic)
                assert memory[offset:offset+4] == bytes((0, int(args.hires), 0, 0)), 'HIRES word was not patched'
                print(f'PASS: timed run loaded both originals; HIRES={int(args.hires)} startup word verified')
            else:
                assert (boot/'passed').exists() and 'Return OK.' in report, report + output
                if args.mode == 'smoke':
                    assert (game/'smoke-passed').read_bytes() == b'PASS'
                print(f'PASS: {args.mode} slave returned normally; WHDLoad core saved')
        finally:
            emu.terminate()
            try: emu.wait(timeout=5)
            except subprocess.TimeoutExpired: emu.kill(); emu.wait()

if __name__ == '__main__':
    main()
