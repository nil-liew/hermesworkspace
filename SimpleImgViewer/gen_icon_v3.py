#!/usr/bin/env python3
"""Generate SimpleImgViewer icon with new design and palette."""
from PIL import Image, ImageDraw
import os, math

SIZE = 1024
ICONSET_DIR = '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.iconset'
os.makedirs(ICONSET_DIR, exist_ok=True)

BG_DARK = (8, 8, 18)
GOLD = (200, 160, 80)
ORANGE = (255, 128, 0)

def draw_v3(size, color):
    """Cleaner, more abstract geometric design."""
    img = Image.new('RGBA', (size, size), (*BG_DARK, 255))
    draw = ImageDraw.Draw(img)
    
    # Main shape: A large, slightly rounded square with a geometric cutout or overlay
    main_size = int(size * 0.6)
    margin = (size - main_size) // 2
    radius = int(size * 0.08)
    
    # Draw the main frame
    draw.rounded_rectangle(
        [margin, margin, margin + main_size, margin + main_size],
        radius=radius,
        fill=None,
        outline=color,
        width=int(size * 0.025)
    )
    
    # Inner abstract representation
    # Option A: Landscape/Mountain silhouette
    # Option B: Grid of smaller frames (since it's an image viewer)
    
    # Let's do a stylized landscape inside the frame
    inner_margin = int(size * 0.08)
    ix = margin + inner_margin
    iy = margin + inner_margin
    iw = main_size - inner_margin * 2
    ih = main_size - inner_margin * 2
    
    # Mountain shape
    points = [
        (ix, iy + ih),
        (ix + iw // 4, iy + ih // 2),
        (ix + iw // 2, iy + ih // 3),
        (ix + 3 * iw // 4, iy + ih // 2),
        (ix + iw, iy + ih)
    ]
    draw.polygon(points, fill=color)
    
    # Sun/Moon in corner
    sun_r = int(iw // 8)
    sun_x = ix + iw - sun_r
    sun_y = iy + ih - sun_r
    draw.ellipse([sun_x - sun_r, sun_y - sun_r, sun_x + sun_r, sun_y + sun_r], fill=color)
    
    return img

# Generate
img = draw_v3(SIZE, GOLD)
img.save('/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon_1024.png', 'PNG')

# Generate standard sizes
sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes:
    scaled = img.resize((s, s), Image.LANCZOS)
    scaled.save(os.path.join(ICONSET_DIR, f'icon_{s}x{s}.png'), 'PNG')

# Also @2x
for s in [32, 64, 128, 256, 512, 1024]:
    orig = s // 2
    scaled = img.resize((s, s), Image.LANCZOS)
    scaled.save(os.path.join(ICONSET_DIR, f'icon_{orig}x{orig}@2x.png'), 'PNG')

print('Generated icons.')
