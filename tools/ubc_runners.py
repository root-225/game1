"""Build the Abidjan Runner characters from Quaternius Universal Base Characters (CC0).

For each skin:
  * skin tone -> deep brown; clothes painted into the body texture per body region
    (wax / kente / bazin patterns or plain fabric), normal map flattened under clothes
  * extra skinned geometry: boubou robe, pagne skirt, kufi, gele head wrap, hair, bun
  * animations retargeted from source_models/runner_base.glb (idle, run, jump, slide,
    hit, death, cheer, land) + relaxed finger curl
Outputs assets/thirdparty/quaternius/runner_<skin>.glb (+ textures next to it).
"""
import os, math, array, json, collections
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from ubc_common import load, prim_arrays, region, UBC
from rigmath import Rig, q_mul, q_inv, q_norm, q_axis, quat_from_mat
from retarget import Baker, write_frames, FPS
from prune_gltf import read_glb, write_glb, prune
from dress_runner import sphere
from gltf_builder import srgb_to_linear
import patterns

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "thirdparty", "quaternius")
TEX = 1024
SRC_ANIM = os.path.join(HERE, "source_models", "runner_base.glb")

MAP = {"pelvis": "pelvis", "spine_01": "spine_01", "spine_02": "spine_03", "neck_01": "neck_01",
       "head": "Head"}
for s in ("l", "r"):
    for a, b in (("clavicle", "clavicle"), ("upperarm", "upperarm"), ("lowerarm", "lowerarm"),
                 ("hand", "hand"), ("thigh", "thigh"), ("calf", "calf"), ("foot", "foot"), ("ball", "ball")):
        MAP[f"{a}.{s}"] = f"{b}_{s}"

WAX_A = ["f29f05", "1d4e89", "c1272d", "fdf6e3"]
WAX_B = ["0b7a75", "f2b705", "d94f04", "ffffff"]
WAX_C = ["7a1f5c", "f2b705", "1b9e77", "fdf1e0"]

SKINS = {
    "urban": {  # young man: short-sleeve wax shirt, jeans, white sneakers
        "body": "Superhero_Male_FullBody", "sex": "m", "albedo": "T_Superhero_Male_Dark.png",
        "normal": "T_Superhero_Male_Normal.png", "skin": (92, 58, 40),
        "pattern": ("wax", WAX_A, 3),
        "paint": {"chest": "pat", "belly": "pat", "arm_up": "pat", "waist": "#2e4a7d", "hips": "#2e4a7d",
                  "thigh_up": "#2e4a7d", "thigh_low": "#2e4a7d", "shin_up": "#2e4a7d", "shin_low": "#2e4a7d",
                  "foot": "#f2f2f2", "sole": "#c8372d"},
        "acc": ["hair_short"],
    },
    "trad": {  # grand boubou in blue bazin with gold embroidery + kufi
        "body": "Superhero_Male_FullBody", "sex": "m", "albedo": "T_Superhero_Male_Dark.png",
        "normal": "T_Superhero_Male_Normal.png", "skin": (84, 52, 36),
        "pattern": ("embroidery", "2a3f8f", 4),
        "paint": {"chest": "pat", "belly": "pat", "arm_up": "pat", "arm_mid": "pat", "forearm": "pat",
                  "neck": "skin", "waist": "pat", "hips": "pat", "thigh_up": "pat", "thigh_low": "pat",
                  "shin_up": "#2a3f8f", "shin_low": "#2a3f8f", "foot": "#6b4423", "sole": "#3b2414"},
        "acc": ["hair_short", "robe", "kufi"],
    },
    "foot": {  # young woman footballer: Elephants orange jersey, white shorts, orange socks
        "body": "Superhero_Female_FullBody", "sex": "f", "albedo": "T_Superhero_Female_Dark_BaseColor.png",
        "normal": "T_Superhero_Female_Normal.png", "skin": (100, 64, 44),
        "pattern": ("kente", None, 4),
        "paint": {"chest": "#f58220", "belly": "#f58220", "arm_up": "#f58220", "waist": "#fafafa",
                  "hips": "#fafafa", "thigh_up": "#fafafa", "shin_up": "#f58220", "shin_low": "#f58220",
                  "foot": "#1c1c1c", "sole": "#fafafa"},
        "acc": ["hair_bun"],
    },
    "biz": {  # woman in a wax pagne dress with a gele head wrap
        "body": "Superhero_Female_FullBody", "sex": "f", "albedo": "T_Superhero_Female_Dark_BaseColor.png",
        "normal": "T_Superhero_Female_Normal.png", "skin": (106, 68, 46),
        "pattern": ("wax", WAX_C, 3),
        "paint": {"chest": "pat", "belly": "pat", "arm_up": "pat", "waist": "pat", "hips": "pat",
                  "thigh_up": "pat", "thigh_low": "pat", "foot": "#7a4a22", "sole": "#3b2414"},
        "acc": ["skirt", "gele"],
    },
}


def hex_rgb(h):
    h = h.lstrip("#"); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def make_pattern(spec, seed):
    kind, arg, _ = spec
    if kind == "wax": return patterns.wax(arg, seed=seed)
    if kind == "kente": return patterns.kente(seed=seed)
    return patterns.embroidery(arg)


# ----------------------------------------------------------------------------- textures
def surface_maps(a, dom_ids, size):
    """Rasterise the body into UV space: per-texel bind-pose position + dominant bone id."""
    pos = np.zeros((size, size, 3), np.float32)
    bone = np.full((size, size), -1, np.int32)
    uv = a["UV"] * size
    for t in a["I"]:
        p = uv[t]
        x0, y0 = np.floor(p.min(0)).astype(int) - 1
        x1, y1 = np.ceil(p.max(0)).astype(int) + 1
        x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        P3 = a["P"][t]
        val = w0[m, None] * P3[0] + w1[m, None] * P3[1] + w2[m, None] * P3[2]
        ys, xs = gy[m].astype(int), gx[m].astype(int)
        pos[ys, xs] = val
        bone[ys, xs] = collections.Counter(dom_ids[t].tolist()).most_common(1)[0][0]
    for _ in range(4):   # grow islands a few texels so seams never show skin
        empty = bone < 0
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = np.roll(bone, (dy, dx), (0, 1)); npos = np.roll(pos, (dy, dx), (0, 1))
            fill = empty & (nb >= 0)
            bone[fill] = nb[fill]; pos[fill] = npos[fill]
            empty = bone < 0
    return pos, bone


def texel_regions(pos, bone, names, sex):
    """Vectorised version of ubc_common.region() on texels -> dict name -> mask."""
    x, y = np.abs(pos[..., 0]), pos[..., 1]
    pre = np.array([n.split("_")[0] if n else "" for n in names] + [""])
    kind = pre[bone]          # bone == -1 -> "" (last entry)
    arm_cut = 0.33 if sex == "m" else 0.28
    R = {}
    R["head"] = kind == "Head"
    R["neck"] = kind == "neck"
    torso = (kind == "spine") | (kind == "clavicle")
    R["chest"] = torso & (y > 1.18); R["belly"] = torso & (y <= 1.18)
    R["waist"] = (kind == "pelvis") & (y > 0.93); R["hips"] = (kind == "pelvis") & (y <= 0.93)
    R["arm_up"] = (kind == "upperarm") & (x < arm_cut); R["arm_mid"] = (kind == "upperarm") & (x >= arm_cut)
    R["forearm"] = kind == "lowerarm"
    R["hand"] = np.isin(kind, ["hand", "thumb", "index", "middle", "ring", "pinky"])
    R["thigh_up"] = (kind == "thigh") & (y > 0.72); R["thigh_low"] = (kind == "thigh") & (y <= 0.72)
    R["shin_up"] = (kind == "calf") & (y > 0.3); R["shin_low"] = (kind == "calf") & (y <= 0.3)
    feet = np.isin(kind, ["foot", "ball"])
    R["sole"] = feet & (y < 0.035); R["foot"] = feet & (y >= 0.035)
    return R


def paint(cfg, a, dom_ids, names):
    base = Image.open(f"{UBC}/{cfg['albedo']}").convert("RGB").resize((TEX, TEX), Image.LANCZOS)
    alb = np.asarray(base, float)
    pos, bone = surface_maps(a, dom_ids, TEX)
    R = texel_regions(pos, bone, names, cfg["sex"])
    # skin tone: match the face average to the target colour
    head = alb[R["head"]]
    alb = alb * (np.array(cfg["skin"], float) / head.mean(0))[None, None, :]
    alb = np.clip(alb, 0, 255)
    lum = alb.mean(2)
    soft = np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)), float)
    pat = np.asarray(make_pattern(cfg["pattern"], 3).convert("RGB"), float)
    reps = cfg["pattern"][2]
    yy, xx = np.mgrid[0:TEX, 0:TEX]
    tiled = pat[(yy * reps * pat.shape[0] // TEX) % pat.shape[0], (xx * reps * pat.shape[1] // TEX) % pat.shape[1]]
    nrm = np.asarray(Image.open(f"{UBC}/{cfg['normal']}").convert("RGB").resize((TEX, TEX), Image.LANCZOS), float)
    flat = np.array([128, 128, 255], float)
    cloth_mask = np.zeros((TEX, TEX), bool)
    for name, m in R.items():
        spec = cfg["paint"].get(name)
        if spec is None or spec == "skin":
            continue
        if not m.any():
            continue
        shade = np.clip(soft[m] / max(soft[m].mean(), 1), 0.72, 1.18)[:, None]
        col = tiled[m] if spec == "pat" else hex_rgb(spec)[None, :]
        alb[m] = np.clip(col * shade, 0, 255)
        cloth_mask |= m
    # fabric: flatten muscle relief under clothes, add a faint weave
    weave = (np.sin(xx * 1.7) * np.sin(yy * 1.7) * 6)[..., None]
    nrm[cloth_mask] = (nrm[cloth_mask] * 0.15 + flat * 0.85 + weave[cloth_mask] * np.array([1, 1, 0]))
    return Image.fromarray(alb.astype(np.uint8)), Image.fromarray(np.clip(nrm, 0, 255).astype(np.uint8))


# ----------------------------------------------------------------------------- geometry
def ring_surface(y_top, y_bot, r_top, r_bot, zc, rings=8, segs=28, uv_rep=3.0):
    """Open frustum (robe / skirt). r = (rx, rz). Returns P, N, UV, I, t(height 0..1)."""
    P, N, UV, T, I = [], [], [], [], []
    for i in range(rings + 1):
        t = i / rings
        y = y_top + (y_bot - y_top) * t
        rx = r_top[0] + (r_bot[0] - r_top[0]) * t
        rz = r_top[1] + (r_bot[1] - r_top[1]) * t
        for s in range(segs + 1):
            a = 2 * math.pi * s / segs
            x, z = math.sin(a) * rx, math.cos(a) * rz + zc
            P.append((x, y, z))
            n = np.array([math.sin(a) / rx, 0.35 * (r_bot[0] - r_top[0]) / max(abs(y_bot - y_top), 1e-3), math.cos(a) / rz])
            N.append(tuple(n / np.linalg.norm(n)))
            UV.append((s / segs * uv_rep, t * uv_rep * 0.6))
            T.append(t)
    for i in range(rings):
        for s in range(segs):
            a = i * (segs + 1) + s; b = a + 1; c = a + segs + 1; d = c + 1
            I += [a, c, b, b, c, d]
    return P, N, UV, I, T


def sphere_uv(P, c, rep=2.0):
    out = []
    for p in P:
        v = np.array(p) - c
        out.append((math.atan2(v[0], v[2]) / (2 * math.pi) * rep + 0.5, -v[1] * rep * 2))
    return out


def scalp_shell(a, dom, head, offset, lift=0.0, hair_drop=0.0):
    """Offset the scalp triangles of the body along their normals (hair / caps / wraps).
    Hairline is higher at the front (forehead) and lower at the nape."""
    keep = np.zeros(len(a["P"]), bool)
    for v, d in enumerate(dom):
        if d != "Head" and d != "neck_01":
            continue
        x, y, z = a["P"][v]
        c = (z - head["zc"]) / max(head["rz"], 1e-3)          # +1 front, -1 back
        line = head["brow"] + 0.045 * max(c, 0) - (0.07 + hair_drop) * max(-c, 0) - 0.01 * (1 - abs(c))
        keep[v] = y > line
    tris = [t for t in a["I"] if keep[t].all()]
    used = sorted({int(v) for t in tris for v in t})
    remap = {v: i for i, v in enumerate(used)}
    top = head["top"]
    P, N = [], []
    for v in used:
        n = a["N"][v] / (np.linalg.norm(a["N"][v]) or 1)
        p = a["P"][v] + n * offset
        h = max(0.0, (p[1] - head["brow"]) / max(top - head["brow"], 1e-3))
        p = p + np.array([0, lift * h * h, 0])
        P.append(tuple(p)); N.append(tuple(n))
    I = [remap[int(v)] for t in tris for v in t]
    return P, N, I


def accessories(cfg, head, jn, a, dom):
    """Returns list of (kind, P, N, UV, I, joints, weights, colour_hex)."""
    out = []
    one = lambda n: ([(jn["Head"], 0, 0, 0)] * n, [(1.0, 0, 0, 0)] * n)
    hc = np.array([0.0, head["top"] - head["rz"], head["zc"]])
    def shell(kind, offset, col, lift=0.0, drop=0.0):
        P, N, I = scalp_shell(a, dom, head, offset, lift, drop)
        J, W = one(len(P))
        out.append((kind, P, N, sphere_uv(P, hc), I, J, W, col))
    def ball(kind, center, radii, col, rings=8, segs=18):
        P, N, I = sphere(np.array(center), radii, rings=rings, segs=segs)
        J, W = one(len(P))
        out.append((kind, P, N, sphere_uv(P, np.array(center)), I, J, W, col))
    if "hair_short" in cfg["acc"]:
        shell("vc", 0.007, "121010")
    if "hair_bun" in cfg["acc"]:
        shell("vc", 0.008, "121010", drop=0.02)
        ball("vc", [0, head["top"] - 0.015, head["zc"] - head["rz"] * 0.95], (0.058, 0.052, 0.058), "121010")
    if "kufi" in cfg["acc"]:
        shell("vc", 0.006, "121010")
        P, N, I = scalp_shell(a, dom, {**head, "brow": head["brow"] + 0.035}, 0.016, lift=0.012)
        J, W = one(len(P)); out.append(("pat", P, N, sphere_uv(P, hc), I, J, W, None))
    if "gele" in cfg["acc"]:
        P, N, I = scalp_shell(a, dom, {**head, "brow": head["brow"] + 0.012}, 0.028, lift=0.07, hair_drop=0.02)
        J, W = one(len(P)); out.append(("pat", P, N, sphere_uv(P, hc), I, J, W, None))
        for sx in (-1, 1):   # knot "wings" rising above the wrap
            ball("pat", [sx * 0.055, head["top"] + 0.075, head["zc"] + 0.01], (0.075, 0.045, 0.055), None, rings=6, segs=14)
    if "robe" in cfg["acc"] or "skirt" in cfg["acc"]:
        robe = "robe" in cfg["acc"]
        yt, yb = (1.02, 0.33) if robe else (0.99, 0.36)
        rt, rb = ((0.2, 0.15), (0.34, 0.25)) if robe else ((0.185, 0.14), (0.24, 0.175))
        P, N, UV, I, T = ring_surface(yt, yb, rt, rb, -0.04 if robe else -0.045)
        J, W = [], []
        for p, t in zip(P, T):
            rx = rt[0] + (rb[0] - rt[0]) * t
            sl = min(1.0, max(0.0, 0.5 + p[0] / (2 * rx) * 1.4))
            leg = min(0.85, t * 1.15)
            J.append((jn["pelvis"], jn["thigh_l"], jn["thigh_r"], 0))
            W.append((1 - leg, leg * sl, leg * (1 - sl), 0))
        out.append(("pat", P, N, UV, I, J, W, None))
    return out


# ----------------------------------------------------------------------------- animation
def retarget_all(tgt_rig):
    sj, sb = read_glb(SRC_ANIM)
    src = Rig(sj, sb)
    baker = Baker(tgt_rig)
    baker.pelvis = tgt_rig.name_to_node["pelvis"]
    s_idx = {src.nodes[i]["name"]: i for i in src.joints}
    t_idx = {tgt_rig.nodes[i]["name"]: i for i in tgt_rig.joints}
    sbr = {i: quat_from_mat(src.bind_world[i]) for i in src.joints}
    ratio = baker.bind_pos[baker.pelvis][1] / src.bind_world[s_idx["pelvis"]][1, 3]
    fingers = [n for n in t_idx if n.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb") and "leaf" not in n]
    clips = []
    for anim in sj["animations"]:
        length = src.anim_length(anim)
        frames = []
        for k in range(int(round(length * FPS)) + 1):
            t = min(length, k / FPS)
            sw = src.world_from_locals(src.sample_anim(anim, t))
            deltas = {}
            for sn, tn in MAP.items():
                si = s_idx[sn]
                deltas[t_idx[tn]] = q_norm(q_mul(quat_from_mat(sw[si]), q_inv(sbr[si])))
            for fn in fingers:   # relaxed fist: curl each phalanx toward the palm
                part, num, side = fn.split("_")
                curl = {"01": 30, "02": 70, "03": 100}.get(num, 0) * (0.45 if part == "thumb" else 1.0)
                hand = deltas[t_idx["hand_" + side]]
                deltas[t_idx[fn]] = q_mul(hand, q_axis((0, 0, 1), -curl if side == "l" else curl))
            off = (sw[s_idx["pelvis"]][:3, 3] - src.bind_world[s_idx["pelvis"]][:3, 3]) * ratio
            frames.append((t, baker.solve(deltas, off)))
        clips.append((anim["name"], frames))
    return baker, clips


# ----------------------------------------------------------------------------- assemble
def build(skin, cfg):
    j, b, rig = load(cfg["body"])
    names = [j["nodes"][i]["name"] for i in rig.joints]
    jn = {n: k for k, n in enumerate(names)}
    body_mesh_i = max(range(len(j["meshes"])), key=lambda i: j["accessors"][j["meshes"][i]["primitives"][0]["attributes"]["POSITION"]]["count"])
    body = j["meshes"][body_mesh_i]
    a = prim_arrays(rig, body["primitives"][0])
    dom = [names[a["J"][i][np.argmax(a["W"][i])]] for i in range(len(a["P"]))]
    labels = []
    for i, d in enumerate(dom):
        lab = region(d, a["P"][i], cfg["sex"])
        if lab == "foot" and a["P"][i][1] < 0.035:
            lab = "sole"
        labels.append(lab)
    hp = a["P"][[d == "Head" for d in dom]]
    brow_mesh = [m for m in j["meshes"] if m is not body][0]
    bm = j["accessors"][brow_mesh["primitives"][0]["attributes"]["POSITION"]]
    top = hp[:, 1].max()
    skull = hp[hp[:, 1] > top - 0.12]
    head = {"top": top, "brow": max(bm["max"][1] for m in [0]) if False else None,
            "zc": (skull[:, 2].min() + skull[:, 2].max()) / 2, "rz": (skull[:, 2].max() - skull[:, 2].min()) / 2}
    brows = [j["accessors"][m["primitives"][0]["attributes"]["POSITION"]] for m in j["meshes"] if m is not body]
    head["brow"] = max(acc["max"][1] for acc in brows) - 0.005

    os.makedirs(OUT, exist_ok=True)
    vdom = np.array([a["J"][v][np.argmax(a["W"][v])] for v in range(len(a["P"]))])
    alb, nrm = paint(cfg, a, vdom, names)
    alb.save(f"{OUT}/runner_{skin}_albedo.jpg", quality=90)
    nrm.save(f"{OUT}/runner_{skin}_normal.jpg", quality=92)
    pat = make_pattern(cfg["pattern"], 3).resize((512, 512))
    pat.save(f"{OUT}/runner_{skin}_fabric.jpg", quality=90)
    if not os.path.exists(f"{OUT}/eyes.jpg"):
        Image.open(f"{UBC}/T_Eye_Brown.png").convert("RGB").resize((256, 256)).save(f"{OUT}/eyes.jpg", quality=90)
    hair_img = [i["uri"] for i in j["images"] if "Hair" in i["uri"] and "Base" in i["uri"]][0]
    hsrc = Image.open(f"{UBC}/{hair_img.replace('_png.png', '.png')}").convert("RGBA").resize((256, 256))
    hr_ = np.asarray(hsrc, float); hr_[..., :3] *= 0.18
    Image.fromarray(hr_.astype(np.uint8)).save(f"{OUT}/brows_{cfg['sex']}.png")

    # ---- materials / textures (external files next to the .glb)
    orig_mat = [m.get("name", "") for m in j["materials"]]
    j["images"] = [{"uri": f"runner_{skin}_albedo.jpg"}, {"uri": f"runner_{skin}_normal.jpg"},
                   {"uri": f"runner_{skin}_fabric.jpg"}, {"uri": "eyes.jpg"}, {"uri": f"brows_{cfg['sex']}.png"}]
    j["samplers"] = [{"magFilter": 9729, "minFilter": 9987}]
    j["textures"] = [{"source": i, "sampler": 0} for i in range(5)]
    j["materials"] = [
        {"name": "body", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0, "roughnessFactor": 0.72},
         "normalTexture": {"index": 1, "scale": 1.0}},
        {"name": "fabric", "doubleSided": True, "pbrMetallicRoughness": {"baseColorTexture": {"index": 2}, "metallicFactor": 0, "roughnessFactor": 0.8}},
        {"name": "eyes", "pbrMetallicRoughness": {"baseColorTexture": {"index": 3}, "metallicFactor": 0, "roughnessFactor": 0.3}},
        {"name": "brows", "alphaMode": "MASK", "alphaCutoff": 0.4, "doubleSided": True,
         "pbrMetallicRoughness": {"baseColorTexture": {"index": 4}, "metallicFactor": 0, "roughnessFactor": 0.9}},
        {"name": "hair", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 0.95}},
    ]
    keep_attrs = ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0")
    for mi, m in enumerate(j["meshes"]):
        for p in m["primitives"]:
            p["attributes"] = {k: v for k, v in p["attributes"].items() if k in keep_attrs}
            if mi == body_mesh_i:
                p["material"] = 0
            else:   # UBC: eyes use MI_Eyes, eyebrows use the hair material
                p["material"] = 2 if "Eye" in orig_mat[p["material"]] else 3

    buf = bytearray(b)
    def add(vals, code, count, typ, comp, minmax=False):
        while len(buf) % 4: buf.append(0)
        arr = array.array(code, vals); off = len(buf); buf.extend(arr.tobytes())
        j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(arr) * arr.itemsize})
        acc = {"bufferView": len(j["bufferViews"]) - 1, "componentType": comp, "count": count, "type": typ}
        if minmax:
            mm = np.array(vals).reshape(count, -1)
            acc["min"] = [float(v) for v in mm.min(0)]; acc["max"] = [float(v) for v in mm.max(0)]
        j["accessors"].append(acc)
        return len(j["accessors"]) - 1

    groups = {"vc": [[], [], [], [], [], [], []], "pat": [[], [], [], [], [], [], []]}
    for kind, P, N, UV, I, J, W, col in accessories(cfg, head, jn, a, dom):
        g = groups[kind]; off = len(g[0])
        c = [srgb_to_linear(v / 255) for v in hex_rgb(col)] + [1.0] if col else [1, 1, 1, 1]
        g[0] += P; g[1] += N; g[2] += UV; g[3] += [v + off for v in I]; g[4] += J; g[5] += W; g[6] += [c] * len(P)
    for kind, g in groups.items():
        if not g[0]:
            continue
        n = len(g[0])
        attrs = {"POSITION": add([float(x) for v in g[0] for x in v], "f", n, "VEC3", 5126, True),
                 "NORMAL": add([float(x) for v in g[1] for x in v], "f", n, "VEC3", 5126),
                 "TEXCOORD_0": add([float(x) for v in g[2] for x in v], "f", n, "VEC2", 5126),
                 "JOINTS_0": add([int(x) for v in g[4] for x in v], "H", n, "VEC4", 5123),
                 "WEIGHTS_0": add([float(x) for v in g[5] for x in v], "f", n, "VEC4", 5126)}
        if kind == "vc":
            attrs["COLOR_0"] = add([float(x) for v in g[6] for x in v], "f", n, "VEC4", 5126)
        body["primitives"].append({"attributes": attrs, "indices": add(g[3], "H", len(g[3]), "SCALAR", 5123),
                                   "material": 4 if kind == "vc" else 1})

    # ---- animations
    baker, clips = retarget_all(rig)
    j["animations"] = []
    for name, frames in clips:
        write_frames(j, buf, name, frames, rig.joints, baker.pelvis)
    for jnode in rig.joints:
        nd = j["nodes"][jnode]
        nd.pop("matrix", None)
        nd["translation"] = [float(v) for v in baker.bind_local_t[jnode]]
        nd["rotation"] = [float(v) for v in baker.bind_local_r[jnode]]
        nd["scale"] = [1.0, 1.0, 1.0]
    j["buffers"] = [{"byteLength": len(buf)}]
    j, out = prune(j, bytes(buf), {c[0] for c in clips}, [])
    write_glb(f"{OUT}/runner_{skin}.glb", j, out)
    print(f"  -> runner_{skin}.glb  {len(out)//1024} KB, {len(clips)} clips")


if __name__ == "__main__":
    import sys
    only = sys.argv[1:] or list(SKINS)
    for s in only:
        build(s, SKINS[s])
