"""Inspect official CC0 human/military pack downloads, without purchasing assets."""
import json
from pathlib import Path
import urllib.request
import urllib.parse

out = Path('build/asset-discovery')
out.mkdir(parents=True, exist_ok=True)
pages = {
    'human-characters': 'https://quaternius.itch.io/universal-base-characters',
    'human-outfits': 'https://quaternius.itch.io/modular-character-outfits-fantasy',
    'human-animations': 'https://quaternius.itch.io/universal-animation-library',
    'human-download': 'https://quaternius.itch.io/universal-base-characters/purchase',
    'animation-download': 'https://quaternius.itch.io/universal-animation-library/purchase',
    'conventional-guns': 'https://drive.google.com/drive/folders/12V-mHNB6bnW2WzgpJfRBQd-TG4pOO3yx?usp=sharing',
    'animated-guns': 'https://drive.google.com/drive/folders/1ICYTdMXQqhkhrh8Fzjx9D0ozJuONwtC4?usp=sharing',
    'animated-humans': 'https://drive.google.com/drive/folders/1sNi1AfenfPRrvRt5yfaj5QMMd6KKcUJ5?usp=sharing',
}
for name, url in pages.items():
    try:
        with urllib.request.urlopen(url, timeout=40) as response: page = response.read()
        (out / (name + '.html')).write_bytes(page)
        print(json.dumps({'name': name, 'url': url, 'bytes': len(page)}), flush=True)
    except Exception as error: print(json.dumps({'url':url, 'error':str(error)}), flush=True)
for name, url in {
    'gun-preview': 'https://quaternius.com/assets/images/fullres/animatedguns.jpg',
    'character-preview': 'https://quaternius.com/assets/images/fullres/universalbasecharacters/standard.jpg',
    'modular-preview':'https://quaternius.com/assets/images/fullres/modularcharacters.jpg',
    'soldier-preview': 'https://quaternius.com/assets/images/fullres/ultimateanimatedcharacter.jpg',
}.items():
    with urllib.request.urlopen(url, timeout=40) as response: (out / (name+'.jpg')).write_bytes(response.read())

# Capture the publisher's license page for every newly integrated pack.
import re
with urllib.request.urlopen('https://quaternius.com/', timeout=40) as response:
    homepage = response.read().decode()
for href in sorted(set(re.findall(r'href=["\']([^"\']+)["\']', homepage))):
    if 'pack' not in href or not any(term in href.lower() for term in ['gun', 'modularcharacter']):
        continue
    url = urllib.parse.urljoin('https://quaternius.com/', href)
    try:
        with urllib.request.urlopen(url, timeout=40) as response: page = response.read()
        name = Path(urllib.parse.urlparse(url).path).stem
        (out / ('publisher-' + name + '.html')).write_bytes(page)
        print('PUBLISHER_LICENSE', url, 'CC0' in page.decode(errors='replace'), flush=True)
    except Exception as error: print('PUBLISHER_ERROR', url, str(error), flush=True)
