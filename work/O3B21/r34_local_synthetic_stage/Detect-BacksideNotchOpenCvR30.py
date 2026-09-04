#!/usr/bin/env python3
"""R30 rejects doubly exterior-contaminated legacy soft pairs over R29."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R29_SHA256 = "72F0DAAE7DC66D4627F03A265B65C137D7362A60C27AA649BAFE564FC515EB65"
LEGACY_SOFT_MODES = frozenset(("STRICT_BF_CONFIRMED_BY_DF", "STRICT_DF_CONFIRMED_BY_BF"))


def load_r29():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR29.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r29_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R29 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R29_SHA256:
        raise RuntimeError(f"Frozen R29 detector hash changed: {path}")
    return module


R29 = load_r29()
R21 = R29.R21


def exterior_clear(context: dict, parameters: dict) -> bool:
    return bool(
        isinstance(context, dict)
        and float(context["brightPixelFraction"])
        <= float(parameters["appearanceConfirmationMaximumExteriorBrightFraction"])
        and float(context["maximumAngularBrightSupportFraction"])
        <= float(parameters["appearanceConfirmationMaximumExteriorAngularSupportFraction"])
    )


def reject_doubly_contaminated_soft_pairs(pairs: list[dict]) -> tuple[list[dict], dict]:
    parameters = R21.R17._PARAMETERS
    retained = []
    rows = []
    for pair in pairs:
        mode = str(pair.get("confirmationMode", ""))
        bf_clear = exterior_clear(pair.get("bfExteriorContext"), parameters)
        df_clear = exterior_clear(pair.get("dfExteriorContext"), parameters)
        applies = mode in LEGACY_SOFT_MODES
        accepted = not applies or bf_clear or df_clear
        rows.append({
            "confirmationMode": mode,
            "legacySoftExteriorGateApplies": applies,
            "bfExteriorClear": bf_clear,
            "dfExteriorClear": df_clear,
            "accepted": accepted,
        })
        if accepted:
            retained.append(pair)
    return retained, {
        "state": (
            "PASS_NO_DOUBLY_CONTAMINATED_LEGACY_SOFT_PAIR"
            if len(retained) == len(pairs)
            else "APPLIED_DOUBLY_CONTAMINATED_LEGACY_SOFT_PAIR_REMOVED"
        ),
        "inputPairCount": len(pairs),
        "retainedPairCount": len(retained),
        "rows": rows,
    }


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    proposed = R29.pair_candidates(bf, df)
    retained, diagnostic = reject_doubly_contaminated_soft_pairs(proposed)
    bf["legacySoftPairExteriorNegativeControl"] = diagnostic
    return retained


def main() -> int:
    R29.R28.R25.R24.R23.pair_candidates = pair_candidates
    return R29.R28.R25.R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
