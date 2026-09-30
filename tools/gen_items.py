"""Obstacles (8), collectibles (5) and power-ups (3) as low-poly .glb."""
import os, math
from gltf_builder import box, cyl, save_static, merge, rotate_mesh, translate_mesh

OUT_O = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "obstacles")
OUT_C = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "collectibles")

C = dict(
    orange=[0.95, 0.5, 0.1, 1], white=[0.95, 0.95, 0.95, 1], black=[0.1, 0.1, 0.1, 1],
    red=[0.85, 0.2, 0.2, 1], tire=[0.09, 0.09, 0.09, 1], metal=[0.5, 0.52, 0.55, 1],
    drum=[0.2, 0.3, 0.5, 1], taxi=[0.95, 0.62, 0.1, 1], wood=[0.55, 0.36, 0.18, 1],
    dark=[0.12, 0.12, 0.14, 1], oil=[0.05, 0.05, 0.06, 1], cone=[0.95, 0.45, 0.08, 1],
    gold=[1.0, 0.82, 0.15, 1], gold_d=[0.85, 0.6, 0.1, 1], coco=[0.5, 0.34, 0.18, 1],
    cocoflesh=[0.95, 0.95, 0.9, 1], alloco=[0.9, 0.6, 0.15, 1], bag=[0.9, 0.88, 0.8, 1],
    chili=[0.85, 0.15, 0.12, 1], leaf=[0.2, 0.55, 0.25, 1], phone=[0.15, 0.16, 0.2, 1],
    screen=[0.3, 0.7, 0.95, 1], magnet=[0.8, 0.15, 0.15, 1], magnet2=[0.85, 0.85, 0.88, 1],
    shield=[0.2, 0.6, 0.95, 1], star=[1.0, 0.85, 0.2, 1], cloth=[0.9, 0.3, 0.4, 1],
    canvas=[0.85, 0.82, 0.7, 1], wood_d=[0.36, 0.22, 0.12, 1], plantain_g=[0.45, 0.62, 0.18, 1],
    pagne1=[0.92, 0.42, 0.08, 1], pagne2=[0.08, 0.45, 0.28, 1], pagne3=[0.95, 0.80, 0.12, 1], pagne4=[0.55, 0.12, 0.35, 1],
)


def save(out, name, parts, unlit_all=False):
    os.makedirs(out, exist_ok=True)
    colored = [(m, c, {"unlit": unlit_all, "emissive": [x*0.4 for x in c[:3]] if unlit_all else None}) for (m, c) in parts]
    save_static(os.path.join(out, name + ".glb"), colored, name)
    print("  ->", name)


# ------------------------------------------------------------ obstacles (JUMP)
def barrier():  # roadwork barrier - jump
    p = []
    for sx in (-0.8, 0.8):
        p.append((box(sx, 0.5, 0, 0.12, 1.0, 0.12), C["metal"]))
    for i, y in enumerate((0.85, 0.55)):
        p.append((box(0, y, 0, 1.8, 0.22, 0.08), C["white"] if i % 2 else C["orange"]))
    # stripes
    for i in range(5):
        p.append((box(-0.7 + i*0.35, 0.85, 0.05, 0.16, 0.2, 0.02), C["orange"] if i % 2 else C["white"]))
    return p


def pothole():  # nid-de-poule flat on ground - jump
    p = [(box(0, 0.02, 0, 1.6, 0.06, 1.4), C["dark"])]
    p.append((box(0, 0.05, 0, 1.2, 0.04, 1.0), C["oil"]))
    p.append((box(0.3, 0.06, 0.2, 0.5, 0.03, 0.4), C["black"]))
    return p


def tire_pile():  # jump
    p = []
    p.append((cyl(0, 0.22, 0, 0.5, 0.35, seg=12), C["tire"]))
    p.append((cyl(0.15, 0.6, 0.1, 0.5, 0.35, seg=12), C["tire"]))
    p.append((cyl(-0.1, 0.95, -0.05, 0.5, 0.35, seg=12), C["tire"]))
    return p


def cone():  # traffic cone - jump
    p = []
    p.append((box(0, 0.03, 0, 0.7, 0.06, 0.7), C["cone"]))
    p.append((cyl(0, 0.35, 0, 0.28, 0.7, seg=8), C["cone"]))
    p.append((cyl(0, 0.45, 0, 0.22, 0.12, seg=8), C["white"]))
    p.append((cyl(0, 0.62, 0, 0.12, 0.35, seg=8), C["cone"]))
    return p


# ------------------------------------------------------------ obstacles (BLOCK lane)
def drum():  # oil drum - block
    p = [(cyl(0, 0.55, 0, 0.42, 1.1, seg=12), C["drum"])]
    p.append((cyl(0, 0.85, 0, 0.44, 0.06, seg=12), C["metal"]))
    p.append((cyl(0, 0.25, 0, 0.44, 0.06, seg=12), C["metal"]))
    p.append((box(0, 0.55, 0.42, 0.5, 0.4, 0.02), C["red"]))
    return p


def parked_taxi():  # block - a small taxi obstacle
    p = []
    p.append((box(0, 0.4, 0, 1.4, 0.45, 2.4), C["taxi"]))
    p.append((box(0, 0.8, -0.1, 1.25, 0.5, 1.2), C["taxi"]))
    p.append((box(0, 0.82, -0.1, 1.1, 0.4, 1.1), C["screen"]))
    p.append((box(0, 1.02, -0.1, 1.26, 0.05, 1.2), C["black"]))
    for wx in (0.72, -0.72):
        for wz in (0.8, -0.8):
            p.append((cyl(wx, 0.26, wz, 0.28, 0.2, seg=10, axis='x'), C["tire"]))
    p.append((box(0, 0.5, 1.25, 1.3, 0.16, 0.1), C["metal"]))
    return p


def cart():  # pousse-pousse handcart loaded with plantains - block
    p = []
    p.append((box(0, 0.62, 0, 1.3, 0.1, 1.6), C["wood"]))
    p.append((box(0.63, 0.82, 0, 0.06, 0.34, 1.6), C["wood_d"]))
    p.append((box(-0.63, 0.82, 0, 0.06, 0.34, 1.6), C["wood_d"]))
    p.append((box(0, 0.82, 0.78, 1.3, 0.34, 0.06), C["wood_d"]))
    for hx in (0.42, -0.42):  # handles
        p.append((box(hx, 0.72, -1.15, 0.07, 0.07, 0.9), C["wood_d"]))
    p.append((box(0, 0.72, -1.58, 0.9, 0.07, 0.07), C["wood_d"]))
    for wx in (0.74, -0.74):
        p.append((cyl(wx, 0.42, 0.15, 0.42, 0.1, seg=14, axis='x'), C["tire"]))
        p.append((cyl(wx, 0.42, 0.15, 0.12, 0.14, seg=8, axis='x'), C["metal"]))
    for i in range(9):  # plantain bunches, ripe and green
        x = -0.4 + (i % 3) * 0.4; z = -0.5 + (i // 3) * 0.5
        y = 0.78 + (0.12 if (i % 2) else 0.0)
        p.append((box(x, y, z, 0.34, 0.14, 0.42), C["alloco"] if i % 3 else C["plantain_g"]))
        p.append((box(x, y + 0.1, z + 0.1, 0.28, 0.1, 0.3), C["plantain_g"] if i % 3 else C["alloco"]))
    return p


def lowbar():  # overhead banner/roof-rack bar - ROLL under
    p = []
    for sx in (-1.0, 1.0):
        p.append((box(sx, 0.9, 0, 0.14, 1.8, 0.14), C["metal"]))
    p.append((box(0, 1.65, 0, 2.2, 0.45, 0.18), C["red"]))     # banner
    p.append((box(0, 1.65, 0.1, 1.8, 0.32, 0.02), C["canvas"]))
    for i in range(4):
        p.append((box(-0.6 + i*0.4, 1.65, 0.12, 0.3, 0.24, 0.01), [C["star"], C["screen"], C["alloco"], C["leaf"]][i]))
    return p


def stall():  # street-food stand (garba / alloco) with parasol - block
    p = []
    p.append((box(0, 0.75, 0.1, 1.7, 0.08, 0.9), C["wood"]))            # table top
    for lx in (-0.75, 0.75):
        for lz in (-0.25, 0.45):
            p.append((box(lx, 0.37, lz, 0.07, 0.74, 0.07), C["wood_d"]))
    pagne = [C["pagne1"], C["pagne2"], C["pagne3"], C["pagne4"]]
    for i in range(8):                                                   # pagne tablecloth
        p.append((box(-0.745 + i * 0.213, 0.56, 0.56, 0.213, 0.4, 0.02), pagne[i % 4]))
        p.append((box(-0.745 + i * 0.213, 0.44, 0.565, 0.213, 0.06, 0.02), pagne[(i + 2) % 4]))
    for i, col in enumerate((C["white"], C["red"], C["drum"])):          # bowls of food
        x = -0.5 + i * 0.5
        p.append((cyl(x, 0.86, 0.05, 0.19, 0.14, seg=12), col))
        p.append((cyl(x, 0.93, 0.05, 0.15, 0.04, seg=12), C["alloco"] if i != 1 else C["cocoflesh"]))
    p.append((box(0, 1.4, -0.3, 0.06, 1.3, 0.06), C["metal"]))           # parasol pole
    for i in range(8):                                                   # striped parasol
        a = i * math.pi / 4
        panel = box(0.55, 0, 0, 1.1, 0.04, 0.46)
        panel = rotate_mesh(panel, rz=-0.32)
        panel = rotate_mesh(panel, ry=-a)
        panel = translate_mesh(panel, 0, 2.1, -0.3)
        p.append((panel, C["red"] if i % 2 else C["star"]))
    p.append((cyl(0, 2.12, -0.3, 0.08, 0.1, seg=8), C["red"]))
    p.append((cyl(0.95, 0.25, -0.5, 0.18, 0.5, seg=10), C["pagne2"]))    # stool
    return p


# ------------------------------------------------------------ collectibles
def coin():  # CFA coin
    p = [(cyl(0, 0, 0, 0.32, 0.08, seg=14, axis='z'), C["gold"])]
    p.append((cyl(0, 0, 0.045, 0.22, 0.02, seg=14, axis='z'), C["gold_d"]))
    p.append((box(0, 0, 0.06, 0.12, 0.16, 0.01), C["gold_d"]))
    return p


def coconut():  # café / coco
    p = [(cyl(0, 0.28, 0, 0.3, 0.5, seg=10), C["coco"])]
    p.append((cyl(0, 0.55, 0, 0.14, 0.12, seg=8), C["cocoflesh"]))
    p.append((box(0, 0.62, 0, 0.03, 0.18, 0.03), C["metal"]))  # straw
    return p


def alloco():  # fried plantain in bag
    p = [(box(0, 0.2, 0, 0.5, 0.4, 0.35), C["canvas"])]
    for i in range(4):
        p.append((box(-0.15 + i*0.1, 0.42, 0, 0.09, 0.18, 0.09), C["alloco"]))
    return p


def akpakpa():  # snack bag
    p = [(box(0, 0.22, 0, 0.4, 0.44, 0.3), C["bag"])]
    p.append((box(0, 0.46, 0, 0.2, 0.12, 0.2), C["bag"]))
    p.append((box(0, 0.25, 0.16, 0.3, 0.2, 0.02), C["red"]))
    return p


def phone():  # bonus - smartphone
    p = [(box(0, 0.3, 0, 0.34, 0.6, 0.06), C["phone"])]
    p.append((box(0, 0.32, 0.035, 0.28, 0.5, 0.01), C["screen"]))
    return p


# ------------------------------------------------------------ power-ups
def pu_magnet():
    p = []
    p.append((box(-0.18, 0.35, 0, 0.16, 0.5, 0.16), C["magnet"]))
    p.append((box(0.18, 0.35, 0, 0.16, 0.5, 0.16), C["magnet"]))
    p.append((box(0, 0.55, 0, 0.52, 0.16, 0.16), C["magnet"]))
    p.append((box(-0.18, 0.12, 0, 0.16, 0.12, 0.16), C["magnet2"]))
    p.append((box(0.18, 0.12, 0, 0.16, 0.12, 0.16), C["magnet2"]))
    return p


def pu_shield():
    p = [(box(0, 0.4, 0, 0.55, 0.65, 0.12), C["shield"])]
    p.append((box(0, 0.42, 0.07, 0.35, 0.42, 0.02), C["white"]))
    p.append((box(0, 0.15, 0, 0.2, 0.2, 0.1), C["shield"]))
    return p


def pu_x2():
    p = [(cyl(0, 0.4, 0, 0.36, 0.14, seg=12, axis='z'), C["star"])]
    p.append((box(-0.1, 0.4, 0.08, 0.06, 0.28, 0.02), C["red"]))
    p.append((box(0.1, 0.4, 0.08, 0.06, 0.28, 0.02), C["red"]))
    p.append((box(0, 0.4, 0.08, 0.2, 0.06, 0.02), C["red"]))
    return p


if __name__ == "__main__":
    print("obstacles:")
    save(OUT_O, "barrier", barrier())
    save(OUT_O, "pothole", pothole())
    save(OUT_O, "tire", tire_pile())
    save(OUT_O, "cone", cone())
    save(OUT_O, "drum", drum())
    save(OUT_O, "cart", cart())
    save(OUT_O, "stall", stall())
    save(OUT_O, "lowbar", lowbar())
    print("collectibles + power-ups:")
    save(OUT_C, "coconut", coconut())
    save(OUT_C, "alloco", alloco())
    save(OUT_C, "akpakpa", akpakpa())
    save(OUT_C, "phone", phone(), unlit_all=True)
    save(OUT_C, "pu_magnet", pu_magnet(), unlit_all=True)
    save(OUT_C, "pu_shield", pu_shield(), unlit_all=True)
    save(OUT_C, "pu_x2", pu_x2(), unlit_all=True)
    print("done.")
