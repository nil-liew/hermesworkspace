#!/usr/bin/env python3
"""Generate SimpleImgViewer icon: overlapping photo frames with landscape scenes."""
from PIL import Image, ImageDraw, ImageFilter
import os

SIZE = 1024
# Colors matching SimpleVidPlayer style
BG_TOP = (34, 36, 46)
BG_BOT = (22, 23, 30)
GOLD = (200, 160, 80)
GOLD_LIGHT = (230, 190, 110)
GOLD_DARK = (150, 120, 60)

def create_icon():
    img = Image.new('RGBA', (SIZE, SIZE), (*BG_TOP, 255))
    draw = ImageDraw.Draw(img)
    
    # Background gradient
    for y in range(SIZE):
        t = y / SIZE
        r = int(BG_TOP[0] * (1 - t) + BG_BOT[0] * t)
        g = int(BG_TOP[1] * (1 - t) + BG_BOT[1] * t)
        b = int(BG_TOP[2] * (1 - t) + BG_BOT[2] * t)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))
    
    center = SIZE // 2
    frame_size = SIZE // 4
    gap = SIZE // 20
    
    # Helper to draw rounded rect
    def rounded_rect(x, y, w, h, radius, fill=None, outline=None, width=1):
        draw.rounded_rectangle([x, y, x+w, y+h], radius=radius, fill=fill, outline=outline, width=width)
    
    # Draw three overlapping photo frames
    # Frame 1: back-left (darker gold)
    x1, y1 = center - frame_size - gap//2, center - frame_size - gap//2
    rounded_rect(x1, y1, frame_size, frame_size, 30, fill=None, outline=GOLD_DARK, width=4)
    rounded_rect(x1+12, y1+12, frame_size-24, frame_size-24, 20, fill=(28, 30, 40, 255))
    
    # Frame 2: front-left (main gold) - with mountain scene
    x2, y2 = center - frame_size - gap//2, center - frame_size//2 + gap//2
    rounded_rect(x2, y2, frame_size, frame_size, 30, fill=None, outline=GOLD, width=4)
    rounded_rect(x2+12, y2+12, frame_size-24, frame_size-24, 20, fill=(30, 35, 50, 255))
    
    # Draw mountain scene in frame 2
    inner = x2 + 12
    ih = y2 + 12
    iw = frame_size - 24
    ih2 = frame_size - 24
    # Sky gradient
    for i in range(ih, ih + ih2):
        t = (i - ih) / ih2
        sky_r = int(35 + t * 30)
        sky_g = int(40 + t * 40)
        sky_b = int(55 + t * 50)
        draw.line([(inner, i), (inner + iw, i)], fill=(sky_r, sky_g, sky_b, 255))
    # Mountains
    points = [(inner, ih + ih2)]
    for i in range(iw + 1):
        py = ih + ih2//2 + int(ih2//4 * (0.5 + 0.5 * (i/iw)))
        points.append((inner + i, py))
    points.append((inner + iw, ih + ih2))
    draw.polygon(points, fill=(40, 45, 60, 255))
    # Sun
    sun_x = inner + iw//3
    sun_y = ih + ih2//4
    sun_r = iw//8
    draw.ellipse([sun_x-sun_r, sun_y-sun_r, sun_x+sun_r, sun_y+sun_r], fill=GOLD_LIGHT, outline=None)
    
    # Frame 3: front-right (light gold) - with landscape scene
    x3, y3 = center - frame_size//2 + gap//2, center - frame_size - gap//2
    rounded_rect(x3, y3, frame_size, frame_size, 30, fill=None, outline=GOLD_LIGHT, width=4)
    rounded_rect(x3+12, y3+12, frame_size-24, frame_size-24, 20, fill=(35, 40, 55, 255))
    
    # Draw rolling hills in frame 3
    inner3 = x3 + 12
    ih3 = y3 + 12
    iw3 = frame_size - 24
    ih2_3 = frame_size - 24
    for i in range(ih3, ih3 + ih2_3):
        t = (i - ih3) / ih2_3
        sky_r = int(30 + t * 40)
        sky_g = int(35 + t * 50)
        sky_b = int(50 + t * 60)
        draw.line([(inner3, i), (inner3 + iw3, i)], fill=(sky_r, sky_g, sky_b, 255))
    # Hills
    points3 = [(inner3, ih3 + ih2_3)]
    for i in range(iw3 + 1):
        py = ih3 + ih2_3//2 + int(ih2_3//5 * (0.5 + 0.5 * (i/iw3)))
        points3.append((inner3 + i, py))
    points3.append((inner3 + iw3, ih3 + ih2_3))
    draw.polygon(points3, fill=(30, 50, 35, 255))
    
    # Center glow effect
    for i in range(100, 0, -1):
        alpha = int(15 * (1 - i/100))
        draw.ellipse([center-i, center-i, center+i, center+i],
                    fill=(GOLD[0], GOLD[1], GOLD[2], alpha))
    
    return img

# Generate 1024x1024 icon
img = create_icon()
out_path = '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon_1024.png'
img.save(out_path, 'PNG')
print(f'Created {out_path}')

# Create iconset
iconset_dir = '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.iconset'
os.makedirs(iconset_dir, exist_ok=True)

# Generate all required sizes
sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes:
    resized = img.resize((size, size), Image.LANCZOS)
    path = os.path.join(iconset_dir, f'icon_{size}x{size}.png')
    resized.save(path, 'PNG')
    print(f'Created {path}')

# Also create @2x versions
for size in [32, 64, 128, 256, 512, 1024]:
    original = size // 2
    resized = img.resize((size, size), Image.LANCZOS)
    path = os.path.join(iconset_dir, f'icon_{original}x{original}@2x.png')
    resized.save(path, 'PNG')
    print(f'Created {path}')

# Generate .icns
result = os.system(f'iconutil -c icns {iconset_dir} -o /Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.icns')
if result == 0:
    print('Created AppIcon.icns')
else:
    print('Warning: iconutil failed')

print('\nIcon generation complete!')