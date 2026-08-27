#!/usr/bin/env python3
"""Generate SimpleImgViewer icon with geometric design - Orange + Dark Blue."""
from PIL import Image, ImageDraw
import os, math

SIZE = 1024
ICONSET_DIR = '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.iconset'
os.makedirs(ICONSET_DIR, exist_ok=True)

# Color Palette
BG_DARK = (8, 8, 18)      # Deep dark blue
GOLD = (200, 160, 80)     # Gold/Amber
ORANGE = (255, 128, 0)    # Bright orange

def draw_image_viewer_icon(size, primary_color, secondary_color):
    """Create a clean geometric icon for an image viewer."""
    img = Image.new('RGBA', (size, size), (*BG_DARK, 255))
    draw = ImageDraw.Draw(img)
    
    cx, cy = size // 2, size // 2
    
    # Main rounded square frame
    frame_size = int(size * 0.7)
    frame_margin = (size - frame_size) // 2
    frame_radius = int(size * 0.1)
    
    # Draw frame outline
    draw.rounded_rectangle(
        [frame_margin, frame_margin, frame_margin + frame_size, frame_margin + frame_size],
        radius=frame_radius,
        fill=None,
        outline=primary_color,
        width=int(size * 0.02)
    )
    
    # Inner landscape/scene
    inner_margin = int(size * 0.12)
    ix = frame_margin + inner_margin
    iy = frame_margin + inner_margin
    iw = frame_size - inner_margin * 2
    ih = frame_size - inner_margin * 2
    
    # Mountain silhouette
    mountain_points = []
    segments = 20
    for i in range(segments + 1):
        x = ix + (iw * i / segments)
        # Sine wave mountain
        peak_height = ih * 0.4 * (0.5 + 0.5 * math.sin((i / segments) * math.pi * 3))
        y = iy + ih - peak_height
        mountain_points.append((x, y))
    
    mountain_points.append((ix + iw, iy + ih))
    mountain_points.append((ix, iy + ih))
    draw.polygon(mountain_points, fill=secondary_color)
    
    # Sun/Moon
    sun_x = ix + iw // 3
    sun_y = iy + ih // 4
    sun_r = int(iw // 8)
    draw.ellipse([sun_x - sun_r, sun_y - sun_r, sun_x + sun_r, sun_y + sun_r], 
                fill=primary_color)
    
    # Subtle corner accents
    accent_size = int(size * 0.05)
    # Top-left
    draw.rectangle([frame_margin + 10, frame_margin + 10, 
                   frame_margin + 10 + accent_size, frame_margin + 10 + accent_size],
                  fill=primary_color)
    # Bottom-right
    draw.rectangle([frame_margin + frame_size - 10 - accent_size, 
                   frame_margin + frame_size - 10 - accent_size,
                   frame_margin + frame_size - 10,
                   frame_margin + frame_size - 10],
                  fill=primary_color)
    
    return img

# Generate icon with Gold primary and Orange secondary (or vice versa)
img = draw_image_viewer_icon(SIZE, GOLD, ORANGE)
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
