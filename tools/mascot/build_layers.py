#!/usr/bin/env python3
"""Genera las capas animables de Toco (el tocororo de inocencIA).

Uso:  python3 tools/mascot/build_layers.py
Entrada: mascota/*.jpg (ilustración del autor, sin transparencia).
Salida:  assets/mascot/{tail,body,wing,branch,head,eye}.png y assets/mascot/layers.json

Solo depende de Pillow. Todo el trabajo se hace a la resolución original y al
final cada capa se reduce a la escala del lienzo (Pillow reduce RGBA con alfa
premultiplicado, así que no aparecen halos al escalar).

Algoritmo, a grandes rasgos:
 1. Recorte: los píxeles claros (luminancia > LIGHT_T) son "fondo posible".
    Se erosiona esa máscara (cierra fugas de 1-2 px en el contorno azul marino),
    se rellena desde las cuatro esquinas y se reconstruye el fondo dilatando
    de nuevo dentro de los píxeles claros. Lo no alcanzado es el pájaro: el
    pecho blanco queda dentro porque el contorno oscuro lo encierra.
 2. Borde: en una franja de 2 px fuera del pájaro el color se recompone como
    "tinta azul marino sobre blanco" según la luminancia (quita el tinte
    beige del escudo). Después se dilata la silueta STICKER_PX en forma
    redondeada (octógono) y se suaviza: ese anillo es la pegatina blanca.
 3. Capas: cada capa es silueta x máscara de región. Las regiones se definen
    con las constantes de abajo (medidas a ojo sobre la imagen original) y con
    detección automática del borde derecho del ala por filas.
    - head: polígono de la cabeza; corte inferior suave sobre la garganta.
    - body: todo lo demás; bajo la cabeza se pinta un cuello blanco/lavanda
      (extensión vertical del color del pecho con degradado) y bajo el ala se
      pinta el cuerpo (color del pecho/vientre prolongado hacia la izquierda y
      fundido a un verde oscuro de "espalda"), para que al girar no haya huecos.
    - wing: el ala; lo que el tronco tapa se repinta de verde ala.
    - branch: el extremo izquierdo del tronco, que en el dibujo está delante
      del ala; se dibuja encima del ala (copia exacta de lo que hay en body).
    - tail: la cola; se prolonga hacia arriba por debajo del vientre copiando
      píxeles a lo largo de la dirección de las plumas.
    - eye: el interior del ojo (esclerótica + pupila + brillo); en head el ojo
      queda "vacío" con el color de la esclerótica.
    Los bordes entre capas se suavizan solo hacia FUERA de la capa superior,
    de modo que a 0 grados la recomposición reproduce el recorte original.
"""
import glob
import json
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "mascot")

# ---------------------------------------------------------------------------
# Parámetros generales
# ---------------------------------------------------------------------------
LIGHT_T = 150          # luminancia por encima de la cual un píxel puede ser fondo
LEAK_CLOSE = 5         # tamaño del MinFilter que cierra fugas del contorno
STICKER_PX = 5         # grosor del borde blanco en px originales (~3.5 px finales)
CANVAS_H = 720         # alto del lienzo final; el ancho sale de la proporción
NAVY = (18, 36, 82)    # azul marino del contorno (muestreado)
BACK = (31, 91, 99)    # verde azulado oscuro de las plumas del ala (sombra/espalda)
LAVENDER = (205, 216, 242)  # lavanda de las sombras del pecho

# ---------------------------------------------------------------------------
# Coordenadas medidas a ojo, en píxeles de la imagen ORIGINAL (944x1130)
# ---------------------------------------------------------------------------
# Cabeza: polígono generoso por fuera (incluye la pegatina) y, por abajo, pegado
# al contorno superior del ala y luego cortando la garganta blanca.
HEAD_POLY = [
    (300, 0), (300, 262), (368, 296), (389, 301), (400, 296), (410, 292),
    (420, 290), (440, 288), (460, 288), (480, 292), (490, 296), (500, 301),
    (510, 309), (516, 316), (530, 320), (545, 336), (680, 336), (686, 314),
    (691, 297), (712, 296), (728, 299), (745, 303), (760, 306), (860, 306), (860, 0),
]
THROAT_FADE_X = (528, 700)   # tramo de garganta donde el corte es un degradado
THROAT_FADE_Y = (322, 336)   # alfa 1 arriba -> 0 abajo
# Cuello que se pinta en body bajo la cabeza (se recorta además con HEAD_POLY).
# Sus lados izquierdo y derecho llevan contorno azul marino y pegatina (solo se
# ven cuando la cabeza gira y deja al descubierto el cuello).
NECK_POLY = [(420, 302), (412, 232), (700, 232), (700, 300), (690, 340), (512, 340)]
NECK_SIDE_X = (440, 682)     # a la izquierda/derecha de esto se dibuja el contorno lateral
NECK_SAMPLE_Y = (338, 352)   # filas del pecho de donde se toma el color del cuello
NECK_SAMPLE_X = (522, 690)
NECK_ORIG_Y = (300, 318)     # entre estas filas el cuello pasa del color pintado al original

# Ala: el borde derecho (contra el pecho/vientre) se detecta por filas entre
# WING_SCAN_Y buscando hacia la izquierda el contorno azul marino desde WING_SCAN_X.
WING_SCAN_Y = (300, 560)
WING_SCAN_X = lambda y: 545 if y < 455 else 512
WING_EDGE_PAD = 0            # px que el ala se adentra en el pecho más allá del contorno
WING_TOP_LEFT = [(220, 360), (230, 280), (545, 280)]
WING_BOTTOM = [(418, 578), (405, 640), (372, 656), (335, 672), (322, 689), (300, 702), (220, 702)]

# Tronco: el extremo izquierdo está delante del ala.
LOG_BOX = (340, 548, 505, 675)     # caja donde se busca el color madera
LOG_FADE_X = (470, 500)            # fundido del lado derecho de la capa branch
# contorno del extremo del tronco (la capa branch no puede llevar trozos de vientre)
LOG_FRONT_POLY = [(346, 615), (358, 574), (384, 560), (430, 571), (505, 571), (505, 639),
                  (470, 645), (440, 654), (400, 673), (362, 664)]
WING_FEATHER_DIR = (0.48, -0.88)   # dirección de las plumas bajas del ala (hacia arriba-dcha)

# Cola: polígono generoso por fuera; arriba sigue el borde inferior del ala,
# del tronco y del vientre (el vientre se excluye además por color).
TAIL_POLY = [
    (140, 1090), (140, 702), (300, 702), (322, 689), (335, 672), (372, 656),
    (405, 648), (470, 648), (536, 671), (552, 678), (572, 670), (592, 657), (612, 648),
    (640, 641), (640, 1090),
]
TAIL_EXT_BOX = (330, 585, 595, 662)  # zona extra (bajo el cuerpo) para prolongar la cola
TAIL_DIR = (-0.34, 0.94)             # dirección de las plumas (de arriba-dcha a abajo-izq)

# Pivotes (px originales)
PIVOT_HEAD = (575, 300)   # cuello
PIVOT_WING = (470, 322)   # hombro
PIVOT_TAIL = (440, 655)   # arranque de la cola
MAX_ROT = {"head": 8.0, "wing": 8.0, "tail": 10.0}

# Ojo (px originales): centro, radio exterior (con el aro oscuro) y radio de la esclerótica
EYE_C = (571.0, 187.0)
EYE_R_OUT = 40.0       # radio del párpado: cubre el aro y las puntas bajas de la esclerótica
EYE_R_IN = 30.5        # esclerótica: la pupila desplazada se recorta a este círculo
PUPIL_C = (570.0, 191.0)
PUPIL_R = 25.0
MAX_GAZE = 7.0


# ---------------------------------------------------------------------------
# Utilidades de máscaras (PIL puro)
# ---------------------------------------------------------------------------
def pixels(im):
    f = getattr(im, "get_flattened_data", None)
    return list(f() if f else im.getdata())


def poly_mask(size, pts):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def cross_dilate(m):
    out = m
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        out = ImageChops.lighter(out, ImageChops.offset(m, dx, dy))
    return out


def dilate_round(m, r):
    """Dilatación aproximadamente redonda (alterna cuadrado y cruz = octógono)."""
    for i in range(r):
        m = m.filter(ImageFilter.MaxFilter(3)) if i % 2 == 0 else cross_dilate(m)
    return m


def erode_round(m, r):
    return ImageChops.invert(dilate_round(ImageChops.invert(m), r))


def soft_out(m, radius=0.9):
    """Suaviza el borde solo hacia fuera (dentro sigue siendo 255)."""
    return ImageChops.lighter(m, m.filter(ImageFilter.GaussianBlur(radius)))


def threshold(m, t=127):
    return m.point(lambda v: 255 if v > t else 0)


def mul(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.multiply(out, m)
    return out


def median_color(cols):
    if not cols:
        return None
    return tuple(sorted(c[i] for c in cols)[len(cols) // 2] for i in range(3))


def smooth_series(vals, rad):
    keys = sorted(vals)
    out = {}
    for k in keys:
        acc = [vals[j] for j in range(k - rad, k + rad + 1) if j in vals]
        out[k] = tuple(sum(c[i] for c in acc) / len(acc) for i in range(3))
    return out


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------
def main():
    srcs = sorted(glob.glob(os.path.join(ROOT, "mascota", "*.jpg")))
    if not srcs:
        sys.exit("No hay mascota/*.jpg")
    src = srcs[0]
    orig = Image.open(src).convert("RGB")
    W, H = orig.size
    lum = orig.convert("L")
    O = orig.load()

    # --- 1. Recorte por relleno desde los bordes --------------------------------
    light = lum.point(lambda v: 255 if v > LIGHT_T else 0)
    closed = light.filter(ImageFilter.MinFilter(LEAK_CLOSE))
    ff = closed.copy()
    for seed in ((0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)):
        if ff.getpixel(seed) == 255:
            ImageDraw.floodfill(ff, seed, 128)
    bg = ff.point(lambda v: 255 if v == 128 else 0)
    bg = mul(bg.filter(ImageFilter.MaxFilter(LEAK_CLOSE)), light)
    bird = ImageChops.invert(bg)
    # quedarse solo con la componente conexa principal
    comp = bird.copy()
    ImageDraw.floodfill(comp, (550, 420), 128)
    bird = comp.point(lambda v: 255 if v == 128 else 0)

    # --- 2. Color final + pegatina blanca -------------------------------------
    band = ImageChops.subtract(dilate_round(bird, 2), bird)
    full = Image.new("RGB", (W, H), (255, 255, 255))
    full.paste(orig, (0, 0), bird)
    F = full.load()
    Bd = band.load()
    for y in range(H):
        for x in range(W):
            if Bd[x, y]:
                a = max(0.0, min(1.0, (245 - lum.getpixel((x, y))) / 205.0))
                F[x, y] = lerp((255, 255, 255), NAVY, a)
    sil_bin = dilate_round(bird, STICKER_PX)
    sil = ImageChops.lighter(bird, sil_bin.filter(ImageFilter.GaussianBlur(1.0)))
    sil = mul(sil, dilate_round(sil_bin, 2))  # sin colas de blur lejanas

    size = (W, H)
    Bm = bird.load()
    bird_core = erode_round(bird, 4).load()   # interior a >4 px del borde exterior

    # --- 3a. Cabeza -------------------------------------------------------------
    head_bin = poly_mask(size, HEAD_POLY)
    fade = Image.new("L", size, 255)
    fd = fade.load()
    y0, y1 = THROAT_FADE_Y
    for y in range(y0 - 2, y1 + 3):
        v = int(round(255 * smoothstep((y1 - y) / float(y1 - y0))))
        for x in range(THROAT_FADE_X[0], THROAT_FADE_X[1] + 1):
            fd[x, y] = v
    head_a = mul(soft_out(head_bin), fade, sil)

    # ojo vacío en head: esclerótica lisa dentro del círculo interior
    scl = sorted((
        O[int(EYE_C[0] + r * math.cos(t)), int(EYE_C[1] + r * math.sin(t))]
        for r in (26, 27, 28) for t in [i * 0.1 for i in range(63)]
        if sum(O[int(EYE_C[0] + r * math.cos(t)), int(EYE_C[1] + r * math.sin(t))]) > 600), key=sum)
    sclera = scl[int(len(scl) * 0.7)]   # percentil 70: el blanco "medio-alto" del ojo
    head_rgb = full.copy()
    hr = head_rgb.load()
    cx, cy = EYE_C
    px_, py_ = PUPIL_C
    for y in range(int(cy - EYE_R_IN - 3), int(cy + EYE_R_IN + 4)):
        for x in range(int(cx - EYE_R_IN - 3), int(cx + EYE_R_IN + 4)):
            d = math.hypot(x - cx, y - cy)
            dp = math.hypot(x - px_, y - py_)
            # 1 dentro de la pupila (y de la esclerótica); 0 donde eye ya es semitransparente
            t = max(0.0, min(1.0, PUPIL_R + 2.0 - dp)) * max(0.0, min(1.0, EYE_R_IN - 0.5 - d))
            if t > 0:
                hr[x, y] = lerp(F[x, y], sclera, t)
    head = head_rgb.copy()
    head.putalpha(head_a)

    # ojo: la pupila con su brillo y su reflejo (lo que se mueve al mirar)
    eye_a = Image.new("L", size, 0)
    ea = eye_a.load()
    for y in range(int(py_ - PUPIL_R - 3), int(py_ + PUPIL_R + 4)):
        for x in range(int(px_ - PUPIL_R - 3), int(px_ + PUPIL_R + 4)):
            dp = math.hypot(x - px_, y - py_)
            d = math.hypot(x - cx, y - cy)
            ea[x, y] = int(255 * max(0.0, min(1.0, PUPIL_R + 3.0 - dp))
                           * max(0.0, min(1.0, EYE_R_IN + 1.0 - d)))
    eye = full.copy()
    eye.putalpha(eye_a)

    lid_cols = []
    for r in (41, 43, 45, 47):
        for i in range(90):
            t = i * 2 * math.pi / 90
            x, y = int(cx + r * math.cos(t)), int(cy + r * math.sin(t))
            if y < cy + 15:
                lid_cols.append(O[x, y])
    lid_cols = [c for c in lid_cols if c[2] > c[0] + 50 and 60 < c[2] < 200]
    lid = median_color(lid_cols)

    # --- 3b. Ala: borde derecho detectado por filas -----------------------------
    xr = {}
    for y in range(WING_SCAN_Y[0], WING_SCAN_Y[1] + 1):
        x = WING_SCAN_X(y)
        while x > 300:
            r, g, b = O[x, y]
            if (r + g + b) / 3 < 110 and b > r + 10:
                break
            x -= 1
        xr[y] = x + WING_EDGE_PAD
    ys = sorted(xr)
    xr = {y: sorted(xr[j] for j in range(y - 2, y + 3) if j in xr)[
        len([j for j in range(y - 2, y + 3) if j in xr]) // 2] for y in ys}
    wing_poly = WING_TOP_LEFT + [(xr[y], y) for y in ys] + WING_BOTTOM
    wing_bin = mul(poly_mask(size, wing_poly), ImageChops.invert(head_bin))

    # tronco (madera) por color dentro de LOG_BOX
    logm = Image.new("L", size, 0)
    lm = logm.load()
    for y in range(LOG_BOX[1], LOG_BOX[3]):
        for x in range(LOG_BOX[0], LOG_BOX[2]):
            r, g, b = O[x, y]
            if r > 60 and r > g > b and r - b > 45 and g - b > 8 and r - g > 18 and g > 0.3 * r:
                lm[x, y] = 255
    logm = erode_round(dilate_round(logm, 4), 1)
    logm = mul(logm, bird)
    # rellenar huecos internos del tronco
    tmp = ImageChops.invert(logm)
    ImageDraw.floodfill(tmp, (0, 0), 0)
    logm = ImageChops.lighter(logm, tmp)
    logm = mul(logm, poly_mask(size, [(LOG_BOX[0], LOG_BOX[1]), (LOG_BOX[2], LOG_BOX[1]),
                                     (LOG_BOX[2], LOG_BOX[3]), (LOG_BOX[0], LOG_BOX[3])]))

    wing_rgb = full.copy()
    wr = wing_rgb.load()
    WB = wing_bin.load()
    LM = logm.load()
    # lo que el tronco tapa del ala se rellena prolongando las plumas del ala
    # (copiando a lo largo de su dirección), para que al girar no asome madera
    fx, fy = WING_FEATHER_DIR
    for y in range(LOG_BOX[1], LOG_BOX[3]):
        for x in range(LOG_BOX[0], LOG_BOX[2]):
            if WB[x, y] and LM[x, y]:
                c = BACK
                for k in range(1, 200):
                    qx, qy = int(round(x + fx * k)), int(round(y + fy * k))
                    if not WB[qx, qy]:
                        break
                    if not LM[qx, qy] and Bm[qx, qy]:
                        c = F[qx, qy]
                        break
                wr[x, y] = c
    # contorno azul marino del borde del ala que queda oculto tras el tronco
    wring = mul(ImageChops.subtract(wing_bin, erode_round(wing_bin, 4)), erode_round(logm, 1)).load()
    for y in range(LOG_BOX[1], LOG_BOX[3]):
        for x in range(LOG_BOX[0], LOG_BOX[2]):
            if wring[x, y]:
                wr[x, y] = NAVY
    # borde del ala contra el pecho: en una franja de 3 px el antialias del
    # contorno se convierte en "tinta" azul marino con alfa (sin arrastrar
    # píxeles del pecho blanco ni del vientre rojo cuando el ala gira)
    edge_band = mul(ImageChops.subtract(dilate_round(wing_bin, 3), wing_bin), bird)
    wing_a = wing_bin.copy()
    WA = wing_a.load()
    right_band = Image.new("L", size, 0)
    RB = right_band.load()
    EB = edge_band.load()
    eb = edge_band.getbbox()
    for y in range(eb[1], eb[3]):
        for x in range(eb[0], eb[2]):
            if EB[x, y] and y in xr and x > xr[y] and not head_bin.getpixel((x, y)):
                RB[x, y] = 255
                r, g, b = O[x, y]
                if b >= r:
                    a = max(0.0, min(1.0, (240 - (r + g + b) / 3.0) / 130.0))
                    WA[x, y] = int(255 * a)
                    wr[x, y] = NAVY
    wing_a = mul(wing_a, sil)
    wing = wing_rgb.copy()
    wing.putalpha(wing_a)

    # rama delante del ala
    bfade = Image.new("L", size, 0)
    bf = bfade.load()
    for y in range(H):
        for x in range(LOG_BOX[0], LOG_FADE_X[1] + 1):
            bf[x, y] = int(255 * smoothstep((LOG_FADE_X[1] - x) / float(LOG_FADE_X[1] - LOG_FADE_X[0])))
    branch = full.copy()
    # sin píxeles del vientre rojo (la dilatación del tronco los atrapa en los bordes)
    notred = Image.new("L", size, 255)
    nr = notred.load()
    for y in range(LOG_BOX[1], LOG_BOX[3]):
        for x in range(LOG_BOX[0], LOG_BOX[2]):
            r, g, b = O[x, y]
            if r > 90 and g < 0.36 * r and b > 0.6 * g:   # rojo: g y b parecidos; madera: b << g
                nr[x, y] = 0
    front = mul(ImageChops.lighter(mul(logm, erode_round(notred, 1)), erode_round(logm, 5)),
                poly_mask(size, LOG_FRONT_POLY))
    branch.putalpha(mul(soft_out(front, 0.7), bfade, sil))

    # --- 3c. Cuerpo ---------------------------------------------------------------
    body_rgb = full.copy()
    br = body_rgb.load()

    # (i) bajo el ala: pecho/vientre prolongado hacia la izquierda -> espalda
    chest = {}
    for y in ys:
        cols = [F[x, y] for x in range(xr[y] + 3, xr[y] + 13)]
        chest[y] = median_color(cols)
    chest = smooth_series(chest, 6)
    # se pinta sobre el ala dilatada 3 px para tapar también el antialias del
    # contorno original (si no, al girar el ala quedaría su "fantasma")
    wing_u = ImageChops.lighter(wing_bin, right_band)
    WU = wing_u.load()
    wbbox = wing_u.getbbox()
    cmin, cmax = min(chest), max(chest)
    for y in range(wbbox[1], wbbox[3]):
        row = [x for x in range(wbbox[0], wbbox[2]) if WB[x, y]]
        if not row:
            continue
        edge = xr[y] if y in xr else row[-1]
        # por debajo del tronco ya no hay vientre detrás: solo "espalda"
        col = chest[min(max(y, cmin), cmax)] if y <= cmax + 20 else BACK
        reach = 0.15 * math.hypot(edge - PIVOT_WING[0], y - PIVOT_WING[1]) + 10
        for x in range(wbbox[0], wbbox[2]):
            if not WU[x, y] or LM[x, y] or not Bm[x, y] or not bird_core[x, y]:
                continue
            t = smoothstep((edge - x - reach) / 14.0)
            br[x, y] = lerp(col, BACK, t)

    # (ii) bajo la cabeza: cuello blanco/lavanda
    neck_bin = mul(poly_mask(size, NECK_POLY), head_bin, bird)
    ncol = {}
    for x in range(NECK_SAMPLE_X[0], NECK_SAMPLE_X[1] + 1):
        ncol[x] = median_color([F[x, y] for y in range(NECK_SAMPLE_Y[0], NECK_SAMPLE_Y[1])])
    ncol = smooth_series(ncol, 25)
    NB = neck_bin.load()
    nb = neck_bin.getbbox()
    for y in range(nb[1], nb[3]):
        shade = 0.30 * max(0.0, min(1.0, (NECK_ORIG_Y[1] - y) / 80.0))
        w = max(0.0, min(1.0, (y - NECK_ORIG_Y[0]) / float(NECK_ORIG_Y[1] - NECK_ORIG_Y[0])))
        for x in range(nb[0], nb[2]):
            if not NB[x, y]:
                continue
            sx = min(max(x, NECK_SAMPLE_X[0]), NECK_SAMPLE_X[1])
            c = lerp(ncol[sx], LAVENDER, shade)
            br[x, y] = lerp(c, F[x, y], w)
    # contorno lateral del cuello + pegatina (ocultos bajo la cabeza a 0 grados)
    side = Image.new("L", size, 0)
    ImageDraw.Draw(side).rectangle([0, 0, NECK_SIDE_X[0], 300], fill=255)
    ImageDraw.Draw(side).rectangle([NECK_SIDE_X[1], 0, W, 300], fill=255)
    ring = mul(ImageChops.subtract(neck_bin, erode_round(neck_bin, 4)), side)
    nborder = mul(ImageChops.subtract(dilate_round(neck_bin, STICKER_PX), neck_bin), side,
                  head_bin, ImageChops.invert(wing_bin), erode_round(sil_bin, 1))
    RG = ring.load()
    NBo = nborder.load()
    for y in range(nb[1] - 8, nb[3] + 8):
        for x in range(nb[0] - 8, nb[2] + 8):
            if RG[x, y]:
                br[x, y] = NAVY
            elif NBo[x, y]:
                br[x, y] = (255, 255, 255)
    neck_bin = ImageChops.lighter(neck_bin, nborder)

    # (iii) zona solo-cola
    belly = Image.new("L", size, 0)
    bl = belly.load()
    for y in range(560, 780):
        for x in range(330, 620):
            r, g, b = O[x, y]
            red = r > 100 and r - g > 60 and r - b > 45
            wood = r > 60 and r > g > b and r - b > 45 and g - b > 8 and r - g > 18
            if red or wood:
                bl[x, y] = 255
    belly = dilate_round(belly, 5)
    tail_poly = poly_mask(size, TAIL_POLY)
    tail_only = mul(tail_poly, ImageChops.invert(belly), ImageChops.invert(wing_bin))
    keep = ImageChops.invert(tail_only)
    body_a = mul(soft_out(keep), sil)
    # fuera del cuello, nada de body dentro de la cabeza
    hole = mul(head_bin, ImageChops.invert(neck_bin))
    body_a = mul(body_a, ImageChops.invert(hole))
    # bajo el ala la silueta de body se encoge 2 px: así el borde exterior
    # semitransparente de la pegatina lo pone solo el ala (sin doble alfa)
    sil_in = ImageChops.lighter(bird, erode_round(sil_bin, 2).filter(ImageFilter.GaussianBlur(1.0)))
    body_a = Image.composite(ImageChops.darker(body_a, sil_in), body_a, wing_bin)
    body = body_rgb.copy()
    body.putalpha(body_a)

    # --- 3d. Cola: prolongación por debajo del cuerpo ----------------------------
    tail_rgba = full.copy()
    tail_rgba.putalpha(mul(tail_only, sil))
    tail_ext = ImageChops.lighter(tail_poly, poly_mask(size, [
        (TAIL_EXT_BOX[0], TAIL_EXT_BOX[1]), (TAIL_EXT_BOX[2], TAIL_EXT_BOX[1]),
        (TAIL_EXT_BOX[2], TAIL_EXT_BOX[3]), (TAIL_EXT_BOX[0], TAIL_EXT_BOX[3])]))
    TO = tail_only.load()
    # la prolongación solo existe donde body o wing la tapan del todo a 0 grados:
    # así nunca asoma por fuera de la silueta original
    cover = threshold(ImageChops.lighter(body_a, wing_a), 250).load()
    TE = tail_ext.load()
    S_ = sil.load()
    T = tail_rgba.load()
    dx, dy = TAIL_DIR
    tb = tail_ext.getbbox()
    for y in range(tb[1], tb[3]):
        for x in range(tb[0], tb[2]):
            if not TE[x, y] or TO[x, y]:
                continue
            got = None
            for k in range(1, 260):
                qx, qy = int(round(x + dx * k)), int(round(y + dy * k))
                if qy >= H or qx < 0:
                    break
                if TO[qx, qy]:
                    got = (qx, qy)
                    break
            if got:
                c = F[got]
                T[x, y] = (c[0], c[1], c[2], S_[got] if cover[x, y] else 0)
            else:
                T[x, y] = (255, 255, 255, 0)
    tail = tail_rgba

    # --- 4. Escalado, recorte y JSON ---------------------------------------------
    bb = sil.getbbox()
    m = 3
    bb = (bb[0] - m, bb[1] - m, bb[2] + m, bb[3] + m)
    scale = CANVAS_H / float(bb[3] - bb[1])
    cw = int(round((bb[2] - bb[0]) * scale))
    ch = CANVAS_H

    def to_canvas(p):
        return [round((p[0] - bb[0]) * scale, 1), round((p[1] - bb[1]) * scale, 1)]

    os.makedirs(OUT_DIR, exist_ok=True)
    layers = []
    for name, im in (("tail", tail), ("body", body), ("wing", wing),
                     ("branch", branch), ("head", head), ("eye", eye)):
        small = im.crop(bb).resize((cw, ch), Image.LANCZOS)
        a = small.getchannel("A").point(lambda v: v if v > 2 else 0)
        small.putalpha(a)
        box = a.getbbox()
        part = small.crop(box)
        # píxeles totalmente transparentes a negro-cero: comprime mejor
        part = Image.composite(part, Image.new("RGBA", part.size, (0, 0, 0, 0)),
                               part.getchannel("A").point(lambda v: 255 if v else 0))
        path = os.path.join(OUT_DIR, name + ".png")
        part.save(path, optimize=True)
        layers.append({"name": name, "file": name + ".png", "x": box[0], "y": box[1],
                       "width": part.size[0], "height": part.size[1]})

    # anclas desde la silueta
    birdbb = bird.getbbox()
    Sm = sil_bin.load()
    top_y = sil_bin.getbbox()[1]
    top_xs = [x for x in range(W) if Sm[x, top_y + 1]]
    beak = max(((x, y) for y in range(240, 300) for x in range(700, W) if Bm[x, y]), key=lambda p: p[0])
    tail_tip = max(((x, y) for y in range(900, H) for x in range(150, 500) if Bm[x, y]), key=lambda p: p[1])
    head_top = (sum(top_xs) / len(top_xs), top_y)

    hex_ = lambda c: "#%02X%02X%02X" % tuple(int(v) for v in c)
    data = {
        "source": os.path.relpath(src, ROOT),
        "canvas": [cw, ch],
        "scale": round(scale, 5),
        "rotation": "grados; positivo = sentido horario en pantalla (como Canvas.rotate)",
        "order": [l["name"] for l in layers],
        "layers": layers,
        "pivots": {"head": to_canvas(PIVOT_HEAD), "wing": to_canvas(PIVOT_WING),
                   "tail": to_canvas(PIVOT_TAIL)},
        "max_rotation_deg": MAX_ROT,
        "moves_with": {"eye": "head", "branch": "body"},
        "eye": {
            "cx": to_canvas(EYE_C)[0], "cy": to_canvas(EYE_C)[1],
            "r": round(EYE_R_OUT * scale, 1),
            "r_inner": round(EYE_R_IN * scale, 1),
            "pupil_cx": to_canvas(PUPIL_C)[0], "pupil_cy": to_canvas(PUPIL_C)[1],
            "pupil_r": round(PUPIL_R * scale, 1),
            "max_gaze": round(MAX_GAZE * scale, 1),
            "lid_color": hex_(lid),
            "sclera_color": hex_(sclera),
        },
        "anchors": {"beak_tip": to_canvas(beak), "head_top": to_canvas(head_top),
                    "tail_tip": to_canvas(tail_tip)},
    }
    with open(os.path.join(OUT_DIR, "layers.json"), "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    # recorte completo (referencia para verificar la recomposición)
    if len(sys.argv) > 1:
        ref = full.copy()
        ref.putalpha(sil)
        ref.crop(bb).resize((cw, ch), Image.LANCZOS).save(sys.argv[1])
    print("canvas", cw, ch, "scale", round(scale, 4))
    for l in layers:
        print(l["file"], os.path.getsize(os.path.join(OUT_DIR, l["file"])), "bytes")


if __name__ == "__main__":
    main()
