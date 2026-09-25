#!/usr/bin/env python3
"""Exercise the real Amiga Installer, supplying deterministic requester answers.

Requires a local Commodore Installer binary (not redistributed) and the original
game archive. Only the welcome/requester/message/exit forms are replaced; actual
helper execution, error handling and copy operations use release/Install.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools"))
from installer_icon import installer_icon, drawer_icon, readme_icon

def replace_form(text,start,replacement):
    a=text.index(start); depth=0; quoted=False; i=a
    while i<len(text):
        c=text[i]
        if quoted and c=='\\': i+=2; continue
        if c=='"': quoted=not quoted
        elif not quoted:
            if c=='(': depth+=1
            elif c==')':
                depth-=1
                if depth==0: return text[:a]+replacement+text[i+1:]
        i+=1
    raise ValueError("Unbalanced Installer form")

def main():
    installer=Path(sys.argv[1]).resolve()
    temp_path = 'RAM:' if '--ram-temp' in sys.argv else 'T:' if '--t-temp' in sys.argv else 'DH2:scratch'
    temp_work = temp_path + ('' if temp_path.endswith(':') else '/') + '.vette-install-00'
    fresh = '--fresh' in sys.argv
    remove = '--remove' in sys.argv
    reinstall = '--reinstall' in sys.argv
    install_data = fresh or remove or reinstall
    build=ROOT/"build/install-data"
    subprocess.run(["make","-C",str(ROOT/"tools/install-data"),"all","amiga"],check=True)
    subprocess.run(["m68k-amiga-elf-gcc","-O2","-m68000","-nostdlib","-Wno-volatile-register-var",
        "-Wl,--emit-relocs,-Ttext=0,-e,_start",str(ROOT/"tools/install-data/start.s"),
        str(ROOT/"tools/install-data/test_icon.c"),"-o",str(build/"test-icon.elf")],check=True)
    subprocess.run(["elf2hunk",str(build/"test-icon.elf"),str(build/"test-icon.exe"),"-s"],check=True)
    with tempfile.TemporaryDirectory(prefix="vette-installer-script-",dir=ROOT/"tmp") as temp:
        base=Path(temp); boot=base/"boot"; (boot/"s").mkdir(parents=True)
        (base/"state").mkdir(); dest=base/"out/Vette!"; (base/"out").mkdir()
        (base/"scratch").mkdir()
        # Seed the existing-install branches. Reinstall deliberately damages
        # both originals to prove that they are extracted again, not reused.
        if not fresh:
            (dest/"data").mkdir(parents=True)
            subprocess.run([str(build/"VetteInstallData"),str(ROOT/"tmp/VETTE__1.02_and_extras.sit"),str(dest/"data"),str(base/"scratch")],check=True)
            (dest/'keep-marker').write_text('old installation')
            (dest/'data/Vette.scores').write_bytes(b'saved scores')
            for name in ('data/Vette!', 'Vette!.slave', 'ReadMe'):
                (dest/name).write_bytes(b'old release')
            if reinstall:
                (dest/'data/Color VETTE!').write_bytes(b'damaged original')
                (dest/'data/VETTE!.Data').write_bytes(b'damaged original')
        (base/'out/other-drawer').mkdir()
        (base/'out/other-drawer/keep').write_text('unrelated')
        for source,name in ((installer,"Installer"),(build/"VetteInstallData.exe","VetteInstallData"),
                (build/"test-icon.exe","IconTest"),(ROOT/"amiga/out/Vette.exe","Vette!"),
                (ROOT/"build/whdload/Vette!.slave","Vette!.slave"),
                (Path.home()/".local/share/amiga/WHDLoad/C/WHDLoad","WHDLoad"),
                (ROOT/"release/ReadMe","ReadMe"),
                (ROOT/"tools/install-data/COPYING.LIB","LICENSE.LGPL.txt")):
            shutil.copyfile(source,boot/name)
        (boot/"devs/Kickstarts").mkdir(parents=True)
        for source in (Path.home()/"Documents/RetroPie/BIOS/kick40063.A600",
                Path.home()/"Documents/amiberry/whdboot/save-data/Kickstarts/kick40063.A600.RTB"):
            shutil.copyfile(source,boot/"devs/Kickstarts"/source.name)
        script=(ROOT/"release/Install").read_text()
        # Installer detects welcome syntactically. Omitting it would cause an
        # automatic startup requester; retain it in an unexecuted branch.
        script=replace_form(script,"(welcome)",'(if 0 (welcome))')
        script=replace_form(script,"(set #remove-existing",
            f'((textfile (dest "DH2:remove-choice") (append "asked")) (set #remove-existing {int(remove)}))')
        script=replace_form(script,"(set #install-data\n    (askbool",
            f'((textfile (dest "DH2:data-choice") (append "asked")) (set #install-data {int(reinstall)}))')
        script=replace_form(script,"(set #archive",'(set #archive "DH1:tmp/VETTE__1.02_and_extras.sit")')
        script=replace_form(script,"(set #parent",'(set #parent "DH2:out")')
        script=replace_form(script,"(set #temp",f'(set #temp "{temp_path}")')
        script=script.replace('(while (< (P_TempSpace)', '(textfile (dest "DH2:space.txt") (append ("device=%s disk=%ld usable=%ld memory=%s" (getdevice #temp) (getdiskspace #temp) (P_TempSpace) (database "total-mem"))))\n(while (< (P_TempSpace)')
        script=replace_form(script,"(exit)",'(exit (quiet))')
        (boot/"Install").write_text(script); (boot/"Install.info").write_bytes(installer_icon())
        (boot/"Vette!.inf").write_bytes(installer_icon(game=True))
        (boot/"GameTemplate.info").write_bytes(installer_icon(game=True))
        (boot/"ReadMe.info").write_bytes(readme_icon())
        (boot/"Package").mkdir()
        (boot/"Package.info").write_bytes(drawer_icon())
        (boot/"s/startup-sequence").write_text('CD DH0:\nStack 16384\nIconTest\nDF0:C/Assign C: DF0:C\nDF0:C/Assign LIBS: DF0:Libs\nDF0:C/Assign DEVS: DH0:devs\nPath DH0: ADD\nC:LoadWB\nInstaller SCRIPT DH0:Install APPNAME Vette! MINUSER NOVICE DEFUSER NOVICE LOGFILE DH2:installer.log NOPRETEND >DH2:installer-console.log\n'
            + f'IconTest\nIf EXISTS "{temp_work}"\nEcho leftover >DH2:leftover\nEndIf\nEcho done >DH2:finished\n')
        with (ROOT/"tmp/installer-script-emulator.log").open("w") as log:
            emu=subprocess.Popen(["fs-uae","--amiga_model=A1200/020","--chip_memory=2048","--fast_memory=8192",
                "--uae_cpu_model=68020","--uae_cpu_24bit_addressing=false","--uae_z3mem_size=16",
                "--kickstart_file="+os.environ["KICKSTART"],"--hard_drive_0="+str(boot),
                "--hard_drive_0_priority=10","--floppy_drive_0="+str(ROOT/"tmp/Workbenchv2.04rev37.67Workbench.adf"),
                "--hard_drive_1="+str(ROOT),"--hard_drive_2="+str(base),"--warp_mode=1",
                "--fullscreen=0","--window_width=720","--window_height=568","--state_dir="+str(base/"state")],stdout=log,stderr=log)
            try:
                deadline=time.monotonic()+(900 if install_data else 240)
                while time.monotonic()<deadline and not (base/"finished").exists():
                    if emu.poll() is not None: raise RuntimeError("Emulator exited")
                    time.sleep(.5)
                report=(base/"installer.log").read_text(errors="replace") if (base/"installer.log").exists() else "No Installer transcript"
                if (base/"installer-console.log").exists(): report+='\n'+(base/"installer-console.log").read_text(errors="replace")
                if (base/"finished").exists(): report+='\nReturn: '+(base/"finished").read_text(errors="replace")
                if (base/"space.txt").exists(): report+='\n'+(base/"space.txt").read_text(errors="replace")
                (ROOT/"tmp/installer-script.log").write_text(report)
                assert (base/"icon-ok").exists(), "icon.library rejected the generated icon"
                assert (base/"finished").exists(), report
                assert not (base/"leftover").exists(), "Guest scratch directory was not removed"
                assert (base/'remove-choice').exists() == (not fresh), 'Wrong remove prompt path'
                assert (base/'data-choice').exists() == (not fresh and not remove), 'Wrong data prompt path'
                assert (base/"space.txt").exists() == install_data, 'Temporary drawer prompt was not conditional'
                assert (base/'out/other-drawer/keep').read_text() == 'unrelated'
                assert (dest/'keep-marker').exists() == (not fresh and not remove)
                if not fresh and not remove:
                    assert (dest/'data/Vette.scores').read_bytes() == b'saved scores'
                else:
                    assert not (dest/'data/Vette.scores').exists()
                if install_data and temp_path in ('RAM:', 'T:'):
                    space=(base/"space.txt").read_text()
                    assert 'device=RAM disk=0' in space,space
                    assert int(space.split('usable=')[1].split()[0])>=12582912,space
                assert (dest/"data/Vette!").read_bytes()==(boot/"Vette!").read_bytes(), report
                assert (dest/"Vette!.slave").read_bytes()==(boot/"Vette!.slave").read_bytes(), report
                assert (dest/"Vette!.info").exists(),report
                assert (base/"installed-icon-ok").exists(), "Installed WHDLoad icon failed native validation"
                assert dest.with_suffix(".info").exists(),report
                assert (dest/"ReadMe").read_bytes()==(boot/"ReadMe").read_bytes(), report
                assert (dest/"ReadMe.info").read_bytes()==(boot/"ReadMe.info").read_bytes(), report
                assert not (dest/"LICENSE.LGPL.txt").exists(), report
                assert not (dest/"LICENSE.LGPL.txt.info").exists(), report
                from test_install import EXPECTED
                import hashlib
                for name, digest in EXPECTED.items():
                    assert hashlib.sha256((dest/"data"/name).read_bytes()).hexdigest()==digest
                assert not list((base/"scratch").glob(".vette-install-*"))
                assert not list((base/"scratch").glob(".vette-data-*"))
                assert not list((dest/"data").glob(".vette-publish-*"))
                print(f"PASS: native Installer fresh={fresh} remove={remove} reinstall={reinstall}; conditional prompts, data, scores, release files and icons verified")
            finally:
                emu.terminate()
                try: emu.wait(timeout=5)
                except subprocess.TimeoutExpired: emu.kill(); emu.wait()

if __name__=="__main__": main()
