"""Renders the Money Manager v2 app icon set.

Usage: python make_icon.py <out_dir>
Writes icon.png, icon_foreground.png, icon_background.png, icon_monochrome.png (1024px).
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
S = 4096  # supersampled canvas
FINAL = 1024


def hex_rgb(h, a=255):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def diagonal_gradient(size, c1, c2):
    """Top-left c1 → bottom-right c2."""
    g = Image.linear_gradient('L').resize((size * 2, size * 2)).rotate(45, resample=Image.BICUBIC)
    off = size // 2
    mask = g.crop((off, off, off + size, off + size))
    a = Image.new('RGBA', (size, size), hex_rgb(c1))
    b = Image.new('RGBA', (size, size), hex_rgb(c2))
    return Image.composite(b, a, mask)


def vertical_gradient(size_wh, c1, c2):
    w, h = size_wh
    mask = Image.linear_gradient('L').resize((w, h))
    return Image.composite(Image.new('RGBA', (w, h), hex_rgb(c2)), Image.new('RGBA', (w, h), hex_rgb(c1)), mask)


def background(size):
    bg = diagonal_gradient(size, '#7A6CFA', '#2A1F8F')
    rings = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(rings)
    w = int(size * 0.075)
    d.ellipse((size * 0.52, -size * 0.30, size * 1.30, size * 0.48), outline=(255, 255, 255, 22), width=w)
    d.ellipse((-size * 0.38, size * 0.62, size * 0.36, size * 1.36), outline=(255, 255, 255, 16), width=w)
    return Image.alpha_composite(bg, rings)


def artwork(box):
    """Jar + coin artwork, drawn into a transparent square of side `box`."""
    img = Image.new('RGBA', (box, box), (0, 0, 0, 0))

    def r(x0, y0, x1, y1):
        return [int(v * box) for v in (x0, y0, x1, y1)]

    # Soft shadow under the jar.
    shadow = Image.new('RGBA', (box, box), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(r(0.20, 0.47, 0.80, 0.99), radius=int(box * 0.14), fill=(10, 6, 60, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(box * 0.035))
    img = Image.alpha_composite(img, shadow)

    d = ImageDraw.Draw(img)
    # Jar body (glass outline) and rim.
    d.rounded_rectangle(r(0.18, 0.40, 0.82, 0.95), radius=int(box * 0.15), fill=hex_rgb('#FFFFFF'))
    inner_box = r(0.225, 0.445, 0.775, 0.905)
    inner_mask = Image.new('L', (box, box), 0)
    ImageDraw.Draw(inner_mask).rounded_rectangle(inner_box, radius=int(box * 0.11), fill=255)

    contents = Image.new('RGBA', (box, box), hex_rgb('#EEF0FF'))
    # Allocation layers: each bucket gets its share.
    layers = [('#8B5CF6', '#A78BFA', 0.535, 0.640), ('#F59E0B', '#FBBF24', 0.640, 0.745), ('#10B981', '#34D399', 0.745, 0.95)]
    for dark, light, y0, y1 in layers:
        band = vertical_gradient((box, int(box * (y1 - y0)) + 1), light, dark)
        contents.paste(band, (0, int(box * y0)))
    # Glass highlight on the left (composited so it blends instead of replacing pixels).
    shine = Image.new('RGBA', (box, box), (0, 0, 0, 0))
    ImageDraw.Draw(shine).rounded_rectangle(r(0.265, 0.50, 0.305, 0.86), radius=int(box * 0.02), fill=(255, 255, 255, 90))
    contents = Image.alpha_composite(contents, shine)
    img.paste(contents, (0, 0), inner_mask)

    d = ImageDraw.Draw(img)
    d.rounded_rectangle(r(0.13, 0.345, 0.87, 0.445), radius=int(box * 0.05), fill=hex_rgb('#DCD8FF'))
    d.rounded_rectangle(r(0.13, 0.345, 0.87, 0.395), radius=int(box * 0.05), fill=hex_rgb('#FFFFFF'))

    # Gold coin dropping in.
    coin = Image.new('RGBA', (box, box), (0, 0, 0, 0))
    cx, cy, cr = 0.5, 0.165, 0.150
    coin_shadow = Image.new('RGBA', (box, box), (0, 0, 0, 0))
    ImageDraw.Draw(coin_shadow).ellipse(r(cx - cr, cy - cr + 0.02, cx + cr, cy + cr + 0.02), fill=(20, 10, 70, 90))
    coin_shadow = coin_shadow.filter(ImageFilter.GaussianBlur(box * 0.015))
    img = Image.alpha_composite(img, coin_shadow)
    gold = vertical_gradient((box, box), '#FDE68A', '#F59E0B')
    coin_mask = Image.new('L', (box, box), 0)
    ImageDraw.Draw(coin_mask).ellipse(r(cx - cr, cy - cr, cx + cr, cy + cr), fill=255)
    coin.paste(gold, (0, 0), coin_mask)
    cdraw = ImageDraw.Draw(coin)
    ring = 0.112
    cdraw.ellipse(r(cx - ring, cy - ring, cx + ring, cy + ring), outline=hex_rgb('#D97706'), width=int(box * 0.012))
    font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', int(box * 0.16))
    cdraw.text((int(cx * box), int((cy + 0.006) * box)), '₹', font=font, fill=hex_rgb('#92400E'), anchor='mm')
    img = Image.alpha_composite(img, coin)

    # Sparkle.
    d = ImageDraw.Draw(img)
    sx, sy, s1, s2 = 0.74, 0.11, 0.055, 0.014
    d.polygon([(sx * box, (sy - s1) * box), ((sx + s2) * box, sy * box), (sx * box, (sy + s1) * box), ((sx - s2) * box, sy * box)], fill=(255, 255, 255, 235))
    d.polygon([((sx - s1) * box, sy * box), (sx * box, (sy - s2) * box), ((sx + s1) * box, sy * box), (sx * box, (sy + s2) * box)], fill=(255, 255, 255, 235))
    return img


def place(art, canvas, scale):
    """Centers `art` on a transparent canvas, scaled to `scale` of the canvas side."""
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    side = int(canvas * scale)
    a = art.resize((side, side), Image.LANCZOS)
    off = (canvas - side) // 2
    out.paste(a, (off, off + int(canvas * 0.01)), a)
    return out


def save(img, name):
    img.resize((FINAL, FINAL), Image.LANCZOS).save(OUT / name)


art = artwork(S)
bg = background(S)

# Full icon (iOS / legacy Android / web): art fills ~70% of the square.
full = Image.alpha_composite(bg, place(art, S, 0.76))
save(full.convert('RGB'), 'icon.png')

# Adaptive: keep art inside the 66/108 safe zone.
save(place(art, S, 0.60), 'icon_foreground.png')
save(bg.convert('RGB'), 'icon_background.png')

# Monochrome (Android 13 themed icons): white silhouette from alpha.
fg = place(art, S, 0.60)
alpha = fg.getchannel('A').point(lambda v: 255 if v > 128 else 0)
mono = Image.new('RGBA', (S, S), (255, 255, 255, 0))
mono.putalpha(alpha)
save(mono, 'icon_monochrome.png')

# Preview sheet: full icon, circle/squircle masks, small size.
prev = Image.new('RGBA', (1400, 460), hex_rgb('#F5F6FA'))
icon = Image.open(OUT / 'icon.png').convert('RGBA').resize((360, 360), Image.LANCZOS)
rounded = Image.new('L', (360, 360), 0)
ImageDraw.Draw(rounded).rounded_rectangle((0, 0, 359, 359), radius=80, fill=255)
prev.paste(icon, (50, 50), rounded)
circle = Image.new('L', (360, 360), 0)
ImageDraw.Draw(circle).ellipse((0, 0, 359, 359), fill=255)
adaptive = Image.alpha_composite(bg.resize((360, 360), Image.LANCZOS), place(art, 360, 0.60))
prev.paste(adaptive, (470, 50), circle)
dark = Image.new('RGBA', (460, 460), hex_rgb('#0E0F14'))
prev.paste(dark, (900, 0))
for i, sz in enumerate((48, 72, 120)):
    small = Image.open(OUT / 'icon.png').convert('RGBA').resize((sz, sz), Image.LANCZOS)
    m = Image.new('L', (sz, sz), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, sz - 1, sz - 1), radius=sz // 4, fill=255)
    prev.paste(small, (940 + i * 130, 230 - sz // 2), m)
prev.convert('RGB').save(OUT.parent / 'icon_preview.png')
print('done')
