"""Recolour swatches of KayKit palette atlases (used for the Abidjan taxi / woro-woro).

Each KayKit texture is an 8x4 grid of vertical-gradient swatches (128x256 px each).
We replace a swatch's colour while keeping its luminance gradient, so the toon shading
of the original atlas survives. Cell keys are "xy" (column, row).
"""
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def recolor(img, cells, contrast=1.0):
    """contrast < 1 flattens the swatch gradient (keeps bright areas from washing out)."""
    px = img.load()
    for key, hexcol in cells.items():
        cx, cy = int(key[0]), int(key[1])
        x0, y0 = cx * 128, cy * 256
        ref = img.crop((x0 + 30, y0 + 100, x0 + 98, y0 + 156)).resize((1, 1), Image.BOX).getpixel((0, 0))
        ref_l = max(lum(ref), 1.0)
        tgt = hex_rgb(hexcol)
        for y in range(y0, y0 + 256):
            for x in range(x0, x0 + 128):
                p = px[x, y]
                k = min(1.0 + (lum(p) / ref_l - 1.0) * contrast, 1.6)
                px[x, y] = (min(255, int(tgt[0] * k)), min(255, int(tgt[1] * k)),
                            min(255, int(tgt[2] * k)), p[3])
    return img


if __name__ == "__main__":
    # Abidjan taxi (orange) + woro-woro (green) variant of the KayKit city atlas
    city = os.path.join(HERE, "..", "assets", "thirdparty", "kaykit", "city")
    img = Image.open(os.path.join(city, "citybits_texture.png")).convert("RGBA")
    recolor(img, {"31": "e85d0c", "21": "2aa24e"}, contrast=0.45).save(os.path.join(city, "citybits_abidjan.png"), optimize=True)
    print("  -> citybits_abidjan.png")
