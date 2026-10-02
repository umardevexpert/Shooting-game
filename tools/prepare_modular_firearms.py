"""Normalize CC0 modular firearms, preserving real authored geometry.
Source: Quaternius Modular Sci-Fi Guns. Recolor to muted tactical materials.
"""
from pathlib import Path
import bpy,json,math
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
config=json.loads((ROOT/'build/firearm-visuals.json').read_text())
for name,identifier,length,grip in [('AR_4','rifle',.78,.42),('AR_1','burst',.90,.40),('AR_6','heavy',1.04,.42),('Grenade_3','launcher',.83,.46)]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for action in list(bpy.data.actions):bpy.data.actions.remove(action)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/f'build/weapon-source/{name}.glb'))
 source=next(o for o in bpy.context.scene.objects if o.type=='MESH')
 mesh=bpy.data.meshes.new_from_object(source.evaluated_get(bpy.context.evaluated_depsgraph_get()))
 vertices=[source.matrix_world@v.co for v in mesh.vertices]
 low=min(v.x for v in vertices);high=max(v.x for v in vertices);bottom=min(v.z for v in vertices);top=max(v.z for v in vertices)
 size=length/(high-low);origin=Vector((low+(high-low)*grip,0,bottom+(top-bottom)*.23))
 rotation=Matrix.Rotation(-math.pi/2,4,'Z')
 for vertex,world in zip(mesh.vertices,vertices):vertex.co=rotation@(world-origin)*size
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 model=bpy.data.objects.new(identifier,mesh);bpy.context.collection.objects.link(model)
 for mat in mesh.materials:
  if not mat:continue
  material=mat.copy();model.data.materials[model.data.materials.find(mat.name)]=material
  material.use_nodes=True;bsdf=material.node_tree.nodes.get('Principled BSDF')
  color=bsdf.inputs['Base Color'].default_value
  if color[0]>color[1]*1.3:replacement=(.18,.20,.13,1)
  elif max(color[:3])>.35:replacement=(.24,.28,.29,1)
  else:replacement=(.06,.075,.08,1)
  bsdf.inputs['Base Color'].default_value=replacement;bsdf.inputs['Metallic'].default_value=.65;bsdf.inputs['Roughness'].default_value=.55
 bpy.context.view_layer.objects.active=model;model.select_set(True)
 target=ROOT/f'assets/models/weapons/{identifier}.glb'
 bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
 tip=[rotation@(v-origin)*size for v in vertices if v.x>high-(high-low)*.015]
 elevation=sum(v.z for v in tip)/len(tip)
 config[identifier]={'model':f'res://assets/models/weapons/{identifier}.glb','scale':1,'offset':[0,0,.03],'muzzle':[0,elevation,(high-origin.x)*size+.031],'rotation':0,'support_grip':[-.03,-.02,length*.15]}
 print('MODULAR_FIREARM',identifier,'length',length,'bytes',target.stat().st_size)
(ROOT/'data/weapon_visuals.json').write_text(json.dumps(config,indent=2)+'\n')
