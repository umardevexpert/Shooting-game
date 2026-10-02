"""Run with Blender --background --python; derive reusable licensed art modules."""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/models/environment"
OUTPUT.mkdir(parents=True, exist_ok=True)
GROUPS = {
    "props": {
        "container": ["prop_container2.001", "prop_container2door1.001", "prop_container2door2.001"],
        "cargo_crate": ["prop_cargobox3.001"],
        "barrel": ["prop_barrel3.001"],
        "supply_case": ["prop_smallbox1.001"],
        "floodlight": ["prop_floodlight.001"],
        "tripod_light": ["prop_tripodlight.001"],
        "generator": ["Reactor_greeblemachine.003"],
    },
    "structure": {
        "wall_panel": ["hall_circ1125_LowerDeckWall_2FlatWithPanels.000"],
        "pillar": ["hall_circ1125_column1.001"],
        "fence": ["hall_circ1125_fences_1Base.001"],
        "floor_panel": ["FLOOR_BRIDGE"],
    },
}
report = []
for source, groups in GROUPS.items():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / f"assets/vendor/godot_tps/level/geometry/models/{source}.glb"))
    for name, objects in groups.items():
        selected = [bpy.data.objects[obj] for obj in objects]
        assert all(obj.type == "MESH" for obj in selected)
        originals = [obj.matrix_world.copy() for obj in selected]
        # Source scenes place modules at arbitrary yaw; canonicalize before fit.
        axis = selected[0].matrix_world.to_3x3().col[0]
        yaw = math.atan2(axis.y, axis.x) if axis.x * axis.x + axis.y * axis.y > 0.01 else 0
        unrotate = Matrix.Rotation(-yaw, 4, 'Z')
        for obj in selected: obj.matrix_world = unrotate @ obj.matrix_world
        vertices = [obj.matrix_world @ Vector(corner) for obj in selected for corner in obj.bound_box]
        if name in ['container', 'cargo_crate']:
            width = max(v.x for v in vertices) - min(v.x for v in vertices)
            depth = max(v.y for v in vertices) - min(v.y for v in vertices)
            if depth > width:
                turn = Matrix.Rotation(math.pi / 2, 4, 'Z')
                for obj in selected: obj.matrix_world = turn @ obj.matrix_world
                vertices = [obj.matrix_world @ Vector(corner) for obj in selected for corner in obj.bound_box]
        minimum = Vector(tuple(min(vertex[axis] for vertex in vertices) for axis in range(3)))
        maximum = Vector(tuple(max(vertex[axis] for vertex in vertices) for axis in range(3)))
        offset = Vector((-(minimum.x + maximum.x) / 2, -(minimum.y + maximum.y) / 2, -minimum.z))
        bpy.ops.object.select_all(action="DESELECT")
        for obj in selected:
            obj.matrix_world.translation += offset
            obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT / f"{name}.glb"), export_format="GLB", use_selection=True,
                                  export_animations=False, export_cameras=False, export_lights=False)
        for obj, matrix in zip(selected, originals): obj.matrix_world = matrix
        item = {"model": name, "source": source + ".glb", "source_nodes": objects,
                "dimensions_blender": list(maximum - minimum),
                "triangles": sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in selected)}
        report.append(item)
        print("PREPARED_MODULE", json.dumps(item))
(ROOT / "build/environment-modules.json").write_text(json.dumps(report, indent=2))
