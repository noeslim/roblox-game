"""3D preview of Black Market City, rebuilt from the same data as the game (Lune dump of
Logic/CityLayout + Logic/CityParts) and the same mesh library. Renders a few shots with Cycles.

    lune run tools/dump_city && python3 tools/meshgen/city_preview.py
"""
import json
import math
import os
import sys

import bpy  # noqa: I001 (bpy must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import build  # noqa: E402
from lib import rb  # noqa: E402

OUT = os.path.join(ROOT, "docs", "img")

with open(os.path.join(HERE, "city_layout.json")) as f:
    DATA = json.load(f)
LAYOUT = DATA["layout"]
CFG = DATA["config"]

_mat_cache = {}


def part_material(material, color):
    key = (material, color)
    if key in _mat_cache:
        return _mat_cache[key]
    m = bpy.data.materials.new(f"{material}_{color}")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    col = build.hex_to_linear(color) + [1.0]
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.8
    if material in ("Metal", "DiamondPlate", "CorrodedMetal"):
        bsdf.inputs["Metallic"].default_value = 0.6
        bsdf.inputs["Roughness"].default_value = 0.5
    if material == "Neon":
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = 4
    if material == "Glass":
        bsdf.inputs["Roughness"].default_value = 0.05
    _mat_cache[key] = m
    return m


def wedge_mesh():
    """Roblox WedgePart of size 1: slope rises from the front (-Z) to the back (+Z)."""
    me = bpy.data.meshes.get("wedge")
    if me:
        return me
    bm = bmesh.new()
    # roblox corners (x, y, z) -> blender (x, -z, y)
    pts = {
        "bfl": (-0.5, -0.5, -0.5), "bfr": (0.5, -0.5, -0.5), "bbl": (-0.5, -0.5, 0.5), "bbr": (0.5, -0.5, 0.5),
        "tbl": (-0.5, 0.5, 0.5), "tbr": (0.5, 0.5, 0.5),
    }
    v = {k: bm.verts.new(rb(p)) for k, p in pts.items()}
    bm.faces.new((v["bfl"], v["bfr"], v["bbr"], v["bbl"]))
    bm.faces.new((v["bbl"], v["bbr"], v["tbr"], v["tbl"]))
    bm.faces.new((v["bfl"], v["tbl"], v["tbr"], v["bfr"]))
    bm.faces.new((v["bfl"], v["bbl"], v["tbl"]))
    bm.faces.new((v["bfr"], v["tbr"], v["bbr"]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("wedge")
    bm.to_mesh(me)
    bm.free()
    return me


def unit_mesh(shape):
    name = "unit_" + shape
    me = bpy.data.meshes.get(name)
    if me:
        return me
    bm = bmesh.new()
    if shape == "Cylinder":  # roblox cylinders run along X
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.5, radius2=0.5, depth=1.0)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    elif shape == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def roblox_matrix(x, y, z, rot_y=0.0, rot_z=0.0):
    # roblox rotY = blender rotZ; roblox rotZ = blender rotation about -Y
    return Matrix.Translation(rb((x, y, z))) @ Matrix.Rotation(math.radians(rot_y), 4, "Z") @ Matrix.Rotation(math.radians(-rot_z), 4, "Y")


def make_part(spec, base, collection, hidden=False):
    if spec.get("transparency", 0) >= 1 or hidden:
        return None
    shape = spec["shape"]
    me = wedge_mesh() if shape == "Wedge" else unit_mesh(shape)
    ob = bpy.data.objects.new(spec["name"], me)
    size = spec["size"]
    ob.matrix_world = (
        base
        @ roblox_matrix(spec["pos"]["x"], spec["pos"]["y"], spec["pos"]["z"], spec.get("rotY", 0), spec.get("rotZ", 0))
        @ Matrix.Diagonal((size["x"], size["z"], size["y"], 1.0))
    )
    ob.material_slots  # noqa: B018
    ob.data = me
    ob.active_material = part_material(spec["material"], spec["color"])
    ob.material_slots[0].link = "OBJECT"
    ob.material_slots[0].material = part_material(spec["material"], spec["color"])
    collection.objects.link(ob)
    return ob


LIBRARY = {}


def index_library(layout_offsets):
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH" and "__" in ob.name and ob.name != "__origin__":
            asset = ob.name.split("__")[0]
            LIBRARY.setdefault(asset, []).append(ob)
            ob.hide_render = True
            ob.hide_viewport = True
    return layout_offsets


def place_asset(name, base, offsets, collection):
    for ob in LIBRARY.get(name, []):
        inst = ob.copy()  # shares the mesh data
        inst.hide_render = False
        inst.hide_viewport = False
        inst.matrix_world = base @ Matrix.Translation(-rb(offsets[name]["offset"])) @ ob.matrix_world
        collection.objects.link(inst)


def build_city(offsets):
    col = bpy.data.collections.new("City")
    bpy.context.scene.collection.children.link(col)
    identity = Matrix.Identity(4)
    side = CFG["Grid"]["SidewalkHeight"]

    for spec in DATA["slabParts"]:
        make_part(spec, identity, col)
    for b in LAYOUT["buildings"]:
        a = CFG["Archetypes"][b["archetype"]]
        base = roblox_matrix(b["x"], side, b["z"], b["rot"])
        make_part({"name": "Body", "shape": "Block", "size": {"x": a["w"], "y": a["h"], "z": a["d"]}, "pos": {"x": 0, "y": a["h"] / 2, "z": 0}, "material": a["material"], "color": b["color"]}, base, col)
        place_asset("bld_" + b["archetype"], base, offsets, col)
        if b.get("sign"):
            make_part({"name": "Sign", "shape": "Block", "size": {"x": min(a["w"] * 0.6, 18), "y": 3, "z": 0.4}, "pos": {"x": 0, "y": 12, "z": a["d"] / 2 + 0.7}, "material": "Neon", "color": "#FF3FA4"}, base, col)
    B = CFG["Houses"]["BasementDepth"]
    for h, spec in zip(LAYOUT["houses"], DATA["houseParts"]):
        base = roblox_matrix(h["x"], side - B, h["z"])
        for p in spec["parts"]:
            make_part(p, base, col)
        place_asset("house_shack", base, offsets, col)
    for p in LAYOUT["props"]:
        ground = 0 if p["kind"] == "car" else side
        place_asset("prop_" + p["kind"], roblox_matrix(p["x"], ground + p.get("y", 0), p["z"], p["rot"]), offsets, col)
    meshes = {"fountain": "sp_fountain", "gas_station": "sp_gas_station", "control_point": "sp_control_point"}
    for s, parts in zip(LAYOUT["specials"], DATA["specialParts"]):
        if s["kind"] == "sea":
            make_part({"name": "Sea", "shape": "Block", "size": {"x": s["sx"], "y": 1, "z": s["sz"]}, "pos": {"x": 0, "y": -2.5, "z": 0}, "material": "Glass", "color": "#1E4A6A"}, roblox_matrix(s["x"], 0, s["z"]), col)
            continue
        base = roblox_matrix(s["x"], side, s["z"], s["rot"])
        for p in parts:
            make_part(p, base, col)
        if s["kind"] in meshes:
            place_asset(meshes[s["kind"]], base, offsets, col)
    return col


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.42, 0.5, 0.65, 1)
    bg.inputs["Strength"].default_value = 0.8
    scene.world = world
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.5
    sun_data.angle = math.radians(3)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.clip_end = 6000
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def shot(cam, name, eye, target, lens=35):
    cam.data.lens = lens
    cam.location = rb(eye)
    cam.rotation_euler = (rb(target) - rb(eye)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(OUT, f"city_{name}.png")
    bpy.ops.render.render(write_still=True)
    print(f"[preview] {name}")


def main():
    layout, groups, stats, mats = build.make_library()
    offsets = index_library(layout)
    build_city(offsets)
    cam = setup_render()
    os.makedirs(OUT, exist_ok=True)
    half = LAYOUT["half"]
    shot(cam, "overview", (half * 0.9, half * 1.05, half * 1.45), (0, 0, 60), lens=30)
    h = LAYOUT["houses"][1]
    shot(cam, "trap_houses", (h["x"] + 60, 16, h["z"] + 110), (h["x"] - 10, 14, h["z"]), lens=28)
    for p in LAYOUT["pois"]:
        if p["name"] == "Spawn":
            shot(cam, "downtown", (p["x"] + 140, 45, p["z"] + 160), (p["x"] - 40, 20, p["z"] - 60), lens=24)
        if p["name"] == "WarZone":
            shot(cam, "warzone", (p["x"] - 60, 160, p["z"] + 330), (p["x"], 0, p["z"]), lens=30)
    # basement cutaway: hide what build mode hides
    h = LAYOUT["houses"][0]
    base_y = CFG["Grid"]["SidewalkHeight"] - CFG["Houses"]["BasementDepth"]
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH" or ob.hide_render:
            continue
        loc = ob.matrix_world.translation
        near = abs(loc.x - h["x"]) < 40 and abs(loc.y + h["z"]) < 40
        if near and (loc.z > base_y + 12.5 or ob.name in ("BasementWallS", "BasementWallE")):
            ob.hide_render = True
    shot(cam, "basement", (h["x"] + 4, base_y + 60, h["z"] + 45), (h["x"] + 4, base_y, h["z"]), lens=24)


if __name__ == "__main__":
    main()
