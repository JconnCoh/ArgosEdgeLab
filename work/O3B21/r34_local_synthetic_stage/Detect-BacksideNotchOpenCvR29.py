#!/usr/bin/env python3
"""R29 adds holder-clear BF-near-strict plus DF-broad confirmation over R28."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R28_SHA256 = "4F51BA7E8D261BF196CE559C420A4F511F0D06B39BE5F512D2E6ABF585681466"
CONFIRMATION_MODE = "BF_NEAR_STRICT_SYMMETRY_CONFIRMED_BY_DF_BROAD_STRONG_APPEARANCE"


def load_r28():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR28.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r28_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R28 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R28_SHA256:
        raise RuntimeError(f"Frozen R28 detector hash changed: {path}")
    return module


R28 = load_r28()
R21 = R28.R21


def holder_clear(row: dict, result: dict, parameters: dict) -> bool:
    spans = result.get("holderExclusion", {}).get("spans")
    if not isinstance(spans, list):
        return False
    return not R28.R27.R26.R22.angle_in_holder(
        float(row["centerAngleDegrees"]),
        spans,
        float(parameters["pairedShallowHolderClearanceDegrees"]),
    )


def exterior_clear(row: dict, maximum_bright: float, maximum_support: float) -> bool:
    context = row.get("exteriorContext")
    return bool(
        isinstance(context, dict)
        and float(context["brightPixelFraction"]) <= maximum_bright
        and float(context["maximumAngularBrightSupportFraction"]) <= maximum_support
    )


def bf_near_strict(row: dict, result: dict, parameters: dict) -> bool:
    symmetry = float(row["symmetryScore"])
    return bool(
        not row.get("manufacturedMorphologyPassed", False)
        and float(parameters["manufacturedMinimumWidthDegrees"])
        <= float(row["widthDegrees"])
        <= float(parameters["manufacturedMaximumWidthDegrees"])
        and float(parameters["confirmationMinimumSymmetry"])
        <= symmetry
        < float(parameters["manufacturedMinimumSymmetry"])
        and float(row["tipCenterOffsetFraction"])
        <= float(parameters["manufacturedMaximumTipOffsetFraction"])
        and float(row["slopeConsistencyFraction"])
        >= float(parameters["manufacturedMinimumSlopeConsistency"])
        and holder_clear(row, result, parameters)
        and exterior_clear(
            row,
            float(parameters["appearanceConfirmationMaximumExteriorBrightFraction"]),
            float(parameters["appearanceConfirmationMaximumExteriorAngularSupportFraction"]),
        )
    )


def df_broad_strong(row: dict, result: dict, parameters: dict) -> bool:
    return bool(
        float(parameters["broadConfirmationMinimumWidthDegrees"])
        <= float(row["widthDegrees"])
        <= float(parameters["broadConfirmationMaximumWidthDegrees"])
        and float(row["maximumDepthNativePx"])
        >= float(parameters["appearanceConfirmationMinimumDepthPx"])
        and float(row["symmetryScore"])
        >= float(parameters["broadConfirmationMinimumSymmetry"])
        and float(row["tipCenterOffsetFraction"])
        <= float(parameters["broadConfirmationMaximumTipOffsetFraction"])
        and float(row["slopeConsistencyFraction"])
        >= float(parameters["broadConfirmationMinimumSlopeConsistency"])
        and holder_clear(row, result, parameters)
        and exterior_clear(
            row,
            float(parameters["broadConfirmationMaximumExteriorBrightFraction"]),
            float(parameters["broadConfirmationMaximumExteriorAngularSupportFraction"]),
        )
    )


def pair_near_strict_broad(bf: dict, df: dict) -> tuple[list[dict], dict]:
    parameters = R21.R17._PARAMETERS
    bf_rows = [row for row in bf.get("candidates", []) if bf_near_strict(row, bf, parameters)]
    df_rows = [row for row in df.get("candidates", []) if df_broad_strong(row, df, parameters)]
    maximum_difference = float(parameters["confirmationAngleToleranceDegrees"])
    comparisons = []
    proposed = []
    for bf_row in bf_rows:
        for df_row in df_rows:
            difference = float(R21.BASE.circular_distance(
                float(bf_row["centerAngleDegrees"]), float(df_row["centerAngleDegrees"])
            ))
            comparisons.append({
                "bfAngleDegrees": float(bf_row["centerAngleDegrees"]),
                "dfAngleDegrees": float(df_row["centerAngleDegrees"]),
                "angleDifferenceDegrees": difference,
                "maximumAngleDifferenceDegrees": maximum_difference,
                "withinFrozenAngleGate": difference <= maximum_difference,
            })
            if difference <= maximum_difference:
                proposed.append(R21.R17.pair_row(bf_row, df_row, difference, CONFIRMATION_MODE))
    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(parameters["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(R21.BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"]) > cluster_width
               for prior in clustered):
            clustered.append(row)
    return clustered, {
        "state": "PASS_UNIQUE_BF_NEAR_STRICT_DF_BROAD_PAIR" if len(clustered) == 1
                 else "HOLD_BF_NEAR_STRICT_DF_BROAD_PAIR_CARDINALITY",
        "eligibleBfCandidateCount": len(bf_rows),
        "eligibleDfCandidateCount": len(df_rows),
        "pairComparisons": comparisons,
        "preClusterPairCount": len(proposed),
        "proposedPairCount": len(clustered),
    }


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    existing = R28.pair_candidates(bf, df)
    if existing:
        bf["bfNearStrictDfBroadCompensation"] = {"state": "NOT_USED_EXISTING_R28_PAIR"}
        return existing
    proposed, diagnostic = pair_near_strict_broad(bf, df)
    bf["bfNearStrictDfBroadCompensation"] = diagnostic
    return proposed if len(proposed) == 1 else []


def main() -> int:
    R28.R25.R24.R23.pair_candidates = pair_candidates
    return R28.R25.R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
