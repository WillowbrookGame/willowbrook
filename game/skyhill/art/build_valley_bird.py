"""Rebuild the original Skyhill bird: blender --background --factory-startup --python build_valley_bird.py."""
from pathlib import Path
import sys
import bpy
import bmesh

bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    return m

umber = mat("Warm slate", (.16, .105, .083))
cream = mat("Oat belly", (.73, .48, .25))
tips = mat("Dark primaries", (.082, .063, .06))
gold = mat("Ochre beak", (.91, .43, .09))

def geometry(name, vertices, faces, materials, slots, origin=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    me.from_pydata(vertices, [], faces)
    for m in materials:
        me.materials.append(m)
    for face, slot in zip(me.polygons, slots):
        face.material_index = slot
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    obj.location = origin
    return obj

def ellipsoid(name, loc, scale, material, belly=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    if belly:
        obj.data.materials.append(belly)
        for face in obj.data.polygons:
            if face.center.z < -.08:
                face.material_index = 1
    return obj

# Blender +Y becomes Godot -Z. Each wing's origin is its shoulder hinge.
ellipsoid("Body", (0, -.04, 0), (.18, .39, .15), umber, cream)
ellipsoid("Head", (0, .28, .045), (.13, .16, .123), umber, cream)
geometry("Beak", [(-.07,.38,.01),(.07,.38,.01),(0,.39,.1),(0,.56,.023)],
         [(0,2,1),(0,1,3),(1,2,3),(2,0,3)], [gold], [0]*4)
geometry("Tail", [(-.09,-.22,0),(.09,-.22,0),(.2,-.59,.015),(.06,-.63,.015),
                  (0,-.55,.016),(-.06,-.63,.015),(-.2,-.59,.015),(0,-.38,-.055)],
         [(0,1,7),(1,2,7),(2,3,7),(3,4,7),(4,5,7),(5,6,7),(6,0,7),(0,6,5,4,3,2,1)], [tips], [0]*8)
for side, name in [(1, "WingRight"),(-1, "WingLeft")]:
    shape = [(0,.15,0),(.46,.17,.07),(.83,.035,.035),(1.12,-.15,.015),
             (.99,-.21,.014),(.93,-.20,.014),(.89,-.27,.01),(.79,-.24,.014),
             (.72,-.29,0),(.36,-.23,.015),(0,-.20,-.015),(.43,-.055,.125),
             (.42,-.055,-.041)]
    upper = [(i,(i+1)%11,11) for i in range(11)]
    lower = [((i+1)%11,i,12) for i in range(11)]
    geometry(name, [(side*x,y,z) for x,y,z in shape], upper+lower,
             [umber, tips, cream], [1 if 2 <= i <= 7 else 0 for i in range(11)]
             +[1 if 2 <= i <= 7 else 2 for i in range(11)], (side*.12,.015,.02))

# Keep meshes and hinge transforms editable both in Blender and after GLB import.
out = Path(__file__).with_name("valley-bird.glb")
if "--" in sys.argv and len(sys.argv) > sys.argv.index("--")+1:
    bpy.ops.wm.save_as_mainfile(filepath=sys.argv[sys.argv.index("--")+1])
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB")
