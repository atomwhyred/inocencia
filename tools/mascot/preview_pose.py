#!/usr/bin/env python3
"""Compone a Toco desde assets/mascot/layers.json en una pose dada (solo Pillow).

Sirve para revisar las capas igual que las dibujará el CustomPainter:
  - tail gira sobre pivots.tail, wing sobre pivots.wing, head (+eye) sobre pivots.head
  - eye se desplaza (mirada) y se recorta al círculo eye.r_inner
  - el párpado es un círculo de eye.lid_color y radio eye.r que baja desde arriba

Uso:
  python3 tools/mascot/preview_pose.py out.png [head=8] [wing=-8] [tail=10] [gx=3] [gy=0] [lid=0.5]
  python3 tools/mascot/preview_pose.py --sheet hoja.png [recorte_ref.png]
"""
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR = os.path.join(ROOT, "assets", "mascot")
NIGHT = (39, 39, 87)  # #272757


def load():
    with open(os.path.join(DIR, "layers.json"), encoding="utf-8") as fh:
        meta = json.load(fh)
    ims = {l["name"]: Image.open(os.path.join(DIR, l["file"])).convert("RGBA") for l in meta["layers"]}
    return meta, ims


def placed(meta, ims, name):
    l = next(l for l in meta["layers"] if l["name"] == name)
    c = Image.new("RGBA", tuple(meta["canvas"]), (0, 0, 0, 0))
    c.paste(ims[name], (l["x"], l["y"]))
    return c


def circle_mask(size, cx, cy, r, ss=4):
    big = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(big).ellipse([(cx - r) * ss, (cy - r) * ss, (cx + r) * ss, (cy + r) * ss], fill=255)
    return big.resize(size, Image.LANCZOS)


def rot(im, deg, pivot):
    if not deg:
        return im
    # Canvas.rotate positivo = horario en pantalla; PIL rota antihorario.
    return im.rotate(-deg, resample=Image.BICUBIC, center=tuple(pivot))


def compose(meta, ims, head=0.0, wing=0.0, tail=0.0, gx=0.0, gy=0.0, lid=0.0):
    size = tuple(meta["canvas"])
    e = meta["eye"]
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out = Image.alpha_composite(out, rot(placed(meta, ims, "tail"), tail, meta["pivots"]["tail"]))
    out = Image.alpha_composite(out, placed(meta, ims, "body"))
    out = Image.alpha_composite(out, rot(placed(meta, ims, "wing"), wing, meta["pivots"]["wing"]))
    out = Image.alpha_composite(out, placed(meta, ims, "branch"))
    # cabeza + ojo (+ párpado) como un grupo que gira junto
    grp = placed(meta, ims, "head")
    eye = placed(meta, ims, "eye")
    if gx or gy:
        eye = ImageChops.offset(eye, int(round(gx)), int(round(gy)))
        a = ImageChops.multiply(eye.getchannel("A"), circle_mask(size, e["cx"], e["cy"], e["r_inner"]))
        eye.putalpha(a)
    grp = Image.alpha_composite(grp, eye)
    if lid > 0:
        col = tuple(int(e["lid_color"][i:i + 2], 16) for i in (1, 3, 5))
        eyedisc = circle_mask(size, e["cx"], e["cy"], e["r"])
        # el párpado baja desde arriba: semiplano y <= top + 2r*lid, recortado al disco
        cover = Image.new("L", size, 0)
        ImageDraw.Draw(cover).rectangle([0, 0, size[0], e["cy"] - e["r"] + 2 * e["r"] * lid], fill=255)
        lay = Image.new("RGBA", size, col + (255,))
        lay.putalpha(ImageChops.multiply(eyedisc, cover))
        grp = Image.alpha_composite(grp, lay)
    out = Image.alpha_composite(out, rot(grp, head, meta["pivots"]["head"]))
    return out


def on(bg, im):
    b = Image.new("RGBA", im.size, bg + (255,) if len(bg) == 3 else bg)
    return Image.alpha_composite(b, im)


def checker(size, a=(200, 60, 200), b=(60, 200, 90), s=12):
    im = Image.new("RGBA", size, a + (255,))
    d = ImageDraw.Draw(im)
    for y in range(0, size[1], s):
        for x in range(0, size[0], s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=b + (255,))
    return im


def sheet(path, ref_path=None):
    meta, ims = load()
    cw, ch = meta["canvas"]
    tiles = []
    base = compose(meta, ims)
    if ref_path:
        ref = Image.open(ref_path).convert("RGBA")
        diff = ImageChops.difference(on((255, 255, 255), ref), on((255, 255, 255), base)).convert("L")
        print("diferencia max recomposicion vs recorte:", diff.getextrema(),
              "pixeles >8:", sum(1 for v in (diff.get_flattened_data() if hasattr(diff, "get_flattened_data") else diff.getdata()) if v > 8))
        tiles.append(("recorte ref / claro", on((236, 236, 236), ref)))
    tiles.append(("0 grados / claro", on((236, 236, 236), base)))
    tiles.append(("0 grados / #272757", on(NIGHT, base)))
    for n in ("tail", "body", "wing", "branch", "head", "eye"):
        tiles.append(("capa " + n, Image.alpha_composite(checker((cw, ch)), placed(meta, ims, n))))
    poses = [("cabeza +8", dict(head=8)), ("cabeza -8", dict(head=-8)),
             ("ala +8", dict(wing=8)), ("ala -8", dict(wing=-8)),
             ("cola +10", dict(tail=10)), ("cola -10", dict(tail=-10)),
             ("todo + (8,8,10)", dict(head=8, wing=8, tail=10)),
             ("todo - (-8,-8,-10)", dict(head=-8, wing=-8, tail=-10))]
    for lab, kw in poses:
        tiles.append((lab, on(NIGHT, compose(meta, ims, **kw))))
    g = meta["eye"]["max_gaze"]
    for lab, kw in [("mirada arriba", dict(gy=-g)), ("mirada abajo", dict(gy=g)),
                    ("mirada izq", dict(gx=-g)), ("mirada dcha", dict(gx=g)),
                    ("parpado 50%", dict(lid=0.5)), ("parpado 100%", dict(lid=1.0))]:
        im = on((236, 236, 236), compose(meta, ims, **kw))
        e = meta["eye"]
        r = e["r"] * 2.2
        crop = im.crop((int(e["cx"] - r), int(e["cy"] - r), int(e["cx"] + r), int(e["cy"] + r)))
        tiles.append((lab, crop.resize((cw, int(cw * crop.size[1] / crop.size[0])), Image.LANCZOS)))
    cols = 6
    tw, th = cw, ch + 22
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * tw + (cols + 1) * 8, rows * th + (rows + 1) * 8), (250, 250, 250))
    d = ImageDraw.Draw(out)
    for i, (lab, im) in enumerate(tiles):
        x = 8 + (i % cols) * (tw + 8)
        y = 8 + (i // cols) * (th + 8)
        d.text((x + 4, y + 4), lab, fill=(0, 0, 0))
        out.paste(im.convert("RGB"), (x, y + 22))
    out.save(path)
    print("hoja:", path, out.size)


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--sheet":
        sheet(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
        return
    out = sys.argv[1]
    kw = {}
    for a in sys.argv[2:]:
        k, v = a.split("=")
        kw[k] = float(v)
    meta, ims = load()
    compose(meta, ims, **kw).save(out)


if __name__ == "__main__":
    main()
