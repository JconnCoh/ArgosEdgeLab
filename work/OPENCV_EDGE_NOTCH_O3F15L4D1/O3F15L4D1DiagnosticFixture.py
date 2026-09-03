#!/usr/bin/env python3
"""Deterministic image-free child-output fixture for O3F15L4D1 gates."""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time

RUNNER_SHA = "0D43F29355B7C8CCB1A9FB3A5275E752D305B61710B17F4E293518A3A94D1B81"
TEST_SHA = "E98A90ADCF9E705BCA0B57979167FB7F0DAFE526D24FA015EC85DEA6F184BBE0"
LIMIT = 4 * 1024 * 1024


def sha_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest().upper()


def path_of_length(length: int, directory: str, leaf: str) -> str:
    suffix = f"\\{directory}\\resizedImage\\{leaf}"
    value = "D:\\KLARFExport"
    part = 0
    while len(value) + 1 + 60 + len(suffix) < length:
        value += "\\" + (chr(65 + part % 20) * 60)
        part += 1
    value += "\\" + ("z" * (length - len(value) - len(suffix) - 1)) + suffix
    assert len(value) == length
    return value


def classification(alias_count: int = 0, hard_count: int = 0) -> dict:
    by_class = {name: [] for name in ("DIRECT_SAFE", "VERIFIED_SHORT_ALIAS_REQUIRED", "DIRECT_USE_HARD_STOP_ALIAS_ONLY")}
    identities = []
    leaf_index = 0
    for ordinal in range(1, 979):
        identity = f"FIXTURE_{ordinal:04d}|FRONT"
        identities.append(identity)
        for channel in ("BF", "DF"):
            directory = "BrightfieldFrontsideWafer" if channel == "BF" else "DarkfieldFrontsideWafer"
            leaf = f"{channel}_{ordinal:04d}.bmp"
            if leaf_index < hard_count:
                cls, path = "DIRECT_USE_HARD_STOP_ALIAS_ONLY", path_of_length(198, directory, leaf)
            elif leaf_index < hard_count + alias_count:
                cls, path = "VERIFIED_SHORT_ALIAS_REQUIRED", path_of_length(168, directory, leaf)
            else:
                cls, path = "DIRECT_SAFE", f"D:\\KLARFExport\\Fixture\\{ordinal:04d}\\{directory}\\resizedImage\\{leaf}"
            components = [part for part in path.replace("/", "\\").split("\\") if part]
            row = {"ordinal": ordinal, "identity": identity, "channel": channel, "class": cls, "canonicalPath": path, "rawLength": len(path), "effectiveLength": len(path) + 32, "maximumComponentLength": max(map(len, components))}
            if cls != "DIRECT_SAFE":
                alias = f"Q:\\{directory}\\resizedImage\\{leaf}"
                alias_components = [part for part in alias.split("\\") if part]
                row.update({"aliasPath": alias, "aliasPlannedRawLength": len(alias), "aliasPlannedEffectiveLength": len(alias) + 32, "aliasPlannedMaximumComponentLength": max(map(len, alias_components))})
            by_class[cls].append(row)
            leaf_index += 1
    leaf_counts = {name: len(rows) for name, rows in by_class.items()}
    severity = {"DIRECT_SAFE": 0, "VERIFIED_SHORT_ALIAS_REQUIRED": 1, "DIRECT_USE_HARD_STOP_ALIAS_ONLY": 2}
    pair_class = {}
    for cls, rows in by_class.items():
        for row in rows:
            ordinal = row["ordinal"]
            if ordinal not in pair_class or severity[cls] > severity[pair_class[ordinal]]:
                pair_class[ordinal] = cls
    pair_counts = {name: sum(value == name for value in pair_class.values()) for name in severity}
    class_hashes = {name: sha_text("\n".join(f"{row['identity']}|{row['channel']}" for row in rows) + ("\n" if rows else "")) for name, rows in by_class.items()}
    hard_stops = []
    for ordinal in range(1, 979):
        channels = [row["channel"] for row in by_class["DIRECT_USE_HARD_STOP_ALIAS_ONLY"] if row["ordinal"] == ordinal]
        if channels:
            hard_stops.append({"ordinal": ordinal, "identity": identities[ordinal - 1], "channels": channels})
    value = {
        "corpus": "ACTUAL_FROZEN_978",
        "complete": True,
        "pairCount": 978,
        "identityCount": 978,
        "sourceLeafCount": 1956,
        "uniqueOrderedSourceLeafCount": 1956,
        "pairClassificationCounts": pair_counts,
        "sourceLeafClassificationCounts": leaf_counts,
        "orderedIdentitySha256": sha_text("\n".join(identities) + "\n"),
        "orderedClassificationRecordSha256": sha_text(json.dumps({"fixture":"ordered-classification-records","counts":pair_counts}, separators=(",", ":"))),
        "orderedSourceLeafRecordSha256": sha_text(json.dumps([row for name in by_class for row in by_class[name]], separators=(",", ":"))),
        "classificationLeafIdentitySha256": class_hashes,
        "sourceLeavesByClass": by_class,
        "hardStopIdentities": hard_stops,
    }
    core = json.dumps(value, separators=(",", ":"))
    value.update({"serializedCoreBytes": len(core.encode("utf-8")), "serializedEvidenceLimitBytes": LIMIT})
    return value


def main() -> int:
    if sys.argv[1:] != ["PREFLIGHT"]:
        print("fixture requires exact PREFLIGHT stage", file=sys.stderr, flush=True)
        return 64
    mode = os.environ.get("ARGOS_O3F15L4D1_FIXTURE_MODE", "")
    if mode in {"PASS", "PASS_ONE_ALIAS", "PASS_MANY_ALIAS", "CLASSIFICATION_OVERSIZE", "ZERO_STDERR"}:
        counts = {"PASS": (0, 0), "ZERO_STDERR": (0, 0), "CLASSIFICATION_OVERSIZE": (0, 0), "PASS_ONE_ALIAS": (1, 0), "PASS_MANY_ALIAS": (17, 11)}[mode]
        evidence = classification(*counts)
        if mode == "CLASSIFICATION_OVERSIZE":
            evidence["serializedCoreBytes"] = LIMIT + 1
        result = {"schema": "argos_ocv03_o3f15l4_preflight_v1", "state": "PASS_O3F15L4_FRONT_RECONCILE_PREFLIGHT", "runnerPath": "D:/FIXTURE/Run-O3F15L4FrontReconcile.py", "runnerSha256": RUNNER_SHA, "focusedTestSha256": TEST_SHA, "cohortCounts": {"HOLDOUT18": 18, "CURRENT_TAIL": 247, "FULL_TAIL": 713, "FULL978": 978}, "actualFrozen978LexicalClassification": evidence, "mutationsPerformed": False}
        print(json.dumps(result, separators=(",", ":")), flush=True)
        if mode == "ZERO_STDERR":
            print("O3F15L4D1 fixture exact stderr: ZERO_STDERR", file=sys.stderr, flush=True)
        return 0
    if mode == "NONZERO":
        print('{"fixture":"nonzero-partial"}', flush=True)
        print("O3F15L4D1 fixture exact stderr: NONZERO", file=sys.stderr, flush=True)
        return 7
    if mode == "MALFORMED":
        print("O3F15L4D1 fixture malformed stdout", flush=True)
        return 0
    if mode == "TIMEOUT":
        print("O3F15L4D1 fixture partial stdout before timeout", flush=True)
        print("O3F15L4D1 fixture partial stderr before timeout", file=sys.stderr, flush=True)
        time.sleep(10)
        return 9
    if mode == "OVERSIZE":
        sys.stdout.write("X" * (5 * 1024 * 1024 + 1))
        sys.stdout.flush()
        return 0
    print(f"unknown fixture mode: {mode}", file=sys.stderr, flush=True)
    return 65


if __name__ == "__main__":
    raise SystemExit(main())
