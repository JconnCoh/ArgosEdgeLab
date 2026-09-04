#!/usr/bin/env python3
"""Render the already-discovered R18I Slot24 regions for local diagnosis."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


RESULT_SHA256 = "DEC4CAA197D4697FEDE54219DD64B2370DDF5BAC43EA011903BA7C320FE16F3C"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def visual(gray: np.ndarray) -> np.ndarray:
    lo, hi = np.quantile(gray, (0.01, 0.99))
    if hi <= lo:
        return gray.copy()
    return np.clip((gray.astype(np.float32) - lo) * 255.0 / (hi - lo), 0, 255).astype(np.uint8)


def write_png_new(path: Path, image: np.ndarray) -> None:
    if path.exists():
        raise FileExistsError(path)
    if not cv2.imwrite(str(path), image):
        raise RuntimeError(f"OpenCV failed to write {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    result_path = args.result.resolve()
    output = args.output_root.resolve()
    if output.exists():
        raise FileExistsError(output)
    if sha256_file(result_path) != RESULT_SHA256:
        raise ValueError("Frozen R18I Slot24 result changed.")
    result = json.loads(result_path.read_text(encoding="utf-8-sig"))
    regions = result["localization"]["exceptionDiagnostics"]
    if len(regions) != 8:
        raise ValueError("Expected exactly eight frozen Slot24 regions.")
    provider = load(
        "argos_scribe_r18h_for_r18i_region_review",
        project / "work/OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py",
    )
    r11 = provider.R17D.R17C.R17B._load_r11()
    output.mkdir(parents=True)
    rows: list[dict[str, Any]] = []
    sheets: list[np.ndarray] = []
    for channel in ("BF", "DF"):
        source = result["provenance"]["sources"][channel.lower()]
        source_path = Path(str(source["path"]))
        if source_path.stat().st_size != int(source["bytes"]):
            raise ValueError(f"Source byte length changed: {channel}")
        gray = r11.decode_gray_exact(source_path)
        tiles: list[np.ndarray] = []
        for item in regions:
            region = r11.Region(
                region_id=str(item["regionId"]),
                source=str(item["source"]),
                center_x=float(item["x"]),
                center_y=float(item["y"]),
                width=float(item["width"]),
                height=float(item["height"]),
                angle_degrees=float(item["angleDegrees"]),
                localization_score=float(item["score"]),
            )
            patch = r11.rectify(gray, region)
            if patch is None:
                raise ValueError(f"Could not rectify {region.region_id}")
            normalized = visual(patch)
            clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(16, 4)).apply(normalized)
            stem = f"{channel}_{region.region_id}"
            clean_path = output / f"{stem}_CLEAN.png"
            enhanced_path = output / f"{stem}_CLAHE.png"
            write_png_new(clean_path, normalized)
            write_png_new(enhanced_path, clahe)
            display = cv2.cvtColor(cv2.resize(clahe, (800, 200), interpolation=cv2.INTER_AREA), cv2.COLOR_GRAY2BGR)
            cv2.putText(display, stem, (8, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (0, 255, 0), 1, cv2.LINE_AA)
            tiles.append(display)
            rows.append({
                "channel": channel,
                "regionId": region.region_id,
                "regionSource": region.source,
                "centerX": region.center_x,
                "centerY": region.center_y,
                "angleDegrees": region.angle_degrees,
                "cleanPath": str(clean_path),
                "cleanSha256": sha256_file(clean_path),
                "enhancedPath": str(enhanced_path),
                "enhancedSha256": sha256_file(enhanced_path),
            })
        sheets.append(np.vstack(tiles))
    sheet = np.hstack(sheets)
    sheet_path = output / "R18I_SLOT24_REGION_CONTACT_SHEET.png"
    write_png_new(sheet_path, sheet)
    manifest = {
        "schema": "argos_opencv_scribe_r18i_region_review_v1",
        "state": "COMPLETE_DIAGNOSTIC_ONLY",
        "sourceResultSha256": RESULT_SHA256,
        "sourceHashes": {
            channel: result["provenance"]["sources"][channel.lower()]["sha256"]
            for channel in ("BF", "DF")
        },
        "regionCount": len(regions),
        "rows": rows,
        "contactSheetPath": str(sheet_path),
        "contactSheetSha256": sha256_file(sheet_path),
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    manifest_path = output / "R18I_SLOT24_REGION_REVIEW.json"
    r11.write_json_new(manifest_path, manifest)
    print(json.dumps({
        "state": manifest["state"], "regionCount": len(regions),
        "contactSheet": str(sheet_path), "manifestSha256": sha256_file(manifest_path),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
