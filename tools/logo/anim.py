"""Die Nachlade-Animation fuer die README-Seite.

Ablauf einer Runde (7 Sekunden, dann von vorn):

    bereit -> fuenf Schuss, je einer pro Sekunde -> leer
           -> Magazin faellt heraus -> neues rastet ein -> bereit

Das ist die 5-Sekunden-Regel als Bild: waehrend man zaubert, leert sich
das Magazin; danach ist wieder voll aufgeladen.

    python3 tools/logo/anim.py docs/logo
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from render import rasterize, write_png
from gif import write_gif
from logos import kombi

FPS = 10
SCALE = 1.4


def timeline():
    """Liste von Zustaenden, einer je Einzelbild."""
    f = []

    # Bereit
    for _ in range(6):
        f.append(dict(voll=5, sek=5))

    # Fuenf Schuss, je 8 Bilder. Das Muendungsfeuer verglueht ueber 3 Bilder.
    for schuss in range(5):
        rest = 4 - schuss
        for i in range(8):
            flash = (1.0, 0.6, 0.25)[i] if i < 3 else 0.0
            f.append(dict(voll=rest, sek=rest, flash=flash))

    # Leer stehenlassen
    for _ in range(4):
        f.append(dict(voll=0, sek=0))

    # Magazin faellt heraus
    for i in range(6):
        t = (i + 1) / 6
        f.append(dict(voll=0, sek=0, mag_dy=36 * t, mag_alpha=1 - t))

    # Kurz ohne Magazin
    for _ in range(2):
        f.append(dict(voll=0, sek=0, mag_dy=36, mag_alpha=0.0))

    # Neues Magazin rastet von unten ein
    for i in range(6):
        t = (i + 1) / 6
        f.append(dict(voll=5, sek=0, mag_dy=36 * (1 - t), mag_alpha=t))

    # Zifferblatt laeuft hoch: wieder bereit
    for s in (1, 2, 3, 4, 5, 5):
        f.append(dict(voll=5, sek=s))

    return f


def build(out_dir):
    states = timeline()
    frames, w, h = [], None, None
    for st in states:
        logo = kombi(voll=st.get("voll", 5), sek=st.get("sek"),
                     mag_dy=st.get("mag_dy", 0.0),
                     mag_alpha=st.get("mag_alpha", 1.0),
                     flash=st.get("flash", 0.0))
        w, h, buf = rasterize(logo, SCALE)
        frames.append(buf)

    delay = int(round(100 / FPS))
    path = os.path.join(out_dir, "nachladen.gif")
    write_gif(path, w, h, frames, [delay] * len(frames))
    return path, w, h, len(frames), states, frames


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "docs/logo"
    os.makedirs(out, exist_ok=True)
    path, w, h, n, states, frames = build(out)
    print("%s  %dx%d  %d Bilder  %.1f s  %d KiB"
          % (path, w, h, n, n / FPS, os.path.getsize(path) // 1024))

    # Ein paar Schluesselbilder zum Ansehen
    if len(sys.argv) > 2:
        for i in (0, 14, 30, 46, 52, 58, 64):
            if i < len(frames):
                write_png(os.path.join(sys.argv[2], "frame%02d.png" % i), w, h, frames[i])
