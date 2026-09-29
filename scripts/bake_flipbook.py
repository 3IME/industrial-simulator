# Folioscope : fige N instants de l'animation en N maillages statiques
# (sans squelette) dans UN seul GLB. Le jeu affiche les images en sequence :
# le personnage bouge sans aucun rig — la taille ne peut pas deriver.
import json, struct
import numpy as np

SRC = "simulator/assets/props/adult_waving.glb"
DST = "simulator/assets/props/adult_flipbook.glb"
N_FRAMES = 24
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
    return arr.reshape((a["count"],) + ((n,) if n < 16 else (4, 4))).copy()


def quat_to_mat(q):
    x, y, z, w = q
    nr = np.sqrt(x * x + y * y + z * z + w * w)
    x, y, z, w = x / nr, y / nr, z / nr, w / nr
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]], float)


children = {}
for idx, node in enumerate(j["nodes"]):
    for c in node.get("children", []):
        children[c] = idx
ANIM = j["animations"][0]
DUR = float(acc_data(ANIM["samplers"][0]["input"])[:, 0].max())
print("duree de la boucle:", round(DUR, 2), "s ->", N_FRAMES,
      "images,", round(DUR / N_FRAMES * 1000), "ms/image")


def globals_at(T):
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
    G = {}

    def g(i):
        if i not in G:
            G[i] = local[i] if children.get(i) is None else g(children[i]) @ local[i]
        return G[i]

    for i in range(len(j["nodes"])):
        g(i)
    return G


skin = j["skins"][0]
IBMs = acc_data(skin["inverseBindMatrices"]).transpose(0, 2, 1)
prim = j["meshes"][0]["primitives"][0]
at = prim["attributes"]
V = acc_data(at["POSITION"])
Nrm = acc_data(at["NORMAL"])
UV = acc_data(at["TEXCOORD_0"]) if "TEXCOORD_0" in at else None
IDX = acc_data(prim["indices"]).astype(np.uint32)
J = acc_data(at["JOINTS_0"]).astype(int)
W = acc_data(at["WEIGHTS_0"])
Vh = np.hstack([V, np.ones((len(V), 1))])
hips_idx = next(i for i, n in enumerate(j["nodes"]) if n.get("name") == "Hips")

# 1) peau de chaque image + recentrage sur les hanches (pas de glissement)
frames = []
for k in range(N_FRAMES):
    T = k * DUR / N_FRAMES
    G = globals_at(T)
    M = np.stack([G[jb] @ IBMs[b] for b, jb in enumerate(skin["joints"])])
    pos = np.zeros_like(V)
    for c in range(4):
        pos += W[:, c, None] * np.einsum('nij,nj->ni', M[J[:, c]], Vh)[:, :3]
    nrm = np.zeros_like(Nrm)
    for c in range(4):
        nrm += W[:, c, None] * np.einsum('nij,nj->ni', M[J[:, c]][:, :3, :3], Nrm)[:, :3]
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    hips = G[hips_idx][:3, 3]
    pos -= hips    # hanches a l'origine (x/z) : le corps ne glisse pas
    frames.append((pos, nrm, hips))
    print(f"  image {k:2d}: t={T:.2f}s y[{pos[:,1].min():7.1f}..{pos[:,1].max():7.1f}]")

# 2) mise a l'echelle COMMUNE (la plus haute image fixe 1,60 m) ; chaque
# image a les pieds a y=0
y_max = max(f[0][:, 1].max() for f in frames)
scale = HAUTEUR_CIBLE / y_max
frames = [(pos * scale - np.array([0.0, pos[:, 1].min() * scale, 0.0]), nrm, h)
          for pos, nrm, h in frames]
print("echelle commune:", round(scale, 6))

# 3) un seul GLB : N mesh + N noeuds, UNE matiere partagee (texture embarquee
# une seule fois)
views, accs, blob = [], [], bytearray()


def add_blob(nparr, comp, ntype, mn=None, mx=None):
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


meshes = []
for pos, nrm, _h in frames:
    p = add_blob(pos, 5126, "VEC3", pos.min(0), pos.max(0))
    n = add_blob(nrm, 5126, "VEC3")
    attrs = {"POSITION": p, "NORMAL": n}
    if UV is not None:
        attrs["TEXCOORD_0"] = add_blob(UV, 5126, "VEC2")
    ix = add_blob(IDX, 5125, "SCALAR")
    meshes.append({"primitives": [{"attributes": attrs, "indices": ix,
                                   "material": 0, "mode": 4}]})

nodes = [{"mesh": i, "name": f"frame_{i:02d}"} for i in range(N_FRAMES)]

# matiere + texture (une seule fois)
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
        bct["index"] = 0

gltf = {
    "asset": {"version": "2.0", "generator": "flipbook industrial-simulator"},
    "scene": 0,
    "scenes": [{"nodes": list(range(N_FRAMES))}],
    "nodes": nodes,
    "meshes": meshes,
    "materials": [mat_out],
    "accessors": accs,
    "bufferViews": views,
    "buffers": [{"byteLength": 0}],
}
if bct:
    gltf["images"] = [{"bufferView": len(views) - 1,
                       "mimeType": "image/png"}]
    gltf["textures"] = [{"source": 0}]

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
print("GLB folioscope:", DST, len(glb), "octets,", N_FRAMES, "images")
