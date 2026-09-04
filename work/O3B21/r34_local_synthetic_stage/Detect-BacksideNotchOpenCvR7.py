#!/usr/bin/env python3
"""Review-only full-360 backside notch development detector."""

from __future__ import annotations

import argparse
import gc
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import cv2
import numpy as np


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def circle_fit(points: np.ndarray) -> tuple[float, float, float]:
    xy = points.reshape(-1, 2).astype(np.float64)
    matrix = np.column_stack((2.0 * xy[:, 0], 2.0 * xy[:, 1], np.ones(len(xy))))
    target = np.sum(xy * xy, axis=1)
    cx, cy, constant = np.linalg.lstsq(matrix, target, rcond=None)[0]
    radius = math.sqrt(max(0.0, constant + cx * cx + cy * cy))
    return float(cx), float(cy), float(radius)


def circular_blur(values: np.ndarray, sigma: float) -> np.ndarray:
    tripled = np.concatenate((values, values, values)).astype(np.float32).reshape(1, -1)
    smooth = cv2.GaussianBlur(tripled, (0, 0), sigmaX=sigma).reshape(-1)
    size = len(values)
    return smooth[size : 2 * size]


def runs(mask: np.ndarray) -> list[np.ndarray]:
    indices = np.flatnonzero(mask)
    if not len(indices):
        return []
    groups = [group for group in np.split(indices, np.flatnonzero(np.diff(indices) > 1) + 1)]
    if len(groups) > 1 and groups[0][0] == 0 and groups[-1][-1] == len(mask) - 1:
        groups[0] = np.concatenate((groups[-1] - len(mask), groups[0]))
        groups.pop()
    return groups


def candidate_shape(depths: np.ndarray) -> tuple[float, float, float]:
    if depths.size < 2:
        return 0.0, 1.0, 0.0
    maximum = float(np.max(depths))
    tip = int(np.argmax(depths))
    center = (depths.size - 1) / 2.0
    tip_offset = abs(tip - center) / max(center, 1.0)
    pair_count = min(tip + 1, depths.size - tip)
    if pair_count >= 2 and maximum > 0.0:
        left = depths[tip - pair_count + 1 : tip + 1]
        right = depths[tip : tip + pair_count][::-1]
        symmetry = max(0.0, 1.0 - float(np.mean(np.abs(left - right))) / maximum)
    else:
        symmetry = 0.0
    rising = np.diff(depths[: tip + 1]) if tip > 0 else np.asarray([], dtype=np.float64)
    falling = np.diff(depths[tip:]) if tip < depths.size - 1 else np.asarray([], dtype=np.float64)
    consistent = int(np.sum(rising >= -0.5)) + int(np.sum(falling <= 0.5))
    slope_count = int(rising.size + falling.size)
    slope_consistency = float(consistent / slope_count) if slope_count else 0.0
    return symmetry, tip_offset, slope_consistency


def manufactured_candidate(row: dict[str, float]) -> bool:
    return (
        0.9 <= row["widthDegrees"] <= 3.2
        and row["symmetryScore"] >= 0.72
        and row["tipCenterOffsetFraction"] <= 0.70
        and row["slopeConsistencyFraction"] >= 0.55
    )


def wafer_mask(gray: np.ndarray) -> tuple[np.ndarray, np.ndarray, str]:
    representations = [("RAW", gray)]
    representations.append(("CLAHE", cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(gray)))
    candidates: list[tuple[str, np.ndarray]] = []
    for representation_name, representation in representations:
        blurred = cv2.GaussianBlur(representation, (0, 0), 2.0)
        _, normal = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        candidates.extend(
            (
                (f"{representation_name}_OTSU_LIGHT", normal),
                (f"{representation_name}_OTSU_DARK", cv2.bitwise_not(normal)),
            )
        )
        for percentile in (15, 30, 50, 70, 85):
            level = float(np.percentile(blurred, percentile))
            candidates.append((f"{representation_name}_P{percentile}_LIGHT", np.where(blurred >= level, 255, 0).astype(np.uint8)))
            candidates.append((f"{representation_name}_P{percentile}_DARK", np.where(blurred <= level, 255, 0).astype(np.uint8)))
    height, width = gray.shape
    center = (width / 2.0, height / 2.0)
    best: tuple[float, np.ndarray, np.ndarray, str] | None = None
    for close_fraction in (0.006, 0.018):
        kernel_size = max(7, int(round(max(gray.shape) * close_fraction)) | 1)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
        for method, thresholded in candidates:
            closed = cv2.morphologyEx(thresholded, cv2.MORPH_CLOSE, kernel)
            contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            for contour in contours:
                area = cv2.contourArea(contour)
                fraction = area / float(width * height)
                perimeter = cv2.arcLength(contour, True)
                circularity = 0.0 if perimeter <= 0.0 else 4.0 * math.pi * area / (perimeter * perimeter)
                contains_center = cv2.pointPolygonTest(contour, center, False) >= 0
                if not contains_center or fraction < 0.25 or fraction > 0.95 or circularity < 0.45:
                    continue
                score = 4.0 + 2.0 * circularity - abs(fraction - 0.65)
                if best is None or score > best[0]:
                    filled = np.zeros_like(gray)
                    cv2.drawContours(filled, [contour], -1, 255, cv2.FILLED)
                    best = (score, filled, contour, f"{method}_CLOSE_{close_fraction:.3f}")
    if best is None:
        raise RuntimeError("No central backside wafer silhouette qualified.")
    return best[1], best[2], best[3]


def robust_circle(contour: np.ndarray) -> tuple[float, float, float]:
    points = contour.reshape(-1, 2).astype(np.float64)
    cx, cy, radius = circle_fit(points)
    for _ in range(4):
        radial = np.hypot(points[:, 0] - cx, points[:, 1] - cy)
        residual = radial - radius
        median = float(np.median(residual))
        mad = float(np.median(np.abs(residual - median)))
        bound = max(2.0, 3.5 * 1.4826 * mad)
        retained = points[(residual >= -bound) & (residual <= bound)]
        if len(retained) < 500:
            break
        cx, cy, radius = circle_fit(retained)
    return cx, cy, radius


def radial_profile(mask: np.ndarray, cx: float, cy: float, radius: float) -> tuple[np.ndarray, np.ndarray, dict[str, float]]:
    angles = np.linspace(0.0, 2.0 * math.pi, 3600, endpoint=False, dtype=np.float32)
    band = max(30.0, radius * 0.06)
    samples = np.linspace(radius - band, radius + band * 0.3, 240, dtype=np.float32)
    map_x = cx + np.cos(angles)[:, None] * samples[None, :]
    map_y = cy + np.sin(angles)[:, None] * samples[None, :]
    polar = cv2.remap(mask, map_x, map_y, cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    inside = polar > 0
    valid = np.any(inside, axis=1)
    coverage = float(np.mean(valid))
    unsupported_runs = runs(~valid)
    maximum_gap_samples = max((len(group) for group in unsupported_runs), default=0)
    maximum_gap_degrees = maximum_gap_samples * 0.1
    if coverage < 0.80 or maximum_gap_degrees > 12.0:
        raise RuntimeError(
            f"Backside perimeter coverage is incomplete: supported={coverage:.4f}, "
            f"maximumUnsupportedRunDegrees={maximum_gap_degrees:.1f}."
        )
    reversed_index = np.argmax(inside[:, ::-1], axis=1)
    last_index = inside.shape[1] - 1 - reversed_index
    radii = np.full(len(angles), np.nan, dtype=np.float32)
    radii[valid] = samples[last_index[valid]]
    if not np.all(valid):
        supported = np.flatnonzero(valid)
        extended_indices = np.concatenate((supported - len(angles), supported, supported + len(angles)))
        extended_radii = np.tile(radii[supported], 3)
        radii[~valid] = np.interp(np.flatnonzero(~valid), extended_indices, extended_radii)
    return angles, radii, {
        "supportedFraction": coverage,
        "unsupportedSampleCount": int(np.sum(~valid)),
        "maximumUnsupportedRunDegrees": maximum_gap_degrees,
        "boundedInterpolationApplied": bool(not np.all(valid)),
    }


def candidates_from_profile(radii: np.ndarray) -> tuple[np.ndarray, float, list[dict[str, float]]]:
    narrow = circular_blur(radii, 3.0)
    baseline = circular_blur(radii, 80.0)
    depth = baseline - narrow
    median = float(np.median(depth))
    mad = float(np.median(np.abs(depth - median)))
    threshold = max(1.25, median + 4.0 * 1.4826 * mad)
    found: list[dict[str, float]] = []
    for group in runs(depth >= threshold):
        normalized = np.mod(group, len(depth))
        if len(normalized) < 3:
            continue
        local = depth[normalized]
        tip = int(normalized[int(np.argmax(local))])
        width = len(normalized) * 0.1
        if width > 15.0:
            continue
        left_depth = float(local[0])
        right_depth = float(local[-1])
        symmetry, tip_offset, slope_consistency = candidate_shape(local)
        row = {
                "centerAngleDegrees": tip * 0.1,
                "widthDegrees": width,
                "maximumDepthPx": float(np.max(local)),
                "meanDepthPx": float(np.mean(local)),
                "shoulderDepthDifferencePx": abs(left_depth - right_depth),
                "sampleCount": int(len(normalized)),
                "symmetryScore": symmetry,
                "tipCenterOffsetFraction": tip_offset,
                "slopeConsistencyFraction": slope_consistency,
            }
        row["manufacturedMorphologyPassed"] = manufactured_candidate(row)
        found.append(row)
    found.sort(key=lambda row: (-row["maximumDepthPx"], row["centerAngleDegrees"]))
    return depth, threshold, found[:24]


def analyze(path: Path, channel: str, maximum_dimension: int) -> tuple[dict, np.ndarray]:
    native = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if native is None:
        raise RuntimeError(f"{channel} decode failed: {path}")
    native_shape = [int(native.shape[0]), int(native.shape[1])]
    scale = min(1.0, maximum_dimension / max(native.shape))
    gray = cv2.resize(native, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    del native
    gc.collect()
    mask, contour, mask_method = wafer_mask(gray)
    cx, cy, radius = robust_circle(contour)
    angles, radii, coverage = radial_profile(mask, cx, cy, radius)
    depth, threshold, found = candidates_from_profile(radii)
    for row in found:
        row["maximumDepthNativePx"] = row["maximumDepthPx"] / scale
    enhanced = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(gray)
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    cv2.circle(overlay, (round(cx), round(cy)), round(radius), (255, 180, 0), 2, cv2.LINE_AA)
    measured = np.column_stack((cx + np.cos(angles) * radii, cy + np.sin(angles) * radii)).round().astype(np.int32)
    cv2.polylines(overlay, [measured.reshape(-1, 1, 2)], True, (255, 255, 0), 2, cv2.LINE_AA)
    for index, row in enumerate(found, start=1):
        angle = math.radians(row["centerAngleDegrees"])
        point = (round(cx + radius * math.cos(angle)), round(cy + radius * math.sin(angle)))
        cv2.circle(overlay, point, 8, (0, 0, 255), 2, cv2.LINE_AA)
        cv2.putText(overlay, f"{channel}{index}", (point[0] + 10, point[1] - 6), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 0, 255), 2, cv2.LINE_AA)
    result = {
        "channel": channel,
        "nativeShape": native_shape,
        "analysisShape": [int(gray.shape[0]), int(gray.shape[1])],
        "analysisScale": scale,
        "waferMaskMethod": mask_method,
        "patternSuppression": "FILLED_EXTERNAL_WAFER_CONTOUR",
        "circle": {"centerX": cx, "centerY": cy, "radius": radius},
        "perimeterCoverage": coverage,
        "profileThresholdPx": threshold,
        "profileMaximumDepthPx": float(np.max(depth)),
        "candidateCount": len(found),
        "candidates": found,
    }
    return result, overlay


def load_radial_engine(path: Path, expected_sha256: str):
    if sha256_file(path) != expected_sha256.upper():
        raise RuntimeError(f"Frozen radial engine hash changed: {path}")
    specification = importlib.util.spec_from_file_location("argos_frozen_r6_radial", path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"Frozen radial engine could not be loaded: {path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def analyze_radial(
    path: Path,
    channel: str,
    maximum_dimension: int,
    radial_engine,
    radial_parameters: dict,
) -> tuple[dict, np.ndarray]:
    native = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if native is None:
        raise RuntimeError(f"{channel} decode failed: {path}")
    native_shape = [int(native.shape[0]), int(native.shape[1])]
    parameters = radial_engine.Parameters.from_json(radial_parameters)
    radial = radial_engine.localize_channel(native, channel, parameters)
    scale = min(1.0, maximum_dimension / max(native.shape))
    gray = cv2.resize(native, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    enhanced = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(gray)
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    fit = radial.get("fit", {})
    if not radial.get("qualified") or not fit:
        raise RuntimeError(
            f"Frozen R6 {channel} radial channel did not qualify: {radial.get('state', 'UNKNOWN')}"
        )
    circle = {
        "centerX": float(fit["centerX"]) * scale,
        "centerY": float(fit["centerY"]) * scale,
        "radius": float(fit["radius"]) * scale,
    }
    cv2.circle(
        overlay,
        (round(circle["centerX"]), round(circle["centerY"])),
        round(circle["radius"]),
        (255, 180, 0),
        2,
        cv2.LINE_AA,
    )
    native_radii = np.arange(
        float(fit["radius"]) - parameters.refine_radial_half_width_px,
        float(fit["radius"]) + parameters.refine_radial_half_width_px + 1,
        1.0,
        dtype=np.float32,
    )
    trace_angles, trace_profiles = radial_engine.sample_radial_profiles(
        native,
        float(fit["centerX"]), float(fit["centerY"]), native_radii, parameters.refine_angle_samples,
    )
    trace_boundary, _, trace_supported, _ = radial_engine.choose_outer_dark_boundary(
        trace_profiles, native_radii, 1.0, parameters
    )
    trace_points = np.column_stack((
        (float(fit["centerX"]) + np.cos(trace_angles) * trace_boundary) * scale,
        (float(fit["centerY"]) + np.sin(trace_angles) * trace_boundary) * scale,
    )).round().astype(np.int32)
    for group in np.split(np.flatnonzero(trace_supported), np.flatnonzero(np.diff(np.flatnonzero(trace_supported)) > 1) + 1):
        if len(group) >= 2:
            cv2.polylines(overlay, [trace_points[group].reshape(-1, 1, 2)], False, (255, 255, 0), 2, cv2.LINE_AA)
    del native, trace_profiles
    gc.collect()
    candidates = []
    for index, source in enumerate(radial.get("candidates", []), start=1):
        row = dict(source)
        row["maximumDepthAnalysisPx"] = float(row["maximumDepthPx"]) * scale
        row["manufacturedMorphologyPassed"] = manufactured_candidate(row)
        candidates.append(row)
        angle = math.radians(float(row["centerAngleDegrees"]))
        point = (
            round(circle["centerX"] + circle["radius"] * math.cos(angle)),
            round(circle["centerY"] + circle["radius"] * math.sin(angle)),
        )
        cv2.circle(overlay, point, 8, (0, 0, 255), 2, cv2.LINE_AA)
        cv2.putText(
            overlay,
            f"{channel}{index}",
            (point[0] + 10, point[1] - 6),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (0, 0, 255),
            2,
            cv2.LINE_AA,
        )
    result = {
        "channel": channel,
        "nativeShape": native_shape,
        "analysisShape": [int(gray.shape[0]), int(gray.shape[1])],
        "analysisScale": scale,
        "waferMaskMethod": "FROZEN_R6_OUTERMOST_DARK_EXTERIOR_BOUNDARY",
        "patternSuppression": "FULL_360_OUTERMOST_DARK_EXTERIOR_BOUNDARY",
        "circle": circle,
        "profileThresholdPx": float(radial["candidateDepthThresholdPx"]) * scale,
        "profileMaximumDepthPx": max(
            [float(row["maximumDepthPx"]) * scale for row in candidates], default=0.0
        ),
        "candidateCount": len(candidates),
        "candidates": candidates,
        "radialQualification": {
            "state": radial["state"],
            "fit": radial["fit"],
            "search": radial["search"],
        },
    }
    return result, overlay


def circular_distance(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job")
    parser.add_argument("--bf")
    parser.add_argument("--df")
    parser.add_argument("--bf-sha256")
    parser.add_argument("--df-sha256")
    parser.add_argument("--output")
    parser.add_argument("--radial-engine")
    parser.add_argument("--radial-engine-sha256")
    parser.add_argument("--maximum-dimension", type=int, default=2400)
    args = parser.parse_args()
    radial_parameters = None
    if args.job:
        job = json.loads(Path(args.job).read_text(encoding="utf-8"))
        required = (
            "bf", "df", "bfSha256", "dfSha256", "output",
            "radialEngine", "radialEngineSha256", "radialParameters",
        )
        missing = [name for name in required if not job.get(name)]
        if missing:
            raise ValueError(f"Job is missing required values: {', '.join(missing)}")
        args.bf = job["bf"]
        args.df = job["df"]
        args.bf_sha256 = job["bfSha256"]
        args.df_sha256 = job["dfSha256"]
        args.output = job["output"]
        args.radial_engine = job["radialEngine"]
        args.radial_engine_sha256 = job["radialEngineSha256"]
        radial_parameters = job["radialParameters"]
        args.maximum_dimension = int(job.get("maximumDimension", args.maximum_dimension))
    elif not all((args.bf, args.df, args.bf_sha256, args.df_sha256, args.output, args.radial_engine, args.radial_engine_sha256)):
        parser.error("either --job or all direct BF/DF/hash/output/radial-engine arguments are required")
    if radial_parameters is None:
        parser.error("radial parameters are required through --job")
    bf_path, df_path, output = Path(args.bf), Path(args.df), Path(args.output)
    if output.exists():
        raise RuntimeError(f"Output already exists: {output}")
    for path, expected in ((bf_path, args.bf_sha256), (df_path, args.df_sha256)):
        actual = sha256_file(path)
        if actual != expected.upper():
            raise RuntimeError(f"Source hash changed: {path}")
    radial_engine = load_radial_engine(Path(args.radial_engine), args.radial_engine_sha256)
    output.mkdir(parents=False)
    review_paths: dict[str, Path] = {}
    for channel, path in (("BF", bf_path), ("DF", df_path)):
        native = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if native is None:
            raise RuntimeError(f"{channel} decode failed: {path}")
        scale = min(1.0, args.maximum_dimension / max(native.shape))
        small = cv2.resize(native, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
        enhanced = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(small)
        review_paths[channel] = output / f"{channel}_review.jpg"
        if not cv2.imwrite(str(review_paths[channel]), enhanced, [cv2.IMWRITE_JPEG_QUALITY, 90]):
            raise RuntimeError(f"{channel} review JPEG write failed.")
        del native, small, enhanced
        gc.collect()
    failures: list[dict[str, str]] = []
    analyses: dict[str, tuple[dict, np.ndarray]] = {}
    for channel, path in (("BF", bf_path), ("DF", df_path)):
        try:
            analyses[channel] = analyze_radial(
                path, channel, args.maximum_dimension, radial_engine, radial_parameters
            )
        except Exception as error:
            failures.append({"channel": channel, "stage": "WAFER_MASK_OR_RADIAL_PROFILE", "reason": str(error)})
    if failures:
        result = {
            "state": "HOLD_BACKSIDE_NOTCH_ANALYSIS_FAILED",
            "opencvVersion": cv2.__version__,
            "fullPerimeterInference": True,
            "knownNotchLocationConsumed": False,
            "patternSuppression": "FULL_360_OUTERMOST_DARK_EXTERIOR_BOUNDARY_BOTH_CHANNELS",
            "failures": failures,
            "completedChannels": {channel: row[0] for channel, row in analyses.items()},
            "pairedCandidateCount": 0,
            "pairedCandidates": [],
            "overlays": {"BFReview": str(review_paths["BF"]), "DFReview": str(review_paths["DF"])},
            "sourceMutationPerformed": False,
            "reviewOnly": True,
        }
        result_path = output / "RESULT.json"
        result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"state": result["state"], "result": str(result_path), "failures": failures, "overlays": result["overlays"]}))
        return 0
    bf, bf_overlay = analyses["BF"]
    df, df_overlay = analyses["DF"]
    pairs: list[dict[str, float]] = []
    for bf_row in bf["candidates"]:
        for df_row in df["candidates"]:
            if not bf_row["manufacturedMorphologyPassed"] or not df_row["manufacturedMorphologyPassed"]:
                continue
            difference = circular_distance(bf_row["centerAngleDegrees"], df_row["centerAngleDegrees"])
            if difference <= 1.5:
                pairs.append(
                    {
                        "bfAngleDegrees": bf_row["centerAngleDegrees"],
                        "dfAngleDegrees": df_row["centerAngleDegrees"],
                        "angleDifferenceDegrees": difference,
                        "meanAngleDegrees": (bf_row["centerAngleDegrees"] + ((df_row["centerAngleDegrees"] - bf_row["centerAngleDegrees"] + 540.0) % 360.0 - 180.0) / 2.0) % 360.0,
                        "bfWidthDegrees": bf_row["widthDegrees"],
                        "dfWidthDegrees": df_row["widthDegrees"],
                        "bfDepthNativePx": bf_row["maximumDepthNativePx"],
                        "dfDepthNativePx": df_row["maximumDepthPx"],
                        "bfTipDepthAnalysisPx": bf_row["maximumDepthPx"],
                        "dfTipDepthAnalysisPx": df_row["maximumDepthAnalysisPx"],
                        "score": min(bf_row["maximumDepthNativePx"], df_row["maximumDepthPx"]) / (1.0 + difference),
                    }
                )
    pairs.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    for index, pair in enumerate(pairs[:12], start=1):
        for overlay, geometry, angle_degrees, tip_depth in (
            (bf_overlay, bf["circle"], pair["bfAngleDegrees"], pair["bfTipDepthAnalysisPx"]),
            (df_overlay, df["circle"], pair["dfAngleDegrees"], pair["dfTipDepthAnalysisPx"]),
        ):
            angle = math.radians(angle_degrees)
            tip_radius = geometry["radius"] - tip_depth
            point = (round(geometry["centerX"] + tip_radius * math.cos(angle)), round(geometry["centerY"] + tip_radius * math.sin(angle)))
            cv2.circle(overlay, point, 13, (0, 255, 0), 3, cv2.LINE_AA)
            cv2.putText(overlay, f"P{index}", (point[0] + 14, point[1] + 16), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 255, 0), 2, cv2.LINE_AA)
    bf_overlay_path, df_overlay_path = output / "BF_overlay.png", output / "DF_overlay.png"
    bf_review_path, df_review_path = output / "BF_review.jpg", output / "DF_review.jpg"
    if not cv2.imwrite(str(bf_overlay_path), bf_overlay) or not cv2.imwrite(str(df_overlay_path), df_overlay):
        raise RuntimeError("Overlay write failed.")
    jpeg_options = [cv2.IMWRITE_JPEG_QUALITY, 90]
    if not cv2.imwrite(str(bf_review_path), bf_overlay, jpeg_options) or not cv2.imwrite(str(df_review_path), df_overlay, jpeg_options):
        raise RuntimeError("Review JPEG write failed.")
    result = {
        "state": "COMPLETE_BACKSIDE_NOTCH_DEVELOPMENT_DIAGNOSTIC",
        "opencvVersion": cv2.__version__,
        "fullPerimeterInference": True,
        "knownNotchLocationConsumed": False,
        "patternSuppression": "FULL_360_OUTERMOST_DARK_EXTERIOR_BOUNDARY_BOTH_CHANNELS",
        "bf": bf,
        "df": df,
        "bfEligibleCandidateCount": sum(bool(row["manufacturedMorphologyPassed"]) for row in bf["candidates"]),
        "dfEligibleCandidateCount": sum(bool(row["manufacturedMorphologyPassed"]) for row in df["candidates"]),
        "pairedCandidateCount": len(pairs),
        "pairedCandidates": pairs[:12],
        "overlays": {
            "BF": str(bf_overlay_path), "DF": str(df_overlay_path),
            "BFReview": str(bf_review_path), "DFReview": str(df_review_path),
        },
        "sourceMutationPerformed": False,
        "reviewOnly": True,
    }
    result_path = output / "RESULT.json"
    result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"state": result["state"], "result": str(result_path), "pairedCandidateCount": len(pairs), "topPairs": pairs[:5], "overlays": result["overlays"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
