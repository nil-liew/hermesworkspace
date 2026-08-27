#!/usr/bin/env python3
"""Generate SimpleImgViewer icon in similar style to SimpleVidPlayer."""

from PIL import Image, ImageDraw
import os

# Create iconset directory
iconset_dir = '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.iconset'
os.makedirs(iconset_dir, exist_ok=True)

# Colors matching SimpleVidPlayer style
BG_DARK = (8, 8, 18)  # Deep dark blue-black
BG_MID = (20, 20, 35)  # Slightly lighter dark
GOLD = (200, 160, 80)  # Golden amber
GOLD_LIGHT = (230, 190, 110)
GOLD_DARK = (150, 120, 60)

def create_icon(size, filename):
    """Create icon with image frame design."""
    img = Image.new('RGBA', (size, size), (*BG_DARK, 255))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    margin = size // 10
    
    # Background gradient effect (subtle)
    for y in range(size):
        ratio = y / size
        r = int(BG_DARK[0] * (1 - ratio * 0.3) + BG_MID[0] * ratio * 0.3)
        g = int(BG_DARK[1] * (1 - ratio * 0.3) + BG_MID[1] * ratio * 0.3)
        b = int(BG_DARK[2] * (1 - ratio * 0.3) + BG_MID[2] * ratio * 0.3)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    
    # Draw overlapping image frames
    frame_size = size // 3
    gap = size // 12
    
    # Back frame (slightly offset)
    back_x = center - frame_size//2 - gap//2
    back_y = center - frame_size//2 - gap//2
    draw_rounded_rect(draw, back_x, back_y, frame_size, frame_size, 
                      size//20, GOLD_DARK, 3)
    # Inner of back frame
    inner = size//20
    draw_rounded_rect(draw, back_x + inner, back_y + inner, 
                      frame_size - inner*2, frame_size - inner*2,
                      size//30, (25, 25, 45, 255))
    
    # Left front frame
    front_x = center - frame_size//2 - gap//2
    front_y = center - frame_size//2 + gap//2
    draw_rounded_rect(draw, front_x, front_y, frame_size, frame_size,
                      size//20, GOLD, 4)
    # Mountain/sun imagery inside
    draw_mountain_scene(draw, front_x + inner, front_y + inner,
                       frame_size - inner*2, frame_size - inner*2, size)
    
    # Right front frame (slightly overlapping)
    right_x = center - frame_size//2 + gap//2
    right_y = center - frame_size//2 - gap//2
    draw_rounded_rect(draw, right_x, right_y, frame_size, frame_size,
                      size//20, GOLD_LIGHT, 4)
    # Different scene inside
    draw_landscape_scene(draw, right_x + inner, right_y + inner,
                        frame_size - inner*2, frame_size - inner*2, size)
    
    # Center highlight/spotlight effect
    gradient_size = size // 4
    for i in range(gradient_size, 0, -1):
        alpha = int(30 * (1 - i/gradient_size))
        draw.ellipse([center-i, center-i, center+i, center+i],
                    fill=(GOLD[0], GOLD[1], GOLD[2], alpha))
    
    return img

def draw_rounded_rect(draw, x, y, w, h, radius, color, width=2):
    """Draw a rounded rectangle."""
    draw.rounded_rectangle([x, y, x+w, y+h], radius=radius, outline=color, width=width)

def draw_mountain_scene(draw, x, y, w, h, icon_size):
    """Draw a mountain landscape in the frame."""
    inner = icon_size // 40
    # Sky gradient
    for i in range(h):
        ratio = i / h
        r = int(30 + ratio * 40)
        g = int(30 + ratio * 50)
        b = int(50 + ratio * 60)
        draw.line([(x, y+i), (x+w, y+i)], fill=(r, g, b, 255))
    
    # Mountains
    mountain_color = (40, 35, 60, 255)
    draw.polygon([
        (x, y+h),
        (x+w//3, y+h//2),
        (x+w//2, y+h//3),
        (x+2*w//3, y+h//2),
        (x+w, y+h)
    ], fill=mountain_color)
    
    # Sun/moon
    sun_y = y + h//4
    sun_r = w//8
    draw.ellipse([x+w//2-sun_r, sun_y-sun_r, x+w//2+sun_r, sun_y+sun_r],
                fill=GOLD, outline=GOLD_LIGHT, width=2)

def draw_landscape_scene(draw, x, y, w, h, icon_size):
    """Draw a rolling hills landscape."""
    inner = icon_size // 40
    # Sky
    for i in range(h):
        ratio = i / h
        r = int(25 + ratio * 50)
        g = int(35 + ratio * 60)
        b = int(45 + ratio * 70)
        draw.line([(x, y+i), (x+w, y+i)], fill=(r, g, b, 255))
    
    # Rolling hills
    hill_color = (35, 50, 40, 255)
    points = []
    for i in range(w+1):
        py = y + h//2 + int(h//4 * (0.5 + 0.5 * (i/w)))
        points.append((x+i, py))
    points.append((x+w, y+h))
    points.append((x, y+h))
    draw.polygon(points, fill=hill_color)
    
    # Tree silhouette
    tree_x = x + w//3
    tree_base = y + h//2 + int(h//8)
    trunk_w = w//10
    draw.rectangle([tree_x-trunk_w//2, tree_base, 
                   tree_x+trunk_w//2, tree_base+h//4], fill=(25, 35, 25))
    # Canopy
    draw.ellipse([tree_x-w//5, tree_base-h//5, 
                 tree_x+w//5, tree_base+h//6], fill=(30, 45, 35))

# Generate all required icon sizes
sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes:
    img = create_icon(size, f'icon_{size}x{size}')
    path = os.path.join(iconset_dir, f'icon_{size}x{size}.png')
    img.save(path, 'PNG')
    print(f'Created {path}')

# Also create the 1024 version separately for preview
create_icon(1024, 'icon_1024x1024.png').save(
    '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon_1024.png', 'PNG')
print('Created AppIcon_1024.png')

# Generate .icns file
import subprocess
result = subprocess.run(['iconutil', '-c', 'icns', iconset_dir, 
                        '-o', '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.icns'],
                       capture_output=True, text=True)
if result.returncode == 0:
    print('Created AppIcon.icns')
else:
    print(f'Error creating icns: {result.stderr}')

print('\nIcon generation complete!')
