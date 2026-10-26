#!/usr/bin/env python3
"""Generate SimpleImgViewer app icon from attached PNG."""
from PIL import Image, ImageDraw
import os, math

SIZE = 1024
ICONSET_DIR = '/Users/daddy/hermesworkspace/simpleimgviewer/AppIcon.iconset'
os.makedirs(ICONSET_DIR, exist_ok=True)

# Load source image and resize to 1024
source = Image.open('/Users/daddy/hermesworkspace/simpleimgviewer/new_icon_source.png')
img = source.resize((SIZE, SIZE), resample=Image.LANCZOS)

# Draw the icon onto a canvas
canvas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
canvas.paste(img, (0, 0))

# Save 1024x1024
canvas.save('/Users/daddy/hermesworkspace/simpleimgviewer/AppIcon_1024.png', 'PNG')

# Generate all required icon sizes
sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes:
    scaled = canvas.resize((s, s), resample=Image.LANCZOS)
    scaled.save(os.path.join(ICONSET_DIR, f'icon_{s}x{s}.png'), 'PNG')

# @2x versions
for s in [32, 64, 128, 256, 512, 1024]:
    orig = s // 2
    scaled = canvas.resize((s, s), resample=Image.LANCZOS)
    scaled.save(os.path.join(ICONSET_DIR, f'icon_{orig}x{orig}@2x.png'), 'PNG')

# Generate .icns
import subprocess
result = subprocess.run(
    ['iconutil', '-c', 'icns', ICONSET_DIR,
     '-o', '/Users/daddy/hermesworkspace/simpleimgviewer/AppIcon.icns'],
    capture_output=True, text=True
)
print('Icon generation complete!')
if result.returncode != 0:
    print(f'Warning: {result.stderr}')
else:
    print('Created AppIcon.icns')
