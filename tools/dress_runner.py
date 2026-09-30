"""Dress the retargeted Mannequiny (CC-BY 4.0, GDQuest) into Abidjan Runner skins.

* every vertex gets a colour from its dominant bone + position (shirt, sleeves, shorts,
  socks, shoes, collar, tie...), written as COLOR_0 -> one material, one draw call
* accessories (hair, cap, kufi, headband, glasses, eyebrows) are generated and skinned
  rigidly to the head bone inside the same primitive

python3 dress_runner.py runner_base.glb OUT_DIR
"""
import sys, os, math, array
import numpy as np
from prune_gltf import read_glb, write_glb, prune
from rigmath import Rig
from gltf_builder import box, cyl, srgb_to_linear


def hexc(h):
    return np.array([srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)] + [1.0])


def sphere(c, r, rings=10, segs=18, y_min=-1.0, y_max=1.0):
    """UV sphere (radii r=(rx,ry,rz)) keeping latitude band y_min..y_max (unit sphere y)."""
    P, N, I = [], [], []
    lats = [y_min + (y_max - y_min) * i / rings for i in range(rings + 1)]
    for yv in lats:
        rad = math.sqrt(max(0.0, 1 - yv * yv))
        for s in range(segs):
            a = 2 * math.pi * s / segs
            u = np.array([math.cos(a) * rad, yv, math.sin(a) * rad])
            P.append(tuple(c + u * r))
            n = u / np.array(r); n /= np.linalg.norm(n) or 1
            N.append(tuple(n))
    for i in range(rings):
        for s in range(segs):
            a = i * segs + s; b = i * segs + (s + 1) % segs
            c_ = (i + 1) * segs + s; d = (i + 1) * segs + (s + 1) % segs
            I += [a, c_, b, b, c_, d]
    return P, N, I


SKIN = "a36c47"
HAIR = "141010"

# region(v) -> colour key; each skin maps keys to colours + adds accessories
def regions(dom, p, head):
    x, y, z = p
    if dom in ("head", "neck_01"):
        hy0, hy1 = head["ymin"], head["ymax"]
        h = (y - hy0) / (hy1 - hy0)
        if dom == "head" and (h > 0.66 or (z < head["zc"] - 0.02 and h > 0.3)):
            return "hair"
        return "skin"
    if dom.startswith(("spine", "clavicle")):
        if y > 1.44 and abs(x) < 0.07 and z > 0.02:
            return "collar"
        if abs(x) < 0.022 and z > 0.05 and y > 1.2:
            return "tie"
        if y < 1.12:
            return "waist"
        return "shirt"
    if dom.startswith("upperarm"):
        return "sleeve_up" if abs(x) < 0.36 else "sleeve_low"
    if dom.startswith("lowerarm"):
        return "forearm"
    if dom.startswith(("hand", "thumb", "index", "middle", "ring", "pinky")):
        return "skin"
    if dom == "pelvis":
        return "belt" if y > 1.0 else "pants_top"
    if dom.startswith("thigh"):
        return "thigh_up" if y > 0.68 else "thigh_low"
    if dom.startswith("calf"):
        return "calf_up" if y > 0.28 else "calf_low"
    if dom.startswith(("foot", "ball")):
        return "sole" if y < 0.035 else "shoe"
    return "shirt"


SKINS = {
    "urban": {  # hoodie-less street look: blue tee, jeans, red sneakers, backwards cap
        "colors": {"skin": SKIN, "hair": HAIR, "shirt": "2f7fd8", "collar": "2f7fd8", "tie": "2f7fd8",
                   "waist": "2f7fd8", "sleeve_up": "2f7fd8", "sleeve_low": SKIN, "forearm": SKIN,
                   "belt": "3a2a20", "pants_top": "3d5b8c", "thigh_up": "3d5b8c", "thigh_low": "3d5b8c",
                   "calf_up": "3d5b8c", "calf_low": "3d5b8c", "shoe": "e0413a", "sole": "f4f4f4"},
        "acc": ["brows", "cap"], "cap": "e0413a",
    },
    "trad": {  # orange boubou with green embroidery, cream trousers, kufi
        "colors": {"skin": SKIN, "hair": HAIR, "shirt": "f28a1a", "collar": "1e9b56", "tie": "1e9b56",
                   "waist": "f28a1a", "sleeve_up": "f28a1a", "sleeve_low": "f28a1a", "forearm": "f28a1a",
                   "belt": "f28a1a", "pants_top": "f28a1a", "thigh_up": "f28a1a", "thigh_low": "1e9b56",
                   "calf_up": "efe4cc", "calf_low": "efe4cc", "shoe": "6b4423", "sole": "3b2414"},
        "acc": ["brows", "kufi"], "kufi": "1e9b56",
    },
    "foot": {  # Elephants orange jersey, white shorts, orange socks, black boots, headband
        "colors": {"skin": SKIN, "hair": HAIR, "shirt": "f58220", "collar": "1e9b56", "tie": "f58220",
                   "waist": "f58220", "sleeve_up": "f58220", "sleeve_low": "1e9b56", "forearm": SKIN,
                   "belt": "fafafa", "pants_top": "fafafa", "thigh_up": "fafafa", "thigh_low": SKIN,
                   "calf_up": "f58220", "calf_low": "f58220", "shoe": "1c1c1c", "sole": "fafafa"},
        "acc": ["brows", "headband"], "headband": "1e9b56",
    },
    "biz": {  # navy suit, white collar, red tie, brown shoes, glasses
        "colors": {"skin": SKIN, "hair": HAIR, "shirt": "34466b", "collar": "f2f2f2", "tie": "c8262c",
                   "waist": "34466b", "sleeve_up": "34466b", "sleeve_low": "34466b", "forearm": "34466b",
                   "belt": "1b1b1f", "pants_top": "34466b", "thigh_up": "34466b", "thigh_low": "34466b",
                   "calf_up": "34466b", "calf_low": "34466b", "shoe": "4a2c1a", "sole": "1a1a1a"},
        "acc": ["brows", "glasses"],
    },
}


def accessories(cfg, head, front_z):
    out = []  # (mesh, colour_hex)
    cx, cy, cz = 0.0, head["yc"], head["zc"]
    top = head["ymax"]
    hair = HAIR
    # short hair volume: slightly larger cap over the skull top/back
    out.append((sphere(np.array([cx, cy + 0.01, cz - 0.004]), (0.107, 0.142, 0.132), rings=6, y_min=0.25, y_max=1.0), hair))
    # face: white eyes with dark pupils, small mouth
    for sx in (-1, 1):
        ex, ey = sx * 0.036, 1.655
        zf = front_z(ex, ey)
        out.append((sphere(np.array([ex, ey, zf - 0.006]), (0.018, 0.014, 0.012), rings=6, segs=12), "f6f2ea"))
        out.append((sphere(np.array([ex, ey - 0.001, zf + 0.004]), (0.0085, 0.0095, 0.006), rings=5, segs=10), "1a0f0a"))
    zm = front_z(0.0, 1.585)
    out.append((box(0, 1.585, zm + 0.002, 0.034, 0.007, 0.008), "5a2320"))
    if "brows" in cfg["acc"]:
        for sx in (-1, 1):
            zf = front_z(sx * 0.038, 1.692)
            out.append((box(sx * 0.038, 1.692, zf + 0.004, 0.036, 0.009, 0.012), hair))
    if "cap" in cfg["acc"]:
        out.append((sphere(np.array([cx, cy + 0.02, cz]), (0.112, 0.13, 0.136), rings=7, y_min=0.2, y_max=1.0), cfg["cap"]))
        out.append((box(0, cy + 0.05, cz - 0.15, 0.13, 0.014, 0.1), cfg["cap"]))       # brim worn backwards
        out.append((box(0, top + 0.003, cz, 0.022, 0.012, 0.022), "f4f4f4"))            # button
    if "kufi" in cfg["acc"]:
        out.append((cyl(cx, top - 0.028, cz, 0.114, 0.07, seg=20), cfg["kufi"]))
        out.append((cyl(cx, top - 0.056, cz, 0.117, 0.012, seg=20), "f2c230"))          # gold band
    if "headband" in cfg["acc"]:
        out.append((cyl(cx, 1.715, cz, 0.108, 0.028, seg=18), cfg["headband"]))
    if "glasses" in cfg["acc"]:
        for sx in (-1, 1):
            zf = front_z(sx * 0.036, 1.655)
            out.append((box(sx * 0.036, 1.655, zf + 0.008, 0.044, 0.028, 0.006), "101010"))
        zf = front_z(0.0, 1.66)
        out.append((box(0, 1.662, zf + 0.008, 0.03, 0.006, 0.006), "101010"))
    return out


def dress(base_path, out_path, cfg):
    j, b = read_glb(base_path)
    rig = Rig(j, b)
    names = [j["nodes"][i]["name"] for i in rig.joints]
    head_ji = names.index("head")
    mesh = j["meshes"][j["nodes"][rig.mesh_node]["mesh"]]
    P, N, J, W, I, C = [], [], [], [], [], []
    prims = mesh["primitives"]
    heads = []
    data = []
    for k, pr in enumerate(prims):
        p = np.array(rig.accessor(pr["attributes"]["POSITION"])).reshape(-1, 3)
        n = np.array(rig.accessor(pr["attributes"]["NORMAL"])).reshape(-1, 3)
        jj = np.array(rig.accessor(pr["attributes"]["JOINTS_0"])).reshape(-1, 4)
        ww = np.array(rig.accessor(pr["attributes"]["WEIGHTS_0"])).reshape(-1, 4)
        idx = rig.accessor(pr["indices"])
        data.append((k, p, n, jj, ww, idx))
        dom = np.array([jj[i][np.argmax(ww[i])] for i in range(len(p))])
        if k == 0:
            heads = p[dom == head_ji]
    head = {"ymin": heads[:, 1].min(), "ymax": heads[:, 1].max(), "zc": (heads[:, 2].min() + heads[:, 2].max()) / 2}
    head["yc"] = (head["ymin"] + head["ymax"]) / 2

    def front_z(x, y):
        d = np.hypot(heads[:, 0] - x, heads[:, 1] - y)
        near = heads[d < 0.02]
        return near[:, 2].max() if len(near) else head["zc"] + 0.12

    cols = {k: hexc(v) for k, v in cfg["colors"].items()}
    for k, p, n, jj, ww, idx in data:
        off = len(P)
        for i in range(len(p)):
            dom = names[jj[i][np.argmax(ww[i])]]
            if k == 1:          # mannequin ear discs -> skin
                col = cols["skin"]
            else:
                col = cols[regions(dom, p[i], head)]
            P.append(p[i]); N.append(n[i]); J.append(jj[i]); W.append(ww[i]); C.append(col)
        I += [v + off for v in idx]
    for (mp, mn, mi), hx in accessories(cfg, head, front_z):
        off = len(P)
        col = hexc(hx)
        for v, nn in zip(mp, mn):
            P.append(np.array(v)); N.append(np.array(nn)); J.append([head_ji, 0, 0, 0]); W.append([1, 0, 0, 0]); C.append(col)
        I += [v + off for v in mi]

    # write the single dressed primitive
    buf = bytearray(b)
    def add(arr, code, count, typ, comp, minmax=False):
        while len(buf) % 4: buf.append(0)
        a = array.array(code, arr); off = len(buf); buf.extend(a.tobytes())
        j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(a) * a.itemsize})
        acc = {"bufferView": len(j["bufferViews"]) - 1, "componentType": comp, "count": count, "type": typ}
        if minmax:
            m = np.array(arr).reshape(count, -1)
            acc["min"] = [float(v) for v in m.min(0)]; acc["max"] = [float(v) for v in m.max(0)]
        j["accessors"].append(acc)
        return len(j["accessors"]) - 1
    nv = len(P)
    attrs = {
        "POSITION": add([float(c) for v in P for c in v], "f", nv, "VEC3", 5126, True),
        "NORMAL": add([float(c) for v in N for c in v], "f", nv, "VEC3", 5126),
        "COLOR_0": add([float(c) for v in C for c in v], "f", nv, "VEC4", 5126),
        "JOINTS_0": add([int(c) for v in J for c in v], "H", nv, "VEC4", 5123),
        "WEIGHTS_0": add([float(c) for v in W for c in v], "f", nv, "VEC4", 5126),
    }
    ind = add(I, "H" if nv < 65535 else "I", len(I), "SCALAR", 5123 if nv < 65535 else 5125)
    j["materials"] = [{"name": "runner", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1],
                       "metallicFactor": 0.0, "roughnessFactor": 0.62}}]
    mesh["primitives"] = [{"attributes": attrs, "indices": ind, "material": 0}]
    j.pop("textures", None); j.pop("images", None); j.pop("samplers", None)
    j["buffers"] = [{"byteLength": len(buf)}]
    j, out = prune(j, bytes(buf), {a["name"] for a in j["animations"]}, [])
    write_glb(out_path, j, out)
    print("  ->", os.path.basename(out_path), "%d verts" % nv, "%d KB" % (len(out) // 1024))


if __name__ == "__main__":
    base, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for name, cfg in SKINS.items():
        dress(base, os.path.join(out_dir, "runner_%s.glb" % name), cfg)
