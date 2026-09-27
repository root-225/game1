"""Minimal, dependency-free glTF 2.0 (.glb) builder.

Supports flat-shaded low-poly meshes with per-primitive colored materials,
rigid skinning (one joint per vertex) and keyframed joint-rotation animations.
Everything Abidjan Runner needs, generated procedurally in pure Python.
"""
import struct, math, json, array

# ---------------------------------------------------------------- math helpers
def quat_axis_angle(ax, ay, az, ang):
    l = math.sqrt(ax*ax + ay*ay + az*az) or 1.0
    ax, ay, az = ax/l, ay/l, az/l
    s = math.sin(ang * 0.5)
    return (ax*s, ay*s, az*s, math.cos(ang * 0.5))

def quat_mul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return (aw*bx + ax*bw + ay*bz - az*by,
            aw*by - ax*bz + ay*bw + az*bx,
            aw*bz + ax*by - ay*bx + az*bw,
            aw*bw - ax*bx - ay*by - az*bz)

def quat_euler(rx, ry, rz):
    qx = quat_axis_angle(1, 0, 0, rx)
    qy = quat_axis_angle(0, 1, 0, ry)
    qz = quat_axis_angle(0, 0, 1, rz)
    return quat_mul(qz, quat_mul(qy, qx))

IDENT_QUAT = (0.0, 0.0, 0.0, 1.0)

# ---------------------------------------------------------------- geometry
def box(cx, cy, cz, sx, sy, sz):
    """Flat-shaded box centered at (cx,cy,cz) with full sizes sx,sy,sz.
    Returns (positions[list of (x,y,z)], normals, indices) with 24 verts."""
    hx, hy, hz = sx/2, sy/2, sz/2
    # 6 faces, each 4 verts (flat normals)
    faces = [
        # (normal, [corner offsets])
        ((0, 0, 1),  [(-hx,-hy, hz),( hx,-hy, hz),( hx, hy, hz),(-hx, hy, hz)]),
        ((0, 0,-1),  [( hx,-hy,-hz),(-hx,-hy,-hz),(-hx, hy,-hz),( hx, hy,-hz)]),
        ((1, 0, 0),  [( hx,-hy, hz),( hx,-hy,-hz),( hx, hy,-hz),( hx, hy, hz)]),
        ((-1,0, 0),  [(-hx,-hy,-hz),(-hx,-hy, hz),(-hx, hy, hz),(-hx, hy,-hz)]),
        ((0, 1, 0),  [(-hx, hy, hz),( hx, hy, hz),( hx, hy,-hz),(-hx, hy,-hz)]),
        ((0,-1, 0),  [(-hx,-hy,-hz),( hx,-hy,-hz),( hx,-hy, hz),(-hx,-hy, hz)]),
    ]
    pos, nrm, idx = [], [], []
    for n, corners in faces:
        base = len(pos)
        for (x, y, z) in corners:
            pos.append((x+cx, y+cy, z+cz)); nrm.append(n)
        idx += [base, base+1, base+2, base, base+2, base+3]
    return pos, nrm, idx


def cyl(cx, cy, cz, r, h, seg=8, axis='y'):
    """Flat-ish low-poly cylinder (seg sides) centered at c, height h along axis."""
    pos, nrm, idx = [], [], []
    hh = h/2
    ring_b, ring_t = [], []
    for i in range(seg):
        a = 2*math.pi*i/seg
        dx, dz = math.cos(a)*r, math.sin(a)*r
        if axis == 'y':
            ring_b.append((cx+dx, cy-hh, cz+dz)); ring_t.append((cx+dx, cy+hh, cz+dz))
        elif axis == 'x':
            ring_b.append((cx-hh, cy+dx, cz+dz)); ring_t.append((cx+hh, cy+dx, cz+dz))
        else:
            ring_b.append((cx+dx, cy+dz, cz-hh)); ring_t.append((cx+dx, cy+dz, cz+hh))
    # side quads (flat per face)
    for i in range(seg):
        j = (i+1) % seg
        b0, b1, t1, t0 = ring_b[i], ring_b[j], ring_t[j], ring_t[i]
        base = len(pos)
        # face normal
        ux, uy, uz = b1[0]-b0[0], b1[1]-b0[1], b1[2]-b0[2]
        vx, vy, vz = t0[0]-b0[0], t0[1]-b0[1], t0[2]-b0[2]
        nx, ny, nz = uy*vz-uz*vy, uz*vx-ux*vz, ux*vy-uy*vx
        ln = math.sqrt(nx*nx+ny*ny+nz*nz) or 1
        n = (nx/ln, ny/ln, nz/ln)
        for v in (b0, b1, t1, t0):
            pos.append(v); nrm.append(n)
        idx += [base, base+1, base+2, base, base+2, base+3]
    # caps
    for ring, ny, flip in ((ring_b, -1, True), (ring_t, 1, False)):
        cbase = len(pos)
        if axis == 'y':
            center = (cx, cy - hh if ny < 0 else cy + hh, cz); nvec = (0, ny, 0)
        elif axis == 'x':
            center = (cx - hh if ny < 0 else cx + hh, cy, cz); nvec = (ny, 0, 0)
        else:
            center = (cx, cy, cz - hh if ny < 0 else cz + hh); nvec = (0, 0, ny)
        pos.append(center); nrm.append(nvec)
        for v in ring:
            pos.append(v); nrm.append(nvec)
        for i in range(seg):
            j = (i+1) % seg
            if flip:
                idx += [cbase, cbase+1+j, cbase+1+i]
            else:
                idx += [cbase, cbase+1+i, cbase+1+j]
    return pos, nrm, idx


def translate_mesh(mesh, dx, dy, dz):
    pos, nrm, idx = mesh
    return ([(x+dx, y+dy, z+dz) for (x, y, z) in pos], nrm, idx)

def scale_mesh(mesh, s):
    pos, nrm, idx = mesh
    return ([(x*s, y*s, z*s) for (x, y, z) in pos], nrm, idx)


def merge(*meshes):
    P, N, I = [], [], []
    for pos, nrm, idx in meshes:
        off = len(P)
        P += pos; N += nrm; I += [k+off for k in idx]
    return P, N, I


# ---------------------------------------------------------------- glTF writer
class GLTF:
    def __init__(self):
        self.buf = bytearray()
        self.bufferViews = []
        self.accessors = []
        self.meshes = []
        self.materials = []
        self.nodes = []
        self.skins = []
        self.animations = []
        self.scene_roots = []
        self._matcache = {}

    def _align(self, n=4):
        while len(self.buf) % n:
            self.buf.append(0)

    def _view(self, data: bytes):
        self._align(4)
        off = len(self.buf)
        self.buf += data
        self.bufferViews.append({"buffer": 0, "byteOffset": off, "byteLength": len(data)})
        return len(self.bufferViews) - 1

    def _acc_f(self, values, ncomp, minmax=False):
        flat = array.array('f')
        for v in values:
            flat.extend(v if isinstance(v, (list, tuple)) else (v,))
        view = self._view(flat.tobytes())
        types = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4", 16: "MAT4"}
        acc = {"bufferView": view, "componentType": 5126, "count": len(values), "type": types[ncomp]}
        if minmax:
            cols = list(zip(*values))
            acc["min"] = [float(min(c)) for c in cols]
            acc["max"] = [float(max(c)) for c in cols]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def _acc_idx(self, idx):
        if max(idx) < 65535:
            a = array.array('H', idx); ct = 5123
        else:
            a = array.array('I', idx); ct = 5125
        view = self._view(a.tobytes())
        self.accessors.append({"bufferView": view, "componentType": ct, "count": len(idx), "type": "SCALAR"})
        return len(self.accessors) - 1

    def _acc_joints(self, joints):
        a = array.array('B')
        for j in joints:
            a.extend(j)
        view = self._view(a.tobytes())
        self.accessors.append({"bufferView": view, "componentType": 5121, "count": len(joints), "type": "VEC4"})
        return len(self.accessors) - 1

    def material(self, rgba, metallic=0.0, rough=0.85, emissive=None, unlit=False):
        key = (tuple(rgba), metallic, rough, tuple(emissive) if emissive else None, unlit)
        if key in self._matcache:
            return self._matcache[key]
        m = {"pbrMetallicRoughness": {"baseColorFactor": list(rgba),
             "metallicFactor": metallic, "roughnessFactor": rough},
             "doubleSided": False}
        if emissive:
            m["emissiveFactor"] = list(emissive)
        if unlit:
            m["extensions"] = {"KHR_materials_unlit": {}}
        self.materials.append(m)
        i = len(self.materials) - 1
        self._matcache[key] = i
        return i

    def add_mesh(self, prims, name=None):
        """prims: list of dict{positions,normals,indices,material,joints?,weights?}"""
        gprims = []
        for p in prims:
            attrs = {}
            attrs["POSITION"] = self._acc_f(p["positions"], 3, minmax=True)
            attrs["NORMAL"] = self._acc_f(p["normals"], 3)
            if "joints" in p:
                attrs["JOINTS_0"] = self._acc_joints(p["joints"])
                attrs["WEIGHTS_0"] = self._acc_f(p["weights"], 4)
            gp = {"attributes": attrs, "indices": self._acc_idx(p["indices"]), "material": p["material"]}
            gprims.append(gp)
        mesh = {"primitives": gprims}
        if name:
            mesh["name"] = name
        self.meshes.append(mesh)
        return len(self.meshes) - 1

    def add_node(self, name=None, mesh=None, translation=None, rotation=None,
                 scale=None, children=None, skin=None):
        n = {}
        if name: n["name"] = name
        if mesh is not None: n["mesh"] = mesh
        if skin is not None: n["skin"] = skin
        if translation: n["translation"] = list(translation)
        if rotation: n["rotation"] = list(rotation)
        if scale: n["scale"] = list(scale)
        if children: n["children"] = list(children)
        self.nodes.append(n)
        return len(self.nodes) - 1

    def add_skin(self, joint_nodes, ibms, skeleton_root):
        acc = self._acc_f(ibms, 16)
        self.skins.append({"inverseBindMatrices": acc, "joints": joint_nodes,
                           "skeleton": skeleton_root})
        return len(self.skins) - 1

    def add_animation(self, name, channels):
        """channels: list of (joint_node, times[list], quats[list of (x,y,z,w)])"""
        samplers, chs = [], []
        for node, times, quats in channels:
            ti = self._acc_f(times, 1)
            qi = self._acc_f(quats, 4)
            samplers.append({"input": ti, "output": qi, "interpolation": "LINEAR"})
            chs.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": "rotation"}})
        self.animations.append({"name": name, "samplers": samplers, "channels": chs})

    def save(self, path):
        gltf = {
            "asset": {"version": "2.0", "generator": "abidjan-runner-genpy"},
            "scene": 0,
            "scenes": [{"nodes": self.scene_roots}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "accessors": self.accessors,
            "bufferViews": self.bufferViews,
            "buffers": [{"byteLength": len(self.buf)}],
        }
        if self.skins: gltf["skins"] = self.skins
        if self.animations: gltf["animations"] = self.animations
        ext = [m for m in self.materials if "extensions" in m]
        if ext:
            gltf["extensionsUsed"] = ["KHR_materials_unlit"]
        json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(json_bytes) % 4:
            json_bytes += b" "
        bin_bytes = bytes(self.buf)
        while len(bin_bytes) % 4:
            bin_bytes += b"\x00"
        total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(json_bytes), 0x4E4F534A)); f.write(json_bytes)
            f.write(struct.pack("<II", len(bin_bytes), 0x004E4942)); f.write(bin_bytes)
        return path


# ---------------------------------------------------------------- static-mesh helper
def save_static(path, colored_parts, name="asset"):
    """colored_parts: list of (mesh, rgba, opts). Groups by color into primitives."""
    g = GLTF()
    groups = {}
    order = []
    for item in colored_parts:
        mesh, rgba = item[0], item[1]
        opts = item[2] if len(item) > 2 else {}
        mi = g.material(rgba, metallic=opts.get("metallic", 0.0),
                        rough=opts.get("rough", 0.85), emissive=opts.get("emissive"),
                        unlit=opts.get("unlit", False))
        if mi not in groups:
            groups[mi] = ([], [], []); order.append(mi)
        P, N, I = groups[mi]
        p, n, i = mesh
        off = len(P); P += p; N += n; I += [k+off for k in i]
    prims = []
    for mi in order:
        P, N, I = groups[mi]
        prims.append({"positions": P, "normals": N, "indices": I, "material": mi})
    mesh_i = g.add_mesh(prims, name)
    g.scene_roots.append(g.add_node(name=name, mesh=mesh_i))
    return g.save(path)
