"""DKO Glow Wraps Colors - makes a mod with new colors of the Dancers Body Glow Wraps.

The mod works on its own: it carries its own copy of the Glow Wraps straps (with only the new colors on them), so
the Dancers Body Glow Wraps mod does not have to be installed (and nothing clashes when it is). TweakXL adds one
item per color (SFW and/or NSFW).

    python dko_glowwraps_colors.py <colors.json> --cli <WolvenKit.CLI.exe> --work <folder> --mod <folder>
                                   --version sfw|nsfw|both [--items <items.json>]

colors.json: [{"id": "orange_red", "title": "...", "base": [r,g,b], "glow": [r,g,b], "finish": "metallic", "ev": 1.5,
               "speed": 0.5, "tile": 1, "flow": "up|down|out|in", "band": "original|soft|bands|wavy|rings|sharp",
               "band_width": 1.0}, ...]
<mod> receives archive\\pc\\mod\\DoubleKO_Glow_Wraps_Colors.archive(.xl) and r6\\tweaks\\doubleko\\*.yaml
"""
import argparse, base64, copy, json, math, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "reference")
DEPOT = "doubleko\\glowwraps_colors"
MESH_DIR = "doubleko\\dancers_body_glow_wraps\\meshes"
FEET = ("lifted", "flat", "flat_shoes", "high_heels")
MOD = "DoubleKO_Glow_Wraps_Colors"
# colors that are already in the Glow Wraps mod (their mesh appearances exist - a new one must not reuse the name)
TAKEN = {"default", "gold", "silver", "white", "grey", "black", "blue", "orange", "green", "purple", "yellow_green",
         "red_purple", "pink", "hot_pink", "magenta", "turquoise", "cyan", "lime", "crimson", "lavender", "neon_pink",
         "neon_green", "neon_blue", "neon_yellow", "gold_pink", "red_matte", "orange_matte", "yellow_matte",
         "green_matte", "blue_matte", "purple_matte", "blue_orange", "purple_yellow", "red_cyan", "green_magenta",
         "cold_fire_navy", "cold_fire_violet", "silver_alt"}
VERSIONS = {  # item suffix, factory of the Glow Wraps mod, short (hidden pieces), description key, name prefix
    "sfw": ("full", "dancers_body_glow_wraps_factory_name", "off", "dancers_body_glow_wraps_i18n_desc_full", "Dancers Body Glow Wraps"),
    "nsfw": ("nsfw", "dancers_body_glow_wraps_nsfw_factory_name", "on", "dancers_body_glow_wraps_i18n_desc_nsfw", "Dancers Body Glow Wraps NSFW"),
}
HDR = {"WolvenKitVersion": "8.17.0", "WKitJsonVersion": "0.0.9", "GameVersion": 2500,
       "ExportedDateTime": "2026-01-01T00:00:00.0000000Z", "DataType": "CR2W", "ArchiveFileName": ""}


def say(t):
    print(t, flush=True)


def clean_id(s):
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9_]", "_", str(s).lower())).strip("_")


def short_id(cid, name=None):
    """the game-side name of a color: the tool's long id (every setting spelled out) is shortened to its name plus
    a 6-character code made from all the settings - the same color always gets the same code, and the game finds
    short names reliably (long ones fell back to the first color)"""
    if len(cid) <= 24:
        return cid
    import hashlib
    base = clean_id(name or "")[:18].strip("_") or cid[:18].strip("_")
    return base + "_" + hashlib.sha1(cid.encode("utf-8")).hexdigest()[:6]


def title(cid):
    return " ".join(w.capitalize() for w in cid.split("_") if w)


def _val(m, key):
    for v in m["values"]:
        if key in v:
            return v
    return None


# finish -> (MetalnessScale, RoughnessScale) of metal_base_glitter.mt
FINISHES = {
    "metallic": (1.0, 0.3),    # the Glow Wraps colors
    "chrome":   (1.0, 0.05),
    "satin":    (1.0, 0.6),
    "gloss":    (0.0, 0.1),
    "matte":    (0.0, 0.6),
}


def color_material(tpl, c):
    """the Glow Wraps gold material with this color pair (same rules as the DKO Design Builder)"""
    m = copy.deepcopy(tpl)
    base = c.get("base")
    for key, rgb in (("BaseColorScale", base), ("EmissiveColor", c.get("glow"))):
        v = _val(m, key)
        if v and rgb:
            v[key]["Red"], v[key]["Green"], v[key]["Blue"] = [int(max(0, min(255, x))) for x in rgb[:3]]
    if c.get("ev") is not None:          # glow strength (the builder's Glow slider): 0.25 deep .. 5 white-hot
        v = _val(m, "EmissiveEV")
        if v:
            v["EmissiveEV"] = float(c["ev"])
    finish = (c.get("finish") or ("matte" if c.get("matte") else "metallic")).lower()
    metal, rough = FINISHES.get(finish, FINISHES["metallic"])
    sets = {"MetalnessScale": metal, "RoughnessScale": rough}
    if c.get("speed") is not None:       # how fast the glow moves (0 = still, Glow Wraps = 0.5)
        sets["ScrollSpeed"] = float(c["speed"])
    if c.get("tile") is not None:        # how many bands of light run along the straps (Glow Wraps = 1)
        sets["EmissiveTile"] = float(c["tile"])
    for key, val in sets.items():
        v = _val(m, key)
        if v:
            v[key] = val
    return m


def make_icons(colors, adir):
    """one 160x160 icon per color, recolored from the Glow Wraps icon (pure Python, no image library)"""
    tpl = open(os.path.join(REF, "gwc_icon_template.bin"), "rb").read()
    W = H = 160
    n = W * H
    body, mask, shade = tpl[:n * 4], tpl[n * 4:n * 5], tpl[n * 5:n * 6]
    cols = min(len(colors), 8)
    rows = (len(colors) + cols - 1) // cols
    aw, ah = cols * W, rows * H
    atlas = bytearray(aw * ah * 4)
    parts = []
    for k, c in enumerate(colors):
        glow = [float(x) for x in c.get("glow") or (255, 255, 255)]
        base = [float(x) for x in c.get("base") or glow]
        matte = (c.get("finish") or ("matte" if c.get("matte") else "metallic")).lower() in ("matte", "gloss")
        ox, oy = (k % cols) * W, (k // cols) * H
        for i in range(n):
            px = list(body[i * 4:i * 4 + 4])
            m = mask[i] / 255.0
            if m > 0:
                s = shade[i] / 255.0
                col = base
                kk = (0.6 + 0.35 * s) if matte else (0.55 + 0.6 * s)
                rgb = [min(255.0, x * kk) for x in col]
                g = max(0.0, (s - 0.78) / 0.22) * (0.35 if matte else 0.7)
                rgb = [rgb[j] * (1 - g) + glow[j] * g for j in range(3)]
                for j in range(3):
                    px[j] = int(px[j] * (1 - m) + rgb[j] * m)
            x, y = i % W, i // W
            o = ((oy + y) * aw + ox + x) * 4
            atlas[o:o + 4] = bytes(px)
        parts.append({"part": "gwc_" + c["id"], "rect": [ox, oy, ox + W, oy + H]})
    rgba = os.path.join(adir, "_gwc_icons.rgba")
    with open(rgba, "wb") as f:
        f.write(atlas)
    with open(os.path.splitext(rgba)[0] + ".json", "w", encoding="utf-8") as f:
        json.dump({"width": aw, "height": ah, "parts": parts}, f)
    sys.path.insert(0, HERE)
    from dko_item import make_icon_json
    files, atlas_path = make_icon_json("gwc", adir, rgba)
    os.remove(rgba)
    os.remove(os.path.splitext(rgba)[0] + ".json")
    return files, atlas_path



# ---------------- standalone straps ----------------
# glow direction -> (strap layout, scroll sign). "v" = the Glow Wraps layout (glow runs along the height of the body),
# "c" = laid out by the distance from the belly (dko_gwc_mesh.center_uvs). SIGN_UP = the scroll sign that moves the
# glow up the body on the Glow Wraps layout (and out from the belly on the centre layout).
SIGN_UP = 1.0
FLOWS = {"up": ("v", SIGN_UP), "down": ("v", -SIGN_UP), "out": ("c", SIGN_UP), "in": ("c", -SIGN_UP)}
DEFAULT_FLOW = "up" if SIGN_UP > 0 else "down"
BAND_STYLES = ("original", "soft", "bands", "wavy", "melt", "rings", "sharp")
DESC = {
    "sfw": "Glowing dancer body wraps from Double K.O. Designs in a custom color. Wear them alone or under your clothes. Refit for the Hyst EBBP RB body.",
    "nsfw": "Glowing dancer body wraps from Double K.O. Designs in a custom color, cut short with the chest bands and T-piece removed. NSFW. Refit for the Hyst EBBP RB body.",
}
STD = os.path.join(REF, "standalone")
MESH_SRC = {"lifted": "lifted", "flat": "flat", "flat_shoes": "flat", "high_heels": "high_heels"}


W_V_SCALE = 3      # Wavy / Melt: 3 glow lengths per picture (drawn in) - one glow length = about a third of the body, so the
                   # band and its drips fit on the short torso straps instead of lighting them all at once


def glow2_of(c):
    """Two-tone: the second glow color (the glow fades into it along its tail), or None"""
    g2 = c.get("glow2")
    if isinstance(g2, (list, tuple)) and len(g2) >= 3:
        try:
            return [int(max(0, min(255, int(x)))) for x in g2[:3]]
        except (TypeError, ValueError):
            return None
    return None


def uses_layer(c):
    """drawn on the glowing layer (see fx_material): Wavy / Melt (shapes across the strap) and Two-tone (2 colors)"""
    return band_of(c)[0] in ("wavy", "melt") or glow2_of(c) is not None


def layout_of(c):
    """which strap layout a color uses: v = the Glow Wraps' own (glow runs along each strap), c = by the distance
    from the belly; wv / wc = the DKO Design Builder's layout for Wavy (by height / by distance from the belly, with
    the angle around the body across, so the wavy band snakes around the body)"""
    lay = flow_of(c)[0]
    if band_of(c)[0] in ("wavy", "melt"):
        lay = "w" + lay                  # + glowing layer
    elif glow2_of(c) is not None:
        lay = "t" + lay                  # Two-tone: the same layout + glowing layer
    return lay


def flow_of(c):
    f = str(c.get("flow") or DEFAULT_FLOW).lower()
    return FLOWS.get(f, FLOWS[DEFAULT_FLOW])


def band_of(c):
    st = str(c.get("band") or "original").lower()
    st = st if st in BAND_STYLES else "original"
    try:
        wd = max(0.25, min(2.5, float(c.get("band_width", 1.0))))
    except (TypeError, ValueError):
        wd = 1.0
    return st, wd


MELT_DRIPS = 12     # drips across the picture (6 on each side of the body)
MELT_LEN = (0.37, 0.93, 0.55, 1.0, 0.45, 0.78, 0.30, 0.88, 0.62, 0.41, 0.97, 0.52)   # their lengths (fixed, uneven)


def melt_value(v, a, width):
    """Melt: separate drips of uneven length, each with its own rounded top, narrowing to a round tip, with dark
    gaps between them (no solid line across the strap - on the wide waist and hip straps that lit the whole strap).
    v = row of the picture (0..1), a = across it (0..1 = around the body).
    The game reads the picture upside down and the strap texture runs up with height, so the drips run to the
    high-v side to hang DOWN the body."""
    i = int(a * MELT_DRIPS) % MELT_DRIPS
    x = (a * MELT_DRIPS) % 1.0 - 0.5                # -0.5 .. 0.5 across this drip's slot
    top = 0.5 - 0.03 * width * (0.5 + MELT_LEN[(i + 5) % MELT_DRIPS])   # uneven rounded tops
    off = v - top
    if off < 0:
        return 0.0
    L = (0.08 + 0.22 * MELT_LEN[i]) * width         # length (part of one glow length)
    k = off / L
    if k >= 1.0:
        return 0.0
    half = 0.30 * (1.0 - 0.6 * k)                   # narrows towards the tip
    hd = 0.03 * width                               # rounded top
    if off < hd:
        half *= math.sqrt(max(0.0, 1.0 - ((hd - off) / hd) ** 2))
    if k > 0.85:                                    # round tip
        half *= math.sqrt(max(0.0, 1.0 - ((k - 0.85) / 0.15) ** 2))
    if abs(x) >= half:
        return 0.0
    edge = min(1.0, (half - abs(x)) / 0.06)         # soft sides
    return 0.95 * edge * (1.0 - 0.35 * k)           # a little dimmer towards the tip


def fx_repeat(c):
    """Repeat as a whole number (1..8): it is drawn into the glow picture (see make_band)"""
    try:
        return max(1, min(8, int(round(float(c.get("tile") if c.get("tile") is not None else 1)))))
    except (TypeError, ValueError):
        return 1


def picture_repeats(c):
    """how many glow bands the color's picture holds over the strap layout (0..1): Repeat, times 3 for Wavy/Melt"""
    return fx_repeat(c) * (W_V_SCALE if band_of(c)[0] in ("wavy", "melt") else 1)


FX_PUSH = 0.0001    # the glowing layer sits this far (meters) above the strap - small, so it does not poke
                    # through tight clothing worn over the straps (but enough to not flicker against the strap)
FX_SIGN = 1.0       # scroll sign of the glowing layer's material relative to the strap's glow


def fx_material(c, band_path):
    """Melt / Wavy: the strap's own glow material (metal_base_glitter) only reads the glow picture ALONG the strap,
    so drips and waves (which change ACROSS it) came out as solid strips. They are drawn on a glowing see-through
    layer just above the strap instead (the material the DKO Design Builder's see-through colors use), which reads
    the whole picture."""
    g = [int(max(0, min(255, x))) for x in (c.get("glow") or [255, 255, 255])[:3]]
    if glow2_of(c) is not None:
        g = [255, 255, 255]             # Two-tone: both colors are drawn into the picture
    _, sign = flow_of(c)
    speed = abs(float(c.get("speed", 0.5) if c.get("speed") is not None else 0.5))
    # the strap glow moves speed / Repeat (texture lengths per second); the repeats are in the picture here
    # the glow moves speed / Repeat of a glow length per second, as on the plain straps
    spd = FX_SIGN * sign * speed / picture_repeats(c)
    ev = float(c["ev"]) if c.get("ev") is not None else 1.06
    return {"$type": "CMaterialInstance", "audioTag": {"$type": "CName", "$storage": "string", "$value": "None"},
            "baseMaterial": {"DepotPath": {"$type": "ResourcePath", "$storage": "string",
                                           "$value": "base\\materials\\mesh_decal_emissive.mt"}, "Flags": "Default"},
            "cookingPlatform": "PLATFORM_None", "enableMask": 0, "metadata": None, "resourceVersion": 4,
            "values": [
                {"$type": "rRef:ITexture", "DiffuseTexture": {"DepotPath": {"$type": "ResourcePath", "$storage": "string",
                                                                          "$value": band_path}, "Flags": "Default"}},
                {"$type": "Color", "DiffuseColor": {"$type": "Color", "Alpha": 255, "Blue": g[2], "Green": g[1], "Red": g[0]}},
                {"$type": "Float", "DiffuseAlpha": 1.0},
                {"$type": "Float", "EmissiveEV": ev},
                {"$type": "Vector4", "ScrollSpeed": {"$type": "Vector4", "W": 0, "X": 0, "Y": spd, "Z": 0}},
            ]}


def make_band(c, adir):
    """the glow band picture of a color that does not use the Glow Wraps' own glow (None = keep the original)"""
    st, wd = band_of(c)
    fx = uses_layer(c)
    if st == "original" and fx_repeat(c) == 1 and not fx:
        return None                     # the Glow Wraps' own glow picture
    sys.path.insert(0, HERE)
    import dko_item
    style = "original" if st == "soft" else st
    wide = st in ("wavy", "melt")      # shapes across the strap (64 wide)
    g1 = [int(max(0, min(255, x))) for x in (c.get("glow") or [255, 255, 255])[:3]]
    g2 = glow2_of(c)
    _, sign = flow_of(c)
    tail_up = FX_SIGN * sign > 0        # the tail trails behind the moving head
    # Melt / Wavy are drawn on the glowing layer (see fx_material): it has no Repeat setting, so the repeats are
    # drawn into the picture (whole numbers)
    # Repeat (and Wavy/Melt's 3 glow lengths) are drawn into the picture: the material's own Repeat wrapped the
    # glow at fixed places on the straps and left thin dashed lines there
    rep = picture_repeats(c)
    size = 256
    while size < 128 * rep and size < 4096:
        size *= 2
    w = 64 if wide else 4
    rows = []
    for y in range(size):
        v = (y + 0.5) / size * rep % 1.0
        px = []
        for x in range(w):
            col = (1.0, 1.0, 1.0)
            if st == "melt":
                a = melt_value(v, (x + 0.5) / w, wd)
                if g2:          # glow color at the band, the second color down the drips
                    k = max(0.0, min(1.0, (v - 0.5) / (0.3 * wd)))
                    col = [(g1[i] * (1 - k) + g2[i] * k) / 255.0 for i in range(3)]
            else:
                vv = v
                if st == "wavy":
                    # a strong wave (0.22 of a repeat, 4 across = 2 per side of the body)
                    vv = (v - 0.22 * math.sin(2 * math.pi * 4 * (x + 0.5) / w)) % 1.0
                r, gg, b, a = dko_item.band_profile(vv, style if st != "wavy" else "original", wd,
                                                    glow=g1 if g2 else None, trail=g2, tail_up=tail_up)
                if g2:
                    col = (r, gg, b)
            g = int(round(255 * a))
            if fx:
                # glowing layer: see-through where dark; white (tinted by the glow color), or for Two-tone the
                # colors themselves
                px.append(bytes((int(round(255 * col[0])), int(round(255 * col[1])), int(round(255 * col[2])), g)))
            else:
                px.append(bytes((g, g, g, g)))     # strap glow: grey AND alpha, whichever the material reads
        rows.append(b"".join(px))
    base = "gwc_band_" + c["id"]
    dko_item.make_xbm_json(base, adir, b"".join(rows), w, size)
    return dko_item.depot_dir(adir) + "\\" + base + ".xbm"


def color_material_full(tpl, c, band_path):
    m = color_material(tpl, c)
    _, sign = flow_of(c)
    spd = abs(float(c.get("speed", 0.5) if c.get("speed") is not None else 0.5))
    v = _val(m, "EmissiveTile")
    if v:
        v["EmissiveTile"] = 1.0             # Repeat is drawn into the glow picture (no wrap lines on the straps)
    if band_path:
        spd /= picture_repeats(c)
    v = _val(m, "ScrollSpeed")
    if v:
        v["ScrollSpeed"] = sign * spd
    # no strap surface (normal) map: it was laid out for the Glow Wraps' own layout and showed its seams as thin
    # bright lines on shiny finishes - without it the material uses its flat default
    m["values"] = [x for x in m["values"] if "Normal" not in x]
    if uses_layer(c):
        v = _val(m, "EmissiveColor")
        if v:
            v["EmissiveColor"]["Red"] = v["EmissiveColor"]["Green"] = v["EmissiveColor"]["Blue"] = 0
        v = _val(m, "EmissiveEV")
        if v:
            v["EmissiveEV"] = 0.0
    elif band_path:
        v = _val(m, "EmissiveMask")
        if v:
            v["EmissiveMask"]["DepotPath"]["$value"] = band_path
    return m


def strap_mesh(src_json, colors, bands, layout, out_json):
    """one strap mesh: the Glow Wraps geometry with only these colors as appearances (+ 'default')"""
    doc = json.load(open(src_json, encoding="utf-8"))
    R = doc["Data"]["RootChunk"]
    # Feet to head / Head to feet keep the Glow Wraps' own strap layout: each strap runs along its own piece of the
    # texture, so the glow travels ALONG every strap (a layout made from the body position made the short torso
    # straps flash). Center outward / Outside inward get a seamless layout by the distance from the belly.
    if layout.lstrip("t") != "v":
        sys.path.insert(0, HERE)
        import dko_gwc_mesh
        dko_gwc_mesh.relayout(doc, "center" if layout.endswith("c") else "height", around=0.0,
                              u_around=layout.startswith("w"), v_scale=1.0)
    # Wavy / Melt: the glowing layer is a copy of the strap's chunks just above it, INSIDE this mesh (chunks
    # n..2n-1), drawn with the see-through glow material. (As a separate piece it counted as a second garment and
    # the game squeezed the strap under it into the skin: jagged holes under the breasts.)
    layer = layout[0] in "wt"
    if layer:
        sys.path.insert(0, HERE)
        import dko_gwc_mesh
        dko_gwc_mesh.add_layer_chunks(doc, FX_PUSH)
    # template material: the one the Glow Wraps' gold appearance uses
    names = [e["name"]["$value"] for e in R["materialEntries"]]
    tpl_app = R["appearances"][0]
    for ap in R["appearances"]:
        if ap["Data"]["name"]["$value"] == "gold":
            tpl_app = ap
    first = tpl_app["Data"]["chunkMaterials"][0]["$value"]
    idx = R["materialEntries"][names.index(first)]["index"] if first in names else 0
    tpl_mat = R["localMaterialBuffer"]["materials"][idx]
    nchunks = len(tpl_app["Data"]["chunkMaterials"])
    if nchunks != LAYER_N:
        raise ValueError(f"the strap mesh has {nchunks} chunks, expected {LAYER_N}")
    mats, entries, apps = [], [], []
    for c in colors:
        mname = "gwc_" + c["id"]
        mats.append(color_material_full(tpl_mat, c, bands.get(c["id"])))
        entries.append({"$type": "CMeshMaterialEntry", "index": len(mats) - 1, "isLocalInstance": 1,
                        "name": {"$type": "CName", "$storage": "string", "$value": mname}})
        if layer:
            mats.append(fx_material(c, bands.get(c["id"])))
            entries.append({"$type": "CMeshMaterialEntry", "index": len(mats) - 1, "isLocalInstance": 1,
                            "name": {"$type": "CName", "$storage": "string", "$value": mname + "_fx"}})
    for nm in ["default"] + [c["id"] for c in colors]:
        ap = copy.deepcopy(tpl_app)
        ap["Data"]["name"]["$value"] = nm
        mname = "gwc_" + (colors[0]["id"] if nm == "default" else nm)
        cm = [mname] * nchunks + ([mname + "_fx"] * nchunks if layer else [])
        ap["Data"]["chunkMaterials"] = [{"$type": "CName", "$storage": "string", "$value": x} for x in cm]
        apps.append(ap)
    used = set()

    def ids(x):
        if isinstance(x, dict):
            if "HandleId" in x:
                used.add(int(x["HandleId"]))
            for v in x.values():
                ids(v)
        elif isinstance(x, list):
            for v in x:
                ids(v)
    ids({k: v for k, v in R.items() if k != "appearances"})
    nxt = max(used | {-1}) + 1
    for ap in apps:
        ap["HandleId"] = str(nxt)
        nxt += 1
    R["appearances"] = apps
    R["materialEntries"] = entries
    R["localMaterialBuffer"]["materials"] = mats
    for k in ("localMaterialInstances", "preloadLocalMaterialInstances", "externalMaterials", "preloadExternalMaterials"):
        if isinstance(R.get(k), list):
            R[k] = []
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(doc, f)


def _set_paths(o, old, new):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "$value" and isinstance(v, str) and old in v:
                o[k] = v.replace(old, new)
            else:
                _set_paths(v, old, new)
    elif isinstance(o, list):
        for v in o:
            _set_paths(v, old, new)


COMP = "s1_dancers_body_glow_wraps"
LAYER_N = 3        # render chunks of every strap mesh (checked when the straps are built)


def entity_files(adir):
    """ONE mesh entity, appearance file and root entity for every color (copies of the Glow Wraps ones on own
    paths). The item's appearance name carries the color AND its strap set: ..._!<color>+<set>, so ArchiveXL
    picks the strap mesh gwc_<set>_<feet>.mesh ({variant.2}) and the color's appearance in it ({variant.1}).
    (Two look-alike entities, one per strap set, got mixed up by the game.)"""
    dd = DEPOT
    me = json.load(open(os.path.join(STD, "mesh_entity.json"), encoding="utf-8"))
    _set_paths(me, "doubleko\\dancers_body_glow_wraps\\meshes\\dancers_body_glow_wraps_{feet}.mesh",
               dd + "\\gwc_{variant.2}_{feet}.mesh")
    _set_paths(me, "*{variant}", "*{variant.1}")
    app = json.load(open(os.path.join(STD, "app.json"), encoding="utf-8"))
    _set_paths(app, "doubleko\\glowstraps_clean\\dancers_body_glow_wraps\\_dancers_body_glow_wraps_mesh_entity.ent",
               dd + "\\gwc_mesh_entity.ent")
    root = json.load(open(os.path.join(STD, "root_entity.json"), encoding="utf-8"))
    _set_paths(root, "doubleko\\glowstraps_clean\\dancers_body_glow_wraps\\_application.app", dd + "\\gwc.app")
    # hidden pieces (chunk masks) of the short versions also hide their glowing-layer copies: Wavy / Melt meshes
    # carry the layer as chunks n..2n-1 (chunk k -> k + n); the plain meshes have no such chunks (bits ignored)
    n = LAYER_N
    for ap in app["Data"]["RootChunk"]["appearances"]:
        for po in ap["Data"].get("partsOverrides") or []:
            for co in po.get("componentsOverrides") or []:
                if co["componentName"]["$value"] == COMP:
                    m = int(co["chunkMask"]) & ((1 << n) - 1)
                    co["chunkMask"] = str(m | (m << n))
    for doc, nm in ((me, "gwc_mesh_entity.ent"), (app, "gwc.app"), (root, "gwc_root.ent")):
        doc["Header"]["ArchiveFileName"] = ""
        with open(os.path.join(adir, nm + ".json"), "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=1)
    return dd + "\\gwc_root.ent"


def make_factory(rows, out_json):
    doc = json.load(open(os.path.join(STD, "factory.json"), encoding="utf-8"))
    doc["Header"]["ArchiveFileName"] = ""
    doc["Data"]["RootChunk"]["compiledData"] = [[n, p, "true"] for n, p in rows]
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1)


def make_texts(colors, versions, out_json):
    ent = []
    for v in versions:
        suf, prefix = VERSIONS[v][0], VERSIONS[v][4]
        ent.append({"$type": "localizationPersistenceOnScreenEntry", "femaleVariant": DESC[v],
                    "maleVariant": "", "primaryKey": "0", "secondaryKey": f"gwc_desc_{suf}"})
        for c in colors:
            ent.append({"$type": "localizationPersistenceOnScreenEntry", "femaleVariant": f"{prefix} ({c['title']})",
                        "maleVariant": "", "primaryKey": "0", "secondaryKey": f"gwc_{c['id']}_{suf}"})
    loc = {"Header": HDR, "Data": {"Version": 195, "BuildVersion": 0, "RootChunk": {
        "$type": "JsonResource", "cookingPlatform": "PLATFORM_None", "root": {"HandleId": "0", "Data": {
            "$type": "localizationPersistenceOnScreenEntries", "entries": ent}}}, "EmbeddedFiles": []}}
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(loc, f, indent=1)


DATA_TAG = "# DKO-GWC-DATA: "


def make_yaml(colors, versions, atlas, path, raw_list, version_arg):
    lines = ["# ---- Dancers Body Glow Wraps - custom colors (made with the DKO Glow Wraps Colors tool) ----",
             "# Works on its own (needs ArchiveXL and TweakXL). Add one with the CET console, e.g.:"]
    items = []
    for v in versions:
        suf = VERSIONS[v][0]
        for c in colors:
            items.append(f"Items.doubleko_dancers_body_glow_wraps_{c['id']}_{suf}")
    lines += [f'# Game.AddToInventory("{i}")' for i in items]
    for v in versions:
        suf, _, short, _, _ = VERSIONS[v]
        lines += ["", f"Items.doubleko_dancers_body_glow_wraps_$(base_color)_{suf}:",
                  "  $base: Items.GenericInnerChestClothing", "  $instances:"]
        lines += [f'    - {{base_color: {c["id"]}, short: "{short}", set: {v}_{layout_of(c)}}}' for c in colors]
        lines += ["  appearanceName: dancers_body_glow_wraps_short_$(short)_!$(base_color)+$(set)",
                  "  entityName: gwc_factory_name",
                  f"  localizedDescription: LocKey#gwc_desc_{suf}",
                  f"  displayName: LocKey#gwc_$(base_color)_{suf}",
                  "  quality: Quality.Legendary",
                  "  icon:",
                  f"    atlasResourcePath: {atlas}",
                  "    atlasPartName: gwc_$(base_color)",
                  "  statModifiers:", "    - !append Quality.IconicItem", "    - !append Character.ScaleToPlayerLevel",
                  "  appearanceSuffixes: []",
                  "  statModifierGroups:", "    - !append-once Items.IconicQualityRandomization",
                  "  placementSlots:", "    - !append-once OutfitSlots.BodyUnder"]
    # the tool's own color list, so it can open this add-on again later (add / remove / edit colors)
    data = json.dumps({"tool": "DKO Glow Wraps Colors", "version": version_arg, "colors": raw_list}, separators=(",", ":"))
    lines += ["", "# The line below is read by DKO Glow Wraps Colors (Open existing add-on). Please leave it.",
              DATA_TAG + base64.b64encode(data.encode("utf-8")).decode()]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return items


def make_xl(path):
    xl = ["factories:", f"  - {DEPOT}\\gwc_factory.csv",
          "localization:", "  onscreens:", "    en-us:", f"      - {DEPOT}\\gwc_i18n_en_us.json"]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(xl) + "\n")


def run(cmd):
    say("   > " + " ".join(os.path.basename(c) if i == 0 else c for i, c in enumerate(cmd)))
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
    for ln in p.stdout.splitlines():
        if re.search(r"(rror|Failed)", ln):
            say("     " + ln.strip())
    return p.returncode, p.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("colors")
    ap.add_argument("--cli", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--mod", required=True)
    ap.add_argument("--version", default="sfw", choices=("sfw", "nsfw", "both"))
    ap.add_argument("--items", help="write the item ids here (for the store)")
    a = ap.parse_args()
    cli = [a.cli] if a.cli.lower().endswith(".exe") else (["dotnet", a.cli] if a.cli.lower().endswith(".dll") else [a.cli])

    raw = json.load(open(a.colors, encoding="utf-8"))
    if isinstance(raw, dict):
        raw = [raw]
    colors, seen = [], set()
    for c in raw:
        cid = clean_id(c.get("id", ""))
        if not cid:
            continue
        cid = short_id(cid, c.get("name"))
        if cid in TAKEN:
            cid = "custom_" + cid
            say(f"NOTE '{c.get('id')}' is already a Glow Wraps color - this one is called '{cid}'")
        while cid in seen:
            cid += "_2"
        seen.add(cid)
        t = re.sub(r"[^A-Za-z0-9 ,.()+-]", "", str(c.get("title") or "")).strip()
        c = dict(c, id=cid, title=t or title(cid))
        colors.append(c)
    if not colors:
        sys.exit("FAILED no colors in " + a.colors)
    versions = ["sfw", "nsfw"] if a.version == "both" else [a.version]
    say(f"colors: {len(colors)} ({', '.join(c['id'] for c in colors)})   versions: {', '.join(versions)}")

    if os.path.isdir(a.work):
        shutil.rmtree(a.work)
    adir = os.path.join(a.work, "archive", *DEPOT.split("\\"))
    os.makedirs(adir)
    src = os.path.join(a.work, "src")
    os.makedirs(src)

    say("=== 1/5 glow bands")
    bdir = adir
    bands = {}
    for c in colors:
        p = make_band(c, bdir)
        if p:
            bands[c["id"]] = p
    say(f"   {len(bands)} color(s) with their own glow band")

    say("=== 2/5 straps (" + ", ".join(versions) + ")")
    sets = []                                   # (version, layout) that some color uses
    for v in versions:
        for lay in ("v", "c", "tv", "tc", "wv", "wc"):
            if any(layout_of(c) == lay for c in colors):
                sets.append((v, lay))
    need = sorted({f"{v}_{MESH_SRC[ft]}" for v, _ in sets for ft in FEET})
    for n in need:
        shutil.copy(os.path.join(STD, n + ".mesh"), os.path.join(src, n + ".mesh"))
    rc, out = run(cli + ["convert", "serialize", src, "-o", src])
    rows = []
    for v, lay in sets:
        tag = f"{v}_{lay}"
        mine = [c for c in colors if layout_of(c) == lay]
        md = adir
        done = {}
        for ft in FEET:
            sj = os.path.join(src, f"{v}_{MESH_SRC[ft]}.mesh.json")
            if not os.path.isfile(sj):
                sys.exit("FAILED WolvenKit could not read the strap mesh " + os.path.basename(sj))
            outj = os.path.join(md, f"gwc_{tag}_{ft}.mesh.json")
            if MESH_SRC[ft] in done:
                shutil.copy(done[MESH_SRC[ft]], outj)
            else:
                strap_mesh(sj, mine, bands, lay, outj)
                done[MESH_SRC[ft]] = outj
        say(f"   {tag}: {len(mine)} color(s)")
    make_factory([("gwc_factory_name", entity_files(adir))], os.path.join(adir, "gwc_factory.csv.json"))

    say("=== 3/5 item icons and names")
    _, atlas = make_icons(colors, adir)
    make_texts(colors, versions, os.path.join(adir, "gwc_i18n_en_us.json.json"))

    say("=== 4/5 WolvenKit: game files")
    rc, out = run(cli + ["convert", "deserialize", adir, "-o", adir])   # (one flat folder: WolvenKit flattens)
    want = []
    for dp, _, fs in os.walk(adir):
        for f in fs:
            if f.endswith(".json") and f != "gwc_i18n_en_us.json":
                want.append(os.path.join(dp, f[:-5]))
    missing = [os.path.relpath(w, adir) for w in want if not os.path.isfile(w)]
    if missing:
        sys.exit("FAILED WolvenKit did not make: " + ", ".join(missing))
    for dp, _, fs in os.walk(adir):
        for f in fs:
            if f.endswith(".json") and f != "gwc_i18n_en_us.json":
                os.remove(os.path.join(dp, f))

    say("=== 5/5 packing the mod")
    md = os.path.join(a.mod, "archive", "pc", "mod")
    tw = os.path.join(a.mod, "r6", "tweaks", "doubleko")
    if os.path.isdir(a.mod):
        shutil.rmtree(a.mod)
    os.makedirs(md)
    os.makedirs(tw)
    pk = os.path.join(a.work, "pack", MOD)
    shutil.copytree(os.path.join(a.work, "archive"), pk)
    rc, out = run(cli + ["pack", pk, "-o", md])
    if not os.path.isfile(os.path.join(md, MOD + ".archive")):
        sys.exit("FAILED packing (see the log)")
    make_xl(os.path.join(md, MOD + ".archive.xl"))
    items = make_yaml(colors, versions, DEPOT + "\\gwc_icons.inkatlas", os.path.join(tw, "doubleko_glow_wraps_colors.yaml"),
                      raw, a.version)
    if a.items:
        with open(a.items, "w", encoding="utf-8") as f:
            json.dump(items, f, indent=1)
    say(f"DONE {len(items)} items")
    for i in items:
        say(f'   Game.AddToInventory("{i}")')


if __name__ == "__main__":
    main()
