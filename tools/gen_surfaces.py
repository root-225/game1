"""Tileable surface textures (asphalt, paving stones, laterite ground) + particle sprites."""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)
N = 256


def blur_wrap(a, r):
    out = a.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5
    return out


def noise(scale_blur):
    return blur_wrap(rng.random((N, N)), scale_blur)


def norm(a):
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def save(name, rgb):
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"), optimize=True)
    print("  ->", name)


def asphalt():
    fine = norm(noise(1)); mid = norm(noise(6)); big = norm(noise(24))
    v = 0.62 + 0.18 * fine + 0.12 * mid + 0.10 * big
    speck = rng.random((N, N)) > 0.985
    v = np.where(speck, v + 0.25, v)
    base = np.array([62, 63, 68], float)
    return base[None, None, :] * v[..., None] * 1.35


def pavers():
    """Offset rectangular paving stones, warm sandy grey (typical Abidjan sidewalk)."""
    img = np.zeros((N, N, 3), float)
    tile_w, tile_h = 64, 32
    grain = norm(noise(1)) * 0.12 + norm(noise(8)) * 0.1
    for row in range(N // tile_h):
        off = (tile_w // 2) * (row % 2)
        for col in range(-1, N // tile_w + 1):
            x0 = col * tile_w + off; y0 = row * tile_h
            tint = rng.uniform(0.88, 1.06)
            base = np.array([196, 186, 170]) * tint
            xs = np.arange(x0 + 2, x0 + tile_w - 2) % N
            ys = np.arange(y0 + 2, y0 + tile_h - 2) % N
            img[np.ix_(ys, xs)] = base
    mortar = img.sum(-1) == 0
    img[mortar] = [120, 112, 104]
    return img * (0.9 + grain)[..., None]


def smooth_noise(cells):
    """Tileable low-frequency noise: upscale a tiled random grid, crop the centre tile."""
    small = rng.random((cells, cells))
    big = Image.fromarray((np.tile(small, (3, 3)) * 255).astype(np.uint8)).resize((N * 3, N * 3), Image.BICUBIC)
    return norm(np.asarray(big, float)[N:2 * N, N:2 * N])


def laterite():
    """Red-earth ground with dry grass patches (Ivorian laterite)."""
    a = smooth_noise(16); b = norm(noise(2)); c = smooth_noise(5)
    earth = np.array([168, 98, 62], float)
    grass = np.array([104, 128, 58], float)
    mix = np.clip((c - 0.5) * 2.5, 0, 1)[..., None]
    col = earth * (1 - mix) + grass * mix
    return col * (0.86 + 0.12 * a + 0.05 * b)[..., None]


def soft_dot(name, color, size=64):
    y, x = np.mgrid[0:size, 0:size]
    d = np.sqrt((x - size / 2 + 0.5) ** 2 + (y - size / 2 + 0.5) ** 2) / (size / 2)
    alpha = np.clip(1 - d, 0, 1) ** 1.6
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[..., :3] = color
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name + ".png"))
    print("  ->", name)


if __name__ == "__main__":
    print("surfaces:")
    save("asphalt", asphalt())
    save("pavers", pavers())
    save("laterite", laterite())
    soft_dot("dust", (235, 220, 200))
    soft_dot("sparkle", (255, 236, 150))
    print("done.")
