"""Shared loading helpers for Quaternius Universal Base Characters (CC0)."""
import json, numpy as np
from rigmath import Rig

UBC = __import__("os").path.join(__import__("os").path.dirname(__file__), "source_models", "ubc")


def load(name):
    j = json.load(open(f"{UBC}/{name}.gltf"))
    b = open(f"{UBC}/{name}.bin", "rb").read()
    return j, b, Rig(j, b)


def prim_arrays(rig, prim):
    A = prim["attributes"]
    g = lambda k, n: np.array(rig.accessor(A[k])).reshape(-1, n)
    out = {"P": g("POSITION", 3), "N": g("NORMAL", 3), "UV": g("TEXCOORD_0", 2),
           "J": g("JOINTS_0", 4).astype(int), "W": g("WEIGHTS_0", 4),
           "I": np.array(rig.accessor(prim["indices"]), dtype=np.int64).reshape(-1, 3)}
    return out


def region(dom, p, sex):
    """Body region label for a vertex from its dominant bone + bind position."""
    x, y, z = p
    ax = abs(x)
    if dom in ("Head",):
        return "head"
    if dom == "neck_01":
        return "neck"
    if dom.startswith(("spine", "clavicle")):
        return "chest" if y > 1.18 else "belly"
    if dom == "pelvis":
        return "waist" if y > 0.93 else "hips"
    if dom.startswith("upperarm"):
        return "arm_up" if ax < (0.33 if sex == "m" else 0.28) else "arm_mid"
    if dom.startswith("lowerarm"):
        return "forearm"
    if dom.startswith(("hand", "thumb", "index", "middle", "ring", "pinky")):
        return "hand"
    if dom.startswith("thigh"):
        return "thigh_up" if y > 0.72 else "thigh_low"
    if dom.startswith("calf"):
        return "shin_up" if y > 0.3 else "shin_low"
    if dom.startswith(("foot", "ball")):
        return "foot"
    return "chest"
