#!/usr/bin/env python3
"""Generate SimpleImgViewer icon based on reference design.
Dark background with light gold/cream geometric shapes."""
from PIL import Image, ImageDraw
import os, math

SIZE = 1024
ICONSET_DIR = '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.iconset'
os.makedirs(ICONSET_DIR, exist_ok=True)

# Colors from reference image analysis
BG_DARK = (48, 48, 48)        # Dark gray background
BG_MID = (32, 32, 48)         # Slightly blue-tinted dark
GOLD_LIGHT = (240, 208, 176)  # Warm cream/gold accent
GOLD_MID = (240, 192, 176)    # Mid gold
GOLD_DARK = (224, 192, 160)   # Darker gold

def create_geometric_icon(size):
    """Create icon with geometric design matching reference."""
    img = Image.new('RGBA', (size, size), (*BG_DARK, 255))
    draw = ImageDraw.Draw(img)
    
    cx, cy = size // 2, size // 2
    
    # Background gradient (subtle)
    for y in range(size):
        t = y / size
        r = int(BG_DARK[0] * (1 - t) + BG_MID[0] * t)
        g = int(BG_DARK[1] * (1 - t) + BG_MID[1] * t)
        b = int(BG_DARK[2] * (1 - t) + BG_MID[2] * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    
    # Main geometric structure: Large rounded rectangle with inner shapes
    margin = size // 8
    frame_size = size - margin * 2
    radius = size // 8
    
    # Outer frame
    draw.rounded_rectangle(
        [margin, margin, margin + frame_size, margin + frame_size],
        radius=radius,
        fill=None,
        outline=GOLD_LIGHT,
        width=size // 40
    )
    
    # Inner geometric shapes - create a stylized image/viewer look
    inner_margin = size // 16
    ix = margin + inner_margin
    iy = margin + inner_margin
    iw = frame_size - inner_margin * 2
    ih = frame_size - inner_margin * 2
    
    # Large circle in center
    circle_r = iw // 3
    draw.ellipse(
        [cx - circle_r, cy - circle_r, cx + circle_r, cy + circle_r],
        fill=GOLD_MID
    )
    
    # Smaller circles/accents
    small_r = circle_r // 3
    # Top-left accent
    draw.ellipse(
        [ix + small_r, iy + small_r, ix + small_r * 3, iy + small_r * 3],
        fill=GOLD_LIGHT
    )
    # Bottom-right accent
    draw.ellipse(
        [ix + iw - small_r * 3, iy + ih - small_r * 3,
         ix + iw - small_r, iy + ih - small_r],
        fill=GOLD_LIGHT
    )
    
    # Horizontal line accent
    line_y = iy + ih // 2
    line_width = iw // 4
    draw.rectangle(
        [cx - line_width, line_y, cx + line_width, line_y + size // 80],
        fill=GOLD_LIGHT
    )
    
    return img

# Generate icon
img = create_geometric_icon(SIZE)
img.save('/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon_1024.png', 'PNG')

# Generate all sizes
sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes:
    scaled = img.resize((s, s), resample=Image.LANCZOS)
    scaled.save(os.path.join(ICONSET_DIR, f'icon_{s}x{s}.png'), 'PNG')

# @2x versions
for s in [32, 64, 128, 256, 512, 1024]:
    orig = s // 2
    scaled = img.resize((s, s), resample=Image.LANCZOS)
    scaled.save(os.path.join(ICONSET_DIR, f'icon_{orig}x{orig}@2x.png'), 'PNG')

# Generate .icns
import subprocess
result = subprocess.run(
    ['iconutil', '-c', 'icns', ICONSET_DIR,
     '-o', '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.icns'],
    capture_output=True, text=True
)
print('Icon generation complete!')
if result.returncode != 0:
    print(f'Warning: {result.stderr}')
