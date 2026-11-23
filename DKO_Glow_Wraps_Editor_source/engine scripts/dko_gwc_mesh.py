"""Strap mesh helpers for DKO Glow Wraps Colors (pure Python, no numpy).

Works on a .mesh serialized by WolvenKit (JSON). The Glow Wraps glow is a gradient that the material scrolls along
the straps' texture v, and the straps' v runs with the height of the body. center_uvs() lays v out by the distance
from the middle of the body instead, so the same scrolling glow travels from the belly out to the head, hands and
feet (or the other way round with the scroll reversed)."""
import base64, json, math, re, struct

SIZES = {"PT_Short4N": 8, "PT_UByte4": 4, "PT_UByte4N": 4, "PT_Float16_4": 8, "PT_Float16_2": 4, "PT_Dec4": 4,
         "PT_Color": 4, "PT_Float4": 16, "PT_Float3": 12, "PT_Float2": 8, "PT_Short2N": 4, "PT_UShort4N": 8,
         "PT_Short4": 8, "PT_UShort2": 4, "PT_Float1": 4}
BELLY_Z = 1.0      # middle of the body (belly / navel height), the same spot the DKO Design Builder uses
AROUND = 0.5       # how far the glow also travels AROUND the body (front -> back), in glow lengths. The torso straps
                   # are short horizontal bands: a glow that only went up the body swept through each in a blink
                   # (a flash); with this it slides along them, front to back, like a chevron


def _layout(ci):
    strides, pos = {}, {}
    for e in ci["chunkVertices"]["vertexLayout"]["elements"]["Elements"]:
        if e.get("streamType") != "ST_PerVertex" or e.get("usage") in (None, "PS_Invalid"):
            continue
        s = e["streamIndex"]
        pos[(e["usage"], e["usageIndex"])] = (s, strides.get(s, 0), e["type"])
        strides[s] = strides.get(s, 0) + SIZES[e["type"]]
    return strides, pos


def relayout(doc, mode="height", belly_z=BELLY_Z, around=AROUND, u_around=False, v_scale=1.0):
    """New texture layout (UV 0) for the whole strap mesh, with no breaks anywhere.
    The Glow Wraps' own layout has seams (UV islands, some turned 90 degrees) and the glow and the strap surface
    map showed thin lines there. Here every vertex gets its UV from its position only, so where two pieces meet on
    the body they get the same UV:
      v: mode "height" = up the body (Feet to head / Head to feet), "center" = out from the belly (Center outward /
         Outside inward); same scale as the Glow Wraps glow (fitted over the whole mesh).
      u: across the body (x, plus a little depth) - only the material's fine detail uses it."""
    R = doc["Data"]["RootChunk"]
    blob = R["renderResourceBlob"]["Data"]
    h = blob["header"]
    buf = bytearray(base64.b64decode(blob["renderBuffer"]["Bytes"]))
    qs, qo = h["quantizationScale"], h["quantizationOffset"]
    chunks = []
    for ci in h["renderChunkInfos"]:
        n = ci["numVertices"]
        offs = ci["chunkVertices"]["byteOffsets"]["Elements"]
        strides, pos = _layout(ci)
        ps, po, pt = pos[("PS_Position", 0)]
        us, uo, ut = pos[("PS_TexCoord", 0)]
        if pt != "PT_Short4N" or ut != "PT_Float16_2":
            raise ValueError("unexpected vertex format")
        pst, ust = strides[ps], strides[us]
        pts, vs = [], []
        for i in range(n):
            x, y, z, _ = struct.unpack_from("<4h", buf, offs[ps] + i * pst + po)
            x = x / 32767.0 * qs["X"] + qo["X"]
            y = y / 32767.0 * qs["Y"] + qo["Y"]
            z = z / 32767.0 * qs["Z"] + qo["Z"]
            u, v = struct.unpack_from("<2e", buf, offs[us] + i * ust + uo)
            pts.append((x, y, z))
            vs.append(v)
        chunks.append((offs[us], ust, uo, pts, vs))
    # one least-squares fit v = a + s*z over the whole mesh (the scale of the Glow Wraps glow)
    allp = [p for c in chunks for p in c[3]]
    allv = [v for c in chunks for v in c[4]]
    n = len(allp) or 1
    mz = sum(p[2] for p in allp) / n
    mv = sum(allv) / n
    cov = sum((p[2] - mz) * (v - mv) for p, v in zip(allp, allv))
    var = sum((p[2] - mz) ** 2 for p in allp) or 1e-9
    s = cov / var
    if abs(s) < 1e-3:
        s = 0.6
    s *= v_scale       # v_scale > 1: shorter glow (more of it over the body)
    vc = mv + s * (belly_z - mz)
    # the middle of the body front to back (y), for the angle around it
    yc = sum(p[1] for p in allp) / n
    out = []
    for base, ust, uo, pts, vs in chunks:
        for i, (x, y, z) in enumerate(pts):
            # 0 at the front middle -> 1 at the back middle, the same on both sides (no seam anywhere)
            ang = abs(math.atan2(x, y - yc)) / math.pi      # the chest points to +y: that is the front
            if mode == "center":
                v = vc + s * math.sqrt(x * x + (z - belly_z) ** 2) + around * ang
            else:
                v = vc + s * (z - belly_z) + around * ang
            # u: across the body - or (u_around, the DKO Design Builder's layout) the angle around the body,
            # mirrored front -> back on both sides (0 .. 0.5, so no seam): a Wavy band snakes around the body
            u = 0.5 * ang if u_around else 0.5 + x + 0.5 * y
            out.append((base + i * ust + uo, u, v))
    # keep v inside 0..1: the glow material wraps its picture at whole numbers of v at FIXED places on the strap
    # (before it moves the glow), and every wrap showed as a thin dashed line that never moved. Centered on 0.5.
    lo = min(o[2] for o in out)
    hi = max(o[2] for o in out)
    shift = 0.5 - (lo + hi) / 2.0
    if hi - lo > 0.96:
        raise ValueError("strap layout too long for one picture (v %.2f .. %.2f)" % (lo, hi))
    for off, u, v in out:
        struct.pack_into("<2e", buf, off, u, v + shift)
    blob["renderBuffer"]["Bytes"] = base64.b64encode(bytes(buf)).decode()


def center_uvs(doc, belly_z=BELLY_Z):
    relayout(doc, "center", belly_z)


def push_out(doc, dist=0.002):
    """Move every vertex of the mesh `dist` meters out along its surface direction (normal), for a glowing layer
    that sits just above the strap: the render vertices AND the garment copy of the shape (same vertex order).
    The positions are stored quantized to the mesh's box, so the box grows by `dist` and every position is
    written again."""
    R = doc["Data"]["RootChunk"]
    blob = R["renderResourceBlob"]["Data"]
    h = blob["header"]
    buf = bytearray(base64.b64decode(blob["renderBuffer"]["Bytes"]))
    qs, qo = h["quantizationScale"], h["quantizationOffset"]
    ax = ("X", "Y", "Z")
    chunks = []
    for ci in h["renderChunkInfos"]:
        n = ci["numVertices"]
        offs = ci["chunkVertices"]["byteOffsets"]["Elements"]
        strides, pos = _layout(ci)
        ps, po, pt = pos[("PS_Position", 0)]
        ns, no, nt = pos[("PS_Normal", 0)]
        if pt != "PT_Short4N" or nt != "PT_Dec4":
            raise ValueError("unexpected vertex format")
        new = []
        for i in range(n):
            q = struct.unpack_from("<4h", buf, offs[ps] + i * strides[ps] + po)
            p = [q[k] / 32767.0 * qs[ax[k]] + qo[ax[k]] for k in range(3)]
            r = struct.unpack_from("<I", buf, offs[ns] + i * strides[ns] + no)[0]
            nv = [((r >> (10 * k)) & 0x3FF) / 1023.0 * 2.0 - 1.0 for k in range(3)]
            ln = math.sqrt(sum(x * x for x in nv)) or 1.0
            new.append(([p[k] + dist * nv[k] / ln for k in range(3)], q[3]))
        chunks.append((offs[ps], strides[ps], po, new))
    allp = [p for c in chunks for p, _ in c[3]]
    lo = [min(p[k] for p in allp) for k in range(3)]
    hi = [max(p[k] for p in allp) for k in range(3)]
    for k in range(3):
        qo[ax[k]] = (lo[k] + hi[k]) / 2.0
        qs[ax[k]] = max(1e-6, (hi[k] - lo[k]) / 2.0)
    for base, st, po, new in chunks:
        for i, (p, w) in enumerate(new):
            q = [int(round(max(-1.0, min(1.0, (p[k] - qo[ax[k]]) / qs[ax[k]])) * 32767)) for k in range(3)]
            struct.pack_into("<4h", buf, base + i * st + po, q[0], q[1], q[2], w)
    blob["renderBuffer"]["Bytes"] = base64.b64encode(bytes(buf)).decode()
    # the garment copy of the shape (float x, y, z per vertex, same order as the render vertices)
    for prm in R.get("parameters") or []:
        D = prm.get("Data") or {}
        if D.get("$type") != "garmentMeshParamGarment":
            continue
        for gc, (_, _, _, new) in zip(D["chunks"], chunks):
            vb = gc.get("vertices")
            if isinstance(vb, dict) and vb.get("Bytes"):
                arr = base64.b64decode(vb["Bytes"])
                if len(arr) == 12 * len(new):
                    vb["Bytes"] = base64.b64encode(b"".join(struct.pack("<3f", *p) for p, _ in new)).decode()
    bb = R.get("boundingBox")
    if bb:
        for k in range(3):
            bb["Min"][ax[k]] = min(bb["Min"][ax[k]], lo[k])
            bb["Max"][ax[k]] = max(bb["Max"][ax[k]], hi[k])


def add_layer_chunks(doc, dist=0.0001):
    """Copy every render chunk of the mesh as a layer `dist` meters above the strap (along the normals), INSIDE the
    same mesh: chunks n..2n-1 = the layer over chunks 0..n-1. One mesh, one garment component - a separate layer
    component counted as a second garment and the game squeezed the strap under it into the skin.
    Copies the vertex streams, indices, topology and garment chunk data; the layer's positions (and garment copy of
    the shape) are pushed out; every position is written again for the new quantization box. Returns n."""
    R = doc["Data"]["RootChunk"]
    blob = R["renderResourceBlob"]["Data"]
    h = blob["header"]
    buf = bytes(base64.b64decode(blob["renderBuffer"]["Bytes"]))
    qs, qo = h["quantizationScale"], h["quantizationOffset"]
    ax = ("X", "Y", "Z")
    infos = h["renderChunkInfos"]
    n = len(infos)
    vb_end, ib_off, ib_size = h["vertexBufferSize"], h["indexBufferOffset"], h["indexBufferSize"]
    if ib_off != vb_end or len(buf) < ib_off + ib_size:
        raise ValueError("unexpected render buffer layout")
    vert = bytearray(buf[:vb_end])
    idx = bytearray(buf[ib_off:ib_off + ib_size])
    old_pos, new_pos, new_infos = [], [], []
    for ci in infos:
        nv = ci["numVertices"]
        offs = ci["chunkVertices"]["byteOffsets"]["Elements"]
        strides, pos = _layout(ci)
        ps, po, _ = pos[("PS_Position", 0)]
        ns, no, _ = pos[("PS_Normal", 0)]
        pts, moved = [], []
        for i in range(nv):
            q = struct.unpack_from("<4h", buf, offs[ps] + i * strides[ps] + po)
            p = [q[k] / 32767.0 * qs[ax[k]] + qo[ax[k]] for k in range(3)]
            r = struct.unpack_from("<I", buf, offs[ns] + i * strides[ns] + no)[0]
            nn = [((r >> (10 * k)) & 0x3FF) / 1023.0 * 2.0 - 1.0 for k in range(3)]
            ln = math.sqrt(sum(x * x for x in nn)) or 1.0
            pts.append((p, q[3]))
            moved.append(([p[k] + dist * nn[k] / ln for k in range(3)], q[3]))
        # copy each stream of this chunk to the end of the vertex data (16-byte aligned)
        new_offs = list(offs)
        for s, st in strides.items():
            while len(vert) % 16:
                vert.append(0)
            new_offs[s] = len(vert)
            vert += buf[offs[s]:offs[s] + nv * st]
        nci = json.loads(json.dumps(ci))
        nci["chunkVertices"]["byteOffsets"]["Elements"] = new_offs
        te = ci["chunkIndices"]["teOffset"]
        isz = ci["numIndices"] * (2 if ci["chunkIndices"].get("pe", "IBCT_IndexUShort") == "IBCT_IndexUShort" else 4)
        while len(idx) % 4:
            idx.append(0)
        nci["chunkIndices"]["teOffset"] = len(idx)
        idx += buf[ib_off + te:ib_off + te + isz]
        old_pos.append((offs[ps], strides[ps], po, pts))
        new_pos.append((new_offs[ps], strides[ps], po, moved))
        new_infos.append(nci)
    while len(vert) % 16:
        vert.append(0)
    allp = [p for c in old_pos + new_pos for p, _ in c[3]]
    for k in range(3):
        lo = min(p[k] for p in allp)
        hi = max(p[k] for p in allp)
        qo[ax[k]] = (lo + hi) / 2.0
        qs[ax[k]] = max(1e-6, (hi - lo) / 2.0)
    for base, st, po, items in old_pos + new_pos:
        for i, (p, w) in enumerate(items):
            q = [int(round(max(-1.0, min(1.0, (p[k] - qo[ax[k]]) / qs[ax[k]])) * 32767)) for k in range(3)]
            struct.pack_into("<4h", vert, base + i * st + po, q[0], q[1], q[2], w)
    h["renderChunkInfos"] = infos + new_infos
    h["vertexBufferSize"] = len(vert)
    h["indexBufferOffset"] = len(vert)
    h["indexBufferSize"] = len(idx)
    if isinstance(h.get("topology"), list) and len(h["topology"]) == n:
        h["topology"] = h["topology"] + json.loads(json.dumps(h["topology"]))
    blob["renderBuffer"]["Bytes"] = base64.b64encode(bytes(vert + idx)).decode()
    for prm in R.get("parameters") or []:
        D = prm.get("Data") or {}
        if D.get("$type") == "garmentMeshParamGarment" and len(D.get("chunks") or []) == n:
            extra = json.loads(json.dumps(D["chunks"]))
            for gc, (_, _, _, moved) in zip(extra, new_pos):
                vb = gc.get("vertices")
                if isinstance(vb, dict) and vb.get("Bytes") and len(base64.b64decode(vb["Bytes"])) == 12 * len(moved):
                    vb["Bytes"] = base64.b64encode(b"".join(struct.pack("<3f", *p) for p, _ in moved)).decode()
            # each data buffer has its own number in the file: give the copies new ones
            used = [int(x) for x in re.findall(r'"BufferId": "(\d+)"', json.dumps(doc))]
            nxt = max(used + [-1]) + 1

            def renum(o):
                nonlocal nxt
                if isinstance(o, dict):
                    if "BufferId" in o:
                        o["BufferId"] = str(nxt)
                        nxt += 1
                    for v in o.values():
                        renum(v)
                elif isinstance(o, list):
                    for v in o:
                        renum(v)
            renum(extra)
            D["chunks"] = D["chunks"] + extra
        elif D.get("$type") == "meshMeshParamGarmentSupport" and len(D.get("chunkCapVertices") or []) == n:
            D["chunkCapVertices"] = D["chunkCapVertices"] + json.loads(json.dumps(D["chunkCapVertices"]))
    bb = R.get("boundingBox")
    if bb:
        for k in range(3):
            bb["Min"][ax[k]] = min(bb["Min"][ax[k]], min(p[k] for p in allp))
            bb["Max"][ax[k]] = max(bb["Max"][ax[k]], max(p[k] for p in allp))
    return n
