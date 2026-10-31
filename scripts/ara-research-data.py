#!/usr/bin/env python3
"""Create a reusable, compressed GLB + converted USDZ animation research dataset."""
import gzip
import hashlib
import json
import os
import sys
from pathlib import Path

COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    raw = Path(path).read_bytes()
    if raw[:4] != b"glTF" or len(raw) < 20 or int.from_bytes(raw[4:8], "little") != 2:
        raise ValueError("Expected a binary glTF 2.0 file")
    if int.from_bytes(raw[8:12], "little") != len(raw):
        raise ValueError("GLB declared length does not match file size")

    offset, document, binary = 12, None, None
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise ValueError("Truncated GLB chunk header")
        size = int.from_bytes(raw[offset:offset + 4], "little")
        kind = int.from_bytes(raw[offset + 4:offset + 8], "little")
        offset += 8
        chunk = raw[offset:offset + size]
        if len(chunk) != size:
            raise ValueError("Truncated GLB chunk")
        if kind == 0x4E4F534A:
            document = json.loads(chunk.rstrip(b"\0 \t\r\n"))
        elif kind == 0x004E4942:
            binary = chunk
        offset += size
    if document is None or binary is None:
        raise ValueError("GLB JSON or BIN chunk missing")

    views = document.get("bufferViews", [])
    accessors = document.get("accessors", [])

    def accessor_values(index):
        accessor = accessors[index]
        if accessor.get("componentType") != 5126 or accessor.get("sparse"):
            raise ValueError("Animation accessor %d is not a dense FLOAT accessor" % index)
        if "bufferView" not in accessor:
            raise ValueError("Animation accessor %d has no bufferView" % index)
        width = COMPONENTS.get(accessor.get("type"))
        if not width:
            raise ValueError("Unsupported accessor type: %s" % accessor.get("type"))
        view = views[accessor["bufferView"]]
        stride = view.get("byteStride", width * 4)
        if stride < width * 4:
            raise ValueError("Invalid byteStride in accessor %d" % index)
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        count = accessor["count"]
        result = []
        import struct
        for row in range(count):
            base = start + row * stride
            result.append(list(struct.unpack_from("<%df" % width, binary, base)))
        return result, accessor.get("type")

    nodes = document.get("nodes", [])
    skins = document.get("skins", [])
    animations_out = []
    for animation_index, animation in enumerate(document.get("animations", [])):
        tracks = []
        for channel in animation.get("channels", []):
            sampler = animation["samplers"][channel["sampler"]]
            times_rows, _ = accessor_values(sampler["input"])
            output_rows, output_type = accessor_values(sampler["output"])
            times = [row[0] for row in times_rows]
            interpolation = sampler.get("interpolation", "LINEAR")
            multiplier = 3 if interpolation == "CUBICSPLINE" else 1
            if not times or len(output_rows) % (len(times) * multiplier):
                raise ValueError("Animation output/input count mismatch: %s" % animation.get("name", animation_index))
            output_components = COMPONENTS[output_type]
            width = (len(output_rows) * output_components) // (len(times) * multiplier)
            rows_per_group = width // output_components
            if width % output_components or (channel["target"]["path"] != "weights" and width != output_components):
                raise ValueError("Unexpected animation output width")
            values = []
            for frame in range(len(times)):
                start = frame * multiplier * rows_per_group
                group = output_rows[start:start + multiplier * rows_per_group]
                flattened = [[value for row in group[i * rows_per_group:(i + 1) * rows_per_group] for value in row]
                             for i in range(multiplier)]
                if interpolation == "CUBICSPLINE":
                    values.append({"inTangent": flattened[0], "value": flattened[1], "outTangent": flattened[2]})
                elif width == 1:
                    values.append(flattened[0][0])
                else:
                    values.append(flattened[0])
            target = channel["target"]
            node_index = target.get("node")
            tracks.append({
                "nodeIndex": node_index,
                "node": nodes[node_index].get("name", "node#%d" % node_index) if node_index is not None else None,
                "path": target["path"],
                "interpolation": interpolation,
                "timesSeconds": times,
                "values": values,
                "valueWidth": width,
            })
        animations_out.append({
            "index": animation_index,
            "name": animation.get("name") or "animation_%d" % (animation_index + 1),
            "tracks": tracks,
        })

    joints = []
    for skin_index, skin in enumerate(skins):
        for joint_index, node_index in enumerate(skin.get("joints", [])):
            joints.append({
                "skinIndex": skin_index,
                "jointIndex": joint_index,
                "nodeIndex": node_index,
                "name": nodes[node_index].get("name", "node#%d" % node_index),
            })
    morphs = []
    for mesh_index, mesh in enumerate(document.get("meshes", [])):
        names = mesh.get("extras", {}).get("targetNames", [])
        count = max((len(primitive.get("targets", [])) for primitive in mesh.get("primitives", [])), default=0)
        for target_index in range(count):
            morphs.append({"meshIndex": mesh_index, "targetIndex": target_index,
                           "name": names[target_index] if target_index < len(names) else "target_%d" % target_index})

    return {
        "source": {
            "file": Path(path).name,
            "sizeBytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "gltfVersion": 2,
        },
        "rig": {"skinCount": len(skins), "joints": joints, "morphTargets": morphs},
        "animations": animations_out,
    }


def vec(value):
    return [float(item) for item in value]


def quaternion(value):
    imaginary = value.GetImaginary()
    return [float(value.GetReal()), float(imaginary[0]), float(imaginary[1]), float(imaginary[2])]


def usd_attribute_samples(attribute, converter):
    from pxr import Usd
    if not attribute:
        return None
    samples = []
    for time_code in attribute.GetTimeSamples():
        value = attribute.Get(Usd.TimeCode(time_code))
        if value is not None:
            samples.append({"timeCode": float(time_code), "values": converter(value)})
    return samples


def read_usdz(path):
    from pxr import Usd, UsdSkel

    stage = Usd.Stage.Open(path)
    if stage is None:
        raise ValueError("USDZ could not be opened")
    animations = [prim for prim in stage.Traverse() if prim.IsA(UsdSkel.Animation)]
    if len(animations) != 1:
        raise ValueError("Expected one UsdSkel.Animation, found %d" % len(animations))
    prim = animations[0]
    animation = UsdSkel.Animation(prim)
    joints = [str(item) for item in (animation.GetJointsAttr().Get() or [])]
    blend_shapes = [str(item) for item in (animation.GetBlendShapesAttr().Get() or [])]

    return {
        "source": {"file": Path(path).name, "sizeBytes": Path(path).stat().st_size,
                   "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest()},
        "stage": {"startTimeCode": float(stage.GetStartTimeCode()),
                  "endTimeCode": float(stage.GetEndTimeCode()),
                  "timeCodesPerSecond": float(stage.GetTimeCodesPerSecond()),
                  "framesPerSecond": float(stage.GetFramesPerSecond())},
        "animation": {
            "primPath": str(prim.GetPath()),
            "joints": joints,
            "jointTracks": {
                "translations": usd_attribute_samples(animation.GetTranslationsAttr(), lambda values: [vec(v) for v in values]),
                "rotations": usd_attribute_samples(animation.GetRotationsAttr(), lambda values: [quaternion(v) for v in values]),
                "scales": usd_attribute_samples(animation.GetScalesAttr(), lambda values: [vec(v) for v in values]),
            },
            "blendShapes": blend_shapes,
            "blendShapeWeightSamples": usd_attribute_samples(animation.GetBlendShapeWeightsAttr(), vec),
        },
    }


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: ara-research-data.py <source.glb> <converted.usdz> <timeline.json>")
    glb_path, usdz_path, timeline_path = sys.argv[1:]
    dataset = {
        "schemaVersion": 1,
        "generatedBy": "ChatAI Ara research diagnostics",
        "provenance": {
            "githubRunId": os.environ.get("GITHUB_RUN_ID"),
            "githubCommit": os.environ.get("GITHUB_SHA"),
            "preset": os.environ.get("ARA_PRESET"),
            "detail": os.environ.get("ARA_DETAIL"),
            "generatorRepository": "olatunde85/3d-gen",
            "generatorCommit": "e26cdef1464a0babf23bb0235b5f05930301ee25",
        },
        "timeline": json.loads(Path(timeline_path).read_text(encoding="utf-8")),
        "glb": read_glb(glb_path),
        "usdz": read_usdz(usdz_path),
    }
    output = Path("output-usdz/ara-research-data.json.gz")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as raw_stream:
        with gzip.GzipFile(filename="ara-research-data.json", mode="wb", fileobj=raw_stream, compresslevel=9, mtime=0) as stream:
            stream.write(json.dumps(dataset, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    print("Research dataset: %s (%.2f MB compressed); GLB animations=%d; GLB joints=%d; GLB morph targets=%d; USDZ joints=%d; USDZ morph weights=%d samples" % (
        output, output.stat().st_size / 1048576, len(dataset["glb"]["animations"]),
        len(dataset["glb"]["rig"]["joints"]), len(dataset["glb"]["rig"]["morphTargets"]),
        len(dataset["usdz"]["animation"]["joints"]),
        len(dataset["usdz"]["animation"]["blendShapeWeightSamples"] or [])))


if __name__ == "__main__":
    main()
