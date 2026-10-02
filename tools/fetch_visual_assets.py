#!/usr/bin/env python3
"""Fetch only pinned, licensed art from the official Godot TPS repository."""
import hashlib
import json
from pathlib import Path
import struct
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "tools/visual_sources.json").read_text())
DESTINATION = ROOT / "assets/vendor/godot_tps"


def inventory(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    assert magic == b"glTF" and version == 2 and length == len(data)
    size, chunk_type = struct.unpack_from("<II", data, 12)
    assert chunk_type == 0x4E4F534A
    document = json.loads(data[20:20 + size])
    result = {
        "file": str(path.relative_to(ROOT)),
        "nodes": [node.get("name", "") for node in document.get("nodes", [])],
        "meshes": [mesh.get("name", "") for mesh in document.get("meshes", [])],
        "materials": [material.get("name", "") for material in document.get("materials", [])],
        "images": document.get("images", []),
        "animations": [animation.get("name", "") for animation in document.get("animations", [])],
        "skins": [{"name": skin.get("name", ""), "joints": len(skin["joints"])} for skin in document.get("skins", [])],
        "triangles": sum(document["accessors"][primitive["indices"]]["count"] // 3
                         for mesh in document.get("meshes", []) for primitive in mesh["primitives"]
                         if "indices" in primitive),
    }
    return result


def main():
    reports = []
    for entry in LOCK["files"]:
        destination = DESTINATION / entry["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        url = f'https://raw.githubusercontent.com/{LOCK["repository"]}/{LOCK["revision"]}/{entry["path"]}'
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
        assert len(data) == entry["size"], f'Wrong source size: {entry["path"]}'
        blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        assert blob == entry["blob_sha"], f'Wrong source checksum: {entry["path"]}'
        destination.write_bytes(data)
        print(f'VERIFIED SOURCE: {entry["path"]} ({len(data)} bytes)', flush=True)
        if destination.suffix == ".glb":
            report = inventory(destination)
            reports.append(report)
            print(json.dumps({key: report[key] for key in ["file", "meshes", "animations", "skins", "triangles", "images"]}), flush=True)
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    (build / "visual-inventory.json").write_text(json.dumps(reports, indent=2))
    with zipfile.ZipFile(build / "licensed-visual-sources.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(DESTINATION.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(ROOT))
        for path in [build / "visual-inventory.json", ROOT / "tools/visual_sources.json", ROOT / "assets/licenses/Godot-TPS-LICENSE.md"]:
            archive.write(path, path.relative_to(ROOT))
    print(f'Licensed source archive: {(build / "licensed-visual-sources.zip").stat().st_size} bytes')


if __name__ == "__main__":
    main()
