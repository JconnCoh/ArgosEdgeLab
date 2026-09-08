#!/usr/bin/env python3
"""Freeze target-blind canonical-Z run-geometry development evidence.

The sole real Z reference is validation-only: its manifest row is counted and
skipped before its path is resolved, hashed, or decoded.  Thresholds are
evaluated against generated Z morphology and every available real and rendered
non-Z glyph.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
R18H_PATH = ROOT / "OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py"
BASE_MANIFEST_PATH = (
    ROOT
    / "SCRIBE_REVIEW_ONLY/scratch/"
    "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
    "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
)
SUPPLEMENTAL_MANIFEST_PATH = (
    ROOT / "OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
)
GATE_PATH = HERE / "R18ZU_CANONICAL_Z_DEVELOPMENT_GATE_V2.json"

EXPECTED_R18H_SHA256 = "3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD"
EXPECTED_BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256 = "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD"

TOP_WIDTH_MINIMUM = 0.75
BOTTOM_WIDTH_MINIMUM = 0.75
MIDDLE_WIDTH_MAXIMUM = 0.45
SIGNED_CENTER_DRIFT_MINIMUM = 0.20
SIGNED_CENTER_CORRELATION_MAXIMUM = -0.55
SINGLE_RUN_BAND_FRACTION_MINIMUM = 0.75
INTERIOR_RUN_COUNT_MAXIMUM = 2
WIDE_MIDDLE_BAND_COUNT_MAXIMUM = 0
VERTICAL_STEM_BAND_COUNT_MAXIMUM = 2


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def read_object(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(path)
    return value


def run_counts(rows: np.ndarray) -> np.ndarray:
    return np.rint(rows[:, 0] * 4.0).astype(np.int32)


def maximum_run_widths(rows: np.ndarray) -> np.ndarray:
    return np.max(rows[:, (2, 4, 6, 8)], axis=1)


def assess_canonical_z_run_geometry(descriptor: np.ndarray) -> dict[str, Any]:
    values = np.asarray(descriptor, dtype=np.float64)
    if (
        values.shape != (189,)
        or not np.all(np.isfinite(values))
        or float(np.min(values)) < 0.0
        or float(np.max(values)) > 1.0
    ):
        return {"passed": False, "complete": False, "reason": "INVALID_DESCRIPTOR"}
    horizontal = values[:108].reshape(12, 9)
    vertical = values[108:].reshape(9, 9)
    h_counts = run_counts(horizontal)
    v_counts = run_counts(vertical)
    first_widths = horizontal[:, 2]
    centers = horizontal[:, 1]
    center_window = centers[1:9]
    correlation = (
        float(np.corrcoef(np.arange(8, dtype=np.float64), center_window)[0, 1])
        if float(np.ptp(center_window)) > 1e-12
        else 1.0
    )
    evidence = {
        "complete": True,
        "topWidth": float(np.max(first_widths[0:3])),
        "bottomWidth": float(np.max(first_widths[9:12])),
        "middleMaximumWidth": float(np.max(first_widths[3:7])),
        "signedCenterDrift": float(np.mean(centers[1:4]) - np.mean(centers[6:9])),
        "signedCenterCorrelation": correlation,
        "singleRunBandFraction": float(np.mean(h_counts <= 1)),
        "maximumInteriorRunCount": int(np.max(h_counts[1:9])),
        "wideMiddleBandCount": int(np.count_nonzero(first_widths[2:8] >= 0.48)),
        "verticalStemBandCount": int(np.count_nonzero(
            (v_counts == 1) & (vertical[:, 2] >= 0.80)
        )),
    }
    evidence["passed"] = bool(
        evidence["topWidth"] >= TOP_WIDTH_MINIMUM
        and evidence["bottomWidth"] >= BOTTOM_WIDTH_MINIMUM
        and evidence["middleMaximumWidth"] <= MIDDLE_WIDTH_MAXIMUM
        and evidence["signedCenterDrift"] >= SIGNED_CENTER_DRIFT_MINIMUM
        and evidence["signedCenterCorrelation"] <= SIGNED_CENTER_CORRELATION_MAXIMUM
        and evidence["singleRunBandFraction"] >= SINGLE_RUN_BAND_FRACTION_MINIMUM
        and evidence["maximumInteriorRunCount"] <= INTERIOR_RUN_COUNT_MAXIMUM
        and evidence["wideMiddleBandCount"] <= WIDE_MIDDLE_BAND_COUNT_MAXIMUM
        and evidence["verticalStemBandCount"] <= VERTICAL_STEM_BAND_COUNT_MAXIMUM
    )
    return evidence


def safe_child(parent: Path, relative: str) -> Path:
    path = (parent / Path(relative.replace("\\", "/"))).resolve()
    if parent.resolve() not in path.parents:
        raise ValueError("Reference path escaped its manifest root.")
    return path


def load_real_non_z(r18h: Any) -> tuple[list[tuple[str, np.ndarray]], dict[str, Any]]:
    r11 = r18h.R17D.R17C.R17B._load_r11()
    base = read_object(BASE_MANIFEST_PATH)
    supplemental = read_object(SUPPLEMENTAL_MANIFEST_PATH)
    descriptors: list[tuple[str, np.ndarray]] = []
    skipped: list[dict[str, str]] = []

    for manifest_path, manifest, expected_count in (
        (BASE_MANIFEST_PATH, base, 456),
        (SUPPLEMENTAL_MANIFEST_PATH, supplemental, 19),
    ):
        references = list(manifest.get("references", []))
        if len(references) != expected_count:
            raise AssertionError(f"Unexpected reference count: {manifest_path}")
        for row in references:
            label = str(row.get("label", "")).upper()[:1]
            if label == "Z":
                if manifest_path != SUPPLEMENTAL_MANIFEST_PATH:
                    raise AssertionError("Unexpected Z in the base bank.")
                skipped.append({
                    "label": label,
                    "declaredRelativePath": str(row.get("relativePath", "")),
                    "declaredSha256": str(row.get("sha256", "")).upper(),
                })
                continue
            path = safe_child(manifest_path.parent, str(row["relativePath"]))
            if sha256_file(path) != str(row["sha256"]).upper():
                raise AssertionError(f"Reference hash mismatch: {path}")
            prototype = r18h._run_structure_prototype(
                r11, label, str(row.get("physicalIdentity", "")), path
            )
            descriptors.append((label, prototype.descriptor))
    if len(descriptors) != 474 or len(skipped) != 1:
        raise AssertionError("The target-blind real-bank partition changed.")
    return descriptors, {
        "realNonZReferenceCount": len(descriptors),
        "skippedValidationOnlyZRows": skipped,
        "validationOnlyZBytesResolved": False,
        "validationOnlyZBytesHashed": False,
        "validationOnlyZBytesDecoded": False,
    }


def describe_synthetic(r18h: Any, image: np.ndarray) -> np.ndarray:
    descriptor = r18h.describe_run_structure_exact(
        image, 0, 0, int(image.shape[1]), int(image.shape[0])
    )
    if descriptor is None:
        raise AssertionError("Synthetic descriptor failed.")
    return descriptor


def hershey_glyph(
    label: str, font: int, thickness: int, dx: int, blur: int
) -> np.ndarray:
    height, width = 112, 80
    image = np.zeros((height, width), dtype=np.uint8)
    scale = 2.25
    (text_width, text_height), _ = cv2.getTextSize(label, font, scale, thickness)
    x = (width - text_width) // 2 + dx
    y = (height + text_height) // 2
    cv2.putText(image, label, (x, y), font, scale, 255, thickness, cv2.LINE_AA)
    if blur:
        image = cv2.GaussianBlur(image, (blur, blur), 0)
    return image


def line_z(thickness: int, margin: int, inset: int, skew: int) -> np.ndarray:
    height, width = 112, 80
    image = np.zeros((height, width), dtype=np.uint8)
    top, bottom = 14 + inset, height - 15 - inset
    left, right = 9 + margin, width - 10 - margin
    cv2.line(image, (left, top), (right, top), 255, thickness, cv2.LINE_AA)
    cv2.line(
        image,
        (max(left, right + skew), top),
        (min(right, left + skew), bottom),
        255,
        thickness,
        cv2.LINE_AA,
    )
    cv2.line(image, (left, bottom), (right, bottom), 255, thickness, cv2.LINE_AA)
    return cv2.GaussianBlur(image, (3, 3), 0)


def dotted_z(
    rows: int,
    columns: int,
    radius: int,
    x_spacing: int,
    y_spacing: int,
    jitter: float,
    sigma: float,
    bridge: bool,
) -> np.ndarray:
    height, width = 224, 160
    image = np.zeros((height, width), dtype=np.float32)
    x0 = (width - 1 - (columns - 1) * x_spacing) / 2.0
    x1 = x0 + (columns - 1) * x_spacing
    y0 = (height - 1 - (rows - 1) * y_spacing) / 2.0
    y1 = y0 + (rows - 1) * y_spacing
    points: list[tuple[float, float]] = []
    for column in range(columns):
        points.extend(((x0 + column * x_spacing, y0), (x0 + column * x_spacing, y1)))
    for row in range(1, rows - 1):
        fraction = row / (rows - 1)
        points.append((x1 * (1.0 - fraction) + x0 * fraction, y0 + row * y_spacing))
    for index, (x, y) in enumerate(points):
        offset_x = jitter * ((index * 17 % 5) - 2) / 2.0
        offset_y = jitter * ((index * 11 % 5) - 2) / 2.0
        cv2.circle(
            image,
            (int(round(x + offset_x)), int(round(y + offset_y))),
            radius,
            255.0,
            -1,
            lineType=cv2.LINE_AA,
        )
    if bridge:
        cv2.line(
            image,
            (int(round(x1)), int(round(y0))),
            (int(round(x0)), int(round(y1))),
            255.0,
            int(max(1, radius // 2)),
            lineType=cv2.LINE_AA,
        )
    if sigma:
        image = cv2.GaussianBlur(image, (0, 0), sigmaX=sigma, sigmaY=sigma)
    return image


def evaluate_development(r18h: Any) -> dict[str, Any]:
    real_rows, partition = load_real_non_z(r18h)
    real_false = [label for label, descriptor in real_rows if assess_canonical_z_run_geometry(descriptor)["passed"]]

    fonts = (
        cv2.FONT_HERSHEY_SIMPLEX,
        cv2.FONT_HERSHEY_DUPLEX,
        cv2.FONT_HERSHEY_COMPLEX,
        cv2.FONT_HERSHEY_TRIPLEX,
    )
    labels = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    rendered_total = rendered_false = rendered_z_total = rendered_z_pass = 0
    false_labels: dict[str, int] = {}
    for label in labels:
        for font in fonts:
            for thickness in range(2, 11):
                for dx in (-3, 0, 3):
                    for blur in (0, 3):
                        descriptor = describe_synthetic(
                            r18h, hershey_glyph(label, font, thickness, dx, blur)
                        )
                        passed = bool(assess_canonical_z_run_geometry(descriptor)["passed"])
                        if label == "Z":
                            rendered_z_total += 1
                            rendered_z_pass += int(passed)
                        else:
                            rendered_total += 1
                            rendered_false += int(passed)
                            if passed:
                                false_labels[label] = false_labels.get(label, 0) + 1

    line_total = line_pass = 0
    for thickness in range(2, 12):
        for margin in (6, 10, 14):
            for inset in (0, 6, 12):
                for skew in (-5, 0, 5):
                    descriptor = describe_synthetic(
                        r18h, line_z(thickness, margin, inset, skew)
                    )
                    line_total += 1
                    line_pass += int(assess_canonical_z_run_geometry(descriptor)["passed"])

    dotted_totals = {False: 0, True: 0}
    dotted_passes = {False: 0, True: 0}
    for rows in (7, 9, 11):
        for columns in (5, 7):
            for radius in range(2, 7):
                for x_spacing in (6, 8, 10, 12, 14):
                    for y_spacing in (8, 10, 12, 14, 16):
                        for jitter in (0.0, 0.5, 1.0):
                            for sigma in (0.0, 0.6, 1.2):
                                for bridge in (False, True):
                                    descriptor = describe_synthetic(
                                        r18h,
                                        dotted_z(
                                            rows, columns, radius, x_spacing,
                                            y_spacing, jitter, sigma, bridge,
                                        ),
                                    )
                                    dotted_totals[bridge] += 1
                                    dotted_passes[bridge] += int(
                                        assess_canonical_z_run_geometry(descriptor)["passed"]
                                    )

    result = {
        **partition,
        "realNonZFalseAcceptanceCount": len(real_false),
        "realNonZFalseAcceptanceLabels": real_false,
        "renderedNonZVariantCount": rendered_total,
        "renderedNonZFalseAcceptanceCount": rendered_false,
        "renderedNonZFalseAcceptanceByLabel": false_labels,
        "renderedZVariantCount": rendered_z_total,
        "renderedZAcceptanceCount": rendered_z_pass,
        "lineZVariantCount": line_total,
        "lineZAcceptanceCount": line_pass,
        "dottedZUnbridgedVariantCount": dotted_totals[False],
        "dottedZUnbridgedAcceptanceCount": dotted_passes[False],
        "dottedZBridgedVariantCount": dotted_totals[True],
        "dottedZBridgedAcceptanceCount": dotted_passes[True],
    }
    result["passed"] = bool(
        len(real_false) == 0
        and rendered_false == 0
        and line_pass >= 180
        and dotted_passes[False] >= 3500
        and dotted_passes[True] >= 3600
    )
    return result


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-gate", action="store_true")
    args = parser.parse_args(list(argv))
    pins = {
        str(R18H_PATH): EXPECTED_R18H_SHA256,
        str(BASE_MANIFEST_PATH): EXPECTED_BASE_MANIFEST_SHA256,
        str(SUPPLEMENTAL_MANIFEST_PATH): EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256,
    }
    for path_text, expected in pins.items():
        if sha256_file(Path(path_text)) != expected:
            raise AssertionError(f"Frozen dependency changed: {path_text}")
    r18h = load_module("argos_scribe_r18h_for_r18zu_development", R18H_PATH)
    evidence = evaluate_development(r18h)
    gate = {
        "schema": "argos_opencv_scribe_r18zu_canonical_z_development_gate_v2",
        "state": "PASS_TARGET_BLIND_CANONICAL_Z_DEVELOPMENT" if evidence["passed"] else "FAIL",
        "developmentScriptSha256": sha256_file(Path(__file__)),
        "thresholds": {
            "topWidthMinimum": TOP_WIDTH_MINIMUM,
            "bottomWidthMinimum": BOTTOM_WIDTH_MINIMUM,
            "middleWidthMaximum": MIDDLE_WIDTH_MAXIMUM,
            "signedCenterDriftMinimum": SIGNED_CENTER_DRIFT_MINIMUM,
            "signedCenterCorrelationMaximum": SIGNED_CENTER_CORRELATION_MAXIMUM,
            "singleRunBandFractionMinimum": SINGLE_RUN_BAND_FRACTION_MINIMUM,
            "interiorRunCountMaximum": INTERIOR_RUN_COUNT_MAXIMUM,
            "wideMiddleBandCountMaximum": WIDE_MIDDLE_BAND_COUNT_MAXIMUM,
            "verticalStemBandCountMaximum": VERTICAL_STEM_BAND_COUNT_MAXIMUM,
        },
        "dependencySha256": pins,
        "evidence": evidence,
        "runtimeTruthUsed": False,
        "checksumUsed": False,
        "targetIdentityUsed": False,
    }
    print(json.dumps(gate, sort_keys=True))
    if not evidence["passed"]:
        return 2
    if args.write_gate:
        write_json_new(GATE_PATH, gate)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
