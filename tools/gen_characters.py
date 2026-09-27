"""Generate 4 rigged + animated low-poly characters as .glb.
Skins: urban (default), trad, foot, biz. Anims: run, jump, roll, hit, idle."""
import os, math
from gltf_builder import GLTF, box, merge

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "characters")

# ---- skeleton: (name, parent, world_x, world_y, world_z) -------------------
JOINTS = [
    ("hips",      None, 0.00, 0.95, 0.0),
    ("spine",     "hips", 0.00, 1.28, 0.0),
    ("head",      "spine", 0.00, 1.62, 0.0),
    ("shoulderL", "spine", 0.24, 1.44, 0.0),
    ("elbowL",    "shoulderL", 0.28, 1.14, 0.0),
    ("shoulderR", "spine", -0.24, 1.44, 0.0),
    ("elbowR",    "shoulderR", -0.28, 1.14, 0.0),
    ("thighL",    "hips", 0.13, 0.92, 0.0),
    ("shinL",     "thighL", 0.13, 0.50, 0.0),
    ("thighR",    "hips", -0.13, 0.92, 0.0),
    ("shinR",     "thighR", -0.13, 0.50, 0.0),
]
JIDX = {n: i for i, (n, *_ ) in enumerate(JOINTS)}
JPOS = {n: (x, y, z) for (n, p, x, y, z) in JOINTS}


def part(cx, cy, cz, sx, sy, sz, joint):
    m = box(cx, cy, cz, sx, sy, sz)
    return (m, joint)


def build_parts(pal, sleeve_full, legs_bare, accessories):
    skin, shirt, pants, shoe, hair = pal["skin"], pal["shirt"], pal["pants"], pal["shoe"], pal["hair"]
    leg_col = skin if legs_bare else pants
    fore_col = shirt if sleeve_full else skin
    P = []  # (mesh, joint, color)
    def add(cx, cy, cz, sx, sy, sz, joint, col):
        P.append((box(cx, cy, cz, sx, sy, sz), joint, col))
    # torso + pelvis
    add(0, 0.90, 0, 0.34, 0.24, 0.20, "hips", pants)
    add(0, 1.28, 0, 0.42, 0.46, 0.24, "spine", shirt)
    add(0, 1.10, 0.01, 0.30, 0.10, 0.24, "spine", shirt)  # belt/hem area
    # head + hair
    add(0, 1.66, 0, 0.26, 0.26, 0.25, "head", skin)
    add(0, 1.80, 0, 0.28, 0.08, 0.27, "head", hair)   # hair top
    add(0, 1.70, -0.12, 0.28, 0.20, 0.06, "head", hair)  # back hair
    # arms
    add(0.26, 1.30, 0, 0.11, 0.32, 0.12, "shoulderL", shirt if sleeve_full else shirt)  # upper sleeve
    add(0.29, 1.02, 0, 0.10, 0.30, 0.10, "elbowL", fore_col)  # forearm
    add(0.30, 0.86, 0, 0.11, 0.10, 0.12, "elbowL", skin)      # hand
    add(-0.26, 1.30, 0, 0.11, 0.32, 0.12, "shoulderR", shirt)
    add(-0.29, 1.02, 0, 0.10, 0.30, 0.10, "elbowR", fore_col)
    add(-0.30, 0.86, 0, 0.11, 0.10, 0.12, "elbowR", skin)
    # legs
    add(0.13, 0.70, 0, 0.15, 0.44, 0.16, "thighL", leg_col)
    add(0.13, 0.29, 0, 0.13, 0.44, 0.14, "shinL", leg_col if legs_bare else pants)
    add(0.13, 0.05, 0.05, 0.15, 0.10, 0.28, "shinL", shoe)
    add(-0.13, 0.70, 0, 0.15, 0.44, 0.16, "thighR", leg_col)
    add(-0.13, 0.29, 0, 0.13, 0.44, 0.14, "shinR", leg_col if legs_bare else pants)
    add(-0.13, 0.05, 0.05, 0.15, 0.10, 0.28, "shinR", shoe)
    for a in accessories:
        P.append((box(*a[:6]), a[6], a[7]))
    return P


# ---- animation authoring ---------------------------------------------------
def q_from_euler(rx, ry, rz):
    from gltf_builder import quat_euler
    return quat_euler(rx, ry, rz)


def sample(fn, period, n=10, loop=True):
    """Return (times, quats) sampling euler fn(phase)->(rx,ry,rz)."""
    times, quats = [], []
    steps = n
    for i in range(steps + (1 if loop else 0)):
        t = period * i / steps
        p = (i % steps) / steps if loop else i / steps
        rx, ry, rz = fn(p)
        times.append(t); quats.append(q_from_euler(rx, ry, rz))
    if not loop:
        # ensure last frame at period
        pass
    return times, quats


def anim_run(period=0.55):
    tau = 2 * math.pi
    ch = {}
    ch["thighL"] = lambda p: (0.75 * math.sin(tau * p), 0, 0)
    ch["thighR"] = lambda p: (0.75 * math.sin(tau * p + math.pi), 0, 0)
    ch["shinL"] = lambda p: (-0.55 * (1 - math.cos(tau * p)) * 0.6 - 0.15, 0, 0)
    ch["shinR"] = lambda p: (-0.55 * (1 - math.cos(tau * p + math.pi)) * 0.6 - 0.15, 0, 0)
    ch["shoulderL"] = lambda p: (0.7 * math.sin(tau * p + math.pi), 0, 0.05)
    ch["shoulderR"] = lambda p: (0.7 * math.sin(tau * p), 0, -0.05)
    ch["elbowL"] = lambda p: (-0.7, 0, 0)
    ch["elbowR"] = lambda p: (-0.7, 0, 0)
    ch["spine"] = lambda p: (0.18 + 0.05 * math.sin(2 * tau * p), 0, 0)
    ch["head"] = lambda p: (-0.1, 0, 0)
    ch["hips"] = lambda p: (0, 0.06 * math.sin(2 * tau * p), 0)
    return _build(ch, period, loop=True)


def anim_idle(period=2.2):
    tau = 2 * math.pi
    ch = {}
    ch["spine"] = lambda p: (0.04 + 0.03 * math.sin(tau * p), 0, 0)
    ch["shoulderL"] = lambda p: (0.06 * math.sin(tau * p), 0, 0.12)
    ch["shoulderR"] = lambda p: (0.06 * math.sin(tau * p), 0, -0.12)
    ch["head"] = lambda p: (0.02 * math.sin(tau * p), 0.05 * math.sin(tau * p * 0.5), 0)
    return _build(ch, period, loop=True)


def anim_jump(period=0.85):
    # key phases: 0 crouch, .35 launch, .7 airborne tuck, 1 land
    def lerp_keys(keys):
        def f(p):
            for i in range(len(keys) - 1):
                p0, v0 = keys[i]; p1, v1 = keys[i + 1]
                if p0 <= p <= p1:
                    t = (p - p0) / (p1 - p0) if p1 > p0 else 0
                    return v0 + (v1 - v0) * t
            return keys[-1][1]
        return f
    ch = {}
    ch["thighL"] = lerp_keys([(0, -0.5), (0.35, 0.2), (0.7, -0.8), (1, -0.3)])
    ch["thighR"] = lerp_keys([(0, -0.5), (0.35, 0.2), (0.7, -0.8), (1, -0.3)])
    ch["shinL"] = lerp_keys([(0, -0.9), (0.35, -0.2), (0.7, -1.2), (1, -0.5)])
    ch["shinR"] = lerp_keys([(0, -0.9), (0.35, -0.2), (0.7, -1.2), (1, -0.5)])
    ch["shoulderL"] = lerp_keys([(0, 0.3), (0.35, -1.6), (0.7, -1.9), (1, -0.2)])
    ch["shoulderR"] = lerp_keys([(0, 0.3), (0.35, -1.6), (0.7, -1.9), (1, -0.2)])
    ch["spine"] = lerp_keys([(0, 0.3), (0.35, -0.1), (0.7, 0.15), (1, 0.1)])
    return _build_scalar_x(ch, period, loop=False)


def anim_roll(period=0.6):
    def lerp_keys(keys):
        def f(p):
            for i in range(len(keys) - 1):
                p0, v0 = keys[i]; p1, v1 = keys[i + 1]
                if p0 <= p <= p1:
                    t = (p - p0) / (p1 - p0) if p1 > p0 else 0
                    return v0 + (v1 - v0) * t
            return keys[-1][1]
        return f
    ch = {}
    ch["hips"] = lerp_keys([(0, 0), (0.5, -math.pi), (1, -2 * math.pi)])  # forward somersault
    ch["thighL"] = lerp_keys([(0, -0.3), (0.4, -1.8), (0.8, -1.8), (1, -0.3)])
    ch["thighR"] = lerp_keys([(0, -0.3), (0.4, -1.8), (0.8, -1.8), (1, -0.3)])
    ch["shinL"] = lerp_keys([(0, -0.3), (0.4, -1.6), (1, -0.3)])
    ch["shinR"] = lerp_keys([(0, -0.3), (0.4, -1.6), (1, -0.3)])
    ch["spine"] = lambda p: 0.6
    ch["shoulderL"] = lambda p: -2.4
    ch["shoulderR"] = lambda p: -2.4
    return _build_scalar_x(ch, period, loop=False)


def anim_hit(period=0.7):
    def lerp_keys(keys):
        def f(p):
            for i in range(len(keys) - 1):
                p0, v0 = keys[i]; p1, v1 = keys[i + 1]
                if p0 <= p <= p1:
                    t = (p - p0) / (p1 - p0) if p1 > p0 else 0
                    return v0 + (v1 - v0) * t
            return keys[-1][1]
        return f
    ch = {}
    ch["spine"] = lerp_keys([(0, 0.1), (0.3, -0.5), (1, -0.4)])
    ch["head"] = lerp_keys([(0, 0), (0.3, -0.6), (1, -0.5)])
    ch["shoulderL"] = lerp_keys([(0, 0), (0.3, -2.4), (1, -2.0)])
    ch["shoulderR"] = lerp_keys([(0, 0), (0.3, -2.4), (1, -2.0)])
    ch["thighL"] = lerp_keys([(0, 0), (0.4, 0.5), (1, 0.3)])
    ch["thighR"] = lerp_keys([(0, 0), (0.4, -0.2), (1, 0.6)])
    ch["hips"] = lerp_keys([(0, 0), (1, 0.3)])
    return _build_scalar_x(ch, period, loop=False)


def _build(ch_fns, period, loop):
    out = {}
    for joint, fn in ch_fns.items():
        t, q = sample(fn, period, n=12, loop=loop)
        out[joint] = (t, q)
    return out


def _build_scalar_x(ch_fns, period, loop):
    # fns return a single float = rotation about X
    out = {}
    n = 14
    for joint, fn in ch_fns.items():
        times, quats = [], []
        for i in range(n + 1):
            p = i / n
            times.append(period * p)
            quats.append(q_from_euler(fn(p), 0, 0))
        out[joint] = (times, quats)
    return out


# ---- assemble one character ------------------------------------------------
def make_character(name, pal, sleeve_full=False, legs_bare=False, accessories=()):
    g = GLTF()
    # joint nodes (local translation = world - parent world)
    node_of = {}
    children = {n: [] for n, *_ in JOINTS}
    for (nm, parent, x, y, z) in JOINTS:
        if parent:
            px, py, pz = JPOS[parent]
            lt = (x - px, y - py, z - pz)
        else:
            lt = (x, y, z)
        idx = g.add_node(name=nm, translation=lt, rotation=(0, 0, 0, 1))
        node_of[nm] = idx
    # link children
    for (nm, parent, *_ ) in JOINTS:
        if parent:
            g.nodes[node_of[parent]].setdefault("children", []).append(node_of[nm])
    # skin joints order == JOINTS order
    joint_node_list = [node_of[n] for (n, *_ ) in JOINTS]
    ibms = []
    for (n, *_ ) in JOINTS:
        x, y, z = JPOS[n]
        ibms.append([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1])
    # geometry grouped by color
    parts = build_parts(pal, sleeve_full, legs_bare, accessories)
    groups = {}
    order = []
    for (mesh, joint, col) in parts:
        key = tuple(col)
        if key not in groups:
            groups[key] = {"pos": [], "nrm": [], "idx": [], "joints": [], "weights": []}
            order.append(key)
        gp = groups[key]
        pos, nrm, idx = mesh
        off = len(gp["pos"])
        gp["pos"] += pos; gp["nrm"] += nrm; gp["idx"] += [k + off for k in idx]
        j = JIDX[joint]
        gp["joints"] += [(j, 0, 0, 0)] * len(pos)
        gp["weights"] += [(1.0, 0.0, 0.0, 0.0)] * len(pos)
    prims = []
    for key in order:
        gp = groups[key]
        mi = g.material(list(key), rough=0.8)
        prims.append({"positions": gp["pos"], "normals": gp["nrm"], "indices": gp["idx"],
                      "joints": gp["joints"], "weights": gp["weights"], "material": mi})
    mesh_i = g.add_mesh(prims, name)
    skin_i = g.add_skin(joint_node_list, ibms, node_of["hips"])
    mesh_node = g.add_node(name="Body", mesh=mesh_i, skin=skin_i)
    root = g.add_node(name=name, children=[node_of["hips"], mesh_node])
    g.scene_roots.append(root)
    # animations
    for aname, data in (("run", anim_run()), ("idle", anim_idle()), ("jump", anim_jump()),
                        ("roll", anim_roll()), ("hit", anim_hit())):
        channels = []
        for joint, (t, q) in data.items():
            channels.append((node_of[joint], t, q))
        g.add_animation(aname, channels)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    g.save(path)
    print("  ->", os.path.relpath(path))


PALETTES = {
    "urban": dict(skin=[0.55, 0.34, 0.20, 1], shirt=[0.20, 0.45, 0.72, 1],
                  pants=[0.24, 0.30, 0.42, 1], shoe=[0.85, 0.20, 0.20, 1], hair=[0.08, 0.06, 0.05, 1]),
    "trad": dict(skin=[0.50, 0.30, 0.18, 1], shirt=[0.90, 0.55, 0.10, 1],
                 pants=[0.10, 0.10, 0.12, 1], shoe=[0.35, 0.22, 0.10, 1], hair=[0.06, 0.05, 0.04, 1]),
    "foot": dict(skin=[0.58, 0.36, 0.22, 1], shirt=[0.95, 0.75, 0.10, 1],
                 pants=[0.10, 0.35, 0.20, 1], shoe=[0.95, 0.95, 0.95, 1], hair=[0.05, 0.04, 0.03, 1]),
    "biz": dict(skin=[0.52, 0.32, 0.19, 1], shirt=[0.16, 0.17, 0.22, 1],
                pants=[0.12, 0.13, 0.17, 1], shoe=[0.05, 0.05, 0.05, 1], hair=[0.07, 0.05, 0.04, 1]),
}

if __name__ == "__main__":
    print("characters:")
    make_character("urban", PALETTES["urban"], sleeve_full=False, legs_bare=False)
    # trad: colorful dashiki accent stripe + cap
    make_character("trad", PALETTES["trad"], sleeve_full=True, legs_bare=False, accessories=[
        (0, 1.28, 0.13, 0.30, 0.30, 0.02, "spine", [0.15, 0.55, 0.35, 1]),   # embroidery panel
        (0, 1.83, 0, 0.30, 0.10, 0.30, "head", [0.90, 0.55, 0.10, 1]),        # kufi cap
    ])
    # foot: jersey number + socks (bare legs = shorts)
    make_character("foot", PALETTES["foot"], sleeve_full=False, legs_bare=True, accessories=[
        (0, 1.30, 0.13, 0.16, 0.20, 0.02, "spine", [0.10, 0.35, 0.20, 1]),    # number panel
        (0.13, 0.16, 0.05, 0.14, 0.16, 0.16, "shinL", [0.95, 0.75, 0.10, 1]), # sock L
        (-0.13, 0.16, 0.05, 0.14, 0.16, 0.16, "shinR", [0.95, 0.75, 0.10, 1]),# sock R
    ])
    # biz: tie + jacket lapels
    make_character("biz", PALETTES["biz"], sleeve_full=True, legs_bare=False, accessories=[
        (0, 1.24, 0.13, 0.05, 0.34, 0.02, "spine", [0.70, 0.12, 0.15, 1]),    # tie
        (0, 1.40, 0.12, 0.24, 0.06, 0.03, "spine", [0.92, 0.92, 0.95, 1]),    # collar
    ])
    print("done.")
