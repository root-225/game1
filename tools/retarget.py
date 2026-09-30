"""Retarget KayKit animations (CC0) onto the humanoid Mannequiny rig (CC-BY 4.0) and add an
authored baseball-style SLIDE clip. Both rigs bind in the same T-pose (+X = left arm,
-Y legs, +Z forward), so a world-space rotation delta per bone transfers cleanly:

    D(t) = Rsrc_world(t) * inverse(Rsrc_bind)      Rtgt_world(t) = D(t) * Rtgt_bind

Usage: python3 retarget.py SRC_KAYKIT.glb TARGET.glb OUT.glb
"""
import sys, struct, json, array
import numpy as np
from prune_gltf import read_glb, write_glb
from rigmath import Rig, q_mul, q_inv, q_norm, q_axis, q_rotate, quat_from_mat, q_slerp

MAP = {
    "hips": "pelvis", "spine": "spine_01", "chest": "spine_02", "head": "head",
    "upperarm.l": "upperarm.l", "lowerarm.l": "lowerarm.l", "wrist.l": "hand.l",
    "upperarm.r": "upperarm.r", "lowerarm.r": "lowerarm.r", "wrist.r": "hand.r",
    "upperleg.l": "thigh.l", "lowerleg.l": "calf.l", "foot.l": "foot.l", "toes.l": "ball.l",
    "upperleg.r": "thigh.r", "lowerleg.r": "calf.r", "foot.r": "foot.r", "toes.r": "ball.r",
}
# source clip -> output name
CLIPS = {"Idle": "idle", "Running_A": "run", "Jump_Full_Short": "jump", "Hit_A": "hit",
         "Death_A": "death", "Cheer": "cheer", "Jump_Land": "land"}
FPS = 30.0
# KayKit's chibi torso is wide, so its arms hang far from the body. Pre-rotate the arm chain
# toward the body in the reference pose (applied before the animated delta).
ARM_TUCK = 28.0
ARM_FIX = {"upperarm.l": -1, "lowerarm.l": -1, "hand.l": -1, "upperarm.r": 1, "lowerarm.r": 1, "hand.r": 1}


class Baker:
    def __init__(self, tgt: Rig):
        self.t = tgt
        self.order = self._topo()
        tj = tgt.joints
        self.bind_rot = {jn: quat_from_mat(tgt.bind_world[jn]) for jn in tj}
        self.bind_pos = {jn: tgt.bind_world[jn][:3, 3].copy() for jn in tj}
        # parent world transform of a joint at bind (for non-joint parents: scene default)
        self.bind_local_t, self.bind_local_r = {}, {}
        for jn in tj:
            pw = self._parent_bind_world(jn)
            L = np.linalg.inv(pw) @ tgt.bind_world[jn]
            self.bind_local_t[jn] = L[:3, 3].copy()
            self.bind_local_r[jn] = quat_from_mat(L)

    def _parent_bind_world(self, jn):
        p = self.t.parent.get(jn)
        if p is None:
            return np.eye(4)
        if p in self.t.bind_world:
            return self.t.bind_world[p]
        return self.t.world_default(p)

    def _topo(self):
        joints = set(self.t.joints)
        out, seen = [], set()
        def visit(i):
            if i in seen: return
            p = self.t.parent.get(i)
            if p in joints: visit(p)
            seen.add(i); out.append(i)
        for jn in self.t.joints: visit(jn)
        return out

    def solve(self, deltas, pelvis_offset):
        """deltas: {tgt_joint_node: world delta quat}; returns {joint: (local_t, local_r)}."""
        world_r, world_m, res = {}, {}, {}
        for jn in self.order:
            p = self.t.parent.get(jn)
            if p in world_m:
                pm = world_m[p]
            else:
                pm = self._parent_bind_world(jn)
            pr = quat_from_mat(pm)
            if jn in deltas:
                wr = q_norm(q_mul(deltas[jn], self.bind_rot[jn]))
            else:
                wr = q_norm(q_mul(pr, self.bind_local_r[jn]))
            lr = q_norm(q_mul(q_inv(pr), wr))
            lt = self.bind_local_t[jn].copy()
            if jn == self.pelvis and pelvis_offset is not None:
                # world offset -> parent-local offset
                inv = np.linalg.inv(pm[:3, :3])
                lt = lt + inv @ pelvis_offset
            M = np.eye(4)
            x, y, z, w = lr
            M[:3, :3] = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                                  [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                                  [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
            M[:3, 3] = lt
            world_m[jn] = pm @ M
            res[jn] = (lt, lr)
        return res


def retarget(src: Rig, baker: Baker, anim):
    tgt = baker.t
    n2t = {tgt.nodes[i]["name"]: i for i in tgt.joints}
    s_idx = {src.nodes[i]["name"]: i for i in src.joints}
    src_bind_rot = {i: quat_from_mat(src.bind_world[i]) for i in src.joints}
    hips = s_idx["hips"]
    ratio = baker.bind_pos[baker.pelvis][1] / src.bind_world[hips][1, 3]
    length = src.anim_length(anim)
    frames = []
    n = max(2, int(round(length * FPS)) + 1)
    for k in range(n):
        t = min(length, k / FPS)
        sw = src.world_from_locals(src.sample_anim(anim, t))
        deltas = {}
        for s_name, t_name in MAP.items():
            si = s_idx[s_name]
            d = q_norm(q_mul(quat_from_mat(sw[si]), q_inv(src_bind_rot[si])))
            if t_name in ARM_FIX:
                d = q_mul(d, q_axis((0, 0, 1), ARM_TUCK * ARM_FIX[t_name]))
            deltas[n2t[t_name]] = d
        off = (sw[hips][:3, 3] - src.bind_world[hips][:3, 3]) * ratio
        frames.append((t, baker.solve(deltas, off)))
    return frames


def slide_clip(baker: Baker):
    """Low baseball slide: lean far back, lead leg forward, one hand down, one up. 0.6 s.
    Head stays under ~0.8 m so it visibly clears the overhead bars."""
    n2t = {baker.t.nodes[i]["name"]: i for i in baker.t.joints}
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    rx = lambda d: q_axis(X, d)
    start = {  # neutral stride: arms down, knees slightly bent
        "pelvis": rx(0), "spine_01": rx(8), "spine_02": rx(10), "neck_01": rx(0), "head": rx(0),
        "thigh.l": rx(-25), "calf.l": rx(10), "foot.l": rx(0), "ball.l": rx(0),
        "thigh.r": rx(15), "calf.r": rx(40), "foot.r": rx(10), "ball.r": rx(10),
        "upperarm.l": q_axis(Z, -72), "lowerarm.l": q_mul(rx(-40), q_axis(Z, -75)), "hand.l": q_mul(rx(-40), q_axis(Z, -75)),
        "upperarm.r": q_axis(Z, 72), "lowerarm.r": q_mul(rx(-40), q_axis(Z, 75)), "hand.r": q_mul(rx(-40), q_axis(Z, 75)),
    }
    full = {
        "pelvis": rx(-68), "spine_01": rx(-55), "spine_02": rx(-42), "neck_01": rx(-15), "head": rx(10),
        "thigh.l": rx(-86), "calf.l": rx(-88), "foot.l": rx(-50), "ball.l": rx(-50),
        "thigh.r": rx(-55), "calf.r": rx(75), "foot.r": rx(40), "ball.r": rx(40),
        # left hand trails on the ground, right arm up and forward for balance
        "upperarm.l": q_mul(q_axis(Y, 45), q_axis(Z, -65)), "lowerarm.l": q_mul(q_axis(Y, 40), q_axis(Z, -80)),
        "hand.l": q_mul(q_axis(Y, 40), q_axis(Z, -80)),
        "upperarm.r": q_mul(rx(-35), q_axis(Y, 75)), "lowerarm.r": q_mul(rx(-70), q_axis(Y, 75)),
        "hand.r": q_mul(rx(-70), q_axis(Y, 75)),
    }
    def pose(k):
        deltas = {n2t[b]: q_slerp(start[b], full[b], k) for b in full}
        return baker.solve(deltas, np.array([0, -0.52 * k, 0.12 * k]))
    keys = [(0.0, 0.0), (0.12, 1.0), (0.46, 1.0), (0.6, 0.45)]
    frames = []
    for i in range(int(0.6 * FPS) + 1):
        t = i / FPS
        k = keys[-1][1]
        for a, b in zip(keys, keys[1:]):
            if a[0] <= t <= b[0]:
                f = (t - a[0]) / (b[0] - a[0]); f = f * f * (3 - 2 * f)
                k = a[1] + (b[1] - a[1]) * f
                break
        frames.append((t, pose(k)))
    return frames


def write_frames(j, buf, name, frames, joints, pelvis):
    """Append an animation (rotation for all joints, translation for pelvis) to glTF j/buf."""
    def add(data_bytes, count, typ):
        while len(buf) % 4: buf.append(0)
        off = len(buf); buf.extend(data_bytes)
        j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(data_bytes)})
        acc = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": count, "type": typ}
        if typ == "SCALAR":
            vals = array.array("f"); vals.frombytes(bytes(data_bytes))
            acc["min"] = [min(vals)]; acc["max"] = [max(vals)]
        j["accessors"].append(acc)
        return len(j["accessors"]) - 1
    times = array.array("f", [f[0] for f in frames])
    ti = add(times.tobytes(), len(times), "SCALAR")
    samplers, channels = [], []
    for jn in joints:
        rots = [f[1][jn][1] for f in frames]
        if all(np.allclose(r, rots[0], atol=1e-5) or np.allclose(r, -rots[0], atol=1e-5) for r in rots):
            one = array.array("f", [0.0]); t1 = add(one.tobytes(), 1, "SCALAR")
            ri = add(array.array("f", list(rots[0])).tobytes(), 1, "VEC4")
            samplers.append({"input": t1, "output": ri, "interpolation": "LINEAR"})
        else:
            # keep quaternion hemisphere continuous
            fixed = [rots[0]]
            for r in rots[1:]:
                fixed.append(-r if np.dot(r, fixed[-1]) < 0 else r)
            data = array.array("f", [c for r in fixed for c in r])
            ri = add(data.tobytes(), len(fixed), "VEC4")
            samplers.append({"input": ti, "output": ri, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": jn, "path": "rotation"}})
    pos = array.array("f", [c for f in frames for c in f[1][pelvis][0]])
    pi = add(pos.tobytes(), len(frames), "VEC3")
    samplers.append({"input": ti, "output": pi, "interpolation": "LINEAR"})
    channels.append({"sampler": len(samplers) - 1, "target": {"node": pelvis, "path": "translation"}})
    j.setdefault("animations", []).append({"name": name, "samplers": samplers, "channels": channels})


def main(src_path, tgt_path, out_path):
    sj, sb = read_glb(src_path)
    tj, tb = read_glb(tgt_path)
    src, tgt = Rig(sj, sb), Rig(tj, tb)
    baker = Baker(tgt)
    baker.pelvis = tgt.name_to_node["pelvis"]
    buf = bytearray(tb)
    tj["animations"] = []
    anims = {a["name"]: a for a in sj["animations"]}
    for s_name, o_name in CLIPS.items():
        write_frames(tj, buf, o_name, retarget(src, baker, anims[s_name]), tgt.joints, baker.pelvis)
        print("  retargeted", s_name, "->", o_name)
    write_frames(tj, buf, "slide", slide_clip(baker), tgt.joints, baker.pelvis)
    print("  authored slide")
    # rest pose = bind T-pose (the source file's node defaults were a random pose)
    for jn in tgt.joints:
        n = tj["nodes"][jn]
        n.pop("matrix", None)
        n["translation"] = [float(v) for v in baker.bind_local_t[jn]]
        n["rotation"] = [float(v) for v in baker.bind_local_r[jn]]
        n["scale"] = [1.0, 1.0, 1.0]
    tj["buffers"] = [{"byteLength": len(buf)}]
    # drop now-unused buffer data from the old animations
    from prune_gltf import prune
    keep = {a["name"] for a in tj["animations"]}
    tj, out = prune(tj, bytes(buf), keep, [])
    write_glb(out_path, tj, out)
    print("  ->", out_path, len(out) // 1024, "KB")


if __name__ == "__main__":
    main(*sys.argv[1:4])
