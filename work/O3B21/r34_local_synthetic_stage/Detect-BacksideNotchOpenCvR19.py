#!/usr/bin/env python3
"""R19 paired exterior fixture-contact suppression over frozen R18."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R18_SHA256 = "DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A"


def load_r18():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R18.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR18.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r18_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R18 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R17.BASE.sha256_file(path) != R18_SHA256:
        raise RuntimeError(f"Frozen R18 detector hash changed: {path}")
    return module


R18 = load_r18()


def paired_fixture_contact(row: dict) -> bool:
    bf = row["bfExteriorContext"]
    df = row["dfExteriorContext"]
    bright = [float(bf["brightPixelFraction"]), float(df["brightPixelFraction"])]
    support = [
        float(bf["maximumAngularBrightSupportFraction"]),
        float(df["maximumAngularBrightSupportFraction"]),
    ]
    return (
        min(bright)
        >= float(R18.R17._PARAMETERS["fixtureExteriorMinimumSecondaryChannelBrightFraction"])
        and max(bright)
        >= float(R18.R17._PARAMETERS["fixtureExteriorMinimumPrimaryChannelBrightFraction"])
        and min(support)
        >= float(R18.R17._PARAMETERS["fixtureExteriorMinimumSecondaryChannelAngularSupportFraction"])
        and max(support)
        >= float(R18.R17._PARAMETERS["fixtureExteriorMinimumPrimaryChannelAngularSupportFraction"])
    )


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    prior_fixture_contact = R18.fixture_contact
    R18.fixture_contact = lambda _row: False
    try:
        clustered = R18.pair_candidates(bf, df)
    finally:
        R18.fixture_contact = prior_fixture_contact

    for row in clustered:
        row["bothChannelsExteriorFixtureContact"] = paired_fixture_contact(row)
    if len(clustered) > 1:
        non_fixture = [row for row in clustered if not row["bothChannelsExteriorFixtureContact"]]
        if non_fixture:
            clustered = non_fixture
    return sorted(clustered, key=lambda row: (-row["score"], row["meanAngleDegrees"]))


def main() -> int:
    R18.R17.pair_candidates = pair_candidates
    return R18.R17.main()


if __name__ == "__main__":
    raise SystemExit(main())
