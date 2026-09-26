"""Builds the Black Market mesh library.

    python3 tools/meshgen/build.py            # FBX + Luau config
    python3 tools/meshgen/build.py --render   # + preview images in assets/previews/

Outputs:
    assets/BlackMarketMeshes.fbx          import ONCE in Studio (see docs/SETUP_STUDIO.md)
    src/shared/Config/MeshLibrary.luau    offsets + materials used by ModelFactory
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import lib  # noqa: E402
from assets import BUILDABLES, WEAPON_PARTS  # noqa: E402
from materials import MATERIALS  # noqa: E402

FBX_PATH = os.path.join(ROOT, "assets", "BlackMarketMeshes.fbx")
LUAU_PATH = os.path.join(ROOT, "src", "shared", "Config", "MeshLibrary.luau")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")
SPACING = 14  # studs between models in the file (so they don't overlap in Studio)
PER_ROW = 6


def hex_to_linear(h):
    h = h.lstrip("#")
    rgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]


def make_materials():
    mats = {}
    for key, (_, color, rough, metal, emission, transparency) in MATERIALS.items():
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        col = hex_to_linear(color) + [1.0]
        bsdf.inputs["Base Color"].default_value = col
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emission:
            bsdf.inputs["Emission Color"].default_value = col
            bsdf.inputs["Emission Strength"].default_value = emission
        if transparency:
            bsdf.inputs["Transmission Weight"].default_value = transparency
        mats[key] = m
    return mats


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()

    layout = {}
    all_assets = [("buildable", n, f) for n, f in BUILDABLES] + [("weapon", n, f) for n, f in WEAPON_PARTS]
    for index, (kind, name, fn) in enumerate(all_assets):
        start = len(lib.PIECES)
        lib.begin_asset(name)
        fn()
        col, row = index % PER_ROW, index // PER_ROW
        offset = ((col + 1) * SPACING, 0.0, row * SPACING)  # roblox studs
        move = Matrix.Translation(lib.rb(offset))
        for ob in lib.PIECES[start:]:
            ob.matrix_world = move @ ob.matrix_world
        layout[name] = {"kind": kind, "offset": offset}

    # everything to plain meshes (applies bevels, curves...)
    select_only(lib.PIECES)
    bpy.ops.object.convert(target="MESH")

    groups = {}
    for ob in list(bpy.context.scene.objects):
        if "bm_asset" in ob:
            groups.setdefault((ob["bm_asset"], ob["bm_mat"]), []).append(ob)

    stats = {}
    for (asset, mat), objs in groups.items():
        select_only(objs)
        if len(objs) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        name = f"{asset}__{mat}"
        ob.name = name
        ob.data.name = name
        ob.data.materials.clear()
        ob.data.materials.append(mats[mat])
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
        ob.data.calc_loop_triangles()
        tris = len(ob.data.loop_triangles)
        stats[asset] = stats.get(asset, 0) + tris
        if tris > 20000:
            raise SystemExit(f"{name}: {tris} triangles (Roblox limit is 20000 per mesh)")

    # 1x1x1 stud reference cube at the origin: gives the runtime the position and scale
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    anchor = bpy.context.view_layer.objects.active
    anchor.name = "__origin__"
    anchor.data.materials.append(mats["plastic_grey"])

    os.makedirs(os.path.dirname(FBX_PATH), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=FBX_PATH,
        use_selection=False,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=True,
        mesh_smooth_type="OFF",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        path_mode="STRIP",
    )
    write_luau(layout, groups.keys())
    total = sum(stats.values())
    print(f"[meshgen] {len(layout)} models, {len(groups)} meshes, {total} triangles -> {FBX_PATH}")
    for asset in sorted(stats):
        print(f"  {asset:18s} {stats[asset]:6d} tris")
    return layout


def lua_str(s):
    return json.dumps(s)


def write_luau(layout, group_keys):
    lines = [
        "--!strict",
        "-- GENERATED by tools/meshgen/build.py - do not edit by hand, re-run the generator.",
        "-- Describes assets/BlackMarketMeshes.fbx once imported in Studio as",
        "-- ReplicatedStorage.Assets.BlackMarketMeshes (see docs/SETUP_STUDIO.md).",
        "-- Offsets are in studs, relative to the 1x1x1 \"__origin__\" cube of the file.",
        "",
        "local MeshLibrary = {}",
        "",
        "MeshLibrary.Models = {",
    ]
    for name, info in layout.items():
        x, y, z = info["offset"]
        mats = sorted(m for (a, m) in group_keys if a == name)
        mat_list = ", ".join(lua_str(m) for m in mats)
        lines.append(f"\t{name} = {{ kind = {lua_str(info['kind'])}, offset = {{ x = {x}, y = {y}, z = {z} }}, materials = {{ {mat_list} }} }},")
    lines += [
        "} :: { [string]: { kind: string, offset: { x: number, y: number, z: number }, materials: { string } } }",
        "",
        "-- material key -> how the MeshPart looks in Roblox",
        "MeshLibrary.Materials = {",
    ]
    for key, (rbx_mat, color, _r, _m, _e, transparency) in MATERIALS.items():
        lines.append(f"\t{key} = {{ material = {lua_str(rbx_mat)}, color = {lua_str(color)}, transparency = {transparency} }},")
    lines += [
        "} :: { [string]: { material: string, color: string, transparency: number } }",
        "",
        "return MeshLibrary",
        "",
    ]
    with open(LUAU_PATH, "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    layout = build()
    if "--render" in sys.argv:
        import render

        render.render_all(layout, PREVIEW_DIR)
