"""Procedural, tileable African textile patterns (wax print, kente, bazin embroidery)."""
import math, random
import numpy as np
from PIL import Image, ImageDraw


def _hex(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def wax(colors, size=512, cells=4, seed=1):
    """Dutch-wax style print: offset grid of concentric 'target' motifs, leaves and dots.
    colors = [background, main, accent, detail]. Tileable (motifs wrap at the edges)."""
    rnd = random.Random(seed)
    bg, c1, c2, c3 = [_hex(c) for c in colors]
    img = Image.new("RGB", (size, size), bg)
    d = ImageDraw.Draw(img)
    step = size / cells
    def wrap_draw(fn, x, y, r):
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                if -r < x + ox < size + r and -r < y + oy < size + r:
                    fn(x + ox, y + oy)
    for row in range(cells):
        for col in range(cells):
            cx = (col + 0.5 + (0.5 if row % 2 else 0)) * step
            cy = (row + 0.5) * step
            R = step * 0.42
            def target(x, y):
                for k, c in enumerate([c1, bg, c2, bg, c3]):
                    rr = R * (1 - k * 0.19)
                    d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=c)
            wrap_draw(target, cx, cy, R)
            # leaf / petal motifs between the targets
            lx, ly = cx + step * 0.5, cy
            def leaf(x, y):
                for a in range(4):
                    ang = a * math.pi / 2 + math.pi / 4
                    px, py = x + math.cos(ang) * step * 0.16, y + math.sin(ang) * step * 0.16
                    d.ellipse([px - step * 0.07, py - step * 0.07, px + step * 0.07, py + step * 0.07], fill=c2)
                d.ellipse([x - step * 0.05, y - step * 0.05, x + step * 0.05, y + step * 0.05], fill=c3)
            wrap_draw(leaf, lx, ly, step * 0.25)
    # speckle dots
    for _ in range(cells * cells * 6):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        r = rnd.uniform(1.5, 3.5)
        wrap_draw(lambda X, Y: d.ellipse([X - r, Y - r, X + r, Y + r], fill=c3), x, y, r)
    return img


def kente(size=512, seed=2):
    """Kente-like woven strips: alternating striped blocks in gold / green / red / black."""
    rnd = random.Random(seed)
    pal = [_hex(c) for c in ("f2b705", "1b7a3a", "c3272b", "111111", "f2b705")]
    img = Image.new("RGB", (size, size), pal[0])
    d = ImageDraw.Draw(img)
    strip = size // 8
    for s in range(8):
        x0 = s * strip
        block = size // 8
        for b in range(8):
            y0 = b * block
            if (s + b) % 2 == 0:  # horizontal stripes block
                for k in range(0, block, 6):
                    d.rectangle([x0, y0 + k, x0 + strip, y0 + k + 3], fill=pal[(k // 6 + s) % 4])
            else:                 # checker block
                c = pal[(s * 3 + b) % 4]
                d.rectangle([x0 + 3, y0 + 3, x0 + strip - 3, y0 + block - 3], fill=c)
                d.rectangle([x0 + strip // 3, y0 + 6, x0 + 2 * strip // 3, y0 + block - 6], fill=pal[(s + b + 1) % 4])
        d.line([x0, 0, x0, size], fill=pal[3], width=2)
    return img


def embroidery(base, gold="e0b23a", size=512):
    """Bazin fabric (subtle damask sheen) with a gold embroidery lattice (grand boubou)."""
    b = _hex(base); g = _hex(gold)
    img = Image.new("RGB", (size, size), b)
    d = ImageDraw.Draw(img)
    arr = np.asarray(img).astype(float)
    y, x = np.mgrid[0:size, 0:size]
    damask = (np.sin(x / size * 2 * math.pi * 8) * np.sin(y / size * 2 * math.pi * 8)) * 10
    arr = np.clip(arr + damask[..., None], 0, 255)
    img = Image.fromarray(arr.astype(np.uint8))
    d = ImageDraw.Draw(img)
    n = 4; st = size / n
    for i in range(n):
        for j in range(n):
            cx, cy = (i + 0.5) * st, (j + 0.5) * st
            r = st * 0.3
            d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], outline=g, width=4)
            d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=g)
    return img


if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
    ims = [wax(["f29f05", "1d4e89", "c1272d", "fdf6e3"]), wax(["0b7a75", "f2b705", "d94f04", "ffffff"], seed=5),
           kente(), embroidery("2a3f8f")]
    W = Image.new("RGB", (4 * 256 + 30, 256), "white")
    for i, im in enumerate(ims):
        W.paste(im.resize((256, 256)), (i * 266, 0))
    W.save(out + "/patterns.png")
