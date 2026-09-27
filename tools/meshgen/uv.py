"""UVs for the library meshes: box projection in studs, so a texture tile covers the same number of
studs on every face of every model (walls, trims, crates...). Faces pick the axis their normal points
along; walls map (horizontal, up) so patterns like bricks and siding stay level."""
import bmesh


def box_project(ob, studs_per_tile):
    """Writes the "UVMap" layer of a mesh object, from its world-space vertices (Blender Z up)."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.verify()
    mw = ob.matrix_world
    k = 1.0 / studs_per_tile
    for face in bm.faces:
        n = (mw.to_3x3() @ face.normal)
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            p = mw @ loop.vert.co
            if az >= ax and az >= ay:  # floors, roofs, tops
                u, v = p.x, p.y if n.z > 0 else -p.y
            elif ax >= ay:  # walls facing +/- X
                u, v = (-p.y if n.x > 0 else p.y), p.z
            else:  # walls facing +/- Y
                u, v = (p.x if n.y < 0 else -p.x), p.z
            loop[uv].uv = (u * k, v * k)
    bm.to_mesh(me)
    bm.free()
