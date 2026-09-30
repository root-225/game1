"""Environment props generated procedurally: road chunk, Plateau glass towers (skyline),
kiosk, palms, lagoon-bridge balustrade. Street buildings/cars come from KayKit (CC0)."""
import os, math, random
from gltf_builder import box, cyl, save_static, rotate_mesh, merge

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "env")

C = dict(
    glass=[0.30, 0.52, 0.68, 1], glass2=[0.42, 0.66, 0.80, 1], glass3=[0.22, 0.40, 0.55, 1],
    concrete=[0.80, 0.79, 0.76, 1], concrete_d=[0.55, 0.55, 0.56, 1], frame=[0.88, 0.88, 0.90, 1],
    roof=[0.60, 0.28, 0.20, 1], wood=[0.55, 0.36, 0.18, 1], orange=[0.95, 0.55, 0.10, 1],
    window=[0.18, 0.26, 0.34, 1], trunk=[0.50, 0.36, 0.22, 1], trunk2=[0.42, 0.30, 0.18, 1],
    leaf=[0.16, 0.52, 0.20, 1], leaf2=[0.24, 0.62, 0.24, 1], coco=[0.45, 0.30, 0.12, 1],
    asphalt=[0.23, 0.23, 0.25, 1], paint=[0.95, 0.95, 0.92, 1], yellow=[0.96, 0.78, 0.18, 1],
    curb_r=[0.80, 0.18, 0.16, 1], curb_w=[0.93, 0.93, 0.91, 1], sidewalk=[0.74, 0.70, 0.64, 1],
    red=[0.85, 0.2, 0.2, 1], green=[0.2, 0.6, 0.3, 1], glass_dark=[0.15, 0.25, 0.35, 1],
)

LEN = 12.0          # chunk length (m)
ROAD_HALF = 3.6     # asphalt half width -> 3 lanes of 2.2 m + margins
SIDEWALK_OUT = 6.5  # outer edge of sidewalk


def road_segment():
    """Road chunk centred on origin, length LEN along Z, top of asphalt at y=0."""
    p = []
    p.append((box(0, -0.1, 0, ROAD_HALF * 2, 0.2, LEN), C["asphalt"], {"name": "asphalt"}))
    for lx in (-1.1, 1.1):                      # lane dividers (dashed)
        for i in range(3):
            p.append((box(lx, 0.005, -LEN / 2 + 2 + i * 4, 0.14, 0.02, 2.0), C["paint"]))
    for sx in (-1, 1):
        p.append((box(sx * 3.35, 0.005, 0, 0.14, 0.02, LEN), C["yellow"]))
        # red / white painted curb blocks (very common in Abidjan)
        for i in range(12):
            col = C["curb_r"] if i % 2 == 0 else C["curb_w"]
            p.append((box(sx * 3.75, 0.08, -LEN / 2 + 0.5 + i, 0.3, 0.36, 1.0), col))
        w = SIDEWALK_OUT - 3.9
        p.append((box(sx * (3.9 + w / 2), 0.05, 0, w, 0.3, LEN), C["sidewalk"], {"name": "sidewalk"}))
    return p


def tower(seed=0):
    """Plateau-style glass tower (for the skyline). ~3x3 footprint, 8-14 high."""
    r = random.Random(seed)
    p = []
    w = r.uniform(2.6, 3.4); d = r.uniform(2.6, 3.4); h = r.uniform(8, 14)
    glass = r.choice([C["glass"], C["glass2"], C["glass3"]])
    p.append((box(0, h / 2, 0, w, h, d), glass, {"name": "glass", "rough": 0.25, "metallic": 0.3}))
    # vertical mullions + floor bands
    for i in range(1, 4):
        x = -w / 2 + i * w / 4
        p.append((box(x, h / 2, d / 2 + 0.02, 0.08, h, 0.04), C["frame"]))
        p.append((box(x, h / 2, -d / 2 - 0.02, 0.08, h, 0.04), C["frame"]))
        z = -d / 2 + i * d / 4
        p.append((box(w / 2 + 0.02, h / 2, z, 0.04, h, 0.08), C["frame"]))
        p.append((box(-w / 2 - 0.02, h / 2, z, 0.04, h, 0.08), C["frame"]))
    for f in range(1, int(h / 1.4)):
        y = f * 1.4
        p.append((box(0, y, 0, w + 0.08, 0.1, d + 0.08), C["frame"]))
    # crown / setback (e.g. Pyramide / Tour F feel)
    if r.random() < 0.5:
        p.append((box(0, h + 1.0, 0, w * 0.6, 2.0, d * 0.6), glass))
        p.append((box(0, h + 2.2, 0, 0.15, 1.6, 0.15), C["concrete_d"]))
    else:
        p.append((box(0, h + 0.3, 0, w * 0.8, 0.6, d * 0.8), C["concrete_d"]))
    p.append((box(0, 0.6, 0, w + 0.3, 1.2, d + 0.3), C["concrete"]))
    return p


def kiosk():
    p = []
    p.append((box(0, 0.9, 0, 1.8, 1.6, 1.4), C["wood"]))
    p.append((box(0, 1.85, 0, 2.2, 0.25, 1.8), C["roof"]))
    cols = [C["red"], C["yellow"], C["green"], C["glass"]]
    for i in range(5):
        p.append((box(-0.8 + i * 0.4, 1.55, 0.85, 0.36, 0.5, 0.05), cols[i % len(cols)]))
    p.append((box(0, 1.1, 0.72, 1.5, 0.12, 0.1), C["concrete"]))
    p.append((box(0.7, 0.5, 0.75, 0.25, 0.4, 0.25), C["orange"]))
    return p


def palm(seed=0):
    """Coconut palm: leaning segmented trunk + drooping multi-segment fronds."""
    r = random.Random(seed)
    p = []
    th = r.uniform(4.2, 5.6)
    segs = 7
    lean = r.uniform(0.25, 0.6)
    x = 0.0
    for i in range(segs):
        t = i / segs
        y = th * t + th / segs / 2
        x = lean * t * t
        rad = 0.2 - 0.07 * t
        p.append((cyl(x, y, 0, rad, th / segs + 0.04, seg=7), C["trunk"] if i % 2 else C["trunk2"]))
        p.append((cyl(x, y - th / segs / 2 + 0.02, 0, rad + 0.03, 0.06, seg=7), C["trunk2"]))
    tx, ty = lean, th
    n = 9
    for i in range(n):
        a = 2 * math.pi * i / n + r.uniform(-0.15, 0.15)
        seg_len = 0.75
        px, py, pz = tx, ty, 0.0
        pitch = r.uniform(0.15, 0.35)      # starts slightly upward, then droops
        for k in range(4):
            w = 0.55 - k * 0.1
            leaf = box(seg_len / 2, 0, 0, seg_len, 0.05, w)
            leaf = rotate_mesh(leaf, rz=pitch)
            leaf = rotate_mesh(leaf, ry=-a)
            leaf = ([(vx + px, vy + py, vz + pz) for (vx, vy, vz) in leaf[0]], leaf[1], leaf[2])
            p.append((leaf, C["leaf"] if (i + k) % 2 else C["leaf2"]))
            px += math.cos(a) * math.cos(pitch) * seg_len
            pz += math.sin(a) * math.cos(pitch) * seg_len
            py += math.sin(pitch) * seg_len
            pitch -= 0.38
    for i in range(4):
        a = i * 1.6
        p.append((cyl(tx + math.cos(a) * 0.2, ty - 0.2, math.sin(a) * 0.2, 0.13, 0.22, seg=6), C["coco"]))
    return p


def railing():
    """Lagoon-bridge edge for one chunk: concrete balustrade + deck edge beam, x>0 side."""
    p = []
    x = SIDEWALK_OUT - 0.15
    p.append((box(x, -1.0, 0, 0.5, 2.1, LEN), C["concrete"], {"name": "bridge"}))     # deck edge
    p.append((box(x + 0.1, -1.6, 0, 0.7, 0.5, LEN), C["concrete_d"]))                    # beam lip
    p.append((box(x, 1.05, 0, 0.35, 0.14, LEN), C["frame"]))                            # handrail
    p.append((box(x, 0.3, 0, 0.35, 0.14, LEN), C["concrete"]))                          # base rail
    for i in range(16):
        z = -LEN / 2 + 0.375 + i * 0.75
        p.append((box(x, 0.68, z, 0.14, 0.62, 0.14), C["concrete"]))                    # balusters
    for z in (-LEN / 2 + 0.2, 0.0):
        p.append((box(x, 0.65, z, 0.4, 1.0, 0.4), C["concrete_d"]))                     # posts
    return p


def save(name, parts):
    os.makedirs(OUT, exist_ok=True)
    colored = [(item[0], item[1], item[2] if len(item) > 2 else {}) for item in parts]
    save_static(os.path.join(OUT, name + ".glb"), colored, name)
    print("  ->", name)


if __name__ == "__main__":
    print("environment:")
    save("road", road_segment())
    save("kiosk", kiosk())
    save("railing", railing())
    for i in range(4):
        save("tower_%d" % i, tower(seed=i * 13 + 5))
    for i in range(3):
        save("palm_%d" % i, palm(seed=i * 11 + 5))
    print("done.")
