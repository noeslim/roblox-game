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

from lib import box, cyl, extrude, lathe, tube

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


def window(face, u, y, w, h, W, D, lit=False, frame="trim_light", sill=True):
    glass = "window_lit" if lit else "window_glass"
    box(_face_size(face, w, h, 0.1), _face_point(face, u, y, W, D, 0.06), glass, bev=0, segs=1)
    for dy in (-h / 2, h / 2):
        box(_face_size(face, w + 0.5, 0.3, 0.3), _face_point(face, u, y + dy, W, D, 0.12), frame, bev=0, segs=1)
    for du in (-w / 2, w / 2):
        box(_face_size(face, 0.3, h, 0.3), _face_point(face, u + du, y, W, D, 0.12), frame, bev=0, segs=1)
    box(_face_size(face, 0.18, h, 0.15), _face_point(face, u, y, W, D, 0.1), frame, bev=0, segs=1)
    if sill:
        box(_face_size(face, w + 0.9, 0.3, 0.7), _face_point(face, u, y - h / 2 - 0.2, W, D, 0.3), frame, bev=0, segs=1)


def window_grid(face, W, D, floors, floor_h, per_floor, first_floor, w, h, rng, lit_chance=0.3, frame="trim_light", margin=4, y0=0.0):
    length = W if face in ("front", "back") else D
    usable = length - 2 * margin
    step = usable / per_floor
    for f in range(first_floor, floors):
        y = y0 + f * floor_h + floor_h * 0.55
        for i in range(per_floor):
            u = -length / 2 + margin + step * (i + 0.5)
            window(face, u, y, w, h, W, D, lit=rng.random() < lit_chance, frame=frame)


def cornice(W, D, y, mat="trim_light", depth=0.8, height=0.8):
    box((W + 2 * depth, height, depth), (0, y, D / 2 + depth / 2), mat, bev=0, segs=1)
    box((W + 2 * depth, height, depth), (0, y, -D / 2 - depth / 2), mat, bev=0, segs=1)
    box((depth, height, D), (W / 2 + depth / 2, y, 0), mat, bev=0, segs=1)
    box((depth, height, D), (-W / 2 - depth / 2, y, 0), mat, bev=0, segs=1)


def parapet(W, D, H, mat="trim_light", h=1.4, t=0.8):
    box((W, h, t), (0, H + h / 2, D / 2 - t / 2), mat, bev=0, segs=1)
    box((W, h, t), (0, H + h / 2, -D / 2 + t / 2), mat, bev=0, segs=1)
    box((t, h, D - 2 * t), (W / 2 - t / 2, H + h / 2, 0), mat, bev=0, segs=1)
    box((t, h, D - 2 * t), (-W / 2 + t / 2, H + h / 2, 0), mat, bev=0, segs=1)


def ac_unit(x, y, z):
    box((3, 2, 2.4), (x, y + 1, z), "plastic_grey", bev=0.1, segs=1)
    cyl(0.8, 0.1, (x, y + 2.02, z), "metal_black", bev=0, verts=12)


DOOR_LEAF = {"wood_dark": "door_wood", "window_glass": "door_glass", "metal_dark": "door_metal"}


def door(face, u, W, D, w=4, h=7.5, mat="wood_dark", y0=0.0):
    leaf = DOOR_LEAF.get(mat, mat)  # own mesh: replaced in game by a door that opens
    box(_face_size(face, w, h, 0.2), _face_point(face, u, y0 + h / 2, W, D, 0.08), leaf, bev=0.02, segs=1)
    box(_face_size(face, w + 1, 0.5, 0.5), _face_point(face, u, y0 + h + 0.25, W, D, 0.2), "trim_light", bev=0, segs=1)
    for du in (-w / 2 - 0.25, w / 2 + 0.25):
        box(_face_size(face, 0.5, h, 0.5), _face_point(face, u + du, y0 + h / 2, W, D, 0.2), "trim_light", bev=0, segs=1)
    box(_face_size(face, 0.15, 0.15, 0.3), _face_point(face, u + w / 2 - 0.5, y0 + h * 0.5, W, D, 0.3), "chrome", bev=0, segs=1)


def awning(face, u, y, w, W, D, depth=3.5):
    fx, fy, fz = _face_point(face, u, y, W, D, depth / 2)
    rot = {"front": (-20, 0, 0), "back": (20, 0, 0), "right": (0, 0, 20), "left": (0, 0, -20)}[face]
    box(_face_size(face, w, 0.2, depth), (fx, fy, fz), "awning", bev=0, segs=1, rot=rot)


# Buildings --------------------------------------------------------------------------------------------

@city_asset
def bld_apartment():
    a = ARCH["apartment"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(11)
    floors, fh = 4, H / 4
    for face in ("front", "back"):
        window_grid(face, W, D, floors, fh, 5, 1, 3.2, 5.5, rng)
        window_grid(face, W, D, 1, fh, 5, 0, 3.2, 5.5, rng) if face == "back" else None
    for face in ("left", "right"):
        window_grid(face, W, D, floors, fh, 3, 0, 3.0, 5.5, rng)
    # ground floor front: entrance + two windows
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"])
    box((9, 0.4, 4), (0, 9.2, D / 2 + 2), "trim_dark", bev=0, segs=1)
    for u in (-13, 13):
        window("front", u, 5, 6, 5, W, D, lit=True)
    # fire escape
    for f in range(1, floors):
        y = f * fh
        box((12, 0.3, 3), (-8, y, D / 2 + 1.6), "metal_black", bev=0, segs=1)
        tube([(-14, y, D / 2 + 3), (-14, y + 3, D / 2 + 3), (-2, y + 3, D / 2 + 3), (-2, y, D / 2 + 3)], 0.08, "metal_black", verts=6)
        if f < floors - 1:
            tube([(-3, y + 0.2, D / 2 + 1.6), (-12, y + fh, D / 2 + 1.6)], 0.12, "metal_black", verts=6)
    cornice(W, D, H - 0.4)
    parapet(W, D, H)
    cyl(3, 6, (8, H + 7, -4), "wood_worn", bev=0.1, verts=16)
    lathe([(3.2, 0), (0.1, 2)], (8, H + 10, -4), "metal_dark", verts=16)
    for dx in (-2, 2):
        for dz in (-2, 2):
            box((0.3, 4, 0.3), (8 + dx, H + 2, -4 + dz), "metal_black", bev=0, segs=1)
    ac_unit(-10, H, -6)
    ac_unit(-4, H, 6)
    box((5, 4, 4), (14, H + 2, 8), "concrete", bev=0.05, segs=1)


@city_asset
def bld_shop():
    a = ARCH["shop"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(12)
    # storefront
    box((W - 8, 7, 0.15), (-2, 4.5, D / 2 + 0.06), "window_glass", bev=0, segs=1)
    box((W - 7, 0.5, 0.5), (-2, 8.2, D / 2 + 0.2), "trim_dark", bev=0, segs=1)
    box((W - 7, 1, 0.5), (-2, 0.5, D / 2 + 0.2), "trim_dark", bev=0, segs=1)
    for u in (-W / 2 + 4, -2, W / 2 - 8):
        box((0.4, 7.5, 0.4), (u, 4.5, D / 2 + 0.2), "trim_dark", bev=0, segs=1)
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="window_glass")
    awning("front", -2, 9.8, W - 6, W, D)
    window_grid("front", W, D, 2, H / 2, 4, 1, 3.5, 5, rng)
    window_grid("back", W, D, 2, H / 2, 4, 1, 3.5, 5, rng)
    for face in ("left", "right"):
        window_grid(face, W, D, 2, H / 2, 2, 1, 3, 5, rng)
    cornice(W, D, H - 0.4, "trim_dark")
    parapet(W, D, H, "trim_dark", h=1)
    ac_unit(-6, H, -4)
    ac_unit(4, H, -6)


def glass_tower(W, D, H, floor_h, rng, crown=True, lobby_h=None, dr=None):
    lobby_h = lobby_h or floor_h
    floors = int(H // floor_h)
    for f in range(1, floors):
        if f * floor_h < lobby_h:
            continue  # the lobby is taller than a floor
        y = f * floor_h + floor_h * 0.5
        for face in ("front", "back", "left", "right"):
            length = W if face in ("front", "back") else D
            box(_face_size(face, length - 1, floor_h * 0.62, 0.2), _face_point(face, 0, y, W, D, 0.08), "window_lit" if rng.random() < 0.25 else "window_glass", bev=0, segs=1)
    for face in ("front", "back", "left", "right"):
        length = W if face in ("front", "back") else D
        n = int(length // 4)
        for i in range(n + 1):
            u = -length / 2 + 0.5 + i * (length - 1) / n
            box(_face_size(face, 0.35, H - lobby_h, 0.35), _face_point(face, u, lobby_h + (H - lobby_h) / 2, W, D, 0.2), "trim_dark", bev=0, segs=1)
    # lobby
    box((W * 0.6, lobby_h - 1, 0.15), (0, lobby_h / 2, D / 2 + 0.06), "window_glass", bev=0, segs=1)
    box((W * 0.7, 0.6, 5), (0, lobby_h, D / 2 + 2.5), "trim_dark", bev=0, segs=1)
    dr = dr or {"x": 0, "w": 6, "h": lobby_h - 1.5}
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="window_glass")
    parapet(W, D, H, "trim_dark", h=1.2)
    if crown:
        box((W * 0.6, 6, D * 0.6), (0, H + 3, 0), "concrete", bev=0.1, segs=1)
        cyl(0.4, 22, (0, H + 17, 0), "metal_steel", bev=0.05, verts=8)
        lathe([(0.8, 0), (0.8, 0.8), (0, 1.2)], (0, H + 28, 0), "neon_red", verts=12)
    for i in range(3):
        ac_unit(-W / 3 + i * 6, H, -D / 3)


@city_asset
def bld_office():
    a = ARCH["office"]
    glass_tower(a["w"], a["d"], a["h"], 5, random.Random(13), crown=False, lobby_h=a["interior"]["height"], dr=a["door"])


@city_asset
def bld_tower():
    a = ARCH["tower"]
    glass_tower(a["w"], a["d"], a["h"], 5, random.Random(14), crown=True, lobby_h=a["interior"]["height"], dr=a["door"])


@city_asset
def bld_warehouse():
    a = ARCH["warehouse"]
    W, D, H = a["w"], a["d"], a["h"]
    for u in (-14, 14):
        box((14, 14, 0.3), (u, 7, D / 2 + 0.1), "metal_steel", bev=0, segs=1)
        for i in range(14):
            box((14, 0.12, 0.35), (u, 0.5 + i, D / 2 + 0.3), "metal_dark", bev=0, segs=1)
        box((16, 0.8, 0.8), (u, 14.4, D / 2 + 0.4), "trim_dark", bev=0, segs=1)
        box((1, 0.6, 1), (u, 16, D / 2 + 0.6), "lamp_lens", bev=0, segs=1)
    for face in ("left", "right", "back"):
        length = W if face == "back" else D
        box(_face_size(face, length - 6, 2, 0.15), _face_point(face, 0, H - 4, W, D, 0.06), "window_glass", bev=0, segs=1)
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="metal_dark")
    for i in range(4):
        cyl(1.2, 2.5, (-20 + i * 13, H + 1.25, 0), "metal_steel", bev=0.1, verts=12)
        lathe([(1.6, 0), (0.1, 0.8)], (-20 + i * 13, H + 2.5, 0), "metal_dark", verts=12)
    box((W, 0.8, 0.8), (0, H - 0.4, D / 2 + 0.4), "trim_dark", bev=0, segs=1)
    for u in (-24, -4, 4, 24):
        box((1.4, 2, 0.8), (u, 1.5, D / 2 + 0.5), "rubber", bev=0.1, segs=1)


@city_asset
def bld_chinatown():
    a = ARCH["chinatown"]
    W, D, H = a["w"], a["d"], a["h"]
    rng = random.Random(15)
    fh = H / 3
    box((W - 6, 6.5, 0.15), (-1, 4, D / 2 + 0.06), "window_glass", bev=0, segs=1)
    dr = a["door"]
    door("front", dr["x"], W, D, w=dr["w"], h=dr["h"], mat="wood_dark")
    awning("front", -1, 9.5, W - 4, W, D, depth=3)
    for f in (1, 2):
        y = f * fh
        box((W - 2, 0.4, 3), (0, y, D / 2 + 1.5), "concrete", bev=0, segs=1)
        tube([(-W / 2 + 1, y + 3, D / 2 + 3), (W / 2 - 1, y + 3, D / 2 + 3)], 0.1, "paint_red", verts=6)
        for i in range(8):
            u = -W / 2 + 1.5 + i * (W - 3) / 7
            box((0.15, 3, 0.15), (u, y + 1.5, D / 2 + 3), "paint_red", bev=0, segs=1)
    window_grid("front", W, D, 3, fh, 3, 1, 3, 4.5, rng, lit_chance=0.5, frame="paint_red")
    window_grid("back", W, D, 3, fh, 3, 1, 3, 4.5, rng, lit_chance=0.4)
    for face in ("left", "right"):
        window_grid(face, W, D, 3, fh, 2, 1, 2.6, 4.5, rng)
    # tiled roof edge + lanterns
    box((W + 3, 1.2, D + 3), (0, H + 0.2, 0), "roof_green", bev=0.2, segs=1)
    box((W + 1, 1.6, D + 1), (0, H + 1.2, 0), "roof_green", bev=0.3, segs=1)
    for u in (-W / 2 + 4, 0, W / 2 - 4):
        tube([(u, 11, D / 2 + 3.3), (u, 10, D / 2 + 3.3)], 0.04, "metal_black", verts=6)
        lathe([(0.2, -0.9), (0.7, -0.6), (0.8, 0), (0.7, 0.6), (0.2, 0.9)], (u, 9.1, D / 2 + 3.3), "neon_red", verts=12)


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
        window_grid(face, W, D, 2, H / 2, 3, 0, 6, 6, random.Random(16), lit_chance=0.3, frame="trim_dark")


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
            box(_face_size(face, 4, 5, 0.2), _face_point(face, u, 10, W, D, 0.06), "metal_black", bev=0, segs=1)
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
        window("front", x - 4, G + 6, 4.5, 5, 58, 50, lit=x == -4, frame="trim_light")
    for face in ("left", "right"):
        for u in (-12, 10):
            window(face, u, G + 6, 4, 5, 58, 50, lit=False, frame="trim_light")
    for x in (-14, 0, 14):
        window("back", 4 - x, G + 6, 4, 5, 58, 50, lit=False, frame="trim_light")
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
