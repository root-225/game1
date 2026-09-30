"""Shrink a .glb for mobile: keep only listed animations, drop mesh nodes by name,
garbage-collect unused accessors/bufferViews and optionally extract the embedded texture.

    python3 prune_gltf.py in.glb out.glb --keep Idle,Running_A --drop Cape,Hat --tex out.png
"""
import argparse, json, struct


def read_glb(path):
    b = open(path, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    bin_start = 20 + jl + 8
    bl = struct.unpack("<I", b[20 + jl:24 + jl])[0]
    return j, b[bin_start:bin_start + bl]


def write_glb(path, j, binary):
    jb = json.dumps(j, separators=(",", ":")).encode()
    jb += b" " * (-len(jb) % 4)
    binary += b"\0" * (-len(binary) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(jb) + len(binary)))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A) + jb)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + binary)


def prune(j, binary, keep_anims, drop_nodes):
    j["animations"] = [a for a in j.get("animations", []) if a["name"] in keep_anims]
    for n in j["nodes"]:
        if any(d.lower() in n.get("name", "").lower() for d in drop_nodes):
            n.pop("mesh", None)
            n.pop("skin", None)
    # meshes still referenced
    used_mesh = sorted({n["mesh"] for n in j["nodes"] if "mesh" in n})
    mesh_map = {old: new for new, old in enumerate(used_mesh)}
    j["meshes"] = [j["meshes"][i] for i in used_mesh]
    for n in j["nodes"]:
        if "mesh" in n:
            n["mesh"] = mesh_map[n["mesh"]]
    # accessors in use
    used_acc = set()
    for m in j["meshes"]:
        for p in m["primitives"]:
            used_acc.update(p["attributes"].values())
            if "indices" in p:
                used_acc.add(p["indices"])
            for t in p.get("targets", []):
                used_acc.update(t.values())
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            used_acc.add(s["inverseBindMatrices"])
    for a in j["animations"]:
        for s in a["samplers"]:
            used_acc.update((s["input"], s["output"]))
    acc_list = sorted(used_acc)
    acc_map = {old: new for new, old in enumerate(acc_list)}
    j["accessors"] = [j["accessors"][i] for i in acc_list]
    # bufferViews in use -> repack
    used_bv = sorted({a["bufferView"] for a in j["accessors"] if "bufferView" in a} |
                     {im["bufferView"] for im in j.get("images", []) if "bufferView" in im})
    out = bytearray()
    bv_map = {}
    new_bvs = []
    for old in used_bv:
        bv = dict(j["bufferViews"][old])
        start = bv.get("byteOffset", 0)
        data = binary[start:start + bv["byteLength"]]
        out += b"\0" * (-len(out) % 4)
        bv["byteOffset"] = len(out)
        out += data
        bv_map[old] = len(new_bvs)
        new_bvs.append(bv)
    j["bufferViews"] = new_bvs
    for a in j["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = bv_map[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = bv_map[im["bufferView"]]
    # remap accessor references
    for m in j["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = acc_map[p["indices"]]
            if "targets" in p:
                p["targets"] = [{k: acc_map[v] for k, v in t.items()} for t in p["targets"]]
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            s["inverseBindMatrices"] = acc_map[s["inverseBindMatrices"]]
    for a in j["animations"]:
        for s in a["samplers"]:
            s["input"] = acc_map[s["input"]]
            s["output"] = acc_map[s["output"]]
    j["buffers"] = [{"byteLength": len(out)}]
    return j, bytes(out)


def extract_texture(j, binary, path):
    im = j["images"][0]
    bv = j["bufferViews"][im["bufferView"]]
    s = bv.get("byteOffset", 0)
    open(path, "wb").write(binary[s:s + bv["byteLength"]])


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--keep", default=""); ap.add_argument("--drop", default="")
    ap.add_argument("--tex", default="")
    a = ap.parse_args()
    j, b = read_glb(a.src)
    before = len(b)
    j, b = prune(j, b, set(filter(None, a.keep.split(","))), list(filter(None, a.drop.split(","))))
    if a.tex:
        extract_texture(j, b, a.tex)
    write_glb(a.dst, j, b)
    print("%s: %d KB -> %d KB, %d anims, %d meshes" % (a.dst.split("/")[-1], before // 1024, len(b) // 1024,
                                                        len(j["animations"]), len(j["meshes"])))
