#!/usr/bin/env python3
"""Review-only whole-wafer crop refinement around R18H scribe candidates.

R18J does not alter the frozen R18H OCR or its reference bank. It refines an
approximate perimeter candidate into ordinary source-pixel 2000x800 BF/DF
crops, then calls the unchanged R18H evaluator on bounded channel, polarity,
and direction hypotheses. No line, wafer grid, notch, checksum, or synthetic
dot reconstruction selects crop geometry or image-first characters.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


REVISION = "ARGOS_OPENCV_SCRIBE_CROP_SWEEP_R18J_REVIEW_ONLY_20260903"
ANGLE_OFFSETS = (-6.0, 0.0, 6.0)
NORMAL_OFFSETS = (0.0, 150.0, 300.0)
WINDOW_WIDTH = 2000.0
WINDOW_HEIGHT = 800.0
MAXIMUM_DISCOVERED_REGIONS = 8
MAXIMUM_PROMOTED_REGIONS = 2
MINIMUM_IMAGE_SCORE = 0.60
AMBIGUITY_SCORE_DELTA = 0.03


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    if path.exists():
        raise FileExistsError(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


@dataclass(frozen=True)
class RefinedRegion:
    source_region_id: str
    source_region_source: str
    source_localization_score: float
    region: Any
    structure_evidence: dict[str, Any]


def structure_key(row: dict[str, Any]) -> tuple[Any, ...]:
    ratios = row.get("ratios", {})
    return (
        bool(row.get("passed")),
        int(row.get("coveredCellCount", 0)),
        float(ratios.get("coherenceSum", 0.0)),
        float(ratios.get("characterPitchPair", 0.0)),
        int(row.get("qualifiedComponentCount", 0)),
    )


def shifted_region(r11: Any, source: Any, angle_offset: float, normal_offset: float) -> Any:
    radians = math.radians(float(source.angle_degrees))
    unit_y = (-math.sin(radians), math.cos(radians))
    return r11.Region(
        region_id=f"R18J_{source.region_id}_A{angle_offset:+.0f}_N{normal_offset:+.0f}",
        source="R18J_BOUNDED_SOURCE_PIXEL_CROP_SWEEP",
        center_x=float(source.center_x + normal_offset * unit_y[0]),
        center_y=float(source.center_y + normal_offset * unit_y[1]),
        width=WINDOW_WIDTH,
        height=WINDOW_HEIGHT,
        angle_degrees=float(source.angle_degrees + angle_offset),
        localization_score=float(source.localization_score),
    )


def refine_regions(r11: Any, r17c: Any, bf: np.ndarray, df: np.ndarray) -> tuple[list[RefinedRegion], list[dict[str, Any]]]:
    discovered = r11.perimeter_scribe_regions(bf, df, 1600, 24, WINDOW_WIDTH, WINDOW_HEIGHT)
    unique = r11.deduplicate_auto_regions(discovered)[:MAXIMUM_DISCOVERED_REGIONS]
    refined: list[RefinedRegion] = []
    diagnostics: list[dict[str, Any]] = []
    for source in unique:
        best_region = None
        best_evidence = None
        best_key = None
        for angle_offset in ANGLE_OFFSETS:
            for normal_offset in NORMAL_OFFSETS:
                candidate = shifted_region(r11, source, angle_offset, normal_offset)
                bf_crop = r11.rectify(bf, candidate)
                df_crop = r11.rectify(df, candidate)
                if bf_crop is None or df_crop is None:
                    continue
                for channel, crop in (("BF", bf_crop), ("DF", df_crop)):
                    for polarity, view in (("DARK", crop), ("BRIGHT", 255 - crop)):
                        evidence = r17c.measure_structure(view)
                        row = {
                            "sourceRegionId": source.region_id,
                            "channel": channel,
                            "polarity": polarity,
                            "angleOffsetDegrees": angle_offset,
                            "normalOffsetPixels": normal_offset,
                            **evidence,
                        }
                        key = structure_key(evidence)
                        if best_key is None or key > best_key:
                            best_key = key
                            best_region = candidate
                            best_evidence = row
        if best_region is not None and best_evidence is not None:
            diagnostics.append(best_evidence)
            refined.append(RefinedRegion(
                source_region_id=str(source.region_id),
                source_region_source=str(source.source),
                source_localization_score=float(source.localization_score),
                region=best_region,
                structure_evidence=best_evidence,
            ))
    refined.sort(key=lambda item: (structure_key(item.structure_evidence), item.source_localization_score), reverse=True)
    return refined[:MAXIMUM_PROMOTED_REGIONS], diagnostics


def load_banks(provider: Any, job: dict[str, Any]) -> tuple[Any, list[Any], list[Any], list[Any], dict[str, Any]]:
    r11 = provider.R17D.R17C.R17B._load_r11()
    reference = job["references"]
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in reference["roots"]}
    manifest = Path(str(reference["manifestPath"]))
    manifest_sha = str(reference["manifestSha256"])
    prototypes, evidence = r11.load_reference_prototypes(manifest, manifest_sha, roots)
    supplemental = Path(str(reference["supplementalManifestPath"]))
    supplemental_sha = str(reference["supplementalManifestSha256"])
    prototypes, evidence = provider.R18F.R18F_LOADER.combine_reference_prototypes(
        r11, prototypes, evidence, supplemental, supplemental_sha,
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, manifest, manifest_sha, roots, supplemental, supplemental_sha,
    )
    structure = provider.load_run_structure_prototypes(
        r11, manifest, manifest_sha, roots, supplemental, supplemental_sha,
    )
    return r11, prototypes, topology, structure, evidence


def decode_bound(r11: Any, row: dict[str, Any]) -> tuple[np.ndarray, dict[str, Any]]:
    path = Path(str(row["path"]))
    if not path.is_file() or path.stat().st_size != int(row["bytes"]):
        raise ValueError(f"Source is absent or its length changed: {path}")
    actual = sha256_file(path)
    if actual != str(row["sha256"]).upper():
        raise ValueError(f"Source SHA-256 mismatch: {path}")
    return r11.decode_gray_exact(path), {
        "path": str(path), "bytes": path.stat().st_size, "sha256": actual,
        "width": None, "height": None,
    }


def analyze(job: dict[str, Any], provider_path: Path, output_root: Path) -> dict[str, Any]:
    authority = job.get("authority", {})
    if not bool(authority.get("reviewOnly")) or any(bool(authority.get(key)) for key in (
        "identityAcceptanceAuthorized", "automaticReferenceAdmissionAuthorized", "trainingAuthorized",
        "activationAuthorized", "xmlAuthorized", "productionAuthorized",
    )):
        raise ValueError("R18J requires review-only authority with every expansion disabled.")
    provider = load("argos_scribe_r18h_for_r18j", provider_path)
    r11, prototypes, topology, structure, reference_evidence = load_banks(provider, job)
    bf, bf_evidence = decode_bound(r11, job["inputs"]["bf"])
    df, df_evidence = decode_bound(r11, job["inputs"]["df"])
    if bf.shape != df.shape:
        raise ValueError("BF and DF source dimensions differ.")
    bf_evidence.update({"width": int(bf.shape[1]), "height": int(bf.shape[0])})
    df_evidence.update({"width": int(df.shape[1]), "height": int(df.shape[0])})
    promoted, localization = refine_regions(r11, provider.R17D.R17C, bf, df)
    crops_root = output_root / "crops"
    crops_root.mkdir(parents=True, exist_ok=False)
    hypotheses: list[dict[str, Any]] = []
    for rank, item in enumerate(promoted, start=1):
        bf_crop = r11.rectify(bf, item.region)
        df_crop = r11.rectify(df, item.region)
        if bf_crop is None or df_crop is None:
            continue
        crop_paths: dict[str, str] = {}
        crop_hashes: dict[str, str] = {}
        for channel, crop in (("BF", bf_crop), ("DF", df_crop)):
            path = crops_root / f"R{rank:02d}_{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
            if not cv2.imwrite(str(path), crop):
                raise RuntimeError(path)
            crop_paths[channel] = str(path)
            crop_hashes[channel] = sha256_file(path)
        for channel, crop in (("BF", bf_crop), ("DF", df_crop)):
            for polarity, view in (("DARK", crop), ("BRIGHT", 255 - crop)):
                for direction, oriented in (("FORWARD", view), ("REVERSE_180", cv2.rotate(view, cv2.ROTATE_180))):
                    try:
                        evaluated = provider.evaluate_detector_input_structural(
                            r11, oriented, prototypes, topology, structure,
                            str(job["identity"]["physicalIdentity"]),
                        )
                    except ValueError as error:
                        hypotheses.append({
                            "regionRank": rank, "channel": channel, "polarity": polarity,
                            "direction": direction, "state": "HOLD_OCR_EVALUATION_ERROR", "detail": str(error),
                        })
                        continue
                    hypotheses.append({
                        "regionRank": rank,
                        "sourceRegionId": item.source_region_id,
                        "regionId": item.region.region_id,
                        "channel": channel,
                        "polarity": polarity,
                        "direction": direction,
                        "cropPath": crop_paths[channel],
                        "cropSha256": crop_hashes[channel],
                        "angleDegrees": float(item.region.angle_degrees),
                        "centerX": float(item.region.center_x),
                        "centerY": float(item.region.center_y),
                        "imageFirstString": str(evaluated.get("imageFirstString", "")),
                        "proposedString": str(evaluated.get("proposedString", "")),
                        "selectionScore": float(evaluated["selectionScore"]),
                        "boundaryComplete": bool(evaluated["boundaryComplete"]),
                        "checksumValid": bool(evaluated["checksumValid"]),
                        "grid": {key: int(evaluated[key]) for key in ("x", "y", "cellWidth", "cellHeight")},
                        "checksumUsedForImageFirst": False,
                    })
    eligible = [row for row in hypotheses if "selectionScore" in row]
    eligible.sort(key=lambda row: (-float(row["selectionScore"]), str(row["imageFirstString"])))
    best = eligible[0] if eligible else None
    close_strings = sorted({
        str(row["imageFirstString"]) for row in eligible
        if best is not None and bool(row["boundaryComplete"])
        and float(row["selectionScore"]) >= float(best["selectionScore"]) - AMBIGUITY_SCORE_DELTA
    })
    any_structure_pass = any(bool(row.get("passed")) for row in localization)
    if best is None:
        state = "HOLD_SCRIBE_NOT_LOCALIZED"
    elif not any_structure_pass:
        state = "HOLD_SCRIBE_NOT_LOCALIZED"
    elif not bool(best["boundaryComplete"]):
        state = "HOLD_SCRIBE_GRID_BOUNDARY_INCOMPLETE"
    elif float(best["selectionScore"]) < MINIMUM_IMAGE_SCORE:
        state = "HOLD_SCRIBE_IMAGE_SCORE_BELOW_FROZEN_MINIMUM"
    elif len(close_strings) != 1:
        state = "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS"
    else:
        state = "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
    return {
        "schema": "argos_opencv_scribe_crop_sweep_result_v1",
        "revision": REVISION,
        "state": state,
        "identity": job["identity"],
        "imageFirstString": "" if best is None else str(best["imageFirstString"]),
        "proposedString": "" if best is None else str(best["proposedString"]),
        "identityAccepted": False,
        "bestHypothesis": best,
        "closeImageFirstStrings": close_strings,
        "hypotheses": hypotheses,
        "localization": {
            "discoveredCandidateCount": len(localization),
            "promotedCandidateCount": len(promoted),
            "anyStructurePass": any_structure_pass,
            "rows": localization,
            "angleOffsetsDegrees": list(ANGLE_OFFSETS),
            "normalOffsetsPixels": list(NORMAL_OFFSETS),
            "windowWidth": int(WINDOW_WIDTH),
            "windowHeight": int(WINDOW_HEIGHT),
            "lineGridOrNotchAlignmentUsed": False,
            "syntheticDotReconstructionUsed": False,
        },
        "provenance": {
            "providerPath": str(provider_path),
            "providerSha256": sha256_file(provider_path),
            "readerModified": False,
            "referenceLibraryModified": False,
            "checksumUsedForImageFirst": False,
            "sources": {"bf": bf_evidence, "df": df_evidence},
            "references": reference_evidence,
        },
        "authority": {
            "reviewOnly": True,
            "identityAcceptanceAuthorized": False,
            "automaticReferenceAdmissionAuthorized": False,
            "trainingAuthorized": False,
            "activationAuthorized": False,
            "xmlAuthorized": False,
            "productionAuthorized": False,
        },
    }


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True, type=Path)
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args(list(argv))
    if args.result.exists() or args.output_root.exists():
        raise FileExistsError(args.result if args.result.exists() else args.output_root)
    result = analyze(read_json(args.job), args.provider.resolve(), args.output_root.resolve())
    write_json_new(args.result.resolve(), result)
    print(json.dumps({
        "state": result["state"], "imageFirstString": result["imageFirstString"],
        "resultPath": str(args.result.resolve()),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
