#!/usr/bin/env python3
"""Bake a subtle Hips Y-axis sway into selected Ara USDZ timeline clips."""
import json
import math
import os
import sys
import tempfile
import zipfile

from pxr import Gf, Usd, UsdSkel, UsdUtils

AMPLITUDE_DEGREES = 5.0
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


def frame_times(start, end, fps):
    duration = end - start
    count = int(math.floor(duration * fps + 1e-7))
    times = [start + frame / fps for frame in range(count + 1)]
    if end - times[-1] > 1e-7:
        times.append(end)
    else:
        times[-1] = end
    return times


def patch_usd_file(source_usdz, destination_usdz, timeline_path):
    timeline_fps, clips = load_target_clips(timeline_path)

    with tempfile.TemporaryDirectory() as temp:
        unpacked = os.path.join(temp, "package")
        os.makedirs(unpacked)
        with zipfile.ZipFile(source_usdz, "r") as archive:
            archive.extractall(unpacked)

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
        original_time_samples = rotations_attr.GetTimeSamples()
        if not original_time_samples:
            raise RuntimeError("USDZ animation has no rotation time samples")

        # Capture interpolated original rotations before replacing clip samples.
        baked_clips = {}
        for name, (start, end) in clips.items():
            samples = []
            for seconds in frame_times(start, end, timeline_fps):
                time_code = seconds * time_codes_per_second
                original = rotations_attr.Get(Usd.TimeCode(time_code))
                if original is None or hips_index >= len(original):
                    raise RuntimeError(f"Missing original rotations for {name} at {seconds:.6f}s")
                samples.append((seconds, time_code, list(original)))

            peak_wave = max(
                abs(math.sin(2.0 * math.pi * FREQUENCY_HZ * (seconds - start)) *
                    math.sin(math.pi * (seconds - start) / (end - start)) ** 2)
                for seconds, _, _ in samples
            )
            if peak_wave < 1e-6:
                raise RuntimeError(f"No usable 0.8 Hz Hips sway samples for {name}")
            baked_clips[name] = (start, end, samples, peak_wave)

        # Remove old keys inside the target clips so the new motion is truly baked at 30 FPS.
        for time_code in original_time_samples:
            seconds = float(time_code) / time_codes_per_second
            if any(start <= seconds <= end for start, end in clips.values()):
                rotations_attr.ClearAtTime(Usd.TimeCode(time_code))

        stats = {}
        patched = 0
        for name, (start, end, samples, peak_wave) in baked_clips.items():
            peak = 0.0
            for seconds, time_code, original in samples:
                progress = (seconds - start) / (end - start)
                envelope = math.sin(math.pi * progress) ** 2
                wave = math.sin(2.0 * math.pi * FREQUENCY_HZ * (seconds - start)) * envelope
                angle = AMPLITUDE_DEGREES * wave / peak_wave
                original[hips_index] = quat_mul(original[hips_index], yaw_quaternion(angle))
                if not rotations_attr.Set(original, Usd.TimeCode(time_code)):
                    raise RuntimeError(f"Could not author {name} rotation at {seconds:.6f}s")
                peak = max(peak, abs(angle))
                patched += 1
            stats[name] = {
                "count": len(samples),
                "first": samples[0][0],
                "last": samples[-1][0],
                "peak": peak,
            }

        stage.GetRootLayer().Save()

        os.makedirs(os.path.dirname(destination_usdz), exist_ok=True)
        if not UsdUtils.CreateNewARKitUsdzPackage(usd_files[0], destination_usdz):
            raise RuntimeError("OpenUSD failed to package the edited stage as an ARKit USDZ")

        # Reopen the actual package; this also catches broken package dependencies.
        packaged_stage = Usd.Stage.Open(destination_usdz)
        if packaged_stage is None:
            raise RuntimeError("Repacked Ara-Avatar.usdz could not be reopened")
        packaged_animation = find_animation(packaged_stage)
        packaged_rotations = packaged_animation.GetRotationsAttr()
        for name, (start, end) in clips.items():
            for seconds in (start, end):
                value = packaged_rotations.Get(Usd.TimeCode(seconds * time_codes_per_second))
                if value is None or hips_index >= len(value):
                    raise RuntimeError(f"Packaged USDZ is missing {name} boundary at {seconds:.6f}s")

        print(
            f"Baked Hips Y sway: amplitude={AMPLITUDE_DEGREES:.1f}deg, "
            f"frequency={FREQUENCY_HZ:.2f}Hz, sample rate={timeline_fps:.0f}FPS"
        )
        print(f"USD timeCodesPerSecond: {time_codes_per_second:.2f}; Hips joint index: {hips_index}")
        print(f"Patched Hips rotation samples: {patched}")
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
