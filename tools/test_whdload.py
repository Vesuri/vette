#!/usr/bin/env python3
"""Run isolated WHDLoad tests and retain its own core dumps under tmp/.

Source amiga/env.sh first. ROMs and original data are local inputs, never shipped.
The quit mode requires a QUIT_PROBE=1 executable; timed mode runs production.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SHARE = Path.home()/'.local/share/amiga'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode', choices=('smoke', 'boot', 'load', 'quit', 'timed'), default='quit')
    p.add_argument('--whdload', type=Path, default=Path(os.environ.get('WHDLOAD_BINARY',
                   Path(os.environ.get('WHDLOAD', SHARE/'WHDLoad'))/'C/WHDLoad')))
    p.add_argument('--workbench', type=Path,
                   default=Path(os.environ.get('WORKBENCH_ADF', SHARE/'Workbenchv2.04rev37.67Workbench.adf')))
    p.add_argument('--rom', type=Path, default=SHARE/'Kickstarts/kick40063.A600')
    p.add_argument('--rtb', type=Path, default=SHARE/'Kickstarts/kick40063.A600.RTB')
    p.add_argument('--exe', type=Path, default=ROOT/'amiga/out/Vette.exe')
    p.add_argument('--seconds', type=int, default=90, help='host safety ceiling')
    p.add_argument('--ticks', type=int, default=1500, help='WHDLoad timeout in PAL fields')
    p.add_argument('--cpu', default='68020')
    p.add_argument('--setup', help='AmigaXDev AMIGA_SETUP machine, e.g. a1200-030 or a1200-040; replaces --cpu')
    p.add_argument('--no-mmu', action='store_true', help='with --setup, remove the preset CPU MMU')
    p.add_argument('--whdload-option', action='append', default=[], help='extra WHDLoad option, e.g. MMU')
    p.add_argument('--fsuae-option', action='append', default=[], metavar='KEY=VALUE',
                   help='with --setup, replace or add one FS-UAE option, e.g. uae_cpu_frequency=25000000')
    p.add_argument('--hires', action='store_true', help='enable the slave Custom1 HIRES option')
    p.add_argument('--no-preload', action='store_true')
    args = p.parse_args()
    if (args.no_mmu or args.fsuae_option) and not args.setup:
        p.error('--no-mmu and --fsuae-option require --setup')
    machine = setup_args(args.setup, args.no_mmu, args.fsuae_option) if args.setup else None
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
    options = ('' if args.no_preload else 'PRELOAD ') + ''.join(o + ' ' for o in args.whdload_option)
    (boot/'s/startup-sequence').write_text(
        'DF0:C/Assign C: DF0:C\nDF0:C/Assign LIBS: DF0:Libs\n'
        'DF0:C/Assign DEVS: DH0:devs\nStack 16384\nFailAt 999\n'
        f'CD DH1:\nWHDLoad Vette!.slave {options}CUSTOM1={int(args.hires)} SPLASHDELAY=0 NOREQ COREDUMP FILELOG TIMEOUT={args.ticks} >DH0:result\n'
        'If WARN\nEcho failed >DH0:failed\nElse\nEcho passed >DH0:passed\nEndIf\n')
    # amiga/env.sh selects AmigaXDev's native FS-UAE; its corrections, including the 040/060
    # MMU write attributes that copyback testing needs, are absent from the x86_64 one.
    emulator = os.environ.get('FSUAE') or os.environ.get('FSUAE_ARM') or str(SHARE/'fs-uae-arm/fs-uae')
    if machine is None:
        machine = ['--amiga_model=A1200', '--cpu='+args.cpu,
            '--uae_cpu_model='+args.cpu, '--uae_cpu_24bit_addressing=false',
            '--jit_compiler=0', '--chip_memory=2048', '--fast_memory=8192',
            '--kickstart_file='+os.environ.get('KICKSTART', str(SHARE/'Kickstarts/kick40063.A600'))]
    with (base/'emulator.log').open('w') as log:
        emu = subprocess.Popen([emulator, *machine, '--base_dir='+str(base/'fsuae'),
            '--hard_drive_0='+str(boot), '--hard_drive_0_priority=10', '--hard_drive_1='+str(game),
            '--floppy_drive_0='+str(args.workbench),
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
            if args.setup:
                check_machine(base, report, args.mode, machine)
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

def setup_args(name, no_mmu, overrides):
    """Return the shared launcher's preset arguments, so machines match AmigaXDev exactly."""
    common = os.environ.get('FSUAE_COMMON', str(SHARE/'fsuae_common.sh'))
    out = subprocess.run(['/bin/bash', '-c', '. "$1" && AMIGA_SETUP="$2" && fsuae_setup && '
                          'printf "%s\\0" "${FSUAE_SETUP_ARGS[@]}"', 'setup', common, name],
                         check=True, capture_output=True, text=True).stdout
    machine = out.split('\0')[:-1]
    if no_mmu:
        overrides = ['uae_mmu_model=0', *overrides]
    # Replace in place: FS-UAE can reapply a duplicated raw UAE option.
    for override in overrides:
        key = '--' + override.split('=', 1)[0] + '='
        machine = [a for a in machine if not a.startswith(key)] + ['--' + override]
    return machine

def check_machine(base, report, mode, machine):
    """Require the emulated CPU and MMU to be what the run claims, and the slave's caches."""
    option = dict(a[2:].split('=', 1) for a in machine)
    log = (base/'fsuae/Cache/Logs/fs-uae.log.txt').read_text(errors='replace')
    # As AmigaXDev scripts/test_fsuae_config.py: a UAE fixup logs "[UAE] [000] TEXT", then TEXT.
    lines = log.splitlines()
    fixups = [l for prev, l in zip([''] + lines, lines) if l.strip() and (prev == '[UAE] [000] ' + l
              or re.fullmatch(r'Unknown CPU specified|.* must be paired with .*', l))]
    assert not fixups, f'FS-UAE changed the configuration: {fixups}'
    cpu, mmu = option['cpu'], option['uae_mmu_model']
    runtime = re.findall(r'CPU=(\d+), FPU=\d+.*?MMU=(\d+), JIT=0', log)
    assert runtime and runtime[-1] == (re.sub(r'\D', '', cpu), mmu), f'Runtime CPU/MMU {runtime} != {cpu}/{mmu}'
    if mode == 'smoke':
        return
    # The last appended report is this run's.
    cacr = int(re.findall(r'CACR=([0-9A-F]+)', report)[-1], 16)
    tc = int(re.findall(r'\bTC=([0-9A-F]+)', report)[-1], 16) if mmu != '0' else 0
    print(f'Machine: {cpu} MMU={mmu} CACR={cacr:X} TC={tc:X}')
    # The slave enables both caches on a 68030/68040/68060 (the 68020 has no data cache).
    model = re.sub(r'\D', '', cpu)
    if model == '68020':
        assert cacr & 0x1, f'68020 instruction cache off: CACR={cacr:X}'
    elif model == '68030':
        assert cacr & 0x0101 == 0x0101, f'68030 instruction/data caches not both on: CACR={cacr:X}'
    else:
        assert cacr & 0x80008000 == 0x80008000, f'{cpu} expected both caches: CACR={cacr:X}'

if __name__ == '__main__':
    main()
