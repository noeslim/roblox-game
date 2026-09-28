"""City models: building facades (details over plain part walls), street furniture, specials and the
trap house details. Origin convention: buildings / props / specials = center of the base at ground
level (y = 0), front (street side) towards +Z. The trap house uses the plot origin (basement floor
center, +Z = street), like the game code.
Dimensions come from src/shared/Config/City.luau through tools/meshgen/city_layout.json
(run `lune run tools/dump_city` first)."""
import json
import math
import os
import random

from lib import box, cyl, extrude, lathe, neon_text, tube

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "city_layout.json")) as f:
    CITY = json.load(f)["config"]
ARCH = CITY["Archetypes"]
HOUSE = CITY["Houses"]

CITY_ASSETS = []


def city_asset(fn):
    CITY_ASSETS.append((fn.__name__, fn))
    return fn


# Facade helpers ------------------------------------------------------------------------------------
# The walls are Roblox parts (textured by MapBuilder); these meshes hang just outside them: window
# openings (dark reveal + glass + surround), bands, cornices, roof clutter, signs.

OX = [0.0]  # x of the facade box center (the trap house is centered on x = +4)


def _face_point(face, u, y, W, D, out):
    """Point on a facade: u = coordinate along the face, out = distance outside the wall."""
    ox = OX[0]
    if face == "front":
        return (u + ox, y, D / 2 + out)
    if face == "back":
        return (-u + ox, y, -D / 2 - out)
    if face == "right":
        return (W / 2 + out + ox, y, -u)
    return (-W / 2 - out + ox, y, u)


def _face_size(face, along, up, depth):
    if face in ("front", "back"):
        return (along, up, depth)
    return (depth, up, along)


def _fbox(face, u, y, along, up, depth, out, W, D, mat):
    box(_face_size(face, along, up, depth), _face_point(face, u, y, W, D, out), mat, bev=0, segs=1)


def window(face, u, y, w, h, W, D, lit=False, frame="trim_light", sill=True, style="classic"):
    """A window opening: dark reveal (reads as depth), glass, surround, mullions, lintel and sill.
    style: "classic" (stone surround, 4 panes, lintel with keystone), "modern" (thin dark frame),
    "plain" (surround only)."""
    glass = "window_lit" if lit else "window_glass"
    _fbox(face, u, y, w + 0.5, h + 0.5, 0.05, 0.03, W, D, "plastic_black")  # reveal
    _fbox(face, u, y, w, h, 0.08, 0.08, W, D, glass)
    t = 0.18 if style == "modern" else 0.35
    fmat = "trim_dark" if style == "modern" else frame
    for dy in (-h / 2 - t / 2, h / 2 + t / 2):
        _fbox(face, u, y + dy, w + 2 * t, t, 0.3, 0.16, W, D, fmat)
    for du in (-w / 2 - t / 2, w / 2 + t / 2):
        _fbox(face, u + du, y, t, h, 0.3, 0.16, W, D, fmat)
    if style != "plain":
        _fbox(face, u, y, 0.12, h, 0.1, 0.14, W, D, "trim_dark")  # mullion
        _fbox(face, u, y + h * 0.1, w, 0.12, 0.1, 0.14, W, D, "trim_dark")  # transom
    if style == "classic":
        _fbox(face, u, y + h / 2 + t + 0.35, w + 1.2, 0.7, 0.45, 0.22, W, D, frame)  # lintel
        _fbox(face, u, y + h / 2 + t + 0.4, 0.8, 0.9, 0.55, 0.3, W, D, frame)  # keystone
    if sill:
        _fbox(face, u, y - h / 2 - t - 0.15, w + 1.0, 0.3, 0.8, 0.4, W, D, frame if style != "modern" else "metal_dark")


def window_grid(face, W, D, floors, floor_h, per_floor, first_floor, w, h, rng, lit_chance=0.3, frame="trim_light", margin=4, y0=0.0, style="classic", ac_chance=0.0):
    length = W if face in ("front", "back") else D
    usable = length - 2 * margin
    step = usable / per_floor
    for f in range(first_floor, floors):
        y = y0 + f * floor_h + floor_h * 0.55
        for i in range(per_floor):
            u = -length / 2 + margin + step * (i + 0.5)
            window(face, u, y, w, h, W, D, lit=rng.random() < lit_chance, frame=frame, style=style)
            if ac_chance and rng.random() < ac_chance:
                # window air conditioner hanging under the sill
                _fbox(face, u, y - h / 2 - 1.2, 2.4, 1.4, 1.6, 0.9, W, D, "plastic_grey")
                _fbox(face, u, y - h / 2 - 1.2, 2.0, 1.0, 0.05, 1.72, W, D, "metal_dark")


def band(W, D, y, mat="trim_light", h=0.5, depth=0.35):
    """Horizontal band all around (string course between floors, plinth top...)."""
    for face in ("front", "back"):
        _fbox(face, 0, y, W + 2 * depth, h, depth, depth / 2, W, D, mat)
    for face in ("left", "right"):
        _fbox(face, 0, y, D, h, depth, depth / 2, W, D, mat)


def plinth(W, D, h=1.6, mat="concrete", depth=0.3):
    for face in ("front", "back"):
        _fbox(face, 0, h / 2, W + 2 * depth, h, depth, depth / 2, W, D, mat)
    for face in ("left", "right"):
        _fbox(face, 0, h / 2, D, h, depth, depth / 2, W, D, mat)


def quoins(W, D, H, mat="trim_light", block=1.3, y0=1.6):
    """Stone blocks on the four corners, long and short in turn."""
    y, i = y0, 0
    while y + block <= H - 1:
        long = 2.2 if i % 2 == 0 else 1.4
        for sx in (-1, 1):
            for sz in (-1, 1):
                box((long, block - 0.12, 0.3), (sx * (W / 2 - long / 2 + 0.15) + OX[0], y + block / 2, sz * (D / 2 + 0.15)), mat, bev=0, segs=1)
                box((0.3, block - 0.12, long), (sx * (W / 2 + 0.15) + OX[0], y + block / 2, sz * (D / 2 - long / 2 + 0.15)), mat, bev=0, segs=1)
        y += block
        i += 1


def cornice(W, D, y, mat="trim_light", depth=0.8, height=0.8, dentils=False):
    """Stepped crown moulding around the top (+ small dentil blocks under it)."""
    for k, (d, h, dy) in enumerate(((depth * 0.45, height * 0.45, -height * 0.5), (depth, height * 0.6, 0.0), (depth * 1.25, height * 0.3, height * 0.45))):
        for face in ("front", "back"):
            _fbox(face, 0, y + dy, W + 2 * d, h, d, d / 2, W, D, mat)
        for face in ("left", "right"):
            _fbox(face, 0, y + dy, D, h, d, d / 2, W, D, mat)
    if dentils:
        for face in ("front", "back"):
            n = int(W // 1.2)
            for i in range(n):
                _fbox(face, -W / 2 + 0.6 + i * (W - 1.2) / max(1, n - 1), y - height * 0.95, 0.5, 0.45, 0.5, 0.25, W, D, mat)


def parapet(W, D, H, mat="trim_light", h=1.4, t=0.8):
    box((W, h, t), (0 + OX[0], H + h / 2, D / 2 - t / 2), mat, bev=0, segs=1)
    box((W, h, t), (0 + OX[0], H + h / 2, -D / 2 + t / 2), mat, bev=0, segs=1)
    box((t, h, D - 2 * t), (W / 2 - t / 2 + OX[0], H + h / 2, 0), mat, bev=0, segs=1)
    box((t, h, D - 2 * t), (-W / 2 + t / 2 + OX[0], H + h / 2, 0), mat, bev=0, segs=1)
    # coping on top
    box((W + 0.3, 0.25, t + 0.3), (0 + OX[0], H + h + 0.12, D / 2 - t / 2), "concrete", bev=0, segs=1)
    box((W + 0.3, 0.25, t + 0.3), (0 + OX[0], H + h + 0.12, -D / 2 + t / 2), "concrete", bev=0, segs=1)


def drainpipe(x, z, top, bottom=0.3):
    tube([(x, top, z), (x, bottom + 0.8, z), (x, bottom + 0.3, z + 0.5)], 0.22, "metal_dark", verts=8)
    box((0.9, 0.6, 0.9), (x, top + 0.3, z), "metal_dark", bev=0.05, segs=1)
    y = bottom + 2.5
    while y < top - 1:
        box((0.6, 0.12, 0.3), (x, y, z), "metal_black", bev=0, segs=1)
        y += 3.5


def ac_unit(x, y, z):
    box((3, 2, 2.4), (x, y + 1, z), "plastic_grey", bev=0.1, segs=1)
    cyl(0.8, 0.1, (x, y + 2.02, z), "metal_black", bev=0, verts=12)
    for i in range(4):
        box((2.6, 0.08, 0.05), (x, y + 0.4 + i * 0.35, z + 1.22), "metal_dark", bev=0, segs=1)


def water_tank(x, y, z, r=3, h=6):
    for dx in (-r * 0.6, r * 0.6):
        for dz in (-r * 0.6, r * 0.6):
            box((0.35, 4, 0.35), (x + dx, y + 2, z + dz), "metal_black", bev=0, segs=1)
    box((r * 1.8, 0.3, r * 1.8), (x, y + 4, z), "wood_worn", bev=0, segs=1)
    cyl(r, h, (x, y + 4 + h / 2, z), "wood_worn", bev=0.1, verts=18)
    for k in (0.25, 0.75):
        cyl(r + 0.08, 0.2, (x, y + 4 + h * k, z), "metal_dark", bev=0, verts=18)
    lathe([(r + 0.2, 0), (0.1, 2)], (x, y + 4 + h, z), "metal_dark", verts=18)


def roof_clutter(W, D, H, rng, count=5, tank=False, dish=True):
    """Bulkhead (stair exit), vents, pipes, a satellite dish, an antenna, maybe a water tank."""
    bx, bz = -W / 4, -D / 4
    box((6, 7, 5), (bx + OX[0], H + 3.5, bz), "concrete", bev=0.05, segs=1)
    box((6.4, 0.4, 5.4), (bx + OX[0], H + 7.2, bz), "concrete", bev=0, segs=1)
    box((0.1, 6, 3), (bx + OX[0] + 3.02, H + 3, bz), "metal_dark", bev=0, segs=1)
    for i in range(count):
        x = rng.uniform(-W / 2 + 3, W / 2 - 3)
        z = rng.uniform(-D / 2 + 3, D / 2 - 3)
        if abs(x - bx) < 5 and abs(z - bz) < 5:
            continue
        kind = rng.random()
        if kind < 0.4:
            cyl(0.5, 2.2, (x + OX[0], H + 1.1, z), "metal_steel", bev=0.05, verts=10)
            lathe([(0.9, 0), (0.1, 0.5)], (x + OX[0], H + 2.2, z), "metal_dark", verts=10)
        elif kind < 0.75:
            ac_unit(x + OX[0], H, z)
        else:
            box((2, 1.2, 2), (x + OX[0], H + 0.6, z), "metal_dark", bev=0.05, segs=1)
            tube([(x + OX[0], H + 1.2, z), (x + OX[0], H + 1.8, z), (x + OX[0] + 3, H + 1.8, z)], 0.18, "metal_steel", verts=8)
    if dish:
        dx, dz = W / 2 - 3, -D / 2 + 3
        box((0.3, 2.2, 0.3), (dx + OX[0], H + 1.1, dz), "metal_steel", bev=0, segs=1)
        lathe([(0.05, 0), (0.9, 0.35), (1.3, 0.6)], (dx + OX[0], H + 2.3, dz), "plastic_grey", verts=16, rot=(55, 30, 0))
    tube([(W / 2 - 2 + OX[0], H, D / 2 - 2), (W / 2 - 2 + OX[0], H + 9, D / 2 - 2)], 0.08, "metal_steel", verts=6)
    for k in (5, 7.5):
        box((1.6, 0.06, 0.06), (W / 2 - 2 + OX[0], H + k, D / 2 - 2), "metal_steel", bev=0, segs=1)
    if tank:
        water_tank(W / 4 + OX[0], H, D / 4)


def blade_sign(u, y, text, W, D, mat="neon_pink", board="metal_black", length=None, size=1.5):
    """Projecting sign on the front face: bracket, board perpendicular to the street, neon letters on
    both sides (seen by people walking along the sidewalk)."""
    L = length or max(4.0, len(text) * size * 0.7 + 1.2)
    z = D / 2 + L / 2 + 0.6
    x = u + OX[0]
    box((0.2, 0.2, L + 0.8), (x, y + 1.6, D / 2 + (L + 0.8) / 2), "metal_black", bev=0, segs=1)
    box((0.4, size * 1.6, L), (x, y, z), board, bev=0.05, segs=1)
    for side in (-1, 1):
        neon_text(text, size, (x + side * 0.26, y - size * 0.1, z), mat, tube_radius=0.07, rot=(0, 90 * side, 0))


def door(face, u, W, D, w=4, h=7.5, mat="wood_dark", y0=0.0):
    leaf = DOOR_LEAF.get(mat, mat)  # own mesh: replaced in game by a door that opens
    box(_face_size(face, w, h, 0.2), _face_point(face, u, y0 + h / 2, W, D, 0.08), leaf, bev=0.02, segs=1)
    box(_face_size(face, w + 1.4, 0.7, 0.6), _face_point(face, u, y0 + h + 0.35, W, D, 0.25), "trim_light", bev=0, segs=1)
    for du in (-w / 2 - 0.35, w / 2 + 0.35):
        box(_face_size(face, 0.7, h, 0.6), _face_point(face, u + du, y0 + h / 2, W, D, 0.25), "trim_light", bev=0, segs=1)
    box(_face_size(face, 0.15, 0.15, 0.3), _face_point(face, u + w / 2 - 0.5, y0 + h * 0.5, W, D, 0.3), "chrome", bev=0, segs=1)
    box(_face_size(face, w + 2.4, 0.3, 1.6), _face_point(face, u, y0 + 0.15, W, D, 0.8), "concrete", bev=0.03, segs=1)  # step


DOOR_LEAF = {"wood_dark": "door_wood", "window_glass": "door_glass", "metal_dark": "door_metal"}


def awning(face, u, y, w, W, D, depth=3.5):
    fx, fy, fz = _face_point(face, u, y, W, D, depth / 2)
    rot = {"front": (-20, 0, 0), "back": (20, 0, 0), "right": (0, 0, 20), "left": (0, 0, -20)}[face]
    box(_face_size(face, w, 0.2, depth), (fx, fy, fz), "awning", bev=0, segs=1, rot=rot)
    # valance hanging at the front edge
    ex, ey, ez = _face_point(face, u, y - math.sin(math.radians(20)) * depth / 2 - 0.4, W, D, depth * 0.95)
    box(_face_size(face, w, 0.8, 0.08), (ex, ey, ez), "awning", bev=0, segs=1)
    for du in (-w / 2, w / 2):
        tube([_face_point(face, u + du, y + 0.4, W, D, 0.1), _face_point(face, u + du, y - 1.0, W, D, depth * 0.95)], 0.05, "metal_dark", verts=6)


def storefront(u, w, W, D, h=7.5, shutter=0.0, bars=False):
    """Shop window: kickplate, glass, mullions, fascia. shutter = fraction rolled down; bars = grille."""
    _fbox("front", u, 0.6, w + 1, 1.2, 0.5, 0.25, W, D, "trim_dark")
    _fbox("front", u, 1.2 + (h - 1.2) / 2, w, h - 1.2, 0.12, 0.06, W, D, "window_glass")
    n = max(1, int(w // 5))
    for i in range(n + 1):
        _fbox("front", u - w / 2 + i * w / n, 1.2 + (h - 1.2) / 2, 0.35, h - 1.2, 0.35, 0.2, W, D, "trim_dark")
    _fbox("front", u, h + 0.5, w + 1, 1.0, 0.5, 0.25, W, D, "trim_dark")
    if shutter > 0:
        sh = (h - 1.2) * shutter
        _fbox("front", u, h - sh / 2, w, sh, 0.12, 0.35, W, D, "metal_dark")
        k = int(sh / 0.35)
        for i in range(k):
            _fbox("front", u, h - 0.2 - i * 0.35, w, 0.06, 0.05, 0.45, W, D, "metal_black")
        _fbox("front", u, h - sh, w, 0.2, 0.2, 0.45, W, D, "metal_steel")
    if bars:
        for i in range(int(w // 0.7) + 1):
            _fbox("front", u - w / 2 + i * 0.7, 1.2 + (h - 1.2) / 2, 0.1, h - 1.2, 0.1, 0.45, W, D, "metal_black")
        for yy in (2.2, h - 0.8):
            _fbox("front", u, yy, w, 0.12, 0.12, 0.45, W, D, "metal_black")


# Buildings --------------------------------------------------------------------------------------------

def brick_block(W, D, H, floors, fh, rng, frame="trim_light", dentils=True):
    """What every old brick building shares: plinth, bands, corner stones, crown, drainpipes."""
    plinth(W, D)
    for f in range(1, floors):
        band(W, D, f * fh - 0.2, frame, h=0.45, depth=0.3)
    quoins(W, D, H, frame)
    cornice(W, D, H - 0.5, frame, dentils=dentils)
    drainpipe(W / 2 - 0.8 + OX[0], D / 2 + 0.5, H - 0.6)
    drainpipe(-W / 2 + 0.8 + OX[0], -D / 2 - 0.5, H - 0.6)


def fire_escape(x0, x1, floors, fh, D):
    """Landings with railings and slanted ladders on the front face."""
    z = D / 2
    for f in range(1, floors):
        y = f * fh + 0.3
        box((x1 - x0, 0.25, 3), ((x0 + x1) / 2 + OX[0], y, z + 1.6), "metal_black", bev=0, segs=1)
        for i in range(int((x1 - x0) // 0.8) + 1):
            box((0.06, 0.06, 2.9), (x0 + i * 0.8 + OX[0], y + 0.14, z + 1.6), "metal_black", bev=0, segs=1)
        tube([(x0 + OX[0], y, z + 3.05), (x0 + OX[0], y + 3, z + 3.05), (x1 + OX[0], y + 3, z + 3.05), (x1 + OX[0], y, z + 3.05)], 0.07, "metal_black", verts=6)
        tube([(x0 + OX[0], y + 1.5, z + 3.05), (x1 + OX[0], y + 1.5, z + 3.05)], 0.05, "metal_black", verts=6)
        for i in range(int((x1 - x0) // 1.2) + 1):
            box((0.05, 3, 0.05), (x0 + i * 1.2 + OX[0], y + 1.5, z + 3.05), "metal_black", bev=0, segs=1)
        for sx in (x0, x1):
            box((0.12, 0.12, 3), (sx + OX[0], y - 0.3, z + 1.6), "metal_black", bev=0, segs=1)  # brackets
        if f < floors - 1:
            a = (x1 - 1.2, y + 0.2)
            b = (x0 + 1.5, y + fh)
            for side in (0.2, 1.1):
                tube([(a[0] + OX[0], a[1], z + side + 0.5), (b[0] + OX[0], b[1], z + side + 0.5)], 0.06, "metal_black", verts=6)
            steps = 10
            for i in range(1, steps):
                t = i / steps
                box((0.9, 0.06, 0.25), (a[0] + (b[0] - a[0]) * t + OX[0], a[1] + (b[1] - a[1]) * t, z + 1.1), "metal_black", bev=0, segs=1)


@city_asset
def bld_apartment():
    a = ARCH["apartment"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(11)
    floors, fh = 4, H / 4
    window_grid("front", W, D, floors, fh, 5, 1, 3.2, 5.5, rng, ac_chance=0.2)
    window_grid("back", W, D, floors, fh, 5, 0, 3.2, 5.5, rng, ac_chance=0.15)
    for face in ("left", "right"):
        window_grid(face, W, D, floors, fh, 3, 0, 3.0, 5.5, rng)
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"])
    box((9, 0.4, 4), (0, 9.2, D / 2 + 2), "trim_dark", bev=0, segs=1)
    for dx in (-4.2, 4.2):
        tube([(dx, 9.2, D / 2 + 3.8), (dx, 10.5, D / 2 + 0.3)], 0.06, "metal_black", verts=6)
    lathe([(0.1, 0.4), (0.35, 0.1), (0.3, -0.3), (0.0, -0.4)], (0, 8.8, D / 2 + 2), "lamp_lens", verts=10)
    for u in (-13, 13):
        window("front", u, 5, 6, 5, W, D, lit=True, style="classic")
    brick_block(W, D, H, floors, fh, rng)
    fire_escape(-14, -2, floors, fh, D)
    parapet(W, D, H)
    roof_clutter(W, D, H, rng, count=5, tank=True)


@city_asset
def bld_apartment_b():
    """Variant: balconies on the front, paired windows, flat modern crown."""
    a = ARCH["apartment"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(111)
    floors, fh = 4, H / 4
    for f in range(1, floors):
        y = f * fh + fh * 0.55
        for u in (-12, 12):
            # balcony: slab, railing, glass door
            box((9, 0.4, 3.2), (u, f * fh + 0.2, D / 2 + 1.6), "concrete", bev=0.03, segs=1)
            tube([(u - 4.4, f * fh + 0.4, D / 2 + 3.1), (u - 4.4, f * fh + 3.4, D / 2 + 3.1), (u + 4.4, f * fh + 3.4, D / 2 + 3.1), (u + 4.4, f * fh + 0.4, D / 2 + 3.1)], 0.08, "metal_black", verts=6)
            for i in range(12):
                box((0.06, 3, 0.06), (u - 4.2 + i * 0.76, f * fh + 1.9, D / 2 + 3.1), "metal_black", bev=0, segs=1)
            window("front", u - 2, y - 0.6, 2.4, 7, W, D, lit=rng.random() < 0.35, style="modern", sill=False)
            window("front", u + 2, y, 2.6, 5, W, D, lit=rng.random() < 0.35, style="modern")
        window("front", 0, y, 3, 5, W, D, lit=rng.random() < 0.3, style="modern")
    window_grid("back", W, D, floors, fh, 6, 0, 2.8, 5, rng, style="modern", ac_chance=0.25)
    for face in ("left", "right"):
        window_grid(face, W, D, floors, fh, 3, 0, 2.8, 5, rng, style="modern")
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="window_glass")
    box((10, 0.5, 4.5), (0, 9.2, D / 2 + 2.25), "concrete", bev=0.03, segs=1)
    for u in (-13, 13):
        window("front", u, 5, 6, 5, W, D, lit=True, style="modern")
    plinth(W, D, h=1.2, mat="concrete")
    for f in range(1, floors):
        band(W, D, f * fh - 0.2, "concrete", h=0.6, depth=0.25)
    drainpipe(W / 2 - 0.8, D / 2 + 0.5, H - 0.6)
    parapet(W, D, H, "concrete", h=1.2)
    roof_clutter(W, D, H, rng, count=6)


def shop_upper(W, D, H, rng, frame="trim_light"):
    window_grid("front", W, D, 2, H / 2, 4, 1, 3.5, 5, rng)
    window_grid("back", W, D, 2, H / 2, 4, 1, 3.5, 5, rng)
    for face in ("left", "right"):
        window_grid(face, W, D, 2, H / 2, 2, 1, 3, 5, rng)
    band(W, D, H / 2 - 0.2, frame, h=0.5)
    quoins(W, D, H, frame, y0=H / 2)
    cornice(W, D, H - 0.4, frame, dentils=True)
    parapet(W, D, H, frame, h=1)
    drainpipe(W / 2 - 0.6, D / 2 + 0.5, H - 0.5)


@city_asset
def bld_shop():
    """Liquor store: glass front half shuttered, awning, blade sign."""
    a = ARCH["shop"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(12)
    dr = a["door"]
    storefront(-4, W - 14, W, D, shutter=0.35)
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="window_glass")
    awning("front", -4, 9.8, W - 12, W, D)
    blade_sign(W / 2 - 1.5, 13.5, "LIQUOR", W, D, "neon_blue")
    shop_upper(W, D, H, rng)
    roof_clutter(W, D, H, rng, count=3, dish=True)


@city_asset
def bld_shop_b():
    """Pawn shop: barred windows, roller shutter, red neon."""
    a = ARCH["shop"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(121)
    dr = a["door"]
    storefront(-4, W - 14, W, D, bars=True)
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="metal_dark")
    blade_sign(W / 2 - 1.5, 13.5, "PAWN", W, D, "neon_red")
    box((W - 12, 1.4, 1.2), (-4, 9.6, D / 2 + 0.6), "metal_dark", bev=0.05, segs=1)  # shutter box
    shop_upper(W, D, H, rng, frame="concrete")
    roof_clutter(W, D, H, rng, count=4, dish=False)


@city_asset
def bld_shop_c():
    """Diner: big windows, chrome band, neon."""
    a = ARCH["shop"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(122)
    dr = a["door"]
    storefront(-4, W - 14, W, D, h=7)
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="window_glass")
    for y in (7.9, 8.4):
        box((W + 0.4, 0.25, 0.3), (0, y, D / 2 + 0.3), "chrome", bev=0.05, segs=1)
    awning("front", -4, 9.8, W - 12, W, D, depth=2.5)
    blade_sign(W / 2 - 1.5, 13.5, "DINER", W, D, "neon_pink")
    shop_upper(W, D, H, rng)
    roof_clutter(W, D, H, rng, count=4)
    for i in range(3):
        cyl(0.6, 3, (-8 + i * 3, H + 1.5, -6), "metal_steel", bev=0.05, verts=10)  # kitchen exhausts


def glass_tower(W, D, H, floor_h, rng, crown=True, lobby_h=None, dr=None, spandrel="concrete", fins=4):
    """Curtain wall: glass per floor, spandrel band between floors, vertical fins, lobby, crown."""
    lobby_h = lobby_h or floor_h
    floors = int(H // floor_h)
    for f in range(1, floors):
        if f * floor_h < lobby_h:
            continue  # the lobby is taller than a floor
        y = f * floor_h + floor_h * 0.5
        for face in ("front", "back", "left", "right"):
            length = W if face in ("front", "back") else D
            _fbox(face, 0, y + 0.3, length - 1, floor_h * 0.66, 0.2, 0.08, W, D, "window_lit" if rng.random() < 0.25 else "window_glass")
            _fbox(face, 0, f * floor_h + 0.35, length - 0.2, floor_h * 0.28, 0.3, 0.16, W, D, spandrel)
    for face in ("front", "back", "left", "right"):
        length = W if face in ("front", "back") else D
        n = int(length // fins)
        for i in range(n + 1):
            u = -length / 2 + 0.5 + i * (length - 1) / n
            _fbox(face, u, lobby_h + (H - lobby_h) / 2, 0.35, H - lobby_h, 0.6, 0.3, W, D, "trim_dark")
    # lobby: tall glass, stone base, canopy
    _fbox("front", 0, lobby_h / 2, W * 0.6, lobby_h - 1, 0.15, 0.06, W, D, "window_glass")
    for u in (-W * 0.3 - 1.5, W * 0.3 + 1.5):
        _fbox("front", u, lobby_h / 2, 3, lobby_h, 0.6, 0.3, W, D, "trim_light")
    box((W * 0.7, 0.6, 5), (0, lobby_h, D / 2 + 2.5), "trim_dark", bev=0, segs=1)
    box((W * 0.7, 0.1, 4.6), (0, lobby_h - 0.35, D / 2 + 2.5), "lamp_lens", bev=0, segs=1)
    dr = dr or {"x": 0, "w": 6, "h": lobby_h - 1.5}
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="window_glass")
    plinth(W, D, h=1.0, mat="trim_light")
    parapet(W, D, H, "trim_dark", h=1.2)
    if crown:
        box((W * 0.6, 6, D * 0.6), (0, H + 3, 0), "concrete", bev=0.1, segs=1)
        for face in ("front", "back"):
            box((W * 0.6 - 2, 3, 0.2), (0, H + 3, (D * 0.3 + 0.1) * (1 if face == "front" else -1)), "metal_dark", bev=0, segs=1)
        cyl(0.4, 22, (0, H + 17, 0), "metal_steel", bev=0.05, verts=8)
        lathe([(0.8, 0), (0.8, 0.8), (0, 1.2)], (0, H + 28, 0), "neon_red", verts=12)
    roof_clutter(W, D, H, rng, count=4, dish=True)


@city_asset
def bld_office():
    a = ARCH["office"]
    glass_tower(a["w"], a["d"], a["h"], 5, random.Random(13), crown=False, lobby_h=a["interior"]["height"], dr=a["door"])


@city_asset
def bld_office_b():
    """Variant: stone-clad, narrower fins, dark spandrels."""
    a = ARCH["office"]
    glass_tower(a["w"], a["d"], a["h"], 5, random.Random(131), crown=False, lobby_h=a["interior"]["height"], dr=a["door"], spandrel="trim_light", fins=2.6)


@city_asset
def bld_tower():
    a = ARCH["tower"]
    glass_tower(a["w"], a["d"], a["h"], 5, random.Random(14), crown=True, lobby_h=a["interior"]["height"], dr=a["door"])


@city_asset
def bld_tower_b():
    a = ARCH["tower"]
    glass_tower(a["w"], a["d"], a["h"], 5, random.Random(141), crown=True, lobby_h=a["interior"]["height"], dr=a["door"], spandrel="metal_dark", fins=3)


@city_asset
def bld_warehouse():
    a = ARCH["warehouse"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(18)
    for u in (-14, 14):
        # roller doors with their frame, dock and bumpers
        box((14, 14, 0.3), (u, 7, D / 2 + 0.1), "metal_steel", bev=0, segs=1)
        for i in range(14):
            box((14, 0.12, 0.35), (u, 0.5 + i, D / 2 + 0.3), "metal_dark", bev=0, segs=1)
        box((16, 0.8, 0.8), (u, 14.4, D / 2 + 0.4), "trim_dark", bev=0, segs=1)
        for du in (-7.6, 7.6):
            box((0.8, 14, 0.8), (u + du, 7, D / 2 + 0.4), "trim_dark", bev=0, segs=1)
        box((1, 0.6, 1), (u, 16, D / 2 + 0.6), "lamp_lens", bev=0, segs=1)
        for du in (-5, 5):
            box((1.4, 2, 0.8), (u + du, 1.5, D / 2 + 0.5), "rubber", bev=0.1, segs=1)
    # ribbed cladding: vertical ribs on the sides and back
    for face in ("left", "right", "back"):
        length = W if face == "back" else D
        n = int(length // 3)
        for i in range(n + 1):
            _fbox(face, -length / 2 + 0.5 + i * (length - 1) / n, H / 2, 0.3, H - 1, 0.3, 0.15, W, D, "metal_dark")
        _fbox(face, 0, H - 4, length - 6, 2, 0.15, 0.3, W, D, "window_glass")
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="metal_dark")
    _fbox("front", 0, H - 5, 10, 3, 0.2, 0.2, W, D, "paint_red")  # company panel
    for i in range(4):
        cyl(1.2, 2.5, (-20 + i * 13, H + 1.25, 0), "metal_steel", bev=0.1, verts=12)
        lathe([(1.6, 0), (0.1, 0.8)], (-20 + i * 13, H + 2.5, 0), "metal_dark", verts=12)
    for i in range(3):
        box((8, 1.2, 4), (-16 + i * 16, H + 0.6, -10), "window_glass", bev=0.05, segs=1)  # skylights
        box((8.4, 0.3, 4.4), (-16 + i * 16, H + 0.15, -10), "metal_dark", bev=0, segs=1)
    box((W, 0.8, 0.8), (0, H - 0.4, D / 2 + 0.4), "trim_dark", bev=0, segs=1)
    drainpipe(W / 2 - 1, D / 2 + 0.5, H - 0.5)
    drainpipe(-W / 2 + 1, D / 2 + 0.5, H - 0.5)
    tube([(-W / 2 + 2, 3, -D / 2 - 1), (W / 2 - 2, 3, -D / 2 - 1)], 0.35, "metal_rust", verts=10)  # pipe run
    del rng


def chinatown_block(W, D, H, rng, sign, sign_mat):
    fh = H / 3
    storefront(-1, W - 8, W, D, h=7)
    dr = ARCH["chinatown"]["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="wood_dark")
    awning("front", -1, 9.5, W - 4, W, D, depth=3)
    for f in (1, 2):
        y = f * fh
        box((W - 2, 0.4, 3), (0, y, D / 2 + 1.5), "concrete", bev=0, segs=1)
        tube([(-W / 2 + 1, y + 3, D / 2 + 3), (W / 2 - 1, y + 3, D / 2 + 3)], 0.1, "paint_red", verts=6)
        for i in range(8):
            u = -W / 2 + 1.5 + i * (W - 3) / 7
            box((0.15, 3, 0.15), (u, y + 1.5, D / 2 + 3), "paint_red", bev=0, segs=1)
    window_grid("front", W, D, 3, fh, 3, 1, 3, 4.5, rng, lit_chance=0.5, frame="paint_red", style="plain")
    window_grid("back", W, D, 3, fh, 3, 1, 3, 4.5, rng, lit_chance=0.4, style="plain", ac_chance=0.3)
    for face in ("left", "right"):
        window_grid(face, W, D, 3, fh, 2, 1, 2.6, 4.5, rng, style="plain")
    # tiled roof with upturned eaves + lanterns
    box((W + 3, 1.2, D + 3), (0, H + 0.2, 0), "roof_green", bev=0.2, segs=1)
    box((W + 1, 1.6, D + 1), (0, H + 1.2, 0), "roof_green", bev=0.3, segs=1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            tube([(sx * (W / 2 + 1.4), H + 0.7, sz * (D / 2 + 1.4)), (sx * (W / 2 + 2.2), H + 1.6, sz * (D / 2 + 2.2))], 0.25, "roof_green", verts=6)
    box((W + 3.4, 0.3, 0.3), (0, H - 0.5, D / 2 + 1.6), "paint_red", bev=0, segs=1)
    for u in (-W / 2 + 4, 0, W / 2 - 4):
        tube([(u, 11, D / 2 + 3.3), (u, 10, D / 2 + 3.3)], 0.04, "metal_black", verts=6)
        lathe([(0.2, -0.9), (0.7, -0.6), (0.8, 0), (0.7, 0.6), (0.2, 0.9)], (u, 9.1, D / 2 + 3.3), "neon_red", verts=12)
    blade_sign(W / 2 - 1.2, 15, sign, W, D, sign_mat, board="paint_red", size=1.3)
    drainpipe(W / 2 - 0.6, D / 2 + 0.5, H - 0.5)


@city_asset
def bld_chinatown():
    a = ARCH["chinatown"]
    chinatown_block(a["w"], a["d"], a["h"], random.Random(15), "TEA", "neon_green")


@city_asset
def bld_chinatown_b():
    a = ARCH["chinatown"]
    chinatown_block(a["w"], a["d"], a["h"], random.Random(151), "NOODLES", "neon_orange")


@city_asset
def bld_mansion():
    a = ARCH["mansion"]
    W, D, H = a["w"], a["d"], a["h"]
    # big glass panels
    for u in (-18, -6, 6, 18):
        box((10, 8, 0.15), (u, 5, D / 2 + 0.06), "window_lit" if u in (-6, 18) else "window_glass", bev=0, segs=1)
        box((10, 7, 0.15), (u, 16, D / 2 + 0.06), "window_glass", bev=0, segs=1)
        box((0.4, 20, 0.4), (u - 5.2, 10, D / 2 + 0.2), "trim_dark", bev=0, segs=1)
    box((W + 6, 0.8, D + 6), (0, H + 0.4, 0), "plaster_white", bev=0.1, segs=1)
    box((W + 4, 0.6, 6), (0, 11, D / 2 + 3), "plaster_white", bev=0.05, segs=1)
    tube([(-W / 2, 12.2, D / 2 + 5.8), (W / 2, 12.2, D / 2 + 5.8)], 0.06, "chrome", verts=6)
    box((W, 1.2, 0.1), (0, 11.9, D / 2 + 5.9), "glass", bev=0, segs=1)
    for u in (-12, 12):
        box((1.2, 10.5, 1.2), (u, 5.25, D / 2 + 5), "plaster_white", bev=0.1, segs=1)
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="wood_dark")
    for face in ("left", "right", "back"):
        window_grid(face, W, D, 2, H / 2, 3, 0, 6, 6, random.Random(16), lit_chance=0.3, frame="trim_dark", style="modern")
    plinth(W, D, h=0.8, mat="trim_light")
    for x in (-W / 2 - 3, W / 2 + 3):
        lathe([(1.2, 0), (1.0, 1.2), (1.3, 1.4), (0, 1.5)], (x, 0, D / 2 + 4), "concrete", verts=16)  # planters
        lathe([(0.2, 1.4), (1.1, 2.5), (0.9, 3.4), (0, 3.6)], (x, 0, D / 2 + 4), "leaf", verts=10)


@city_asset
def bld_ruin():
    a = ARCH["ruin"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(17)
    # broken top edge and holes
    for i in range(10):
        x = -W / 2 + 2 + i * (W - 4) / 9
        h = rng.uniform(1, 6)
        box((rng.uniform(3, 5), h, 1), (x, H + h / 2, D / 2 - 0.5), "concrete", bev=0.2, segs=1)
    for face in ("front", "back", "left", "right"):
        length = W if face in ("front", "back") else D
        for i in range(3):
            u = -length / 2 + (i + 0.5) * length / 3
            _fbox(face, u, 10, 4, 5, 0.2, 0.06, W, D, "metal_black")
            _fbox(face, u, 12.9, 5, 0.6, 0.4, 0.2, W, D, "concrete")
            for k in range(4):  # boards nailed over the holes
                _fbox(face, u + rng.uniform(-0.3, 0.3), 8.4 + k * 1.1, 4.6, 0.5, 0.12, 0.2, W, D, "wood_worn")
    for i in range(12):
        x, z = rng.uniform(-W / 2 - 4, W / 2 + 4), rng.uniform(D / 2 + 1, D / 2 + 6)
        if abs(x - a["door"]["x"]) < a["door"]["w"] / 2 + 3:
            x += a["door"]["w"] + 6  # keep the doorway clear
        box((rng.uniform(1, 3), rng.uniform(0.6, 1.6), rng.uniform(1, 3)), (x, 0.5, z), "concrete", bev=0.2, segs=1, rot=(rng.uniform(-20, 20), rng.uniform(0, 90), rng.uniform(-20, 20)))
    for i in range(6):
        x = rng.uniform(-W / 2 + 2, W / 2 - 2)
        tube([(x, H, D / 2 - 0.5), (x + rng.uniform(-1, 1), H + rng.uniform(3, 6), D / 2 - 0.5 + rng.uniform(-1, 1))], 0.08, "metal_rust", verts=6)


# Street furniture -------------------------------------------------------------------------------------

@city_asset
def prop_lamp():
    lathe([(0.6, 0), (0.45, 0.4), (0.25, 1.2), (0.2, 15), (0.0, 15.2)], (0, 0, 0), "metal_dark", verts=16)
    tube([(0, 14.6, 0), (0, 15.4, 1.5), (0, 15.4, 4.5)], 0.14, "metal_dark", verts=8)
    box((1.4, 0.5, 2.4), (0, 15.2, 5), "metal_dark", bev=0.12, segs=2)
    box((1.1, 0.12, 2.0), (0, 14.95, 5), "lamp_lens", bev=0, segs=1)


@city_asset
def prop_tree():
    rng = random.Random(21)
    lathe([(0.9, 0), (0.6, 1), (0.45, 6), (0.3, 11), (0.0, 11.5)], (0, 0, 0), "bark", verts=12)
    for i in range(3):
        a = i * 2.1
        tube([(0, 7 + i, 0), (math.cos(a) * 2.5, 9 + i, math.sin(a) * 2.5)], 0.18, "bark", verts=6)
    import bpy  # icospheres for the canopy
    from lib import PIECES, STATE, rb

    for i in range(7):
        a = i / 7 * math.pi * 2
        r = 1.5 if i else 0
        pos = (math.cos(a) * 2.2 * r / 1.5, 10.5 + rng.uniform(-0.8, 1.2), math.sin(a) * 2.2 * r / 1.5)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=rng.uniform(2.6, 3.4), location=rb(pos))
        ob = bpy.context.view_layer.objects.active
        for v in ob.data.vertices:
            v.co *= rng.uniform(0.85, 1.12)
        ob["bm_asset"] = STATE["asset"]
        ob["bm_mat"] = "leaf"
        PIECES.append(ob)


@city_asset
def prop_bench():
    for i in range(3):
        box((5, 0.2, 0.45), (0, 1.6, -0.5 + i * 0.5), "wood_mid", bev=0.04, segs=1)
    for i in range(2):
        box((5, 0.45, 0.18), (0, 2.3 + i * 0.6, -0.9), "wood_mid", bev=0.04, segs=1, rot=(-10, 0, 0))
    for x in (-2.2, 2.2):
        extrude([(-0.8, 0), (0.5, 0), (0.5, 0.2), (-0.1, 1.5), (-0.6, 3.4), (-0.8, 3.4)], 0.15, (x, 0, 0), "metal_black", bev=0.02, rot=(0, 90, 0))


@city_asset
def prop_trashcan():
    lathe([(0.9, 0), (1.0, 0.1), (1.05, 3.2), (1.1, 3.3), (0.0, 3.35)], (0, 0, 0), "paint_green", verts=20)
    lathe([(1.12, 3.3), (1.12, 3.5), (0.6, 3.9), (0.0, 3.95)], (0, 0, 0), "metal_dark", verts=20)


@city_asset
def prop_hydrant():
    lathe([(0.5, 0), (0.5, 0.2), (0.38, 0.3), (0.38, 1.8), (0.45, 1.9), (0.3, 2.3), (0.0, 2.5)], (0, 0, 0), "paint_red", verts=16)
    for axis, d in (("x", (0.45, 1.3, 0)), ("x", (-0.45, 1.3, 0)), ("z", (0, 1.3, 0.45))):
        cyl(0.16, 0.3, d, "metal_brass", axis=axis, bev=0.03, verts=10)


@city_asset
def prop_mailbox():
    box((0.3, 3.2, 0.3), (0, 1.6, 0), "wood_worn", bev=0.03, segs=1)
    box((0.9, 0.9, 1.6), (0, 3.6, 0), "metal_dark", bev=0.3, segs=3)
    box((0.1, 0.8, 0.12), (0.5, 3.8, -0.4), "paint_red", bev=0, segs=1)


@city_asset
def prop_car():
    # sedan, length along Z (front = +Z), width 6.4, length 14
    side = [(-7, 0.9), (7, 0.9), (7.1, 2.4), (6.2, 3.0), (3.2, 3.2), (1.8, 5.0), (-2.8, 5.1), (-4.8, 3.4), (-7.1, 3.1), (-7.2, 2.0)]
    extrude(side, 6.2, (0, 0, 0), "car_paint", bev=0.25, segs=3, rot=(0, -90, 0))
    cabin = [(1.6, 3.25), (-4.6, 3.3), (-2.7, 4.95), (1.5, 4.9), (1.75, 4.6)]
    extrude([(x + 0.0, y) for x, y in cabin], 6.3, (0, 0, 0), "window_glass", bev=0.05, segs=1, rot=(0, -90, 0))
    for zx in ((-3.05, 4.6), (3.05, 4.6), (-3.05, -4.6), (3.05, -4.6)):
        cyl(1.25, 0.9, (zx[0], 1.25, zx[1]), "rubber", axis="x", bev=0.25, verts=20)
        cyl(0.7, 0.95, (zx[0], 1.25, zx[1]), "chrome", axis="x", bev=0.08, verts=12)
    for x in (-2.2, 2.2):
        box((1.2, 0.5, 0.2), (x, 2.4, 7.05), "headlight", bev=0.05, segs=1)
        box((1.2, 0.5, 0.2), (x, 2.5, -7.15), "neon_red", bev=0.05, segs=1)
    box((6.4, 0.6, 0.5), (0, 1.3, 7.1), "plastic_black", bev=0.15, segs=1)
    box((6.4, 0.6, 0.5), (0, 1.3, -7.2), "plastic_black", bev=0.15, segs=1)
    box((1.6, 0.4, 0.1), (0, 1.3, -7.5), "paper", bev=0, segs=1)


@city_asset
def prop_barrier():
    extrude([(-1.2, 0), (1.2, 0), (1.2, 0.5), (0.4, 1.3), (0.35, 2.8), (-0.35, 2.8), (-0.4, 1.3), (-1.2, 0.5)], 7.8, (0, 0, 0), "concrete", bev=0.06, segs=1, rot=(0, 90, 0))
    box((7.8, 0.3, 0.05), (0, 2.2, 0.39), "neon_orange", bev=0, segs=1)


@city_asset
def prop_container():
    L, Wd, Hh = 20, 8, 8.5
    box((L, Hh, Wd), (0, Hh / 2, 0), "container_paint", bev=0.1, segs=1)
    for i in range(24):
        x = -L / 2 + 0.6 + i * (L - 1.2) / 23
        for z in (Wd / 2 + 0.1, -Wd / 2 - 0.1):
            box((0.35, Hh - 1, 0.2), (x, Hh / 2, z), "container_paint", bev=0, segs=1)
    box((0.2, Hh - 0.6, Wd - 0.6), (L / 2 + 0.1, Hh / 2, 0), "container_paint", bev=0, segs=1)
    for z in (-1.5, 1.5):
        tube([(L / 2 + 0.3, 0.8, z), (L / 2 + 0.3, Hh - 0.8, z)], 0.08, "metal_steel", verts=6)
    for x in (-L / 2 + 0.3, L / 2 - 0.3):
        for z in (-Wd / 2 + 0.3, Wd / 2 - 0.3):
            box((0.6, Hh + 0.05, 0.6), (x, Hh / 2, z), "metal_dark", bev=0, segs=1)


@city_asset
def prop_smokestack():
    lathe([(4, 0), (3.6, 4), (2.6, 60), (2.9, 61), (2.9, 62), (2.2, 62.2)], (0, 0, 0), "brick_red", verts=24)
    for y in (20, 40):
        cyl(3.1 - y / 60, 0.8, (0, y, 0), "metal_dark", bev=0.1, verts=24)


@city_asset
def prop_lantern():
    tube([(0, 1.4, 0), (0, 0.9, 0)], 0.04, "metal_black", verts=6)
    lathe([(0.2, -0.9), (0.7, -0.6), (0.8, 0), (0.7, 0.6), (0.2, 0.9)], (0, 0, 0), "neon_red", verts=12)


@city_asset
def prop_utility_pole():
    """Wooden pole, crossarm along Z (the wires run along X), insulators where the wires hang
    (City.Props.WireOffsets), transformer can and a few cable ties."""
    H = CITY["Props"]["PoleHeight"]
    lathe([(0.55, 0), (0.5, 1), (0.36, H - 0.2), (0.0, H)], (0, 0, 0), "wood_pole", verts=12)
    arm_y = H - 1.5
    box((0.45, 0.5, 7.0), (0, arm_y, 0), "wood_pole", bev=0.05, segs=1)
    for z in (-2.2, 2.2):
        tube([(0, arm_y - 0.2, z * 0.2), (0, arm_y - 2.4, z * 0.02)], 0.06, "metal_dark", verts=6)
    for z in CITY["Props"]["WireOffsets"]:
        cyl(0.14, 0.3, (0, arm_y + 0.4, z), "glass_dark", bev=0.02, verts=10)
        cyl(0.2, 0.08, (0, arm_y + 0.3, z), "glass_dark", bev=0, verts=10)
    # transformer
    cyl(0.9, 2.6, (0.95, arm_y - 4.5, 0), "plastic_grey", bev=0.15, verts=16)
    box((0.3, 0.8, 0.6), (0.55, arm_y - 4.0, 0), "metal_dark", bev=0.05, segs=1)
    tube([(0.95, arm_y - 3.1, 0), (0.6, arm_y - 1.6, 0.4), (0, arm_y + 0.5, CITY["Props"]["WireOffsets"][1])], 0.05, "rubber", verts=6)
    # staples, tag, climbing steps
    for y in (3.5, 4.8, 6.1, 7.4, 8.7):
        box((0.12, 0.12, 0.9), (0.42 if int(y * 10) % 2 else -0.42, y, 0), "metal_steel", bev=0, segs=1)
    box((0.02, 0.5, 0.35), (0.5, 7.5, 0), "paper", bev=0, segs=1)


@city_asset
def prop_traffic_light():
    """Pole on a corner, mast arm along +Z over the road, three heads facing +X."""
    lathe([(0.7, 0), (0.6, 0.5), (0.35, 1.0), (0.32, 19.5), (0.0, 19.8)], (0, 0, 0), "metal_dark", verts=16)
    tube([(0, 18.5, 0), (0, 18.7, 7), (0, 18.9, 15)], 0.2, "metal_dark", verts=10)
    tube([(0, 15.5, 0), (0, 18.3, 5)], 0.08, "metal_dark", verts=6)
    for z in (6.0, 10.5, 14.5):
        box((1.2, 4.2, 1.5), (0, 16.3, z), "metal_black", bev=0.15, segs=2)
        for i, mat in enumerate(("signal_red", "signal_amber", "signal_green")):
            y = 17.6 - i * 1.3
            cyl(0.45, 0.1, (0.62, y, z), mat, axis="x", bev=0, verts=16)
            box((0.6, 0.12, 1.1), (0.9, y + 0.55, z), "metal_black", bev=0, segs=1)  # visor
        tube([(0, 18.5, z), (0, 18.4, z)], 0.05, "metal_dark", verts=6)
    # pedestrian box and push button
    box((0.9, 1.4, 1.2), (0.6, 10.5, 0), "metal_black", bev=0.1, segs=1)
    box((0.1, 0.9, 0.8), (1.08, 10.5, 0), "signal_amber", bev=0, segs=1)
    box((0.4, 0.6, 0.35), (0.45, 3.6, 0), "paint_green", bev=0.05, segs=1)
    box((0.02, 1.4, 3.6), (-0.36, 12.8, 0), "paint_green", bev=0, segs=1)  # street name plate


@city_asset
def prop_billboard():
    """Rooftop billboard facing +Z: two steel legs, lattice, board (the ad is a SurfaceGui added
    by MapBuilder in front of the board) and three lamps on arms."""
    W, Hb, y0 = 28.0, 12.0, 8.0
    for x in (-W / 3, W / 3):
        box((0.9, y0 + Hb, 0.9), (x, (y0 + Hb) / 2, -0.8), "metal_dark", bev=0.05, segs=1)
        tube([(x, 0.2, -4), (x, y0, -0.9)], 0.18, "metal_dark", verts=8)
        box((1.6, 0.3, 1.6), (x, 0.15, -0.8), "concrete", bev=0.05, segs=1)
    for y in (2.5, 5.5):
        box((W * 0.7, 0.3, 0.3), (0, y, -0.8), "metal_dark", bev=0, segs=1)
    box((W + 0.8, Hb + 0.8, 0.5), (0, y0 + Hb / 2, 0), "metal_black", bev=0.08, segs=1)
    box((W, Hb, 0.2), (0, y0 + Hb / 2, 0.3), "billboard_face", bev=0, segs=1)
    box((W + 1, 0.2, 2.2), (0, y0 - 0.5, 0.8), "diamond_plate", bev=0, segs=1)  # catwalk
    for x in (-W / 2 + 0.2, W / 2 - 0.2):
        tube([(x, y0 - 0.4, 1.8), (x, y0 + 0.6, 1.8)], 0.05, "metal_dark", verts=6)
    for x in (-W / 3, 0, W / 3):
        tube([(x, y0 + Hb + 0.4, 0), (x, y0 + Hb + 1.2, 2.2), (x, y0 + Hb + 1.0, 3.6)], 0.09, "metal_dark", verts=6)
        box((1.4, 0.6, 1.0), (x, y0 + Hb + 0.8, 3.8), "metal_dark", bev=0.1, segs=1, rot=(-25, 0, 0))
        box((1.1, 0.1, 0.7), (x, y0 + Hb + 0.45, 3.8), "lamp_lens", bev=0, segs=1, rot=(-25, 0, 0))


def _blob(pos, radius, mat, squash=(1.0, 0.8, 1.0), seed=0, subdiv=2):
    """Lumpy sphere (trash bags, shrubs)."""
    import bpy
    from lib import PIECES, STATE, rb

    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=rb(pos))
    ob = bpy.context.view_layer.objects.active
    for v in ob.data.vertices:
        v.co.x *= squash[0] * rng.uniform(0.9, 1.1)
        v.co.y *= squash[2] * rng.uniform(0.9, 1.1)
        v.co.z *= squash[1] * rng.uniform(0.9, 1.1)
    ob["bm_asset"] = STATE["asset"]
    ob["bm_mat"] = mat
    PIECES.append(ob)
    return ob


@city_asset
def prop_trash_bags():
    rng = random.Random(31)
    spots = [(-0.8, 0, 0), (0.7, 0, 0.3), (0, 0, -0.8), (-0.2, 0.9, -0.1), (1.3, 0, -0.9)]
    for i, (x, y, z) in enumerate(spots):
        r = rng.uniform(0.75, 1.0)
        _blob((x, y + r * 0.75, z), r, "plastic_black", squash=(1.0, 0.8, 0.95), seed=i)
        tube([(x, y + r * 1.4, z), (x + 0.1, y + r * 1.75, z + 0.05)], 0.12, "plastic_black", verts=6)  # knot
    box((0.9, 0.5, 0.6), (1.6, 0.25, 0.9), "wood_crate", bev=0.03, segs=1, rot=(0, 25, 0))  # a crate
    box((0.3, 0.02, 0.4), (-1.6, 0.01, 0.8), "paper", bev=0, segs=1, rot=(0, 40, 0))


@city_asset
def prop_dumpster():
    box((7, 4, 4), (0, 2.4, 0), "paint_green", bev=0.15, segs=2)
    box((7.3, 0.35, 4.3), (0, 4.45, 0), "metal_dark", bev=0.05, segs=1)
    for x in (-1.8, 1.8):
        box((3.4, 0.15, 4.2), (x, 4.75, -0.1), "plastic_black", bev=0.05, segs=1, rot=(-6, 0, 0))
    for x in (-3.3, 3.3):
        box((0.4, 3.6, 4.4), (x, 2.4, 0), "metal_dark", bev=0.05, segs=1)
    for x in (-2.6, 2.6):
        for z in (-1.5, 1.5):
            cyl(0.35, 0.3, (x, 0.35, z), "rubber", axis="x", bev=0.05, verts=10)
    box((5, 0.12, 0.1), (0, 3.3, 2.05), "paper", bev=0, segs=1)  # stencil band


@city_asset
def prop_newspaper():
    for i, mat in enumerate(("paint_red", "metal_dark", "paint_green")):
        x = -1.6 + i * 1.6
        for dx in (-0.5, 0.5):
            box((0.12, 1.4, 0.12), (x + dx, 0.7, 0), "metal_black", bev=0, segs=1)
        box((1.4, 1.7, 1.2), (x, 2.25, 0), mat, bev=0.08, segs=1)
        box((1.1, 0.8, 0.05), (x, 2.4, 0.61), "window_glass", bev=0, segs=1)
        box((1.0, 0.6, 0.04), (x, 2.4, 0.56), "paper", bev=0, segs=1)
        box((1.3, 0.25, 0.1), (x, 3.2, 0.61), "metal_steel", bev=0, segs=1)


@city_asset
def prop_phone_booth():
    box((2.8, 0.2, 2.2), (0, 0.1, 0), "concrete", bev=0.03, segs=1)
    for x in (-1.3, 1.3):
        box((0.2, 7, 0.2), (x, 3.6, -0.9), "metal_dark", bev=0, segs=1)
        box((0.1, 4.5, 1.8), (x, 4.2, 0), "window_glass", bev=0, segs=1)
    box((2.8, 7, 0.15), (0, 3.6, -1.0), "metal_dark", bev=0, segs=1)
    box((3, 0.5, 2.4), (0, 7.3, -0.1), "metal_dark", bev=0.05, segs=1)
    box((2.6, 0.45, 0.1), (0, 7.3, 1.12), "neon_blue", bev=0, segs=1)
    box((1.1, 1.6, 0.6), (0, 4.4, -0.7), "metal_steel", bev=0.08, segs=1)
    box((0.3, 0.9, 0.35), (-0.3, 4.6, -0.3), "plastic_black", bev=0.05, segs=1)  # handset
    tube([(-0.3, 4.2, -0.35), (-0.1, 3.4, -0.4), (0.1, 4.0, -0.45)], 0.04, "plastic_black", verts=6)


@city_asset
def prop_bus_stop():
    W, D, H = 8.0, 3.0, 7.5
    for x in (-W / 2, W / 2):
        for z in (-D / 2, D / 2 - 0.2):
            box((0.25, H, 0.25), (x, H / 2, z), "metal_dark", bev=0, segs=1)
    box((W + 0.8, 0.35, D + 0.8), (0, H + 0.1, 0.1), "trim_dark", bev=0.05, segs=1, rot=(-4, 0, 0))
    box((W, 5.5, 0.12), (0, 3.6, -D / 2), "window_glass", bev=0, segs=1)
    box((0.12, 5.5, D - 0.4), (-W / 2, 3.6, -0.1), "window_glass", bev=0, segs=1)
    box((0.3, 5.2, D - 0.4), (W / 2 + 0.1, 3.6, -0.1), "metal_dark", bev=0, segs=1)
    box((0.1, 4.6, D - 0.8), (W / 2 + 0.3, 3.6, -0.1), "billboard_face", bev=0, segs=1)  # ad panel
    for i in range(3):
        box((5.5, 0.15, 0.4), (-0.6, 1.8, -0.9 + i * 0.45), "wood_mid", bev=0.03, segs=1)
    for x in (-3, 1.8):
        box((0.15, 1.8, 1.2), (x, 0.9, -0.5), "metal_black", bev=0, segs=1)
    # the bus sign on its pole
    box((0.2, 9, 0.2), (-W / 2 - 1.5, 4.5, D / 2), "metal_steel", bev=0, segs=1)
    box((1.8, 1.8, 0.1), (-W / 2 - 1.5, 8.2, D / 2 + 0.1), "paint_red", bev=0.05, segs=1)
    neon_text("BUS", 0.7, (-W / 2 - 1.5, 8.2, D / 2 + 0.18), "neon_orange", tube_radius=0.05)


@city_asset
def prop_parking_meter():
    lathe([(0.25, 0), (0.12, 0.2), (0.1, 3.4)], (0, 0, 0), "metal_dark", verts=10)
    box((0.7, 1.1, 0.5), (0, 3.9, 0), "metal_steel", bev=0.1, segs=2)
    lathe([(0.36, 0), (0.3, 0.3), (0.0, 0.45)], (0, 4.45, 0), "chrome", verts=12)
    box((0.45, 0.3, 0.05), (0, 4.0, 0.26), "screen", bev=0, segs=1)
    box((0.12, 0.25, 0.05), (0.18, 3.6, 0.26), "metal_black", bev=0, segs=1)


@city_asset
def prop_planter():
    box((4, 1.6, 4), (0, 0.8, 0), "concrete", bev=0.1, segs=1)
    box((3.4, 0.2, 3.4), (0, 1.55, 0), "soil", bev=0, segs=1)
    for i, (x, z) in enumerate(((-0.7, -0.6), (0.8, -0.2), (0, 0.8), (-0.3, 0.1))):
        _blob((x, 2.3 + (i % 2) * 0.4, z), 1.1, "leaf", squash=(1.0, 0.9, 1.0), seed=40 + i)


@city_asset
def prop_bike_rack():
    for i in range(4):
        x = -2.25 + i * 1.5
        tube([(x, 0, -0.9), (x, 2.2, -0.9), (x, 2.4, -0.6), (x, 2.4, 0.6), (x, 2.2, 0.9), (x, 0, 0.9)], 0.08, "metal_steel", verts=8)
    tube([(-2.6, 0.3, 0), (2.6, 0.3, 0)], 0.06, "metal_steel", verts=6)


# Parked cars: variants of "car" (MapBuilder picks one per spot); front = +Z, car_paint is recolored

def _wheels(xs, zs, r=1.25):
    for x in xs:
        for z in zs:
            cyl(r, 0.9, (x, r, z), "rubber", axis="x", bev=0.25, verts=20)
            cyl(r * 0.56, 0.95, (x, r, z), "chrome", axis="x", bev=0.08, verts=12)


def _lights(W, front, back, y):
    for x in (-W / 2 + 1, W / 2 - 1):
        box((1.2, 0.5, 0.2), (x, y, front), "headlight", bev=0.05, segs=1)
        box((1.2, 0.5, 0.2), (x, y + 0.1, back), "neon_red", bev=0.05, segs=1)


@city_asset
def prop_car_b():
    """Delivery van: tall box body, sliding door line, big windscreen."""
    side = [(-7.5, 0.9), (7.2, 0.9), (7.4, 2.6), (6.8, 3.4), (5.0, 6.8), (-7.5, 7.0)]
    extrude(side, 6.6, (0, 0, 0), "car_paint", bev=0.2, segs=2, rot=(0, -90, 0))
    extrude([(6.6, 3.7), (5.0, 6.5), (3.4, 6.5), (3.4, 3.7)], 6.7, (0, 0, 0), "window_glass", bev=0.05, segs=1, rot=(0, -90, 0))
    for x in (-3.36, 3.36):
        box((0.05, 0.06, 5), (x, 4.2, -1), "metal_black", bev=0, segs=1)
    _wheels((-3.2, 3.2), (4.6, -4.8))
    _lights(6.6, 7.45, -7.55, 2.4)
    box((6.8, 0.6, 0.5), (0, 1.3, 7.5), "plastic_black", bev=0.15, segs=1)
    box((6.8, 0.6, 0.5), (0, 1.3, -7.6), "plastic_black", bev=0.15, segs=1)


@city_asset
def prop_car_c():
    """Pickup truck: cab and open bed."""
    side = [(-7.6, 1.1), (7.4, 1.1), (7.5, 3.0), (5.0, 3.4), (3.4, 5.4), (-0.6, 5.5), (-0.8, 3.4), (-7.6, 3.4)]
    extrude(side, 6.6, (0, 0.2, 0), "car_paint", bev=0.2, segs=2, rot=(0, -90, 0))
    extrude([(3.1, 3.6), (1.9 + 1.0, 5.2), (-0.4, 5.25), (-0.5, 3.6)], 6.7, (0, 0.2, 0), "window_glass", bev=0.05, segs=1, rot=(0, -90, 0))
    box((6.0, 0.2, 6.4), (0, 3.2, -4.2), "metal_black", bev=0, segs=1)  # bed floor
    box((6.6, 0.5, 0.2), (0, 4.0, -7.6), "chrome", bev=0.05, segs=1)
    _wheels((-3.2, 3.2), (4.8, -4.8), r=1.4)
    _lights(6.6, 7.55, -7.7, 2.8)
    box((6.8, 0.7, 0.5), (0, 1.6, 7.6), "chrome", bev=0.15, segs=1)


@city_asset
def prop_car_d():
    """Compact hatchback."""
    side = [(-5.8, 0.9), (5.6, 0.9), (5.8, 2.3), (5.0, 2.9), (2.4, 3.1), (0.8, 4.9), (-4.4, 5.0), (-5.8, 3.4)]
    extrude(side, 5.8, (0, 0, 0), "car_paint", bev=0.25, segs=3, rot=(0, -90, 0))
    extrude([(0.6, 3.15), (-4.2, 3.2), (-4.3, 4.8), (0.7, 4.75), (0.95, 4.5)], 5.9, (0, 0, 0), "window_glass", bev=0.05, segs=1, rot=(0, -90, 0))
    _wheels((-2.85, 2.85), (3.6, -3.8), r=1.15)
    _lights(5.8, 5.9, -5.9, 2.2)
    box((6.0, 0.55, 0.45), (0, 1.25, 5.8), "plastic_black", bev=0.15, segs=1)
    box((6.0, 0.55, 0.45), (0, 1.25, -5.9), "plastic_black", bev=0.15, segs=1)


# Specials ------------------------------------------------------------------------------------------------

@city_asset
def sp_fountain():
    lathe([(9, 0), (9.5, 0.2), (9.5, 1.6), (8.8, 1.8), (8.6, 0.6), (0, 0.6)], (0, 0, 0), "concrete", verts=48)
    cyl(8.6, 0.2, (0, 1.2, 0), "water", bev=0, verts=48)
    lathe([(1.4, 0.6), (1.0, 3), (0.8, 5), (3.5, 5.4), (3.6, 5.8), (0.6, 6), (0.5, 8), (1.2, 8.3), (0, 8.8)], (0, 0, 0), "concrete", verts=32)
    cyl(3.4, 0.15, (0, 5.75, 0), "water", bev=0, verts=32)


@city_asset
def sp_gas_station():
    for x in (-20, 20):
        for z in (-8, 8):
            box((1.2, 11, 1.2), (x, 5.5, z + 8), "metal_steel", bev=0.1, segs=1)
    box((52, 1.6, 26), (0, 11.8, 8), "plaster_white", bev=0.15, segs=1)
    box((52.2, 0.6, 26.2), (0, 11.2, 8), "neon_red", bev=0, segs=1)
    for x in (-10, 10):
        box((2, 0.4, 10), (x, 0.2, 8), "concrete", bev=0.1, segs=1)
        for z in (5, 11):
            box((1.4, 4.2, 1.2), (x, 2.5, z), "plastic_grey", bev=0.15, segs=2)
            box((1.0, 1.0, 1.25), (x, 3.6, z), "screen", bev=0, segs=1)
    box((6, 12, 0.6), (-28, 6, 20), "plastic_black", bev=0.1, segs=1)
    box((0.6, 18, 0.6), (-28, 9, 20), "metal_steel", bev=0, segs=1)


@city_asset
def prop_hoop():
    tube([(0, 0, 0), (0, 10, 0), (0, 11, 1.5)], 0.2, "metal_dark", verts=8)
    box((6, 3.5, 0.2), (0, 11.5, 2), "glass", bev=0.05, segs=1)
    lathe([(0.75, 0), (0.8, 0.05), (0.8, 0.1), (0.75, 0.15)], (0, 10.2, 2.8), "neon_orange", verts=20)


@city_asset
def sp_control_point():
    lathe([(18, 0), (18, 0.15), (17.5, 0.2), (0, 0.2)], (0, 0, 0), "concrete", verts=48)
    lathe([(17.2, 0.21), (17.2, 0.3), (16.6, 0.3), (16.6, 0.21)], (0, 0, 0), "neon_orange", verts=48)
    tube([(0, 0, 0), (0, 16, 0)], 0.2, "metal_steel", verts=8)
    box((0.1, 3.5, 5.5), (0, 14, 2.8), "fabric_dark", bev=0, segs=1)


# Trap house (bicoque) details, in plot-local coordinates ------------------------------------------------

@city_asset
def house_shack():
    B = HOUSE["BasementDepth"]
    G = B  # ground floor level
    top = G + HOUSE["GroundFloorHeight"]
    # windows: front living room, sides, back (the house box spans x -25..33, z -25..25)
    OX[0] = 4.0
    for x in (-16, -4, 8):
        window("front", x - 4, G + 6, 4.5, 5, 58, 50, lit=x == -4, frame="trim_light", style="plain")
    for face in ("left", "right"):
        for u in (-12, 10):
            window(face, u, G + 6, 4, 5, 58, 50, lit=False, frame="trim_light", style="plain")
    for x in (-14, 0, 14):
        window("back", 4 - x, G + 6, 4, 5, 58, 50, lit=False, frame="trim_light", style="plain")
    OX[0] = 0.0
    # door frame + open door leaf (the door opens into the hallway)
    box((0.6, 8.4, 0.6), (25.2, G + 4.2, 25.2), "trim_light", bev=0.05, segs=1)
    box((0.6, 8.4, 0.6), (30.8, G + 4.2, 25.2), "trim_light", bev=0.05, segs=1)
    box((6.2, 0.6, 0.6), (28, G + 8.3, 25.2), "trim_light", bev=0.05, segs=1)
    box((0.3, 7.8, 4.6), (25.8, G + 3.9, 22.2), "wood_dark", bev=0.05, segs=1)
    cyl(0.15, 0.3, (26.1, G + 3.9, 20.3), "chrome", axis="x", bev=0.03, verts=8)
    # porch: railing, posts caps, steps, light
    for x in (14.5, 32.5):
        box((0.9, 0.4, 0.9), (x, G + 1.2, 32.5), "trim_light", bev=0.05, segs=1)
    tube([(14.5, G + 3.4, 25.5), (14.5, G + 3.4, 32.5), (25, G + 3.4, 32.5)], 0.12, "trim_light", verts=6)
    for i in range(10):
        x = 15 + i * 1
        box((0.15, 2.8, 0.15), (x, G + 2.0, 32.5), "trim_light", bev=0, segs=1)
    for i in range(3):
        box((5.5, 0.35, 1.2), (28, G + 0.2 - i * 0.2, 33.6 + i * 1.1), "wood_mid", bev=0.03, segs=1)
    box((0.8, 0.8, 0.5), (31.2, G + 7, 25.4), "lamp_lens", bev=0.1, segs=1)
    # roof trim, gutters, chimney
    tube([(-27, top + 1.0, 27.2), (35, top + 1.0, 27.2)], 0.25, "trim_dark", verts=8)
    tube([(-27, top + 1.0, -27.2), (35, top + 1.0, -27.2)], 0.25, "trim_dark", verts=8)
    tube([(34.8, top + 1.0, 27.2), (34.8, G, 27.2)], 0.18, "trim_dark", verts=8)
    box((4, 12, 4), (-14, top + 6, -12), "brick_red", bev=0.1, segs=1)
    box((4.6, 0.6, 4.6), (-14, top + 12.2, -12), "concrete", bev=0.05, segs=1)
    ac_unit(-27, G, 6)
    # basement: exposed pipes, bare bulbs, water heater (all in the stairwell / on the walls)
    for z in (-18, 0, 18):
        tube([(-23.5, B - 1.2, z), (31.5, B - 1.2, z)], 0.18, "metal_rust", verts=8)
    for pos in ((0, B - 1.6, -8), (0, B - 1.6, 10), (28, B - 1.6, 6)):
        tube([(pos[0], B - 0.2, pos[2]), (pos[0], pos[1] + 0.4, pos[2])], 0.04, "metal_black", verts=6)
        lathe([(0.1, 0.4), (0.35, 0.1), (0.3, -0.3), (0.0, -0.4)], pos, "lamp_lens", verts=10)
    cyl(1.6, 6, (30, 3, -20), "metal_steel", bev=0.2, verts=16)
    # stair steps drawn on the ramp (the ramp itself gives the collisions)
    run, rise = 22, B
    steps = 16
    for i in range(steps):
        z = run - (i + 0.5) * run / steps
        y = rise - (i + 0.5) * rise / steps
        box((7.6, 0.3, run / steps + 0.1), (28, y + 0.35, z), "wood_mid", bev=0.03, segs=1)
    tube([(24.6, B + 3, 22), (24.6, 3, 0)], 0.1, "metal_black", verts=6)


# Trap house variants: same walls (Logic/CityParts), different life around them --------------------------

def _house_front_windows():
    """(u along the front face, y) of the three front windows, plot-local x = u + 4."""
    G = HOUSE["BasementDepth"]
    return [(x - 4, G + 6) for x in (-16, -4, 8)]


def _bars(face, u, y, w, h, W, D):
    for i in range(int(w // 0.55) + 1):
        _fbox(face, u - w / 2 + i * w / int(w // 0.55), y, 0.1, h + 0.4, 0.1, 0.5, W, D, "metal_black")
    for dy in (-h / 2, 0, h / 2):
        _fbox(face, u, y + dy, w + 0.3, 0.12, 0.12, 0.5, W, D, "metal_black")


@city_asset
def house_shack_b():
    """Rougher: boarded window, bars, satellite dish, old couch on the porch, bags by the side."""
    house_shack()
    G = HOUSE["BasementDepth"]
    top = G + HOUSE["GroundFloorHeight"]
    OX[0] = 4.0
    (u0, y0), (u1, y1), _ = _house_front_windows()
    rng = random.Random(61)
    for k in range(5):  # boards nailed over the first window
        _fbox("front", u0 + rng.uniform(-0.3, 0.3), y0 - 2 + k * 1.0, 5.4, 0.7, 0.12, 0.55, 58, 50, "wood_worn")
    _bars("front", u1, y1, 4.5, 5, 58, 50)
    OX[0] = 0.0
    # satellite dish on the side wall, cable down
    box((0.3, 2, 0.3), (33.4, top - 1, 18), "metal_steel", bev=0, segs=1)
    lathe([(0.05, 0), (0.9, 0.35), (1.3, 0.6)], (34.2, top - 0.3, 18), "plastic_grey", verts=16, rot=(0, 0, -70))
    tube([(33.3, top - 1.5, 18), (33.3, G + 2, 18)], 0.04, "plastic_black", verts=6)
    # couch on the porch, bags and a tire by the side
    box((6, 1.4, 2.4), (20, G + 0.9, 29), "fabric_dark", bev=0.3, segs=2)
    box((6, 2.2, 0.8), (20, G + 1.9, 28.1), "fabric_dark", bev=0.3, segs=2)
    for x in (16.8, 23.2):
        box((0.8, 1.8, 2.4), (x, G + 1.4, 29), "fabric_dark", bev=0.3, segs=2)
    for i, (x, z) in enumerate(((-27.5, 18), (-28.5, 16.5), (-27.8, 15))):
        _blob((x, G + 0.8, z), 0.9, "plastic_black", seed=70 + i)
    cyl(1.4, 0.9, (-28, G + 0.45, 11), "rubber", axis="y", bev=0.3, verts=16)


@city_asset
def house_shack_c():
    """Guarded: bars on every front window, camera and floodlight over the door, sign on the porch."""
    house_shack()
    G = HOUSE["BasementDepth"]
    OX[0] = 4.0
    for u, y in _house_front_windows():
        _bars("front", u, y, 4.5, 5, 58, 50)
    OX[0] = 0.0
    # camera + floodlight above the door
    box((0.6, 0.6, 1.2), (31.5, G + 9.2, 26), "plastic_grey", bev=0.1, segs=1, rot=(-20, -25, 0))
    cyl(0.22, 0.2, (31.3, G + 9.0, 26.7), "glass_dark", axis="z", bev=0, verts=10)
    box((1.4, 0.6, 0.8), (24.5, G + 9.2, 25.8), "metal_dark", bev=0.05, segs=1)
    box((1.2, 0.1, 0.6), (24.5, G + 8.88, 25.9), "lamp_lens", bev=0, segs=1)
    # sign hanging on the porch railing
    box((3, 1.8, 0.1), (19, G + 2.6, 32.65), "paper", bev=0, segs=1)
    box((2.6, 0.3, 0.02), (19, G + 3.0, 32.71), "paint_red", bev=0, segs=1)
    box((2.2, 0.2, 0.02), (19, G + 2.4, 32.71), "metal_black", bev=0, segs=1)
    # oil drum by the side
    cyl(1, 3, (-27.5, G + 1.5, 14), "metal_rust", bev=0.1, verts=16)
