"""Reuse WHDLoad/Rescue on Fractalus icon artwork without redrawing it."""
import struct
import base64
from pathlib import Path

def template_icon(name):
    return base64.b64decode((Path(__file__).resolve().parents[1] / 'release/icons' / name).read_bytes())

def drawer_icon():
    return template_icon('drawer.info.b64')

def readme_icon():
    return template_icon('readme.info.b64')

def installer_icon(game=False):
    if game:
        # Distributed as Vette.inf, renamed and configured by Installer, exactly
        # as RoF.inf in the reference package. No synthetic replacement artwork.
        return template_icon('game.inf.b64')
    data = template_icon('install.info.b64')
    old = b'APPNAME=Rescue on Fractalus!\0'
    new = b'APPNAME=Vette!\0'
    field = struct.pack('>I', len(old)) + old
    assert data.count(field) == 1
    return data.replace(field, struct.pack('>I', len(new)) + new)
