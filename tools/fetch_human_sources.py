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

out=Path('build/asset-discovery');out.mkdir(parents=True,exist_ok=True)
for name in ['universal-animation-library']:
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
        digest=hashlib.sha256(archive.read_bytes()).hexdigest()
        assert digest == 'cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724', 'Publisher animation archive changed; review source license and version before import'
        print('FREE_ARCHIVE',name,archive.stat().st_size,digest,flush=True)
        with zipfile.ZipFile(archive) as z:
            for entry_name in z.namelist():
                if 'license' in Path(entry_name).name.lower():
                    (out/(name+'-'+Path(entry_name).name)).write_bytes(z.read(entry_name))
            inventory=[{'path':info.filename,'bytes':info.file_size} for info in z.infolist() if not info.is_dir()]
            (out/(name+'-inventory.json')).write_text(json.dumps(inventory,indent=2))
            print('FREE_MODELS',name,[entry for entry in inventory if entry['path'].lower().endswith(('.glb','.gltf','.fbx','.txt'))],flush=True)
            candidates=[entry for entry in inventory if entry['path'].lower().endswith('.glb')]
            if candidates:
                entry=next((e for e in candidates if 'male' in e['path'].lower() and 'female' not in e['path'].lower()),candidates[0])
                if entry['bytes']<30_000_000:
                    target=Path('build/human-source/human-models')/Path(entry['path']).name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(entry['path']))
                    evidence=out/'human-models'/target.name;evidence.parent.mkdir(parents=True,exist_ok=True);evidence.write_bytes(target.read_bytes())
                    print('HUMAN_MODEL_EXTRACTED',str(target),entry['bytes'],flush=True)
    except Exception as error:
        raise RuntimeError(f"Could not fetch verified free animation source {name}") from error
