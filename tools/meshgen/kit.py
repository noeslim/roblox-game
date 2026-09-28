"""Quaternius "Downtown City MegaKit" (CC0) in the mesh library: its facade modules are assembled
around our building boxes (Config/City archetypes), just outside the part walls MapBuilder builds
(they keep the collisions, the door hole and the interior). Output assets are ordinary library
models ("bld_shop_k", "bld_apartment_l"...), picked as variants by MapBuilder.

Kit conventions (Blender, after the glTF import): modules are 2 or 4 m wide along X (centered),
3 m high along Z (a floor), 0.2 m thick along Y with the outside facing -Y.
Kit materials map to our material keys (materials.py, "kit_*"); their textures are resized to
1024 px, the ORM maps are split into roughness and metalness (what Roblox reads), the color variants
the export lost (pale brick, dark / green trim) are baked by tinting.
"""
import math
import os
import random

import bpy
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
KIT_DIR = os.path.join(ROOT, "assets", "incoming", "downtown_megakit", "glTF (Godot)")
TEX_OUT = os.path.join(ROOT, "assets", "textures", "kit")
SIZE = 1024

# kit material -> our key (None = dropped: faces hidden against our walls, roofs, floors)
KEYS = {
    "MI_RedBrick": "kit_brick",
    "MI_RedBrick_Pale": "kit_brick_pale",
    "MI_Trim": "kit_trim",
    "MI_Trim_Dark": "kit_trim_dark",
    "MI_Trim_Green": "kit_trim_green",
    "MI_Trim_MetalConcrete": "kit_metal",
    "MI_Ornaments": "kit_ornaments",
    "MI_Roof_Slate": "kit_slate",
    "MI_Concrete": "kit_concrete",
    "MI_Glass": "kit_glass",
    "MI_FakeInterior": "interior",
    "MI_FakeInterior_1": "interior",
    "MI_FakeInterior_2": "interior",
    "MI_FakeInterior_3": "interior",
    "MI_FakeInterior_4": "interior",
    "MI_InteriorWall": None,
    "MI_InteriorFloor": None,
    "MI_InteriorRoof": None,
    "MI_Asphalt": None,
    "MI_Dirt": "soil",
    "MI_StreetDecals": None,
}

# our textured kit keys: (texture set, tint or None)
TEXTURES = {
    "kit_brick": ("T_RedBrick", None),
    "kit_brick_pale": ("T_RedBrick", "#C9A596"),
    "kit_trim": ("T_Trim", None),
    "kit_trim_dark": ("T_Trim", "#3A3A40"),
    "kit_trim_green": ("T_Trim", "#3C6A52"),
    "kit_metal": ("T_MetalConcrete", None),
    "kit_ornaments": ("T_Ornaments", None),
    "kit_slate": ("T_RoofSlate", None),
    "kit_concrete": ("T_Concrete", None),
}

LIT_CHANCE = 0.3  # window interiors lit (glow at night, material "window_lit")


def available():
    return os.path.isdir(KIT_DIR)


# Textures ------------------------------------------------------------------------------------------

def tex_path(key, kind):
    return os.path.join(TEX_OUT, f"{key}_{kind}.png")


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)])


def prepare_textures():
    """1024 px maps per textured key: color (tinted if asked), normal, roughness, metalness."""
    os.makedirs(TEX_OUT, exist_ok=True)
    for key, (base, tint) in TEXTURES.items():
        if os.path.exists(tex_path(key, "metalness")):
            continue
        color = Image.open(os.path.join(KIT_DIR, f"{base}_BaseColor.png")).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        if tint:
            arr = np.asarray(color) / 255
            lum = arr @ np.array([0.2126, 0.7152, 0.0722])
            detail = lum / max(lum.mean(), 1e-6)
            arr = np.clip(detail[..., None] * _hex(tint)[None, None, :], 0, 1)
            color = Image.fromarray((arr * 255).astype(np.uint8), "RGB")
        color.save(tex_path(key, "color"), optimize=True)
        Image.open(os.path.join(KIT_DIR, f"{base}_Normal.png")).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(tex_path(key, "normal"), optimize=True)
        orm = Image.open(os.path.join(KIT_DIR, f"{base}_ORM.png")).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        _o, r, m = orm.split()
        r.save(tex_path(key, "roughness"), optimize=True)
        m.save(tex_path(key, "metalness"), optimize=True)
    print(f"[kit] {len(TEXTURES)} texture sets -> {TEX_OUT}")


def material(key, metal):
    """Principled material of a textured kit key (the importer reads color, normal, roughness and
    metalness and makes a SurfaceAppearance)."""
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]

    def image(kind, non_color):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(tex_path(key, kind), check_existing=True)
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        return node

    links.new(image("color", False).outputs["Color"], bsdf.inputs["Base Color"])
    links.new(image("roughness", True).outputs["Color"], bsdf.inputs["Roughness"])
    links.new(image("metalness", True).outputs["Color"], bsdf.inputs["Metallic"])
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(image("normal", True).outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


# Pieces --------------------------------------------------------------------------------------------

_PIECES = {}  # name -> {"parts": [(key, template object)], "min": Vector, "max": Vector}


def piece(name):
    """The kit module `name`, split per material key, faces we never see removed. Templates stay out
    of the scene (not exported); placements are linked copies."""
    if name in _PIECES:
        return _PIECES[name]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(KIT_DIR, name + ".gltf"))
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for o in new:  # bake the world transform before the parents (empties) go
        o.data = o.data.copy()
        o.data.transform(o.matrix_world)
    for o in [o for o in bpy.data.objects if o not in before and o.type != "MESH"]:
        bpy.data.objects.remove(o)
    parts = []
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in new:
        for v in o.data.vertices:
            lo = Vector(map(min, lo, v.co))
            hi = Vector(map(max, hi, v.co))
        # one template per kit material slot
        for slot, mat in enumerate(o.data.materials):
            key = KEYS.get(mat.name.split(".")[0] if mat else "", None)
            if key is None:
                continue
            me = o.data.copy()
            import bmesh

            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != slot], context="FACES")
            bm.to_mesh(me)
            bm.free()
            if len(me.polygons) == 0:
                bpy.data.meshes.remove(me)
                continue
            me.materials.clear()
            t = bpy.data.objects.new(f"{name}:{key}", me)
            parts.append((key, t))
        for c in list(o.users_collection):
            c.objects.unlink(o)
    _PIECES[name] = {"parts": parts, "min": lo, "max": hi}
    return _PIECES[name]


def place(name, matrix, rng):
    """Adds a copy of kit module `name` to the current asset, transformed by `matrix` (Blender)."""
    from lib import PIECES, STATE

    p = piece(name)
    lit = rng.random() < LIT_CHANCE
    for key, t in p["parts"]:
        if key == "kit_glass" and name.startswith("DoorFrame"):
            continue  # the doorway stays open (MapBuilder puts a door that opens there)
        if key == "interior":
            key = "window_lit" if lit else "kit_interior"
        ob = bpy.data.objects.new(t.name, t.data)
        ob.matrix_world = matrix
        bpy.context.scene.collection.objects.link(ob)
        ob["bm_asset"] = STATE["asset"]
        ob["bm_mat"] = key
        PIECES.append(ob)


# Facades -------------------------------------------------------------------------------------------

def _faces(W, D):
    """(name, blender frame of the wall plane, length). Our models: front = Roblox +Z = Blender -Y."""
    return [
        ("front", Matrix.Translation((0, -D / 2, 0)), W),
        ("back", Matrix.Translation((0, D / 2, 0)) @ Matrix.Rotation(math.pi, 4, "Z"), W),
        ("right", Matrix.Translation((W / 2, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"), D),
        ("left", Matrix.Translation((-W / 2, 0, 0)) @ Matrix.Rotation(-math.pi / 2, 4, "Z"), D),
    ]


def _module(frame, name, u, width, z, sz, depth_scale):
    """Matrix placing module `name` centered at u along the wall, bottom at z, stretched to `width`
    studs, its back against the wall plane (it hangs outside)."""
    p = piece(name)
    size = p["max"] - p["min"]
    cx = (p["min"].x + p["max"].x) / 2
    sx = width / max(size.x, 1e-6)
    return frame @ Matrix.Translation((u, 0, z)) @ Matrix.Diagonal((sx, depth_scale, sz, 1)) @ Matrix.Translation((-cx, -p["max"].y, -p["min"].z))


def _fill(a, b, module_width):
    """Centers and width of the modules filling [a, b] with modules close to module_width."""
    length = b - a
    if length < module_width * 0.35:
        return []
    n = max(1, round(length / module_width))
    w = length / n
    return [(a + w * (i + 0.5), w) for i in range(n)]


def facade(W, D, H, rows, door, style, rng, studs_per_m=3.3):
    """rows: bottom to top, [(height in meters, {face: [module names cycled]} or a name)].
    door: {"x", "w", "h"} of the front door (its module goes there on the ground row)."""
    total_m = sum(h for h, _ in rows)
    sz = H / total_m  # studs per meter, vertically
    module = 2 * studs_per_m
    depth = studs_per_m * 0.8
    z = 0.0
    for r, (h, spec) in enumerate(rows):
        for face, frame, length in _faces(W, D):
            names = spec if isinstance(spec, list) else (spec.get(face) or spec.get("sides"))
            if isinstance(names, str):
                names = [names]
            spans = [(-length / 2, length / 2)]
            if r == 0 and face == "front" and door:
                dw = door["w"] + 2.0
                spans = [(-length / 2, door["x"] - dw / 2), (door["x"] + dw / 2, length / 2)]
                place(style["door"], _module(frame, style["door"], door["x"], dw, z, sz, depth), rng)
            k = 0
            for a, b in spans:
                for u, w in _fill(a, b, module):
                    name = names[k % len(names)]
                    k += 1
                    place(name, _module(frame, name, u, w, z, sz, depth), rng)
        # corner columns hide the joints between faces
        if style.get("corner") and h >= 2:
            p = piece(style["corner"])
            c = (p["min"] + p["max"]) / 2
            stretch = h * sz / max(p["max"].z - p["min"].z, 1e-6)  # the column spans the row
            for sx in (-1, 1):
                for sy in (-1, 1):
                    m = Matrix.Translation((sx * W / 2, sy * D / 2, z)) @ Matrix.Diagonal((studs_per_m, studs_per_m, stretch, 1)) @ Matrix.Translation((-c.x, -c.y, -p["min"].z))
                    place(style["corner"], m, rng)
        z += h * sz


STYLES = {
    # red brick walls, metal shop front
    "k": {
        "door": "DoorFrame_Metal_Single",
        "corner": "Brick_Column_TrimBricks",
        "shop_ground": {"front": ["Metal_FirstFloor_Window"], "sides": ["Brick_BottomTrim", "Brick_BottomTrim", "Metal_FirstFloor_Wall"]},
        "home_ground": {"front": ["Brick_Window_Trim_Single", "Brick_Plain_3"], "sides": ["Brick_BottomTrim"]},
        "upper": {"front": ["Brick_Window_Trim_Single", "Brick_Window_Trim"], "sides": ["Brick_Plain_3", "Brick_Window_Square_Single"]},
        "cornice": {"front": "Cornice_Trim_Center", "sides": "Cornice_Brick_Center"},
    },
    # pale brick, green trim shop front, curved windows
    "l": {
        "door": "DoorFrame_Trim",
        "corner": "Trim_Column_Center",
        "shop_ground": {"front": ["Trim_FirstFloor_Window_001"], "sides": ["Trim_FirstFloor_Wall", "Trim_Plain_3"]},
        "home_ground": {"front": ["Trim_Window", "Trim_Plain_3"], "sides": ["Trim_FirstFloor_Wall"]},
        "upper": {"front": ["Brick_Window_Square_Single", "Brick_Window_Trim_Single"], "sides": ["Brick_Plain_3", "Brick_Window_Square_Single", "Brick_Plain_3"]},
        "cornice": {"front": "Cornice_Trim_Center", "sides": "Cornice_Trim_Center"},
    },
}


def building(archetype, arch, style_id, kind, floors):
    """A whole facade for one archetype. kind: "shop" (shop front) or "home" (windows + door)."""
    rng = random.Random(f"{archetype}/{style_id}")
    s = STYLES[style_id]
    rows = [(3, s[kind + "_ground"])] + [(3, s["upper"])] * (floors - 1) + [(1, s["cornice"])]
    facade(arch["w"], arch["d"], arch["h"], rows, arch["door"], s, rng)
