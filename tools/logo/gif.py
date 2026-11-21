"""Animiertes GIF aus RGB-Einzelbildern. Nur Standardbibliothek.

Ein GIF, weil das auf einer README-Seite ueberall abspielt - ohne
JavaScript, ohne dass der Betrachter etwas erlauben muss.
"""

import struct


# ------------------------------------------------------------------- Palette

def build_palette(frames, limit=255):
    """Haeufigste Farben aller Bilder, Rest wird auf die naechste abgebildet."""
    hist = {}
    for buf in frames:
        for i in range(0, len(buf), 3):
            c = (buf[i], buf[i + 1], buf[i + 2])
            hist[c] = hist.get(c, 0) + 1
    top = sorted(hist.items(), key=lambda kv: -kv[1])[:limit]
    return [c for c, _ in top]


def _nearest(c, pal):
    best, bd = 0, None
    for i, p in enumerate(pal):
        d = (c[0] - p[0]) ** 2 + (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2
        if bd is None or d < bd:
            best, bd = i, d
            if d == 0:
                break
    return best


def index_frame(buf, pal, cache):
    out = bytearray(len(buf) // 3)
    for n in range(len(out)):
        i = n * 3
        c = (buf[i], buf[i + 1], buf[i + 2])
        k = cache.get(c)
        if k is None:
            k = _nearest(c, pal)
            cache[c] = k
        out[n] = k
    return bytes(out)


# ----------------------------------------------------------------------- LZW

def lzw_encode(indices, min_code_size):
    clear = 1 << min_code_size
    end = clear + 1
    code_size = min_code_size + 1
    table = {}

    def reset():
        table.clear()
        for i in range(clear):
            table[(i,)] = i

    reset()
    next_code = end + 1

    bits, nbits = 0, 0
    out = bytearray()

    def emit(code, width):
        nonlocal bits, nbits
        bits |= code << nbits
        nbits += width
        while nbits >= 8:
            out.append(bits & 0xFF)
            bits >>= 8
            nbits -= 8

    emit(clear, code_size)
    if not indices:
        emit(end, code_size)
    else:
        prefix = (indices[0],)
        for ch in indices[1:]:
            cand = prefix + (ch,)
            if cand in table:
                prefix = cand
                continue
            emit(table[prefix], code_size)
            table[cand] = next_code
            next_code += 1
            # Verbreitern, sobald der naechste freie Code nicht mehr in die
            # aktuelle Breite passt - nicht erst danach. Eine Stelle zu spaet,
            # und der Decoder liest ab da Unsinn.
            if next_code == (1 << code_size):
                if code_size < 12:
                    code_size += 1
                else:
                    emit(clear, code_size)
                    reset()
                    code_size = min_code_size + 1
                    next_code = end + 1
            prefix = (ch,)
        emit(table[prefix], code_size)
        emit(end, code_size)

    if nbits:
        out.append(bits & 0xFF)
    return bytes(out)


def lzw_decode(data, min_code_size):
    """Gegenprobe zum Encoder - damit nicht blind ein GIF entsteht."""
    clear = 1 << min_code_size
    end = clear + 1
    code_size = min_code_size + 1
    table = [(i,) for i in range(clear)] + [None, None]

    out = []
    prev = None
    bits, nbits, pos = 0, 0, 0
    while True:
        while nbits < code_size and pos < len(data):
            bits |= data[pos] << nbits
            nbits += 8
            pos += 1
        if nbits < code_size:
            break
        code = bits & ((1 << code_size) - 1)
        bits >>= code_size
        nbits -= code_size

        if code == clear:
            table = [(i,) for i in range(clear)] + [None, None]
            code_size = min_code_size + 1
            prev = None
            continue
        if code == end:
            break
        if code < len(table) and table[code] is not None:
            entry = table[code]
        elif prev is not None:
            entry = prev + (prev[0],)
        else:
            break
        out.extend(entry)
        if prev is not None:
            if len(table) < 4096:
                table.append(prev + (entry[0],))
            # Der Decoder haengt dem Encoder um genau einen Eintrag
            # hinterher: den zum zuletzt gelesenen Code gehoerenden traegt
            # er erst beim naechsten Durchgang nach. Deshalb das +1 - sonst
            # liest er ab dem 255. Code mit der falschen Breite.
            if len(table) + 1 == (1 << code_size) and code_size < 12:
                code_size += 1
        prev = entry
    return bytes(out)


# ----------------------------------------------------------------------- GIF

def _blocks(data):
    out = bytearray()
    for i in range(0, len(data), 255):
        chunk = data[i:i + 255]
        out.append(len(chunk))
        out.extend(chunk)
    out.append(0)
    return bytes(out)


def write_gif(path, w, h, frames_rgb, delays_cs, loop=0):
    """frames_rgb: Liste von RGB-Listen. delays_cs: Verzoegerung je Bild in 1/100 s."""
    pal = build_palette(frames_rgb)
    bits = max(2, (len(pal) - 1).bit_length())
    size = 1 << bits
    pal = pal + [(0, 0, 0)] * (size - len(pal))

    out = bytearray(b"GIF89a")
    out += struct.pack("<HHBBB", w, h, 0xF0 | (bits - 1), 0, 0)
    for r, g, b in pal:
        out += bytes((r, g, b))

    out += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01" + struct.pack("<H", loop) + b"\x00"

    cache = {}
    for buf, delay in zip(frames_rgb, delays_cs):
        out += b"\x21\xF9\x04\x00" + struct.pack("<H", delay) + b"\x00\x00"
        out += b"\x2C" + struct.pack("<HHHHB", 0, 0, w, h, 0)
        idx = index_frame(buf, pal, cache)
        out += bytes((bits,)) + _blocks(lzw_encode(idx, bits))

    out += b"\x3B"
    open(path, "wb").write(bytes(out))
    return pal
