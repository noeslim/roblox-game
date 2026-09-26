"""Modeling helpers for the Black Market mesh library (Blender 4.2 as a Python module).

All helpers take ROBLOX coordinates (studs): X right, Y up, Z towards the viewer / street.
They are converted to Blender (Z up): blender = (x, -z, y).
Every piece is tagged with the current asset id and a material key; build.py later joins the
pieces per (asset, material) into one mesh object named "<asset>__<material>".
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

STATE = {"asset": None}
PIECES = []


def begin_asset(asset_id):
    STATE["asset"] = asset_id


def rb(v):
    """Roblox position -> Blender position."""
    return Vector((v[0], -v[2], v[1]))


def rbs(s):
    """Roblox size -> Blender size."""
    return Vector((s[0], s[2], s[1]))


def rot_matrix(rx=0.0, ry=0.0, rz=0.0):
    """Rotation given in Roblox degrees (applied X, then Y, then Z) as a Blender matrix."""
    mx = Matrix.Rotation(math.radians(rx), 4, "X")
    my = Matrix.Rotation(math.radians(ry), 4, "Z")  # roblox Y = blender Z
    mz = Matrix.Rotation(math.radians(-rz), 4, "Y")  # roblox Z = blender -Y
    return mx @ my @ mz


def _link(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _tag(ob, mat, pos, rot):
    ob.matrix_world = Matrix.Translation(rb(pos)) @ rot_matrix(*rot)
    ob["bm_asset"] = STATE["asset"]
    ob["bm_mat"] = mat
    PIECES.append(ob)
    return ob


def bevel(ob, width, segments=3, angle=35):
    if width <= 0:
        return ob
    m = ob.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.use_clamp_overlap = True
    return ob


def box(size, pos, mat, bev=0.03, segs=3, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    s = rbs(size)
    for v in bm.verts:
        v.co = Vector((v.co.x * s.x, v.co.y * s.y, v.co.z * s.z))
    ob = _link(bm, "box")
    bevel(ob, min(bev, min(size) * 0.45), segs)
    return _tag(ob, mat, pos, rot)


def cyl(radius, length, pos, mat, axis="y", verts=32, bev=0.02, segs=2, rot=(0, 0, 0), radius2=None):
    """Cylinder (or cone with radius2) along a Roblox axis."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=verts,
        radius1=radius, radius2=radius if radius2 is None else radius2, depth=length,
    )
    ob = _link(bm, "cyl")
    bevel(ob, min(bev, radius * 0.4, length * 0.4), segs, angle=50)
    base = {"y": (0, 0, 0), "x": (0, 0, 90), "z": (90, 0, 0)}[axis]
    ob.matrix_world = Matrix.Translation(rb(pos)) @ rot_matrix(*rot) @ rot_matrix(*base)
    ob["bm_asset"] = STATE["asset"]
    ob["bm_mat"] = mat
    PIECES.append(ob)
    return ob


def lathe(profile, pos, mat, axis="y", verts=40, rot=(0, 0, 0)):
    """Surface of revolution. profile = [(radius, height), ...] bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, h in profile:
        ring = []
        for i in range(verts):
            a = 2 * math.pi * i / verts
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, h)))
        rings.append(ring)
    for a_ring, b_ring in zip(rings, rings[1:]):
        for i in range(verts):
            j = (i + 1) % verts
            bm.faces.new((a_ring[i], a_ring[j], b_ring[j], b_ring[i]))
    if profile[0][0] > 0:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 0:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _link(bm, "lathe")
    base = {"y": (0, 0, 0), "x": (0, 0, 90), "z": (90, 0, 0)}[axis]
    ob.matrix_world = Matrix.Translation(rb(pos)) @ rot_matrix(*rot) @ rot_matrix(*base)
    ob["bm_asset"] = STATE["asset"]
    ob["bm_mat"] = mat
    PIECES.append(ob)
    return ob


def extrude(poly, depth, pos, mat, bev=0.02, segs=2, rot=(0, 0, 0)):
    """2D polygon in the Roblox XY plane (list of (x, y), CCW), extruded along Z, centered."""
    bm = bmesh.new()
    front = [bm.verts.new((x, depth / 2, y)) for x, y in poly]
    back = [bm.verts.new((x, -depth / 2, y)) for x, y in poly]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(poly)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _link(bm, "extrude")
    bevel(ob, bev, segs, angle=30)
    return _tag(ob, mat, pos, rot)


def tube(points, radius, mat, verts=12):
    """Round tube through Roblox-space points (cables, neon tubes, rails)."""
    curve = bpy.data.curves.new("tube", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = max(2, verts // 4)
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, pt in zip(spline.points, points):
        v = rb(pt)
        p.co = (v.x, v.y, v.z, 1)
    ob = bpy.data.objects.new("tube", curve)
    bpy.context.scene.collection.objects.link(ob)
    ob["bm_asset"] = STATE["asset"]
    ob["bm_mat"] = mat
    PIECES.append(ob)
    return ob


def neon_text(text, size, pos, mat, tube_radius=0.05, rot=(0, 0, 0), font_extrude=0.0):
    """Neon-tube letters: the glyph outlines become round tubes. Faces the viewer (+Z)."""
    curve = bpy.data.curves.new("text", "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.fill_mode = "NONE"
    curve.bevel_depth = tube_radius
    curve.bevel_resolution = 3
    curve.extrude = font_extrude
    ob = bpy.data.objects.new("text", curve)
    bpy.context.scene.collection.objects.link(ob)
    # text lies in Blender XY; stand it up so it faces Roblox +Z (Blender -Y)
    ob.matrix_world = Matrix.Translation(rb(pos)) @ rot_matrix(*rot) @ Matrix.Rotation(math.radians(90), 4, "X")
    ob["bm_asset"] = STATE["asset"]
    ob["bm_mat"] = mat
    PIECES.append(ob)
    return ob


def leaf(length, width, pos, mat, yaw, pitch, bend=0.25):
    """Curved elongated leaf (plant)."""
    bm = bmesh.new()
    steps = 8
    left, right, mid = [], [], []
    for i in range(steps + 1):
        t = i / steps
        w = math.sin(math.pi * t) * width / 2
        z = -bend * t * t * length
        mid.append(bm.verts.new((0, t * length, z + 0.01)))
        left.append(bm.verts.new((-w, t * length, z)))
        right.append(bm.verts.new((w, t * length, z)))
    for i in range(steps):
        bm.faces.new((left[i], mid[i], mid[i + 1], left[i + 1]))
        bm.faces.new((mid[i], right[i], right[i + 1], mid[i + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    ob = _link(bm, "leaf")
    sol = ob.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.03
    # leaf grows along blender +Y: yaw around up, pitch upwards
    ob.matrix_world = (
        Matrix.Translation(rb(pos))
        @ Matrix.Rotation(math.radians(yaw), 4, "Z")
        @ Matrix.Rotation(math.radians(pitch), 4, "X")
    )
    ob["bm_asset"] = STATE["asset"]
    ob["bm_mat"] = mat
    PIECES.append(ob)
    return ob
