"""Makes the item files for a design: <name>.app, <name>_root_entity.ent and _<name>_mesh_entity.ent,
copied from the design_02 templates in tools\\reference with every design_02 name swapped for <name>.
Used by dko_build.py (step 5); can also be run alone:  python dko_item.py <name> <archive folder>"""
import copy, json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "reference")
OLD = "design_02"
FILES = ("{}.app", "{}_root_entity.ent", "_{}_mesh_entity.ent")


def depot_dir(adir):
    parts = adir.replace("/", "\\").split("\\")
    k = len(parts) - 1 - parts[::-1].index("archive")
    return "\\".join(parts[k + 1:])


def make_item_json(name, adir, feet=False, bodies=False, tattoo=False):
    """Writes the three .json files next to the mesh and returns their paths.
    feet=True: the mesh entity points at <name>_{feet}.mesh, so ArchiveXL picks the mesh that matches V's feet
    (lifted / flat / flat_shoes / high_heels), the same way the Dancers Body Glow Wraps item does it."""
    dd = depot_dir(adir)
    out = []
    for pat in FILES:
        src = os.path.join(REF, pat.format(OLD) + ".json")
        if not os.path.isfile(src):
            sys.exit(f"Reference file missing: {src}")
        txt = open(src, encoding="utf-8").read()
        txt = txt.replace("doubleko\\\\designs\\\\", dd.replace("\\", "\\\\") + "\\\\")
        txt = txt.replace(OLD, name)
        if feet or bodies:
            # ArchiveXL fills in V's body tag ({body}: base_body, ebbprb, ...) and feet state ({feet}) at run time
            p_old = dd.replace("\\", "\\\\") + "\\\\" + name + ".mesh"
            sub = ("_{body}" if bodies else "") + ("_{feet}" if feet else "")
            txt = txt.replace('"' + p_old + '"', '"*' + p_old[:-5] + sub + '.mesh"')
        doc = json.loads(txt)  # must still be valid
        if tattoo and pat.startswith("_") and pat.endswith(".ent"):
            # full-color tattoo: a second garment component with the skin-tight tattoo layer (same colors list)
            comps = doc["Data"]["RootChunk"]["components"]
            g = next(c for c in comps if c.get("$type") == "entGarmentSkinnedMeshComponent")
            t = copy.deepcopy(g)
            t["name"]["$value"] = "s1_dko_tattoo_" + name
            t["id"] = str(int(g["id"]) ^ 0x5A5A5A5A5A5A)
            mp = g["mesh"]["DepotPath"]["$value"]
            stem = mp.rsplit("\\", 1)
            t["mesh"]["DepotPath"]["$value"] = stem[0] + "\\tattoo_" + stem[1].lstrip("*") if len(stem) == 2 else mp
            if mp.startswith("*"):
                t["mesh"]["DepotPath"]["$value"] = "*" + t["mesh"]["DepotPath"]["$value"].lstrip("*")
            comps.append(t)
            txt = json.dumps(doc, indent=2)
        if pat.endswith(".app"):
            # the design_02 template carried an override for the Dancers Body Glow Wraps component (chunkMask 3):
            # worn together, it hid most of the straps (all chunks but the first two). Designs override nothing.
            n = 0
            for ap in doc["Data"]["RootChunk"].get("appearances", []):
                for po in (ap.get("Data") or {}).get("partsOverrides", []):
                    n += len(po.get("componentsOverrides", []))
                    po["componentsOverrides"] = []
            txt = json.dumps(doc, indent=2)
        dst = os.path.join(adir, pat.format(name) + ".json")
        with open(dst, "w", encoding="utf-8") as f:
            f.write(txt)
        out.append(dst)
    return out


def source_dir(adir):
    parts = adir.replace("/", "\\").split("\\")
    k = len(parts) - 1 - parts[::-1].index("archive")
    return "\\".join(parts[:k])


def color_label(c):
    """readable color name for the item name, e.g. clear_cyan_purple_glow4 -> Clear Cyan Purple (glow 2)"""
    cid = str(c.get("id", ""))
    m = re.search(r"_glow(\d+)$", cid)
    words = re.sub(r"_glow\d+$", "", cid).replace("_", " ").title()
    if m:
        words += f" (glow {int(m.group(1)) / 2:g})"
    return words


def make_item_extras(name, adir, title=None, colors=None):
    """Own factory (name -> root entity), own language file, own .yaml item entry and .xl file for this design.
    Returns (json files to deserialize, yaml path, xl path, language key prefix)."""
    dd = depot_dir(adir)
    res = os.path.join(source_dir(adir), "resources")
    hdr = {"WolvenKitVersion": "10.0.0-beta.2-nightly.2026-11-07", "WKitJsonVersion": "0.0.9", "GameVersion": 2500,
           "ExportedDateTime": "2026-01-01T00:00:00.0000000Z", "DataType": "CR2W", "ArchiveFileName": ""}
    fac = {"Header": hdr, "Data": {"Version": 195, "BuildVersion": 0, "RootChunk": {
        "$type": "C2dArray",
        "compiledData": [[f"dko_{name}_factory_name", dd + "\\" + name + "_root_entity.ent", "true"]],
        "compiledHeaders": ["name", "path", "preload"], "cookingPlatform": "PLATFORM_None", "data": [],
        "headers": ["name", "path", "preload"]}, "EmbeddedFiles": []}}
    base_title = title or f"DKO {name.replace('_', ' ').title()} Glow Design"
    pairs = [(f"dko_{name}_i18n_name", base_title), (f"dko_{name}_i18n_desc", "Glowing body design from Double K.O. Designs.")]
    # every color gets its own name: "<design> - <color>"
    pairs += [(f"dko_{name}_i18n_name_{c['id']}", f"{base_title} - {color_label(c)}") for c in (colors or [])]
    ent = [{"$type": "localizationPersistenceOnScreenEntry", "femaleVariant": v, "secondaryKey": k} for k, v in pairs]
    loc = {"Header": hdr, "Data": {"Version": 195, "BuildVersion": 0, "RootChunk": {
        "$type": "JsonResource", "root": {"HandleId": "0", "Data": {
            "$type": "localizationPersistenceOnScreenEntries", "entries": ent}}}, "EmbeddedFiles": []}}
    jf = os.path.join(adir, f"{name}_factory.csv.json")
    jl = os.path.join(adir, f"{name}_i18n_en_us.json.json")
    for p, d in ((jf, fac), (jl, loc)):
        with open(p, "w", encoding="utf-8") as f:
            json.dump(d, f, indent=2)
    return jf, jl, dd, res


HYST_LIKE = ("ebbp", "ebb", "ebbrb", "rb")      # Hyst bodies close to EBBPRB: they use its meshes when not built


def write_yaml_xl(name, dd, res, with_loc, colors=None, icon_atlas=None, title=None, bodies=None, feet=False):
    tpl = open(os.path.join(REF, "design_02_item.yaml"), encoding="utf-8").read().replace(OLD, name)
    if colors:
        ids = [c["id"] for c in colors]
        head = f"# ---- {title or name} ----\n" + "".join(f'# Game.AddToInventory("Items.doubleko_{name}_{i}")\n' for i in ids)
        body = tpl[tpl.index(f"Items.doubleko_{name}_$(base_color):"):]
        a0 = body.index("  $instances:")
        a1 = body.index("  appearanceName:")
        body = body[:a0] + "  $instances:\n" + "".join(f"    - {{base_color: {i}}}\n" for i in ids) + body[a1:]
        tpl = head + body
        # each color shows its own name in game
        tpl = tpl.replace(f"displayName: LocKey#dko_{name}_i18n_name", f"displayName: LocKey#dko_{name}_i18n_name_$(base_color)")
    if icon_atlas:
        tpl = tpl.replace("doubleko\\glowstraps_clean\\dancers_body_glow_wraps\\dancers_body_glow_wraps_icons.inkatlas", icon_atlas)
        tpl = tpl.replace("atlasPartName: dancers_body_glow_wraps_$(base_color)", f"atlasPartName: dko_{name}_$(base_color)")
    if not with_loc:  # language file could not be built: use the design_02 texts that already exist in the game files
        tpl = tpl.replace(f"dko_{name}_i18n_name", "dko_design_02_i18n_name").replace(f"dko_{name}_i18n_desc", "dko_design_02_i18n_desc")
    twk = os.path.join(res, "r6", "tweaks", "doubleko")
    os.makedirs(twk, exist_ok=True)
    yp = os.path.join(twk, name + ".yaml")
    with open(yp, "w", encoding="utf-8") as f:
        f.write(tpl)
    xl = "factories:\n  - " + dd + "\\" + name + "_factory.csv\n"
    if with_loc:
        xl += "localization:\n  onscreens:\n    en-us:\n      - " + dd + "\\" + name + "_i18n_en_us.json\n"
    if bodies and "ebbprb" in bodies:
        # a body that was not built falls back to base_body; the Hyst bodies near EBBPRB use the EBBPRB meshes
        fs = ("lifted", "flat", "flat_shoes", "high_heels") if feet else (None,)
        links = ""
        for f_ in fs:
            suf = f"_{f_}" if f_ else ""
            al = [t for t in HYST_LIKE if t not in bodies]
            if al:
                links += f"    {dd}\\{name}_ebbprb{suf}.mesh:\n" + "".join(f"      - {dd}\\{name}_{t}{suf}.mesh\n" for t in al)
        if links:
            xl += "resource:\n  link:\n" + links
    xp = os.path.join(res, f"doubleko_{name}.archive.xl")
    with open(xp, "w", encoding="utf-8") as f:
        f.write(xl)
    return yp, xp


def make_icon_json(name, adir, rgba_path):
    """Item icons: <name>_icons.xbm (uncompressed, made straight from the rendered pixels, no image library
    needed) and <name>_icons.inkatlas with one part per color (dko_<name>_<color>). Returns the JSON files."""
    import base64
    meta = json.load(open(os.path.splitext(rgba_path)[0] + ".json", encoding="utf-8"))
    w, h = meta["width"], meta["height"]
    raw = open(rgba_path, "rb").read()
    if len(raw) != w * h * 4:
        sys.exit(f"icon pixels have the wrong size: {rgba_path}")
    dd = depot_dir(adir)
    xbm = json.load(open(os.path.join(REF, "icon_template.xbm.json"), encoding="utf-8"))
    xbm["Header"]["ArchiveFileName"] = ""
    rc = xbm["Data"]["RootChunk"]
    rc["width"], rc["height"] = w, h
    rc["setup"]["compression"] = "TCM_None"
    rc["setup"]["rawFormat"] = "TRF_TrueColor"
    rc["setup"]["hasMipchain"] = 0
    blob = rc["renderTextureResource"]["renderResourceBlobPC"]["Data"]
    hd = blob["header"]
    # the game keeps texture rows bottom-up (WolvenKit flips images on import): store the rows in reverse,
    # or the icon shows upside down
    row = w * 4
    raw = b"".join(raw[y * row:(y + 1) * row] for y in range(h - 1, -1, -1))
    size = w * h * 4
    mip = hd["mipMapInfo"][0]
    mip["layout"]["rowPitch"] = w * 4
    mip["layout"]["slicePitch"] = size
    mip["placement"]["offset"] = 0
    mip["placement"]["size"] = size
    hd["mipMapInfo"] = [mip]
    hd["sizeInfo"]["width"], hd["sizeInfo"]["height"] = w, h
    ti = hd["textureInfo"]
    ti["mipCount"] = 1
    ti["sliceSize"] = size
    ti["textureDataSize"] = size
    blob["textureData"]["Bytes"] = base64.b64encode(raw).decode("ascii")
    xp = os.path.join(adir, f"{name}_icons.xbm.json")
    with open(xp, "w", encoding="utf-8") as f:
        json.dump(xbm, f)

    atl = json.load(open(os.path.join(REF, "icon_template.inkatlas.json"), encoding="utf-8"))
    atl["Header"]["ArchiveFileName"] = ""
    slots = atl["Data"]["RootChunk"]["slots"]["Elements"]
    proto = slots[0]["parts"][0]
    parts = []
    for p in meta["parts"]:
        l, t, r, b = p["rect"]
        m = json.loads(json.dumps(proto))
        m["clippingRectInPixels"].update({"left": l, "top": t, "right": r, "bottom": b})
        m["clippingRectInUVCoords"].update({"Left": l / w, "Top": t / h, "Right": r / w, "Bottom": b / h})
        m["partName"]["$value"] = p["part"]
        parts.append(m)
    tex = dd + "\\" + name + "_icons.xbm"
    slots[0]["parts"] = parts
    slots[0]["texture"]["DepotPath"] = {"$type": "ResourcePath", "$storage": "string", "$value": tex}
    slots[1]["parts"] = []
    slots[1]["texture"]["DepotPath"] = {"$type": "ResourcePath", "$storage": "string", "$value": tex}
    ap = os.path.join(adir, f"{name}_icons.inkatlas.json")
    with open(ap, "w", encoding="utf-8") as f:
        json.dump(atl, f, indent=1)
    return [xp, ap], dd + "\\" + name + "_icons.inkatlas"


BAND_STYLES = ("original", "bands", "wavy", "rings", "sharp", "pixelated")   # pixelated = older name of bands


def band_profile(v, style="original", width=1.0, glow=None, trail=None, tail_up=True):
    """(r, g, b, a) 0..1 of the glow band at texture height v (0..1, one repeat).
    original: one soft band. bands (older name: pixelated): the band in hard blocks and a few brightness steps (digital look).
    wavy: like original here; make_band_json shifts it up and down across the texture width (= around the body).
    rings: three thin rings travelling together. sharp: one solid band with hard edges.
    width scales the band (and a trail's tail); 1 = the original width."""
    width = max(0.1, float(width))
    if style in ("bands", "pixelated"):
        v = (int(v * 24) + 0.5) / 24               # 24 blocks per repeat
    if trail:
        g = [x / 255.0 for x in (glow or [255, 255, 255])[:3]]
        t = [x / 255.0 for x in trail[:3]]
        head = 0.35 if tail_up else 0.65
        off = (v - head) if tail_up else (head - v)     # > 0 = behind the head (tail side)
        if off < 0:
            k = 0.0
            a = max(0.0, 1.0 + off / (0.05 * width)) ** 1.5      # short soft leading edge
        else:
            k = min(1.0, off / (0.22 * width))                   # color: glow at the head -> trail color
            a = max(0.0, 1.0 - off / min(0.62, 0.5 * width)) ** 1.3   # long fading tail
        col = [g[i] * (1 - k) + t[i] * k for i in range(3)]
        d = abs(off) / (0.5 * width)
    else:
        col = [1.0, 1.0, 1.0]
        d = abs(v - 0.5) / (0.18 * width)
        a = max(0.0, 1.0 - d) ** 1.5
    if style == "rings":
        if not trail:
            # three thin rings, brightest in the middle
            span = 0.135 * width
            a = max(max(0.0, 1.0 - abs(v - (0.5 + i * span)) / (0.035 * width)) * (1.0 if i == 0 else 0.7)
                    for i in (-1, 0, 1))
        else:
            # three thin rings: the first in the glow color, the next ones fading into the trail color
            sgn = 1 if tail_up else -1
            head = 0.35 if tail_up else 0.65
            a = 0.0
            for i, f in ((0, 1.0), (1, 0.75), (2, 0.5)):
                ctr = head + sgn * i * 0.12 * width
                r = max(0.0, 1.0 - abs(v - ctr) / (0.035 * width)) * f
                if r > a:
                    a = r
                    k = min(1.0, i / 2.0)
                    col = [g[j] * (1 - k) + t[j] * k for j in range(3)]
    elif style == "sharp":
        a = 1.0 if a > 0.3 else 0.0
    elif style in ("bands", "pixelated"):
        a = round(a * 4) / 4.0                      # 4 brightness steps
    return col[0], col[1], col[2], max(0.0, min(1.0, a))


def _px(rgba):
    r, g, b, a = rgba
    return [int(round(255 * r)), int(round(255 * g)), int(round(255 * b)), int(round(255 * a))]


def make_band_json(name, adir, size=256, glow=None, trail=None, tail_up=True, suffix="", style="original", width=1.0):
    """<name>_glowband[_<suffix>].xbm: a narrow texture holding one glow band per repeat. Transparent colors
    scroll it along the design, so only the band lights up and the rest of the design stays see-through.
    With a trail color the band is a comet: a bright head in the glow color and a long tail that fades into the
    trail color behind it (tail_up = the tail lies towards higher texture rows; it follows the scroll direction).
    style / width: see band_profile."""
    # wavy: the band is shifted up and down across the texture's width. The design's u runs once around the body
    # (Blender step, Wavy band on), so the band snakes around it in 6 waves. Other styles are the same across.
    w = 64 if style == "wavy" else 4
    rows = []
    for y in range(size):
        v = (y + 0.5) / size
        if w == 4:
            rows.append(bytes(_px(band_profile(v, style, width, glow, trail, tail_up))) * 4)
        else:
            rows.append(b"".join(bytes(_px(band_profile((v - 0.06 * math.sin(2 * math.pi * 6 * (x + 0.5) / w)) % 1.0,
                                                        style, width, glow, trail, tail_up))) for x in range(w)))
    raw = b"".join(rows)                           # top row first; make_xbm_json flips for the game
    base = f"{name}_glowband" + (f"_{suffix}" if suffix else "")
    return make_xbm_json(base, adir, raw, w, size), depot_dir(adir) + "\\" + base + ".xbm"


def make_xbm_json(base, adir, raw, w, h):
    import base64
    xbm = json.load(open(os.path.join(REF, "icon_template.xbm.json"), encoding="utf-8"))
    xbm["Header"]["ArchiveFileName"] = ""
    rc = xbm["Data"]["RootChunk"]
    rc["width"], rc["height"] = w, h
    rc["setup"]["compression"] = "TCM_None"
    rc["setup"]["rawFormat"] = "TRF_TrueColor"
    rc["setup"]["hasMipchain"] = 0
    rc["setup"]["group"] = "TEXG_Generic_Color"
    blob = rc["renderTextureResource"]["renderResourceBlobPC"]["Data"]
    hd = blob["header"]
    row = w * 4
    raw = b"".join(raw[y * row:(y + 1) * row] for y in range(h - 1, -1, -1))
    size = w * h * 4
    mip = hd["mipMapInfo"][0]
    mip["layout"]["rowPitch"] = row
    mip["layout"]["slicePitch"] = size
    mip["placement"]["offset"] = 0
    mip["placement"]["size"] = size
    hd["mipMapInfo"] = [mip]
    hd["sizeInfo"]["width"], hd["sizeInfo"]["height"] = w, h
    ti = hd["textureInfo"]
    ti["mipCount"] = 1
    ti["sliceSize"] = size
    ti["textureDataSize"] = size
    blob["textureData"]["Bytes"] = base64.b64encode(raw).decode("ascii")
    p = os.path.join(adir, base + ".xbm.json")
    with open(p, "w", encoding="utf-8") as f:
        json.dump(xbm, f)
    return p


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    for p in make_item_json(sys.argv[1], sys.argv[2]):
        print("wrote", p)
