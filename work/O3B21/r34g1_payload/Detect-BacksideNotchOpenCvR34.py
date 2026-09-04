#!/usr/bin/env python3
"""R34 preserves multi-pair ambiguity unless the sole exterior-clean pair is score-dominant."""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path
import sys


R33_SHA256 = "1D1F6FC63B719063AB95B53AF580C0A9C8CA40801D0F573F7BE09EF9603BA6D3"
R32_PASS_STATE = "PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR"
SCORE_DOMINANCE_HOLD_STATE = (
    "HOLD_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_SCORE_DOMINANT"
)


def load_r33():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR33.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r33_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R33 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R32.R21.BASE.sha256_file(path) != R33_SHA256:
        raise RuntimeError(f"Frozen R33 detector hash changed: {path}")
    return module


R33 = load_r33()
R32 = R33.R32
ORIGINAL_R32_RESOLVER = R32.resolve_unique_both_channel_exterior_clear_pair


def finite_score(pair: dict) -> float | None:
    try:
        score = float(pair["score"])
    except (KeyError, TypeError, ValueError, OverflowError):
        return None
    return score if math.isfinite(score) else None


def resolve_unique_both_channel_exterior_clear_pair(
    pairs: list[dict],
) -> tuple[list[dict], dict]:
    retained, r32_diagnostic = ORIGINAL_R32_RESOLVER(pairs)
    diagnostic = dict(r32_diagnostic)
    diagnostic.update({
        "requiresStrictScoreDominance": True,
        "scorePopulation": "CURRENT_WAFER_R17_PAIRED_CANDIDATES",
        "scoreDominanceEvaluated": False,
        "allComparedPairScoresFinite": None,
        "uniqueBothChannelsExteriorClearPairScore": None,
        "maximumExteriorDirtyPairScore": None,
        "strictScoreDominancePassed": None,
    })
    if diagnostic.get("state") != R32_PASS_STATE:
        return retained, diagnostic

    clean_pair = retained[0]
    dirty_pairs = [pair for pair in pairs if pair is not clean_pair]
    clean_score = finite_score(clean_pair)
    dirty_scores = [finite_score(pair) for pair in dirty_pairs]
    all_finite = (
        clean_score is not None
        and bool(dirty_scores)
        and all(score is not None for score in dirty_scores)
    )
    maximum_dirty = max(dirty_scores) if all_finite else None
    dominant = bool(all_finite and clean_score > maximum_dirty)
    diagnostic.update({
        "scoreDominanceEvaluated": True,
        "allComparedPairScoresFinite": all_finite,
        "uniqueBothChannelsExteriorClearPairScore": clean_score,
        "maximumExteriorDirtyPairScore": maximum_dirty,
        "strictScoreDominancePassed": dominant,
    })
    if dominant:
        return retained, diagnostic

    diagnostic["state"] = SCORE_DOMINANCE_HOLD_STATE
    diagnostic["retainedPairCount"] = len(pairs)
    return pairs, diagnostic


def main() -> int:
    R32.resolve_unique_both_channel_exterior_clear_pair = (
        resolve_unique_both_channel_exterior_clear_pair
    )
    return R33.main()


if __name__ == "__main__":
    raise SystemExit(main())
