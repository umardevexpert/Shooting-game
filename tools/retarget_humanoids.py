"""Bake CC0 Universal Animation Library clips onto the tactical humanoid rig."""
import copy
import json
from pathlib import Path
import struct
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ANIMATIONS = {'Idle_Loop':'idle','Walk_Loop':'walk','Sprint_Loop':'run',
 'Jog_Fwd_Loop':'aim_forward','Pistol_Idle_Loop':'combat_idle',
 'Pistol_Aim_Neutral':'aim_center','Pistol_Aim_Up':'aim_up','Pistol_Aim_Down':'aim_down',
 'Pistol_Shoot':'fire_source','Pistol_Reload':'reload_source','Death01':'death_source',
 'Hit_Chest':'hit','Hit_Head':'hit_heavy','Jump_Loop':'jump','Roll':'roll',
 'Interact':'interact','Crouch_Idle_Loop':'crouch_idle','Crouch_Fwd_Loop':'crouch_walk'}
MAP={'Root':'root','Hips':'pelvis','Abdomen':'spine_01','Torso':'spine_02','Chest':'spine_03','Neck':'neck_01','Head':'Head'}
CANONICAL={'Root':'root','Hips':'hips','Abdomen':'spine1','Torso':'spine2','Chest':'spine3','Neck':'neck','Head':'head'}
for suffix,side in [('L','l'),('R','r')]:
 for target,source,canonical in [('Shoulder','clavicle','shoulder'),('UpperArm','upperarm','upper_arm'),('LowerArm','lowerarm','forearm'),('Hand','hand','hand'),('UpperLeg','thigh','thigh'),('LowerLeg','calf','calf'),('Foot','foot','foot')]:
  MAP[target+'.'+suffix]=source+'_'+side;CANONICAL[target+'.'+suffix]=canonical+'.'+suffix
 for finger in ['Index','Middle','Ring','Pinky','Thumb']:
  for old,new in [(2,'01'),(3,'02'),(4,'03')]:MAP[finger+str(old)+'.'+suffix]=finger.lower()+'_'+new+'_'+side


def load(path):
 data=path.read_bytes();size=struct.unpack_from('<I',data,12)[0]
 return json.loads(data[20:20+size]),bytearray(data[28+size:])


def read(doc,binary,index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
 width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
 return np.ndarray((a['count'],width),dtype='<f4',buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*4),4)).copy()


def append(doc,binary,values,kind):
 values=np.asarray(values,dtype='<f4');binary.extend(b'\0'*((-len(binary))%4));offset=len(binary);binary.extend(values.tobytes())
 view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':values.nbytes})
 a={'bufferView':view,'componentType':5126,'count':len(values),'type':kind}
 if kind=='SCALAR':a.update(min=values.min(0).tolist(),max=values.max(0).tolist())
 doc['accessors'].append(a);return len(doc['accessors'])-1


def mul(a,b):
 av,bv=np.asarray(a[:3]),np.asarray(b[:3]);v=a[3]*bv+b[3]*av+np.cross(av,bv)
 return np.r_[v,a[3]*b[3]-np.dot(av,bv)]


def inverse(q):return np.r_[-np.asarray(q[:3]),q[3]]


def rotate(q,v):return mul(mul(q,np.r_[v,0]),inverse(q))[:3]


def hierarchy(doc):
 parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
 order=[]
 def visit(i):
  if i in order:return
  if i in parents:visit(parents[i])
  order.append(i)
 for i in range(len(doc['nodes'])):visit(i)
 return parents,order


def globals_for(doc,parents,order,rotations):
 result={}
 for i in order:
  result[i]=mul(result[parents[i]],rotations[i]) if i in parents else rotations[i]
 return result


def sample(times,values,t):
 if len(times)==1:return values[0]
 index=int(np.searchsorted(times,t,side='right'))-1;index=max(0,min(index,len(times)-2))
 weight=np.clip((t-times[index])/max(times[index+1]-times[index],1e-9),0,1)
 a,b=values[index],values[index+1]
 if len(a)==4 and np.dot(a,b)<0:b=-b
 result=a*(1-weight)+b*weight
 return result/np.linalg.norm(result) if len(a)==4 else result


def retarget(name,source,sbinary):
 doc,binary=load(ROOT/f'build/human-source/{name}-normalized.glb')
 sp,so=hierarchy(source);tp,to=hierarchy(doc)
 sr=[np.asarray(n.get('rotation',[0,0,0,1]),float) for n in source['nodes']]
 tr=[np.asarray(n.get('rotation',[0,0,0,1]),float) for n in doc['nodes']]
 sg=globals_for(source,sp,so,sr);tg=globals_for(doc,tp,to,tr)
 sources={n.get('name'):i for i,n in enumerate(source['nodes'])}
 targets={n.get('name'):i for i,n in enumerate(doc['nodes'])}
 mapped={targets[t]:sources[s] for t,s in MAP.items() if t in targets and s in sources}
 animations=[]
 for original in source['animations']:
  if original['name'] not in ANIMATIONS:continue
  streams={}
  duration=0
  for channel in original['channels']:
   sampler=original['samplers'][channel['sampler']];assert sampler.get('interpolation','LINEAR')=='LINEAR'
   times=read(source,sbinary,sampler['input'])[:,0];values=read(source,sbinary,sampler['output'])
   streams[(channel['target']['node'],channel['target']['path'])]=(times,values)
   duration=max(duration,float(times[-1]))
  times=np.linspace(0,duration,max(2,int(np.ceil(duration*30))+1),dtype=np.float32)
  rotations={i:[] for i in mapped};translations=[]
  for time in times:
   pose=[sample(*streams[(i,'rotation')],time) if (i,'rotation')in streams else q for i,q in enumerate(sr)]
   animated_source=globals_for(source,sp,so,pose);animated_target={}
   for i in to:
    parent=animated_target.get(tp.get(i),np.asarray([0,0,0,1.]))
    if i in mapped:
     j=mapped[i];desired=mul(mul(animated_source[j],inverse(sg[j])),tg[i])
     local=mul(inverse(parent),desired);local/=np.linalg.norm(local)
     rotations[i].append(local);animated_target[i]=desired
    else:animated_target[i]=mul(parent,tr[i])
   hip=sources['pelvis'];target_hip=targets['Hips']
   base=np.asarray(doc['nodes'][target_hip].get('translation',[0,0,0]),float)
   if (hip,'translation')in streams:
    delta=sample(*streams[(hip,'translation')],time)-np.asarray(source['nodes'][hip].get('translation',[0,0,0]))
    delta=rotate(sg[sp[hip]],delta);delta=rotate(inverse(tg[tp[target_hip]]),delta)
    base=base+delta
   translations.append(base)
  animation={'name':ANIMATIONS[original['name']],'samplers':[],'channels':[]}
  input_accessor=append(doc,binary,times[:,None],'SCALAR')
  for i,values in list(rotations.items())+[(targets['Hips'],translations)]:
   kind='rotation' if i in rotations and values is rotations[i] else 'translation'
   values=np.asarray(values)
   # Correct quaternion sign continuity across samples.
   if kind=='rotation':
    for index in range(1,len(values)):
     if np.dot(values[index-1],values[index])<0:values[index]*=-1
   output=append(doc,binary,values,'VEC4' if kind=='rotation' else 'VEC3')
   animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':i,'path':kind}})
   animation['samplers'].append({'input':input_accessor,'output':output,'interpolation':'LINEAR'})
  animations.append(animation)
 # Derive in-place directional leg cycles from the licensed jog animation.
 # Upper-body aim stays a separate layer; these are derived clips, not source strafe art.
 forward=next(a for a in animations if a['name']=='aim_forward')
 for alias in ['aim_backward','aim_left','aim_right','aim_run']:
  clip=copy.deepcopy(forward);clip['name']=alias
  for channel in clip['channels']:
   i=channel['target']['node'];sampler=clip['samplers'][channel['sampler']]
   original_name=doc['nodes'][i].get('name','')
   if alias=='aim_backward' and (original_name.startswith(('UpperLeg','LowerLeg','Foot')) or original_name=='Hips'):
    values=read(doc,binary,sampler['output'])[::-1].copy()
    sampler['output']=append(doc,binary,values,'VEC4' if channel['target']['path']=='rotation' else 'VEC3')
   elif alias in ['aim_left','aim_right'] and original_name in ['UpperLeg.L','UpperLeg.R']:
    angle=np.pi/2 if alias=='aim_left' else -np.pi/2
    yaw=np.asarray([0,np.sin(angle/2),0,np.cos(angle/2)])
    local_yaw=mul(mul(inverse(tg[tp[i]]),yaw),tg[tp[i]])
    values=np.asarray([mul(local_yaw,q) for q in read(doc,binary,sampler['output'])])
    sampler['output']=append(doc,binary,values,'VEC4')
  animations.append(clip)
 doc['animations']=animations
 for node in doc['nodes']:node['name']=CANONICAL.get(node.get('name'),node.get('name','Node'))
 doc['buffers']=[{'byteLength':len(binary)}]
 encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);binary.extend(b'\0'*((-len(binary))%4))
 result=struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary
 destination=ROOT/f'assets/models/{name.lower()}_operator.glb';destination.write_bytes(result)
 print('RETARGETED',name,len(mapped),'animated humanoid bones',len(animations),'clips',len(result),'bytes')


if __name__=='__main__':
 source,binary=load(ROOT/'build/human-source/human-models/UAL1_Standard.glb')
 for name in ['Swat','Casual']:retarget(name,source,binary)
