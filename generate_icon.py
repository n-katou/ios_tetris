#!/usr/bin/env python3
"""Generate a Tetris app icon with colourful blocks on a dark background."""

from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 1024

TETROMINO_COLORS = {
    "I": (0,   220, 240),   # cyan
    "O": (240, 220,   0),   # yellow
    "T": (160,  40, 220),   # purple
    "S": (50,  210,  80),   # green
    "Z": (230,  40,  40),   # red
    "J": (40,  100, 230),   # blue
    "L": (240, 130,  20),   # orange
}

def draw_block(draw, img, x, y, size, color):
    """Draw a single Tetris block with highlight and shadow."""
    pad = 3
    x0, y0, x1, y1 = x + pad, y + pad, x + size - pad, y + size - pad

    # Glow layer
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for s in range(12, 0, -2):
        a = int(50 * (1 - s / 12))
        gd.rectangle([x0 - s, y0 - s, x1 + s, y1 + s], fill=(*color, a))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=6))
    img.alpha_composite(glow)
    draw = ImageDraw.Draw(img)

    # Main fill
    draw.rectangle([x0, y0, x1, y1], fill=(*color, 255))

    # Top-left highlight
    draw.line([(x0, y1), (x0, y0), (x1, y0)], fill=(255, 255, 255, 130), width=3)
    # Bottom-right shadow
    draw.line([(x1, y0), (x1, y1), (x0, y1)], fill=(0, 0, 0, 120), width=3)

    return draw

def make_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # Background gradient (dark charcoal → near-black)
    for y in range(SIZE):
        t = y / SIZE
        r = int(12 + 8  * t)
        g = int(12 + 8  * t)
        b = int(18 + 14 * t)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

    # Subtle grid
    grid = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    cell = SIZE // 10
    for c in range(0, SIZE, cell):
        gd.line([(c, 0), (c, SIZE)], fill=(255, 255, 255, 10), width=1)
    for r in range(0, SIZE, cell):
        gd.line([(0, r), (SIZE, r)], fill=(255, 255, 255, 10), width=1)
    img.alpha_composite(grid)
    draw = ImageDraw.Draw(img)

    # --- Layout: blocks arranged as a Tetris scene ---
    # Block size based on a 10-col grid
    B = SIZE // 10   # 102 px

    # Helper
    def block(col, row, color_key):
        nonlocal draw
        draw = draw_block(draw, img, col * B, row * B, B, TETROMINO_COLORS[color_key])

    # Bottom "locked" rows (rows 7-9)
    locked = [
        # row 7
        [(0,"J"),(1,"J"),(2,"S"),(3,"S"),(4,"Z"),(5,"Z"),(6,"L"),(7,"L"),(8,"I"),(9,"I")],
        # row 8
        [(0,"T"),(1,"T"),(2,"T"),(3,"O"),(4,"O"),(5,"I"),(6,"I"),(7,"I"),(8,"I"),(9,"Z")],
        # row 9
        [(0,"L"),(1,"O"),(2,"O"),(3,"S"),(4,"S"),(5,"J"),(6,"T"),(7,"T"),(8,"T"),(9,"L")],
    ]
    for row_offset, cells in enumerate(locked):
        for col, key in cells:
            block(col, 7 + row_offset, key)

    # Falling I-piece (horizontal, row 5, cols 3-6) — cyan
    for c in range(3, 7):
        block(c, 5, "I")

    # T-piece in place (rows 3-4)
    #   .T.
    #   TTT
    block(4, 3, "T")
    block(3, 4, "T"); block(4, 4, "T"); block(5, 4, "T")

    # S-piece (rows 1-2, right side)
    #   .SS
    #   SS.
    block(6, 1, "S"); block(7, 1, "S")
    block(5, 2, "S"); block(6, 2, "S")

    # L-piece (rows 2-4, left side)
    #   L..
    #   L..
    #   LL.
    block(1, 2, "L")
    block(1, 3, "L")
    block(1, 4, "L"); block(2, 4, "L")

    # O-piece top-right (rows 0-1)
    block(8, 0, "O"); block(9, 0, "O")
    block(8, 1, "O"); block(9, 1, "O")

    # Vignette
    vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    cx = cy = SIZE // 2
    for r in range(SIZE // 2, 0, -6):
        dist = r / (SIZE // 2)
        alpha = int(max(0, (dist - 0.45) * 2) * 180)
        vd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, alpha))
    vignette = vignette.filter(ImageFilter.GaussianBlur(radius=20))
    img.alpha_composite(vignette)

    # Export
    out_path = "/Users/workspace/ios系/ios_tetris/ios_tetris/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    final = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    final.paste(img, mask=img.split()[3])
    final.save(out_path, "PNG")
    print(f"Saved: {out_path}")

make_icon()
