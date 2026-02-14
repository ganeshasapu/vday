#!/usr/bin/env python3
"""Generate Mwah app icon as .icns"""

import os
import subprocess
import math
from PIL import Image, ImageDraw

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONSET_DIR = os.path.join(PROJECT_DIR, "AppIcon.iconset")
ICNS_PATH = os.path.join(PROJECT_DIR, "AppIcon.icns")

SIZES = [16, 32, 64, 128, 256, 512, 1024]

def draw_heart(size):
    """Draw a pink/red gradient heart on a transparent background."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = size * 0.1
    w = size - 2 * margin
    h = size - 2 * margin
    cx = size / 2
    cy = size / 2 + margin * 0.3  # shift down slightly

    # Generate heart shape points using parametric equation
    points = []
    steps = 500
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        points.append((x, y))

    # Normalize to fit in the icon
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    range_x = max_x - min_x
    range_y = max_y - min_y
    scale = min(w / range_x, h / range_y)

    scaled = []
    for x, y in points:
        sx = cx + (x - (min_x + max_x) / 2) * scale
        sy = cy + (y - (min_y + max_y) / 2) * scale
        scaled.append((sx, sy))

    # Draw filled heart with gradient effect using layered circles
    # First draw a solid pink heart
    draw.polygon(scaled, fill=(236, 64, 122, 255))

    # Add a subtle gradient overlay - lighter at top, darker at bottom
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)

    # Top highlight
    highlight_points = []
    for x, y in scaled:
        # Shift points up and shrink for highlight
        nx = cx + (x - cx) * 0.7
        ny = cy + (y - cy) * 0.7 - size * 0.05
        highlight_points.append((nx, ny))

    odraw.polygon(highlight_points, fill=(255, 120, 170, 80))
    img = Image.alpha_composite(img, overlay)

    # Draw a subtle dark red shadow at the bottom of the heart
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    shadow_points = []
    for x, y in scaled:
        nx = cx + (x - cx) * 0.5
        ny = cy + (y - cy) * 0.5 + size * 0.08
        shadow_points.append((nx, ny))
    sdraw.polygon(shadow_points, fill=(180, 20, 60, 60))
    img = Image.alpha_composite(img, shadow)

    # Add a white shine/reflection spot in the upper-left area
    shine = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shdraw = ImageDraw.Draw(shine)
    shine_cx = cx - size * 0.15
    shine_cy = cy - size * 0.15
    shine_r = size * 0.08
    shdraw.ellipse(
        [shine_cx - shine_r, shine_cy - shine_r,
         shine_cx + shine_r, shine_cy + shine_r],
        fill=(255, 255, 255, 120)
    )
    img = Image.alpha_composite(img, shine)

    return img


def main():
    os.makedirs(ICONSET_DIR, exist_ok=True)

    for s in SIZES:
        img = draw_heart(s)
        # Standard resolution
        if s <= 512:
            img_1x = img.resize((s, s), Image.LANCZOS)
            img_1x.save(os.path.join(ICONSET_DIR, f"icon_{s}x{s}.png"))
        # @2x (Retina) variants
        if s >= 32:
            half = s // 2
            img_2x = img.resize((s, s), Image.LANCZOS)
            img_2x.save(os.path.join(ICONSET_DIR, f"icon_{half}x{half}@2x.png"))

    # Convert to .icns
    subprocess.run(["iconutil", "-c", "icns", ICONSET_DIR, "-o", ICNS_PATH], check=True)
    print(f"Icon created: {ICNS_PATH}")

    # Clean up iconset
    import shutil
    shutil.rmtree(ICONSET_DIR)


if __name__ == "__main__":
    main()
