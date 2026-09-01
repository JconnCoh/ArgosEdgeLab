#!/usr/bin/env python3
"""R24 evidence-derived single-sample BF confirmation over frozen R23."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R23_SHA256 = "AAE38F93C7C1FE16E0967713A3773E33D61488E4D02BE6794E2811624D6DCE4C"


def load_r23():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R23.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR23.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r23_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R23 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R23_SHA256:
        raise RuntimeError(f"Frozen R23 detector hash changed: {path}")
    return module


R23 = load_r23()
ORIGINAL_BF_APPEARANCE_PROBE = R23.R22.bf_appearance_probe
ORIGINAL_PAIR_ROW = R23.R21.R17.pair_row


def single_sample_bf_appearance_probe(
    bf: dict, anchor_angle: float, native
) -> tuple[dict, dict | None]:
    probe, candidate = ORIGINAL_BF_APPEARANCE_PROBE(bf, anchor_angle, native)
    if candidate is not None:
        return probe, candidate

    parameters = R23.R21.R17._PARAMETERS
    required = {
        "searchSupportedFraction",
        "holderMasked",
        "peakProminencePx",
        "runThresholdPx",
        "centerAngleDegrees",
        "angleDifferenceDegrees",
        "widthDegrees",
        "symmetryScore",
        "tipCenterOffsetFraction",
        "slopeConsistencyFraction",
        "exteriorContext",
    }
    if not required.issubset(probe):
        probe["singleSampleQualification"] = {
            "state": "NOT_EVALUATED_INCOMPLETE_BF_PROBE"
        }
        return probe, None

    prominence = float(probe["peakProminencePx"])
    run_threshold = float(probe["runThresholdPx"])
    ratio = prominence / run_threshold if run_threshold > 0.0 else 0.0
    width = float(probe["widthDegrees"])
    context = probe["exteriorContext"]
    qualified = (
        not bool(probe["holderMasked"])
        and float(probe["searchSupportedFraction"])
        >= float(parameters["bfSingleSampleMinimumSupportedFraction"])
        and prominence >= float(parameters["bfSingleSampleMinimumProminencePx"])
        and ratio >= float(parameters["bfSingleSampleMinimumProminenceToThresholdRatio"])
        and float(parameters["bfSingleSampleMinimumWidthDegrees"])
        <= width
        <= float(parameters["bfSingleSampleMaximumWidthDegrees"])
        and float(probe["angleDifferenceDegrees"])
        <= float(parameters["bfSingleSampleMaximumCenterOffsetDegrees"])
        and float(context["brightPixelFraction"])
        <= float(parameters["bfSingleSampleMaximumExteriorBrightFraction"])
        and float(context["maximumAngularBrightSupportFraction"])
        <= float(parameters["bfSingleSampleMaximumExteriorAngularSupportFraction"])
    )
    probe["singleSampleQualification"] = {
        "state": (
            "PASS_BF_SINGLE_SAMPLE_HIGH_PROMINENCE_APPEARANCE"
            if qualified
            else "HOLD_BF_SINGLE_SAMPLE_HIGH_PROMINENCE_APPEARANCE"
        ),
        "prominenceToRunThresholdRatio": ratio,
        "minimumSupportedFraction": float(
            parameters["bfSingleSampleMinimumSupportedFraction"]
        ),
        "minimumProminencePx": float(parameters["bfSingleSampleMinimumProminencePx"]),
        "minimumProminenceToThresholdRatio": float(
            parameters["bfSingleSampleMinimumProminenceToThresholdRatio"]
        ),
        "minimumWidthDegrees": float(parameters["bfSingleSampleMinimumWidthDegrees"]),
        "maximumWidthDegrees": float(parameters["bfSingleSampleMaximumWidthDegrees"]),
        "maximumCenterOffsetDegrees": float(
            parameters["bfSingleSampleMaximumCenterOffsetDegrees"]
        ),
    }
    if not qualified:
        return probe, None

    probe["state"] = "PASS_BF_SINGLE_SAMPLE_HIGH_PROMINENCE_APPEARANCE_CONFIRMED"
    center = float(probe["centerAngleDegrees"])
    scale = float(bf["analysisScale"])
    candidate = {
        "startAngleDegrees": (center - width / 2.0) % 360.0,
        "endAngleDegrees": (center + width / 2.0) % 360.0,
        "centerAngleDegrees": center,
        "widthDegrees": width,
        "maximumDepthPx": prominence,
        "maximumDepthNativePx": prominence,
        "maximumDepthAnalysisPx": prominence * scale,
        "symmetryScore": float(probe["symmetryScore"]),
        "tipCenterOffsetFraction": float(probe["tipCenterOffsetFraction"]),
        "slopeConsistencyFraction": float(probe["slopeConsistencyFraction"]),
        "manufacturedMorphologyPassed": False,
        "candidateSource": "DF_STRONG_ANCHORED_BF_SINGLE_SAMPLE_HIGH_PROMINENCE_APPEARANCE",
        "exteriorContext": context,
    }
    return probe, candidate


def pair_row(bf_row: dict, df_row: dict, difference: float, mode: str) -> dict:
    row = ORIGINAL_PAIR_ROW(bf_row, df_row, difference, mode)
    if (
        bf_row.get("candidateSource")
        == "DF_STRONG_ANCHORED_BF_SINGLE_SAMPLE_HIGH_PROMINENCE_APPEARANCE"
        and mode == "DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE"
    ):
        row["confirmationMode"] = (
            "DF_STRONG_MORPHOLOGY_ANCHORED_BF_SINGLE_SAMPLE_HIGH_PROMINENCE_APPEARANCE"
        )
    return row


def main() -> int:
    R23.R22.bf_appearance_probe = single_sample_bf_appearance_probe
    R23.R21.R17.pair_row = pair_row
    return R23.main()


if __name__ == "__main__":
    raise SystemExit(main())
