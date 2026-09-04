#!/usr/bin/env python3
"""R25 rejects non-shallow BF responses from R23 shallow confirmation modes."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R24_SHA256 = "BDEAA9DBA4AA5FB1DEDF5FBBFA7C8F02C1860522E713EA1BE0BDB36539401477"


def load_r24():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R24.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR24.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r24_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R24 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R23.R21.BASE.sha256_file(path) != R24_SHA256:
        raise RuntimeError(f"Frozen R24 detector hash changed: {path}")
    return module


R24 = load_r24()
ORIGINAL_R23_PAIR = R24.R23.pair_candidates
SHALLOW_MODES = {
    "DF_STRONG_MORPHOLOGY_ANCHORED_BF_SHALLOW_IMAGE_APPEARANCE",
    "DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE",
}


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    pairs = ORIGINAL_R23_PAIR(bf, df)
    maximum_ratio = float(
        R24.R23.R21.R17._PARAMETERS[
            "bfShallowAppearanceMaximumDepthRatioToDfAnchor"
        ]
    )
    retained = []
    diagnostics = []
    for row in pairs:
        mode = str(row["confirmationMode"])
        df_depth = float(row["dfDepthNativePx"])
        ratio = float(row["bfDepthNativePx"]) / df_depth if df_depth > 0.0 else float("inf")
        applies = mode in SHALLOW_MODES
        accepted = not applies or ratio <= maximum_ratio
        diagnostics.append({
            "confirmationMode": mode,
            "bfDepthNativePx": float(row["bfDepthNativePx"]),
            "dfDepthNativePx": df_depth,
            "bfToDfDepthRatio": ratio,
            "maximumBfToDfDepthRatio": maximum_ratio,
            "shallowModeRatioGateApplies": applies,
            "accepted": accepted,
        })
        if accepted:
            retained.append(row)
    bf["bfShallowDepthRatioNegativeControl"] = {
        "state": (
            "PASS_NO_NONSHALLOW_BF_RESPONSE"
            if len(retained) == len(pairs)
            else "APPLIED_NONSHALLOW_BF_RESPONSE_REMOVED"
        ),
        "inputPairCount": len(pairs),
        "retainedPairCount": len(retained),
        "rows": diagnostics,
    }
    return retained


def main() -> int:
    R24.R23.pair_candidates = pair_candidates
    return R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
