#!/usr/bin/env python3
"""Strumento di lavoro: crea la grafica che non nasce dai modelli 3D.

Uso (dalla cartella del progetto):
    python3 strumenti/genera_arte.py texture     # texture ricolorate per i modelli
    python3 strumenti/genera_arte.py ambiente    # mattoni, sfondi, icona, palette
    python3 strumenti/genera_arte.py             # tutto

Le texture ricolorate finiscono in sorgenti3d/oggetti (le usa render_sprite.gd),
la grafica d'ambiente in arte/ambiente (la usa il gioco).
"""
import colorsys
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RADICE = Path(__file__).resolve().parent.parent
OGGETTI = RADICE / "sorgenti3d" / "oggetti"
AMBIENTE = RADICE / "arte" / "ambiente"


# ---------------------------------------------------------------- texture

def _hsv(img: np.ndarray) -> np.ndarray:
    """RGB 0..1 -> HSV 0..1, vettoriale."""
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    mx = img.max(axis=-1)
    mn = img.min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6.0
    h[gm] = (b - r)[gm] / d[gm] + 2.0
    h[bm] = (r - g)[bm] / d[bm] + 4.0
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return np.stack([h, s, mx], axis=-1)


def _rgb(hsv: np.ndarray) -> np.ndarray:
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    i = np.floor(h * 6.0).astype(int) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    out = np.zeros(hsv.shape)
    for k, (a, b, c) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[..., 0][m] = a[m]
        out[..., 1][m] = b[m]
        out[..., 2][m] = c[m]
    return out


def ricolora(origine: str, destinazione: str, regole: list) -> None:
    """Ogni regola: (h_min, h_max, s_min, s_max, v_min, v_max) -> (h, s_mul, s_add, v_mul, v_add).

    h = None lascia la tinta com'è. Le tinte sono in gradi. Vince la prima regola che combacia.
    """
    img = np.asarray(Image.open(OGGETTI / origine).convert("RGB")).astype(float) / 255.0
    hsv = _hsv(img)
    h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    fatto = np.zeros(h.shape, dtype=bool)
    nuovo = hsv.copy()
    for (h0, h1, s0, s1, v0, v1), (nh, sm, sa, vm, va) in regole:
        if h0 <= h1:
            mh = (h >= h0) & (h <= h1)
        else:  # intervallo a cavallo dello zero (rossi)
            mh = (h >= h0) | (h <= h1)
        m = mh & (s >= s0) & (s <= s1) & (v >= v0) & (v <= v1) & ~fatto
        if nh is not None:
            nuovo[..., 0][m] = nh / 360.0
        nuovo[..., 1][m] = np.clip(s[m] * sm + sa, 0, 1)
        nuovo[..., 2][m] = np.clip(v[m] * vm + va, 0, 1)
        fatto |= m
    out = (_rgb(nuovo) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(out, "RGB").save(OGGETTI / destinazione)
    print("texture:", destinazione)


def texture() -> None:
    # Il Non Narrato: mantello e cappuccio viola-notte, volto inghiottito dal buio.
    ricolora("rogue_texture.png", "protagonista_texture.png", [
        ((10, 40, 0.10, 0.48, 0.80, 1.0), (262, 0.0, 0.35, 0.0, 0.05)),      # pelle -> vuoto
        ((120, 200, 0.25, 1.0, 0.0, 1.0), (258, 0.0, 0.34, 0.50, 0.06)),      # verde -> viola-notte
        ((40, 120, 0.25, 1.0, 0.0, 1.0), (250, 0.0, 0.25, 0.55, 0.10)),       # orli giallo-verdi
        ((0, 45, 0.30, 1.0, 0.0, 1.0), (22, 0.45, 0.0, 0.62, 0.0)),           # cuoio più scuro
        ((0, 360, 0.0, 0.30, 0.0, 1.0), (235, 1.0, 0.06, 0.92, 0.0)),         # grigi appena freddi
    ])
    # Scheletri: ossa pallide e fredde, stoffe spente.
    ricolora("skeleton_texture.png", "scheletro_texture.png", [
        ((15, 60, 0.0, 0.45, 0.70, 1.0), (48, 0.55, 0.0, 0.90, 0.0)),         # ossa
        ((330, 15, 0.40, 1.0, 0.0, 1.0), (352, 0.85, 0.0, 0.62, 0.0)),        # rosso -> sangue secco
        ((200, 290, 0.25, 1.0, 0.0, 1.0), (268, 0.75, 0.0, 0.60, 0.0)),       # blu/viola -> stoffa logora
        ((0, 45, 0.30, 1.0, 0.0, 1.0), (24, 0.50, 0.0, 0.65, 0.0)),           # cuoio/legno
        ((0, 360, 0.0, 0.30, 0.0, 1.0), (230, 1.0, 0.05, 0.88, 0.0)),         # metallo
    ])


REGOLE_CUPE = [
    # (tinta da-a, saturazione da-a, luminosità da-a) -> (nuova tinta, sat×, sat+, lum×, lum+)
    ((10, 40, 0.10, 0.48, 0.80, 1.0), (262, 0.0, 0.35, 0.0, 0.05)),       # pelle -> vuoto (il Non Narrato non ha volto)
    ((120, 175, 0.25, 1.0, 0.0, 1.0), (258, 0.0, 0.34, 0.50, 0.06)),       # verdi -> viola-notte
    ((175, 200, 0.25, 1.0, 0.0, 1.0), (196, 0.55, 0.0, 0.55, 0.0)),        # verde-acqua -> acqua scura
    ((60, 120, 0.25, 1.0, 0.0, 1.0), (250, 0.0, 0.25, 0.55, 0.10)),        # giallo-verdi -> viola
    ((40, 60, 0.30, 1.0, 0.0, 1.0), (36, 0.55, 0.0, 0.62, 0.0)),           # oro -> bronzo spento
    ((200, 255, 0.20, 1.0, 0.0, 1.0), (222, 0.45, 0.0, 0.62, 0.0)),        # blu -> acciaio freddo
    ((255, 320, 0.20, 1.0, 0.0, 1.0), (272, 0.6, 0.0, 0.58, 0.0)),         # viola e magenta -> vino scuro
    ((320, 360, 0.35, 1.0, 0.0, 1.0), (352, 0.75, 0.0, 0.58, 0.0)),        # rossi -> sangue secco
    ((0, 10, 0.35, 1.0, 0.0, 1.0), (352, 0.75, 0.0, 0.58, 0.0)),
    ((0, 45, 0.30, 1.0, 0.0, 1.0), (22, 0.45, 0.0, 0.62, 0.0)),            # cuoio e legno più scuri
    ((0, 360, 0.0, 0.30, 0.0, 1.0), (235, 1.0, 0.06, 0.88, 0.0)),          # grigi appena freddi
]


def texture_cupe() -> None:
    """Le texture di tutti i personaggi KayKit nella stessa palette cupa: servono al manichino."""
    for nome in ["rogue", "knight", "barbarian", "mage", "skeleton"]:
        ricolora(nome + "_texture.png", nome + "_cupo.png", REGOLE_CUPE)


# ---------------------------------------------------------------- avvio

def main() -> None:
    cosa = sys.argv[1:] or ["texture", "ambiente"]
    if "texture" in cosa:
        texture()
        texture_cupe()
    if "ambiente" in cosa:
        ambiente()


# ---------------------------------------------------------------- ambiente

# La palette fissa del gioco: pochi colori cupi, scelti a mano.
PALETTE = """
07060b 0d0a12 15111d 1d1828 272036 322a44 40385a 554c72
1a1c22 262a32 353a44 474d58 5c6370 767e8a 969da6 b8bdc2
2a1408 4a1f0c 6e2e10 984514 c46a1c e39432 f4c35a fbe9a6
3a332c 5a4f42 7d6f5c a39478 c9bb9c e6dcc2
2a0a10 4d0f18 7a1620 a8242a d04038
0f2a3a 175066 2a86a0 6bd0e0 c8f4f8
12201a 213a2c 3a5a40
3a1f4a 5e2f74 8a4aa6
""".split()

LATO_LUT = 32


def _oklab(rgb: np.ndarray) -> np.ndarray:
    """sRGB 0..1 -> Oklab (distanze più vicine a quelle percepite dall'occhio)."""
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    l = 0.4122214708 * lin[..., 0] + 0.5363325363 * lin[..., 1] + 0.0514459929 * lin[..., 2]
    m = 0.2119034982 * lin[..., 0] + 0.6806995451 * lin[..., 1] + 0.1073969566 * lin[..., 2]
    s = 0.0883024619 * lin[..., 0] + 0.2817188376 * lin[..., 1] + 0.6299787005 * lin[..., 2]
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ], axis=-1)


def palette() -> None:
    colori = np.array([[int(c[i:i + 2], 16) for i in (0, 2, 4)] for c in PALETTE], dtype=np.uint8)
    Image.fromarray(colori[np.newaxis, :, :], "RGB").save(AMBIENTE / "palette.png")
    # Tabella di ricerca: per ogni colore possibile dà il colore di palette più vicino.
    # 32 fette da 32x32 affiancate (rosso in orizzontale, verde in verticale, blu = fetta).
    n = LATO_LUT
    asse = np.arange(n) / (n - 1)
    b, g, r = np.meshgrid(asse, asse, asse, indexing="ij")
    cubo = np.stack([r, g, b], axis=-1).reshape(-1, 3)
    lab_cubo = _oklab(cubo)
    lab_pal = _oklab(colori.astype(float) / 255.0)
    dist = ((lab_cubo[:, np.newaxis, :] - lab_pal[np.newaxis, :, :]) ** 2).sum(axis=-1)
    scelti = colori[dist.argmin(axis=1)].reshape(n, n, n, 3)  # [b][g][r]
    lut = np.concatenate([scelti[i] for i in range(n)], axis=1)  # altezza n, larghezza n*n
    Image.fromarray(lut, "RGB").save(AMBIENTE / "lut_palette.png")
    print("ambiente: palette.png (%d colori), lut_palette.png" % len(colori))


def icona() -> None:
    """Icona dell'app: il Non Narrato ingrandito su fondo viola-notte."""
    foglio = Image.open(RADICE / "arte" / "sprite" / "protagonista.png").convert("RGBA")
    figura = foglio.crop((0, 0, 96, 96))
    figura = figura.crop(figura.getbbox())
    lato = 432
    yy, xx = np.mgrid[0:lato, 0:lato]
    d = np.sqrt((xx - lato / 2) ** 2 + (yy - lato * 0.46) ** 2) / (lato * 0.62)
    alone = np.clip(1.0 - d, 0.0, 1.0) ** 1.6
    c0 = np.array([13, 10, 18], dtype=float)
    c1 = np.array([86, 62, 118], dtype=float)
    sfondo = (c0 + (c1 - c0) * alone[..., np.newaxis]).astype(np.uint8)
    sfondo = Image.fromarray(sfondo, "RGB").convert("RGBA")
    sfondo.save(AMBIENTE / "icona_sfondo.png")
    scala = 4
    grande = figura.resize((figura.width * scala, figura.height * scala), Image.NEAREST)
    primo = Image.new("RGBA", (lato, lato), (0, 0, 0, 0))
    primo.alpha_composite(grande, ((lato - grande.width) // 2 + 14, (lato - grande.height) // 2))
    primo.save(AMBIENTE / "icona_primo_piano.png")
    intera = sfondo.copy()
    intera.alpha_composite(primo)
    intera.convert("RGB").save(RADICE / "icon.png")
    print("ambiente: icone")


def rumore() -> None:
    """Nuvola che si ripete senza giunte: serve alla nebbia."""
    lato = 128
    rng = np.random.default_rng(7)
    totale = np.zeros((lato, lato))
    peso = 1.0
    for celle in (4, 8, 16, 32):
        griglia = rng.random((celle, celle))
        passo = lato // celle
        yy, xx = np.mgrid[0:lato, 0:lato]
        gx, gy = xx / passo, yy / passo
        x0, y0 = gx.astype(int) % celle, gy.astype(int) % celle
        x1, y1 = (x0 + 1) % celle, (y0 + 1) % celle
        fx, fy = gx - np.floor(gx), gy - np.floor(gy)
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        alto = griglia[y0, x0] * (1 - fx) + griglia[y0, x1] * fx
        basso = griglia[y1, x0] * (1 - fx) + griglia[y1, x1] * fx
        totale += (alto * (1 - fy) + basso * fy) * peso
        peso *= 0.5
    totale = (totale - totale.min()) / (totale.max() - totale.min())
    Image.fromarray((totale * 255).astype(np.uint8), "L").convert("RGB").save(AMBIENTE / "rumore.png")
    print("ambiente: rumore.png")


def ambiente() -> None:
    AMBIENTE.mkdir(parents=True, exist_ok=True)
    palette()
    rumore()
    icona()


if __name__ == "__main__":
    main()
