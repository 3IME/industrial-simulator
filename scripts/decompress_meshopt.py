# Decompression EXT_meshopt_compression + dequantization KHR_mesh_quantization
# -> GLB standard lisible par Godot
import struct, json, sys
import numpy as np
from meshoptimizer import decode_vertex_buffer, decode_index_buffer, decode_index_sequence

NC = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}
DT = {5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NBYTES = {5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}

def traiter(src_path, dst_path):
    with open(src_path,'rb') as f: data=f.read()
    jlen = struct.unpack('<I',data[12:16])[0]
    j = json.loads(data[20:20+jlen])
    bin_off = 20+jlen
    blen = struct.unpack('<I',data[bin_off:bin_off+4])[0]
    BIN = data[bin_off+8:bin_off+8+blen]

    nouvelles = {}
    for ai, acc in enumerate(j['accessors']):
        ct = acc['componentType']
        nc = NC[acc['type']]
        count = acc['count']
        stride = nc * NBYTES[ct]
        if 'bufferView' in acc:
            bv = j['bufferViews'][acc['bufferView']]
            ext = bv.get('extensions',{}).get('EXT_meshopt_compression',{})
            if ext:
                sdata = BIN[ext['byteOffset']:ext['byteOffset']+ext['byteLength']]
                mode = ext.get('mode','ATTRIBUTES')
                if mode in ('TRIANGLES','INDICES'):
                    if mode == 'TRIANGLES':
                        res = decode_index_buffer(len(sdata), ext['count'], sdata)
                    else:
                        res = decode_index_sequence(len(sdata), ext['count'], sdata)
                    nouvelles[ai] = bytes(res)
                else:
                    res = decode_vertex_buffer(stride, ext['count'], sdata)
                    nouvelles[ai] = bytes(res)
            else:
                off = bv.get('byteOffset',0) + acc.get('byteOffset',0)
                nouvelles[ai] = BIN[off:off + count*stride]
        else:
            nouvelles[ai] = b'\x00' * (count * stride)

    views, accs, blob = [], [], bytearray()
    def add_data(raw):
        while len(blob)%4: blob.extend(b'\x00')
        views.append({"buffer":0,"byteOffset":len(blob),"byteLength":len(raw)})
        blob.extend(raw)
        return len(views)-1

    meshes = []
    for mesh in j['meshes']:
        prims = []
        for prim in mesh['primitives']:
            attrs = {}
            for attr_name, acc_idx in prim['attributes'].items():
                acc = j['accessors'][acc_idx]
                ct = acc['componentType']
                nc = NC[acc['type']]
                raw = nouvelles[acc_idx]
                if ct != 5126:
                    arr = np.frombuffer(raw, dtype=np.dtype(DT[ct]).newbyteorder('<'),
                                       count=acc['count']*nc)
                    arr = arr.reshape(acc['count'], nc).astype(np.float64)
                    bits = 8*NBYTES[ct]
                    vmax = float(2**(bits-1)-1) if ct in (5120,5122) else float(2**bits-1)
                    if acc.get('normalized',False):
                        dec = np.maximum(arr/vmax, -1.0)
                    else:
                        mn = np.array(acc.get('min',[0.0]*nc))
                        mx = np.array(acc.get('max',[1.0]*nc))
                        dec = arr/vmax*(mx-mn)+mn
                    raw = dec.astype('<f4').tobytes()
                bv_idx = add_data(raw)
                vals = np.frombuffer(raw, dtype='<f4', count=acc['count']*nc).reshape(acc['count'],nc)
                accs.append({"bufferView":bv_idx,"componentType":5126,"count":acc['count'],
                           "type":acc['type'],
                           "min":[float(v) for v in vals.min(0)],
                           "max":[float(v) for v in vals.max(0)]})
                attrs[attr_name] = len(accs)-1
            prim_new = {"attributes":attrs,"mode":prim.get("mode",4)}
            if 'indices' in prim:
                iacc = j['accessors'][prim['indices']]
                iraw = nouvelles[prim['indices']]
                # meshopt peut retourner u16 ou u32 selon la taille
                n = iacc['count']
                if len(iraw) >= n*4:
                    ival = np.frombuffer(iraw, dtype='<u4', count=n)
                    ct_i, raw_i = 5125, ival.tobytes()
                elif len(iraw) >= n*2:
                    ival = np.frombuffer(iraw, dtype='<u2', count=n).astype(np.uint32)
                    ct_i, raw_i = 5125, ival.tobytes()
                else:
                    ival = np.zeros(n, dtype=np.uint32)
                    ct_i, raw_i = 5125, ival.tobytes()
                ibv = add_data(raw_i)
                accs.append({"bufferView":ibv,"componentType":ct_i,"count":n,"type":"SCALAR"})
                prim_new["indices"] = len(accs)-1
            if 'material' in prim:
                prim_new["material"] = 0
            prims.append(prim_new)
        meshes.append({"primitives":prims})

    nodes = []
    for n in j['nodes']:
        nn = {k:v for k,v in n.items() if k not in ('extensions',)}
        nodes.append(nn)

    gltf = {"asset":{"version":"2.0","generator":"meshopt-decompress"},
        "scene":0,"scenes":[{"nodes":list(range(len(nodes)))}],
        "nodes":nodes,"meshes":meshes,"accessors":accs,"bufferViews":views,
        "buffers":[{"byteLength":0}]}

    if j.get('materials'):
        mat = json.loads(json.dumps(j['materials'][0]))
        bct = mat.get('pbrMetallicRoughness',{}).get('baseColorTexture')
        if bct and j.get('images'):
            img = j['images'][0]
            if 'bufferView' in img:
                ibv = j['bufferViews'][img['bufferView']]
                iext = ibv.get('extensions',{}).get('EXT_meshopt_compression',{})
                if iext:
                    isrc = BIN[iext['byteOffset']:iext['byteOffset']+iext['byteLength']]
                    ires = decode_vertex_buffer(1, iext['count'], isrc)
                    iraw = bytes(ires)[:ibv['byteLength']]
                else:
                    iraw = BIN[ibv['byteOffset']:ibv['byteOffset']+ibv['byteLength']]
                ibv_new = add_data(iraw)
                gltf["images"] = [{"bufferView":ibv_new,"mimeType":img.get("mimeType","image/png")}]
                gltf["textures"] = [{"source":0}]
                bct["index"] = 0
        gltf["materials"] = [mat]

    gltf["buffers"][0]["byteLength"] = len(blob)
    json_out = json.dumps(gltf,separators=(',',':')).encode()
    while len(json_out)%4: json_out += b' '
    blob_pad = bytes(blob)
    while len(blob_pad)%4: blob_pad += b'\x00'
    total = 12+8+len(json_out)+8+len(blob_pad)
    glb = (struct.pack('<III',0x46546C67,2,total)
        +struct.pack('<II',len(json_out),0x4E4F534A)+json_out
        +struct.pack('<II',len(blob_pad),0x004E4942)+blob_pad)
    open(dst_path,'wb').write(glb)
    print("GLB decompresse:", dst_path, len(glb), "octets")

if __name__ == "__main__":
    traiter(sys.argv[1], sys.argv[2])
