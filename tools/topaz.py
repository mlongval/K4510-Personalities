# topaz.py ROM OUT: the Amiga's Topaz 8 out of a Kickstart ROM, as 256
# characters of 8 bytes (a row a byte, the left pixel the top bit; 0-31
# blank), for the A1200's sidebar.  Found the way the ROM itself has it: the
# TextFont whose name is "topaz.font" and whose size is 8x8.
import struct, sys
r = open(sys.argv[1], 'rb').read(); base = 0x1000000 - len(r)
out = bytearray(256 * 8)
i = -1
while True:
    i = r.find(b'topaz.font\0', i + 1)
    if i < 0: sys.exit('topaz.py: no Topaz 8 in this ROM')
    p = struct.pack('>I', base + i); j = -1
    while True:
        j = r.find(p, j + 1)
        if j < 0: break
        s = j - 10                                       # ln_Name is at 10 in the TextFont
        ys, _, _, xs = struct.unpack('>HBBH', r[s + 20:s + 26])
        lo, hi = r[s + 32], r[s + 33]
        if (ys, xs) != (8, 8) or lo > hi: continue
        data, mod, loc = struct.unpack('>IHI', r[s + 34:s + 44])
        data -= base; loc -= base
        for c in range(lo, hi + 1):
            off, w = struct.unpack('>HH', r[loc + (c - lo) * 4:loc + (c - lo) * 4 + 4])
            for y in range(8):
                row = 0
                for x in range(min(w, 8)):
                    b = off + x
                    if r[data + y * mod + b // 8] & (0x80 >> (b % 8)): row |= 0x80 >> x
                out[c * 8 + y] = row
        open(sys.argv[2], 'wb').write(out)
        sys.exit(0)
