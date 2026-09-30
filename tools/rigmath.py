"""Minimal glTF rig math: node world transforms (bind / animated), quaternions, matrices."""
import math, array
import numpy as np

def q_mul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return np.array([aw*bx + ax*bw + ay*bz - az*by, aw*by - ax*bz + ay*bw + az*bx,
                     aw*bz + ax*by - ay*bx + az*bw, aw*bw - ax*bx - ay*by - az*bz])

def q_inv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]]) / np.dot(q, q)

def q_norm(q):
    return q / np.linalg.norm(q)

def q_axis(axis, deg):
    a = np.array(axis, float); a /= np.linalg.norm(a)
    s = math.sin(math.radians(deg) / 2)
    return np.array([a[0]*s, a[1]*s, a[2]*s, math.cos(math.radians(deg) / 2)])

def q_rotate(q, v):
    p = np.array([v[0], v[1], v[2], 0.0])
    return q_mul(q_mul(q, p), q_inv(q))[:3]

def q_slerp(a, b, t):
    d = np.dot(a, b)
    if d < 0: b = -b; d = -d
    if d > 0.9995: return q_norm(a + (b - a) * t)
    th = math.acos(d); s = math.sin(th)
    return (math.sin((1 - t) * th) * a + math.sin(t * th) * b) / s

def mat_from_trs(t, r, s):
    x, y, z, w = r
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                  [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                  [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    M = np.eye(4); M[:3, :3] = R * np.array(s)[None, :]; M[:3, 3] = t
    return M

def quat_from_mat(M):
    R = M[:3, :3].copy()
    for i in range(3):
        n = np.linalg.norm(R[:, i])
        if n > 0: R[:, i] /= n
    tr = R[0, 0] + R[1, 1] + R[2, 2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        q = [(R[2, 1]-R[1, 2])/s, (R[0, 2]-R[2, 0])/s, (R[1, 0]-R[0, 1])/s, 0.25*s]
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = math.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        q = [0.25*s, (R[0, 1]+R[1, 0])/s, (R[0, 2]+R[2, 0])/s, (R[2, 1]-R[1, 2])/s]
    elif R[1, 1] > R[2, 2]:
        s = math.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        q = [(R[0, 1]+R[1, 0])/s, 0.25*s, (R[1, 2]+R[2, 1])/s, (R[0, 2]-R[2, 0])/s]
    else:
        s = math.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        q = [(R[0, 2]+R[2, 0])/s, (R[1, 2]+R[2, 1])/s, 0.25*s, (R[1, 0]-R[0, 1])/s]
    return q_norm(np.array(q))


class Rig:
    def __init__(self, j, b):
        self.j, self.b = j, b
        self.nodes = j["nodes"]
        self.parent = {}
        for i, n in enumerate(self.nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        self.skin = j["skins"][0]
        self.joints = self.skin["joints"]
        self.name_to_node = {n.get("name"): i for i, n in enumerate(self.nodes)}
        ibm = self.accessor(self.skin["inverseBindMatrices"])
        self.ibm = {jn: np.array(ibm[k*16:(k+1)*16]).reshape(4, 4).T for k, jn in enumerate(self.joints)}
        self.mesh_node = next(i for i, n in enumerate(self.nodes) if "skin" in n)
        # bind world of each joint = meshNodeWorld * inverse(IBM)
        mw = self.world_default(self.mesh_node)
        self.bind_world = {jn: mw @ np.linalg.inv(self.ibm[jn]) for jn in self.joints}

    def accessor(self, i):
        a = self.j["accessors"][i]; bv = self.j["bufferViews"][a["bufferView"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]] * a["count"]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        code = {5126: "f", 5123: "H", 5121: "B", 5125: "I"}[a["componentType"]]
        size = array.array(code).itemsize
        stride = bv.get("byteStride")
        if stride and stride != size * (n // a["count"]):
            comps = n // a["count"]; out = []
            for k in range(a["count"]):
                arr = array.array(code); arr.frombytes(self.b[off+k*stride: off+k*stride+comps*size]); out += list(arr)
            return out
        arr = array.array(code); arr.frombytes(self.b[off: off + n * size])
        return list(arr)

    def local_default(self, i):
        n = self.nodes[i]
        if "matrix" in n:
            return np.array(n["matrix"]).reshape(4, 4).T
        return mat_from_trs(n.get("translation", [0, 0, 0]), n.get("rotation", [0, 0, 0, 1]), n.get("scale", [1, 1, 1]))

    def world_default(self, i):
        M = self.local_default(i)
        while i in self.parent:
            i = self.parent[i]; M = self.local_default(i) @ M
        return M

    def sample_anim(self, anim, t):
        """Return {node: 4x4 local} for all nodes at time t (defaults where not animated)."""
        trs = {}
        for i, n in enumerate(self.nodes):
            trs[i] = [list(n.get("translation", [0, 0, 0])), list(n.get("rotation", [0, 0, 0, 1])), list(n.get("scale", [1, 1, 1]))]
        for ch in anim["channels"]:
            s = anim["samplers"][ch["sampler"]]
            times = self.accessor(s["input"]); vals = self.accessor(s["output"])
            path = ch["target"]["path"]; node = ch["target"]["node"]
            if path == "weights": continue
            c = 4 if path == "rotation" else 3
            k = 0
            while k < len(times) - 1 and times[k + 1] < t: k += 1
            if t <= times[0] or len(times) == 1: v = vals[0:c]
            elif t >= times[-1]: v = vals[(len(times)-1)*c:len(times)*c]
            else:
                f = (t - times[k]) / (times[k+1] - times[k])
                a = np.array(vals[k*c:(k+1)*c]); b = np.array(vals[(k+1)*c:(k+2)*c])
                v = list(q_slerp(q_norm(a), q_norm(b), f)) if c == 4 else list(a + (b - a) * f)
            trs[node][{"translation": 0, "rotation": 1, "scale": 2}[path]] = v
        return {i: mat_from_trs(*trs[i]) for i in trs}

    def world_from_locals(self, locals_):
        cache = {}
        def w(i):
            if i in cache: return cache[i]
            M = locals_[i] if i not in self.parent else w(self.parent[i]) @ locals_[i]
            cache[i] = M; return M
        return {i: w(i) for i in locals_}

    def anim_length(self, anim):
        return max(self.j["accessors"][s["input"]]["max"][0] for s in anim["samplers"])
