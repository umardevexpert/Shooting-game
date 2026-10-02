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
        print('DRIVE_FILES',name,repr(listing),flush=True)
        for item in listing or []:
            print('DRIVE_ITEM',repr(item),flush=True)
    except Exception as error:print('DRIVE_ERROR',name,str(error),flush=True)
for name in ['universal-base-characters','universal-animation-library']:
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
        print('ITCH_FREE_PAGE',name,[(x.get('data-upload_id'),x.get_text(' ',strip=True)) for x in soup.select('[data-upload_id]')],flush=True)
    except Exception as error:print('ITCH_ERROR',name,str(error),flush=True)
