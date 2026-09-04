#!/usr/bin/env python3
"""R28 pairs strict full-perimeter BF evidence to frozen DF-shallow evidence."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

R27_SHA256 = "656F7705752F64CDAEBB88B195DB6E47A689B2727CB0113E168A72B8898F9FDF"
CONFIRMATION_MODE = (
    "DF_GEOMETRY_BF_MANUFACTURED_MORPHOLOGY_CONFIRMED_BY_"
    "DF_SHALLOW_IMAGE_APPEARANCE"
)


def load_r27():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR27.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r27_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R27 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R27_SHA256:
        raise RuntimeError(f"Frozen R27 detector hash changed: {path}")
    return module


R27 = load_r27()
R26 = R27.R26
R25 = R27.R25
R23 = R27.R23
R21 = R27.R21


def pair_frozen_cross_channel_evidence(
    bf_candidates: list[dict], df_shallow_rows: list[dict]
) -> tuple[list[dict], dict]:
    """Apply only frozen holder, angle, score, and clustering semantics."""
    parameters = R21.R17._PARAMETERS
    eligible_bf = [
        row for row in bf_candidates
        if bool(row.get("manufacturedMorphologyPassed"))
    ]
    holder_clear_df = [
        row for row in df_shallow_rows
        if row.get("holderMasked") is False
    ]
    maximum_difference = float(
        parameters["pairedShallowMaximumAngleDifferenceDegrees"]
    )
    comparisons = []
    proposed = []
    for bf_row in eligible_bf:
        for df_row in holder_clear_df:
            difference = float(R21.BASE.circular_distance(
                float(bf_row["centerAngleDegrees"]),
                float(df_row["centerAngleDegrees"]),
            ))
            within_gate = difference <= maximum_difference
            comparisons.append({
                "bfAngleDegrees": float(bf_row["centerAngleDegrees"]),
                "dfAngleDegrees": float(df_row["centerAngleDegrees"]),
                "angleDifferenceDegrees": difference,
                "maximumAngleDifferenceDegrees": maximum_difference,
                "withinFrozenAngleGate": within_gate,
            })
            if within_gate:
                proposed.append(R21.R17.pair_row(
                    bf_row, df_row, difference, CONFIRMATION_MODE
                ))

    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(parameters["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(
            R21.BASE.circular_distance(
                row["meanAngleDegrees"], prior["meanAngleDegrees"]
            ) > cluster_width
            for prior in clustered
        ):
            clustered.append(row)
    return clustered, {
        "eligibleBfCandidateCount": len(eligible_bf),
        "dfShallowQualifiedCandidateCount": len(df_shallow_rows),
        "dfShallowHolderClearCandidateCount": len(holder_clear_df),
        "pairComparisons": comparisons,
        "preClusterPairCount": len(proposed),
        "proposedPairCount": len(clustered),
    }


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
    retained, pairing = pair_frozen_cross_channel_evidence(candidates, df_rows)
    diagnostic.update(pairing)
    strong_anchors = [
        row for row in df_rows
        if R23.df_anchor_qualified(row, R21.R17._PARAMETERS)
    ]
    diagnostic["qualifiedDfStrongAnchorCount"] = len(strong_anchors)
    diagnostic["qualifiedDfStrongAnchors"] = strong_anchors

    if len(retained) == 1:
        diagnostic["state"] = (
            "PASS_UNIQUE_DF_GEOMETRY_BF_MANUFACTURED_DF_SHALLOW_PAIR"
        )
        bf["candidates"] = candidates
        bf["candidateCount"] = len(candidates)
        bf["profileThresholdPx"] = diagnostic["profileThresholdAnalysisPx"]
        bf["patternSuppression"] = (
            "DF_GEOMETRY_FULL_360_BF_BOUNDARY_WITH_BF_HOLDER_EXCLUSION_"
            "LOCAL_HIGH_PASS_AND_FROZEN_DF_SHALLOW_APPEARANCE"
        )
    else:
        diagnostic["state"] = (
            "HOLD_DF_GEOMETRY_BF_MANUFACTURED_DF_SHALLOW_PAIR_CARDINALITY"
        )
        retained = []
    bf["dfGeometryBfFullPerimeterCompensation"] = diagnostic
    return retained

def main() -> int:
    R25.R24.R23.pair_candidates = pair_candidates
    return R25.R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
