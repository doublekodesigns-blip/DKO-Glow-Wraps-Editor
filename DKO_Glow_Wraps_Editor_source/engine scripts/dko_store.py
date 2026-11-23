"""Double K.O. Designs - Virtual Atelier store.
Keeps a list of every design built with the DKO Design Builder (creations.json) and writes the store script
"Double K.O. Designs" with all of them in all their colors. If a Double K.O. Designs store already exists in the
game (for example the one from the Dancers Body Glow Wraps mod), its items are kept: the new file has the same
name and store id, so it replaces that store with one that holds the old items AND the new designs.

    python dko_store.py <creations.json> <out folder> [--base <existing store .reds>] [--add NAME --title T --colors colors.json]

<out folder> receives the store mod: archive\\pc\\mod\\DoubleKO_Designs_Store.archive (store icon) and
r6\\scripts\\DoubleKODesigns\\DoubleKODesigns-atelier-store.reds"""
import argparse, json, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STORE_ID = "DoubleKODesigns"
STORE_TITLE = "Double K.O. Designs"
STORE_FILE = "DoubleKODesigns-atelier-store.reds"
ICON = "doubleko/glowstraps_clean/atelier/atelier_icon.inkatlas"    # forward slashes (Virtual Atelier needs them)
PRICE = 2000
# the Dancers Body Glow Wraps (Nexus mods "Dancers Body Glow Wraps" and "... NSFW"): always in the store. The store
# only shows the ones that are installed (see the script below), so it works with either, both or none of them.
WRAP_COLORS = ["gold", "silver", "white", "grey", "black", "blue", "orange", "green", "purple", "yellow_green",
               "red_purple", "pink", "hot_pink", "magenta", "turquoise", "cyan", "lime", "crimson", "lavender",
               "neon_pink", "neon_green", "neon_blue", "neon_yellow", "gold_pink", "red_matte", "orange_matte",
               "yellow_matte", "green_matte", "blue_matte", "purple_matte", "blue_orange", "purple_yellow", "red_cyan",
               "green_magenta", "cold_fire_navy", "cold_fire_violet", "silver_alt"]
WRAPS = [f"Items.doubleko_dancers_body_glow_wraps_{c}_{cut}" for cut in ("full", "nsfw") for c in WRAP_COLORS]


def store_script(items, note):
    """Virtual Atelier store script. Items that are not installed (no record in the game) are left out when the
    game starts, so the store never shows empty entries."""
    lst = ",\n".join(f'    "{i["id"]}"' for i in items)
    return f"""// {STORE_TITLE} - Virtual Atelier store. {note}
// Requires Virtual Atelier. Only the items that are installed are shown.
@addMethod(gameuiInGameMenuGameController)
protected cb func RegisterDoubleKODesignsStore(event: ref<VirtualShopRegistration>) -> Bool {{
  let all: array<String> = [
{lst}
  ];
  let allPrices: array<Int32> = [ {", ".join(str(i["price"]) for i in items)} ];
  let allQualities: array<String> = [ {", ".join('"' + i["quality"] + '"' for i in items)} ];
  let items: array<String>;
  let prices: array<Int32>;
  let qualities: array<String>;
  let i = 0;
  while i < ArraySize(all) {{
    if IsDefined(TweakDBInterface.GetItemRecord(TDBID.Create(all[i]))) {{
      ArrayPush(items, all[i]);
      ArrayPush(prices, allPrices[i]);
      ArrayPush(qualities, allQualities[i]);
    }}
    i += 1;
  }}
  event.AddStore(
    n"{STORE_ID}",
    "{STORE_TITLE}",
    items,
    prices,
    r"{ICON}",
    n"slot_01",
    qualities
  );
}}
"""


def read_items(path):
    """the item ids, prices and qualities of an existing Virtual Atelier store file (both store script formats)"""
    txt = open(path, encoding="utf-8", errors="replace").read()
    arrays = None
    m = re.search(r"let\s+all\s*:\s*array<String>\s*=\s*\[(.*?)\]\s*;.*?let\s+allPrices\s*:\s*array<Int32>\s*=\s*\[(.*?)\]\s*;"
                  r".*?let\s+allQualities\s*:\s*array<String>\s*=\s*\[(.*?)\]\s*;", txt, re.S)
    if m:                                   # newer script: only installed items are shown
        arrays = [m.group(1), m.group(2), m.group(3)]
    else:                                   # older script: the lists are written into AddStore(...)
        m = re.search(r"AddStore\s*\((.*)\)\s*;", txt, re.S)
        if not m:
            return []
        arrays = re.findall(r"\[(.*?)\]", m.group(1), re.S)
        if len(arrays) < 3:
            return []
    ids = re.findall(r'"([^"]+)"', arrays[0])
    prices = [int(p) for p in re.findall(r"\d+", arrays[1])]
    quals = re.findall(r'"([^"]+)"', arrays[2])
    out = []
    for i, it in enumerate(ids):
        out.append({"id": it, "price": prices[i] if i < len(prices) else (prices[-1] if prices else PRICE),
                    "quality": quals[i] if i < len(quals) else (quals[-1] if quals else "Legendary")})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("registry")
    ap.add_argument("out")
    ap.add_argument("--base", help="the Double K.O. Designs store file that is in the game now (its items are kept)")
    ap.add_argument("--add")
    ap.add_argument("--title")
    ap.add_argument("--colors")
    ap.add_argument("--extra", nargs=2, metavar=("GROUP", "ITEMS_JSON"),
                    help="a group of extra item ids (e.g. the Glow Wraps custom colors); replaces that group's old list")
    a = ap.parse_args()
    reg = {"designs": [], "base_items": []}
    if os.path.isfile(a.registry):
        try:
            reg.update(json.load(open(a.registry, encoding="utf-8")))
        except Exception:
            pass
    if a.add:
        cols = [c["id"] for c in json.load(open(a.colors, encoding="utf-8"))]
        reg["designs"] = [d for d in reg["designs"] if d["name"] != a.add]
        reg["designs"].append({"name": a.add, "title": a.title or a.add, "colors": cols})
    reg.setdefault("extra", {})
    if a.extra:
        reg["extra"][a.extra[0]] = list(json.load(open(a.extra[1], encoding="utf-8")))
    extra_ids = [i for g in reg["extra"].values() for i in g]
    mine = {f"Items.doubleko_{d['name']}_{c}" for d in reg["designs"] for c in d["colors"]}
    prefixes = tuple(f"Items.doubleko_{d['name']}_" for d in reg["designs"])
    if a.base and os.path.isfile(a.base):
        # items of the existing store that are not builder designs (e.g. the glow wraps) are kept
        old = [i for i in read_items(a.base) if i["id"] not in mine and not i["id"].startswith(prefixes)]
        if a.extra:   # this list replaces the old custom Glow Wraps colors
            old = [i for i in old if not (i["id"].startswith("Items.doubleko_dancers_body_glow_wraps_") and i["id"] not in WRAPS)]
        if old:
            reg["base_items"] = old
    with open(a.registry, "w", encoding="utf-8") as f:
        json.dump(reg, f, indent=1)

    items = [{"id": w, "price": PRICE, "quality": "Legendary"} for w in WRAPS]
    items += [i for i in (reg.get("base_items") or []) if i["id"] not in WRAPS]
    items += [{"id": f"Items.doubleko_{d['name']}_{c}", "price": PRICE, "quality": "Legendary"}
              for d in reg["designs"] for c in d["colors"]]
    items += [{"id": i, "price": PRICE, "quality": "Legendary"} for i in extra_ids]
    seen = set()
    items = [i for i in items if not (i["id"] in seen or seen.add(i["id"]))]
    reds = store_script(items, f"Written by the DKO Design Builder: the Dancers Body Glow Wraps + {len(reg['designs'])} builder designs.")
    sd = os.path.join(a.out, "r6", "scripts", "DoubleKODesigns")
    md = os.path.join(a.out, "archive", "pc", "mod")
    os.makedirs(sd, exist_ok=True)
    os.makedirs(md, exist_ok=True)
    with open(os.path.join(sd, STORE_FILE), "w", encoding="utf-8") as f:
        f.write(reds)
    shutil.copyfile(os.path.join(HERE, "store", "DoubleKO_Designs_Store.archive"),
                    os.path.join(md, "DoubleKO_Designs_Store.archive"))
    print(f"store: {len(items)} items (glow wraps + {len(reg['designs'])} designs + {len(extra_ids)} custom Glow Wraps colors)")


if __name__ == "__main__":
    main()
