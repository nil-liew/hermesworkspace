#!/usr/bin/env python3
"""Generate SimpleVidPlayer app icon: rounded-rect dark cinema tile with a pastel play triangle."""
import subprocess, os, math, struct, zlib

SIZE = 1024
# Cinema Dark Mode palette: dark charcoal bg, soft amber play triangle (pastel)
BG_TOP = (34, 36, 46)
BG_BOT = (22, 23, 30)
AMBER = (255, 196, 128)
CORNER = 220  # macOS squircle-ish corner radius at 1024

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def inside_rounded_rect(x, y, w, h, r):
    if x < 0 or y < 0 or x >= w or y >= h:
        return False, 0.0
    # distance-based coverage for anti-aliasing
    cx = min(max(x, r), w - r)
    cy = min(max(y, r), h - r)
    dx = x - cx
    dy = y - cy
    d = math.hypot(dx, dy) if (abs(dx) > 0 or abs(dy) > 0) else 0
    if x < r or x >= w - r or y < r or y >= h - r:
        # in corner zone
        cov = max(0.0, min(1.0, r - d + 0.5))
        return cov > 0, cov
    return True, 1.0

def inside_triangle(px, py):
    """Play triangle centered slightly right of center."""
    cx, cy = SIZE * 0.54, SIZE * 0.5
    s = 300  # half-height of triangle
    # equilateral-ish play triangle pointing right
    p = [(cx - s * 0.75, cy - s), (cx - s * 0.75, cy + s), (cx + s * 1.15, cy)]
    def edge(a, b, x, y):
        return (x - b[0]) * (a[1] - b[1]) - (a[0] - b[0]) * (y - b[1])
    d1 = edge(p[0], p[1], px, py)
    d2 = edge(p[1], p[2], px, py)
    d3 = edge(p[2], p[0], px, py)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    inside = not (neg and pos)
    # signed distance approx for AA (use min distance to edges, crude but fine)
    return inside

rows = []
for y in range(SIZE):
    row = bytearray()
    row.append(0)  # filter byte
    for x in range(SIZE):
        ins, cov = inside_rounded_rect(x, y, SIZE, SIZE, CORNER)
        if not ins or cov <= 0:
            row += bytes([0, 0, 0, 0])
            continue
        t = y / SIZE
        col = lerp(BG_TOP, BG_BOT, t)
        # subtle inner glow near center
        d = math.hypot(x - SIZE/2, y - SIZE/2) / (SIZE/2)
        glow = max(0.0, 1.0 - d * 1.4) * 14
        col = tuple(min(255, int(c + glow)) for c in col)
        # amber triangle with soft edge
        margin = 6
        if inside_triangle(x, y):
            r, g, b, a = AMBER[0], AMBER[1], AMBER[2], int(255 * cov)
        elif any(inside_triangle(x+dx, y+dy) for dx in (-margin, 0, margin) for dy in (-margin, 0, margin)):
            # soft edge blend toward bg
            r, g, b = AMBER
            a = int(140 * cov)
        else:
            r, g, b = col
            a = int(255 * cov)
        row += bytes([r, g, b, a])
    rows.append(bytes(row))

raw = b''.join(rows)

def png_chunk(tag, data):
    c = struct.pack('>I', len(data)) + tag + data
    c += struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    return c

ihdr = struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0)
png = b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', ihdr) + png_chunk(b'IDAT', zlib.compress(raw, 9)) + png_chunk(b'IEND', b'')

out = '/Users/daddy/hermesworkspace/simplevidplayer/AppIcon_1024.png'
with open(out, 'wb') as f:
    f.write(png)
print('written', out, len(png))
