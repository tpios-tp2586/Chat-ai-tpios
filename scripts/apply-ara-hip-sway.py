#!/usr/bin/env python3
"""Bake a subtle Hips Y-axis sway into selected Ara USDZ timeline clips."""
import json
import math
import os
import sys
import tempfile
import zipfile

from pxr import Gf, Usd, UsdSkel

AMPLITUDE_DEGREES = 3.0
FREQUENCY_HZ = 0.8
TARGET_FPS = 30.0
TARGET_CLIPS = {"Talk", "AraListening"}


def quat_mul(a, b):
    aw = float(a.GetReal())
    av = a.GetImaginary()
    bw = float(b.GetReal())
    bv = b.GetImaginary()
    cross = Gf.Cross(av, bv)
    return Gf.Quatf(
        aw * bw - float(Gf.Dot(av, bv)),
        Gf.Vec3f(
            aw * bv[0] + bw * av[0] + float(cross[0]),
            aw * bv[1] + bw * av[1] + float(cross[1]),
            aw * bv[2] + bw * av[2] + float(cross[2]),
        ),
    )


def yaw_quaternion(degrees):
    half = math.radians(degrees) * 0.5
    return Gf.Quatf(math.cos(half), Gf.Vec3f(0.0, math.sin(half), 0.0))


def load_target_clips(timeline_path):
    with open(timeline_path, encoding="utf-8") as source:
        timeline = json.load(source)

    fps = float(timeline["fps"])
    if abs(fps - TARGET_FPS) > 0.01:
        raise RuntimeError(f"Expected {TARGET_FPS:.0f} FPS timeline, found {fps}")

    clips = {}
    for clip in timeline["clips"]:
        name = str(clip["name"])
        if name not in TARGET_CLIPS:
            continue
        start = float(clip["start"])
        end = float(clip["end"])
        if not math.isfinite(start) or not math.isfinite(end) or end <= start:
            raise RuntimeError(f"Invalid time range for {name}: {start}-{end}")
        clips[name] = (start, end)

    missing = TARGET_CLIPS - clips.keys()
    if missing:
        raise RuntimeError("Timeline is missing target clips: " + ", ".join(sorted(missing)))
    return fps, clips


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


def patch_usd_file(source_usdz, destination_usdz, timeline_path):
    timeline_fps, clips = load_target_clips(timeline_path)

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

        stage = Usd.Stage.Open(usd_files[0])
        if stage is None:
            raise RuntimeError("USD payload could not be opened")

        time_codes_per_second = float(stage.GetTimeCodesPerSecond())
        if time_codes_per_second <= 0:
            raise RuntimeError(f"Invalid USD timeCodesPerSecond: {time_codes_per_second}")
        if abs(time_codes_per_second - timeline_fps) > 0.01:
            raise RuntimeError(
                f"Timeline fps ({timeline_fps}) does not match USD timeCodesPerSecond "
                f"({time_codes_per_second})"
            )

        animation = find_animation(stage)
        joints = animation.GetJointsAttr().Get() or []
        hips_index = find_joint(joints, "Hips")
        rotations_attr = animation.GetRotationsAttr()
        time_samples = rotations_attr.GetTimeSamples()
        if not time_samples:
            raise RuntimeError("USDZ animation has no rotation time samples")

        # Normalize the tapered sine per clip so its sampled peak reaches 3 degrees
        # while the offset still returns to zero at both clip boundaries.
        peak_wave = {}
        for name, (start, end) in clips.items():
            peak = 0.0
            for time_code in time_samples:
                seconds = float(time_code) / time_codes_per_second
                if start <= seconds <= end:
                    progress = min(1.0, max(0.0, (seconds - start) / (end - start)))
                    envelope = math.sin(math.pi * progress) ** 2
                    wave = math.sin(2.0 * math.pi * FREQUENCY_HZ * (seconds - start)) * envelope
                    peak = max(peak, abs(wave))
            if peak < 1e-6:
                raise RuntimeError(f"No usable 0.8 Hz Hips sway samples for {name}")
            peak_wave[name] = peak

        stats = {
            name: {"count": 0, "first": None, "last": None, "peak": 0.0}
            for name in clips
        }
        patched = 0

        for time_code in time_samples:
            seconds = float(time_code) / time_codes_per_second
            match = next(
                ((name, start, end) for name, (start, end) in clips.items()
                 if start <= seconds <= end),
                None,
            )
            if match is None:
                continue

            name, start, end = match
            values = rotations_attr.Get(time_code)
            if values is None or hips_index >= len(values):
                raise RuntimeError(f"Missing Hips rotation at time code {time_code}")

            progress = min(1.0, max(0.0, (seconds - start) / (end - start)))
            envelope = math.sin(math.pi * progress) ** 2
            elapsed = seconds - start
            wave = math.sin(2.0 * math.pi * FREQUENCY_HZ * elapsed) * envelope
            angle = AMPLITUDE_DEGREES * wave / peak_wave[name]

            values = list(values)
            values[hips_index] = quat_mul(values[hips_index], yaw_quaternion(angle))
            rotations_attr.Set(values, time_code)

            item = stats[name]
            item["count"] += 1
            item["first"] = seconds if item["first"] is None else item["first"]
            item["last"] = seconds
            item["peak"] = max(item["peak"], abs(angle))
            patched += 1

        for name, (start, end) in clips.items():
            item = stats[name]
            if item["count"] < 2:
                raise RuntimeError(f"Insufficient Hips samples for {name}: {item['count']}")
            tolerance = 1.5 / timeline_fps
            if abs(item["first"] - start) > tolerance or abs(item["last"] - end) > tolerance:
                raise RuntimeError(
                    f"{name} sample range {item['first']:.4f}-{item['last']:.4f}s "
                    f"does not cover timeline range {start:.4f}-{end:.4f}s"
                )

        stage.GetRootLayer().Save()

        os.makedirs(os.path.dirname(destination_usdz), exist_ok=True)
        with zipfile.ZipFile(destination_usdz, "w", compression=zipfile.ZIP_STORED) as archive:
            for name in names:
                archive.write(os.path.join(unpacked, name), name)

        print(
            f"Baked Hips Y sway: amplitude={AMPLITUDE_DEGREES:.1f}deg, "
            f"frequency={FREQUENCY_HZ:.2f}Hz, envelope=zero-at-clip-ends"
        )
        print(f"Timeline fps: {timeline_fps:.2f}; USD timeCodesPerSecond: {time_codes_per_second:.2f}")
        print("Per-clip tapered sway normalized to a sampled peak of +/-3.000deg")
        print(f"Hips joint index: {hips_index}; patched rotation samples: {patched}")
        for name, (start, end) in clips.items():
            item = stats[name]
            print(
                f"{name}: timeline={start:.4f}-{end:.4f}s; "
                f"samples={item['count']} ({item['first']:.4f}-{item['last']:.4f}s); "
                f"peak baked offset={item['peak']:.3f}deg"
            )


def main():
    if len(sys.argv) != 4:
        raise SystemExit(
            "Usage: apply-ara-hip-sway.py <input.usdz> <output.usdz> <animation-timeline.json>"
        )
    source, destination, timeline = sys.argv[1:]
    if os.path.abspath(source) == os.path.abspath(destination):
        raise SystemExit("Input and output USDZ paths must differ")
    patch_usd_file(source, destination, timeline)


if __name__ == "__main__":
    main()
