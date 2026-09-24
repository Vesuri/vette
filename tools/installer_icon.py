"""Reuse release icons and generate the WHDLoad game project icon."""
import struct
import base64
from pathlib import Path

def template_icon(name):
    return base64.b64decode((Path(__file__).resolve().parents[1] / 'release/icons' / name).read_bytes())

def drawer_icon():
    return template_icon('drawer.info.b64')

def install_project_icon():
    data = template_icon('install.info.b64')
    old = b'APPNAME=Rescue on Fractalus!\0'
    new = b'APPNAME=Vette!\0'
    field = struct.pack('>I', len(old)) + old
    assert data.count(field) == 1
    # Preserve both the classic image and the trailing ColorIcon FORM, as well
    # as Installer/LOG=FALSE/PRETEND=FALSE/MINUSER=AVERAGE from the source icon.
    # DEFUSER defaults to MINUSER, per Installer 43.3 documentation.
    return data.replace(field, struct.pack('>I', len(new)) + new)

def installer_icon(game=False):
    if not game:
        return install_project_icon()
    # DiskObject: all pointers are presence markers in the serialized format.
    header=bytearray(78)
    struct.pack_into(">HH",header,0,0xe310,1)
    struct.pack_into(">hhhhHHH",header,8,0,0,32,24,5,1,1)
    struct.pack_into(">I",header,22,1)  # GadgetRender image
    header[48]=4                     # WBPROJECT: opened by WHDLoad
    struct.pack_into(">IIiiIII",header,50,1,1,-2147483648,-2147483648,0,0,10240)
    image=struct.pack(">hhhhhIBBI",0,0,32,24,2,1,3,0,0)
    pixels=[[0]*32 for _ in range(24)]
    # A disk with an arrow pointing into it; standard Workbench four pens.
    for y in range(3,22):
        for x in range(5,27):
            pixels[y][x]=1 if x in (5,26) or y in (3,21) else 2
    for y in range(4,10):
        for x in range(9,23): pixels[y][x]=1 if x in (9,22) or y==9 else 0
    for y in range(13,20):
        for x in range(9,23): pixels[y][x]=0
    for y in range(10,16):
        for x in range(14,18): pixels[y][x]=3
    for y in range(15,20):
        for x in range(11+y-15,21-(y-15)): pixels[y][x]=3
    planes=bytearray()
    for plane in range(2):
        for row in pixels:
            value=0
            for p in row: value=(value<<1)|((p>>plane)&1)
            planes.extend(struct.pack(">I",value))
    def string(value):
        raw=value.encode('ascii')+b'\0'
        return struct.pack('>I',len(raw))+raw
    tooltypes=('SLAVE=Vette.slave','PRELOAD')
    return (bytes(header)+image+planes+string('WHDLoad')
        +struct.pack('>I',4*(len(tooltypes)+1))
        +b''.join(string(t) for t in tooltypes))
