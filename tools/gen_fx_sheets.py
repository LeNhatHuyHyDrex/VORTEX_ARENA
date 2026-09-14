"""Build sprite sheets from the 2D Spell Effects pack (CC0) and copy RPG SFX.

Input : .packs_tmp/fx_spell/fx*/  (frame PNGs), .packs_tmp/sfx80/*.ogg
Output: assets/vfx/spell_fx/<name>.png  (one sheet per effect)
        assets/vfx/spell_fx/manifest.json
        assets/audio/rpg_sfx/*.ogg

Why sheets: the pack ships ~20 loose PNGs per effect; importing hundreds of
tiny textures slows Godot. One grid sheet + a manifest keeps it tidy.
"""
import json
import math
import os
import re
import shutil

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.join(ROOT, "..")
FX_SRC = os.path.join(PROJ, ".packs_tmp", "fx_spell")
SFX_SRC = os.path.join(PROJ, ".packs_tmp", "sfx80")
FX_OUT = os.path.join(PROJ, "assets", "vfx", "spell_fx")
SFX_OUT = os.path.join(PROJ, "assets", "audio", "rpg_sfx")

from PIL import Image

os.makedirs(FX_OUT, exist_ok=True)
os.makedirs(SFX_OUT, exist_ok=True)

manifest = {}
for entry in sorted(os.listdir(FX_SRC)):
    folder = os.path.join(FX_SRC, entry)
    if not os.path.isdir(folder):
        continue
    frames = []
    for f in sorted(os.listdir(folder)):
        if not f.lower().endswith(".png"):
            continue
        # Numeric sort so the animation order matches the original numbering.
        frames.append((f, folder))
    def key(item):
        m = re.search(r"(\d+)\.png$", item[0])
        return int(m.group(1)) if m else 0
    frames.sort(key=key)
    if not frames:
        continue
    imgs = [Image.open(os.path.join(d, f)).convert("RGBA") for f, d in frames]
    fw = max(im.width for im in imgs)
    fh = max(im.height for im in imgs)
    count = len(imgs)
    cols = min(count, 5)
    rows = int(math.ceil(count / float(cols)))
    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        cx = (i % cols) * fw + (fw - im.width) // 2
        cy = (i // cols) * fh + (fh - im.height) // 2
        sheet.paste(im, (cx, cy), im)
    name = entry  # e.g. fx3_fireBall
    sheet.save(os.path.join(FX_OUT, name + ".png"))
    manifest[name] = {"cols": cols, "rows": rows, "count": count,
                      "fw": fw, "fh": fh}
    print("sheet", name, count, "frames", cols, "x", rows)

with open(os.path.join(FX_OUT, "manifest.json"), "w") as fp:
    json.dump(manifest, fp, indent=1)

n = 0
for f in sorted(os.listdir(SFX_SRC)):
    if f.lower().endswith(".ogg"):
        shutil.copy2(os.path.join(SFX_SRC, f), os.path.join(SFX_OUT, f))
        n += 1
print("sfx copied:", n)
