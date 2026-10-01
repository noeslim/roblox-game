"""Poly Haven models (CC0, assets/incoming/polyhaven_*, fetched by tools/download_assets.ps1) in the mesh
library: street props, facade details, trap house clutter and hideout furniture.

Each model listed in MODELS is imported once (glTF), reduced to its triangle budget (Decimate, so a
building can carry several copies under Roblox's 20000 triangles per mesh), scaled from meters to studs
and split per material into templates kept out of the scene. place() / face() / fit() add copies to the
asset being built, like kit.place().

Materials: every textured Poly Haven material becomes a key "ph_<name>" with its own maps (color,
OpenGL normal, roughness and metalness split out of the "arm" map), 512 px JPG in assets/textures/ph/
(ignored by git, rebuilt from assets/incoming). Glass and bulbs map to the library's plain keys.
Front of a model = Blender -Y = Roblox +Z, like our own models.
"""
import math
import os
import re

import bpy
from mathutils import Matrix, Vector
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
INCOMING = os.path.join(ROOT, "assets", "incoming")
TEX_OUT = os.path.join(ROOT, "assets", "textures", "ph")
SIZE = 512
STUDS_PER_M = 3.3

# name: (glTF folder under assets/incoming, objects kept (None = all), triangle budget)
MODELS = {
    # street
    "hydrant": ("polyhaven_hidden_alley/fire_hydrant", ["fire_hydrant", "fire_hydrant_cap_01", "fire_hydrant_cap_02", "fire_hydrant_cap_03", "fire_hydrant_chain"], 2400),
    "hydrant_aged": ("polyhaven_hidden_alley/fire_hydrant", ["fire_hydrant_aged", "fire_hydrant_cap_01_aged", "fire_hydrant_cap_02_aged", "fire_hydrant_cap_03_aged", "fire_hydrant_chain_aged"], 2400),
    # the lid leans against the can, as in the file
    "trash_can": ("polyhaven_hidden_alley/metal_trash_can", ["metal_trash_can", "metal_trash_can_handle_left", "metal_trash_can_handle_right", "metal_trash_can_lid"], 2400),
    "trash_can_rust": ("polyhaven_hidden_alley/metal_trash_can", ["metal_trash_can_rust", "metal_trash_can_rust_handle_left", "metal_trash_can_rust_handle_right", "metal_trash_can_rust_lid"], 2400),
    "barrier": ("polyhaven_hidden_alley/concrete_road_barrier_02", None, 1600),
    "utility_box": ("polyhaven_hidden_alley/utility_box_01", None, 1600),
    "utility_box_wide": ("polyhaven_hidden_alley/utility_box_02", None, 1800),
    "manhole": ("polyhaven_hidden_alley/water_manhole_cover", None, 900),
    "barrel_red": ("polyhaven_hidden_alley/Barrel_01", None, 900),
    "barrel_plastic": ("polyhaven_hidden_alley/Barrel_02", None, 900),
    "barrel_blue": ("polyhaven_hidden_alley/barrel_03", None, 900),
    "barrel_stove": ("polyhaven_hidden_alley/barrel_stove", None, 1600),
    "tyre": ("polyhaven_hidden_alley/old_tyre", None, 700),
    "rim": ("polyhaven_hidden_alley/rusted_wheel_rim_01", None, 800),
    "cardboard_box": ("polyhaven_hidden_alley/cardboard_box_01", None, 500),
    "crate": ("polyhaven_hidden_alley/wooden_crate_01", None, 1000),
    "crate_long": ("polyhaven_hidden_alley/wooden_crate_02", None, 1000),
    "covered_car": ("polyhaven_hidden_alley/covered_car", None, 5000),
    # facades
    "aircon": ("polyhaven_hidden_alley/exterior_aircon_unit", ["exterior_aircon_unit"], 1400),
    "aircon_rusted": ("polyhaven_hidden_alley/exterior_aircon_unit", ["exterior_aircon_unit_rusted"], 1400),
    "shutter": ("polyhaven_hidden_alley/rollershutter_window_01", ["rollershutter_window_01"], 560),
    "shutter_graffiti": ("polyhaven_hidden_alley/rollershutter_window_01", ["rollershutter_window_01_graffiti"], 560),
    "shutter_door": ("polyhaven_hidden_alley/rollershutter_door", ["rollershutter_door"], 560),
    "shutter_door_graffiti": ("polyhaven_hidden_alley/rollershutter_door", ["rollershutter_door_graffiti"], 560),
    "camera": ("polyhaven_hidden_alley/security_camera_01", None, 1200),
    "floodlight": ("polyhaven_hidden_alley/security_light", None, 1200),
    "wall_lantern": ("polyhaven_hidden_alley/street_lamp_02", None, 2500),
    # hideout
    "sofa": ("polyhaven_shed/sofa_02", None, 2800),
    "sofa_old": ("polyhaven_shed/Sofa_01", None, 3000),
    "armchair": ("polyhaven_shed/ArmChair_01", None, 3000),
    "plastic_chair": ("polyhaven_shed/plastic_monobloc_chair_01", None, 1500),
    "shelves": ("polyhaven_shed/steel_frame_shelves_02", None, 2500),
    "bookshelf": ("polyhaven_shed/wooden_bookshelf_worn", None, 2500),
    "tv": ("polyhaven_shed/Television_01", None, 1900),
    "cash_register": ("polyhaven_shed/CashRegister_01", None, 2500),
    "generator": ("polyhaven_shed/portable_generator", None, 3500),
    "propane": ("polyhaven_shed/propane_tank", None, 1200),
    "vice": ("polyhaven_shed/bench_vice_01", ["bench_vice_frame", "bench_vice_clamp", "bench_vice_dial", "bench_vice_bar"], 1500),
    "tool_chest": ("polyhaven_shed/metal_tool_chest", None, 2500),
    "drill": ("polyhaven_shed/Drill_01", None, 900),
    "crowbar": ("polyhaven_shed/crowbar_01", None, 500),
    "pipe_wrench": ("polyhaven_shed/pipe_wrench", None, 700),
    "bolt_cutters": ("polyhaven_shed/bolt_cutters_01", None, 800),
    "spray_cans": ("polyhaven_shed/spray_paint_bottles", None, 900),
    "fluorescent": ("polyhaven_shed/mounted_fluorescent_lights", ["mounted_fluorescent_lights_d"], 800),
    "hanging_light": ("polyhaven_shed/caged_hanging_light", None, 2500),
}

# material keys of the library for the untextured Poly Haven materials
PLAIN = [("glass", "window_glass"), ("bulb", "lamp_lens")]

TEXTURED = {}  # key -> {"maps": {kind: path}, "rough": float, "metal": float}
_PIECES = {}  # model name -> {"parts": [(key, mesh data)], "size": Vector (studs, Blender axes)}


def available():
    return os.path.isdir(os.path.join(INCOMING, "polyhaven_hidden_alley")) and os.path.isdir(os.path.join(INCOMING, "polyhaven_shed"))


def _gltf(folder):
    d = os.path.join(INCOMING, folder)
    for f in sorted(os.listdir(d)):
        if f.endswith(".gltf"):
            return os.path.join(d, f)
    raise FileNotFoundError(d)


def _base_name(mat):
    return re.sub(r"\.\d+$", "", mat.name)


def _linked(socket):
    return socket.links[0].from_node if socket.is_linked else None


def _image_of(node):
    """The image feeding a node, through Separate Color / Normal Map nodes."""
    while node is not None and node.type != "TEX_IMAGE":
        inputs = [i for i in node.inputs if i.is_linked]
        node = inputs[0].links[0].from_node if inputs else None
    return node.image if node is not None else None


def _channel(socket):
    """(image, channel index or None) feeding a scalar input."""
    node = _linked(socket)
    if node is None:
        return None, None
    channel = None
    if node.type in ("SEPRGB", "SEPARATE_COLOR", "SEPXYZ"):
        out = socket.links[0].from_socket.name
        channel = {"R": 0, "Red": 0, "G": 1, "Green": 1, "B": 2, "Blue": 2}.get(out)
    return _image_of(node), channel


def _save(img, path, kind, channel=None):
    src = Image.open(bpy.path.abspath(img.filepath))
    if channel is not None:
        src = src.convert("RGB").split()[channel]
    elif kind in ("roughness", "metalness"):
        src = src.convert("L")
    else:
        src = src.convert("RGB")
    src.resize((SIZE, SIZE), Image.LANCZOS).save(path, quality=88)


def _material_key(mat):
    """Library key of a Poly Haven material; textured ones get their maps written once."""
    name = _base_name(mat).lower()
    for word, key in PLAIN:
        if word in name:
            return key
    key = "ph_" + re.sub(r"[^a-z0-9]+", "_", name).strip("_")
    if key in TEXTURED:
        return key
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if mat.use_nodes else None
    if bsdf is None:
        return "metal_dark"
    os.makedirs(TEX_OUT, exist_ok=True)
    maps = {}
    color = _image_of(_linked(bsdf.inputs["Base Color"]))
    if color is None:
        return "metal_dark" if bsdf.inputs["Metallic"].default_value > 0.5 else "plastic_grey"
    maps["color"] = os.path.join(TEX_OUT, f"{key}_color.jpg")
    _save(color, maps["color"], "color")
    normal = _image_of(_linked(bsdf.inputs["Normal"]))
    if normal is not None:
        maps["normal"] = os.path.join(TEX_OUT, f"{key}_normal.jpg")
        _save(normal, maps["normal"], "normal")
    for kind, socket in (("roughness", "Roughness"), ("metalness", "Metallic")):
        img, ch = _channel(bsdf.inputs[socket])
        if img is not None:
            maps[kind] = os.path.join(TEX_OUT, f"{key}_{kind}.jpg")
            _save(img, maps[kind], kind, ch)
    TEXTURED[key] = {"maps": maps, "rough": bsdf.inputs["Roughness"].default_value, "metal": bsdf.inputs["Metallic"].default_value}
    return key


def _load(name):
    folder, keep, budget = MODELS[name]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=_gltf(folder))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH" and (keep is None or o.name.split(".")[0] in keep)]
    for o in meshes:  # world transform baked in, own data (the file is imported once per model)
        o.data = o.data.copy()
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
    total = 0
    for o in meshes:
        o.data.calc_loop_triangles()
        total += len(o.data.loop_triangles)
    ratio = min(1.0, budget / max(total, 1))
    import bmesh

    parts = []
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        if ratio < 0.999:
            mod = o.modifiers.new("decimate", "DECIMATE")
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            dg = bpy.context.evaluated_depsgraph_get()
            me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
            me.materials.clear()
            for m in o.data.materials:
                me.materials.append(m)
        else:
            me = o.data
        for v in me.vertices:
            lo = Vector(map(min, lo, v.co))
            hi = Vector(map(max, hi, v.co))
        for slot, mat in enumerate(me.materials):
            if mat is None:
                continue
            key = _material_key(mat)
            part = me.copy()
            bm = bmesh.new()
            bm.from_mesh(part)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != slot], context="FACES")
            bm.to_mesh(part)
            bm.free()
            if len(part.polygons):
                part.materials.clear()
                parts.append((key, part))
            else:
                bpy.data.meshes.remove(part)
    for o in new:
        bpy.data.objects.remove(o)
    # bottom center at the origin, meters -> studs
    shift = Matrix.Diagonal((STUDS_PER_M, STUDS_PER_M, STUDS_PER_M, 1)) @ Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for _key, me in parts:
        me.transform(shift)
    _PIECES[name] = {"parts": parts, "size": (hi - lo) * STUDS_PER_M}


def prepare():
    """Imports every model of MODELS (call before the library materials are made)."""
    if not available():
        return
    for name in MODELS:
        _load(name)
    print(f"[phaven] {len(MODELS)} models, {len(TEXTURED)} textured materials -> {TEX_OUT}")


def materials_table():
    """MATERIALS entries (materials.py format) for the textured keys."""
    return {key: ("Metal" if t["metal"] > 0.5 else "SmoothPlastic", "#FFFFFF", t["rough"], t["metal"], 0, 0) for key, t in TEXTURED.items()}


def material(key):
    """Principled material with the maps of a textured key (Studio makes a SurfaceAppearance)."""
    t = TEXTURED[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = t["rough"]
    bsdf.inputs["Metallic"].default_value = t["metal"]

    def image(kind, non_color):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(t["maps"][kind], check_existing=True)
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        return node

    links.new(image("color", False).outputs["Color"], bsdf.inputs["Base Color"])
    for kind, socket in (("roughness", "Roughness"), ("metalness", "Metallic")):
        if kind in t["maps"]:
            links.new(image(kind, True).outputs["Color"], bsdf.inputs[socket])
    if "normal" in t["maps"]:
        nmap = nodes.new("ShaderNodeNormalMap")
        links.new(image("normal", True).outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


# Placing ------------------------------------------------------------------------------------------

def has(name):
    return name in _PIECES


def size(name):
    """(width x, height y, depth z) in Roblox studs at scale 1."""
    s = _PIECES[name]["size"]
    return (s.x, s.z, s.y)


def place(name, pos, yaw=0.0, scale=1.0):
    """Adds model `name` to the current asset, bottom center at Roblox `pos`, turned by `yaw` degrees
    around the vertical (0 = facing +Z). scale: number or (sx, sy, sz) in the model's own axes."""
    from lib import PIECES, STATE, rb

    sx, sy, sz = scale if isinstance(scale, tuple) else (scale, scale, scale)
    matrix = Matrix.Translation(rb(pos)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Diagonal((sx, sz, sy, 1))
    for key, me in _PIECES[name]["parts"]:
        ob = bpy.data.objects.new(f"{name}:{key}", me.copy())
        ob.matrix_world = matrix
        bpy.context.scene.collection.objects.link(ob)
        ob["bm_asset"] = STATE["asset"]
        ob["bm_mat"] = key
        PIECES.append(ob)


FACE_YAW = {"front": 0.0, "back": 180.0, "right": 90.0, "left": -90.0}


def face(name, face_name, point, scale=1.0, gap=0.05):
    """Hangs `name` on a building face: `point` = Roblox point on the wall (from _face_point with out=0),
    the model's back against the wall, facing out."""
    w, h, d = size(name)
    s = scale if isinstance(scale, tuple) else (scale, scale, scale)
    out = d * s[2] / 2 + gap
    dx, dz = {"front": (0, out), "back": (0, -out), "right": (out, 0), "left": (-out, 0)}[face_name]
    place(name, (point[0] + dx, point[1], point[2] + dz), FACE_YAW[face_name], scale)


def fit(name, box_size, bottom_center, yaw=0.0, stretch=False):
    """Scales `name` to fit inside box_size (studs, Roblox x / y / z of the unturned model): uniformly,
    or each axis separately with stretch=True."""
    w, h, d = size(name)
    bx, by, bz = box_size
    if stretch:
        scale = (bx / w, by / h, bz / d)
    else:
        k = min(bx / w, by / h, bz / d)
        scale = (k, k, k)
    place(name, bottom_center, yaw, scale)
