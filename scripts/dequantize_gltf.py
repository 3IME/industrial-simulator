# Dequantise les glTF utilisant KHR_mesh_quantization (attributs entiers)
# en attributs flottants classiques, compris par l'importateur Godot.
import json, struct, sys, os
import numpy as np

EXT = "KHR_mesh_quantization"
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPES = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16}


def traiter_glb(chemin):
    with open(chemin, 'rb') as f:
        data = f.read()
    if data[:4] != b'glTF':
        print("  pas un GLB :", chemin)
        return False
    jlen = struct.unpack('<I', data[12:16])[0]
    j = json.loads(data[20:20 + jlen])
    bin_off = 20 + jlen
    blen = struct.unpack('<I', data[bin_off:bin_off + 4])[0]
    blob = bytearray(data[bin_off + 8:bin_off + 8 + blen])

    if EXT not in j.get("extensionsRequired", []) and \
       EXT not in j.get("extensionsUsed", []):
        print("  sans quantization :", chemin)
        return True

    views, accs = [], []
    nouveau_blob = bytearray()

    def copier_vue(bv):
        raw = bytes(blob[bv["byteOffset"]:bv["byteOffset"] + bv["byteLength"]])
        while len(nouveau_blob) % 4:
            nouveau_blob.extend(b'\x00')
        views.append({"buffer": 0, "byteOffset": len(nouveau_blob),
                      "byteLength": len(raw)})
        nouveau_blob.extend(raw)
        return len(views) - 1

    # 1) les vues d'images (textures) sont conservees et remappees
    if "images" in j:
        for img in j["images"]:
            if "bufferView" in img:
                img["bufferView"] = copier_vue(j["bufferViews"][img["bufferView"]])

    for ai, acc in enumerate(j["accessors"]):
        ct = acc["componentType"]
        # Les SCALAIRES entiers (indices de triangles) et les JOINTS
        # doivent RESTER entiers : on copie leur vue telle quelle.
        if ct == 5126 or acc["type"] == "SCALAR":
            acc["bufferView"] = copier_vue(j["bufferViews"][acc["bufferView"]])
            accs.append(acc)
            continue
        # attribut entier a decoder
        bv = j["bufferViews"][acc["bufferView"]]
        base = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        n = NCOMP[acc["type"]]
        bits = 8 * np.dtype(DTYPES[ct]).itemsize
        vmax = float(2 ** (bits - 1) - 1) if ct in (5120, 5122) else float(2 ** bits - 1)
        dt = np.dtype(DTYPES[ct]).newbyteorder('<')
        stride = bv.get("byteStride", 0) or n * dt.itemsize
        # Vue possiblement ENTRELEVEE : lecture element par element en
        # respectant le pas (np.frombuffer lit sequentiellement).
        vb = bytes(blob)
        lignes = []
        for i in range(acc["count"]):
            lignes.append(np.frombuffer(vb, dtype=dt, count=n,
                                        offset=base + i * stride))
        vals = np.array(lignes, dtype=np.float64)
        mn = np.array(acc.get("min", [0.0] * n), dtype=np.float64)
        mx = np.array(acc.get("max", [1.0] * n), dtype=np.float64)
        dec = vals / vmax * (mx - mn) + mn
        dec32 = dec.astype('<f4')
        while len(nouveau_blob) % 4:
            nouveau_blob.extend(b'\x00')
        views.append({"buffer": 0, "byteOffset": len(nouveau_blob),
                      "byteLength": len(dec32.tobytes())})
        nouveau_blob.extend(dec32.tobytes())
        acc["bufferView"] = len(views) - 1
        acc["byteOffset"] = 0        # vue decodee compacte : plus de decalage
        acc["componentType"] = 5126
        acc["min"] = [float(v) for v in dec.min(0)]
        acc["max"] = [float(v) for v in dec.max(0)]
        if "normalized" in acc:
            del acc["normalized"]
        accs.append(acc)

    j["accessors"] = accs
    j["bufferViews"] = views
    for cle in ("extensionsRequired", "extensionsUsed"):
        if cle in j:
            j[cle] = [e for e in j[cle] if e != EXT]
            if not j[cle]:
                del j[cle]
    j["buffers"] = [{"byteLength": len(nouveau_blob)}]

    json_out = json.dumps(j, separators=(',', ':')).encode()
    while len(json_out) % 4:
        json_out += b' '
    blob_pad = bytes(nouveau_blob)
    while len(blob_pad) % 4:
        blob_pad += b'\x00'
    glb = (struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(json_out) + 8 + len(blob_pad))
           + struct.pack('<II', len(json_out), 0x4E4F534A) + json_out
           + struct.pack('<II', len(blob_pad), 0x004E4942) + blob_pad)
    with open(chemin, 'wb') as f:
        f.write(glb)
    print("  dequantise :", chemin, len(glb), "octets")
    return True


if __name__ == "__main__":
    for chemin in sys.argv[1:]:
        traiter_glb(chemin)
