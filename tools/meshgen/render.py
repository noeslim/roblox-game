"""Preview renders of the mesh library (Cycles CPU) + a contact sheet."""
import math
import os

import bpy
from mathutils import Vector

import lib

TILE_W, TILE_H = 420, 320


def _setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.resolution_x = TILE_W
    scene.render.resolution_y = TILE_H
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.09, 0.09, 0.12, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    scene.view_settings.view_transform = "AgX"

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def light(name, kind, energy, color, size):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        data.color = color
        if kind == "AREA":
            data.size = size
        ob = bpy.data.objects.new(name, data)
        scene.collection.objects.link(ob)
        return ob

    key = light("Key", "AREA", 900, (1.0, 0.92, 0.85), 6)
    rim = light("Rim", "AREA", 700, (0.55, 0.45, 1.0), 5)
    fill = light("Fill", "AREA", 250, (0.6, 0.8, 1.0), 8)
    floor_mesh = bpy.data.meshes.new("Floor")
    floor = bpy.data.objects.new("Floor", floor_mesh)
    scene.collection.objects.link(floor)
    import bmesh

    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=400)
    bm.to_mesh(floor_mesh)
    bm.free()
    fm = bpy.data.materials.new("FloorMat")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.06, 0.06, 0.07, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.35
    floor_mesh.materials.append(fm)
    return cam, key, rim, fill, floor


def _asset_objects(name):
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(name + "__")]


def _bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


COMBOS = {
    "combo_street": ["street_body", "street_barrel", "street_stock", "street_sight", "street_mag"],
    "combo_neon": ["neon_body", "neon_barrel", "neon_stock", "neon_sight", "neon_mag"],
    "combo_ghost": ["ghost_body", "ghost_barrel", "gold_stock", "ghost_sight", "drum_mag"],
}


def _shift(objs, delta):
    for o in objs:
        o.matrix_world.translation += delta


def render_all(layout, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    cam, key, rim, fill, floor = _setup_scene()
    anchor = bpy.context.scene.objects.get("__origin__")
    if anchor:
        anchor.hide_render = True
    all_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and "__" in o.name and o.name != "__origin__"]
    tiles = []
    for name, info in layout.items():
        objs = _asset_objects(name)
        if not objs:
            continue
        for o in all_meshes:
            o.hide_render = o not in objs
        lo, hi = _bounds(objs)
        center = (lo + hi) / 2
        radius = max((hi - lo).length / 2, 0.5)
        floor.location = (center.x, center.y, lo.z - 0.001)
        # camera in front (-Y in Blender = +Z Roblox = customer side), a bit to the right and above
        direction = Vector((0.55, -1.0, 0.45)).normalized()
        cam.location = center + direction * radius * 3.2
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        key.location = center + Vector((-3, -4, 5)) * radius
        key.rotation_euler = (center - key.location).to_track_quat("-Z", "Y").to_euler()
        rim.location = center + Vector((4, 4, 3)) * radius
        rim.rotation_euler = (center - rim.location).to_track_quat("-Z", "Y").to_euler()
        fill.location = center + Vector((4, -3, 1)) * radius
        fill.rotation_euler = (center - fill.location).to_track_quat("-Z", "Y").to_euler()
        for l, e in ((key, 260), (rim, 160), (fill, 90)):
            l.data.energy = e * radius * radius
        path = os.path.join(out_dir, f"{name}.png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append((name, path))
        print(f"[render] {name}")
    # assembled weapons: bring the parts of a combo back to weapon space
    for combo, parts in COMBOS.items():
        moved = []
        for part in parts:
            objs = _asset_objects(part)
            delta = -lib.rb(layout[part]["offset"])
            _shift(objs, delta)
            moved.append((objs, delta))
        shown = [o for objs, _ in moved for o in objs]
        for o in all_meshes:
            o.hide_render = o not in shown
        lo, hi = _bounds(shown)
        center = (lo + hi) / 2
        radius = (hi - lo).length / 2
        floor.location = (center.x, center.y, lo.z - 0.001)
        cam.location = center + Vector((0.25, -1.0, 0.3)).normalized() * radius * 2.6
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        for l, offs, e in ((key, (-3, -4, 5), 260), (rim, (4, 4, 3), 160), (fill, (4, -3, 1), 90)):
            l.location = center + Vector(offs) * radius
            l.rotation_euler = (center - l.location).to_track_quat("-Z", "Y").to_euler()
            l.data.energy = e * radius * radius
        path = os.path.join(out_dir, f"{combo}.png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.insert(0, (combo, path))
        for objs, delta in moved:
            _shift(objs, -delta)
        print(f"[render] {combo}")
    _contact_sheet(tiles, os.path.join(out_dir, "_all.png"))


def _contact_sheet(tiles, path, cols=4):
    rows = math.ceil(len(tiles) / cols)
    sheet = bpy.data.images.new("sheet", TILE_W * cols, TILE_H * rows)
    pixels = [0.02, 0.02, 0.03, 1.0] * (TILE_W * cols * TILE_H * rows)
    for i, (_, tile_path) in enumerate(tiles):
        img = bpy.data.images.load(tile_path)
        src = list(img.pixels)
        col, row = i % cols, rows - 1 - i // cols
        for y in range(TILE_H):
            dst_start = ((row * TILE_H + y) * TILE_W * cols + col * TILE_W) * 4
            src_start = y * TILE_W * 4
            pixels[dst_start : dst_start + TILE_W * 4] = src[src_start : src_start + TILE_W * 4]
    sheet.pixels = pixels
    sheet.filepath_raw = path
    sheet.file_format = "PNG"
    sheet.save()
