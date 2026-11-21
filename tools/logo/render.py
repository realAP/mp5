"""Winziger Rasterizer: eine Formbeschreibung -> SVG und PNG.

Nur Standardbibliothek. Zweck: die Logos vor dem Ausliefern ansehen zu
koennen, statt sie blind zu schreiben. Beide Ausgaben entstehen aus
derselben Beschreibung, koennen also nicht auseinanderlaufen.

Formen:  poly, circle, ring, arc, line
Alles wird flach gefuellt - was fuer ein Icon ohnehin die richtige Wahl ist.
"""

import math
import struct
import zlib

SS = 3  # Supersampling pro Achse


# ---------------------------------------------------------------- Geometrie

def bez3(p0, p1, p2, p3, n=24):
    """Kubische Bezier zu Punkten verflachen."""
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = (u * u * u * p0[0] + 3 * u * u * t * p1[0]
             + 3 * u * t * t * p2[0] + t * t * t * p3[0])
        y = (u * u * u * p0[1] + 3 * u * u * t * p1[1]
             + 3 * u * t * t * p2[1] + t * t * t * p3[1])
        out.append((x, y))
    return out


def bez2(p0, p1, p2, n=18):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                    u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]))
    return out


def thick(a, b, w):
    """Dicke Linie als Viereck."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln * w / 2, dx / ln * w / 2
    return [(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny),
            (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)]


def hexrgb(c):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16))


# ---------------------------------------------------------------- Rastern

def _fill_poly(cov, w, h, pts, alpha):
    """Scanline-Fuellung, even-odd, in das Deckungsraster."""
    n = len(pts)
    if n < 3:
        return
    ys = [p[1] for p in pts]
    y0 = max(0, int(min(ys) * SS))
    y1 = min(h * SS - 1, int(max(ys) * SS) + 1)
    for sy in range(y0, y1 + 1):
        yc = (sy + 0.5) / SS
        xs = []
        for i in range(n):
            ax, ay = pts[i]
            bx, by = pts[(i + 1) % n]
            if (ay <= yc < by) or (by <= yc < ay):
                xs.append(ax + (yc - ay) / (by - ay) * (bx - ax))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            sx0 = max(0, int(xs[i] * SS))
            sx1 = min(w * SS - 1, int(xs[i + 1] * SS))
            for sx in range(sx0, sx1 + 1):
                xc = (sx + 0.5) / SS
                if xs[i] <= xc <= xs[i + 1]:
                    cov[sy * w * SS + sx] = alpha


def _fill_radial(cov, w, h, c, r_in, r_out, a0, a1, alpha):
    """Kreis, Ring oder Kreissegment ueber Abstand und Winkel."""
    cx, cy = c
    y0 = max(0, int((cy - r_out) * SS))
    y1 = min(h * SS - 1, int((cy + r_out) * SS) + 1)
    x0 = max(0, int((cx - r_out) * SS))
    x1 = min(w * SS - 1, int((cx + r_out) * SS) + 1)
    for sy in range(y0, y1 + 1):
        yc = (sy + 0.5) / SS - cy
        for sx in range(x0, x1 + 1):
            xc = (sx + 0.5) / SS - cx
            d = math.hypot(xc, yc)
            if not (r_in <= d <= r_out):
                continue
            if a0 is not None:
                ang = math.degrees(math.atan2(yc, xc)) % 360
                lo, hi = a0 % 360, a1 % 360
                inside = (lo <= ang <= hi) if lo <= hi else (ang >= lo or ang <= hi)
                if not inside:
                    continue
            cov[sy * w * SS + sx] = alpha


def _bbox(sh, scale, w, h):
    """Umgriff einer Form in Bildpunkten, auf das Bild beschnitten."""
    t = sh["t"]
    if t == "poly":
        xs = [p[0] for p in sh["pts"]]
        ys = [p[1] for p in sh["pts"]]
    elif t in ("circle", "ring", "arc"):
        r = sh["r"] + (sh.get("w", 0) / 2)
        xs = [sh["c"][0] - r, sh["c"][0] + r]
        ys = [sh["c"][1] - r, sh["c"][1] + r]
    elif t == "line":
        d = sh["w"]
        xs = [sh["a"][0] - d, sh["a"][0] + d, sh["b"][0] - d, sh["b"][0] + d]
        ys = [sh["a"][1] - d, sh["a"][1] + d, sh["b"][1] - d, sh["b"][1] + d]
    else:
        return 0, 0, w - 1, h - 1
    return (max(0, int(min(xs) * scale) - 1), max(0, int(min(ys) * scale) - 1),
            min(w - 1, int(max(xs) * scale) + 1), min(h - 1, int(max(ys) * scale) + 1))


def rasterize(logo, scale=1.0):
    w = int(logo["size"][0] * scale)
    h = int(logo["size"][1] * scale)
    bg = hexrgb(logo.get("bg", "#000000"))
    buf = [bg[0], bg[1], bg[2]] * (w * h)

    for sh in logo["shapes"]:
        col = hexrgb(sh["fill"])
        alpha = sh.get("opacity", 1.0)
        cov = [0.0] * (w * SS * h * SS)

        t = sh["t"]
        if t == "poly":
            _fill_poly(cov, w, h, [(x * scale, y * scale) for x, y in sh["pts"]], 1.0)
        elif t == "circle":
            _fill_radial(cov, w, h, (sh["c"][0] * scale, sh["c"][1] * scale),
                         0, sh["r"] * scale, None, None, 1.0)
        elif t == "ring":
            r, lw = sh["r"] * scale, sh["w"] * scale
            _fill_radial(cov, w, h, (sh["c"][0] * scale, sh["c"][1] * scale),
                         r - lw / 2, r + lw / 2, None, None, 1.0)
        elif t == "arc":
            r, lw = sh["r"] * scale, sh["w"] * scale
            _fill_radial(cov, w, h, (sh["c"][0] * scale, sh["c"][1] * scale),
                         r - lw / 2, r + lw / 2, sh["a0"], sh["a1"], 1.0)
        elif t == "line":
            _fill_poly(cov, w, h,
                       [(x * scale, y * scale)
                        for x, y in thick(sh["a"], sh["b"], sh["w"])], 1.0)

        # Herunterrechnen und auf den Hintergrund legen - nur im
        # Umgriff der Form. Ueber das ganze Bild zu laufen war der
        # Flaschenhals und machte Animationen unbezahlbar.
        bx0, by0, bx1, by1 = _bbox(sh, scale, w, h)
        for y in range(by0, by1 + 1):
            for x in range(bx0, bx1 + 1):
                s = 0.0
                for dy in range(SS):
                    base = (y * SS + dy) * w * SS + x * SS
                    for dx in range(SS):
                        s += cov[base + dx]
                a = (s / (SS * SS)) * alpha
                if a <= 0.001:
                    continue
                i = (y * w + x) * 3
                for k in range(3):
                    buf[i + k] = int(buf[i + k] * (1 - a) + col[k] * a + 0.5)

    return w, h, buf


def write_png(path, w, h, buf):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw.extend(buf[y * w * 3:(y + 1) * w * 3])

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)


# ---------------------------------------------------------------- SVG

def to_svg(logo, with_bg=True, extra_defs="", cls=None):
    w, h = logo["size"]
    out = []
    if with_bg:
        out.append('<rect width="%d" height="%d" fill="%s"/>' % (w, h, logo.get("bg", "none")))
    for sh in logo["shapes"]:
        op = '' if sh.get("opacity", 1.0) >= 1 else ' opacity="%.2f"' % sh["opacity"]
        f = sh["fill"]
        t = sh["t"]
        if t == "poly":
            pts = " ".join("%.2f,%.2f" % p for p in sh["pts"])
            out.append('<polygon points="%s" fill="%s"%s/>' % (pts, f, op))
        elif t == "circle":
            out.append('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"%s/>'
                       % (sh["c"][0], sh["c"][1], sh["r"], f, op))
        elif t == "ring":
            out.append('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="none" '
                       'stroke="%s" stroke-width="%.2f"%s/>'
                       % (sh["c"][0], sh["c"][1], sh["r"], f, sh["w"], op))
        elif t == "arc":
            cx, cy, r = sh["c"][0], sh["c"][1], sh["r"]
            a0, a1 = math.radians(sh["a0"]), math.radians(sh["a1"])
            x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
            x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
            large = 1 if (sh["a1"] - sh["a0"]) % 360 > 180 else 0
            out.append('<path d="M %.2f %.2f A %.2f %.2f 0 %d 1 %.2f %.2f" '
                       'fill="none" stroke="%s" stroke-width="%.2f" '
                       'stroke-linecap="butt"%s/>'
                       % (x0, y0, r, r, large, x1, y1, f, sh["w"], op))
        elif t == "line":
            out.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" '
                       'stroke="%s" stroke-width="%.2f" stroke-linecap="butt"%s/>'
                       % (sh["a"][0], sh["a"][1], sh["b"][0], sh["b"][1], f, sh["w"], op))
    body = "\n  ".join(out)
    c = ' class="%s"' % cls if cls else ''
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d"%s '
            'role="img">%s\n  %s\n</svg>' % (w, h, c, extra_defs, body))


def clip_below(pts, ycut):
    """Teil eines Polygons unterhalb von ycut (Sutherland-Hodgman)."""
    out = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        ain, bin_ = a[1] >= ycut, b[1] >= ycut
        if ain:
            out.append(a)
        if ain != bin_:
            t = (ycut - a[1]) / (b[1] - a[1])
            out.append((a[0] + t * (b[0] - a[0]), ycut))
    return out


def shrink(pts, d):
    """Polygon grob um d zum Schwerpunkt hin schrumpfen."""
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    out = []
    for x, y in pts:
        dx, dy = x - cx, y - cy
        ln = math.hypot(dx, dy) or 1.0
        f = max(0.0, (ln - d)) / ln
        out.append((cx + dx * f, cy + dy * f))
    return out
