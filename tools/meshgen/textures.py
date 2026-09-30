"""Procedural PBR textures (color / normal / roughness), perfectly tileable (FFT noise, toroidal
voronoi), following Roblox's guidance: tileable textures for large surfaces, <= 1024 px, OpenGL
tangent-space normal maps.

    python3 tools/meshgen/textures.py        # writes assets/textures/*.png + a contact sheet

They travel inside the FBX (one small "swatch" mesh per texture): after the import Studio has
uploaded them, and MapBuilder turns each swatch into a MaterialVariant applied to the whole city.
"""
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures")
N = 512

# name: (Roblox base material, studs per tile)
TEXTURES = {}


def texture(base_material, studs_per_tile):
    def deco(fn):
        TEXTURES[fn.__name__] = (fn, base_material, studs_per_tile)
        return fn

    return deco


# Noise ------------------------------------------------------------------------------------------------

def fbm(rng, beta=1.8, lo=1.0, hi=None, aniso=(1.0, 1.0), n=N):
    """Periodic fractal noise in 0..1. beta = spectral slope, lo/hi = frequency band (cycles per tile)."""
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[0]
    k = np.sqrt(fx * fx + fy * fy)
    amp = np.zeros_like(k)
    band = (k >= lo) & ((k <= hi) if hi else True)
    amp[band] = 1.0 / np.power(k[band], beta / 2 + 0.5)
    spec = amp * np.exp(2j * np.pi * rng.random((n, n)))
    img = np.real(np.fft.ifft2(spec))
    img -= img.min()
    return img / max(img.max(), 1e-9)


def voronoi(rng, count, n=N, jitter=None):
    """Toroidal voronoi: returns (F1, F2, cell id) with distances in tile units.
    With `jitter`, points sit on a jittered grid (count = side * side): even-sized cells."""
    if jitter is None:
        pts = rng.random((count, 2))
    else:
        side = int(round(math.sqrt(count)))
        gy, gx = np.mgrid[0:side, 0:side]
        pts = (np.stack([gx.ravel(), gy.ravel()], axis=1) + 0.5 + (rng.random((side * side, 2)) - 0.5) * jitter) / side % 1
    ys, xs = np.mgrid[0:n, 0:n] / n
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    cell = np.zeros((n, n), dtype=np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xs - px)
        dx = np.minimum(dx, 1 - dx)
        dy = np.abs(ys - py)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cell = np.where(closer, i, cell)
        f1 = np.where(closer, d, f1)
    return f1, f2, cell


def hexcolor(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)])


def tint(value, color):
    """value (n,n) 0..1 multiplies an RGB color -> (n,n,3)."""
    return value[..., None] * color[None, None, :]


def mix(a, b, t):
    t = t[..., None] if t.ndim == 2 else t
    return a * (1 - t) + b * t


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def normal_from_height(h, strength):
    """OpenGL tangent-space normal map (green = up), tileable."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * strength * N / 64
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * strength * N / 64
    nx, ny, nz = -dx, dy, np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length, ny / length, nz / length], axis=-1) * 0.5 + 0.5


def per_cell(ids, count, rng):
    """A random value per cell id."""
    return rng.random(count + 1)[ids]


# Textures (each returns color RGB 0..1, height 0..1, roughness 0..1, normal strength) ------------

@texture("Asphalt", 14)
def asphalt(rng):
    grain = fbm(rng, beta=0.6, lo=40)
    large = fbm(rng, beta=2.2, lo=1, hi=12)
    specks = smooth(fbm(rng, beta=0.2, lo=120), 0.72, 0.8)
    f1, f2, _ = voronoi(rng, 18)
    crack_line = 1 - smooth(f2 - f1, 0.0, 0.006)
    crack_mask = smooth(fbm(rng, beta=2.0, lo=1, hi=8), 0.62, 0.7)
    cracks = crack_line * crack_mask
    stains = smooth(fbm(rng, beta=2.4, lo=1, hi=10), 0.7, 0.85)
    v = 0.16 + grain * 0.06 + large * 0.05 + specks * 0.12 - cracks * 0.1 - stains * 0.05
    color = tint(v, hexcolor("#E8E6EA"))
    height = 0.5 + grain * 0.25 + specks * 0.2 - cracks * 0.8
    rough = 0.9 - specks * 0.2 + stains * -0.25
    return color, height, rough, 2.0


@texture("Pavement", 8)
def sidewalk(rng):
    ys, xs = np.mgrid[0:N, 0:N] / N
    slabs = 2
    gx = np.abs(((xs * slabs) % 1) - 0.5)
    gy = np.abs(((ys * slabs) % 1) - 0.5)
    groove = smooth(np.maximum(gx, gy), 0.488, 0.497)
    slab_id = (np.floor(xs * slabs) + np.floor(ys * slabs) * slabs).astype(int)
    slab_tone = per_cell(slab_id, slabs * slabs, rng) * 0.08
    grain = fbm(rng, beta=0.8, lo=30)
    mottling = fbm(rng, beta=2.0, lo=1, hi=16)
    gum = smooth(fbm(rng, beta=0.1, lo=150), 0.86, 0.9)
    stains = smooth(fbm(rng, beta=2.2, lo=2, hi=12), 0.68, 0.82)
    v = 0.5 + slab_tone + grain * 0.08 + mottling * 0.1 - groove * 0.25 - gum * 0.2 - stains * 0.12
    color = tint(v, hexcolor("#D6D2CC"))
    height = 0.6 + grain * 0.15 - groove * 0.6 + gum * 0.08
    rough = 0.85 - stains * 0.2
    return color, height, rough, 1.6


def brick_wall(rng, base, mortar_color, soot_amount):
    ys, xs = np.mgrid[0:N, 0:N] / N
    rows, per_row = 14, 4
    row = np.floor(ys * rows)
    offset = (row % 2) * 0.5 / per_row
    bx = (xs + offset) * per_row
    col = np.floor(bx) % per_row
    u = bx % 1
    v = (ys * rows) % 1
    mortar = np.maximum(smooth(np.abs(u - 0.5), 0.44, 0.47), smooth(np.abs(v - 0.5), 0.38, 0.43))
    brick_id = (row * per_row + col).astype(int)
    tone = per_cell(brick_id, rows * per_row, rng)
    hue = per_cell(brick_id, rows * per_row, rng)
    grain = fbm(rng, beta=0.7, lo=40)
    chips = smooth(fbm(rng, beta=0.5, lo=60), 0.78, 0.84) * (1 - mortar)
    soot = fbm(rng, beta=2.2, lo=1, hi=6) * soot_amount
    brick_col = base[None, None, :] * (0.72 + tone[..., None] * 0.45) + (hue[..., None] - 0.5) * np.array([0.06, 0.02, -0.02])
    brick_col = brick_col * (0.85 + grain[..., None] * 0.3)
    color = mix(brick_col, mortar_color[None, None, :] * (0.85 + grain[..., None] * 0.25), mortar)
    color = color * (1 - soot[..., None] * 0.5) * (1 - chips[..., None] * 0.25)
    height = (1 - mortar) * 0.7 + grain * 0.2 - chips * 0.3
    rough = 0.8 + mortar * 0.15
    return np.clip(color, 0, 1), height, rough, 2.4


@texture("Brick", 8)
def brick_red(rng):
    return brick_wall(rng, hexcolor("#8A4432"), hexcolor("#B8B0A2"), 0.5)


@texture("Brick", 8)
def brick_dark(rng):
    return brick_wall(rng, hexcolor("#4E423E"), hexcolor("#8A847A"), 0.7)


@texture("Concrete", 12)
def concrete(rng):
    ys, xs = np.mgrid[0:N, 0:N] / N
    grain = fbm(rng, beta=0.7, lo=40)
    mottling = fbm(rng, beta=2.1, lo=1, hi=12)
    streaks = fbm(rng, beta=1.4, lo=2, aniso=(1.0, 0.06))
    pores = smooth(fbm(rng, beta=0.1, lo=160), 0.8, 0.85)
    seams = np.maximum(smooth(np.abs(((xs * 2) % 1) - 0.5), 0.492, 0.498), smooth(np.abs(((ys * 2) % 1) - 0.5), 0.494, 0.499))
    v = 0.52 + grain * 0.08 + mottling * 0.12 - streaks * 0.16 - pores * 0.15 - seams * 0.12
    color = tint(v, hexcolor("#D0CEC8"))
    height = 0.5 + grain * 0.2 - pores * 0.4 - seams * 0.5
    rough = 0.88 - streaks * 0.1
    return color, height, rough, 1.4


@texture("Plaster", 8)
def plaster(rng):
    grain = fbm(rng, beta=1.0, lo=20)
    mottling = fbm(rng, beta=2.2, lo=1, hi=10)
    f1, f2, _ = voronoi(rng, 25)
    cracks = (1 - smooth(f2 - f1, 0.0, 0.002)) * smooth(fbm(rng, beta=2.0, lo=2, hi=8), 0.8, 0.84) * 0.6
    v = 0.82 + grain * 0.06 + mottling * 0.08 - cracks * 0.3
    color = tint(v, hexcolor("#F2EEE6"))
    height = 0.5 + grain * 0.3 - cracks * 0.6
    return color, height, 0.9 - grain * 0.05, 1.0


@texture("WoodPlanks", 8)
def siding(rng):
    ys, xs = np.mgrid[0:N, 0:N] / N
    boards = 10
    v = (ys * boards) % 1
    board_id = np.floor(ys * boards).astype(int)
    tone = per_cell(board_id, boards, rng)
    lip = smooth(v, 0.86, 0.97)
    grain = fbm(rng, beta=1.2, lo=4, aniso=(0.05, 1.0))
    chips = smooth(fbm(rng, beta=0.8, lo=30), 0.76, 0.8)
    paint = hexcolor("#E6E2DA") * 1.0
    wood = hexcolor("#6A5440")
    base = tint(0.86 + tone * 0.1 + grain * 0.06 - lip * 0.35, paint)
    color = mix(base, tint(0.7 + grain * 0.3, wood), chips)
    height = v * 0.8 - lip * 0.8 + grain * 0.1
    return np.clip(color, 0, 1), height, 0.75 + chips * 0.15, 2.2


@texture("RoofShingles", 8)
def shingles(rng):
    ys, xs = np.mgrid[0:N, 0:N] / N
    rows, tabs = 12, 6
    row = np.floor(ys * rows)
    bx = (xs + (row % 2) * 0.5 / tabs) * tabs
    tab_id = (row * tabs + np.floor(bx) % tabs).astype(int)
    u = bx % 1
    v = (ys * rows) % 1
    gap = smooth(np.abs(u - 0.5), 0.46, 0.49)
    edge = smooth(v, 0.82, 0.95)
    tone = per_cell(tab_id, rows * tabs, rng)
    granules = fbm(rng, beta=0.3, lo=90)
    moss = smooth(fbm(rng, beta=2.2, lo=1, hi=8), 0.72, 0.85)
    base = tint(0.3 + tone * 0.12 + granules * 0.12 - gap * 0.15 - edge * 0.12, hexcolor("#D8D2CC"))
    color = mix(base, tint(0.35 + granules * 0.1, hexcolor("#5A6A40")), moss * 0.5)
    height = v * 0.7 - edge * 0.6 - gap * 0.4 + granules * 0.15
    return np.clip(color, 0, 1), height, 0.92, 2.4


@texture("CorrodedMetal", 10)
def metal_corrugated(rng):
    ys, xs = np.mgrid[0:N, 0:N] / N
    ridges = 0.5 + 0.5 * np.sin(xs * 2 * np.pi * 16)
    rust = smooth(fbm(rng, beta=1.8, lo=1, hi=16, aniso=(1.0, 0.4)), 0.55, 0.75)
    streaks = fbm(rng, beta=1.2, lo=2, aniso=(1.0, 0.05))
    grain = fbm(rng, beta=0.5, lo=60)
    metal = tint(0.55 + ridges * 0.15 + grain * 0.08 - streaks * 0.12, hexcolor("#B8C0C8"))
    rusty = tint(0.45 + grain * 0.3, hexcolor("#9A5A34"))
    color = mix(metal, rusty, rust)
    height = ridges * 0.9 + grain * 0.05 - rust * 0.05
    rough = 0.45 + rust * 0.45
    return np.clip(color, 0, 1), height, rough, 3.0


@texture("Cobblestone", 8)
def cobblestone(rng):
    f1, f2, cell = voronoi(rng, 64, jitter=0.7)
    edge = f2 - f1
    grout = 1 - smooth(edge, 0.006, 0.014)
    dome = smooth(edge, 0.0, 0.05)
    tone = per_cell(cell, 64, rng)
    grain = fbm(rng, beta=0.8, lo=40)
    stone = tint(0.42 + tone * 0.2 + grain * 0.12, hexcolor("#C8C0B8"))
    color = mix(stone, tint(0.2 + grain * 0.1, hexcolor("#8A847A")), grout)
    height = dome * (1 - grout) + grain * 0.1
    return np.clip(color, 0, 1), height, 0.8 + grout * 0.15, 3.0


@texture("Ground", 14)
def dirt(rng):
    low = fbm(rng, beta=2.2, lo=1, hi=10)
    mid = fbm(rng, beta=1.2, lo=8)
    pebbles = smooth(fbm(rng, beta=0.3, lo=80), 0.74, 0.8)
    cracks = smooth(fbm(rng, beta=0.9, lo=12), 0.0, 0.25)
    v = 0.5 + low * 0.22 + mid * 0.16 + pebbles * 0.22 - (1 - cracks) * 0.12
    color = mix(tint(v, hexcolor("#A08466")), tint(v, hexcolor("#7A7266")), low)
    height = mid * 0.5 + pebbles * 0.5
    return np.clip(color, 0, 1), height, 0.95, 2.0


@texture("WoodPlanks", 8)
def planks(rng):
    ys, xs = np.mgrid[0:N, 0:N] / N
    boards = 8
    b = np.floor(ys * boards)
    joint_offset = per_cell(b.astype(int), boards, rng)
    u = (xs + joint_offset) % 1
    v = (ys * boards) % 1
    seams = np.maximum(smooth(np.abs(v - 0.5), 0.46, 0.49), smooth(np.abs(u - 0.5), 0.495, 0.499))
    tone = per_cell((b * 2 + np.floor((xs + joint_offset) % 1 * 2)).astype(int), boards * 2, rng)
    grain = fbm(rng, beta=1.4, lo=3, aniso=(0.04, 1.0))
    color = tint(0.45 + tone * 0.2 + grain * 0.2 - seams * 0.3, hexcolor("#A07850"))
    height = 0.7 - seams * 0.7 + grain * 0.1
    return np.clip(color, 0, 1), height, 0.7, 1.8


@texture("Metal", 6)
def painted_metal(rng):
    """Painted steel: flat paint, fine orange peel, scratches and chips showing darker metal."""
    peel = fbm(rng, beta=0.9, lo=50)
    wear = fbm(rng, beta=2.0, lo=1, hi=10)
    scratches = smooth(fbm(rng, beta=1.0, lo=6, aniso=(1.0, 0.03)), 0.8, 0.86)
    chips = smooth(fbm(rng, beta=0.6, lo=40), 0.8, 0.85) * smooth(wear, 0.5, 0.8)
    grime = smooth(fbm(rng, beta=1.6, lo=2, aniso=(1.0, 0.08)), 0.55, 0.9)
    v = 0.78 + peel * 0.06 - grime * 0.18 - scratches * 0.12
    color = mix(tint(v, hexcolor("#E6E6E6")), tint(0.35 + peel * 0.1, hexcolor("#9A9AA0")), chips)
    height = 0.6 + peel * 0.08 - chips * 0.5 - scratches * 0.2
    rough = 0.5 + grime * 0.3 - chips * 0.2
    return np.clip(color, 0, 1), height, rough, 1.2


@texture("Limestone", 10)
def stone(rng):
    """Cast stone trim: smooth blocks with thin joints, weathering streaks."""
    ys, xs = np.mgrid[0:N, 0:N] / N
    joints = np.maximum(smooth(np.abs(((xs * 2) % 1) - 0.5), 0.494, 0.499), smooth(np.abs(((ys * 4) % 1) - 0.5), 0.49, 0.498))
    grain = fbm(rng, beta=0.8, lo=40)
    mottling = fbm(rng, beta=2.2, lo=1, hi=10)
    streaks = fbm(rng, beta=1.3, lo=2, aniso=(1.0, 0.05))
    v = 0.72 + grain * 0.06 + mottling * 0.1 - streaks * 0.18 - joints * 0.2
    color = tint(v, hexcolor("#EAE4D8"))
    height = 0.55 + grain * 0.15 - joints * 0.6
    return np.clip(color, 0, 1), height, 0.85 - streaks * 0.1, 1.2


@texture("Fabric", 4)
def canvas(rng):
    """Woven canvas (awnings, tarps, fabric)."""
    ys, xs = np.mgrid[0:N, 0:N] / N
    weave = (0.5 + 0.5 * np.sin(xs * 2 * np.pi * 96)) * (0.5 + 0.5 * np.sin(ys * 2 * np.pi * 96))
    dirt = fbm(rng, beta=2.0, lo=1, hi=10)
    v = 0.75 + weave * 0.12 - dirt * 0.2
    color = tint(v, hexcolor("#E4E0D8"))
    return np.clip(color, 0, 1), weave * 0.5, 0.95, 1.0


@texture("CorrodedMetal", 6)
def rust(rng):
    """Heavy rust with flaking paint."""
    base = fbm(rng, beta=1.6, lo=1, hi=30)
    flakes = smooth(fbm(rng, beta=0.9, lo=12), 0.55, 0.65)
    pits = smooth(fbm(rng, beta=0.3, lo=90), 0.7, 0.78)
    rusty = mix(tint(0.4 + base * 0.3, hexcolor("#8A4A28")), tint(0.3 + base * 0.2, hexcolor("#5A3020")), pits)
    paint = tint(0.55 + base * 0.1, hexcolor("#6A6E72"))
    color = mix(rusty, paint, flakes * 0.6)
    height = 0.4 + flakes * 0.4 - pits * 0.3 + base * 0.1
    return np.clip(color, 0, 1), height, 0.9 - flakes * 0.2, 2.4


@texture("Wood", 6)
def wood_grain(rng):
    """Continuous wood grain (poles, frames, furniture): no board joints."""
    ys, xs = np.mgrid[0:N, 0:N] / N
    grain = fbm(rng, beta=1.5, lo=3, aniso=(0.03, 1.0))
    rings = 0.5 + 0.5 * np.sin((ys + grain * 0.08) * 2 * np.pi * 22)
    knots = smooth(fbm(rng, beta=0.6, lo=6), 0.83, 0.88)
    v = 0.55 + grain * 0.2 + rings * 0.1 - knots * 0.25
    color = tint(v, hexcolor("#A07850"))
    height = 0.5 + rings * 0.2 + grain * 0.1 - knots * 0.2
    return np.clip(color, 0, 1), height, 0.75, 1.4


@texture("Wood", 6)
def bark(rng):
    """Tree bark: deep vertical furrows."""
    ys, xs = np.mgrid[0:N, 0:N] / N
    furrows = fbm(rng, beta=1.2, lo=6, aniso=(1.0, 0.12))
    plates = smooth(furrows, 0.35, 0.6)
    moss = smooth(fbm(rng, beta=2.0, lo=1, hi=8), 0.7, 0.85)
    base = tint(0.35 + plates * 0.35, hexcolor("#8A7058"))
    color = mix(base, tint(np.full((N, N), 0.4), hexcolor("#4A5A30")), moss * 0.4)
    return np.clip(color, 0, 1), plates, 0.95, 3.0


# Photo scans ------------------------------------------------------------------------------------------
# CC0 scans pushed by the authors (tools/download_assets.ps1, docs/ASSETS.md) replace the procedural
# pattern of the same name when their folder is there: name -> (folder under assets/incoming, studs per
# tile at the scan's real size). The skins (skins.py) are recolored from these, like the patterns.
INCOMING = os.path.join(ROOT, "assets", "incoming")
SCANS = {
    "asphalt": ("polyhaven_textures/asphalt_02", 14),
    "sidewalk": ("polyhaven_textures/concrete_pavement_02", 10),
    "brick_red": ("polyhaven_textures/brick_wall_02", 6),
    "brick_dark": ("polyhaven_textures/brick_wall_09", 7),
    "concrete": ("polyhaven_textures/concrete_wall_007", 12),
    "plaster": ("polyhaven_textures/worn_plaster_wall", 8),
    "metal_corrugated": ("polyhaven_textures/rusty_corrugated_iron", 8),
    "cobblestone": ("polyhaven_textures/cobblestone_05", 8),
    "planks": ("polyhaven_textures/old_wood_floor", 8),
    "shingles": ("polyhaven_textures/roof_07", 8),
    "painted_metal": ("ambientcg/PaintedMetal006", 6),
    "rust": ("polyhaven_textures/rusty_metal_04", 6),
}
# which file of a scan folder is which map (Poly Haven: *_diff_* / *_nor_gl_* / *_rough_*;
# ambientCG: *_Color / *_NormalGL / *_Roughness)
SCAN_MAPS = {
    "color": ("_diff_", "_diffuse_", "_Color."),
    "normal": ("_nor_gl_", "_NormalGL."),
    "roughness": ("_rough_", "_Roughness."),
}


def scan_files(name):
    """{"color", "normal", "roughness"} -> file of the scan for this texture, or None if not all there."""
    if name not in SCANS:
        return None
    folder = os.path.join(INCOMING, SCANS[name][0])
    if not os.path.isdir(folder):
        return None
    found = {}
    for kind, marks in SCAN_MAPS.items():
        for f in sorted(os.listdir(folder)):
            if any(m in f for m in marks) and f.lower().endswith((".jpg", ".jpeg", ".png")):
                found[kind] = os.path.join(folder, f)
                break
    return found if len(found) == len(SCAN_MAPS) else None


def save_scan(name, files):
    os.makedirs(OUT, exist_ok=True)
    for kind, path in files.items():
        mode = "L" if kind == "roughness" else "RGB"
        img = Image.open(path).convert(mode).resize((N, N), Image.LANCZOS)
        img.save(os.path.join(OUT, f"{name}_{kind}.png"), optimize=True)


# a scanned texture tiles at the scan's real size
for _name, (_folder, _studs) in SCANS.items():
    if _name in TEXTURES and scan_files(_name):
        _fn, _base, _ = TEXTURES[_name]
        TEXTURES[_name] = (_fn, _base, _studs)


# Output ------------------------------------------------------------------------------------------------

def save(name, color, height, rough, strength):
    os.makedirs(OUT, exist_ok=True)
    rough = np.clip(rough if isinstance(rough, np.ndarray) else np.full((N, N), rough), 0, 1)
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, f"{name}_color.png"), optimize=True)
    normal = normal_from_height(np.clip(height, -2, 2), strength)
    Image.fromarray((normal * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, f"{name}_normal.png"), optimize=True)
    Image.fromarray((rough * 255).astype(np.uint8), "L").save(os.path.join(OUT, f"{name}_roughness.png"), optimize=True)


def build_all():
    for i, (name, (fn, _base, _studs)) in enumerate(TEXTURES.items()):
        files = scan_files(name)
        if files:
            save_scan(name, files)
            print(f"[textures] {name} (scan {SCANS[name][0]})")
            continue
        rng = np.random.default_rng(1000 + i)
        color, height, rough, strength = fn(rng)
        save(name, color, height, rough, strength)
        print(f"[textures] {name}")
    # contact sheet: each texture tiled 2x2 so seams would show
    names = list(TEXTURES)
    cols = 4
    rows = math.ceil(len(names) / cols)
    tile = 256
    sheet = Image.new("RGB", (cols * tile * 2, rows * tile * 2), (20, 20, 24))
    for i, name in enumerate(names):
        img = Image.open(os.path.join(OUT, f"{name}_color.png")).resize((tile, tile))
        x, y = (i % cols) * tile * 2, (i // cols) * tile * 2
        for dx in (0, tile):
            for dy in (0, tile):
                sheet.paste(img, (x + dx, y + dy))
    sheet.save(os.path.join(ROOT, "assets", "previews", "textures_sheet.png"))


if __name__ == "__main__":
    build_all()
