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
import kit  # noqa: E402
import skins  # noqa: E402
import uv  # noqa: E402
from assets import BUILDABLES, WEAPON_PARTS  # noqa: E402
from city_assets import CITY_ASSETS  # noqa: E402
from materials import MATERIALS  # noqa: E402
from textures import OUT as TEXTURE_DIR  # noqa: E402
from textures import TEXTURES  # noqa: E402

FBX_PATH = os.path.join(ROOT, "assets", "BlackMarketMeshes.fbx")
LUAU_PATH = os.path.join(ROOT, "src", "shared", "Config", "MeshLibrary.luau")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")
SPACING = 14  # studs between models in the file (so they don't overlap in Studio)
PER_ROW = 6


def hex_to_linear(h):
    h = h.lstrip("#")
    rgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]


def skin_material(key):
    """UV-mapped PBR material of a textured key: Studio's importer uploads the maps and makes a
    SurfaceAppearance for every mesh using it."""
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    _rbx, _color, _rough, metal, _e, _t = MATERIALS[key]
    bsdf.inputs["Metallic"].default_value = metal

    def image(path, non_color):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(path, check_existing=True)
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        return node

    links.new(image(skins.color_path(key), False).outputs["Color"], bsdf.inputs["Base Color"])
    links.new(image(skins.pattern_path(key, "roughness"), True).outputs["Color"], bsdf.inputs["Roughness"])
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(image(skins.pattern_path(key, "normal"), True).outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def make_materials():
    mats = {}
    for key, (_, color, rough, metal, emission, transparency) in MATERIALS.items():
        if key in skins.SKINS:
            mats[key] = skin_material(key)
            continue
        if key in kit.TEXTURES and kit.available():
            mats[key] = kit.material(key, metal)
            continue
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
    layout, groups, stats, mats = make_library()
    export(layout, groups, stats)
    return layout


def make_library():
    """Builds every model in the current (empty) scene. Returns (layout, groups, stats, materials)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    skins.build_all()
    if kit.available():
        kit.prepare_textures()
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
    # city models are big: one row further away, spaced by their own size
    cursor = 0.0
    for name, fn in CITY_ASSETS:
        start = len(lib.PIECES)
        lib.begin_asset(name)
        fn()
        offset = (cursor + 80.0, 0.0, -160.0)
        move = Matrix.Translation(lib.rb(offset))
        for ob in lib.PIECES[start:]:
            ob.matrix_world = move @ ob.matrix_world
        kind = "house" if name.startswith("house") else ("building" if name.startswith("bld") else "prop")
        layout[name] = {"kind": kind, "offset": offset}
        cursor += 140.0

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
        # UVs in studs: textured keys tile their skin, the others get a sensible density for
        # Roblox's own materials
        if mat not in kit.TEXTURES:  # the kit's meshes keep their own UVs (trim sheets)
            uv.box_project(ob, skins.SKINS[mat][1] if mat in skins.SKINS else 8)
        # pivot = bounding box center, like a Roblox MeshPart's CFrame
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
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
    make_swatches()
    return layout, groups, stats, mats


def texture_material(name, mapping=None):
    """Principled material with the PBR maps of a texture (what Studio's importer reads).
    mapping: optional (studs_per_tile) -> world-space box projection, for the city preview."""
    m = bpy.data.materials.new("tex_" + name + ("_world" if mapping else ""))
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    vector = None
    if mapping:
        coord = nodes.new("ShaderNodeTexCoord")
        mp = nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / mapping, 1 / mapping, 1 / mapping)
        links.new(coord.outputs["Object" if mapping < 0 else "Object"], mp.inputs["Vector"])
        vector = mp.outputs["Vector"]

    def image(kind, non_color):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(os.path.join(TEXTURE_DIR, f"{name}_{kind}.png"), check_existing=True)
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        if vector is not None:
            node.projection = "BOX"
            node.projection_blend = 0.15
            links.new(vector, node.inputs["Vector"])
        return node

    links.new(image("color", False).outputs["Color"], bsdf.inputs["Base Color"])
    links.new(image("roughness", True).outputs["Color"], bsdf.inputs["Roughness"])
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(image("normal", True).outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def make_swatches():
    """One 4x4 stud textured plane per texture. Studio uploads the maps on import and creates a
    SurfaceAppearance; MapBuilder turns it into a MaterialVariant for the whole city."""
    for i, name in enumerate(TEXTURES):
        bpy.ops.mesh.primitive_plane_add(size=4.0, location=lib.rb((i * 6.0, 0.0, -40.0)))
        ob = bpy.context.view_layer.objects.active
        ob.name = "__swatch__" + name
        ob.data.name = ob.name
        ob.data.materials.append(texture_material(name))


def export(layout, groups, stats):

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
        path_mode="COPY",  # Roblox: Path Mode = Copy + Embed Textures
        embed_textures=True,
    )
    write_luau(layout, groups)
    total = sum(stats.values())
    print(f"[meshgen] {len(layout)} models, {len(groups)} meshes, {total} triangles -> {FBX_PATH}")
    for asset in sorted(stats):
        print(f"  {asset:18s} {stats[asset]:6d} tris")
    return layout


def lua_str(s):
    return json.dumps(s)


def part_boxes(groups, layout):
    """Bounding box of every mesh in Roblox studs, relative to its model's origin. The runtime places
    the meshes with these numbers instead of trusting where the Studio importer put them."""
    boxes = {}
    for (asset, mat), objs in groups.items():
        ob = bpy.data.objects.get(f"{asset}__{mat}")
        if ob is None:
            continue
        pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        ox, oy, oz = layout[asset]["offset"]
        center = ((lo[0] + hi[0]) / 2 - ox, (lo[2] + hi[2]) / 2 - oy, -(lo[1] + hi[1]) / 2 - oz)
        size = (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1])
        boxes[f"{asset}__{mat}"] = (center, size)
    return boxes


def write_luau(layout, groups):
    group_keys = groups.keys()
    boxes = part_boxes(groups, layout)
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
        textured = "true" if key in skins.SKINS or key in kit.TEXTURES else "false"
        lines.append(f"\t{key} = {{ material = {lua_str(rbx_mat)}, color = {lua_str(color)}, transparency = {transparency}, textured = {textured} }},")
    lines += [
        "} :: { [string]: { material: string, color: string, transparency: number, textured: boolean } }",
        "",
        "-- bounding box of each mesh (center relative to the model origin, size), in studs",
        "MeshLibrary.Parts = {",
    ]
    for name in sorted(boxes):
        (cx, cy, cz), (sx, sy, sz) = boxes[name]
        lines.append(f"\t[{lua_str(name)}] = {{ c = {{ {cx:.4f}, {cy:.4f}, {cz:.4f} }}, s = {{ {sx:.4f}, {sy:.4f}, {sz:.4f} }} }},")
    lines += [
        "} :: { [string]: { c: { number }, s: { number } } }",
        "",
        "-- tileable PBR textures (tools/meshgen/textures.py), carried by the \"__swatch__<name>\" meshes;",
        "-- MapBuilder turns each into a MaterialVariant \"BM_<name>\"",
        "MeshLibrary.Textures = {",
    ]
    for name, (_fn, base, studs) in TEXTURES.items():
        lines.append(f"\t{name} = {{ baseMaterial = {lua_str(base)}, studsPerTile = {studs} }},")
    lines += [
        "} :: { [string]: { baseMaterial: string, studsPerTile: number } }",
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
