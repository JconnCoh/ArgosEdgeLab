#!/usr/bin/env python3
"""R32 resolves a multi-pair result only when exactly one pair is exterior-clean in both channels."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R31_SHA256 = "34476F0109CE68FB6365A7C650CC6FFF2B874B64A38EAA0DA09542261427BCA7"


def load_r31():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR31.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r31_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R31 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R31_SHA256:
        raise RuntimeError(f"Frozen R31 detector hash changed: {path}")
    return module


R31 = load_r31()
R30 = R31.R30
R21 = R31.R21


def pair_exterior_clear(pair: dict, parameters: dict) -> tuple[bool, bool]:
    return (
        R30.exterior_clear(pair.get("bfExteriorContext"), parameters),
        R30.exterior_clear(pair.get("dfExteriorContext"), parameters),
    )


def resolve_unique_both_channel_exterior_clear_pair(pairs: list[dict]) -> tuple[list[dict], dict]:
    parameters = R21.R17._PARAMETERS
    rows = []
    clean = []
    for pair in pairs:
        bf_clear, df_clear = pair_exterior_clear(pair, parameters)
        both_clear = bf_clear and df_clear
        rows.append({
            "meanAngleDegrees": pair.get("meanAngleDegrees"),
            "confirmationMode": pair.get("confirmationMode"),
            "bfExteriorClear": bf_clear,
            "dfExteriorClear": df_clear,
            "bothChannelsExteriorClear": both_clear,
        })
        if both_clear:
            clean.append(pair)

    applies = len(pairs) > 1
    uniquely_resolved = applies and len(clean) == 1
    retained = clean if uniquely_resolved else pairs
    return retained, {
        "state": (
            "PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR"
            if uniquely_resolved
            else "NOT_APPLIED_SINGLE_OR_EMPTY_PAIR"
            if not applies
            else "HOLD_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_UNIQUE"
        ),
        "appliesOnlyToMultiplePairs": True,
        "usesFrozenR30ExteriorThresholds": True,
        "inputPairCount": len(pairs),
        "bothChannelsExteriorClearPairCount": len(clean),
        "retainedPairCount": len(retained),
        "rows": rows,
    }


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    proposed = R31.pair_candidates(bf, df)
    retained, diagnostic = resolve_unique_both_channel_exterior_clear_pair(proposed)
    bf["multiPairExteriorCleanResolution"] = diagnostic
    return retained


def main() -> int:
    R31.R30.R29.R28.R25.R24.R23.pair_candidates = pair_candidates
    return R31.R30.R29.R28.R25.R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
