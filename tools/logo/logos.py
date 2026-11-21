"""Die Logo-Entwuerfe als Formbeschreibung. Quelle fuer SVG und PNG."""

import math
from render import bez2, bez3, thick, clip_below

BG   = "#13110c"
GOLD = "#f2b839"
GOLD_D = "#b07f18"
MANA = "#8fc3ff"
MANA_D = "#3f6bb8"
DARK = "#0a0906"
DIM  = "#4a4433"

S = 128   # Kantenlaenge aller Entwuerfe


# --------------------------------------------------------------- 1 Magazin

def magazin(fill=0.58):
    """Das gebogene MP5-Magazin als Manabehaelter mit Sekundenmarken."""
    outer = (bez2((50, 12), (40, 62), (39, 104), 20)
             + [(68, 112)]
             + bez2((68, 112), (75, 62), (78, 12), 20)[::-1][:0]
             + bez2((78, 12), (75, 62), (68, 112), 20)[::-1]
             + [(50, 12)])
    inner = (bez2((55, 19), (46, 62), (45, 99), 20)
             + [(65, 105)]
             + bez2((71, 19), (69, 62), (65, 105), 20)[::-1]
             + [(55, 19)])

    ytop = 19 + (105 - 19) * (1 - fill)
    mana = clip_below(inner, ytop)

    shapes = [
        # Zufuehrlippen: sitzen auf dem Magazin, nicht daneben
        {"t": "poly", "pts": [(47, 6), (81, 6), (79, 16), (49, 16)], "fill": GOLD},
        {"t": "poly", "pts": [(53, 9), (75, 9), (74, 13), (54, 13)], "fill": DARK},
        {"t": "poly", "pts": outer, "fill": GOLD},
        {"t": "poly", "pts": inner, "fill": DARK},
        {"t": "poly", "pts": mana, "fill": MANA},
    ]
    # Fuenf Sekundenkerben, nur am Ruecken - quer durchgezogen sah es
    # aus wie eine Leiter und zerschnitt die Fuellung.
    for i in range(5):
        y = 30 + i * 16
        shapes.append({"t": "poly",
                       "pts": [(36, y), (52, y), (52, y + 3.5), (36, y + 3.5)],
                       "fill": BG})
        shapes.append({"t": "poly",
                       "pts": [(36, y), (46, y), (46, y + 3.5), (36, y + 3.5)],
                       "fill": GOLD})
    return {"name": "magazin", "size": (S, S), "bg": BG, "shapes": shapes}


# ----------------------------------- 2 Silhouette und 2+6 Kombination

SW, SH = 204, 118   # Breitformat fuer die Silhouetten.
# Hoehe 118, nicht 100: die Bodenplatte des Magazins reicht bis y=110
# und war vorher abgeschnitten.


def _kern(shapes, fill=GOLD, detail=GOLD_D):
    """Gemeinsame Teile: Lauf, Korn, Spannhebel, Gehaeuse, Visier, Griff."""
    # Lauf
    shapes.append({"t": "poly", "pts": [(8, 36), (28, 36), (28, 44), (8, 44)], "fill": detail})
    # Gekapseltes Korn: Ring auf einem Sockel - das auffaelligste Teil vorn
    shapes.append({"t": "poly", "pts": [(26, 24), (38, 24), (36, 36), (28, 36)], "fill": fill})
    shapes.append({"t": "ring", "c": (32, 20), "r": 8, "w": 4, "fill": fill})
    # Spannrohr oben, mit dem Knick nach vorn-oben
    shapes.append({"t": "poly", "pts": [(38, 22), (88, 22), (88, 31), (38, 31)], "fill": detail})
    # Spannhebel: sitzt hinter dem Korn, nicht darueber - vorher kreuzte
    # er den Ring und las sich als Haken.
    shapes.append({"t": "poly", "pts": thick((58, 27), (47, 11), 9), "fill": fill})
    # Gehaeuse
    shapes.append({"t": "poly", "pts": [(78, 28), (150, 28), (150, 50), (78, 50)], "fill": fill})
    # Auswurffenster
    shapes.append({"t": "poly", "pts": [(96, 33), (116, 33), (116, 40), (96, 40)], "fill": BG})
    # Trommelvisier hinten - traegt in der Kombination das Zifferblatt
    shapes.append({"t": "poly", "pts": [(132, 22), (152, 22), (152, 30), (132, 30)], "fill": detail})
    # Abzugsgruppe: Gehaeuse, dann der Buegel als Ring mit offener Mitte.
    # Vorher verschmolz er mit dem Griff zu einem Klumpen.
    shapes.append({"t": "poly", "pts": [(112, 50), (154, 50), (154, 60), (112, 60)], "fill": fill})
    shapes.append({"t": "poly", "pts": [(114, 60), (142, 60), (140, 80), (116, 80)], "fill": fill})
    shapes.append({"t": "poly", "pts": [(119, 63), (137, 63), (135, 75), (121, 75)], "fill": BG})
    shapes.append({"t": "poly", "pts": [(124, 60), (130, 60), (128, 72), (123, 71)], "fill": detail})
    # Pistolengriff, deutlich nach hinten geneigt und schmaler als das Magazin
    shapes.append({"t": "poly", "pts": [(138, 60), (156, 60), (152, 96), (136, 93)], "fill": fill})
    # Schulterstuetze
    shapes.append({"t": "poly", "pts": [(150, 32), (188, 36), (188, 46), (150, 48)], "fill": detail})
    shapes.append({"t": "poly", "pts": [(186, 28), (196, 28), (196, 58), (186, 56)], "fill": fill})


def _magazin(shapes, fill=GOLD, mana=0.62):
    """Nach vorn gekruemmtes Magazin, aussen Gold, innen Mana."""
    top_l, top_r = (80, 50), (106, 50)
    outer = ([top_l]
             + bez2((80, 50), (74, 76), (66, 96), 16)
             + [(88, 99)]
             + bez2((88, 99), (100, 76), (106, 50), 16)[::-1]
             + [top_r])
    shapes.append({"t": "poly", "pts": outer, "fill": fill})
    inner = ([(85, 54)]
             + bez2((85, 54), (79, 76), (73, 92), 16)
             + [(85, 94)]
             + bez2((85, 94), (96, 76), (101, 54), 16)[::-1]
             + [(101, 54)])
    shapes.append({"t": "poly", "pts": inner, "fill": DARK})
    from render import clip_below
    ytop = 54 + (94 - 54) * (1 - mana)
    shapes.append({"t": "poly", "pts": clip_below(inner, ytop), "fill": MANA})


# ------------------------------------------------------------------ 2a treu

def treu(fill=0.55):
    shapes = []
    # Handschutz = Fortschrittsbalken
    shapes.append({"t": "poly", "pts": [(28, 31), (82, 31), (82, 50), (28, 50)], "fill": GOLD})
    shapes.append({"t": "poly", "pts": [(32, 35), (78, 35), (78, 46), (32, 46)], "fill": DARK})
    xe = 34 + (76 - 34) * fill
    shapes.append({"t": "poly", "pts": [(34, 37), (xe, 37), (xe, 44), (34, 44)], "fill": MANA})
    _kern(shapes)
    trommel_uhr(shapes, 5)
    _magazin(shapes)
    return {"name": "sil-treu", "size": (SW, SH), "bg": BG, "shapes": shapes}


# ------------------------------------- 2+6 kombiniert: Patronen im Magazin

def trommel_uhr(shapes, sek=5, cx=143, cy=15, r=14, ring=True):
    """Das Trommelvisier als Zifferblatt - das Zeitsymbol sitzt damit an
    einem Teil, das die Waffe ohnehin hat, statt danebengeklebt zu werden."""
    if ring:
        for i in range(5):
            a0 = -90 + i * 72 + 4
            a1 = -90 + (i + 1) * 72 - 4
            shapes.append({"t": "arc", "c": (cx, cy), "r": r + 4, "w": 3.5,
                           "fill": GOLD if i < sek else DIM, "a0": a0, "a1": a1})
    shapes.append({"t": "circle", "c": (cx, cy), "r": r, "fill": GOLD})
    shapes.append({"t": "circle", "c": (cx, cy), "r": r - 3, "fill": DARK})
    for i in range(5):
        a = math.radians(-90 + i * 72)
        shapes.append({"t": "poly",
                       "pts": thick((cx + (r - 6) * math.cos(a), cy + (r - 6) * math.sin(a)),
                                    (cx + (r - 3.4) * math.cos(a), cy + (r - 3.4) * math.sin(a)),
                                    2.6),
                       "fill": GOLD if i < sek else DIM})
    a = math.radians(-90 + (5 - sek) * 72)
    shapes.append({"t": "poly",
                   "pts": thick((cx, cy), (cx + (r - 6) * math.cos(a),
                                           cy + (r - 6) * math.sin(a)), 2.8),
                   "fill": MANA})
    shapes.append({"t": "circle", "c": (cx, cy), "r": 2.2, "fill": MANA})


def muendungsfeuer(shapes, staerke=1.0):
    """Manablitz an der Muendung, fuer die Animation."""
    if staerke <= 0:
        return
    for i, ang in enumerate((-32, 0, 32)):
        a = math.radians(180 + ang)
        ln = (14 + 10 * staerke) * (1.0 if ang == 0 else 0.7)
        shapes.append({"t": "poly",
                       "pts": thick((8, 40), (8 + ln * math.cos(a), 40 + ln * math.sin(a)),
                                    7 * staerke if ang == 0 else 5 * staerke),
                       "fill": MANA if i != 1 else "#d8eaff",
                       "opacity": min(1.0, staerke)})
    shapes.append({"t": "circle", "c": (8, 40), "r": 6 * staerke, "fill": "#d8eaff",
                   "opacity": min(1.0, staerke)})


def verschiebe(shapes, dx, dy):
    """Formen versetzen - fuer das Magazin, das herausfaellt."""
    out = []
    for sh in shapes:
        sh = dict(sh)
        if sh["t"] == "poly":
            sh["pts"] = [(x + dx, y + dy) for x, y in sh["pts"]]
        elif sh["t"] in ("circle", "ring", "arc"):
            sh["c"] = (sh["c"][0] + dx, sh["c"][1] + dy)
        elif sh["t"] == "line":
            sh["a"] = (sh["a"][0] + dx, sh["a"][1] + dy)
            sh["b"] = (sh["b"][0] + dx, sh["b"][1] + dy)
        out.append(sh)
    return out


def _magazin_patronen(shapes, voll=3, n=5):
    """Durchsichtiges Magazin mit n Manapatronen - eine je Sekunde.

    Im Magazin liegen die Patronen quer, Spitze nach vorn, und stapeln sich
    nach unten. Die Kruemmung versetzt jede Reihe etwas weiter nach vorn.
    """
    # Magazinkoerper, nach vorn gekruemmt
    outer = ([(80, 48)]
             + bez2((80, 48), (73, 76), (62, 100), 18)
             + [(86, 104)]
             + bez2((86, 104), (102, 76), (108, 48), 18)[::-1]
             + [(108, 48)])
    shapes.append({"t": "poly", "pts": outer, "fill": GOLD})
    inner = ([(85, 53)]
             + bez2((85, 53), (78, 76), (69, 96), 18)
             + [(85, 99)]
             + bez2((85, 99), (97, 76), (103, 53), 18)[::-1]
             + [(103, 53)])
    shapes.append({"t": "poly", "pts": inner, "fill": DARK})

    # Die Patronen: Huelse plus Spitze, Spitze zeigt nach vorn (links)
    for i in range(n):
        y = 56.5 + i * 8.2
        dx = i * 3.4                      # folgt der Kruemmung nach vorn
        x0, x1 = 86 - dx, 102 - dx
        hell = i < voll
        case = MANA if hell else DIM
        tip = MANA_D if hell else "#3b3626"
        shapes.append({"t": "poly",
                       "pts": [(x0 + 4, y), (x1, y), (x1, y + 6), (x0 + 4, y + 6)],
                       "fill": case})
        shapes.append({"t": "poly",
                       "pts": [(x0 + 4, y), (x0 + 4, y + 6), (x0 - 2, y + 3)],
                       "fill": tip})

    # Bodenplatte
    shapes.append({"t": "poly", "pts": [(60, 100), (88, 104), (86, 110), (58, 106)],
                   "fill": GOLD_D})


def kombi(voll=3, mag_dy=0.0, mag_alpha=1.0, flash=0.0, sek=None):
    """Entwurf 2 mit Entwurf 6: die Silhouette, und im Magazin stecken
    fuenf Manapatronen - eine je Sekunde der Regel.

    mag_dy/mag_alpha bewegen und blenden das Magazin fuer die Animation,
    flash ist das Muendungsfeuer, sek die Stellung des Zifferblatts.
    """
    shapes = []
    muendungsfeuer(shapes, flash)
    # Handschutz schlicht, damit das Magazin die Anzeige traegt
    shapes.append({"t": "poly", "pts": [(28, 31), (82, 31), (82, 50), (28, 50)], "fill": GOLD})
    shapes.append({"t": "poly", "pts": [(33, 36), (77, 36), (77, 45), (33, 45)], "fill": DARK})
    for i in range(3):
        x = 36 + i * 14
        shapes.append({"t": "poly", "pts": [(x, 38), (x + 9, 38), (x + 9, 43), (x, 43)],
                       "fill": GOLD_D})
    _kern(shapes)
    trommel_uhr(shapes, voll if sek is None else sek)

    mag = []
    _magazin_patronen(mag, voll)
    if mag_dy or mag_alpha < 1.0:
        mag = verschiebe(mag, 0, mag_dy)
        if mag_alpha < 1.0:
            for sh in mag:
                sh["opacity"] = sh.get("opacity", 1.0) * mag_alpha
    shapes.extend(mag)
    return {"name": "sil-kombi", "size": (SW, SH), "bg": BG, "shapes": shapes}


# ---------------------------------------------------------------- 3 Visier

def visier(elapsed=3):
    """Das Trommelvisier als Fuenf-Sekunden-Ring."""
    shapes = [
        {"t": "ring", "c": (64, 64), "r": 46, "w": 4, "fill": DIM},
    ]
    # Fuenf Segmente mit Luecke, oben beginnend
    gap = 5
    for i in range(5):
        a0 = -90 + i * 72 + gap / 2
        a1 = -90 + (i + 1) * 72 - gap / 2
        shapes.append({"t": "arc", "c": (64, 64), "r": 46, "w": 11,
                       "fill": GOLD if i < elapsed else MANA_D,
                       "a0": a0, "a1": a1})
    # Visierscheibe mit den vier Diopterloechern
    shapes.append({"t": "circle", "c": (64, 64), "r": 31, "fill": GOLD_D})
    shapes.append({"t": "circle", "c": (64, 64), "r": 27, "fill": DARK})
    for i in range(4):
        a = math.radians(45 + i * 90)
        shapes.append({"t": "circle",
                       "c": (64 + 20 * math.cos(a), 64 + 20 * math.sin(a)),
                       "r": 3.4, "fill": GOLD_D})
    # Manatropfen in der Mitte
    drop = ([(64, 36)]
            + bez3((64, 36), (80, 56), (82, 62), (82, 70), 18)
            + bez3((82, 70), (82, 80), (74, 88), (64, 88), 14)
            + bez3((64, 88), (54, 88), (46, 80), (46, 70), 14)
            + bez3((46, 70), (46, 62), (48, 56), (64, 36), 18))
    shapes.append({"t": "poly", "pts": drop, "fill": MANA})
    return {"name": "visier", "size": (S, S), "bg": BG, "shapes": shapes}


# ------------------------------------------------------------- 4 Wortmarke

def _glyph_M(x, y, w, h, t):
    return [(x, y + h), (x, y), (x + t, y), (x + w / 2, y + h * 0.55),
            (x + w - t, y), (x + w, y), (x + w, y + h), (x + w - t, y + h),
            (x + w - t, y + h * 0.42), (x + w / 2, y + h * 0.95),
            (x + t, y + h * 0.42), (x + t, y + h)]


def _glyph_P(x, y, w, h, t):
    return [(x, y + h), (x, y), (x + w, y), (x + w, y + h * 0.56),
            (x + t, y + h * 0.56), (x + t, y + h)]


def wortmarke():
    """M P 5 geometrisch, die 5 traegt die Magazinkruemmung."""
    t = 11
    shapes = [
        {"t": "poly", "pts": _glyph_M(10, 44, 34, 44, t), "fill": GOLD},
        {"t": "poly", "pts": _glyph_P(50, 44, 26, 44, t), "fill": GOLD},
    ]
    # Punze des P als Manatropfen - der schwebende Punkt davor sah aus
    # wie ein Einschussloch an der falschen Stelle.
    punze = ([(66, 50)]
             + bez3((66, 50), (73, 57), (74, 59), (74, 62), 14)
             + bez3((74, 62), (74, 66), (70, 69), (66, 69), 12)
             + bez3((66, 69), (62, 69), (58, 66), (58, 62), 12)
             + bez3((58, 62), (58, 59), (59, 57), (66, 50), 14))
    shapes.append({"t": "poly", "pts": punze, "fill": MANA})
    # Die 5 als gebogenes Magazin
    five = [(84, 44), (116, 44), (116, 54), (94, 54), (93, 62)]
    five += bez2((93, 62), (118, 58), (116, 74), 14)
    five += bez2((116, 74), (116, 92), (96, 88), 14)
    five += [(86, 84), (90, 75), (98, 78)]
    five += bez2((98, 78), (107, 80), (106, 72), 10)
    five += bez2((106, 72), (105, 64), (84, 70), 10)
    shapes.append({"t": "poly", "pts": five, "fill": GOLD})
    # Grundlinie als Manabalken
    shapes.append({"t": "poly", "pts": [(10, 96), (116, 96), (116, 102), (10, 102)],
                   "fill": DIM})
    shapes.append({"t": "poly", "pts": [(10, 96), (74, 96), (74, 102), (10, 102)],
                   "fill": MANA})
    return {"name": "wortmarke", "size": (S, S), "bg": BG, "shapes": shapes}


# -------------------------------------------------------------- 5 Muendung

def kimme(elapsed=3):
    """Das Zielbild: Korn und Kimme, dazwischen der Manatropfen.

    Die Muendung von vorn hatte ich auch probiert - mit den Schlitzen des
    Handschutzes las sie sich als Zahnrad, und das Korn verschwand zwischen
    den Strahlen. Das Zielbild ist eindeutiger und bleibt klein lesbar.
    """
    shapes = []

    # Manatropfen, sitzt im Ausschnitt der Kimme
    drop = ([(64, 16)]
            + bez3((64, 16), (80, 38), (83, 44), (83, 52), 18)
            + bez3((83, 52), (83, 63), (75, 72), (64, 72), 14)
            + bez3((64, 72), (53, 72), (45, 63), (45, 52), 14)
            + bez3((45, 52), (45, 44), (48, 38), (64, 16), 18))
    shapes.append({"t": "poly", "pts": drop, "fill": MANA})
    shapes.append({"t": "circle", "c": (56, 47), "r": 5.5, "fill": "#bedcff"})

    # Kimme: Block mit Ausschnitt, der den Tropfen einfasst
    shapes.append({"t": "poly",
                   "pts": [(10, 68), (50, 68), (54, 88), (74, 88), (78, 68),
                           (118, 68), (118, 100), (10, 100)],
                   "fill": GOLD})
    # Zwei dunkle Stege auf den Schultern, wie bei einer Visierkimme
    shapes.append({"t": "poly",
                   "pts": [(18, 76), (42, 76), (42, 82), (18, 82)], "fill": BG})
    shapes.append({"t": "poly",
                   "pts": [(86, 76), (110, 76), (110, 82), (86, 82)], "fill": BG})

    # Fuenf Sekundenmarken auf der Kimme, von links auflaufend
    for i in range(5):
        x = 18 + i * 19
        shapes.append({"t": "poly",
                       "pts": [(x, 106), (x + 13, 106), (x + 13, 115), (x, 115)],
                       "fill": GOLD if i < elapsed else DIM})

    # Korn oben, als Gegenstueck zur Kimme
    shapes.append({"t": "poly", "pts": [(61, 2), (67, 2), (69, 14), (59, 14)],
                   "fill": GOLD_D})
    return {"name": "kimme", "size": (S, S), "bg": BG, "shapes": shapes}


# ----------------------------------------------------------- 6 Fuenf Schuss

def fuenfschuss(level=(1.0, 1.0, 1.0, 0.55, 0.0)):
    """Fuenf Patronen als Manabehaelter - eine je Sekunde."""
    shapes = []
    x0, w, gap = 12, 19, 4
    for i in range(5):
        x = x0 + i * (w + gap)
        top, bot = 26, 104
        # Geschoss mit Schulter: erst dadurch liest es sich als Patrone
        # und nicht als Buntstift.
        shapes.append({"t": "poly",
                       "pts": [(x + 4, top + 14), (x + w / 2, top - 4),
                               (x + w - 4, top + 14)],
                       "fill": GOLD_D})
        shapes.append({"t": "poly",
                       "pts": [(x + 4, top + 14), (x + w - 4, top + 14),
                               (x + w, top + 22), (x, top + 22)],
                       "fill": GOLD_D})
        # Huelse
        shapes.append({"t": "poly",
                       "pts": [(x, top + 22), (x + w, top + 22), (x + w, bot), (x, bot)],
                       "fill": GOLD})
        shapes.append({"t": "poly",
                       "pts": [(x + 3.5, top + 26), (x + w - 3.5, top + 26),
                               (x + w - 3.5, bot - 4), (x + 3.5, bot - 4)],
                       "fill": DARK})
        lv = level[i]
        if lv > 0:
            h = (bot - 4 - (top + 26)) * lv
            shapes.append({"t": "poly",
                           "pts": [(x + 3.5, bot - 4 - h), (x + w - 3.5, bot - 4 - h),
                                   (x + w - 3.5, bot - 4), (x + 3.5, bot - 4)],
                           "fill": MANA})
        # Bodenrand
        shapes.append({"t": "poly",
                       "pts": [(x - 1.5, bot), (x + w + 1.5, bot),
                               (x + w + 1.5, bot + 8), (x - 1.5, bot + 8)],
                       "fill": GOLD_D})
    return {"name": "fuenfschuss", "size": (S, S), "bg": BG, "shapes": shapes}


ALL = [
    ("magazin",     "Das Magazin",      magazin),
    ("silhouette",  "Die Silhouette",   treu),
    ("kombi",       "Die Kombination",  kombi),
    ("visier",      "Das Visier",       visier),
    ("wortmarke",   "Die Wortmarke",    wortmarke),
    ("kimme",       "Das Zielbild",     kimme),
    ("fuenfschuss", "Fuenf Schuss",     fuenfschuss),
]


def recolor(logo, bg, dark=None):
    """Variante auf anderem Grund. Alle Flaechen, die den Hintergrund
    nachbilden (Kerben, Aussparungen), wandern mit."""
    out = dict(logo)
    out["bg"] = bg
    shapes = []
    for sh in logo["shapes"]:
        sh = dict(sh)
        if sh["fill"] == logo.get("bg"):
            sh["fill"] = bg
        elif dark and sh["fill"] == DARK:
            sh["fill"] = dark
        shapes.append(sh)
    out["shapes"] = shapes
    return out
