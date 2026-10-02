"""Cook licensed Quaternius firearms into meter-scaled, +Z muzzle-facing GLBs.
Run with Blender. Source FBXs remain in build/ and are not Android runtime assets.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'assets/models/weapons';OUTPUT.mkdir(parents=True,exist_ok=True)
CONFIG={}
for name,identifier,length,grip in [('Pistol','pistol',.27,.22),('P90','smg',.60,.48),('Shotgun','shotgun',.92,.32),('SniperRifle','sniper',1.08,.38)]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for action in list(bpy.data.actions):bpy.data.actions.remove(action)
 bpy.ops.import_scene.fbx(filepath=str(ROOT/f'build/weapon-source/{name}.fbx'))
 for obj in bpy.context.scene.objects:
  if obj.type=='ARMATURE':obj.data.pose_position='REST'
 bpy.context.view_layer.update()
 source=next(o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('Icosphere'))
 graph=bpy.context.evaluated_depsgraph_get();mesh=bpy.data.meshes.new_from_object(source.evaluated_get(graph))
 vertices=[source.matrix_world@v.co for v in mesh.vertices]
 axis=0 if name=='Pistol' else 1
 low=min(v[axis] for v in vertices);high=max(v[axis] for v in vertices);bottom=min(v.z for v in vertices);top=max(v.z for v in vertices)
 size=length/(high-low);origin=Vector((0,0,bottom+(top-bottom)*.38));origin[axis]=low+(high-low)*grip
 rotation=Matrix.Rotation(-math.pi/2 if axis==0 else math.pi,4,'Z')
 for v,world in zip(mesh.vertices,vertices):v.co=rotation@(world-origin)*size
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 model=bpy.data.objects.new(identifier,mesh);bpy.context.collection.objects.link(model)
 for mat in mesh.materials:
  if not mat or not mat.use_nodes:continue
  bsdf=mat.node_tree.nodes.get('Principled BSDF')
  if bsdf:bsdf.inputs['Metallic'].default_value=.75;bsdf.inputs['Roughness'].default_value=.48
 bpy.context.view_layer.objects.active=model;model.select_set(True)
 target=OUTPUT/f'{identifier}.glb'
 bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
 tip=[rotation@(v-origin)*size for v in vertices if v[axis]>high-(high-low)*.015]
 elevation=sum(v.z for v in tip)/len(tip)
 CONFIG[identifier]={'model':f'res://assets/models/weapons/{identifier}.glb','scale':1,'offset':[0,0,.03],'muzzle':[0,elevation,(high-origin[axis])*size+.031],'rotation':0,'support_grip':[0,-.01,length*.15]}
 print('FIREARM',identifier,'meters',length,'muzzle',CONFIG[identifier]['muzzle'],'bytes',target.stat().st_size)
for identifier, visual in CONFIG.items():
 visual['aim_grip']=[.1,1.42,-.38 if identifier=='pistol' else -.32]
(ROOT/'build/firearm-visuals.json').write_text(json.dumps(CONFIG,indent=2))
