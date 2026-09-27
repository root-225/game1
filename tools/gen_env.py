"""Environment props: buildings, kiosk, taxi (wôrô-wôrô), bridge, palm, road, ground."""
import os, math, random
from gltf_builder import box, cyl, save_static, merge, translate_mesh

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "env")

C = dict(
    glass=[0.35, 0.55, 0.70, 1], glass2=[0.45, 0.65, 0.78, 1], concrete=[0.72, 0.72, 0.70, 1],
    concrete_d=[0.55, 0.55, 0.55, 1], roof=[0.60, 0.28, 0.20, 1], wood=[0.55, 0.36, 0.18, 1],
    orange=[0.95, 0.55, 0.10, 1], taxi=[0.95, 0.62, 0.10, 1], taxi_top=[0.15, 0.15, 0.18, 1],
    window=[0.20, 0.28, 0.35, 1], tire=[0.08, 0.08, 0.08, 1], chrome=[0.8, 0.8, 0.82, 1],
    trunk=[0.42, 0.28, 0.14, 1], leaf=[0.18, 0.55, 0.22, 1], leaf2=[0.22, 0.62, 0.26, 1],
    asphalt=[0.20, 0.20, 0.22, 1], line=[0.85, 0.82, 0.5, 1], curb=[0.6, 0.6, 0.6, 1],
    steel=[0.55, 0.58, 0.62, 1], cable=[0.3, 0.3, 0.32, 1], red=[0.85, 0.2, 0.2, 1],
    green=[0.2, 0.6, 0.3, 1], yellow=[0.95, 0.8, 0.2, 1], grass=[0.28, 0.42, 0.20, 1],
)


def building(seed=0):
    r = random.Random(seed)
    parts = []
    w = r.uniform(2.6, 3.6); d = r.uniform(2.6, 3.6); h = r.uniform(6, 12)
    body = box(0, h/2, 0, w, h, d)
    parts.append((body, C["glass"] if r.random() < 0.5 else C["concrete"]))
    # window bands
    floors = int(h / 1.2)
    for f in range(1, floors):
        y = f * 1.2
        parts.append((box(0, y, d/2 + 0.01, w * 0.86, 0.55, 0.02), C["window"]))
        parts.append((box(w/2 + 0.01, y, 0, 0.02, 0.55, d * 0.86), C["window"]))
    # rooftop
    parts.append((box(0, h + 0.25, 0, w * 0.5, 0.5, d * 0.5), C["concrete_d"]))
    parts.append((box(w*0.2, h + 0.9, d*0.2, 0.2, 1.2, 0.2), C["concrete_d"]))
    return parts


def kiosk():
    p = []
    p.append((box(0, 0.9, 0, 1.8, 1.6, 1.4), C["wood"]))
    p.append((box(0, 1.85, 0, 2.2, 0.25, 1.8), C["roof"]))
    # striped awning slats
    cols = [C["red"], C["yellow"], C["green"], C["glass"]]
    for i in range(5):
        p.append((box(-0.8 + i*0.4, 1.55, 0.85, 0.36, 0.5, 0.05), cols[i % len(cols)]))
    p.append((box(0, 1.1, 0.72, 1.5, 0.12, 0.1), C["concrete"]))  # counter
    p.append((box(0.7, 0.5, 0.75, 0.25, 0.4, 0.25), C["orange"]))  # crate
    return p


def taxi():
    p = []
    # body lower
    p.append((box(0, 0.45, 0, 1.5, 0.5, 3.0), C["taxi"]))
    # cabin
    p.append((box(0, 0.95, -0.1, 1.35, 0.55, 1.5), C["taxi"]))
    p.append((box(0, 0.98, -0.1, 1.2, 0.45, 1.4), C["window"]))
    p.append((box(0, 1.2, -0.1, 1.36, 0.06, 1.5), C["taxi_top"]))  # roof
    # hood/trunk
    p.append((box(0, 0.62, 1.25, 1.4, 0.2, 0.6), C["taxi"]))
    p.append((box(0, 0.62, -1.35, 1.4, 0.2, 0.5), C["taxi"]))
    # bumpers + lights
    p.append((box(0, 0.35, 1.55, 1.4, 0.18, 0.12), C["chrome"]))
    p.append((box(0, 0.35, -1.55, 1.4, 0.18, 0.12), C["chrome"]))
    p.append((box(0.5, 0.55, 1.52, 0.25, 0.15, 0.05), C["yellow"]))
    p.append((box(-0.5, 0.55, 1.52, 0.25, 0.15, 0.05), C["yellow"]))
    p.append((box(0.5, 0.55, -1.52, 0.25, 0.15, 0.05), C["red"]))
    p.append((box(-0.5, 0.55, -1.52, 0.25, 0.15, 0.05), C["red"]))
    # taxi sign
    p.append((box(0, 1.28, 0.3, 0.4, 0.12, 0.25), C["orange"]))
    # wheels
    for wx in (0.78, -0.78):
        for wz in (0.95, -0.95):
            p.append((cyl(wx, 0.28, wz, 0.32, 0.22, seg=10, axis='x'), C["tire"]))
            p.append((cyl(wx, 0.28, wz, 0.14, 0.24, seg=8, axis='x'), C["chrome"]))
    return p


def bridge():
    p = []
    # deck
    p.append((box(0, 0.4, 0, 8.0, 0.4, 4.0), C["concrete"]))
    p.append((box(0, 0.62, 1.9, 8.0, 0.25, 0.15), C["curb"]))
    p.append((box(0, 0.62, -1.9, 8.0, 0.25, 0.15), C["curb"]))
    # two pylons
    for px in (-2.2, 2.2):
        p.append((box(px, 3.5, 0, 0.5, 6.6, 0.5), C["steel"]))
        p.append((box(px, 7.0, 0, 0.8, 0.6, 0.8), C["steel"]))
        # cables (thin angled boxes)
        for i in range(4):
            off = 0.6 + i * 0.7
            p.append((box(px, 4.0, off * (1 if px > 0 else 1), 0.05, 5.5, 0.05), C["cable"]))
            p.append((box(px, 4.0, -off, 0.05, 5.5, 0.05), C["cable"]))
    return p


def palm(seed=0):
    r = random.Random(seed)
    p = []
    th = r.uniform(3.0, 4.2)
    # trunk segments (slight lean)
    segs = 6
    x = 0
    for i in range(segs):
        y = 0.3 + i * (th / segs)
        x += r.uniform(-0.03, 0.06)
        p.append((cyl(x, y, 0, 0.16 - i * 0.012, th / segs + 0.02, seg=6), C["trunk"]))
    topx, topy = x, 0.3 + th
    # fronds
    for i in range(7):
        a = 2 * math.pi * i / 7
        dx, dz = math.cos(a), math.sin(a)
        frond = box(topx + dx * 0.9, topy - 0.1 + (0.2 if i % 2 else 0), dz * 0.9, 1.6, 0.08, 0.35)
        # tilt by translating; keep simple flat fan
        p.append((frond, C["leaf"] if i % 2 else C["leaf2"]))
    p.append((cyl(topx, topy, 0, 0.18, 0.2, seg=6), C["trunk"]))
    # coconuts
    for i in range(3):
        a = i * 2.1
        p.append((cyl(topx + math.cos(a)*0.18, topy - 0.15, math.sin(a)*0.18, 0.1, 0.16, seg=6), C["trunk"]))
    return p


def road_segment():
    """One reusable road chunk, 3 lanes wide, length 12, origin at center. +Y up."""
    p = []
    LEN = 12.0; W = 7.2
    p.append((box(0, -0.05, 0, W, 0.1, LEN), C["asphalt"]))
    # lane divider dashes (x = +-1.2)
    for lx in (-1.2, 1.2):
        for i in range(6):
            z = -LEN/2 + 1.0 + i * 2.0
            p.append((box(lx, 0.01, z, 0.12, 0.02, 0.9), C["line"]))
    # curbs + sidewalk
    for sx in (-1, 1):
        p.append((box(sx * (W/2 + 0.4), 0.08, 0, 0.8, 0.24, LEN), C["curb"]))
        p.append((box(sx * (W/2 + 1.6), 0.02, 0, 1.6, 0.12, LEN), C["concrete"]))
    return p


def ground_tile():
    p = [(box(0, -0.2, 0, 60, 0.3, 60), C["grass"])]
    return p


def save(name, parts, **kw):
    os.makedirs(OUT, exist_ok=True)
    colored = [(m, c) for (m, c) in parts]
    save_static(os.path.join(OUT, name + ".glb"), colored, name)
    print("  ->", name)


if __name__ == "__main__":
    print("environment:")
    save("road", road_segment())
    save("ground", ground_tile())
    save("kiosk", kiosk())
    save("taxi", taxi())
    save("bridge", bridge())
    for i in range(3):
        save("building_%d" % i, building(seed=i * 7 + 3))
    for i in range(2):
        save("palm_%d" % i, palm(seed=i * 11 + 5))
    print("done.")
