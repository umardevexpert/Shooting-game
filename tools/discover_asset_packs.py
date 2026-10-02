"""Inspect established publishers for a realistic human/military art pipeline."""
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request

output = Path('build/asset-discovery')
output.mkdir(parents=True, exist_ok=True)

def inspect(name, url):
    with urllib.request.urlopen(url, timeout=30) as response:
        page = response.read().decode('utf-8')
    (output / (name + '.html')).write_text(page)
    links = [urllib.parse.urljoin(url, link) for link in re.findall(r'href=[\"\']([^\"\']+)[\"\']', page)]
    relevant = [link for link in links if any(word in link.lower() for word in ['character', 'human', 'gun', 'military', 'soldier', 'animation', '.zip', 'drive.google', 'license', 'creativecommons'])]
    print(json.dumps({'publisher': name, 'url': url, 'links': sorted(set(relevant)), 'cc0_mentioned': 'CC0' in page or 'publicdomain/zero' in page}), flush=True)
    return links

links = inspect('quaternius-index', 'https://quaternius.com/')
pages = sorted(set(link for link in links if '/packs/' in link and any(word in link.lower() for word in ['character', 'gun', 'military', 'animation'])))
for index, url in enumerate(pages[:20]):
    try: inspect('pack-' + str(index), url)
    except Exception as error: print(json.dumps({'url': url, 'error': str(error)}), flush=True)
