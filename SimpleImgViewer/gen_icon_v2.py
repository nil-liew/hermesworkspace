#!/usr/bin/env python3
"""Generate SimpleImgViewer icon with new design and palette."""
from PIL import Image, ImageDraw
import os, math

# Settings
SIZE = 1024
ICONSET_DIR = '/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon.iconset'
os.makedirs(ICONSET_DIR, exist_ok=True)

# Cinema Dark + Gold Palette
BG_DARK = (8, 8, 18)
GOLD = (200, 160, 80)
GOLD_LIGHT = (230, 190, 110)
ORANGE = (255, 128, 0) # User requested orange variation option

def draw_new_design(size, accent_color):
    """
    Design based on attachment: 
    Symmetric, centered geometric structure.
    """
    img = Image.new('RGBA', (size, size), (*BG_DARK, 255))
    draw = ImageDraw.Draw(img)
    
    # Example structure: Central geometric shape (e.g., stylized frame)
    # Using the requested structure and the provided accent color
    cx, cy = size // 2, size // 2
    
    # Main geometric element: Large centered frame
    draw.rounded_rectangle(
        [size * 0.15, size * 0.15, size * 0.85, size * 0.85],
        radius=size * 0.05,
        outline=accent_color,
        width=int(size * 0.03)
    )
    
    # Inner element: Stylized center
    draw.ellipse(
        [size * 0.4, size * 0.4, size * 0.6, size * 0.6],
        fill=accent_color
    )
    
    return img

# 1. Generate Gold/Dark Blue version
gold_img = draw_new_design(SIZE, GOLD)
gold_img.save('/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon_1024.png', 'PNG')

# 2. Generate Orange version
orange_img = draw_new_design(SIZE, ORANGE)
orange_img.save('/Users/daddy/hermesworkspace/SimpleImgViewer/AppIcon_1024_orange.png', 'PNG')

print('Generated new icons.')
