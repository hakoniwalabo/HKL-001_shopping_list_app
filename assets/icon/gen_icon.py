"""
Shopping cart icon generator for 買い物リストアプリ.
Outputs: icon.png (1024x1024, teal background + white cart)
"""

from PIL import Image, ImageDraw

SIZE = 1024

def line_with_caps(draw, x1, y1, x2, y2, width, color):
    """Draw a line with circular end-caps for smooth joins."""
    draw.line([(x1, y1), (x2, y2)], fill=color, width=width)
    r = width // 2
    draw.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=color)
    draw.ellipse([x2 - r, y2 - r, x2 + r, y2 + r], fill=color)


def create_icon(size=SIZE):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Background: Material Teal 600 ──
    teal = (0, 137, 123, 255)
    draw.rounded_rectangle(
        [0, 0, size - 1, size - 1],
        radius=int(size * 0.22),
        fill=teal,
    )

    # ── Cart (white, stroke style) ──
    W = (255, 255, 255, 255)
    LW = 52  # stroke width

    # All coordinates are for 1024px; vertically centered around y=512
    # Handle bar  (horizontal, top)
    H_Y  = 194           # handle y
    H_X1 = 188           # handle left x
    H_X2 = 736           # handle right x (arm starts here)

    # Arm: right end of handle bar down to basket top-right
    ARM_X2 = 830         # basket right x
    ARM_Y2 = 474         # basket top y

    # Basket
    BASK_X1 = 316        # basket left x (top)
    BASK_X2 = ARM_X2
    BASK_Y1 = ARM_Y2
    BASK_BX1 = 252       # basket bottom-left x
    BASK_BX2 = 766       # basket bottom-right x
    BASK_Y2 = 694        # basket bottom y

    # Wheels
    WH_R  = 68           # outer radius
    WH_INN = 28          # inner hole radius
    WH_Y  = 788          # wheel center y (just below basket)
    WH_X1 = 332          # left wheel x
    WH_X2 = 686          # right wheel x

    # Draw cart strokes
    line_with_caps(draw, H_X1,    H_Y,    H_X2,    H_Y,    LW, W)  # handle bar
    line_with_caps(draw, H_X2,    H_Y,    ARM_X2,  ARM_Y2, LW, W)  # arm
    line_with_caps(draw, BASK_X1, BASK_Y1, BASK_X2, BASK_Y1, LW, W)  # basket top
    line_with_caps(draw, BASK_X1, BASK_Y1, BASK_BX1, BASK_Y2, LW, W) # basket left
    line_with_caps(draw, BASK_X2, BASK_Y1, BASK_BX2, BASK_Y2, LW, W) # basket right
    line_with_caps(draw, BASK_BX1, BASK_Y2, BASK_BX2, BASK_Y2, LW, W) # basket bottom

    # Wheels (filled circle with teal inner hole = ring look)
    for cx, cy in [(WH_X1, WH_Y), (WH_X2, WH_Y)]:
        draw.ellipse([cx - WH_R, cy - WH_R, cx + WH_R, cy + WH_R], fill=W)
        draw.ellipse([cx - WH_INN, cy - WH_INN, cx + WH_INN, cy + WH_INN], fill=teal)

    return img


if __name__ == "__main__":
    import os

    out_dir = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(out_dir, "icon.png")

    icon = create_icon()
    icon.save(out_path)
    print(f"Saved: {out_path}  ({SIZE}x{SIZE})")
