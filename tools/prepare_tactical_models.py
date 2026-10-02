"""Normalize CC0 Quaternius character units and conventional firearm presentation."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
for name in ['Swat','Casual']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/f'build/human-source/{name}.glb'))
    for obj in list(bpy.context.scene.objects):
        if obj.type not in ['MESH','ARMATURE']:continue
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        bsdf=mat.node_tree.nodes.get('Principled BSDF')
        if bsdf:
            bsdf.inputs['Metallic'].default_value=0.15 if 'Visor' in mat.name else 0
            bsdf.inputs['Roughness'].default_value=0.2 if 'Visor' in mat.name else 0.8
    target=ROOT/f'build/human-source/{name}-normalized.glb'
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
    print('NORMALIZED',name,target.stat().st_size)
