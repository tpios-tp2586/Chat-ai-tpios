#!/usr/bin/env python3
"""Split Ara-Avatar.usdz into per-clip USDZ files using animation-timeline.json.

Usage:
    python3 split-ara-clips.py <Ara-Avatar.usdz> <animation-timeline.json> <output_dir>

Writes one .usdz per clip entry in the timeline, e.g. Ara-Idle.usdz, Ara-Wave.usdz ...
"""
import json
import sys
import os
import shutil
import zipfile
import tempfile
from pxr import Usd, UsdSkel, Sdf, UsdGeom, UsdUtils, Gf

# Clips to extract — only what the app needs
WANTED = {
    "Idle", "Wave", "Talk", "TalkExplain",
    "AraListening", "AraThinking", "AraEmpathy", "AraLaugh",
    "Cheer", "Laugh",
}

def slug(name: str) -> str:
    return "".join(c if c.isalnum() else "-" for c in name).strip("-")

def extract_usdz(usdz_path: str, tmp_dir: str) -> str:
    """Unzip usdz, return path to the main .usda/.usdc file."""
    with zipfile.ZipFile(usdz_path) as zf:
        zf.extractall(tmp_dir)
    # Find root layer
    for name in ["Ara-Avatar.usdc", "Ara-Avatar.usda", "root.usdc", "root.usda"]:
        p = os.path.join(tmp_dir, name)
        if os.path.exists(p):
            return p
    # fallback: first .usdc or .usda
    for f in sorted(os.listdir(tmp_dir)):
        if f.endswith((".usdc", ".usda")):
            return os.path.join(tmp_dir, f)
    raise RuntimeError("No USD root layer found in USDZ")

def retime_stage(src_stage, start_sec: float, end_sec: float, dst_path: str, fps: float):
    """Create a new stage containing only frames [start_sec, end_sec], offset to t=0."""
    start_tc = start_sec * fps
    end_tc   = end_sec   * fps

    dst_stage = Usd.Stage.CreateNew(dst_path)
    dst_stage.SetStartTimeCode(0)
    dst_stage.SetEndTimeCode(round((end_sec - start_sec) * fps))
    dst_stage.SetTimeCodesPerSecond(fps)
    dst_stage.SetFramesPerSecond(fps)
    dst_stage.GetRootLayer().subLayerPaths = src_stage.GetRootLayer().subLayerPaths

    # Copy all prims
    src_layer = src_stage.GetRootLayer()
    dst_layer = dst_stage.GetRootLayer()
    Sdf.CopySpec(src_layer, Sdf.Path("/"), dst_layer, Sdf.Path("/"))

    # Re-time all time-sampled attributes by shifting offset
    offset = -start_tc
    for prim in dst_stage.Traverse():
        for attr in prim.GetAttributes():
            samples = attr.GetTimeSamples()
            if not samples:
                continue
            # Only keep samples in [start_tc, end_tc]
            new_samples = {}
            for t in samples:
                if start_tc - 1 <= t <= end_tc + 1:
                    new_samples[t + offset] = attr.Get(t)
            if new_samples:
                # Clear old samples
                attr.Clear()
                for t, v in new_samples.items():
                    attr.Set(v, t)
            else:
                attr.Clear()

    dst_stage.Save()

def pack_usdz(usdc_path: str, source_dir: str, out_path: str):
    """Pack usdc + textures into a usdz."""
    asset_resolver = UsdUtils.CreateNewARKitUsdzPackage(
        Sdf.AssetPath(usdc_path), out_path
    )
    # If that fails (older OpenUSD), fallback to zip
    if not os.path.exists(out_path) or os.path.getsize(out_path) < 100:
        with zipfile.ZipFile(out_path, "w", zipfile.ZIP_STORED) as zf:
            for root, _, files in os.walk(source_dir):
                for f in files:
                    fp = os.path.join(root, f)
                    arcname = os.path.relpath(fp, source_dir)
                    zf.write(fp, arcname)

def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: split-ara-clips.py <Ara-Avatar.usdz> <timeline.json> <output_dir>")

    usdz_path, timeline_path, output_dir = sys.argv[1:]
    os.makedirs(output_dir, exist_ok=True)

    with open(timeline_path) as f:
        timeline = json.load(f)

    fps = float(timeline.get("fps", 30))
    clips = {c["name"]: c for c in timeline["clips"]}

    with tempfile.TemporaryDirectory() as tmp:
        root_layer_path = extract_usdz(usdz_path, tmp)
        src_stage = Usd.Stage.Open(root_layer_path)
        print(f"Opened stage: {root_layer_path}, fps={fps}")

        for clip_name, clip_data in clips.items():
            if clip_name not in WANTED:
                continue
            start = float(clip_data["start"])
            end   = float(clip_data["end"])
            out_name = f"Ara-{slug(clip_name)}.usdz"
            out_path = os.path.join(output_dir, out_name)

            clip_tmp = tempfile.mkdtemp()
            try:
                usdc_out = os.path.join(clip_tmp, f"Ara-{slug(clip_name)}.usdc")
                retime_stage(src_stage, start, end, usdc_out, fps)
                # Copy textures
                for f in os.listdir(tmp):
                    if not f.endswith((".usdc", ".usda")):
                        shutil.copy2(os.path.join(tmp, f), os.path.join(clip_tmp, f))
                pack_usdz(usdc_out, clip_tmp, out_path)
                size = os.path.getsize(out_path)
                print(f"  {out_name}: {size/1024:.0f} KB (start={start:.3f}s end={end:.3f}s)")
            except Exception as e:
                print(f"  ERROR {clip_name}: {e}")
            finally:
                shutil.rmtree(clip_tmp, ignore_errors=True)

    print("Done.")

if __name__ == "__main__":
    main()
