"""Fetch exact CC0 sources from pinned mirrors, validating size and SHA-256."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
for source in json.loads((ROOT / 'tools/tactical_sources.json').read_text())['sources']:
    path = ROOT / source['target']
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
        with urllib.request.urlopen(source['url'], timeout=60) as response:
            data = response.read()
        assert len(data) == source['bytes'], f"Source size mismatch: {source['name']}"
        assert hashlib.sha256(data).hexdigest() == source['sha256'], f"Source digest mismatch: {source['name']}"
        path.write_bytes(data)
    print('VERIFIED_SOURCE', source['name'], source['license'], path.stat().st_size)
