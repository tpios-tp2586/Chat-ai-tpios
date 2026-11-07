#!/usr/bin/env python3
"""Split Ara-Avatar.usdz into per-clip USDZ files.

Reads skeletal animation data directly from USD time samples,
writes per-clip .usda files, packs into .usdz using zip.

Usage:
    python3 split-ara-clips.py <Ara-Avatar.usdz> <animation-timeline.json> <output_dir>
"""
import json
import sys
import os
import zipfile
import tempfile
import shutil
from pxr import Usd, UsdSkel, Sdf, Gf, Vt

WANTED = {
    "Idle", "Wave", "Talk", "TalkExplain",
    "AraListening", "AraThinking", "AraEmpathy", "AraLaugh",
    "Cheer", "Laugh",
}

def slug(name):
    return "".join(c if c.isalnum() else "-" for c in name).strip("-")


def pack_usdz(usda_path, out_path, extra_files=None):
    """Pack a .usda (and optional extra files) into a .usdz zip."""
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_STORED) as zf:
        zf.write(usda_path, os.path.basename(usda_path))
        for ep in (extra_files or []):
            zf.write(ep, os.path.basename(ep))


def write_clip_usda(src_stage, src_skel_anim, joints, fps,
                    start_sec, end_sec, out_path):
    """Write a trimmed skeletal animation as .usda, timecodes starting at 0."""
    start_tc = start_sec * fps
    end_tc   = end_sec   * fps

    # Collect all src timecodes in range
    all_tc = src_skel_anim.GetRotationsAttr().GetTimeSamples()
    clip_tc = [t for t in all_tc if start_tc - 0.5 <= t <= end_tc + 0.5]
    if not clip_tc:
        raise RuntimeError(f"No time samples found between {start_sec}s and {end_sec}s")

    offset = -start_tc  # shift so clip starts at 0

    # Gather rotation, translation, scale samples for the clip
    rot_attr   = src_skel_anim.GetRotationsAttr()
    trans_attr = src_skel_anim.GetTranslationsAttr()
    scale_attr = src_skel_anim.GetScalesAttr()

    # Build new stage
    dst_stage = Usd.Stage.CreateNew(out_path)
    dst_stage.SetStartTimeCode(0)
    dst_stage.SetEndTimeCode(round((end_sec - start_sec) * fps))
    dst_stage.SetTimeCodesPerSecond(fps)
    dst_stage.SetFramesPerSecond(fps)

    # Recreate prim hierarchy from source
    # Find the root skeleton prim to preserve structure
    skel_root = None
    for prim in src_stage.Traverse():
        if prim.GetTypeName() == "SkelRoot":
            skel_root = prim
            break

    if skel_root is None:
        raise RuntimeError("No SkelRoot found in source stage")

    # Copy the full hierarchy with Sdf.CopySpec on individual prims
    # Use SkelRoot path
    src_layer = src_stage.GetRootLayer()
    dst_layer = dst_stage.GetRootLayer()

    # Copy only the prim specs we need (SkelRoot + descendants)
    root_path = skel_root.GetPath()

    # Use CreateClassPrim approach — directly define prims and copy attributes
    # This avoids the subLayerPaths incompatibility
    Sdf.CopySpec(src_layer, root_path, dst_layer, root_path)

    # Now re-time the animation prim
    anim_path = src_skel_anim.GetPrim().GetPath()
    dst_anim_prim = dst_stage.GetPrimAtPath(anim_path)
    if not dst_anim_prim.IsValid():
        raise RuntimeError(f"Anim prim {anim_path} not in dst stage after copy")

    dst_anim = UsdSkel.Animation(dst_anim_prim)

    # Clear and re-write rotation timecodes
    dst_rot = dst_anim.GetRotationsAttr()
    dst_rot.Clear()
    for tc in clip_tc:
        val = rot_attr.Get(Usd.TimeCode(tc))
        if val is not None:
            dst_rot.Set(val, tc + offset)

    # Translation
    dst_trans = dst_anim.GetTranslationsAttr()
    dst_trans.Clear()
    trans_tc = trans_attr.GetTimeSamples() if trans_attr else []
    for tc in [t for t in trans_tc if start_tc - 0.5 <= t <= end_tc + 0.5]:
        val = trans_attr.Get(Usd.TimeCode(tc))
        if val is not None:
            dst_trans.Set(val, tc + offset)

    # Scale
    dst_scale = dst_anim.GetScalesAttr()
    dst_scale.Clear()
    scale_tc = scale_attr.GetTimeSamples() if scale_attr else []
    for tc in [t for t in scale_tc if start_tc - 0.5 <= t <= end_tc + 0.5]:
        val = scale_attr.Get(Usd.TimeCode(tc))
        if val is not None:
            dst_scale.Set(val, tc + offset)

    dst_stage.Save()


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: split-ara-clips.py <Ara-Avatar.usdz> <timeline.json> <output_dir>")

    usdz_path, timeline_path, output_dir = sys.argv[1:]
    os.makedirs(output_dir, exist_ok=True)

    with open(timeline_path) as f:
        timeline = json.load(f)

    clips = {c["name"]: c for c in timeline["clips"]}

    # Open source stage
    stage = Usd.Stage.Open(usdz_path)
    if stage is None:
        raise RuntimeError("Cannot open USDZ")

    fps = float(stage.GetTimeCodesPerSecond())
    print(f"Source: fps={fps}, range={stage.GetStartTimeCode()}..{stage.GetEndTimeCode()}")

    # Find animation
    anims = [p for p in stage.Traverse() if p.IsA(UsdSkel.Animation)]
    if not anims:
        raise RuntimeError("No UsdSkel.Animation found")
    skel_anim = UsdSkel.Animation(anims[0])
    joints = list(skel_anim.GetJointsAttr().Get() or [])
    print(f"Animation: {anims[0].GetPath()}, joints={len(joints)}")

    for clip_name, clip_data in clips.items():
        if clip_name not in WANTED:
            continue
        start = float(clip_data["start"])
        end   = float(clip_data["end"])
        out_name = f"Ara-{slug(clip_name)}.usdz"
        out_path = os.path.join(output_dir, out_name)

        with tempfile.TemporaryDirectory() as tmp:
            usda_name = f"Ara-{slug(clip_name)}.usda"
            usda_path = os.path.join(tmp, usda_name)
            try:
                write_clip_usda(stage, skel_anim, joints, fps,
                                start, end, usda_path)
                # Also copy textures from source USDZ
                tex_files = []
                with zipfile.ZipFile(usdz_path) as zf:
                    for name in zf.namelist():
                        if not name.endswith((".usdc", ".usda", ".usdz")):
                            tex_path = os.path.join(tmp, os.path.basename(name))
                            with zf.open(name) as src, open(tex_path, "wb") as dst:
                                dst.write(src.read())
                            tex_files.append(tex_path)
                pack_usdz(usda_path, out_path, tex_files)
                size = os.path.getsize(out_path) / 1024
                print(f"  OK {out_name}: {size:.0f} KB")
            except Exception as e:
                print(f"  ERROR {clip_name}: {e}")

    print("Done.")


if __name__ == "__main__":
    main()
