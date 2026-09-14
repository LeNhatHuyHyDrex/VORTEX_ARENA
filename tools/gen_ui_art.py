"""Generate the 7 optional UI art pieces (dark-fantasy style) as PNG files.

Run:  python tools/gen_ui_art.py
Out:  assets/art/ui/{panel_parchment,card_frame,pedestal,button_normal,
       button_hover,title_ribbon,skill_slot}.png

Why generated: external asset packs (itch.io / kenney) may be unreachable;
the art-overrides contract only needs *a* PNG per slot, and these painted
plates match the project's dark-fantasy direction. Any PNG can later be
replaced by hand without touching code.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "ui")
os.makedirs(OUT, exist_ok=True)

# Palette matches in-game vector style: deep blue-black base, steel borders,
# purple/cyan accents, gold details.
BASE = (12, 13, 20, 255)
BASE_LIGHT = (24, 26, 38, 255)
STEEL = (64, 76, 106, 255)
STEEL_LIGHT = (110, 128, 172, 255)
GOLD = (232, 190, 96, 255)
PURPLE = (167, 139, 250, 255)
CYAN = (56, 189, 248, 255)


def noise_layer(w, h, strength=10, seed=7):
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            v = rng.randint(-strength, strength)
            px[x, y] = (v, v, v, 0)
    return img


def add_noise(img, strength=8, alpha=60, seed=7):
    w, h = img.size
    n = noise_layer(w, h, strength, seed)
    base = img.convert("RGBA")
    base.alpha_composite(n)
    return base


def radial_glow(img, center, radius, color, peak=110):
    """Soft radial glow composited over img."""
    w, h = img.size
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = glow.load()
    cx, cy = center
    for y in range(max(0, int(cy - radius)), min(h, int(cy + radius))):
        for x in range(max(0, int(cx - radius)), min(w, int(cx + radius))):
            d = math.hypot(x - cx, y - cy) / radius
            if d < 1.0:
                a = int(peak * (1.0 - d) ** 2)
                gd[x, y] = (color[0], color[1], color[2], a)
    img.alpha_composite(glow)


def rr(d, box, radius, **kw):
    d.rounded_rectangle(box, radius=radius, **kw)


# ----------------------------------------------------------------- panel
def gen_panel_parchment():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    # Dark parchment body with subtle vertical weave
    for y in range(h):
        t = y / h
        c = tuple(int(BASE[i] + (BASE_LIGHT[i] - BASE[i]) * (0.5 + 0.5 * math.sin(t * math.pi))) for i in range(3))
        d.line([(0, y), (w, y)], fill=c + (255,))
    img = add_noise(img, strength=14, alpha=70, seed=11)
    d = ImageDraw.Draw(img)
    # Outer ornate metal frame
    rr(d, (6, 6, w - 7, h - 7), 26, outline=STEEL, width=10)
    rr(d, (14, 14, w - 15, h - 15), 20, outline=STEEL_LIGHT, width=3)
    rr(d, (22, 22, w - 23, h - 23), 16, outline=(20, 22, 32, 255), width=3)
    # Inner purple accent line
    rr(d, (34, 34, w - 35, h - 35), 12, outline=(PURPLE[0], PURPLE[1], PURPLE[2], 90), width=2)
    # Corner rivets
    for cx, cy in [(28, 28), (w - 28, 28), (28, h - 28), (w - 28, h - 28)]:
        d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=(30, 33, 46, 255), outline=STEEL_LIGHT, width=2)
        d.ellipse((cx - 4, cy - 5, cx + 3, cy + 2), fill=(150, 165, 205, 255))
    # Center sigil glow (subtle, behind content)
    radial_glow(img, (w // 2, h // 2), 210, PURPLE, peak=26)
    img.save(os.path.join(OUT, "panel_parchment.png"))


# ------------------------------------------------------------- card_frame
def gen_card_frame():
    w, h = 256, 340
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = 8
    # Frame body: dark plate with window cut in the middle
    rr(d, (m, m, w - m, h - m), 24, fill=(10, 10, 16, 235))
    win = (m + 10, m + 10, w - m - 10, h - m - 60)
    d.rounded_rectangle(win, radius=16, fill=(0, 0, 0, 0), outline=None)
    # Punch the window transparent
    punch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pd = ImageDraw.Draw(punch)
    pd.rounded_rectangle(win, radius=16, fill=(0, 0, 0, 255))
    img = Image.composite(Image.new("RGBA", (w, h), (0, 0, 0, 0)), img, punch.split()[3])
    d = ImageDraw.Draw(img)
    # Metal border layers
    rr(d, (m, m, w - m, h - m), 24, outline=STEEL, width=7)
    rr(d, (m + 6, m + 6, w - m - 6, h - m - 6), 20, outline=STEEL_LIGHT, width=2)
    # Bottom nameplate band
    rr(d, (m + 4, h - m - 48, w - m - 4, h - m - 4), 16, fill=(8, 8, 14, 220), outline=STEEL, width=3)
    rr(d, (m + 10, h - m - 42, w - m - 10, h - m - 10), 12, outline=(GOLD[0], GOLD[1], GOLD[2], 70), width=2)
    # Corner filigree: quarter arcs + dot
    def filigree(cx, cy, sx, sy):
        for r in (30, 22, 14):
            d.arc((cx - r, cy - r, cx + r, cy + r), start=90 if (sx > 0 and sy > 0) else 0,
                  end=180, fill=GOLD if r == 22 else STEEL_LIGHT, width=3)
        d.ellipse((cx + sx * 26 - 4, cy + sy * 26 - 4, cx + sx * 26 + 4, cy + sy * 26 + 4), fill=GOLD)
    filigree(m + 14, m + 14, 1, 1)
    filigree(w - m - 14, m + 14, -1, 1)
    filigree(m + 14, h - m - 56, 1, -1)
    filigree(w - m - 14, h - m - 56, -1, -1)
    # Top gem
    d.ellipse((w // 2 - 10, m - 2, w // 2 + 10, m + 18), fill=(26, 20, 46, 255), outline=PURPLE, width=3)
    d.ellipse((w // 2 - 4, m + 4, w // 2 + 4, m + 12), fill=(220, 205, 255, 255))
    img.save(os.path.join(OUT, "card_frame.png"))


# ---------------------------------------------------------------- pedestal
def gen_pedestal():
    w, h = 256, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2 - 6
    rx, ry = 108, 38

    def ellipse(cx, cy, rx, ry, fill, outline=None, width=0):
        pts = [(cx + math.cos(a * 2 * math.pi / 64) * rx, cy + math.sin(a * 2 * math.pi / 64) * ry) for a in range(64)]
        d.polygon(pts, fill=fill, outline=outline, width=width)

    # Side wall (extruded down)
    top = [(cx + math.cos(a * 2 * math.pi / 64) * rx, cy + math.sin(a * 2 * math.pi / 64) * ry) for a in range(64)]
    bottom = [(x, y + 34) for x, y in top]
    side_pts = top[16:] + bottom[16:]  # front half
    d.polygon(side_pts, fill=(16, 15, 22, 255))
    # Carved bands on the wall
    d.polygon([(cx - rx + 10, cy + 12), (cx + rx - 10, cy + 12), (cx + rx - 10, cy + 16), (cx - rx + 10, cy + 16)], fill=(36, 40, 60, 255))
    d.polygon([(cx - rx + 16, cy + 24), (cx + rx - 16, cy + 24), (cx + rx - 16, cy + 27), (cx - rx + 16, cy + 27)], fill=(28, 31, 48, 255))
    # Top platform
    ellipse(cx, cy, rx, ry, (38, 40, 56, 255))
    ellipse(cx, cy, rx - 8, ry - 6, (46, 49, 70, 255), outline=STEEL_LIGHT, width=2)
    # Runic ring (purple, slightly rotating look)
    for i in range(12):
        a = 2 * math.pi * i / 12
        x = cx + math.cos(a) * (rx - 22)
        y = cy + math.sin(a) * (ry - 12)
        d.ellipse((x - 3, y - 2, x + 3, y + 2), fill=(PURPLE[0], PURPLE[1], PURPLE[2], 200))
    ellipse(cx, cy, rx - 34, ry - 16, (30, 30, 46, 255), outline=(PURPLE[0], PURPLE[1], PURPLE[2], 120), width=2)
    img.save(os.path.join(OUT, "pedestal.png"))


# ----------------------------------------------------------------- buttons
def gen_button(hover=False):
    w, h = 256, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base_col = (30, 26, 52, 250) if hover else (20, 20, 34, 245)
    rr(d, (4, 4, w - 5, h - 5), 20, fill=base_col, outline=STEEL, width=5)
    rr(d, (9, 9, w - 10, h - 10), 16, outline=STEEL_LIGHT if hover else (70, 80, 116, 200), width=2)
    # Top bevel highlight
    rr(d, (12, 10, w - 13, h // 2), 14, fill=(255, 255, 255, 26 if hover else 14))
    # Bottom shadow lip
    rr(d, (12, h - 18, w - 13, h - 12), 6, fill=(0, 0, 0, 90))
    # Accent edge: gold on hover, purple normal
    acc = GOLD if hover else PURPLE
    d.line([(26, h - 8), (w - 26, h - 8)], fill=(acc[0], acc[1], acc[2], 200), width=3)
    # Side rivets
    for cx in (20, w - 20):
        d.ellipse((cx - 5, h // 2 - 5, cx + 5, h // 2 + 5), fill=(14, 12, 26, 255), outline=STEEL_LIGHT, width=2)
    if hover:
        radial_glow(img, (w // 2, h // 2), 150, acc, peak=46)
    img.save(os.path.join(OUT, "button_hover.png" if hover else "button_normal.png"))


# ------------------------------------------------------------ title_ribbon
def gen_title_ribbon():
    w, h = 512, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = h // 2
    # Main banner band with tapered ends
    band = [(60, cy - 34), (w - 60, cy - 34), (w - 44, cy), (w - 60, cy + 34), (60, cy + 34), (44, cy)]
    d.polygon(band, fill=(24, 20, 44, 245), outline=STEEL)
    rr(d, (66, cy - 26, w - 66, cy + 26), 14, outline=STEEL_LIGHT, width=2)
    rr(d, (74, cy - 19, w - 74, cy + 19), 10, outline=(GOLD[0], GOLD[1], GOLD[2], 90), width=2)
    # End tails (darker, offset)
    d.polygon([(44, cy - 20), (12, cy - 30), (22, cy), (12, cy + 30), (44, cy + 20)], fill=(16, 14, 30, 245), outline=STEEL)
    d.polygon([(w - 44, cy - 20), (w - 12, cy - 30), (w - 22, cy), (w - 12, cy + 30), (w - 44, cy + 20)], fill=(16, 14, 30, 245), outline=STEEL)
    # Center gem
    d.ellipse((w // 2 - 12, cy - 12, w // 2 + 12, cy + 12), fill=(30, 22, 52, 255), outline=PURPLE, width=3)
    d.ellipse((w // 2 - 5, cy - 5, w // 2 + 5, cy + 5), fill=(225, 210, 255, 255))
    radial_glow(img, (w // 2, cy), 120, PURPLE, peak=40)
    img.save(os.path.join(OUT, "title_ribbon.png"))


# --------------------------------------------------------------- skill_slot
def gen_skill_slot():
    s = 128
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rr(d, (6, 6, s - 7, s - 7), 26, fill=(14, 14, 24, 240), outline=STEEL, width=5)
    rr(d, (12, 12, s - 13, s - 13), 22, outline=(STEEL_LIGHT[0], STEEL_LIGHT[1], STEEL_LIGHT[2], 170), width=2)
    # Inner recessed well
    rr(d, (18, 18, s - 19, s - 19), 18, fill=(6, 6, 12, 220))
    rr(d, (20, 16, s - 21, s // 2), 16, fill=(255, 255, 255, 12))
    # Bottom shadow
    rr(d, (22, s - 22, s - 23, s - 18), 4, fill=(0, 0, 0, 110))
    # Corner notches
    for cx, cy in [(16, 16), (s - 16, 16), (16, s - 16), (s - 16, s - 16)]:
        d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(10, 10, 18, 255), outline=STEEL_LIGHT, width=2)
    img.save(os.path.join(OUT, "skill_slot.png"))


gen_panel_parchment()
gen_card_frame()
gen_pedestal()
gen_button(False)
gen_button(True)
gen_title_ribbon()
gen_skill_slot()
print("done ->", os.path.abspath(OUT))
