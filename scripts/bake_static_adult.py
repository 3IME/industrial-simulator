# Fige le personnage anime en maillage statique (pose de salut).
# Un maillage statique n'a plus de squelette : sa boite englobante est
# exacte, aucune derive d'echelle n'est possible au rendu.
import json, struct
import numpy as np

SRC = "simulator/assets/props/adult_waving.glb"
DST = "simulator/assets/props/adult_static.glb"
HAUTEUR_CIBLE = 1.60   # metres, pieds au sol

with open(SRC, 'rb') as f:
    data = f.read()
jlen = struct.unpack('<I', data[12:16])[0]
j = json.loads(data[20:20 + jlen])
bin_start = 20 + jlen
blen = struct.unpack('<I', data[bin_start:bin_start + 4])[0]
BIN = data[bin_start + 8:bin_start + 8 + blen]

NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def acc_data(i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = NCOMP[a["type"]]
    dt = {5121: np.uint8, 5126: np.float32, 5123: np.uint16,
          5125: np.uint32}[a["componentType"]]
    stride = bv.get("byteStride", 0) or n * np.dtype(dt).itemsize
    arr = np.frombuffer(BIN, dtype=np.dtype(dt).newbyteorder('<'),
                        count=a["count"] * n, offset=base)
    shape = (a["count"],) + ((n,) if n < 16 else (4, 4))
    return arr.reshape(shape).copy()


def quat_to_mat(q):
    x, y, z, w = q
    nrm = np.sqrt(x * x + y * y + z * z + w * w)
    x, y, z, w = x / nrm, y / nrm, z / nrm, w / nrm
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]], float)


children = {}
for idx, node in enumerate(j["nodes"]):
    for c in node.get("children", []):
        children[c] = idx
ANIM = j["animations"][0]


def globals_at(T):
    """Transformations globales de tous les noeuds a l'instant T,
    racine Armature neutralisee (skin dans l'espace rig)."""
    local = {}
    for idx, node in enumerate(j["nodes"]):
        m = np.eye(4)
        m[:3, :3] = quat_to_mat(node.get("rotation", [0, 0, 0, 1])) \
            @ np.diag(node.get("scale", [1, 1, 1]))
        m[:3, 3] = node.get("translation", [0, 0, 0])
        local[idx] = m
    for ch in ANIM["channels"]:
        tgt = ch["target"]["node"]
        samp = ANIM["samplers"][ch["sampler"]]
        inp = acc_data(samp["input"])[:, 0]
        i = int(np.argmin(np.abs(inp - T)))
        out = acc_data(samp["output"])
        p = ch["target"]["path"]
        if p == "translation":
            local[tgt][:3, 3] = out[i]
        elif p == "rotation":
            local[tgt][:3, :3] = quat_to_mat(out[i])
    # Convention verifiee (diag_skinning.py) : G AVEC l'echelle Armature
    # activee et IBM transpose donnent l'identite exacte au repos.

    G = {}

    def g(i):
        if i not in G:
            G[i] = local[i] if children.get(i) is None else g(children[i]) @ local[i]
        return G[i]

    for i in range(len(j["nodes"])):
        g(i)
    return G


# 1) instant le plus "debout" : position monde de la tete maximale
head_idx = next(i for i, n in enumerate(j["nodes"]) if n.get("name") == "Head")
dur = acc_data(ANIM["samplers"][0]["input"])[:, 0].max()
meilleur_t, meilleur_y = 0.0, -1e9
t = 0.0
while t <= dur:
    y = globals_at(t)[head_idx][1, 3]
    if y > meilleur_y:
        meilleur_y, meilleur_t = y, t
    t += 0.1
T = round(meilleur_t, 2)
print("instant retenu: t =", T, "s (tete la plus haute, pose debout)")

G = globals_at(T)

# 2) skinning (IBM column-major -> transpose)
skin = j["skins"][0]
IBMs = acc_data(skin["inverseBindMatrices"]).transpose(0, 2, 1)
M = np.stack([G[ji] @ IBMs[k] for k, ji in enumerate(skin["joints"])])

prim = j["meshes"][0]["primitives"][0]
at = prim["attributes"]
V = acc_data(at["POSITION"])
Nrm = acc_data(at["NORMAL"])
J = acc_data(at["JOINTS_0"]).astype(int)
W = acc_data(at["WEIGHTS_0"])

Vh = np.hstack([V, np.ones((len(V), 1))])
out = np.zeros_like(V)
for k in range(4):
    out += W[:, k, None] * np.einsum('nij,nj->ni', M[J[:, k]], Vh)[:, :3]
outn = np.zeros_like(Nrm)
for k in range(4):
    outn += W[:, k, None] * np.einsum('nij,nj->ni', M[J[:, k]][:, :3, :3], Nrm)[:, :3]
outn /= np.linalg.norm(outn, axis=1, keepdims=True)
print("bbox peau brute:", out.min(0).round(2), "->", out.max(0).round(2))

# 3) normalisation deterministe : pieds a y=0, hauteur exacte 1,60 m
out -= np.array([0.0, out[:, 1].min(), 0.0])
out *= HAUTEUR_CIBLE / (out[:, 1].max() - 0.0)
print("bbox normalisee:", out.min(0).round(3), "->", out.max(0).round(3))

# 4) ecriture GLB statique
views, accs, blob = [], [], bytearray()


def add_blob(nparr, comp, ntype, mn=None, mx=None):
    global blob
    raw = nparr.astype('<f4' if comp == 5126 else '<u4').tobytes()
    while len(blob) % 4:
        blob.extend(b'\x00')
    views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(raw)})
    blob.extend(raw)
    a = {"bufferView": len(views) - 1, "componentType": comp,
         "count": len(nparr), "type": ntype}
    if mn is not None:
        a["min"] = [float(v) for v in mn]
        a["max"] = [float(v) for v in mx]
    accs.append(a)
    return len(accs) - 1


pos = add_blob(out, 5126, "VEC3", out.min(0), out.max(0))
nrm = add_blob(outn, 5126, "VEC3")
uv = add_blob(acc_data(at["TEXCOORD_0"]), 5126, "VEC2") if "TEXCOORD_0" in at else None
idx = add_blob(acc_data(prim["indices"]).astype(np.uint32), 5125, "SCALAR")

attrs_out = {"POSITION": pos, "NORMAL": nrm}
if uv is not None:
    attrs_out["TEXCOORD_0"] = uv
gltf = {
    "asset": {"version": "2.0", "generator": "bake industrial-simulator"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"mesh": 0, "name": "adulte_statique"}],
    "meshes": [{"primitives": [{"attributes": attrs_out, "indices": idx, "mode": 4}]}],
    "accessors": accs,
    "bufferViews": views,
    "buffers": [{"byteLength": 0}],
}

if prim.get("material") is not None:
    mat_out = json.loads(json.dumps(j["materials"][prim["material"]]))
    bct = mat_out.get("pbrMetallicRoughness", {}).get("baseColorTexture")
    if bct:
        tex = j["textures"][bct["index"]]
        img = j["images"][tex["source"]]
        if "bufferView" in img:
            sbv = j["bufferViews"][img["bufferView"]]
            raw = bytes(BIN[sbv["byteOffset"]:sbv["byteOffset"] + sbv["byteLength"]])
            while len(blob) % 4:
                blob.extend(b'\x00')
            views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(raw)})
            blob.extend(raw)
            gltf["images"] = [{"bufferView": len(views) - 1,
                               "mimeType": img.get("mimeType", "image/png")}]
            gltf["textures"] = [{"source": 0}]
            bct["index"] = 0
    gltf["materials"] = [mat_out]
    gltf["meshes"][0]["primitives"][0]["material"] = 0

gltf["buffers"][0]["byteLength"] = len(blob)
json_out = json.dumps(gltf, separators=(',', ':')).encode()
while len(json_out) % 4:
    json_out += b' '
blob = bytes(blob)
while len(blob) % 4:
    blob += b'\x00'
glb = (struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(json_out) + 8 + len(blob))
       + struct.pack('<II', len(json_out), 0x4E4F534A) + json_out
       + struct.pack('<II', len(blob), 0x004E4942) + blob)
open(DST, 'wb').write(glb)
print("GLB statique:", DST, len(glb), "octets")

import trimesh
s = trimesh.load(DST, force="scene")
b0 = min(g.bounds[0] for g in s.geometry.values())
b1 = max(g.bounds[1] for g in s.geometry.values())
print("bbox final:", np.round(b0, 3), np.round(b1, 3),
      "hauteur:", round(float(b1[1] - b0[1]), 3))
