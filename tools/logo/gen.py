"""Erzeugt aus den Formbeschreibungen die Dateien unter docs/logo/."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from render import rasterize, write_png, to_svg
from logos import ALL, BG, GOLD, MANA, recolor

OUT = sys.argv[1] if len(sys.argv) > 1 else "docs/logo"

TEXT = {
    "magazin": dict(
        title="Das Magazin",
        tag="Favorit",
        idea="Das gebogene MP5-Magazin, aber es steckt Mana darin statt Munition. "
             "Der Füllstand ist der Wert, die fünf Kerben am Rücken sind die fünf Sekunden.",
        works=["Die Krümmung ist die eindeutigste Form, die die Waffe hat — "
               "man erkennt sie auch ohne den Rest.",
               "Ein Füllstand ist von Haus aus eine Anzeige. Das Logo kann also "
               "dasselbe sagen wie das Addon, ohne eine Zahl zu zeigen.",
               "Hochformat: passt neben eine Überschrift, ohne breit zu werden."],
        fails=["Hochkant und schmal — im quadratischen Icon-Raster bleibt links "
               "und rechts Luft.",
               "Bei 16 Pixeln wird es ein Strich. Als Favicon müsste man die "
               "Kerben weglassen."],
        use="Addon-Icon, README-Kopf, Kurator-Eintrag.",
    ),
    "silhouette": dict(
        title="Die Silhouette",
        tag="am deutlichsten",
        idea="Die ganze Waffe in der Seitenansicht. Der Handschutz ist der "
             "Fortschrittsbalken, das Magazin ist der Manavorrat.",
        works=["Niemand muss raten, worauf der Name anspielt.",
               "Zwei Anzeigeflächen in einem Bild: Balken vorn, Vorrat unten."],
        fails=["Breitformat, und es braucht Platz. Unter 32 Pixeln fällt es "
               "zu einem goldenen Fleck zusammen.",
               "Am stärksten als Waffe lesbar — wenn das Addon irgendwo "
               "gelistet wird, ist das der Entwurf, der am ehesten aneckt."],
        use="Kopfgrafik, Titelbild einer Addon-Seite. Nicht als kleines Icon.",
    ),
    "visier": dict(
        title="Das Visier",
        tag="am besten skalierbar",
        idea="Das Trommelvisier der MP5, umgedeutet als Fünf-Sekunden-Ring: "
             "fünf Segmente, die beim Zaubern volllaufen. In der Mitte die "
             "Visierscheibe mit ihren vier Diopterlöchern und dem Manatropfen.",
        works=["Rund und mittig — das ideale Format für ein Icon.",
               "Der Ring ist eine echte Anzeige: drei von fünf Segmenten "
               "gefüllt heißt drei Sekunden vorbei. Lässt sich im Addon "
               "tatsächlich animieren.",
               "Bleibt bei 16 Pixeln als Ring mit Punkt lesbar."],
        fails=["Die Anspielung auf die Waffe ist die leiseste von allen. "
               "Wer die MP5 nicht kennt, sieht einen Timer — was nicht "
               "schlimm ist, aber den Witz kostet."],
        use="Überall. Icon, Favicon, Minimap-Knopf.",
    ),
    "wortmarke": dict(
        title="Die Wortmarke",
        tag="für Text",
        idea="M P 5 geometrisch gezeichnet. Die Punze des P ist ein Manatropfen, "
             "die 5 trägt die Krümmung des Magazins, und darunter läuft die "
             "Grundlinie als Manabalken voll.",
        works=["Der Name steht da. Kein Rätselraten, keine Erklärung nötig.",
               "Bleibt klein lesbar, weil Buchstaben dafür gebaut sind.",
               "Die Grundlinie kann denselben Füllstand zeigen wie die Anzeige."],
        fails=["Ohne die anderen Entwürfe daneben ist die Anspielung auf die "
               "Waffe praktisch unsichtbar.",
               "Eine Wortmarke ist kein Icon. Im Addon-Verzeichnis neben "
               "lauter Bildern fällt sie durch."],
        use="README-Kopf, Titelzeile im Handout, Chat-Präfix.",
    ),
    "kimme": dict(
        title="Das Zielbild",
        tag="Alternative",
        idea="Korn und Kimme, und dazwischen hängt der Manatropfen — das Bild, "
             "das man sieht, wenn man über die Visierung zielt. Unter der Kimme "
             "laufen fünf Marken voll.",
        works=["Der Tropfen in der Kerbe ist eine klare, ruhige Form.",
               "Die fünf Marken sitzen unten und stören den Kern nicht.",
               "Breiter als hoch, aber kompakt genug fürs Icon."],
        fails=["Ehrlich: das Zielbild liest sich nicht von selbst als Visierung. "
               "Wer es nicht weiß, sieht einen Tropfen über einem Sockel. "
               "Die Idee braucht die Bildunterschrift.",
               "Ich hatte vorher die Mündung von vorn gezeichnet, mit den "
               "Schlitzen des Handschutzes. Die las sich als Zahnrad — "
               "deshalb dieser Entwurf an ihrer Stelle."],
        use="Wenn Entwurf 3 zu neutral wirkt und Entwurf 2 zu wörtlich.",
    ),
    "fuenfschuss": dict(
        title="Fünf Schuss",
        tag="ohne Waffe",
        idea="Fünf Patronen nebeneinander, jede ein Manabehälter. Eine je Sekunde: "
             "sie laufen von links nach rechts voll.",
        works=["Die Fünf ist die Form selbst — man zählt sie, statt sie zu lesen.",
               "Zeigt keine Waffe, nur Munition. Deutlich zurückhaltender "
               "als Entwurf 2, wenn das Logo irgendwo öffentlich steht.",
               "Quadratisch und symmetrisch."],
        fails=["Bei kleinen Größen wird es ein Kamm — die einzelnen Füllstände "
               "verschwinden als Erstes.",
               "Fünf gleiche Formen nebeneinander sind ruhig, aber auch "
               "wenig einprägsam."],
        use="Ladebalken, Statusleiste, Trennelement im Handout.",
    ),
}

ORDER = ["magazin", "silhouette", "visier", "wortmarke", "kimme", "fuenfschuss"]

CSS = """
  :root{
    --bg:#0d0c0a; --panel:#15130f; --ink:#e8dfc8; --dim:#9c9177;
    --gold:#ffd100; --line:#3a3326; --ok:#4ad04a; --bad:#d87a7a;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);line-height:1.55;font-size:15px;
       font-family:"Segoe UI",system-ui,-apple-system,sans-serif}
  .wrap{max-width:1040px;margin:0 auto;padding:40px 24px 80px}
  h1{font-size:30px;margin:0 0 6px;color:var(--gold);letter-spacing:.5px}
  h2{font-size:21px;margin:48px 0 4px;border-bottom:1px solid var(--line);padding-bottom:8px}
  h3{font-size:15px;margin:14px 0 4px;color:var(--gold)}
  a{color:#8fc3ff}
  p{margin:8px 0}
  .lede{color:var(--dim);max-width:72ch}
  code{background:#000;padding:1px 5px;border-radius:3px;font-size:13px;color:#d8c89a}
  ul{margin:6px 0;padding-left:20px}
  li{margin:3px 0}
  .tag{display:inline-block;font-size:11px;letter-spacing:.6px;text-transform:uppercase;
       color:#0d0c0a;background:var(--gold);padding:1px 7px;border-radius:2px;
       margin-right:6px;vertical-align:2px}
  .variant{display:grid;grid-template-columns:300px 1fr;gap:28px;background:var(--panel);
           border:1px solid var(--line);border-radius:4px;padding:22px;margin:18px 0;
           align-items:start}
  @media(max-width:820px){.variant{grid-template-columns:1fr}}
  .stage{display:flex;flex-direction:column;align-items:center;gap:14px;min-width:0}
  .big{width:200px;height:200px;border:1px solid #241f14;border-radius:3px}
  .sizes{display:flex;align-items:flex-end;gap:14px}
  .sizes figure{margin:0;text-align:center}
  .sizes figcaption{font-size:10px;color:#5d5747;margin-top:4px}
  .meta{font-size:13.5px;color:var(--dim)}
  .pro{color:var(--ok)} .con{color:var(--bad)}
  .pro span,.con span{color:var(--dim)}
  .note{border-left:3px solid #e08a2a;background:#1a150c;padding:10px 14px;margin:16px 0;
        color:#d8c9a8;font-size:14px}
  .footer{margin-top:60px;border-top:1px solid var(--line);padding-top:14px;
          color:var(--dim);font-size:13px}
  table{border-collapse:collapse;width:100%;margin:12px 0;font-size:14px}
  th,td{border:1px solid var(--line);padding:7px 10px;text-align:left;vertical-align:top}
  th{background:#1b1812;color:var(--gold);font-weight:600}
  /* Die SVGs tragen nur ein viewBox, kein width/height - ohne diese Regel
     faellt der Browser auf 300x150 zurueck. */
  svg{display:block;width:100%;height:100%}
"""


def sizes_block(svg):
    out = []
    for px, cap in ((64, "64 px"), (32, "32 px"), (16, "16 px")):
        out.append('<figure><div style="width:%dpx;height:%dpx">%s</div>'
                   '<figcaption>%s</figcaption></figure>' % (px, px, svg, cap))
    return '<div class="sizes">%s</div>' % "".join(out)


def main():
    os.makedirs(OUT, exist_ok=True)
    fns = dict((k, f) for k, _, f in ALL)
    svgs = {}

    for key in ORDER:
        logo = fns[key]()
        svg = to_svg(logo)
        svgs[key] = svg
        open(os.path.join(OUT, key + ".svg"), "w").write(svg + "\n")

        # Variante auf hellem Grund: die Aussparungen wandern mit, sonst
        # stuende das Logo mit seinem eigenen dunklen Kasten darauf.
        svg_light = to_svg(recolor(logo, "#efe7d4", "#2b2721"))
        open(os.path.join(OUT, key + "-hell.svg"), "w").write(svg_light + "\n")

        for scale, suffix in ((1.0, ""), (0.25, "-32")):
            w, h, b = rasterize(logo, scale)
            write_png(os.path.join(OUT, key + suffix + ".png"), w, h, b)

        t = TEXT[key]
        os.makedirs(os.path.join(OUT, key), exist_ok=True)
        detail = """<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MP5 Logo &ndash; %s</title><style>%s
  .pair{display:flex;gap:18px;flex-wrap:wrap;margin:18px 0}
  .pair div{border:1px solid var(--line);border-radius:3px;padding:18px}
  .light{background:#efe7d4}
</style></head><body><div class="wrap">
<p class="meta"><a href="../index.html">&larr; alle Entw&uuml;rfe</a></p>
<h1>%s</h1>
<p class="lede">%s</p>
<div class="pair">
  <div style="width:260px;height:260px">%s</div>
  <div class="light" style="width:260px;height:260px">%s</div>
</div>
<p class="meta">Links wie im Spiel, rechts auf hellem Grund. Die Aussparungen
&ndash; Kerben, Stege, Punzen &ndash; nehmen den Hintergrund jeweils mit, sonst
st&uuml;nde das Zeichen mit seinem eigenen dunklen Kasten auf dem Papier.</p>
%s
<h3>Was tr&auml;gt</h3><ul class="meta">%s</ul>
<h3>Was nicht</h3><ul class="meta">%s</ul>
<h3>Wof&uuml;r</h3><p class="meta">%s</p>
<p class="meta">Dateien: <code>%s.svg</code>, <code>%s-hell.svg</code>,
<code>%s.png</code> (128&nbsp;px), <code>%s-32.png</code></p>
<div class="footer">MP5 &ndash; Logo-Entw&uuml;rfe &middot; Stand 21.11.2026</div>
</div></body></html>
""" % (t["title"], CSS, t["title"], t["idea"], svg, svg_light, sizes_block(svg),
       "".join("<li class='pro'>+ <span>%s</span></li>" % w for w in t["works"]),
       "".join("<li class='con'>&ndash; <span>%s</span></li>" % w for w in t["fails"]),
       t["use"], key, key, key, key)
        open(os.path.join(OUT, key, "index.html"), "w").write(detail)

    cards = []
    for i, key in enumerate(ORDER, 1):
        t = TEXT[key]
        cards.append("""
<h2>Entwurf %d &mdash; &bdquo;%s&ldquo;</h2>
<div class="variant">
  <div class="stage">
    <div class="big">%s</div>
    %s
  </div>
  <div>
    <h3><span class="tag">%s</span>%s</h3>
    <p class="meta">%s</p>
    <ul class="meta">%s%s</ul>
    <p class="meta"><b>Wof&uuml;r:</b> %s &middot;
    <a href="%s/index.html">Einzelansicht</a> &middot;
    <a href="%s.svg">SVG</a></p>
  </div>
</div>""" % (i, t["title"], svgs[key], sizes_block(svgs[key]), t["tag"], t["title"],
             t["idea"],
             "".join("<li class='pro'>+ <span>%s</span></li>" % w for w in t["works"]),
             "".join("<li class='con'>&ndash; <span>%s</span></li>" % w for w in t["fails"]),
             t["use"], key, key))

    index = """<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MP5 &ndash; Logo-Entw&uuml;rfe</title><style>%s</style></head>
<body><div class="wrap">
<h1>MP5 &ndash; Logo-Entw&uuml;rfe</h1>
<p class="lede">Sechs Entw&uuml;rfe in Anlehnung an die MP5, aber als Mana-Waffe mit
Zeitmesser: goldener Blizzard-Rahmen, Manablau, und &uuml;berall die F&uuml;nf aus den
f&uuml;nf Sekunden. Jeder Entwurf steht gro&szlig; und in drei Icon-Gr&ouml;&szlig;en da,
damit sichtbar ist, was beim Verkleinern als Erstes verschwindet.</p>

<div class="note">
<b>Alles sind Vektoren.</b> Die Zeichnungen auf dieser Seite sind dieselben SVGs,
die neben der Seite liegen &ndash; keine Bilder, kein Nachbau. Skalieren verlustfrei,
und die Farben lassen sich einzeln &auml;ndern.
</div>
%s
<h2>Gegen&uuml;berstellung</h2>
<table>
  <tr><th>Entwurf</th><th>Format</th><th>Noch lesbar bei</th><th>Anspielung auf die Waffe</th></tr>
  <tr><td>1 &ndash; Magazin</td><td>hoch</td><td>32&nbsp;px</td><td>stark</td></tr>
  <tr><td>2 &ndash; Silhouette</td><td>breit</td><td>48&nbsp;px</td><td>unmissverst&auml;ndlich</td></tr>
  <tr><td>3 &ndash; Visier</td><td>quadratisch</td><td>16&nbsp;px</td><td>leise</td></tr>
  <tr><td>4 &ndash; Wortmarke</td><td>breit</td><td>16&nbsp;px</td><td>nur im Namen</td></tr>
  <tr><td>5 &ndash; Zielbild</td><td>quadratisch</td><td>24&nbsp;px</td><td>braucht die Bildunterschrift</td></tr>
  <tr><td>6 &ndash; F&uuml;nf Schuss</td><td>quadratisch</td><td>32&nbsp;px</td><td>Munition, keine Waffe</td></tr>
</table>

<h2>Empfehlung</h2>
<p class="meta"><b>Entwurf 3 als Icon, Entwurf 4 als Wortmarke.</b> Das Visier ist das
einzige, das bei 16&nbsp;Pixeln noch etwas sagt, und sein Ring kann im Addon
tats&auml;chlich mitlaufen &ndash; das Logo w&auml;re dann dieselbe Anzeige wie der Balken.
Die Wortmarke daneben nennt den Namen, den das Icon nicht zeigen kann. Zusammen
decken sie beide F&auml;lle ab, ohne dass man den Witz erkl&auml;ren muss.</p>
<p class="meta">Wenn es ein einzelnes Bild sein soll und Gr&ouml;&szlig;e keine Rolle
spielt: <b>Entwurf 1</b>. Die Magazinkr&uuml;mmung ist die einpr&auml;gsamste Form im
ganzen Satz, und ein F&uuml;llstand ist schon von sich aus das, was das Addon tut.</p>

<div class="footer">
MP5 &ndash; Logo-Entw&uuml;rfe &middot; Stand 21.11.2026 &middot; Entwurf zur Auswahl.
Keiner davon ist bisher irgendwo eingebaut.
</div>
</div></body></html>
""" % (CSS, "".join(cards))
    open(os.path.join(OUT, "index.html"), "w").write(index)
    print("geschrieben nach", OUT)


main()
