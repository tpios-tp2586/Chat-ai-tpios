#!/usr/bin/env python3
"""Inspect skeletal joint rotations in the converted Ara USDZ timeline."""
import json
import math
import sys
from pxr import Usd, UsdSkel


TARGETS = [
    "Spine2", "Neck", "Head", "RightShoulder", "RightArm",
    "RightForeArm", "RightHand", "RightHandIndex1",
    "RightHandMiddle1", "RightHandPinky1",
]


def quaternion_components(value):
    imaginary = value.GetImaginary()
    return (float(value.GetReal()), float(imaginary[0]),
            float(imaginary[1]), float(imaginary[2]))


def angle_degrees(a, b):
    dot = abs(sum(x * y for x, y in zip(a, b)))
    dot = min(1.0, max(-1.0, dot))
    return 2.0 * math.degrees(math.acos(dot))


def main():
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: inspect-ara-usdz-animation.py <avatar.usdz> <animation-timeline.json>"
        )

    usdz_path, timeline_path = sys.argv[1:]
    with open(timeline_path, encoding="utf-8") as stream:
        manifest = json.load(stream)

    stage = Usd.Stage.Open(usdz_path)
    if stage is None:
        raise RuntimeError("USDZ could not be opened by USD")

    animations = [prim for prim in stage.Traverse() if prim.IsA(UsdSkel.Animation)]
    if len(animations) != 1:
        raise RuntimeError("Expected exactly one UsdSkel.Animation, found %d" % len(animations))

    animation = UsdSkel.Animation(animations[0])
    joints = [str(joint) for joint in (animation.GetJointsAttr().Get() or [])]
    rotations_attr = animation.GetRotationsAttr()
    time_samples = rotations_attr.GetTimeSamples()
    if not joints or not time_samples:
        raise RuntimeError("USDZ skeletal animation has no joint rotations or time samples")

    joint_indices = {}
    for index, joint in enumerate(joints):
        joint_indices[joint.rsplit("/", 1)[-1]] = index

    clips = {clip["name"]: clip for clip in manifest["clips"]}
    if "Talk" not in clips or "TalkExplain" not in clips:
        raise RuntimeError("Timeline must contain Talk and TalkExplain")

    fps = float(stage.GetTimeCodesPerSecond())
    if fps <= 0:
        raise RuntimeError("Invalid USD timeCodesPerSecond")

    def rotation_at(joint_index, seconds):
        value = rotations_attr.Get(Usd.TimeCode(seconds * fps))
        if value is None or joint_index >= len(value):
            return None
        return quaternion_components(value[joint_index])

    def clip_delta(joint_index, clip_a, clip_b=None):
        maximum = 0.0
        previous = None
        for sample in range(41):
            fraction = sample / 40.0
            time_a = clip_a["start"] + (clip_a["end"] - clip_a["start"]) * fraction
            qa = rotation_at(joint_index, time_a)
            if qa is None:
                continue
            if clip_b is None:
                if previous is not None:
                    maximum = max(maximum, angle_degrees(previous, qa))
                previous = qa
            else:
                time_b = clip_b["start"] + (clip_b["end"] - clip_b["start"]) * fraction
                qb = rotation_at(joint_index, time_b)
                if qb is not None:
                    maximum = max(maximum, angle_degrees(qa, qb))
        return maximum

    report = [
        "USDZ skeletal animation: %s" % animations[0].GetPath(),
        "joints=%d rotationTimeSamples=%d timeCodesPerSecond=%.3f" %
        (len(joints), len(time_samples), fps),
        "timeRange=%.3f..%.3f" %
        (stage.GetStartTimeCode(), stage.GetEndTimeCode()),
        "Talk vs TalkExplain: maximum sampled quaternion angular difference",
    ]

    missing = []
    for name in TARGETS:
        index = joint_indices.get(name)
        if index is None:
            report.append("%s: JOINT MISSING" % name)
            if name in ("RightArm", "RightForeArm", "RightHand"):
                missing.append(name)
            continue
        delta = clip_delta(index, clips["TalkExplain"], clips["Talk"])
        motion = clip_delta(index, clips["TalkExplain"])
        report.append(
            "%s: maxAngleDeltaVsTalk=%.3fdeg; maxStepWithinTalkExplain=%.3fdeg" %
            (name, delta, motion)
        )

    output = "\n".join(report) + "\n"
    print(output, end="")
    with open("output-usdz/usdz-animation-diagnostics.txt", "w", encoding="utf-8") as stream:
        stream.write(output)

    if missing:
        raise RuntimeError("Required USDZ arm joints are missing: " + ", ".join(missing))


if __name__ == "__main__":
    main()
