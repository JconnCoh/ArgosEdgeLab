#!/usr/bin/env python3
"""R26 full-perimeter BF resampling from qualified DF geometry over frozen R25."""

from __future__ import annotations

import gc
import importlib.util
from pathlib import Path
import sys

import cv2
import numpy as np


R25_SHA256 = "6A7977E4DAFE692FCE6E7DE4740C94EE66D5F79ECD62FDF190CB5EE8E4862274"


def load_r25():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R25.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR25.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r25_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R25 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R24.R23.R21.BASE.sha256_file(path) != R25_SHA256:
        raise RuntimeError(f"Frozen R25 detector hash changed: {path}")
    return module


R25 = load_r25()
R23 = R25.R24.R23
R22 = R23.R22
R21 = R23.R21
ORIGINAL_R25_PAIR = R25.pair_candidates


def df_geometry_bf_candidates(bf: dict, df: dict) -> tuple[list[dict], dict]:
    native = cv2.imread(str(R22.LAST_PATH["BF"]), cv2.IMREAD_GRAYSCALE)
    if native is None:
        raise RuntimeError("DF-geometry BF full-perimeter decode failed.")
    engine = R21.R17.BASE_RADIAL
    parameter_values = R21.R17._PARAMETERS
    parameters = engine.Parameters.from_json(parameter_values)
    fit = df["radialQualification"]["fit"]
    radii = np.arange(
        float(fit["radius"]) - parameters.refine_radial_half_width_px,
        float(fit["radius"]) + parameters.refine_radial_half_width_px + 1.0,
        1.0,
        dtype=np.float32,
    )
    angles, profiles = engine.sample_radial_profiles(
        native, float(fit["centerX"]), float(fit["centerY"]),
        radii, parameters.refine_angle_samples,
    )
    boundary, _, supported, floor = engine.choose_outer_dark_boundary(
        profiles, radii, 1.0, parameters
    )
    angle_degrees = np.rad2deg(angles) % 360.0
    spans = list(bf["holderExclusion"]["spans"])
    holder = np.asarray(
        [R22.angle_in_holder(float(angle), spans, 0.0) for angle in angle_degrees],
        dtype=bool,
    )
    supported &= ~holder
    supported_fraction = float(np.mean(supported))
    minimum_coverage = float(parameter_values["minimumAngularCoverageFraction"])
    diagnostic = {
        "state": "HOLD_DF_GEOMETRY_BF_FULL_PERIMETER_NOT_QUALIFIED",
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "dfCandidateAngleConsumed": False,
        "bfSourcePixelsUsed": True,
        "dfGeometryUsed": True,
        "holderExclusionSource": "BF_CHANNEL_LOCAL_FROZEN_SPANS",
        "supportedFractionAfterHolderExclusion": supported_fraction,
        "minimumSupportedFraction": minimum_coverage,
        "adaptiveContrastFloor": float(floor),
    }
    if supported_fraction < minimum_coverage or int(supported.sum()) < 64:
        del native, profiles
        gc.collect()
        return [], diagnostic

    scale = float(bf["analysisScale"])
    scaled_boundary = boundary.astype(np.float32) * scale
    if not np.all(supported):
        indices = np.flatnonzero(supported)
        extended_indices = np.concatenate(
            (indices - len(scaled_boundary), indices, indices + len(scaled_boundary))
        )
        extended_boundary = np.tile(scaled_boundary[indices], 3)
        scaled_boundary[~supported] = np.interp(
            np.flatnonzero(~supported), extended_indices, extended_boundary
        )
    _, threshold, source_candidates = R21.BASE.candidates_from_profile(scaled_boundary)
    candidates = []
    for source in source_candidates:
        row = dict(source)
        row["maximumDepthAnalysisPx"] = float(row["maximumDepthPx"])
        row["maximumDepthNativePx"] = float(row["maximumDepthPx"]) / scale
        row["manufacturedMorphologyPassed"] = R21.BASE.manufactured_candidate(row)
        row["candidateSource"] = "DF_GEOMETRY_BF_FULL_PERIMETER_LOCAL_HIGH_PASS"
        row["exteriorContext"] = R21.R17.exterior_context(
            native, fit, float(row["centerAngleDegrees"]), parameter_values
        )
        candidates.append(row)
    diagnostic.update({
        "state": "PASS_DF_GEOMETRY_BF_FULL_PERIMETER_EXTRACTED",
        "profileThresholdAnalysisPx": float(threshold),
        "candidateCount": len(candidates),
        "eligibleCandidateCount": sum(
            bool(row["manufacturedMorphologyPassed"]) for row in candidates
        ),
    })
    del native, profiles
    gc.collect()
    return candidates, diagnostic


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    existing = ORIGINAL_R25_PAIR(bf, df)
    bf_trace = bf.get("backsideTraceQualification", {})
    df_trace = df.get("backsideTraceQualification", {})
    eligible = (
        not existing
        and bool(bf_trace.get("strictUsable"))
        and bool(bf_trace.get("bfLowFrequencyShapeSuppressed"))
        and bool(df_trace.get("strictUsable"))
        and bool(df_trace.get("rawRmsPassed"))
    )
    if not eligible:
        bf["dfGeometryBfFullPerimeterCompensation"] = {
            "state": "NOT_USED_EXISTING_PAIR_OR_TRACE_PRECONDITION_NOT_MET"
        }
        return existing

    candidates, diagnostic = df_geometry_bf_candidates(bf, df)
    alternate = dict(bf)
    alternate["candidates"] = candidates
    alternate["candidateCount"] = len(candidates)
    proposed = ORIGINAL_R25_PAIR(alternate, df)
    diagnostic["proposedPairCount"] = len(proposed)
    if len(proposed) == 1:
        diagnostic["state"] = "PASS_UNIQUE_DF_GEOMETRY_BF_FULL_PERIMETER_PAIR"
        bf["candidates"] = candidates
        bf["candidateCount"] = len(candidates)
        bf["profileThresholdPx"] = diagnostic["profileThresholdAnalysisPx"]
        bf["patternSuppression"] = (
            "DF_GEOMETRY_FULL_360_BF_BOUNDARY_WITH_BF_HOLDER_EXCLUSION_AND_LOCAL_HIGH_PASS"
        )
    else:
        proposed = []
    bf["dfGeometryBfFullPerimeterCompensation"] = diagnostic
    return proposed


def main() -> int:
    R25.R24.R23.pair_candidates = pair_candidates
    return R25.R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
