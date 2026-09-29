# Diagnostic : quelle convention d'IBM utilise ce GLB ?
import json, struct
import numpy as np

SRC = "simulator/assets/props/adult_waving.glb"
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
ARMATURE = j["scenes"][0]["nodes"][0]


def globals_rest(arm_scale):
    local = {}
    for idx, node in enumerate(j["nodes"]):
        m = np.eye(4)
        m[:3, :3] = quat_to_mat(node.get("rotation", [0, 0, 0, 1])) \
            @ np.diag(node.get("scale", [1, 1, 1]))
        m[:3, 3] = node.get("translation", [0, 0, 0])
        local[idx] = m
    if not arm_scale:
        local[ARMATURE] = np.eye(4)
    G = {}

    def g(i):
        if i not in G:
            G[i] = local[i] if children.get(i) is None else g(children[i]) @ local[i]
        return G[i]

    for i in range(len(j["nodes"])):
        g(i)
    return G


skin = j["skins"][0]
IBM = acc_data(skin["inverseBindMatrices"])
G_full = globals_rest(arm_scale=True)
G_neut = globals_rest(arm_scale=False)


def err(M):
    return float(np.abs(M - np.eye(4)).max())


print(f"{'os':14s} {'full.T':>10s} {'full':>10s} {'neut.T':>10s} {'neut':>10s}")
for k, jb in enumerate(skin["joints"][:8]):
    name = j["nodes"][jb].get("name", "?")
    print(f"{name:14s} {err(G_full[jb] @ IBM[k].T):10.3f} "
          f"{err(G_full[jb] @ IBM[k]):10.3f} "
          f"{err(G_neut[jb] @ IBM[k].T):10.3f} "
          f"{err(G_neut[jb] @ IBM[k]):10.3f}")
print("IBM[0] premiere ligne :", IBM[0][0].round(3))
print("IBM[0] diagonale      :", [round(float(IBM[0][i, i]), 3) for i in range(4)])
