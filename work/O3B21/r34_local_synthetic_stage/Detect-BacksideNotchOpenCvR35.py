#!/usr/bin/env python3
"""R35 limits dirty-pair score holds to nearby competing geometry."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R34_SHA256 = "3B3B9F6E461BC8F7C5498763A6ED9A46A404E55E5E3C69B10235C3489B3FF066"
MAXIMUM_NEARBY_COMPETITOR_SEPARATION_DEGREES = 60.0


def load_r34():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR34.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r34_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R34 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R32.R21.BASE.sha256_file(path) != R34_SHA256:
        raise RuntimeError(f"Frozen R34 detector hash changed: {path}")
    return module


R34 = load_r34()
ORIGINAL_R34_RESOLVER = R34.resolve_unique_both_channel_exterior_clear_pair


def angular_distance(first: float, second: float) -> float:
    delta = abs(first - second) % 360.0
    return min(delta, 360.0 - delta)


def resolve_unique_both_channel_exterior_clear_pair(
    pairs: list[dict],
) -> tuple[list[dict], dict]:
    retained, r34_diagnostic = ORIGINAL_R34_RESOLVER(pairs)
    diagnostic = dict(r34_diagnostic)
    diagnostic.update({
        "maximumNearbyCompetitorSeparationDegrees":
            MAXIMUM_NEARBY_COMPETITOR_SEPARATION_DEGREES,
        "nearbyCompetitorEvaluated": False,
        "minimumDominatingDirtySeparationDegrees": None,
        "dominatingDirtyCompetitorIsNearby": None,
        "distantExteriorDirtyCandidatesRejected": False,
    })
    if diagnostic.get("state") != R34.SCORE_DOMINANCE_HOLD_STATE:
        return retained, diagnostic
    if diagnostic.get("allComparedPairScoresFinite") is not True:
        return retained, diagnostic

    rows = list(diagnostic.get("rows") or [])
    clean_indexes = [
        index for index, row in enumerate(rows)
        if row.get("bothChannelsExteriorClear") is True
    ]
    if len(clean_indexes) != 1 or len(rows) != len(pairs):
        return retained, diagnostic
    clean_index = clean_indexes[0]
    clean_pair = pairs[clean_index]
    clean_score = float(clean_pair["score"])
    separations = [
        angular_distance(
            float(clean_pair["meanAngleDegrees"]),
            float(pair["meanAngleDegrees"]),
        )
        for index, pair in enumerate(pairs)
        if index != clean_index and float(pair["score"]) >= clean_score
    ]
    if not separations:
        return retained, diagnostic
    minimum = min(separations)
    nearby = minimum <= MAXIMUM_NEARBY_COMPETITOR_SEPARATION_DEGREES
    diagnostic.update({
        "nearbyCompetitorEvaluated": True,
        "minimumDominatingDirtySeparationDegrees": minimum,
        "dominatingDirtyCompetitorIsNearby": nearby,
    })
    if nearby:
        return retained, diagnostic

    diagnostic.update({
        "state": R34.R32_PASS_STATE,
        "retainedPairCount": 1,
        "distantExteriorDirtyCandidatesRejected": True,
    })
    return [clean_pair], diagnostic


def main() -> int:
    R34.resolve_unique_both_channel_exterior_clear_pair = (
        resolve_unique_both_channel_exterior_clear_pair
    )
    return R34.main()


if __name__ == "__main__":
    raise SystemExit(main())
