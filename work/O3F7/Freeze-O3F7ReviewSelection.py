#!/usr/bin/env python3
"""Freeze the O3F7 current-recipe crop-review cohort from O3F6 metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any


SOURCE = Path(r"D:\O3F6R8M\RESULTS.json")
SOURCE_SHA256 = "A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8"
OUTPUT = Path(r"D:\O3F7SEL2")
OPERATOR_EXAMPLE_SUFFIXES = ("2ca6ca6c4c", "7d57e118f1")


def need(value: Any, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    need(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value


def write_new(path: Path, value: Any) -> None:
    partial = path.with_name(path.name + ".partial")
    need(not path.exists() and not partial.exists(), f"Output collision: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def circular_gap(left: float, right: float) -> float:
    return abs((left - right + 180.0) % 360.0 - 180.0)


def rank_key(row: dict[str, Any]) -> tuple[int, int, str]:
    return (
        -len(row.get("bfIncompleteTiles") or []),
        -int(row.get("bfCandidateCount") or 0),
        str(row["identity"]),
    )


def project(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "identity": row["identity"],
        "safeId": row["safeId"],
        "state": row["r8State"],
        "bfIncompleteTileCount": len(row.get("bfIncompleteTiles") or []),
        "bfCandidateCount": row.get("bfCandidateCount"),
        "dfCandidateCount": row.get("dfCandidateCount"),
        "diagnosticRoot": row.get("r7DiagnosticRoot"),
    }


def nearest_pairs(bf: list[dict[str, Any]], df: list[dict[str, Any]], limit: int = 3) -> list[dict[str, Any]]:
    pairs = []
    for bf_index, bf_row in enumerate(bf):
        for df_index, df_row in enumerate(df):
            gap = circular_gap(float(bf_row["axisCenterAngleDegrees"]), float(df_row["axisCenterAngleDegrees"]))
            pairs.append(
                {
                    "bfCandidateIndex": bf_index,
                    "dfCandidateIndex": df_index,
                    "bfAngleDegrees": float(bf_row["axisCenterAngleDegrees"]),
                    "dfAngleDegrees": float(df_row["axisCenterAngleDegrees"]),
                    "channelAngleDifferenceDegrees": gap,
                }
            )
    return sorted(pairs, key=lambda row: (row["channelAngleDifferenceDegrees"], row["bfCandidateIndex"], row["dfCandidateIndex"]))[:limit]


def declared_asset(root: Path, role: str, value: dict[str, Any]) -> dict[str, Any]:
    relative = str(value["path"])
    need(relative and not os.path.isabs(relative) and "*" not in relative and "?" not in relative, "Unsafe asset path")
    path = (root / relative).resolve()
    need(os.path.commonpath([os.path.normcase(str(root.resolve())), os.path.normcase(str(path))]) == os.path.normcase(str(root.resolve())), "Asset escapes diagnostic root")
    need(path.is_file() and path.stat().st_size == int(value["bytes"]), f"Declared asset metadata changed: {path}")
    return {
        "role": role,
        "path": str(path),
        "bytes": int(value["bytes"]),
        "sha256": str(value["sha256"]).upper(),
        "pngBytesRead": False,
    }


def add_candidate_assets(assets: list[dict[str, Any]], root: Path, channel: str, index: int, candidates: list[dict[str, Any]]) -> None:
    need(0 <= index < len(candidates), f"{channel} candidate index is out of range")
    declared = candidates[index]["assets"]
    for kind in ("clean", "overlay"):
        assets.append(declared_asset(root, f"{channel}_C{index + 1:02d}_{kind.upper()}", declared[kind]))


def review_case(row: dict[str, Any], categories: list[str]) -> dict[str, Any]:
    state = str(row["r8State"])
    diagnostic_text = row.get("r7DiagnosticRoot")
    if not diagnostic_text:
        need(state == "HOLD_FRONT_NOTCH_PROVIDER_ERROR", "Missing diagnostic root outside provider error")
        return {**project(row), "categories": categories, "assetState": "NO_DIAGNOSTIC_ROOT_PROVIDER_ERROR", "assets": []}
    root = Path(str(diagnostic_text))
    manifest_path = root / "MANIFEST.json"
    if not manifest_path.is_file():
        need(state == "HOLD_FRONT_NOTCH_PROVIDER_ERROR", f"Diagnostic manifest missing: {manifest_path}")
        return {**project(row), "categories": categories, "assetState": "NO_MANIFEST_PROVIDER_ERROR", "assets": []}
    manifest = read_json(manifest_path)
    results = manifest.get("results")
    need(isinstance(results, list) and len(results) == 1, f"Unexpected manifest results: {manifest_path}")
    result = results[0]
    need(str(result["pairId"]) == str(row["safeId"]), f"Pair binding changed: {manifest_path}")
    bf = list(result["bf"]["candidates"])
    df = list(result["df"]["candidates"])
    assets = [
        declared_asset(root, "BF_OVERVIEW", result["bf"]["overview"]),
        declared_asset(root, "DF_OVERVIEW", result["df"]["overview"]),
    ]
    diagnostics: dict[str, Any] = {}
    if state.startswith("PASS"):
        selected = result.get("selectedReviewOnlyManufacturedNotch")
        need(isinstance(selected, dict), f"Pass lacks selected pair: {manifest_path}")
        bf_index = int(selected["bfCandidateIndex"])
        df_index = int(selected["dfCandidateIndex"])
        add_candidate_assets(assets, root, "BF", bf_index, bf)
        add_candidate_assets(assets, root, "DF", df_index, df)
        diagnostics["selectedPair"] = {
            "bfCandidateIndex": bf_index,
            "dfCandidateIndex": df_index,
            "channelAngleDifferenceDegrees": float(selected["channelAngleDifferenceDegrees"]),
        }
    elif state == "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH":
        pairs = nearest_pairs(bf, df)
        diagnostics["nearestUnpairedCandidatesDiagnosticOnly"] = pairs
        used_bf: set[int] = set()
        used_df: set[int] = set()
        for pair in pairs:
            used_bf.add(int(pair["bfCandidateIndex"]))
            used_df.add(int(pair["dfCandidateIndex"]))
        for index in sorted(used_bf):
            add_candidate_assets(assets, root, "BF", index, bf)
        for index in sorted(used_df):
            add_candidate_assets(assets, root, "DF", index, df)
    elif state == "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED":
        diagnostics["dfPerimeterQualified"] = False
        for index in range(min(3, len(bf))):
            add_candidate_assets(assets, root, "BF", index, bf)
    else:
        need(state == "HOLD_FRONT_NOTCH_PROVIDER_ERROR", f"Unexpected review state: {state}")
    return {
        **project(row),
        "categories": categories,
        "manifestPath": str(manifest_path),
        "manifestSha256": sha256(manifest_path),
        "assetState": "EXISTING_DECLARED_ASSETS_READY",
        "diagnostics": diagnostics,
        "assets": assets,
    }


def self_test() -> None:
    rows = [
        {"identity": "b", "bfIncompleteTiles": [1], "bfCandidateCount": 3},
        {"identity": "c", "bfIncompleteTiles": [1, 2], "bfCandidateCount": 1},
        {"identity": "a", "bfIncompleteTiles": [1], "bfCandidateCount": 3},
    ]
    need([row["identity"] for row in sorted(rows, key=rank_key)] == ["c", "a", "b"], "Rank self-test failed")
    bf = [{"axisCenterAngleDegrees": 359.5}, {"axisCenterAngleDegrees": 90.0}]
    df = [{"axisCenterAngleDegrees": 0.5}, {"axisCenterAngleDegrees": 95.0}]
    pairs = nearest_pairs(bf, df, 2)
    need(pairs[0]["channelAngleDifferenceDegrees"] == 1.0 and pairs[0]["bfCandidateIndex"] == 0, "Circular-pair self-test failed")
    print("PASS_O3F7_SELECTION_SELF_TEST")


def run() -> None:
    need(SOURCE.is_file() and sha256(SOURCE) == SOURCE_SHA256, "O3F6 results pin changed")
    need(not OUTPUT.exists(), f"Fresh output root already exists: {OUTPUT}")
    source = read_json(SOURCE)
    rows = list(source["rows"])
    need(len(rows) == 978, "O3F6 row count changed")
    holds = sorted(
        [row for row in rows if str(row["identity"]).startswith("PatternedFront\\") and str(row["r8State"]).startswith("HOLD")],
        key=lambda row: str(row["identity"]),
    )
    patterned_controls = sorted(
        [row for row in rows if str(row["identity"]).startswith("PatternedFront\\") and str(row["r8State"]).startswith("PASS")],
        key=rank_key,
    )[:5]
    unpatterned_controls = sorted(
        [row for row in rows if str(row["identity"]).startswith("UnpatternedFront\\") and str(row["r8State"]).startswith("PASS")],
        key=rank_key,
    )[:5]
    operator_examples = [row for row in rows if str(row["safeId"]).endswith(OPERATOR_EXAMPLE_SUFFIXES)]
    need(len(holds) == 12 and len(patterned_controls) == 5 and len(unpatterned_controls) == 5, "Review cohort cardinality changed")
    need(len(operator_examples) == 2, f"Expected two operator filename examples, found {len(operator_examples)}")
    selection = {
        "schema": "argos_ocv03_o3f7_review_selection_v1",
        "state": "FROZEN_BEFORE_NEW_IMAGE_INSPECTION",
        "sourceResultsSha256": SOURCE_SHA256,
        "patternedHolds": [project(row) for row in holds],
        "patternedPassControls": [project(row) for row in patterned_controls],
        "unpatternedPassControls": [project(row) for row in unpatterned_controls],
        "operatorFilenameExamples": [project(row) for row in operator_examples],
        "selectionFrozenBeforeNewImageInspection": True,
        "imageBytesRead": False,
        "detectorChanged": False,
    }
    OUTPUT.mkdir()
    selection_path = OUTPUT / "SELECTION.json"
    write_new(selection_path, selection)

    combined: dict[str, dict[str, Any]] = {}
    for category, cohort in (
        ("PATTERNED_HOLD", holds),
        ("OPERATOR_FILENAME_EXAMPLE", operator_examples),
        ("PATTERNED_WORST_CONTOUR_PASS_CONTROL", patterned_controls),
        ("UNPATTERNED_WORST_CONTOUR_PASS_CONTROL", unpatterned_controls),
    ):
        for row in cohort:
            key = str(row["identity"])
            if key not in combined:
                combined[key] = {"row": row, "categories": []}
            combined[key]["categories"].append(category)
    ordered = sorted(combined.values(), key=lambda item: (0 if "PATTERNED_HOLD" in item["categories"] else 1, str(item["row"]["identity"])))
    cases = [review_case(item["row"], item["categories"]) for item in ordered]
    review = {
        "schema": "argos_ocv03_o3f7_existing_crop_review_order_v1",
        "state": "READY_FOR_OPERATOR_FILE_REVIEW",
        "selectionSha256": sha256(selection_path),
        "caseCount": len(cases),
        "cases": cases,
        "labels": ["STITCH_VERTICAL_STEP", "STITCH_LATERAL_SHIFT", "HOLDER_EDGE_CONTAMINATION", "NORMAL_NOTCH_VARIATION"],
        "nearestUnpairedCandidatesAreDiagnosticOnly": True,
        "automaticHoldClearance": False,
        "selectorRelaxation": False,
        "pngBytesRead": False,
        "imagesCopiedOrChanged": False,
    }
    review_path = OUTPUT / "REVIEW_ORDER.json"
    write_new(review_path, review)
    lines = []
    for index, case in enumerate(cases, 1):
        lines.append(f"[{index:02d}] {','.join(case['categories'])} | {case['state']} | {case['identity']}")
        for asset in case["assets"]:
            lines.append(f"  {asset['role']}: {asset['path']}")
    text_path = OUTPUT / "REVIEW_ORDER.txt"
    text_path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    summary = {
        "schema": "argos_ocv03_o3f7_review_selection_summary_v1",
        "state": "PASS_O3F7_EXISTING_CROP_REVIEW_READY",
        "selectionSha256": sha256(selection_path),
        "reviewOrderSha256": sha256(review_path),
        "reviewTextSha256": sha256(text_path),
        "caseCount": len(cases),
        "patternedHoldCount": len(holds),
        "patternedPassControlCount": len(patterned_controls),
        "unpatternedPassControlCount": len(unpatterned_controls),
        "operatorExampleCount": len(operator_examples),
        "caseWithExistingAssetsCount": sum(case["assetState"] == "EXISTING_DECLARED_ASSETS_READY" for case in cases),
        "providerErrorWithoutAssetsCount": sum(case["assetState"] != "EXISTING_DECLARED_ASSETS_READY" for case in cases),
        "pngBytesRead": False,
        "imagesCopiedOrChanged": False,
        "sourceMutation": False,
        "detectorChanged": False,
    }
    summary_path = OUTPUT / "SUMMARY.json"
    write_new(summary_path, summary)
    print(json.dumps({**summary, "summarySha256": sha256(summary_path)}, separators=(",", ":")))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("self-test", "run"))
    args = parser.parse_args()
    if args.action == "self-test":
        self_test()
    else:
        run()


if __name__ == "__main__":
    main()
