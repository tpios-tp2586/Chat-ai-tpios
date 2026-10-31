#!/usr/bin/env python3
"""Bake a small Hips Y-axis sway into Talk and AraListening in an Ara USDZ."""
import math
import os
import shutil
import sys
import tempfile
import zipfile

from pxr import Gf, Usd, UsdSkel

AMPLITUDE_DEGREES = 3.0
FREQUENCY_HZ = 0.8
FPS = 30.0
TARGET_CLIPS = {
    "Talk": (4.80, 11.20),
    "AraListening": (14.00, 17.20),
}


def quat_mul(a, b):
    aw = float(a.GetReal())
    av = a.GetImaginary()
    bw = float(b.GetReal())
    bv = b.GetImaginary()
    return Gf.Quatf(
        aw * bw - float(Gf.Dot(av, bv)),
        Gf.Vec3f(
            aw * bv[0] + bw * av[0] + float(Gf.Cross(av, bv)[0]),
            aw * bv[1] + bw * av[1] + float(Gf.Cross(av, bv)[1]),
            aw * bv[2] + bw * av[2] + float(Gf.Cross(av, bv)[2]),
        ),
    )


def yaw_quaternion(degrees):
    half = math.radians(degrees) * 0.5
    return Gf.Quatf(math.cos(half), Gf.Vec3f(0.0, math.sin(half), 0.0))


def find_animation(stage):
    animations = [prim for prim in stage.Traverse() if prim.IsA(UsdSkel.Animation)]
    if len(animations) != 1:
        raise RuntimeError(f"Expected exactly one UsdSkel.Animation, found {len(animations)}")
    return UsdSkel.Animation(animations[0])


def find_joint(joints, wanted):
    for index, joint in enumerate(joints):
        if str(joint).rsplit("/", 1)[-1] == wanted:
            return index
    raise RuntimeError(f"Joint {wanted!r} not found in USDZ animation")


def clip_for_time(seconds):
    for name, (start, end) in TARGET_CLIPS.items():
        if start <= seconds <= end:
            return name, start, end
    return None


def patch_usd_file(source_usdz, destination_usdz):
    with tempfile.TemporaryDirectory() as temp:
        unpacked = os.path.join(temp, "package")
        os.makedirs(unpacked)
        with zipfile.ZipFile(source_usdz, "r") as archive:
            archive.extractall(unpacked)
            names = archive.namelist()

        usd_files = []
        for root, _, files in os.walk(unpacked):
            for filename in files:
                if filename.endswith((".usd", ".usda", ".usdc")):
                    usd_files.append(os.path.join(root, filename))
        if len(usd_files) != 1:
            raise RuntimeError(f"Expected one USD payload in USDZ, found {len(usd_files)}")

        usd_path = usd_files[0]
        stage = Usd.Stage.Open(usd_path)
        if stage is None:
            raise RuntimeError("USD payload could not be opened")

        animation = find_animation(stage)
        joints = animation.GetJointsAttr().Get() or []
        hips_index = find_joint(joints, "Hips")
        rotations_attr = animation.GetRotationsAttr()
        time_samples = rotations_attr.GetTimeSamples()
        if not time_samples:
            raise RuntimeError("USDZ animation has no rotation time samples")

        start_end = {name: [False, False] for name in TARGET_CLIPS}
        patched = 0
        for time_code in time_samples:
            seconds = float(time_code) / FPS
            clip = clip_for_time(seconds)
            if clip is None:
                continue
            name, start, _ = clip
            values = rotations_attr.Get(time_code)
            if values is None or hips_index >= len(values):
                raise RuntimeError(f"Missing Hips rotation at time code {time_code}")
            elapsed = max(0.0, seconds - start)
            angle = AMPLITUDE_DEGREES * math.sin(2.0 * math.pi * FREQUENCY_HZ * elapsed)
            values = list(values)
            values[hips_index] = quat_mul(values[hips_index], yaw_quaternion(angle))
            rotations_attr.Set(values, time_code)
            patched += 1
            start_end[name][0] = True
            start_end[name][1] = True

        for name, flags in start_end.items():
            if not all(flags):
                raise RuntimeError(f"No rotation samples patched for {name}")

        stage.GetRootLayer().Save()
        stage.Reload()

        os.makedirs(os.path.dirname(destination_usdz), exist_ok=True)
        with zipfile.ZipFile(destination_usdz, "w", compression=zipfile.ZIP_STORED) as archive:
            for name in names:
                path = os.path.join(unpacked, name)
                archive.write(path, name)

        print(f"Baked Hips Y sway: ±{AMPLITUDE_DEGREES}°, {FREQUENCY_HZ}Hz, {FPS:.0f}fps")
        print(f"Patched rotation samples: {patched}")
        print(f"Hips joint index: {hips_index}")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: apply-ara-hip-sway.py <input.usdz> <output.usdz>")
    source, destination = sys.argv[1:]
    if os.path.abspath(source) == os.path.abspath(destination):
        raise SystemExit("Input and output USDZ paths must differ")
    patch_usd_file(source, destination)


if __name__ == "__main__":
    main()
