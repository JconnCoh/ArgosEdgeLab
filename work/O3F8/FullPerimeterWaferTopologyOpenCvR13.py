#!/usr/bin/env python3
"""R13: preserve R11 and apply its frozen DF seed ceiling to DF candidates.

R11 incorrectly applies the BF topology candidate ceiling to the independent
R6 DF radial candidate array.  R13 changes only that resource-limit binding:
BF remains capped by topologyConfig.maximumChannelCandidateCount, while DF
uses the already-frozen O3P8 maximumSeedCountPerWafer ceiling.  Candidate
generation, ordering, pairing, morphology, ambiguity, and selector thresholds
remain R11 byte-for-byte.
"""

from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import sys
from typing import Any


R11_SOURCE_SHA256 = "B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059"
HERE = Path(__file__).resolve().parent
R11_PATH = HERE / "FullPerimeterWaferTopologyOpenCvR11.py"

if not R11_PATH.is_file():
    raise ValueError(f"Frozen R11 dependency is missing: {R11_PATH}")
if hashlib.sha256(R11_PATH.read_bytes()).hexdigest().upper() != R11_SOURCE_SHA256:
    raise ValueError(f"Frozen R11 dependency changed: {R11_PATH}")

spec = importlib.util.spec_from_file_location("argos_o3f8_full_perimeter_r11_for_r13", R11_PATH)
if spec is None or spec.loader is None:
    raise ValueError(f"Cannot load frozen R11 dependency: {R11_PATH}")
R11 = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = R11
spec.loader.exec_module(R11)

R11_RADIAL_CHANNEL_FROM_BASE = R11.radial_channel_from_base
DF_RADIAL_CANDIDATE_LIMIT = int(R11.O3P8_CORROBORATION["maximumSeedCountPerWafer"])
if DF_RADIAL_CANDIDATE_LIMIT != 64:
    raise ValueError("Frozen R11 DF seed ceiling changed.")


def radial_channel_from_base(identity: str, base: dict[str, Any], cfg: dict[str, Any]) -> dict[str, Any]:
    """Use the existing DF seed ceiling without changing the BF topology cap."""
    df_cfg = dict(cfg)
    df_cfg["maximumChannelCandidateCount"] = DF_RADIAL_CANDIDATE_LIMIT
    result = R11_RADIAL_CHANNEL_FROM_BASE(identity, base, df_cfg)
    result["candidateResourceLimit"] = DF_RADIAL_CANDIDATE_LIMIT
    result["candidateResourceLimitSource"] = "FROZEN_O3P8_MAXIMUM_SEED_COUNT_PER_WAFER"
    return result


R11.radial_channel_from_base = radial_channel_from_base
R11.__file__ = str(Path(__file__).resolve())


if __name__ == "__main__":
    raise SystemExit(R11.main())
