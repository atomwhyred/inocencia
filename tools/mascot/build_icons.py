#!/usr/bin/env python3
"""Genera el icono de la app, el splash nativo de Android y el logo del splash de Flutter
a partir de las capas de Toco (assets/mascot). Solo Pillow.

  python3 tools/mascot/build_icons.py

Escribe:
  - android/app/src/main/res/mipmap-*/ic_launcher.png      icono clasico (cuadrado redondeado)
  - android/app/src/main/res/drawable-*/ic_launcher_foreground.png  primer plano del icono adaptativo
  - android/app/src/main/res/drawable-nodpi/splash_toco.png         imagen del splash en Android 10-11
  - assets/splash/toco.png                                          logo del splash de Flutter
Los XML (icono adaptativo, temas v31, colores) los mantiene el repositorio a mano.
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import preview_pose as pp  # noqa: E402

ROOT = pp.ROOT
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

BG = (220, 228, 255)  # #DCE4FF, primaryContainer del tema: Toco (azul) resalta sobre el
# Zona del lienzo de Toco que se ve en el icono: cabeza, ala y pecho (sin la cola larga).
ICON_CROP = (62, 0, 437, 462)
# Ancho del primer plano adaptativo (108 dp) y de su zona segura (66 dp).
ADAPTIVE_DP = 108
SAFE_FRACTION = 66 / 108


def toco():
    meta, ims = pp.load()
    return pp.compose(meta, ims)


def fit(im, box_w, box_h):
    """Escala [im] para que quepa en box_w x box_h sin deformarse."""
    s = min(box_w / im.width, box_h / im.height)
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


def centered(fg, size, bg=None):
    out = Image.new("RGBA", (size, size), bg or (0, 0, 0, 0))
    out.alpha_composite(fg, ((size - fg.width) // 2, (size - fg.height) // 2))
    return out


def rounded(im, radius_frac):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=int(im.width * radius_frac), fill=255)
    out = im.copy()
    out.putalpha(mask)
    return out


def main():
    full = toco()
    upper = full.crop(ICON_CROP)

    # Icono clasico por densidad (mdpi = 48 px).
    for name, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        fg = fit(upper, px * 0.80, px * 0.80)
        icon = rounded(centered(fg, px, BG + (255,)), 0.22)
        d = os.path.join(RES, f"mipmap-{name}")
        os.makedirs(d, exist_ok=True)
        icon.save(os.path.join(d, "ic_launcher.png"), optimize=True)

    # Primer plano del icono adaptativo: 108 dp, con Toco dentro de la zona segura (66 dp).
    for name, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)]:
        px = round(ADAPTIVE_DP * scale)
        safe = px * SAFE_FRACTION
        fg = fit(upper, safe * 0.96, safe * 0.96)
        d = os.path.join(RES, f"drawable-{name}")
        os.makedirs(d, exist_ok=True)
        centered(fg, px).save(os.path.join(d, "ic_launcher_foreground.png"), optimize=True)

    # Splash de Android 10-11: Toco entero, centrado, sobre el color de fondo.
    d = os.path.join(RES, "drawable-nodpi")
    os.makedirs(d, exist_ok=True)
    fit(full, 360, 560).save(os.path.join(d, "splash_toco.png"), optimize=True)

    # Logo del splash de Flutter (se muestra tras el nativo).
    d = os.path.join(ROOT, "assets", "splash")
    os.makedirs(d, exist_ok=True)
    fit(full, 440, 680).save(os.path.join(d, "toco.png"), optimize=True)
    print("listo")


if __name__ == "__main__":
    main()
