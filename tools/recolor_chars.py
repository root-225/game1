"""Recolour KayKit character palette atlases into Abidjan Runner skins.

Each KayKit texture is an 8x4 grid of vertical-gradient swatches (128x256 px each).
We replace a swatch's colour while keeping its luminance gradient, so the toon shading
of the original atlas survives. Cell keys are "xy" (column, row).
"""
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "kaykit_textures")
OUT = os.path.join(HERE, "..", "assets", "thirdparty", "kaykit", "characters", "skins")

SKIN = "6b4128"      # deep brown skin tone
SKIN_SHADE = "4f2e1c"
HAIR = "17120f"

SKINS = {
    # Mage body: tee + jeans + red sneakers
    "urban": ("Mage", {"00": SKIN, "72": SKIN, "10": HAIR, "01": "2f7fd8", "11": "2f7fd8",
                       "40": "2f7fd8", "22": "f2f2f2", "30": "f2f2f2", "50": "3b2b22",
                       "32": "34496e", "71": "e0413a"}),
    # Mage body: orange boubou, green trim, cream trousers (Ivorian flag colours)
    "trad": ("Mage", {"00": SKIN, "72": SKIN, "10": HAIR, "01": "f28a1a", "11": "f28a1a",
                      "40": "1e9b56", "30": "1e9b56", "22": "fafafa", "50": "e4b431",
                      "32": "efe4cc", "71": "6b4423"}),
    # Barbarian body: Elephants orange jersey, white shorts, green sash
    "foot": ("Barbarian", {"00": SKIN, "60": SKIN, "10": HAIR, "11": "f58220", "01": "f58220",
                           "21": "fafafa", "70": "1e9b56", "72": "fafafa", "71": "f58220",
                           "32": "fafafa", "30": "e8e8e8"}),
    # Knight body: charcoal suit, white shirt, red tie
    "biz": ("Knight", {"00": SKIN, "10": HAIR, "30": "2b303c", "70": "353b49", "21": "eeeeee",
                       "60": "1b1b1f", "40": "1f2229", "71": "1f2229", "01": "c0272d"}),
}


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
    os.makedirs(OUT, exist_ok=True)
    for name, (base, cells) in SKINS.items():
        img = Image.open(os.path.join(SRC, base.lower() + "_texture.png")).convert("RGBA")
        recolor(img, cells).save(os.path.join(OUT, name + ".png"), optimize=True)
        print("  ->", name, "(base %s)" % base)
