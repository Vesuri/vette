"""Generate an original, minimal classic Workbench project icon for Install."""
import struct

def installer_icon(game=False):
    # DiskObject: all pointers are presence markers in the serialized format.
    header=bytearray(78)
    struct.pack_into(">HH",header,0,0xe310,1)
    struct.pack_into(">hhhhHHH",header,8,0,0,32,24,5,1,1)
    struct.pack_into(">I",header,22,1)  # GadgetRender image
    header[48]=3 if game else 4       # WBTOOL / WBPROJECT
    struct.pack_into(">IIiiIII",header,50,0 if game else 1,0 if game else 1,-2147483648,-2147483648,0,0,4096)
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
    def string(s):
        data=s.encode("ascii")+b"\0"
        return struct.pack(">I",len(data))+data
    types=["APPNAME=Vette!","MINUSER=AVERAGE","DEFUSER=AVERAGE"]
    if game:
        return bytes(header)+image+planes
    return bytes(header)+image+planes+string("Installer")+struct.pack(">I",4*(len(types)+1))+b"".join(map(string,types))
