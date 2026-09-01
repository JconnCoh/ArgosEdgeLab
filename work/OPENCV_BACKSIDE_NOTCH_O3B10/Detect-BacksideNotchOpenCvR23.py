#!/usr/bin/env python3
"""R23 strong-DF morphology anchor with independent BF local appearance over frozen R22."""

from __future__ import annotations

import gc
import importlib.util
from pathlib import Path
import sys

import cv2


R22_SHA256 = "DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94"


def load_r22():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R22.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR22.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r22_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R22 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R22_SHA256:
        raise RuntimeError(f"Frozen R22 detector hash changed: {path}")
    return module


R22 = load_r22()
R21 = R22.R21


def df_anchor_qualified(row: dict, parameters: dict) -> bool:
    return (
        float(parameters["dfStrongAnchorMinimumWidthDegrees"])
        <= float(row["widthDegrees"])
        <= float(parameters["dfStrongAnchorMaximumWidthDegrees"])
        and float(row["maximumDepthNativePx"]) >= float(parameters["dfStrongAnchorMinimumDepthPx"])
        and float(row["symmetryScore"]) >= float(parameters["dfStrongAnchorMinimumSymmetry"])
        and float(row["tipCenterOffsetFraction"]) <= float(parameters["dfStrongAnchorMaximumTipOffsetFraction"])
        and float(row["slopeConsistencyFraction"])
        >= float(parameters["dfStrongAnchorMinimumSlopeConsistency"])
    )


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    existing = R22.ORIGINAL_PAIR(bf, df)
    if existing:
        bf["dfStrongAnchorAppearanceDiagnostics"] = {
            "state": "NOT_USED_EXISTING_STRICT_PAIR",
            "qualifiedAnchorCount": 0,
            "proposedPairCount": 0,
        }
        return existing

    bf_native = cv2.imread(str(R22.LAST_PATH["BF"]), cv2.IMREAD_GRAYSCALE)
    df_native = cv2.imread(str(R22.LAST_PATH["DF"]), cv2.IMREAD_GRAYSCALE)
    if bf_native is None or df_native is None:
        raise RuntimeError("DF-anchor paired appearance decode failed.")

    try:
        bf_rows, bf_diagnostic = R22.shallow_candidates("BF", bf, bf_native)
        df_rows, df_diagnostic = R22.shallow_candidates("DF", df, df_native)
        parameters = R21.R17._PARAMETERS
        proposed = []
        anchors = []
        maximum_difference = float(parameters["pairedShallowMaximumAngleDifferenceDegrees"])
        for df_row in df_rows:
            anchor = {
                "angleDegrees": float(df_row["centerAngleDegrees"]),
                "widthDegrees": float(df_row["widthDegrees"]),
                "depthNativePx": float(df_row["maximumDepthNativePx"]),
                "symmetryScore": float(df_row["symmetryScore"]),
                "tipCenterOffsetFraction": float(df_row["tipCenterOffsetFraction"]),
                "slopeConsistencyFraction": float(df_row["slopeConsistencyFraction"]),
                "qualified": df_anchor_qualified(df_row, parameters),
            }
            if not anchor["qualified"]:
                anchors.append(anchor)
                continue

            shallow_pairs = []
            for bf_row in bf_rows:
                difference = float(R21.BASE.circular_distance(
                    float(bf_row["centerAngleDegrees"]), float(df_row["centerAngleDegrees"])
                ))
                if difference <= maximum_difference:
                    shallow_pairs.append(R21.R17.pair_row(
                        bf_row,
                        df_row,
                        difference,
                        "DF_STRONG_MORPHOLOGY_ANCHORED_BF_SHALLOW_IMAGE_APPEARANCE",
                    ))
            shallow_pairs.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
            if shallow_pairs:
                proposed.append(shallow_pairs[0])
                anchor["bfConfirmationMode"] = "BF_SHALLOW_PROFILE_CANDIDATE"
                anchor["bfProbe"] = None
            else:
                probe, bf_row = R22.bf_appearance_probe(
                    bf, float(df_row["centerAngleDegrees"]), bf_native
                )
                anchor["bfProbe"] = probe
                if bf_row is not None:
                    difference = float(R21.BASE.circular_distance(
                        float(bf_row["centerAngleDegrees"]), float(df_row["centerAngleDegrees"])
                    ))
                    proposed.append(R21.R17.pair_row(
                        bf_row,
                        df_row,
                        difference,
                        "DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE",
                    ))
                    anchor["bfConfirmationMode"] = "BF_ANCHOR_LOCAL_PROMINENCE"
                else:
                    anchor["bfConfirmationMode"] = "HOLD_BF_LOCAL_PROMINENCE_NOT_QUALIFIED"
            anchors.append(anchor)
    finally:
        del bf_native, df_native
        gc.collect()

    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(R21.R17._PARAMETERS["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(
            R21.BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"])
            > cluster_width
            for prior in clustered
        ):
            clustered.append(row)
    qualified_anchor_count = sum(1 for anchor in anchors if anchor["qualified"])
    bf["dfStrongAnchorAppearanceDiagnostics"] = {
        "state": (
            "PASS_DF_STRONG_ANCHOR_BF_APPEARANCE_PROPOSED"
            if len(clustered) == 1
            else "HOLD_DF_STRONG_ANCHOR_PAIR_CARDINALITY"
        ),
        "bfShallow": bf_diagnostic,
        "dfShallow": df_diagnostic,
        "anchors": anchors,
        "qualifiedAnchorCount": qualified_anchor_count,
        "proposedPairCount": len(clustered),
    }
    return clustered


def main() -> int:
    R21.localize_channel = R22.capture_localize
    R21.analyze_radial = R22.capture_analyze
    R21.pair_candidates = pair_candidates
    return R21.main()


if __name__ == "__main__":
    raise SystemExit(main())
