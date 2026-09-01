#!/usr/bin/env python3
"""Evaluate the R31 split-flank proposal against every full R30 current-recipe result."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


here = Path(__file__).parent
detector_root = Path(__file__).parents[1] / "OPENCV_BACKSIDE_NOTCH_O3B10"
detector_path = detector_root / "Detect-BacksideNotchOpenCvR31.py"
spec = importlib.util.spec_from_file_location("r31_actual_analysis", detector_path)
assert spec is not None and spec.loader is not None
r31 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r31)
r31.R21.R17._PARAMETERS = json.loads(
    (detector_root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]

stdout_path = here / "r30val1_response" / "MAINTENANCE.stdout.txt"
lines = stdout_path.read_text(encoding="utf-8").splitlines()
assert len(lines) == 2
execution = json.loads(lines[0])
assert execution["state"] == "PASS_O3B21_R30VAL1_70_EXECUTIONS_COMPLETE"
assert execution["summarySha256"] == "75AB47B9B2E925DB820F0125BC60A42843791E1DA0983DC7987AAF95D93F4A76"

current = [row for row in execution["summary"]["results"] if row["group"].startswith("CURRENT_RECIPE_SMOKE_")]
assert len(current) == 37
zero_pair = [row for row in current if row["pairedCandidateCount"] == 0]
assert len(zero_pair) == 1
assert zero_pair[0]["id"] == "PatternedFront\\Lot_62632-653\\62632-653_20260829233626\\Slot02|BACK"

triggers = []
for row in current:
    if row["pairedCandidateCount"]:
        continue
    proposed, diagnostic = r31.pair_split_flanks(row["bf"], row["df"])
    if proposed:
        triggers.append({
            "ordinal": row["ordinal"],
            "id": row["id"],
            "proposedPairCount": len(proposed),
            "confirmationMode": proposed[0]["confirmationMode"],
            "meanAngleDegrees": proposed[0]["meanAngleDegrees"],
            "diagnostic": diagnostic,
        })

assert len(triggers) == 1
assert triggers[0]["id"] == zero_pair[0]["id"]
assert triggers[0]["proposedPairCount"] == 1
print(json.dumps({
    "schema": "argos_o3b21_r31_r30_response_analysis_v1",
    "state": "PASS_R31_UNIQUE_TRIGGER_ONLY_ON_PATTERNEDFRONT_SLOT02",
    "r30SummarySha256": execution["summarySha256"],
    "currentRecipeFullCandidateSetCount": len(current),
    "r30ExistingUniquePairCount": sum(row["pairedCandidateCount"] == 1 for row in current),
    "r30ZeroPairCount": len(zero_pair),
    "r31NewTriggerCount": len(triggers),
    "triggers": triggers,
    "thresholdRelaxation": False,
    "existingR30PairBypass": True,
}, indent=2))
