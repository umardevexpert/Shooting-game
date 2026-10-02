"""Download only the publishers' publicly offered free CC0 files."""
import hashlib
import http.cookiejar
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request
import zipfile
from bs4 import BeautifulSoup
import gdown

out=Path('build/asset-discovery');out.mkdir(parents=True,exist_ok=True)
# Official Quaternius links are captured in the source-evidence HTML.
for name, folder in [('animated-guns-fbx','155Ce5mXbboLYaAADOIBDl9N5EOf0zm8X'),('guns-fbx','1hLw5riEcdvRgExDks3ywcAaTIlTX5J3Z')]:
    try:
        listing=gdown.download_folder(id=folder,output=str(out/name)+'/',skip_download=True,quiet=True)
        for item in listing or []:
            if Path(item.path).name in ['AssaultRifle_1.fbx','AssaultRifle2_1.fbx','Pistol_1.fbx','Shotgun_1.fbx','SniperRifle_1.fbx','SubmachineGun_1.fbx','AssaultRifle.fbx','Pistol.fbx','Shotgun.fbx','SniperRifle.fbx','Bullpup.fbx','Revolver.fbx','Rifle.fbx','P90.fbx']:
                target=out/'conventional-weapons'/Path(item.path).name
                target.parent.mkdir(parents=True,exist_ok=True)
                direct='https://drive.usercontent.google.com/download?'+urllib.parse.urlencode({'id':item.id,'export':'download','confirm':'t'})
                try:
                    with urllib.request.urlopen(direct,timeout=60) as response: target.write_bytes(response.read())
                    assert target.read_bytes()[:20].startswith(b'Kaydara FBX'), 'Not a public FBX download'
                    result=str(target)
                except Exception:
                    result=gdown.download(id=item.id,output=str(target),quiet=True)
                assert result and target.is_file(),item.path
                print('GUN_DOWNLOADED',target.name,target.stat().st_size,hashlib.sha256(target.read_bytes()).hexdigest(),flush=True)
    except Exception as error:print('DRIVE_ERROR',name,str(error),flush=True)
for name in ['universal-base-characters','universal-animation-library','modular-character-outfits-fantasy','ultimate-gun-pack','ultimate-modular-characters']:
    try:
        opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        base='https://quaternius.itch.io/'+name
        page=opener.open(base+'/purchase',timeout=40).read().decode()
        soup=BeautifulSoup(page,'html.parser')
        csrf=soup.find('meta',attrs={'name':'csrf_token'})['value']
        payload=urllib.parse.urlencode({'csrf_token':csrf}).encode()
        response=opener.open(urllib.request.Request(base+'/download_url',data=payload,headers={'Referer':base+'/purchase','X-Requested-With':'XMLHttpRequest'}),timeout=40)
        data=json.load(response)
        assert 'url' in data,data
        download_page=opener.open(urllib.parse.urljoin(base,data['url']),timeout=40).read().decode()
        (out/(name+'-free-download.html')).write_text(download_page)
        soup=BeautifulSoup(download_page,'html.parser')
        links=soup.select('[data-upload_id]')
        assert len(links)==1,'Only the single officially free Standard file is permitted'
        upload=links[0]['data-upload_id']
        token=soup.find('meta',attrs={'name':'csrf_token'})['value']
        payload=urllib.parse.urlencode({'csrf_token':token}).encode()
        response=opener.open(urllib.request.Request(base+'/file/'+upload,data=payload,headers={'Referer':base+'/purchase','X-Requested-With':'XMLHttpRequest'}),timeout=40)
        file_info=json.load(response)
        assert 'url'in file_info,file_info
        archives=Path('build/human-sourcearchives');archives.mkdir(exist_ok=True)
        archive=archives/(name+'.zip')
        with opener.open(file_info['url'],timeout=180) as source,archive.open('wb') as dest:
            import shutil
            shutil.copyfileobj(source,dest)
        print('FREE_ARCHIVE',name,archive.stat().st_size,hashlib.sha256(archive.read_bytes()).hexdigest(),flush=True)
        with zipfile.ZipFile(archive) as z:
            for entry_name in z.namelist():
                if 'license' in Path(entry_name).name.lower():
                    (out/(name+'-'+Path(entry_name).name)).write_bytes(z.read(entry_name))
            if name == 'universal-base-characters':
                model_name=next(n for n in z.namelist() if n.endswith('/Godot - UE/Superhero_Male_FullBody.gltf'))
                model=json.loads(z.read(model_name));parent=Path(model_name).parent
                import posixpath
                target_folder=out/'human-models';target_folder.mkdir(parents=True,exist_ok=True)
                (target_folder/'Superhero_Male_FullBody.gltf').write_text(json.dumps(model))
                for asset in model.get('buffers',[])+model.get('images',[]):
                    if 'uri' not in asset:continue
                    uri=asset['uri'];source_name=posixpath.normpath(str(parent/uri))
                    target=target_folder/uri;target.parent.mkdir(parents=True,exist_ok=True);if source_name not in z.namelist():
                        source_name=source_name.replace('_png.png','.png')
                    target.write_bytes(z.read(source_name))
                print('HUMAN_GLTF_EXTRACTED',flush=True)
            inventory=[{'path':info.filename,'bytes':info.file_size} for info in z.infolist() if not info.is_dir()]
            (out/(name+'-inventory.json')).write_text(json.dumps(inventory,indent=2))
            print('FREE_MODELS',name,[entry for entry in inventory if entry['path'].lower().endswith(('.glb','.gltf','.fbx','.txt'))],flush=True)
            if name == 'modular-character-outfits-fantasy':
                print('OUTFIT_FILES', [x['path'] for x in inventory if x['path'].lower().endswith(('.gltf','.glb'))],flush=True)
            candidates=[entry for entry in inventory if entry['path'].lower().endswith('.glb')]
            if candidates:
                entry=next((e for e in candidates if 'male' in e['path'].lower() and 'female' not in e['path'].lower()),candidates[0])
                if entry['bytes']<30_000_000:
                    target=out/'human-models'/Path(entry['path']).name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(entry['path']))
                    print('HUMAN_MODEL_EXTRACTED',str(target),entry['bytes'],flush=True)
    except Exception as error:print('ITCH_ERROR',name,str(error),flush=True)
