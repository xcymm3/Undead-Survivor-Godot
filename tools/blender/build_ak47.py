"""Author the game's AK in Blender; only the baked GLB is used at runtime.

Run with Blender --background --factory-startup --python this_file.py.
Coordinates below are game metres, +Y up, muzzle towards -Z. Blender uses Z up.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/models/ak47.glb"
SOURCE = Path(__file__).with_name("ak47.blend")
REPORT = ROOT / "artifacts/ak47-model/export.json"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.context.preferences.filepaths.save_version = 0


def point(p):
    return Vector((p[0], -p[2], p[1]))


def finish(name, color, metallic=0.0, roughness=0.55):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return material


STEEL = finish("Blued steel", (0.105, 0.135, 0.15), 0.45, 0.44)
EDGE = finish("Worn steel edges", (0.27, 0.31, 0.32), 0.55, 0.4)
WOOD = finish("Warm walnut", (0.38, 0.145, 0.043), 0, 0.6)
GRAIN = finish("Walnut grooves", (0.15, 0.047, 0.015), 0, 0.72)
DARK = finish("Recesses", (0.012, 0.018, 0.021), 0.1, 0.75)
RUBBER = finish("Grip and butt plate", (0.035, 0.042, 0.041), 0, 0.85)
body_parts = []
magazine_parts = []


def bevel(obj, width=0.004, segments=2):
    if width:
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("Baked edge chamfer", "BEVEL")
        modifier.width = width
        modifier.segments = segments
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def mesh(name, vertices, faces, material, group, chamfer=0.0):
    data = bpy.data.meshes.new(name)
    data.from_pydata([point(v) for v in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bevel(obj, chamfer)
    obj.select_set(False)
    group.append(obj)
    return obj


def box(name, center, size, material=STEEL, chamfer=0.003, group=None):
    group = body_parts if group is None else group
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(center))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    bevel(obj, chamfer)
    obj.select_set(False)
    group.append(obj)
    return obj


def profile(name, outline, width, material, chamfer=0.004, x=0, group=None):
    # A solid side-profile extrusion, useful for shaped wood and stamped panels.
    n = len(outline)
    vertices = [(x + side * width / 2, y, z) for side in (-1, 1) for y, z in outline]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, vertices, faces, material, body_parts if group is None else group, chamfer)


def tube(name, start, end, radius, material=STEEL, group=None, vertices=16):
    a, b = point(start), point(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b - a).length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(b - a)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    bevel(obj, min(radius * 0.16, 0.002), 1)
    obj.select_set(False)
    (body_parts if group is None else group).append(obj)
    return obj


# Receiver: broad uninterrupted surfaces with a curved, folded top cover.
profile("Receiver", [(-0.073, 0.10), (-0.073, -0.365), (0.055, -0.365), (0.075, -0.27), (0.075, 0.08)], 0.14, STEEL)
profile("DustCover", [(0.073, 0.065), (0.123, 0.045), (0.139, -0.015), (0.139, -0.27), (0.112, -0.315), (0.075, -0.335)], 0.125, STEEL, 0.006)
box("Cover highlight", (0, 0.139, -0.13), (0.057, 0.006, 0.26), EDGE, 0.002)
box("Ejection recess", (0.071, 0.025, -0.16), (0.006, 0.047, 0.18), DARK, 0.001)
profile("Safety lever", [(0.013, 0.025), (0.002, -0.23), (-0.017, -0.20), (-0.011, 0.04)], 0.009, EDGE, 0.001, x=0.079)
for side in (-1, 1):
    for z in (-0.29, -0.015, 0.065):
        tube("Receiver rivet", (side * 0.071, -0.025, z), (side * 0.077, -0.025, z), 0.008, EDGE, vertices=10)

# One separate bolt mesh; its origin is retained for the production recoil pose.
bolt_parts = []
box("Charging rail", (0.084, 0.047, -0.11), (0.018, 0.024, 0.15), EDGE, 0.002, bolt_parts)
tube("Charging handle", (0.084, 0.047, -0.11), (0.14, 0.047, -0.11), 0.013, EDGE, bolt_parts)

# The continuous barrel/gas tube have real circular cross-sections.
tube("Barrel", (0, 0.055, -0.65), (0, 0.055, -1.012), 0.026)
tube("Gas tube", (0, 0.13, -0.625), (0, 0.13, -0.85), 0.022)
box("Gas block", (0, 0.095, -0.855), (0.068, 0.13, 0.045))
tube("Muzzle brake", (0, 0.055, -0.99), (0, 0.055, -1.026), 0.038, EDGE)
tube("Dark bore", (0, 0.055, -1.026), (0, 0.055, -1.031), 0.023, DARK)
box("Brake vent", (0, 0.087, -1.008), (0.035, 0.006, 0.016), DARK, 0.001)
tube("Cleaning rod", (0, 0.005, -0.69), (0, 0.005, -0.985), 0.005, EDGE, vertices=10)

# Sculpted walnut furniture, with grooves merged into the same final mesh.
profile("Lower handguard", [(-0.065, -0.38), (-0.075, -0.58), (-0.035, -0.685), (0.041, -0.68), (0.065, -0.48), (0.045, -0.39)], 0.16, WOOD, 0.009)
profile("Upper handguard", [(0.078, -0.405), (0.145, -0.44), (0.15, -0.58), (0.11, -0.65), (0.075, -0.65)], 0.12, WOOD, 0.006)
for side in (-1, 1):
    for z in (-0.59, -0.54, -0.49, -0.44):
        box("Handguard cut", (side * 0.081, -0.005, z), (0.004, 0.075, 0.009), GRAIN, 0.001)
box("Handguard band", (0, 0.002, -0.678), (0.172, 0.145, 0.024), EDGE)
profile("Walnut stock", [(-0.062, 0.10), (-0.17, 0.50), (-0.16, 0.565), (0.045, 0.565), (0.055, 0.49), (0.025, 0.22), (0.058, 0.10)], 0.14, WOOD, 0.01)
profile("Butt plate", [(-0.164, 0.55), (-0.165, 0.58), (0.046, 0.58), (0.047, 0.55)], 0.154, RUBBER, 0.004)
profile("Pistol grip", [(-0.065, 0.05), (-0.27, 0.15), (-0.29, 0.055), (-0.105, -0.035)], 0.103, WOOD, 0.008)
for side in (-1, 1):
    for y in (-0.15, -0.19, -0.23):
        box("Grip groove", (side * 0.052, y, 0.07 + (-y - 0.15) * 0.35), (0.003, 0.007, 0.055), GRAIN, 0.001)
    for y in (-0.06, -0.085):
        profile("Stock grain", [(y, 0.25), (y - 0.035, 0.48), (y - 0.031, 0.48), (y + 0.004, 0.25)], 0.002, GRAIN, 0, x=side * 0.071)
for start, end in [((0, -0.077, 0.025), (0, -0.15, 0.01)), ((0, -0.15, 0.01), (0, -0.16, -0.10)), ((0, -0.16, -0.10), (0, -0.075, -0.12))]:
    tube("Trigger guard", start, end, 0.008, STEEL, vertices=10)
profile("Trigger", [(-0.074, -0.045), (-0.123, -0.06), (-0.137, -0.04), (-0.12, -0.025)], 0.016, EDGE, 0.001)

# Preserve the exact existing iron-sight line.
box("Front sight pedestal", (0, 0.132, -0.942), (0.066, 0.10, 0.04))
for x in (-0.04, 0.04):
    box("Front sight ear", (x, 0.202, -0.942), (0.014, 0.065, 0.025), STEEL, 0.002)
box("Front sight post", (0, 0.195, -0.942), (0.009, 0.041, 0.018), EDGE, 0.001)
box("Rear sight ramp", (0, 0.132, -0.325), (0.108, 0.04, 0.12))
for x in (-0.037, 0.037):
    box("Rear sight notch", (x, 0.174, -0.355), (0.04, 0.027, 0.035), EDGE, 0.001)

# A single continuous curved magazine shell, rather than overlapping boxes.
vertices = []
steps = 10
for i in range(steps + 1):
    t = i / steps
    y, z = -0.105 - 0.34 * t, -0.25 - 0.11 * t * t
    half_width, depth = 0.052 - 0.004 * t, 0.086
    vertices += [(-half_width, y, z - depth), (half_width, y, z - depth), (half_width, y, z + depth), (-half_width, y, z + depth)]
faces = [(3, 2, 1, 0)]
for i in range(steps):
    for j in range(4):
        faces.append((4 * i + j, 4 * i + (j + 1) % 4, 4 * (i + 1) + (j + 1) % 4, 4 * (i + 1) + j))
faces.append(tuple(range(4 * steps, 4 * steps + 4)))
mesh("Curved shell", vertices, faces, STEEL, magazine_parts, 0.003)
for side in (-1, 1):
    for offset in (-0.045, 0.022):
        for i in range(8):
            a, b = 0.12 + i * 0.095, 0.12 + (i + 1) * 0.095
            tube("Stamped magazine rib", (side * (0.054 - 0.004 * a), -0.105 - 0.34 * a, -0.25 - 0.11 * a * a + offset), (side * (0.054 - 0.004 * b), -0.105 - 0.34 * b, -0.25 - 0.11 * b * b + offset), 0.004, EDGE, magazine_parts, 8)
box("Magazine floorplate", (0, -0.451, -0.36), (0.116, 0.025, 0.184), EDGE, 0.003, magazine_parts)


def consolidate(parts, name, origin=(0, 0, 0)):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = point(origin)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    triangulate = obj.modifiers.new("Baked game triangles", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj.select_set(False)
    return obj


root = bpy.data.objects.new("AK47Asset", None)
bpy.context.collection.objects.link(root)
body = consolidate(body_parts, "AKBody")
magazine = consolidate(magazine_parts, "CurvedMagazine", (0, -0.10, -0.25))
bolt = consolidate(bolt_parts, "ChargingHandle", (0.11, 0.047, -0.11))
for obj in (body, magazine, bolt):
    world = obj.matrix_world.copy()
    obj.parent = root
    obj.matrix_world = world
for name, at in [("MuzzleAnchor", (0, 0.055, -1.03)), ("RightGrip", (0, -0.17, 0.075)), ("LeftGrip", (-0.025, -0.04, -0.52))]:
    marker = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(marker)
    marker.parent = root
    marker.location = point(at)
root["author"] = "Original project model authored with Blender"
root["coordinates"] = "Metres; Y-up glTF; forward -Z"
bpy.context.scene.cursor.location = (0, 0, 0)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_animations=False, export_materials="EXPORT", export_cameras=False, export_lights=False, export_yup=True)
triangles = sum(len(obj.data.polygons) for obj in (body, magazine, bolt))
assert triangles < 15000, triangles
report = {"blender": bpy.app.version_string, "source": str(SOURCE.relative_to(ROOT)), "asset": str(OUTPUT.relative_to(ROOT)), "sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(), "mesh_objects": 3, "triangles": triangles, "materials": len(bpy.data.materials), "animated_parts": ["CurvedMagazine", "ChargingHandle"], "muzzle": [0, 0.055, -1.03]}
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
print("BLENDER AK EXPORT: PASS", json.dumps(report))
