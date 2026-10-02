"""Validate committed runtime asset provenance and checksums without network access."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'assets/manifest.json').read_text())
seen = set()
for asset in manifest['assets']:
    for key in ['asset_name', 'path', 'creator', 'source', 'license', 'purpose',
                'imported_version', 'imported_date', 'attribution_required', 'sha256']:
        assert key in asset, f"Missing {key}: {asset.get('path')}"
    path = root / asset['path']
    assert path.is_relative_to(root) and path.is_file(), f"Missing asset: {path}"
    assert asset['path'] not in seen, f"Duplicate manifest entry: {path}"
    seen.add(asset['path'])
    assert hashlib.sha256(path.read_bytes()).hexdigest() == asset['sha256'], f"Asset checksum changed: {path}"
for folder in ['assets/models', 'assets/textures', 'assets/vendor/kenney_fps', 'assets/vendor/kenney_blaster_kit']:
    for path in (root / folder).rglob('*'):
        if path.suffix in ['.glb', '.png']:
            assert str(path.relative_to(root)) in seen, f"Unrecorded third-party asset: {path}"
print(f'ASSET MANIFEST PASS: {len(seen)} licensed assets with matching checksums')
