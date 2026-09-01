#!/usr/bin/env python3
"""R27 pairs R26 DF-geometry BF candidates to the frozen unique DF strong anchor."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R26_SHA256 = "05534929ECCCB18EA8E2E68A66CF33FA7AAF6B43CA80B6BBBD1970C3946FC1D6"


def load_r26():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR26.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r26_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R26 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R26_SHA256:
        raise RuntimeError(f"Frozen R26 detector hash changed: {path}")
    return module


R26 = load_r26()
R25 = R26.R25
R23 = R26.R23
R21 = R26.R21


def apply_frozen_depth_ratio_gate(bf: dict, pairs: list[dict]) -> list[dict]:
    maximum_ratio = float(
        R21.R17._PARAMETERS["bfShallowAppearanceMaximumDepthRatioToDfAnchor"]
    )
    retained = []
    rows = []
    for pair in pairs:
        df_depth = float(pair["dfDepthNativePx"])
        ratio = (
            float(pair["bfDepthNativePx"]) / df_depth
            if df_depth > 0.0
            else float("inf")
        )
        applies = str(pair["confirmationMode"]) in R25.SHALLOW_MODES
        accepted = not applies or ratio <= maximum_ratio
        rows.append({
            "confirmationMode": str(pair["confirmationMode"]),
            "bfDepthNativePx": float(pair["bfDepthNativePx"]),
            "dfDepthNativePx": df_depth,
            "bfToDfDepthRatio": ratio,
            "maximumBfToDfDepthRatio": maximum_ratio,
            "shallowModeRatioGateApplies": applies,
            "accepted": accepted,
        })
        if accepted:
            retained.append(pair)
    bf["bfShallowDepthRatioNegativeControl"] = {
        "state": (
            "PASS_NO_NONSHALLOW_BF_RESPONSE"
            if len(retained) == len(pairs)
            else "APPLIED_NONSHALLOW_BF_RESPONSE_REMOVED"
        ),
        "inputPairCount": len(pairs),
        "retainedPairCount": len(retained),
        "rows": rows,
    }
    return retained


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    existing = R26.ORIGINAL_R25_PAIR(bf, df)
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

    candidates, diagnostic = R26.df_geometry_bf_candidates(bf, df)
    diagnostic["candidates"] = candidates
    strong = bf.get("dfStrongAnchorAppearanceDiagnostics", {})
    df_rows = list(strong.get("dfShallow", {}).get("qualifiedCandidates", []))
    qualified_df = [
        row for row in df_rows
        if R23.df_anchor_qualified(row, R21.R17._PARAMETERS)
    ]
    eligible_bf = [
        row for row in candidates if bool(row.get("manufacturedMorphologyPassed"))
    ]
    diagnostic["qualifiedDfStrongAnchorCount"] = len(qualified_df)
    diagnostic["qualifiedDfStrongAnchors"] = qualified_df
    diagnostic["eligibleBfCandidateCount"] = len(eligible_bf)

    proposed = []
    maximum_difference = float(
        R21.R17._PARAMETERS["pairedShallowMaximumAngleDifferenceDegrees"]
    )
    if len(qualified_df) == 1:
        df_row = qualified_df[0]
        for bf_row in eligible_bf:
            difference = float(R21.BASE.circular_distance(
                float(bf_row["centerAngleDegrees"]),
                float(df_row["centerAngleDegrees"]),
            ))
            if difference <= maximum_difference:
                proposed.append(R21.R17.pair_row(
                    bf_row,
                    df_row,
                    difference,
                    "DF_STRONG_MORPHOLOGY_ANCHORED_BF_SHALLOW_IMAGE_APPEARANCE",
                ))

    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(R21.R17._PARAMETERS["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(
            R21.BASE.circular_distance(
                row["meanAngleDegrees"], prior["meanAngleDegrees"]
            ) > cluster_width
            for prior in clustered
        ):
            clustered.append(row)
    diagnostic["preNegativeControlPairCount"] = len(clustered)
    retained = apply_frozen_depth_ratio_gate(bf, clustered)
    diagnostic["proposedPairCount"] = len(retained)

    if len(retained) == 1:
        diagnostic["state"] = "PASS_UNIQUE_DF_GEOMETRY_BF_STRONG_ANCHOR_PAIR"
        bf["candidates"] = candidates
        bf["candidateCount"] = len(candidates)
        bf["profileThresholdPx"] = diagnostic["profileThresholdAnalysisPx"]
        bf["patternSuppression"] = (
            "DF_GEOMETRY_FULL_360_BF_BOUNDARY_WITH_BF_HOLDER_EXCLUSION_"
            "LOCAL_HIGH_PASS_AND_FROZEN_DF_STRONG_ANCHOR"
        )
    elif len(clustered) == 1:
        diagnostic["state"] = "HOLD_DF_GEOMETRY_BF_PAIR_FAILED_FROZEN_DEPTH_RATIO"
    else:
        diagnostic["state"] = "HOLD_DF_GEOMETRY_BF_STRONG_ANCHOR_PAIR_CARDINALITY"
        retained = []
    bf["dfGeometryBfFullPerimeterCompensation"] = diagnostic
    return retained


def main() -> int:
    R25.R24.R23.pair_candidates = pair_candidates
    return R25.R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
