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
    "kombi": dict(
        title="Die Kombination",
        tag="Empfehlung",
        idea="Entwurf 2 und Entwurf 6 in einem: die Silhouette, und im Magazin "
             "stecken fünf Manapatronen — eine je Sekunde der Regel. Sie liegen "
             "quer, Spitze nach vorn, und folgen der Krümmung des Magazins nach "
             "unten. Beim Zaubern erlöschen sie von oben nach unten. "
             "Das Zeitsymbol sitzt im Trommelvisier: das ist ohnehin ein Kreis, "
             "also wird es zum Zifferblatt mit fünf Marken und einem Zeiger — "
             "angeklebt werden musste dafür nichts.",
        works=["Die Fünf ist nicht mehr dekoriert, sie <b>ist</b> der Inhalt: "
               "fünf Patronen, fünf Sekunden. Das Logo erklärt das Addon, "
               "ohne ein Wort zu brauchen.",
               "Das Magazin trägt die Anzeige, der Handschutz bleibt frei — "
               "vorher kämpften zwei Anzeigeflächen um dieselbe Aufmerksamkeit.",
               "Lässt sich im Addon wirklich mitlaufen lassen: eine Patrone "
               "je verstrichener Sekunde."],
        fails=["Breitformat. Als quadratisches Icon bleibt oben und unten Luft.",
               "Unter 48&nbsp;px verschmelzen die Patronen zu einem blauen "
               "Streifen. Die Waffe bleibt erkennbar, die Fünf nicht.",
               "Die deutlichste Waffe im ganzen Satz — wenn das Addon "
               "irgendwo öffentlich gelistet wird, ist das der Entwurf, der "
               "am ehesten aneckt."],
        use="Kopfgrafik, Titelbild, Addon-Seite. Fürs kleine Icon Entwurf 4.",
        states=[("fünf Sekunden übrig", 5), ("drei", 3), ("eine", 1)],
    ),
    "silhouette": dict(
        title="Die Silhouette",
        tag="neu gezeichnet",
        idea="Dieselbe Waffe ohne die Patronen: der Handschutz ist der "
             "Fortschrittsbalken, das Magazin der Manavorrat. Neu gezeichnet mit "
             "den Teilen, an denen man eine MP5 wirklich erkennt — gekapseltes "
             "Korn, Spannhebel mit dem Knick nach vorn, Trommelvisier.",
        works=["Niemand muss raten, worauf der Name anspielt.",
               "Ruhiger als die Kombination: eine Anzeigefläche statt zwei."],
        fails=["Der Balken im Handschutz ist klein und liegt dort, wo man "
               "zuletzt hinsieht.",
               "Unter 48&nbsp;px ein goldener Fleck."],
        use="Wenn die Patronen zu verspielt wirken.",
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

ORDER = ["kombi", "silhouette", "magazin", "visier", "wortmarke",
         "kimme", "fuenfschuss"]

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
  .big{width:230px;border:1px solid #241f14;border-radius:3px}
  .states{display:flex;flex-direction:column;gap:6px;width:230px}
  .states div{border:1px solid #241f14;border-radius:3px}
  .states p{margin:0;font-size:11px;color:#5d5747;text-align:center}
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
  .optwrap{background:var(--panel);border:1px solid var(--line);border-radius:4px;padding:22px;margin:18px 0}
  .optwrap img{max-width:100%;height:auto;border:1px solid #241f14;border-radius:3px}
  table{border-collapse:collapse;width:100%;margin:12px 0;font-size:14px}
  th,td{border:1px solid var(--line);padding:7px 10px;text-align:left;vertical-align:top}
  th{background:#1b1812;color:var(--gold);font-weight:600}
  /* Die SVGs tragen nur ein viewBox, kein width/height - ohne diese Regel
     faellt der Browser auf 300x150 zurueck. */
  svg{display:block;width:100%;height:auto}
"""


def sizes_block(svg):
    out = []
    for px, cap in ((64, "64 px"), (32, "32 px"), (16, "16 px")):
        out.append('<figure><div style="width:%dpx">%s</div>'
                   '<figcaption>%s</figcaption></figure>' % (px, svg, cap))
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
  <div style="width:280px">%s</div>
  <div class="light" style="width:280px">%s</div>
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
        states = ""
        if t.get("states"):
            rows = "".join(
                '<div>%s</div><p>%s</p>'
                % (to_svg(fns[key](v)), cap) for cap, v in t["states"])
            states = '<div class="states">%s</div>' % rows
        cards.append("""
<h2>Entwurf %d &mdash; &bdquo;%s&ldquo;</h2>
<div class="variant">
  <div class="stage">
    <div class="big">%s</div>
    %s
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
</div>""" % (i, t["title"], svgs[key], sizes_block(svgs[key]), states, t["tag"], t["title"],
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
<h2>Die Animation</h2>
<p class="meta">F&uuml;r die README-Seite: eine Runde dauert sieben Sekunden und
l&auml;uft dann von vorn. F&uuml;nf Schuss, je einer pro Sekunde, danach f&auml;llt
das leere Magazin heraus und ein volles rastet ein. Das ist die 5-Sekunden-Regel
als Bild &ndash; w&auml;hrend man zaubert, leert sich das Magazin; danach ist wieder
aufgeladen.</p>
<div class="optwrap" style="text-align:center">
  <img src="nachladen.gif" alt="MP5-Logo: f&uuml;nf Schuss, dann nachladen"
       width="285" height="165" style="image-rendering:auto">
</div>
<p class="meta">Ein GIF, weil das auf GitHub ohne Umwege abspielt &ndash; kein
JavaScript, nichts zu erlauben. 285&times;165, 70&nbsp;Einzelbilder, 10&nbsp;Bilder
je Sekunde, rund 250&nbsp;KiB. Neu erzeugen mit
<code>python3 tools/logo/anim.py docs/logo</code>.</p>

<h2>Gegen&uuml;berstellung</h2>
<table>
  <tr><th>Entwurf</th><th>Format</th><th>Noch lesbar bei</th><th>Zeigt die f&uuml;nf Sekunden</th></tr>
  <tr><td><b>1 &ndash; Kombination</b></td><td>breit</td><td>48&nbsp;px</td><td><b>doppelt: f&uuml;nf Patronen und das Zifferblatt</b></td></tr>
  <tr><td>2 &ndash; Silhouette</td><td>breit</td><td>48&nbsp;px</td><td>nur als Balken</td></tr>
  <tr><td>3 &ndash; Magazin</td><td>hoch</td><td>32&nbsp;px</td><td>als Kerben</td></tr>
  <tr><td>4 &ndash; Visier</td><td>quadratisch</td><td>16&nbsp;px</td><td>ja, als Ringsegmente</td></tr>
  <tr><td>5 &ndash; Wortmarke</td><td>breit</td><td>16&nbsp;px</td><td>nein</td></tr>
  <tr><td>6 &ndash; Zielbild</td><td>quadratisch</td><td>24&nbsp;px</td><td>als Marken</td></tr>
  <tr><td>7 &ndash; F&uuml;nf Schuss</td><td>quadratisch</td><td>32&nbsp;px</td><td>ja, als f&uuml;nf Patronen</td></tr>
</table>

<h2>Empfehlung</h2>
<p class="meta"><b>Die Kombination als Hauptzeichen, Entwurf 4 als Icon.</b>
Mit den Patronen im Magazin ist die F&uuml;nf nicht mehr Dekoration, sondern der
Inhalt: f&uuml;nf Patronen, f&uuml;nf Sekunden. Das Logo erkl&auml;rt damit das
Addon, ohne ein Wort zu brauchen &ndash; und es l&auml;sst sich im Spiel wirklich
mitlaufen lassen, eine Patrone je verstrichener Sekunde.</p>
<p class="meta">Was es nicht kann, ist klein werden. Unter 48&nbsp;Pixeln verschmelzen
die Patronen zu einem blauen Streifen. F&uuml;rs Icon und das Favicon bleibt deshalb
<b>Entwurf 4</b>, das Visier: rund, mittig, und bei 16&nbsp;Pixeln noch lesbar. Die
beiden zusammen decken den breiten Kopf und das kleine Quadrat ab.</p>

<div class="footer">
MP5 &ndash; Logo-Entw&uuml;rfe &middot; Stand 21.11.2026 &middot; Entwurf zur Auswahl.
Keiner davon ist bisher irgendwo eingebaut.
</div>
</div></body></html>
""" % (CSS, "".join(cards))
    open(os.path.join(OUT, "index.html"), "w").write(index)
    print("geschrieben nach", OUT)


main()
