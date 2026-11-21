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


# ------------------------------------------------------------ 2 Silhouette

def silhouette(fill=0.55):
    """Vereinfachte MP5-Seitenansicht, der Handschutz ist der Balken."""
    shapes = []
    # Schulterstuetze: am Gehaeuse angesetzt statt schwebend
    shapes.append({"t": "poly", "pts": [(102, 48), (122, 50), (122, 58), (102, 58)],
                   "fill": GOLD_D})
    shapes.append({"t": "poly", "pts": [(110, 58), (122, 58), (122, 74), (112, 70)],
                   "fill": GOLD_D})
    # Gehaeuse
    shapes.append({"t": "poly", "pts": [(56, 44), (108, 44), (108, 66), (56, 66)],
                   "fill": GOLD})
    # Spannrohr oben
    shapes.append({"t": "poly", "pts": [(18, 38), (58, 38), (58, 46), (18, 46)],
                   "fill": GOLD_D})
    # Handschutz = Fortschrittsbalken
    hs = [(14, 48), (56, 48), (56, 64), (14, 64)]
    shapes.append({"t": "poly", "pts": hs, "fill": DARK})
    xend = 16 + (54 - 16) * fill
    shapes.append({"t": "poly", "pts": [(16, 50), (xend, 50), (xend, 62), (16, 62)],
                   "fill": MANA})
    shapes.append({"t": "poly", "pts": [(14, 48), (56, 48), (56, 50), (14, 50)],
                   "fill": GOLD})
    shapes.append({"t": "poly", "pts": [(14, 62), (56, 62), (56, 64), (14, 64)],
                   "fill": GOLD})
    # Korn vorne
    shapes.append({"t": "poly", "pts": [(22, 26), (30, 26), (28, 38), (24, 38)],
                   "fill": GOLD})
    # Trommelvisier: sitzt auf dem Gehaeuse auf
    shapes.append({"t": "poly", "pts": [(94, 38), (106, 38), (106, 46), (94, 46)],
                   "fill": GOLD})
    shapes.append({"t": "circle", "c": (100, 32), "r": 9, "fill": GOLD})
    shapes.append({"t": "circle", "c": (100, 32), "r": 4, "fill": BG})
    # Magazin: schmaler und deutlich nach vorn geneigt
    shapes.append({"t": "poly", "pts": [(60, 66), (76, 66), (68, 110), (54, 107)],
                   "fill": GOLD})
    shapes.append({"t": "poly", "pts": [(64, 72), (72, 72), (66, 104), (59, 102)],
                   "fill": MANA})
    # Abzugsbuegel
    shapes.append({"t": "poly", "pts": [(84, 66), (104, 66), (104, 71), (84, 71)],
                   "fill": GOLD})
    shapes.append({"t": "poly", "pts": [(86, 71), (90, 71), (90, 80), (86, 80)],
                   "fill": GOLD})
    shapes.append({"t": "poly", "pts": [(86, 80), (102, 80), (100, 85), (88, 85)],
                   "fill": GOLD})
    # Pistolengriff, nach hinten geneigt
    shapes.append({"t": "poly", "pts": [(92, 71), (106, 71), (102, 104), (90, 101)],
                   "fill": GOLD})
    return {"name": "silhouette", "size": (S, S), "bg": BG, "shapes": shapes}


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
    ("silhouette",  "Die Silhouette",   silhouette),
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
