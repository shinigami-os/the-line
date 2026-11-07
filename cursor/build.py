#!/usr/bin/env python3
"""The Line's cursor theme, drawn with Pillow and written straight to XCursor files.

Flat and square like the rest of The Line: a dark fill, a 1 px light outline (visible on dark and light),
no shadow. The arrow is a sharp blade with the logo's chevron notch; the link pointer is the same arrow in
the accent; the busy cursor is the three slanted blades of the loading indicator, lit one after the other.
The pulse runs around the arrow, the link pointer and the text cursor in a loop: a short dash travels along the
outline, like the notification pulse on the line, pauses a moment, and goes round again.

    python3 cursor/build.py [output dir]      (default: cursor/build/TheLine)

Everything is drawn on a 32-unit grid and rendered at each size with 4x supersampling.
"""

import io
import math
import os
import struct
import sys
import zipfile

from PIL import Image, ImageDraw

SIZES = [24, 32, 48, 64]
SS = 4  # supersampling

FILL = (19, 18, 17, 255)       # bg
LINE = (236, 232, 225, 255)    # text
ACCENT = (154, 92, 255, 255)   # accent
ERROR = (239, 122, 94, 255)    # error
DIM = (90, 84, 76, 255)        # borderStrong


class Pen:
    """Draws in grid units on a supersampled canvas of one cursor size."""

    def __init__(self, size):
        self.size = size
        self.k = size * SS / 32.0
        self.img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        # 1 px outline at 32 px, a little thicker at larger sizes
        self.w = max(1, round(size / 32)) * SS

    def p(self, pts):
        return [(x * self.k, y * self.k) for x, y in pts]

    def shape(self, pts, fill=FILL, outline=LINE):
        """A filled polygon with a crisp outline drawn on top."""
        xy = self.p(pts)
        self.d.polygon(xy, fill=fill)
        self.d.line(xy + [xy[0]], fill=outline, width=self.w, joint="curve")

    def stroke(self, pts, color=LINE, width=1.0, halo=True):
        """A line in grid units; with a dark halo under it so it reads on light backgrounds."""
        xy = self.p(pts)
        w = max(SS, round(width * self.k))
        if halo:
            self.d.line(xy, fill=FILL, width=w + 2 * self.w, joint="curve")
        self.d.line(xy, fill=color, width=w, joint="curve")

    def rect(self, x0, y0, x1, y1, fill=FILL, outline=LINE):
        self.shape([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, outline)

    def dash(self, pts, start, length, color, closed=True, width=1.6):
        """A piece of the outline `pts`, from `start` along it, `length` long (grid units)."""
        path = pts + [pts[0]] if closed else pts
        out, walked = [], 0.0
        lo, hi = max(0.0, start), start + length
        for (x0, y0), (x1, y1) in zip(path, path[1:]):
            seg = math.hypot(x1 - x0, y1 - y0)
            a, b = max(lo, walked), min(hi, walked + seg)
            if a < b:
                f0, f1 = (a - walked) / seg, (b - walked) / seg
                p0 = (x0 + (x1 - x0) * f0, y0 + (y1 - y0) * f0)
                p1 = (x0 + (x1 - x0) * f1, y0 + (y1 - y0) * f1)
                if out and out[-1] == p0:
                    out.append(p1)
                else:
                    if len(out) > 1:
                        self.d.line(self.p(out), fill=color, width=round(width * self.k), joint="curve")
                    out = [p0, p1]
            walked += seg
        if len(out) > 1:
            self.d.line(self.p(out), fill=color, width=round(width * self.k), joint="curve")

    def done(self):
        return self.img.resize((self.size, self.size), Image.LANCZOS)


# ---------------------------------------------------------------- pulse

PULSE_FRAMES = 20      # frames of travel
PULSE_STEP = 30        # ms per travel frame (600 ms around the outline)
PULSE_REST = 300       # ms of stillness between two passes: it loops


def perimeter(pts, closed=True):
    path = pts + [pts[0]] if closed else pts
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(path, path[1:]))


def pulse(pen, pts, f, color=ACCENT, closed=True, length=13):
    """Frame 0 is the still cursor; frames 1..PULSE_FRAMES move the dash in and out along the outline."""
    if f == 0:
        return
    total = perimeter(pts, closed)
    t = -length + (f - 1) / (PULSE_FRAMES - 1) * (total + length)
    pen.dash(pts, t, length, color, closed, width=2.2)


def pulse_delay(f):
    return PULSE_REST if f == 0 else PULSE_STEP


# ---------------------------------------------------------------- shapes

ARROW = [(2, 2), (2, 24), (8, 18), (19, 18)]  # blade arrow: tip, down, chevron notch, out


def arrow(pen, fill=FILL):
    pen.shape(ARROW, fill)


def badge(pen, draw):
    """A small square badge at the bottom right of an arrow (copy, alias, help...)."""
    pen.rect(17, 19, 29, 31)
    draw(pen)


def blades(pen, cx, cy, scale, lit):
    """The loading indicator: three slanted blades, `lit` one in the accent."""
    w, h, gap, skew = 2.4 * scale, 9 * scale, 2.2 * scale, 4.4 * scale
    total = 3 * w + 2 * gap + skew
    x = cx - total / 2
    for i in range(3):
        x0 = x + i * (w + gap)
        pts = [(x0 + skew, cy - h / 2), (x0 + skew + w, cy - h / 2), (x0 + w, cy + h / 2), (x0, cy + h / 2)]
        pen.shape(pts, ACCENT if i == lit else FILL)


def double_arrow(pen, angle, bar=False):
    """A thin double-headed arrow through the centre, at `angle` degrees (0 = horizontal)."""
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    c, length, head, wing = 16, 11, 5, 4

    def pt(t, n=0):
        return (c + ux * t + nx * n, c + uy * t + ny * n)

    for s in (1, -1):
        tip = pt(s * length)
        pen.shape([tip, pt(s * (length - head), wing), pt(s * (length - head), -wing)])
    pen.stroke([pt(-(length - head)), pt(length - head)], width=1.2)
    if bar:
        pen.stroke([pt(0, -7), pt(0, 7)], width=1.6)


# ---------------------------------------------------------------- cursors
# name: (draw function, hotspot in grid units, frames)


def c_default(pen, f):
    arrow(pen)
    pulse(pen, ARROW, f)


def c_pointer(pen, f):
    arrow(pen, ACCENT)
    pulse(pen, ARROW, f, color=LINE)


def c_text(pen, f):
    pen.stroke([(16, 7), (16, 25)], width=1.4)
    pen.stroke([(12, 7), (20, 7)], width=1.4)
    pen.stroke([(12, 25), (20, 25)], width=1.4)
    pulse(pen, [(16, 7), (16, 25)], f, closed=False, length=7)


def c_vertical_text(pen, f):
    pen.stroke([(7, 16), (25, 16)], width=1.4)
    pen.stroke([(7, 12), (7, 20)], width=1.4)
    pen.stroke([(25, 12), (25, 20)], width=1.4)


def c_crosshair(pen, f):
    for seg in (((16, 4), (16, 13)), ((16, 19), (16, 28)), ((4, 16), (13, 16)), ((19, 16), (28, 16))):
        pen.stroke(list(seg), width=1.2)
    pen.rect(15, 15, 17, 17, fill=ACCENT, outline=ACCENT)


def c_cell(pen, f):
    pen.shape([(13, 5), (19, 5), (19, 13), (27, 13), (27, 19), (19, 19), (19, 27), (13, 27), (13, 19),
               (5, 19), (5, 13), (13, 13)])


def c_wait(pen, f):
    blades(pen, 16, 16, 1.3, f)


def c_progress(pen, f):
    arrow(pen)
    blades(pen, 24, 26, 0.7, f)


def c_not_allowed(pen, f):
    pen.rect(7, 7, 25, 25)
    pen.stroke([(10, 22), (22, 10)], color=ERROR, width=2, halo=False)


def c_help(pen, f):
    arrow(pen)
    badge(pen, lambda p: (p.stroke([(21, 23), (23, 22), (25, 23), (25, 25), (23, 26), (23, 27)], width=1.1, halo=False),
                          p.stroke([(23, 28.6), (23, 29.4)], width=1.1, halo=False)))


def c_copy(pen, f):
    arrow(pen)
    badge(pen, lambda p: (p.stroke([(23, 21.5), (23, 28.5)], width=1.3, halo=False),
                          p.stroke([(19.5, 25), (26.5, 25)], width=1.3, halo=False)))


def c_alias(pen, f):
    arrow(pen)
    badge(pen, lambda p: (p.stroke([(20.5, 28), (26, 22.5)], width=1.2, halo=False),
                          p.stroke([(22, 22.5), (26, 22.5), (26, 26.5)], width=1.2, halo=False)))


def c_context_menu(pen, f):
    arrow(pen)
    badge(pen, lambda p: [p.stroke([(20, y), (26, y)], width=1, halo=False) for y in (22.5, 25, 27.5)])


def c_move(pen, f):
    double_arrow(pen, 0)
    double_arrow(pen, 90)


def c_grab(pen, f):
    # An open bracket: something you can take hold of.
    pen.stroke([(10, 9), (10, 23), (22, 23), (22, 9)], width=1.4)
    pen.stroke([(14, 9), (14, 17)], width=1.2)
    pen.stroke([(18, 9), (18, 17)], width=1.2)


def c_grabbing(pen, f):
    pen.rect(10, 13, 22, 23)
    pen.rect(13, 16, 19, 20, fill=ACCENT, outline=ACCENT)


def c_zoom(pen, plus):
    pen.rect(6, 6, 20, 20)
    pen.stroke([(20, 20), (27, 27)], width=2.2)
    pen.stroke([(9.5, 13), (16.5, 13)], width=1.3, halo=False)
    if plus:
        pen.stroke([(13, 9.5), (13, 16.5)], width=1.3, halo=False)


CURSORS = {
    "default": (c_default, (2, 2), 1 + PULSE_FRAMES),
    "pointer": (c_pointer, (2, 2), 1 + PULSE_FRAMES),
    "text": (c_text, (16, 16), 1 + PULSE_FRAMES),
    "vertical-text": (c_vertical_text, (16, 16), 1),
    "crosshair": (c_crosshair, (16, 16), 1),
    "cell": (c_cell, (16, 16), 1),
    "wait": (c_wait, (16, 16), 3),
    "progress": (c_progress, (2, 2), 3),
    "not-allowed": (c_not_allowed, (16, 16), 1),
    "help": (c_help, (2, 2), 1),
    "copy": (c_copy, (2, 2), 1),
    "alias": (c_alias, (2, 2), 1),
    "context-menu": (c_context_menu, (2, 2), 1),
    "move": (c_move, (16, 16), 1),
    "grab": (c_grab, (16, 16), 1),
    "grabbing": (c_grabbing, (16, 16), 1),
    "zoom-in": (lambda p, f: c_zoom(p, True), (13, 13), 1),
    "zoom-out": (lambda p, f: c_zoom(p, False), (13, 13), 1),
    "ew-resize": (lambda p, f: double_arrow(p, 0), (16, 16), 1),
    "ns-resize": (lambda p, f: double_arrow(p, 90), (16, 16), 1),
    "nesw-resize": (lambda p, f: double_arrow(p, -45), (16, 16), 1),
    "nwse-resize": (lambda p, f: double_arrow(p, 45), (16, 16), 1),
    "col-resize": (lambda p, f: double_arrow(p, 0, bar=True), (16, 16), 1),
    "row-resize": (lambda p, f: double_arrow(p, 90, bar=True), (16, 16), 1),
}

# Other names toolkits ask for, as links to the cursors above.
ALIASES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "left-arrow"],
    "pointer": ["hand1", "hand2", "pointing_hand", "9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106"],
    "text": ["xterm", "ibeam"],
    "crosshair": ["cross", "tcross", "cross_reverse", "diamond_cross"],
    "cell": ["plus"],
    "wait": ["watch"],
    "progress": ["left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"],
    "not-allowed": ["crossed_circle", "forbidden", "no-drop", "dnd-no-drop", "circle", "03b6e0fcb3499374a867c041f52298f0"],
    "help": ["question_arrow", "whats_this", "left_ptr_help", "d9ce0ab605698f320427677b458ad60b", "5c6cd98b3f3ebcb1f9c7f1c204630408"],
    "copy": ["dnd-copy", "1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872"],
    "alias": ["link", "dnd-link", "3085a0e285430894940527032f8b26df", "640fb0e74195791501fd1ed57b41487f"],
    "move": ["fleur", "size_all", "all-scroll", "dnd-move", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "grab": ["openhand", "5aca4d189052212118709018842178c0"],
    "grabbing": ["closedhand", "dnd-none", "208530c400c041818281048008011002"],
    "ew-resize": ["e-resize", "w-resize", "h_double_arrow", "sb_h_double_arrow", "size_hor", "left_side", "right_side",
                  "028006030e0e7ebffc7f7070c0600140", "14fef782d02440884392942c11205230"],
    "ns-resize": ["n-resize", "s-resize", "v_double_arrow", "sb_v_double_arrow", "size_ver", "top_side", "bottom_side",
                  "00008160000006810000408080010102", "2870a09082c103050810ffdffffe0204"],
    "nesw-resize": ["ne-resize", "sw-resize", "size_bdiag", "top_right_corner", "bottom_left_corner",
                    "fcf1c3c7cd4491d801f1e1c78f100000"],
    "nwse-resize": ["nw-resize", "se-resize", "size_fdiag", "top_left_corner", "bottom_right_corner",
                    "c7088f0f3e6c8088236ef8e1e3e70000"],
    "col-resize": ["split_h"],
    "row-resize": ["split_v"],
}


# ---------------------------------------------------------------- XCursor writer

def xcursor(images):
    """images: list of (size, Image RGBA, xhot, yhot, delay_ms) -> XCursor file bytes."""
    chunks = []
    for size, img, xhot, yhot, delay in images:
        w, h = img.size
        px = bytearray()
        for r, g, b, a in (img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()):
            # premultiplied ARGB, little-endian
            px += struct.pack("<I", (a << 24) | ((r * a // 255) << 16) | ((g * a // 255) << 8) | (b * a // 255))
        header = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, w, h, xhot, yhot, delay)
        chunks.append((size, header + bytes(px)))
    ntoc = len(chunks)
    out = bytearray(struct.pack("<4sIII", b"Xcur", 16, 0x10000, ntoc))
    pos = 16 + ntoc * 12
    for size, data in chunks:
        out += struct.pack("<III", 0xFFFD0002, size, pos)
        pos += len(data)
    for _, data in chunks:
        out += data
    return bytes(out)


def render(name):
    draw, (hx, hy), frames = CURSORS[name]
    images = []
    for size in SIZES:
        for f in range(frames):
            pen = Pen(size)
            draw(pen, f)
            img = pen.done()
            delay = (pulse_delay(f) if frames == 1 + PULSE_FRAMES else 150) if frames > 1 else 0
            images.append((size, img, round(hx * size / 32), round(hy * size / 32), delay))
    return images


# ---------------------------------------------------------------- hyprcursor writer
# Hyprland draws its pointer through hyprcursor, which animates its own format: one zip (.hlc) per cursor, holding
# a meta.hl and the frames. Several define_size lines for one size make an animation (last value: delay in ms).

def hyprcursor(name, images, aliases):
    _, (hx, hy), _ = CURSORS[name]
    meta = ["resize_algorithm = bilinear", f"hotspot_x = {hx / 32:.4f}", f"hotspot_y = {hy / 32:.4f}"]
    if aliases:
        meta.append("define_override = " + ";".join(aliases))
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        counts = {}
        for size, img, _, _, delay in images:
            i = counts.get(size, 0)
            counts[size] = i + 1
            png = io.BytesIO()
            img.save(png, "PNG")
            fname = f"{name}_{size}_{i}.png"
            z.writestr(fname, png.getvalue())
            meta.append(f"define_size = {size}, {fname}" + (f", {delay}" if delay else ""))
        z.writestr("meta.hl", "\n".join(meta) + "\n")
    return buf.getvalue()


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "build", "TheLine")
    cursors = os.path.join(out, "cursors")
    os.makedirs(cursors, exist_ok=True)

    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=The Line\nComment=The Line's cursors: flat, square, one accent\n")

    hypr = os.path.join(out, "hyprcursors")
    os.makedirs(hypr, exist_ok=True)
    with open(os.path.join(out, "manifest.hl"), "w") as f:
        f.write("name = TheLine\ndescription = The Line's cursors: flat, square, one accent\nversion = 1\ncursors_directory = hyprcursors\n")

    for name in CURSORS:
        images = render(name)
        with open(os.path.join(cursors, name), "wb") as f:
            f.write(xcursor(images))
        with open(os.path.join(hypr, name + ".hlc"), "wb") as f:
            f.write(hyprcursor(name, images, ALIASES.get(name, [])))
        for alias in ALIASES.get(name, []):
            link = os.path.join(cursors, alias)
            if os.path.lexists(link):
                os.remove(link)
            os.symlink(name, link)

    # A preview sheet: every cursor at 48 px on dark and on light.
    names = list(CURSORS)
    cols, cell = 8, 72
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGBA", (cols * cell, rows * cell * 2), (0, 0, 0, 255))
    ImageDraw.Draw(sheet).rectangle([0, rows * cell, cols * cell, rows * cell * 2], fill=(236, 232, 225, 255))
    for i, name in enumerate(names):
        frames = CURSORS[name][2]
        img = render(name)[2 * frames + (6 if frames > 3 else 0)][1]  # 48 px, a frame mid-pulse for the pulsing ones
        x, y = (i % cols) * cell + 12, (i // cols) * cell + 12
        sheet.alpha_composite(img, (x, y))
        sheet.alpha_composite(img, (x, y + rows * cell))
    os.makedirs(os.path.join(here, "build"), exist_ok=True)
    sheet.save(os.path.join(here, "build", "preview.png"))
    print("built", len(names), "cursors in", out)


if __name__ == "__main__":
    main()
