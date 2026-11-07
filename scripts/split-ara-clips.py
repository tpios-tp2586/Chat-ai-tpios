#!/usr/bin/env python3
"""Split Ara-Avatar.usdz into per-clip USDZ files.

Writes minimal USDA with only the SkelAnimation prim retimed to [0, duration].
No Sdf.CopySpec, no stage copy — just read time samples and write USDA text.

Usage:
    python3 split-ara-clips.py <Ara-Avatar.usdz> <animation-timeline.json> <output_dir>
"""
import json, sys, os, zipfile, tempfile

WANTED = {
    "Idle", "Wave", "Talk", "TalkExplain",
    "AraListening", "AraThinking", "AraEmpathy", "AraLaugh",
    "Cheer", "Laugh",
}

def slug(name):
    return "".join(c if c.isalnum() else "-" for c in name).strip("-")

def quat_to_str(q):
    # GfQuath/GfQuatf — get components
    try:
        img = q.GetImaginary()
        return f"({float(q.GetReal()):.8f}, {float(img[0]):.8f}, {float(img[1]):.8f}, {float(img[2]):.8f})"
    except Exception:
        return str(q)

def vec3_to_str(v):
    try:
        return f"({float(v[0]):.8f}, {float(v[1]):.8f}, {float(v[2]):.8f})"
    except Exception:
        return str(v)

def write_clip_usda(skel_anim, fps, start_sec, end_sec, joints, out_path):
    from pxr import Usd, UsdSkel

    start_tc = start_sec * fps
    end_tc   = end_sec   * fps
    offset   = -start_tc
    clip_dur = end_sec - start_sec

    rot_attr   = skel_anim.GetRotationsAttr()
    trans_attr = skel_anim.GetTranslationsAttr()
    scale_attr = skel_anim.GetScalesAttr()

    all_rot_tc = rot_attr.GetTimeSamples()
    clip_tc    = sorted(t for t in all_rot_tc if start_tc - 0.5 <= t <= end_tc + 0.5)
    if not clip_tc:
        raise RuntimeError(f"No rotation samples between {start_sec:.3f}s and {end_sec:.3f}s")

    all_trans_tc = trans_attr.GetTimeSamples() if trans_attr else []
    clip_trans_tc = sorted(t for t in all_trans_tc if start_tc - 0.5 <= t <= end_tc + 0.5)

    all_scale_tc = scale_attr.GetTimeSamples() if scale_attr else []
    clip_scale_tc = sorted(t for t in all_scale_tc if start_tc - 0.5 <= t <= end_tc + 0.5)

    joints_str = ", ".join(f'"{j}"' for j in joints)
    end_tc_out = round(clip_dur * fps)

    lines = [
        '#usda 1.0',
        f'(',
        f'    defaultPrim = "AraClip"',
        f'    startTimeCode = 0',
        f'    endTimeCode = {end_tc_out}',
        f'    timeCodesPerSecond = {fps}',
        f'    framesPerSecond = {fps}',
        f')',
        '',
        'def SkelRoot "AraClip" (',
        '    prepend apiSchemas = ["SkelBindingAPI"]',
        ')',
        '{',
        '    def Skeleton "Skeleton"',
        '    {',
        f'        uniform token[] joints = [{joints_str}]',
        '    }',
        '',
        '    def SkelAnimation "Animation"',
        '    {',
        f'        uniform token[] joints = [{joints_str}]',
    ]

    # rotations
    lines.append('        quatf[] rotations.timeSamples = {')
    for tc in clip_tc:
        val = rot_attr.Get(Usd.TimeCode(tc))
        if val is None:
            continue
        new_tc = tc + offset
        quats = ", ".join(quat_to_str(q) for q in val)
        lines.append(f'            {new_tc:.4f}: [{quats}],')
    lines.append('        }')

    # translations (if present)
    if clip_trans_tc:
        lines.append('        point3f[] translations.timeSamples = {')
        for tc in clip_trans_tc:
            val = trans_attr.Get(Usd.TimeCode(tc))
            if val is None:
                continue
            new_tc = tc + offset
            vecs = ", ".join(vec3_to_str(v) for v in val)
            lines.append(f'            {new_tc:.4f}: [{vecs}],')
        lines.append('        }')

    # scales (if present)
    if clip_scale_tc:
        lines.append('        half3[] scales.timeSamples = {')
        for tc in clip_scale_tc:
            val = scale_attr.Get(Usd.TimeCode(tc))
            if val is None:
                continue
            new_tc = tc + offset
            vecs = ", ".join(vec3_to_str(v) for v in val)
            lines.append(f'            {new_tc:.4f}: [{vecs}],')
        lines.append('        }')

    lines += [
        '    }',
        '}',
    ]

    with open(out_path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: split-ara-clips.py <Ara-Avatar.usdz> <timeline.json> <output_dir>")

    usdz_path, timeline_path, output_dir = sys.argv[1:]
    os.makedirs(output_dir, exist_ok=True)

    with open(timeline_path) as f:
        timeline = json.load(f)

    clips = {c["name"]: c for c in timeline["clips"]}

    from pxr import Usd, UsdSkel
    stage = Usd.Stage.Open(usdz_path)
    if stage is None:
        raise RuntimeError("Cannot open USDZ")

    fps = float(stage.GetTimeCodesPerSecond())
    print(f"Source: fps={fps}, range={stage.GetStartTimeCode():.1f}..{stage.GetEndTimeCode():.1f}")

    anims = [p for p in stage.Traverse() if p.IsA(UsdSkel.Animation)]
    if not anims:
        raise RuntimeError("No UsdSkel.Animation found")
    skel_anim = UsdSkel.Animation(anims[0])
    joints    = [str(j) for j in (skel_anim.GetJointsAttr().Get() or [])]
    print(f"Animation prim: {anims[0].GetPath()}, joints={len(joints)}")

    for clip_name, clip_data in clips.items():
        if clip_name not in WANTED:
            continue
        start  = float(clip_data["start"])
        end    = float(clip_data["end"])
        cslug  = slug(clip_name)
        out_name = f"Ara-{cslug}.usdz"
        out_path  = os.path.join(output_dir, out_name)

        with tempfile.TemporaryDirectory() as tmp:
            usda_path = os.path.join(tmp, f"Ara-{cslug}.usda")
            try:
                write_clip_usda(skel_anim, fps, start, end, joints, usda_path)
                # Pack into USDZ (zip with STORED compression, .usda first)
                with zipfile.ZipFile(out_path, "w", zipfile.ZIP_STORED) as zf:
                    zf.write(usda_path, f"Ara-{cslug}.usda")
                size = os.path.getsize(out_path) / 1024
                print(f"  OK {out_name}: {size:.0f} KB")
            except Exception as e:
                print(f"  ERROR {clip_name}: {e}")

    print("Done.")


if __name__ == "__main__":
    main()
