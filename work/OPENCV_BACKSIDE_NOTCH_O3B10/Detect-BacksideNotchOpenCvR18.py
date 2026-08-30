#!/usr/bin/env python3
"""R18 bounded fixture/broad-channel decision patch over frozen R17."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R17_SHA256 = "B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713"


def load_r17():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R17.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR17.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r17_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R17 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.BASE.sha256_file(path) != R17_SHA256:
        raise RuntimeError(f"Frozen R17 detector hash changed: {path}")
    return module


R17 = load_r17()


def fixture_contact(row: dict) -> bool:
    context = row["exteriorContext"]
    return (
        float(context["brightPixelFraction"])
        >= float(R17._PARAMETERS["fixtureExteriorMinimumBrightFraction"])
        and float(context["maximumAngularBrightSupportFraction"])
        >= float(R17._PARAMETERS["fixtureExteriorMinimumAngularSupportFraction"])
    )


def broad_zero_exterior_confirmation(row: dict) -> bool:
    context = row["exteriorContext"]
    return (
        float(R17._PARAMETERS["broadConfirmationMinimumWidthDegrees"])
        <= float(row["widthDegrees"])
        <= float(R17._PARAMETERS["broadConfirmationMaximumWidthDegrees"])
        and float(row["symmetryScore"])
        >= float(R17._PARAMETERS["broadConfirmationMinimumSymmetry"])
        and float(row["tipCenterOffsetFraction"])
        <= float(R17._PARAMETERS["broadConfirmationMaximumTipOffsetFraction"])
        and float(row["slopeConsistencyFraction"])
        >= float(R17._PARAMETERS["broadConfirmationMinimumSlopeConsistency"])
        and float(context["brightPixelFraction"])
        <= float(R17._PARAMETERS["broadConfirmationMaximumExteriorBrightFraction"])
        and float(context["maximumAngularBrightSupportFraction"])
        <= float(R17._PARAMETERS["broadConfirmationMaximumExteriorAngularSupportFraction"])
    )


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    tolerance = float(R17._PARAMETERS["confirmationAngleToleranceDegrees"])
    proposed: list[dict] = []
    for bf_row in bf["candidates"]:
        for df_row in df["candidates"]:
            difference = R17.BASE.circular_distance(
                float(bf_row["centerAngleDegrees"]), float(df_row["centerAngleDegrees"])
            )
            if difference > tolerance:
                continue
            bf_strict = bool(bf_row["manufacturedMorphologyPassed"])
            df_strict = bool(df_row["manufacturedMorphologyPassed"])
            if bf_strict and df_strict:
                mode = "STRICT_BOTH_CHANNELS"
            elif bf_strict and R17.soft_morphology(df_row):
                mode = "STRICT_BF_CONFIRMED_BY_DF"
            elif df_strict and R17.soft_morphology(bf_row):
                mode = "STRICT_DF_CONFIRMED_BY_BF"
            elif bf_strict and broad_zero_exterior_confirmation(df_row):
                mode = "STRICT_BF_CONFIRMED_BY_BROAD_ZERO_EXTERIOR_DF"
            elif df_strict and broad_zero_exterior_confirmation(bf_row):
                mode = "STRICT_DF_CONFIRMED_BY_BROAD_ZERO_EXTERIOR_BF"
            else:
                continue
            row = R17.pair_row(bf_row, df_row, difference, mode)
            row["bothChannelsExteriorFixtureContact"] = (
                fixture_contact(bf_row)
                and fixture_contact(df_row)
                and max(
                    float(bf_row["exteriorContext"]["brightPixelFraction"]),
                    float(df_row["exteriorContext"]["brightPixelFraction"]),
                ) >= float(R17._PARAMETERS["fixtureExteriorMinimumStrongChannelBrightFraction"])
            )
            proposed.append(row)

    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered: list[dict] = []
    cluster_width = float(R17._PARAMETERS["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(
            R17.BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"]) > cluster_width
            for prior in clustered
        ):
            clustered.append(row)
    if len(clustered) > 1:
        non_fixture = [row for row in clustered if not row["bothChannelsExteriorFixtureContact"]]
        if non_fixture:
            clustered = non_fixture
    return sorted(clustered, key=lambda row: (-row["score"], row["meanAngleDegrees"]))


def main() -> int:
    R17.fixture_contact = fixture_contact
    R17.pair_candidates = pair_candidates
    return R17.main()


if __name__ == "__main__":
    raise SystemExit(main())
