"""Textures of the library meshes ("skins"). Each textured material key of materials.py gets its own
color map (a pattern from textures.py recolored to the key's color) and shares the pattern's normal
and roughness maps. The meshes get UVs in studs (box projection, uv.py), so one tile of texture covers
`studs` studs on every face, whatever the mesh. Studio's importer uploads the maps and gives each mesh
a SurfaceAppearance; ModelFactory keeps it.

    python3 tools/meshgen/skins.py      # writes assets/textures/skins/*.png (build.py calls it too)

Material keys left out stay plain (Roblox material + color): glass, neon, plastic, and the keys the
game recolors at run time (awning, car_paint, container_paint, lit windows, lamps, signals).
"""
import os

import numpy as np
from PIL import Image

from textures import OUT as PATTERNS

OUT = os.path.join(PATTERNS, "skins")

# material key: (pattern, studs per tile, tint or None to keep the pattern's own colors)
SKINS = {
    "brick_red": ("brick_red", 6, None),
    "concrete": ("concrete", 12, "#8A8A8C"),
    "trim_light": ("stone", 10, "#C8C0B0"),
    "trim_dark": ("painted_metal", 6, "#34343A"),
    "metal_dark": ("painted_metal", 6, "#303238"),
    "metal_black": ("painted_metal", 6, "#1C1D22"),
    "paint_green": ("painted_metal", 6, "#2F4F3A"),
    "paint_red": ("painted_metal", 6, "#7A1F1F"),
    "metal_rust": ("rust", 6, None),
    "wood_dark": ("wood_grain", 6, "#3B2616"),
    "wood_mid": ("planks", 8, "#7A5634"),
    "wood_crate": ("planks", 6, "#8A6238"),
    "wood_worn": ("planks", 8, "#5A4632"),
    "wood_pole": ("wood_grain", 6, "#4A3A2C"),
    "bark": ("bark", 6, None),
    "roof_green": ("shingles", 8, "#2E5A45"),
    "plaster_white": ("plaster", 8, "#E8E2D6"),
    "siding": ("siding", 8, "#8A9AA2"),
    "fabric_dark": ("canvas", 4, "#23222A"),
    "fabric_purple": ("canvas", 4, "#3D2570"),
    "leather": ("canvas", 3, "#3A2418"),
    # building door leaves (own meshes, replaced by opening doors in game)
    "door_wood": ("wood_grain", 6, "#3B2616"),
    "door_metal": ("painted_metal", 6, "#2B2D33"),
}


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)])


def color_path(key):
    return os.path.join(OUT, f"{key}_color.png")


def pattern_path(key, kind):
    return os.path.join(PATTERNS, f"{SKINS[key][0]}_{kind}.png")


def build_all():
    os.makedirs(OUT, exist_ok=True)
    for key, (pattern, _studs, tint) in SKINS.items():
        img = np.asarray(Image.open(os.path.join(PATTERNS, f"{pattern}_color.png")).convert("RGB")) / 255
        if tint:
            # keep the pattern's detail (luminance around its mean), take the key's color
            lum = img @ np.array([0.2126, 0.7152, 0.0722])
            detail = lum / max(lum.mean(), 1e-6)
            img = np.clip(detail[..., None] * hex_rgb(tint)[None, None, :], 0, 1)
        Image.fromarray((img * 255).astype(np.uint8), "RGB").save(color_path(key), optimize=True)
    print(f"[skins] {len(SKINS)} color maps -> {OUT}")


if __name__ == "__main__":
    build_all()
