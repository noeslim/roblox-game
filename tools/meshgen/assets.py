"""Every model of the library. Coordinates are Roblox studs relative to the object's center
(buildables: floor at y = -height/2, customers stand on the +Z side) or to the weapon's body
center (weapon parts: barrel towards +X, all parts share the same weapon space so any
combination fits together)."""
import math
import random

from lib import begin_asset, box, cyl, extrude, lathe, leaf, neon_text, tube


def register(fn_list):
    def deco(fn):
        fn_list.append((fn.__name__, fn))
        return fn

    return deco


BUILDABLES = []
WEAPON_PARTS = []
buildable = register(BUILDABLES)
weapon_part = register(WEAPON_PARTS)


# Shared props -------------------------------------------------------------------------------

def cash_stack(pos, count=3):
    x, y, z = pos
    for i in range(count):
        box((0.62, 0.07, 0.28), (x + i * 0.03, y + i * 0.075, z + (i % 2) * 0.03), "cash", bev=0.01, segs=1)
    box((0.1, 0.075 * count + 0.01, 0.3), (x + 0.03, y + 0.075 * (count - 1) / 2, z + 0.015), "paper", bev=0.005, segs=1)


def cash_register(pos):
    x, y, z = pos  # y = counter top
    box((1.1, 0.24, 0.85), (x, y + 0.12, z), "plastic_black", bev=0.04)
    box((1.0, 0.1, 0.75), (x, y + 0.27, z + 0.02), "plastic_grey", bev=0.03, rot=(-8, 0, 0))
    for i in range(3):
        for j in range(4):
            box((0.13, 0.04, 0.11), (x - 0.3 + j * 0.17, y + 0.33 - i * 0.012, z + 0.2 - i * 0.14), "plastic_black", bev=0.015, segs=1, rot=(-8, 0, 0))
    box((0.42, 0.24, 0.05), (x + 0.2, y + 0.46, z - 0.33), "plastic_black", bev=0.02, rot=(-15, 0, 0))
    box((0.36, 0.18, 0.02), (x + 0.2, y + 0.465, z - 0.3), "screen", bev=0.005, segs=1, rot=(-15, 0, 0))
    box((0.9, 0.12, 0.05), (x, y + 0.08, z + 0.44), "metal_steel", bev=0.01, segs=1)


# Business --------------------------------------------------------------------------------------

@buildable
def counter_folding():
    # size 4 x 3 x 2, floor at y = -1.5
    box((4, 0.1, 2), (0, 1.42, 0), "plastic_grey", bev=0.045)
    box((3.9, 0.05, 1.9), (0, 1.35, 0), "metal_steel", bev=0.01, segs=1)
    for sx in (-1.7, 1.7):
        for sz in (-0.78, 0.78):
            tube([(sx, 1.33, sz * 0.9), (sx * 1.02, -1.45, sz)], 0.055, "metal_steel")
            cyl(0.075, 0.08, (sx * 1.02, -1.46, sz), "rubber", bev=0.02)
        tube([(sx * 1.01, -1.1, -0.8), (sx * 1.01, -1.1, 0.8)], 0.04, "metal_steel")
    cash_stack((-1.0, 1.51, 0.25))
    box((0.9, 0.34, 0.6), (1.05, 1.64, -0.25), "metal_dark", bev=0.04)
    tube([(0.8, 1.82, -0.25), (0.85, 1.9, -0.25), (1.25, 1.9, -0.25), (1.3, 1.82, -0.25)], 0.025, "metal_steel")


@buildable
def counter_wood():
    # size 6 x 4 x 2, floor at y = -2
    box((5.8, 3.3, 1.7), (0, -0.2, -0.05), "wood_mid", bev=0.04)
    for x in (-1.9, 0, 1.9):
        box((1.65, 2.4, 0.08), (x, -0.15, 0.82), "wood_dark", bev=0.03)
        box((1.35, 2.1, 0.05), (x, -0.15, 0.86), "wood_mid", bev=0.04)
    box((5.9, 0.3, 1.8), (0, -1.85, 0), "metal_black", bev=0.02)
    box((6, 0.18, 2.0), (0, 1.55, 0), "wood_dark", bev=0.06)
    box((5.8, 0.05, 0.05), (0, 1.42, 0.97), "neon_purple", bev=0.0)
    cash_register((1.7, 1.64, -0.25))
    cash_stack((-1.6, 1.68, 0.1))


@buildable
def counter_metal():
    # size 8 x 4 x 2, floor at y = -2
    box((7.8, 3.3, 1.7), (0, -0.25, -0.05), "metal_brushed", bev=0.05)
    box((7.5, 2.6, 0.05), (0, -0.35, 0.82), "diamond_plate", bev=0.01, segs=1)
    box((7.9, 0.28, 1.8), (0, -1.86, 0), "metal_black", bev=0.02)
    box((8, 0.14, 2), (0, 1.47, 0), "metal_steel", bev=0.04)
    box((7.6, 0.42, 1.6), (0, 1.76, 0), "glass", bev=0.01, segs=1)
    for sx in (-3.8, 3.8):
        for sz in (-0.8, 0.8):
            tube([(sx, 1.54, sz), (sx, 1.98, sz)], 0.035, "metal_black")
    for sz in (-0.8, 0.8):
        tube([(-3.8, 1.98, sz), (3.8, 1.98, sz)], 0.035, "metal_black")
    for sx in (-3.8, 3.8):
        tube([(sx, 1.98, -0.8), (sx, 1.98, 0.8)], 0.035, "metal_black")
    box((7.7, 0.05, 0.05), (0, 1.36, 0.98), "neon_green", bev=0.0)
    cash_stack((-2.8, 1.6, 0.0), 4)


@buildable
def workbench_basic():
    # size 6 x 4 x 3, floor at y = -2
    box((6, 0.28, 3), (0, 0.76, 0), "wood_worn", bev=0.05)
    for sx in (-2.7, 2.7):
        for sz in (-1.3, 1.3):
            box((0.26, 2.6, 0.26), (sx, -0.65, sz), "metal_dark", bev=0.03)
            box((0.4, 0.06, 0.4), (sx, -1.97, sz), "metal_black", bev=0.01, segs=1)
    for sz in (-1.3, 1.3):
        box((5.2, 0.14, 0.12), (0, 0.55, sz), "metal_dark", bev=0.02)
    box((5.6, 0.1, 2.7), (0, -1.45, 0), "wood_mid", bev=0.02)
    # pegboard with tools
    box((6, 1.25, 0.1), (0, 1.52, -1.44), "wood_crate", bev=0.02)
    for i in range(10):
        for j in range(3):
            cyl(0.025, 0.03, (-2.6 + i * 0.58, 1.2 + j * 0.3, -1.38), "metal_black", axis="z", verts=8, bev=0)
    extrude([(-0.08, -0.35), (0.08, -0.35), (0.06, 0.2), (0.14, 0.28), (0.1, 0.4), (-0.1, 0.4), (-0.14, 0.28), (-0.06, 0.2)], 0.04, (-2.0, 1.5, -1.35), "metal_steel", bev=0.01)
    cyl(0.05, 0.75, (-1.2, 1.45, -1.33), "wood_mid", bev=0.01)
    box((0.35, 0.14, 0.12), (-1.2, 1.85, -1.33), "metal_dark", bev=0.02)
    cyl(0.04, 0.5, (-0.5, 1.4, -1.33), "paint_red", bev=0.01)
    cyl(0.012, 0.3, (-0.5, 1.75, -1.33), "metal_steel", bev=0)
    tube([(0.4, 1.9, -1.34), (0.4, 1.3, -1.34), (1.2, 1.3, -1.34), (1.2, 1.9, -1.34)], 0.02, "metal_steel")
    # vise
    box((0.7, 0.18, 0.5), (2.1, 0.99, 0.95), "paint_green", bev=0.03)
    box((0.7, 0.35, 0.18), (2.1, 1.25, 0.8), "paint_green", bev=0.03)
    box((0.7, 0.35, 0.18), (2.1, 1.25, 1.2), "paint_green", bev=0.03)
    cyl(0.05, 0.9, (2.1, 1.2, 1.55), "metal_steel", axis="z", bev=0.01)
    cyl(0.025, 0.5, (2.1, 1.2, 1.95), "metal_steel", axis="x", bev=0.005)
    # lamp
    cyl(0.18, 0.08, (-2.4, 0.94, -1.1), "metal_black", bev=0.02)
    tube([(-2.4, 0.95, -1.1), (-2.4, 1.7, -0.9), (-2.0, 1.95, -0.5)], 0.03, "metal_black")
    lathe([(0.05, 0.0), (0.12, -0.05), (0.3, -0.3), (0.28, -0.32), (0.1, -0.08)], (-2.0, 1.97, -0.45), "metal_black", verts=24)
    cyl(0.08, 0.1, (-2.0, 1.8, -0.45), "neon_orange", bev=0.02)
    # parts & scrap on the bench
    box((1.1, 0.25, 0.7), (-0.4, 1.03, 0.6), "metal_dark", bev=0.03)
    for i in range(5):
        box((0.3, 0.06, 0.12), (0.6 + i * 0.12, 0.93, -0.2 + (i % 2) * 0.2), "metal_gun", bev=0.01, segs=1, rot=(0, i * 23, 0))
    # toolbox on the lower shelf
    box((1.4, 0.6, 0.6), (1.5, -1.1, 0.4), "paint_red", bev=0.05)
    tube([(1.1, -0.8, 0.4), (1.15, -0.62, 0.4), (1.85, -0.62, 0.4), (1.9, -0.8, 0.4)], 0.03, "metal_black")
    box((0.9, 0.5, 0.7), (-1.6, -1.15, -0.5), "wood_crate", bev=0.03)


@buildable
def display_case():
    # size 4 x 4 x 2, floor at y = -2
    box((4, 1.85, 2), (0, -1.05, 0), "wood_dark", bev=0.04)
    box((3.9, 0.15, 1.9), (0, -1.93, 0), "metal_black", bev=0.02)
    box((3.4, 1.4, 0.05), (0, -1.05, 1.0), "wood_mid", bev=0.03)
    box((3.8, 1.8, 1.8), (0, 0.9, 0), "glass", bev=0.01, segs=1)
    box((3.7, 0.04, 1.7), (0, 0.9, 0), "glass", bev=0.0)
    corners = [(-1.9, -0.9), (1.9, -0.9), (1.9, 0.9), (-1.9, 0.9)]
    for x, z in corners:
        tube([(x, -0.1, z), (x, 1.85, z)], 0.04, "metal_steel")
    for y in (-0.1, 1.85):
        for i in range(4):
            (x1, z1), (x2, z2) = corners[i], corners[(i + 1) % 4]
            tube([(x1, y, z1), (x2, y, z2)], 0.04, "metal_steel")
    box((3.6, 0.05, 0.05), (0, 1.78, 0.8), "neon_blue", bev=0.0)
    # velvet pads and a showcased pistol silhouette
    box((3.4, 0.06, 1.4), (0, -0.07, 0), "fabric_purple", bev=0.02)
    extrude([(-0.5, 0.0), (0.45, 0.0), (0.45, 0.16), (-0.5, 0.16), (-0.5, -0.05), (-0.35, -0.05), (-0.45, -0.45), (-0.25, -0.45), (-0.2, 0.0)], 0.1, (-0.8, 0.12, 0), "metal_gun", bev=0.01, rot=(-90, 0, 0))
    extrude([(-0.5, 0.0), (0.45, 0.0), (0.45, 0.16), (-0.5, 0.16), (-0.5, -0.05), (-0.35, -0.05), (-0.45, -0.45), (-0.25, -0.45), (-0.2, 0.0)], 0.1, (0.9, 0.12, 0.1), "metal_gold", bev=0.01, rot=(-90, 20, 0))


@buildable
def wall_rack():
    # size 6 x 6 x 1
    box((6, 6, 0.25), (0, 0, -0.37), "wood_crate", bev=0.03)
    box((6, 0.2, 0.3), (0, 2.9, -0.3), "wood_dark", bev=0.02)
    box((6, 0.2, 0.3), (0, -2.9, -0.3), "wood_dark", bev=0.02)
    for y in (1.6, -0.4, -2.4):
        box((5.6, 0.14, 0.35), (0, y, -0.08), "metal_black", bev=0.02)
        for x in (-2.2, -1.1, 0, 1.1, 2.2):
            tube([(x, y + 0.07, 0.05), (x, y + 0.07, 0.35), (x, y + 0.2, 0.42)], 0.03, "metal_steel")


@buildable
def storage_crate():
    # size 3 x 3 x 3, planks with gaps + corner posts
    rng = random.Random(7)
    for face in range(4):
        for i in range(4):
            y = -1.1 + i * 0.73
            jitter = rng.uniform(-0.01, 0.01)
            if face in (0, 1):
                z = 1.42 if face == 0 else -1.42
                box((2.7, 0.66, 0.12), (jitter, y, z), "wood_crate", bev=0.02, segs=1)
            else:
                x = 1.42 if face == 2 else -1.42
                box((0.12, 0.66, 2.7), (x, y, jitter), "wood_crate", bev=0.02, segs=1)
    for i in range(4):
        box((2.7, 0.12, 0.66), (0, 1.43, -1.1 + i * 0.73), "wood_crate", bev=0.02, segs=1)
        box((2.7, 0.12, 0.66), (0, -1.43, -1.1 + i * 0.73), "wood_crate", bev=0.02, segs=1)
    for sx in (-1.38, 1.38):
        for sz in (-1.38, 1.38):
            box((0.24, 3.0, 0.24), (sx, 0, sz), "wood_worn", bev=0.03)
    for z in (-1.5, 1.5):
        box((2.9, 0.12, 0.02), (0, 0.6, z), "metal_dark", bev=0.0)
        box((2.9, 0.12, 0.02), (0, -0.6, z), "metal_dark", bev=0.0)


@buildable
def safe():
    # size 3 x 4 x 3, floor at y = -2
    box((3, 3.65, 2.8), (0, 0.15, -0.1), "metal_dark", bev=0.14, segs=4)
    for sx in (-1.2, 1.2):
        for sz in (-1.1, 0.9):
            cyl(0.14, 0.2, (sx, -1.9, sz), "metal_black", bev=0.03)
    box((2.45, 3.05, 0.14), (0, 0.15, 1.33), "metal_black", bev=0.05)
    box((2.2, 2.8, 0.05), (0, 0.15, 1.41), "metal_dark", bev=0.03)
    for y in (-0.9, 1.2):
        cyl(0.08, 0.5, (-1.25, y, 1.3), "metal_steel", bev=0.02)
    lathe([(0.0, 0.0), (0.3, 0.0), (0.3, 0.08), (0.24, 0.12), (0.1, 0.14), (0.0, 0.14)], (0.55, 0.75, 1.42), "metal_brass", axis="z", verts=32)
    for i in range(24):
        a = 2 * math.pi * i / 24
        box((0.012, 0.05, 0.02), (0.55 + math.cos(a) * 0.27, 0.75 + math.sin(a) * 0.27, 1.55), "metal_black", bev=0.0, rot=(0, 0, math.degrees(a)))
    cyl(0.1, 0.2, (0.55, -0.1, 1.5), "metal_steel", axis="z", bev=0.02)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.3
        tube([(0.55, -0.1, 1.58), (0.55 + math.cos(a) * 0.45, -0.1 + math.sin(a) * 0.45, 1.6)], 0.035, "metal_steel")
        cyl(0.06, 0.08, (0.55 + math.cos(a) * 0.47, -0.1 + math.sin(a) * 0.47, 1.6), "metal_black", axis="z", bev=0.02)
    box((0.9, 0.22, 0.02), (-0.2, 1.45, 1.44), "metal_brass", bev=0.005, segs=1)


# Decor ------------------------------------------------------------------------------------------------

@buildable
def couch():
    # size 6 x 3 x 3, floor at y = -1.5
    box((6, 0.55, 2.8), (0, -0.95, -0.05), "fabric_dark", bev=0.12, segs=3)
    for sx in (-2.7, 2.7):
        for sz in (-1.2, 1.1):
            lathe([(0.1, 0.0), (0.08, 0.25), (0.12, 0.28), (0.0, 0.29)], (sx, -1.5, sz), "metal_brass", verts=16)
    for x in (-1.36, 1.36):
        box((2.6, 0.55, 2.2), (x, -0.43, 0.25), "fabric_purple", bev=0.22, segs=5)
        box((2.6, 1.45, 0.62), (x, 0.55, -0.95), "fabric_purple", bev=0.26, segs=5, rot=(-10, 0, 0))
    box((5.6, 1.7, 0.5), (0, 0.15, -1.25), "fabric_dark", bev=0.16, segs=4)
    for sx in (-2.72, 2.72):
        box((0.58, 1.25, 2.8), (sx, -0.3, -0.05), "fabric_dark", bev=0.24, segs=5)
    box((0.9, 0.9, 0.3), (1.8, -0.05, 0.3), "fabric_purple", bev=0.13, segs=4, rot=(-25, 20, 10))


@buildable
def plant():
    # size 2 x 4 x 2, floor at y = -2
    lathe([(0.5, -2.0), (0.6, -1.96), (0.8, -0.95), (0.86, -0.88), (0.84, -0.84), (0.74, -0.86), (0.66, -1.2), (0.0, -1.2)], (0, 0, 0), "ceramic", verts=40)
    cyl(0.68, 0.06, (0, -1.02, 0), "soil", bev=0.0)
    rng = random.Random(3)
    for i in range(16):
        yaw = i * 360 / 16 + rng.uniform(-10, 10)
        pitch = rng.uniform(35, 75)
        length = rng.uniform(1.3, 2.1)
        leaf(length, rng.uniform(0.28, 0.42), (rng.uniform(-0.1, 0.1), -1.0, rng.uniform(-0.1, 0.1)), "leaf", yaw, pitch, bend=rng.uniform(0.2, 0.45))


@buildable
def speaker():
    # size 2 x 4 x 2
    box((2, 4, 1.8), (0, 0, -0.1), "plastic_black", bev=0.08)
    box((1.85, 3.85, 0.05), (0, 0, 0.8), "fabric_dark", bev=0.02)
    lathe([(0.62, 0.0), (0.66, 0.05), (0.6, 0.08), (0.45, 0.02), (0.15, -0.12), (0.12, -0.08), (0.0, -0.08)], (0, -0.8, 0.84), "metal_dark", axis="z", verts=40)
    lathe([(0.66, 0.0), (0.72, 0.04), (0.66, 0.08), (0.6, 0.04)], (0, -0.8, 0.84), "rubber", axis="z", verts=40)
    lathe([(0.25, 0.0), (0.28, 0.04), (0.2, 0.06), (0.1, 0.03), (0.0, 0.03)], (0, 1.1, 0.84), "metal_steel", axis="z", verts=32)
    ring = [(math.cos(2 * math.pi * i / 32) * 0.78, -0.8 + math.sin(2 * math.pi * i / 32) * 0.78, 0.86) for i in range(33)]
    tube(ring, 0.03, "neon_purple")
    cyl(0.18, 0.1, (0, 0.35, 0.8), "plastic_black", axis="z", bev=0.02)


@buildable
def neon_sign_pink():
    # size 6 x 6 x 1, floor at y = -3
    for sx in (-2.5, 2.5):
        tube([(sx, -2.95, 0), (sx, 0.1, 0)], 0.07, "metal_dark")
        box((0.6, 0.08, 0.6), (sx, -2.96, 0), "metal_black", bev=0.02)
    box((6, 3, 0.18), (0, 1.5, -0.32), "metal_black", bev=0.04)
    neon_text("BLASTERS", 0.95, (0, 1.75, -0.1), "neon_pink", tube_radius=0.045)
    neon_text("OPEN 24/7", 0.5, (0, 0.75, -0.1), "neon_blue", tube_radius=0.03)
    border = [(-2.8, 0.2, -0.15), (2.8, 0.2, -0.15), (2.8, 2.85, -0.15), (-2.8, 2.85, -0.15), (-2.8, 0.2, -0.15)]
    tube(border, 0.04, "neon_pink")


@buildable
def neon_tube_blue():
    # size 1 x 8 x 1, floor at y = -4
    lathe([(0.45, -4.0), (0.45, -3.85), (0.3, -3.8), (0.12, -3.6), (0.0, -3.6)], (0, 0, 0), "metal_black", verts=32)
    cyl(0.12, 7.3, (0, 0.0, 0), "neon_blue", bev=0.05)
    for y in (-3.0, 0.0, 3.0):
        cyl(0.16, 0.12, (0, y, 0), "metal_steel", bev=0.02)
    lathe([(0.16, 3.7), (0.16, 3.85), (0.0, 3.9)], (0, 0, 0), "metal_black", verts=24)


# Weapon parts (weapon space) ----------------------------------------------------------------------------
# Body spans x -0.85 .. 0.85 and y -0.12 .. 0.32. Barrel starts at x 0.85, stock at x -0.85,
# sights sit on the rail at y 0.36, magazines hang under x ~0.38.

def rail(length, x, y, mat="metal_black"):
    box((length, 0.05, 0.2), (x, y, 0), mat, bev=0.01, segs=1)
    n = int(length / 0.1)
    for i in range(n):
        box((0.05, 0.035, 0.22), (x - length / 2 + 0.05 + i * 0.1, y + 0.04, 0), mat, bev=0.005, segs=1)


def trigger_group(mat_guard="metal_black"):
    tube([(-0.05, -0.12, 0), (-0.02, -0.36, 0), (0.28, -0.37, 0), (0.33, -0.12, 0)], 0.03, mat_guard)
    extrude([(0.1, -0.12), (0.16, -0.12), (0.13, -0.3), (0.09, -0.29)], 0.05, (0, 0, 0), "metal_steel", bev=0.01)


@weapon_part
def street_body():
    extrude([(-0.85, -0.12), (0.85, -0.12), (0.85, 0.24), (0.72, 0.31), (-0.85, 0.31)], 0.36, (0, 0, 0), "metal_gun", bev=0.025)
    rail(1.2, 0.0, 0.33)
    box((0.36, 0.13, 0.02), (0.22, 0.14, 0.185), "metal_black", bev=0.005, segs=1)
    extrude([(-0.36, -0.1), (-0.04, -0.1), (-0.18, -0.86), (-0.5, -0.86)], 0.3, (0, 0, 0), "polymer", bev=0.05)
    for i in range(5):
        box((0.3, 0.02, 0.31), (-0.28 - i * 0.03, -0.3 - i * 0.12, 0), "rubber", bev=0.005, segs=1, rot=(0, 0, -12))
    trigger_group()
    box((0.42, 0.08, 0.34), (0.38, -0.14, 0), "metal_dark", bev=0.015)
    cyl(0.04, 0.12, (-0.6, 0.22, 0.22), "metal_steel", axis="z", bev=0.01)
    for x in (-0.6, 0.5):
        cyl(0.025, 0.02, (x, 0.05, 0.185), "metal_brass", axis="z", verts=10, bev=0)


@weapon_part
def street_barrel():
    cyl(0.085, 1.35, (1.52, 0.12, 0), "metal_rust", axis="x", bev=0.01)
    cyl(0.12, 0.08, (2.16, 0.12, 0), "metal_dark", axis="x", bev=0.02)
    cyl(0.105, 0.28, (1.3, 0.12, 0), "tape", axis="x", bev=0.02)
    box((0.55, 0.28, 0.32), (1.12, 0.07, 0), "polymer", bev=0.06)
    for i in range(3):
        box((0.08, 0.04, 0.33), (0.95 + i * 0.16, -0.05, 0), "rubber", bev=0.01, segs=1)
    box((0.05, 0.15, 0.04), (2.02, 0.26, 0), "metal_black", bev=0.01, segs=1)


@weapon_part
def street_stock():
    tube([(-0.85, 0.22, 0), (-2.0, 0.13, 0)], 0.035, "metal_steel")
    tube([(-0.85, -0.05, 0), (-2.0, -0.32, 0)], 0.035, "metal_steel")
    tube([(-1.95, 0.13, 0), (-1.95, -0.3, 0)], 0.03, "metal_steel")
    box((0.12, 0.62, 0.3), (-2.03, -0.09, 0), "rubber", bev=0.045)
    for x in (-1.25, -1.6):
        cyl(0.06, 0.16, (x, 0.18 - (x + 0.85) * -0.08, 0), "tape", axis="x", bev=0.02)


@weapon_part
def street_sight():
    box((0.22, 0.08, 0.2), (-0.42, 0.4, 0), "metal_black", bev=0.015)
    for z in (-0.065, 0.065):
        box((0.06, 0.11, 0.05), (-0.42, 0.49, z), "metal_black", bev=0.01, segs=1)
    box((0.14, 0.07, 0.16), (0.5, 0.39, 0), "metal_black", bev=0.012)
    box((0.04, 0.12, 0.03), (0.5, 0.47, 0), "metal_black", bev=0.008, segs=1)


@weapon_part
def street_mag():
    extrude([(0.2, -0.12), (0.52, -0.12), (0.6, -0.95), (0.28, -0.95)], 0.26, (0, 0, 0), "metal_dark", bev=0.02)
    box((0.4, 0.08, 0.32), (0.45, -0.98, 0), "polymer", bev=0.025)
    for i in range(3):
        box((0.3, 0.02, 0.27), (0.39 + i * 0.03, -0.35 - i * 0.2, 0), "metal_black", bev=0.004, segs=1, rot=(0, 0, -6))


@weapon_part
def neon_body():
    extrude([(-0.85, -0.1), (0.85, -0.1), (0.92, 0.1), (0.76, 0.3), (-0.62, 0.3), (-0.85, 0.16)], 0.38, (0, 0, 0), "plastic_grey", bev=0.06, segs=3)
    extrude([(-0.34, -0.08), (-0.02, -0.08), (-0.12, -0.84), (-0.46, -0.8)], 0.32, (0, 0, 0), "polymer", bev=0.07)
    for z in (-0.195, 0.195):
        box((1.3, 0.03, 0.02), (0.02, 0.12, z), "neon_blue", bev=0.0)
    trigger_group("plastic_grey")
    box((0.4, 0.07, 0.36), (0.38, -0.13, 0), "metal_dark", bev=0.02)
    rail(1.0, -0.05, 0.33, "metal_dark")
    cyl(0.07, 0.03, (-0.5, 0.14, 0.2), "neon_blue", axis="z", bev=0.0)


@weapon_part
def neon_barrel():
    cyl(0.07, 1.4, (1.55, 0.1, 0), "metal_dark", axis="x", bev=0.01)
    cyl(0.16, 1.05, (1.4, 0.1, 0), "plastic_grey", axis="x", bev=0.05)
    for i in range(5):
        cyl(0.19, 0.04, (1.02 + i * 0.18, 0.1, 0), "metal_steel", axis="x", bev=0.01)
    cyl(0.13, 0.05, (2.05, 0.1, 0), "neon_blue", axis="x", bev=0.01)
    box((0.9, 0.02, 0.02), (1.4, 0.27, 0), "neon_blue", bev=0.0)


@weapon_part
def neon_stock():
    extrude([(-0.85, 0.25), (-1.95, 0.14), (-2.05, 0.02), (-2.05, -0.35), (-1.82, -0.42), (-1.3, -0.06), (-0.85, -0.04)], 0.28, (0, 0, 0), "plastic_grey", bev=0.06, segs=3)
    tube([(-0.95, 0.12, 0.15), (-1.9, 0.02, 0.15)], 0.015, "neon_blue")
    tube([(-0.95, 0.12, -0.15), (-1.9, 0.02, -0.15)], 0.015, "neon_blue")
    box((0.08, 0.52, 0.3), (-2.07, -0.16, 0), "rubber", bev=0.03)


@weapon_part
def neon_sight():
    box((0.38, 0.08, 0.22), (0.0, 0.4, 0), "metal_black", bev=0.015)
    for z in (-0.12, 0.12):
        box((0.06, 0.3, 0.035), (0.04, 0.56, z), "metal_black", bev=0.01)
    box((0.06, 0.035, 0.28), (0.04, 0.71, 0), "metal_black", bev=0.01)
    box((0.02, 0.26, 0.21), (0.06, 0.56, 0), "glass_dark", bev=0.0)
    cyl(0.018, 0.02, (0.08, 0.56, 0), "neon_red", axis="x", verts=12, bev=0)


@weapon_part
def neon_mag():
    cyl(0.14, 0.72, (0.38, -0.5, 0), "plastic_grey", bev=0.04)
    cyl(0.145, 0.34, (0.38, -0.5, 0), "neon_blue", bev=0.02)
    cyl(0.15, 0.06, (0.38, -0.88, 0), "metal_dark", bev=0.02)


@weapon_part
def ghost_body():
    extrude([(-0.85, -0.12), (0.85, -0.12), (0.85, 0.22), (0.56, 0.32), (-0.85, 0.32)], 0.34, (0, 0, 0), "metal_black", bev=0.015)
    extrude([(-0.34, -0.1), (-0.04, -0.1), (-0.16, -0.86), (-0.48, -0.84)], 0.3, (0, 0, 0), "polymer", bev=0.04)
    rail(1.3, 0.0, 0.34)
    for z in (-0.175, 0.175):
        box((0.9, 0.16, 0.01), (0.1, 0.08, z), "polymer_tan", bev=0.0)
    trigger_group()
    box((0.42, 0.08, 0.34), (0.38, -0.14, 0), "metal_black", bev=0.015)


@weapon_part
def ghost_barrel():
    cyl(0.07, 0.3, (1.0, 0.12, 0), "metal_black", axis="x", bev=0.01)
    cyl(0.15, 1.3, (1.72, 0.12, 0), "metal_black", axis="x", bev=0.04, verts=40)
    for x in (1.2, 2.25):
        cyl(0.158, 0.06, (x, 0.12, 0), "metal_gun", axis="x", bev=0.015, verts=40)


@weapon_part
def ghost_sight():
    for x in (-0.25, 0.25):
        box((0.12, 0.14, 0.2), (x, 0.44, 0), "metal_black", bev=0.02)
    cyl(0.1, 0.9, (0.0, 0.58, 0), "metal_black", axis="x", bev=0.02)
    lathe([(0.1, 0.0), (0.15, 0.18), (0.15, 0.28), (0.13, 0.3), (0.0, 0.3)], (0.42, 0.58, 0), "metal_black", axis="x", verts=32)
    cyl(0.12, 0.2, (-0.52, 0.58, 0), "rubber", axis="x", bev=0.04)
    cyl(0.125, 0.02, (0.71, 0.58, 0), "glass_dark", axis="x", bev=0.0)
    cyl(0.03, 0.02, (-0.1, 0.7, 0.0), "neon_red", axis="y", verts=12, bev=0)


@weapon_part
def drum_mag():
    box((0.26, 0.36, 0.24), (0.38, -0.28, 0), "metal_dark", bev=0.02)
    cyl(0.42, 0.34, (0.38, -0.72, 0), "metal_dark", axis="z", bev=0.05, verts=40)
    for z in (-0.17, 0.17):
        cyl(0.44, 0.04, (0.38, -0.72, z), "metal_black", axis="z", bev=0.01, verts=40)
    cyl(0.08, 0.1, (0.38, -0.72, 0.21), "metal_steel", axis="z", bev=0.02)
    box((0.3, 0.04, 0.03), (0.38, -0.72, 0.26), "metal_steel", bev=0.005, segs=1)


@weapon_part
def gold_stock():
    extrude([(-0.85, 0.24), (-2.1, 0.06), (-2.16, -0.02), (-2.16, -0.44), (-1.92, -0.5), (-1.25, -0.16), (-0.85, -0.08)], 0.3, (0, 0, 0), "metal_gold", bev=0.06, segs=3)
    box((0.7, 0.2, 0.32), (-1.55, 0.1, 0), "leather", bev=0.07)
    box((0.08, 0.56, 0.32), (-2.18, -0.22, 0), "metal_black", bev=0.03)
    for x in (-1.1, -1.9):
        cyl(0.03, 0.32, (x, -0.1, 0), "metal_brass", axis="z", verts=10, bev=0.01)
