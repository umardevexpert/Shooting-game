#!/usr/bin/env python3
"""Strip unused rig controls, root translation and redundant keys from licensed GLB."""
import copy
import json
from pathlib import Path
import struct
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/vendor/godot_tps/player/model/player.glb"
DESTINATION = ROOT / "assets/models/operator.glb"
ANIMATIONS = {"Idle-cycle": "idle", "Idlecombat-cycle": "combat_idle",
              "walking_gun-cycle": "walk", "running_gun-cycle": "run",
              "running_aiming": "aim_run", "strafe_front-cycle": "aim_forward",
              "strafe_back-cycle": "aim_backward", "strafe_left-cycle": "aim_left",
              "strafe_right-cycle": "aim_right", "AIM-Center": "aim_center",
              "AIM-Up": "aim_up", "AIM-Down": "aim_down", "flinch1": "hit",
              "flinch_heavy": "hit_heavy", "jump_1_up": "jump"}


def main():
    data = SOURCE.read_bytes()
    json_size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_size])
    binary = bytearray(data[28 + json_size:])
    dimensions = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    types = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}

    def read(index):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        dtype = np.dtype(types[accessor["componentType"]]).newbyteorder("<")
        width = dimensions[accessor["type"]]
        return np.ndarray((accessor["count"], width), dtype=dtype, buffer=binary,
                          offset=view.get("byteOffset", 0) + accessor.get("byteOffset", 0),
                          strides=(view.get("byteStride", dtype.itemsize * width), dtype.itemsize)).copy()

    def append(values, template):
        padding = (-len(binary)) % 4
        binary.extend(b"\0" * padding)
        offset = len(binary)
        raw = values.tobytes()
        binary.extend(raw)
        view = len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(raw)})
        accessor = copy.deepcopy(template)
        accessor.update(bufferView=view, byteOffset=0, count=len(values))
        if "min" in accessor: accessor["min"] = values.min(axis=0).tolist()
        if "max" in accessor: accessor["max"] = values.max(axis=0).tolist()
        doc["accessors"].append(accessor)
        return len(doc["accessors"]) - 1

    skin = doc["skins"][0]
    joints = set()
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            indices, weights = read(attributes["JOINTS_0"]), read(attributes["WEIGHTS_0"])
            joints.update(int(i) for i in indices[weights > 0.00001])
    # Attachment bones remain available even when a particular mesh has no weights there.
    for i, node in enumerate(skin["joints"]):
        if doc["nodes"][node]["name"] in ["hand.R", "hand.L", "chest", "spine1", "spine2", "head.001"]:
            joints.add(i)
    parents = {child: index for index, node in enumerate(doc["nodes"]) for child in node.get("children", [])}
    retained = {index for index, node in enumerate(doc["nodes"]) if "mesh" in node}
    retained.update(skin["joints"][joint] for joint in joints)
    for index in list(retained):
        while index in parents:
            index = parents[index]
            retained.add(index)
    joints.update(i for i, node in enumerate(skin["joints"]) if node in retained)
    old_joints = sorted(joints)
    joint_map = {old: new for new, old in enumerate(old_joints)}
    nodes = sorted(retained)
    node_map = {old: new for new, old in enumerate(nodes)}
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            index = primitive["attributes"]["JOINTS_0"]
            values = read(index)
            remapped = np.array([[joint_map.get(int(j), 0) for j in row] for row in values], dtype=values.dtype)
            primitive["attributes"]["JOINTS_0"] = append(remapped, doc["accessors"][index])
    index = skin["inverseBindMatrices"]
    skin["inverseBindMatrices"] = append(read(index)[old_joints], doc["accessors"][index])
    skin["joints"] = [node_map[skin["joints"][joint]] for joint in old_joints]
    if "skeleton" in skin: skin["skeleton"] = node_map[skin["skeleton"]]
    animations = []
    for original in doc["animations"]:
        if original["name"] not in ANIMATIONS: continue
        animation = {"name": ANIMATIONS[original["name"]], "channels": [], "samplers": []}
        for channel in original["channels"]:
            node = channel["target"]["node"]
            path = channel["target"]["path"]
            if node not in retained: continue
            node_data = doc["nodes"][node]
            if node_data.get("name") == "root" and path == "translation": continue
            sampler = original["samplers"][channel["sampler"]]
            assert sampler.get("interpolation", "LINEAR") == "LINEAR"
            times, values = read(sampler["input"]), read(sampler["output"])
            rest = node_data.get(path, {"translation": [0, 0, 0], "rotation": [0, 0, 0, 1], "scale": [1, 1, 1]}[path])
            if np.allclose(values, rest, atol=0.00003): continue
            if np.allclose(values, values[0], atol=0.00003):
                selection = [0]
            else:
                selection = [0]
                for key in range(1, len(times) - 1):
                    if times[key, 0] - times[selection[-1], 0] >= 1 / 30 - 0.0001:
                        selection.append(key)
                selection.append(len(times) - 1)
            animation["channels"].append({"sampler": len(animation["samplers"]), "target": {"node": node_map[node], "path": path}})
            animation["samplers"].append({"input": append(times[selection], doc["accessors"][sampler["input"]]),
                                           "output": append(values[selection], doc["accessors"][sampler["output"]]), "interpolation": "LINEAR"})
        animations.append(animation)
    doc["animations"] = animations
    doc["nodes"] = [dict(node, children=[node_map[child] for child in node.get("children", []) if child in retained]) for index, node in enumerate(doc["nodes"]) if index in retained]
    for scene in doc["scenes"]: scene["nodes"] = [node_map[node] for node in scene["nodes"] if node in retained]
    references = set()
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            references.update(primitive["attributes"].values())
            if "indices" in primitive: references.add(primitive["indices"])
    references.add(skin["inverseBindMatrices"])
    for animation in animations:
        for sampler in animation["samplers"]: references.update([sampler["input"], sampler["output"]])
    accessor_map = {old: new for new, old in enumerate(sorted(references))}
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            primitive["attributes"] = {name: accessor_map[index] for name, index in primitive["attributes"].items()}
            if "indices" in primitive: primitive["indices"] = accessor_map[primitive["indices"]]
    skin["inverseBindMatrices"] = accessor_map[skin["inverseBindMatrices"]]
    for animation in animations:
        for sampler in animation["samplers"]:
            for key in ["input", "output"]: sampler[key] = accessor_map[sampler[key]]
    accessors = [doc["accessors"][old] for old in sorted(references)]
    views = sorted({accessor["bufferView"] for accessor in accessors})
    view_map = {old: new for new, old in enumerate(views)}
    compact = bytearray()
    compact_views = []
    for old in views:
        view = copy.deepcopy(doc["bufferViews"][old])
        compact.extend(b"\0" * ((-len(compact)) % 4))
        start = view.get("byteOffset", 0)
        view["byteOffset"] = len(compact)
        compact.extend(binary[start:start + view["byteLength"]])
        compact_views.append(view)
    for accessor in accessors: accessor["bufferView"] = view_map[accessor["bufferView"]]
    doc.update(accessors=accessors, bufferViews=compact_views, buffers=[{"byteLength": len(compact)}])
    encoded = json.dumps(doc, separators=(",", ":")).encode()
    encoded += b" " * ((-len(encoded)) % 4)
    compact.extend(b"\0" * ((-len(compact)) % 4))
    output = struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(compact))
    output += struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
    output += struct.pack("<II", len(compact), 0x004E4942) + compact
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    DESTINATION.write_bytes(output)
    print(f"Prepared operator: {len(old_joints)} bones, {len(animations)} animations, {len(output):,} bytes (source {len(data):,})")


if __name__ == "__main__":
    main()
