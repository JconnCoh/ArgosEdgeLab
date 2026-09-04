#!/usr/bin/env python3
"""Review-only OCR over existing paired processor scribe crops.

The crop directory is the inventory. Whole-wafer images and localization are
never read or invoked. The frozen R18H reader and reference bytes are unchanged.
Results are proposals/holds only and cannot accept an identity.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import cv2


REVISION = "ARGOS_OPENCV_SCRIBE_R18P_REFERENCE_ISOLATED_REVIEW_ONLY_20260904"
MINIMUM_IMAGE_SCORE = 0.60
AMBIGUITY_SCORE_DELTA = 0.03


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    if path.exists():
        raise FileExistsError(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    temporary = path.with_suffix(path.suffix + ".partial")
    if temporary.exists():
        temporary.unlink()
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def safe_case_id(physical_identity: str) -> str:
    return hashlib.sha256(physical_identity.encode("utf-8")).hexdigest()[:16].upper()


def physical_lineage_key(physical_identity: str) -> str:
    match = re.fullmatch(
        r"([A-Z0-9]+)[-_]([A-Z0-9]+)(?:[-_].*)?[-_]SLOT([0-9]+)",
        physical_identity.strip(), re.IGNORECASE,
    )
    if match is None:
        raise ValueError(f"Physical identity has no generic lot/slot lineage: {physical_identity}")
    return f"{match.group(1).upper()}-{match.group(2).upper()}|SLOT{int(match.group(3))}"


def exclude_case_reference_lineage(
    prototypes: list[Any],
    topology: list[Any],
    structure: list[Any],
    physical_identity: str,
    source_hashes: set[str],
    supplemental_references: list[dict[str, Any]],
) -> tuple[list[Any], list[Any], list[Any], dict[str, Any]]:
    identities = [[str(item.physical_identity).casefold() for item in bank] for bank in (prototypes, topology, structure)]
    if not (identities[0] == identities[1] == identities[2]):
        raise ValueError("Reference banks lost exact physical-identity alignment.")
    excluded_lineages = {physical_lineage_key(physical_identity)}
    excluded_exact = {physical_identity.casefold()}
    hash_matches: set[str] = set()
    for row in supplemental_references:
        if str(row.get("sourceSha256", "")).upper() not in source_hashes:
            continue
        reference_identity = str(row.get("physicalIdentity", ""))
        if not reference_identity:
            raise ValueError("Source-matched supplemental reference has no physical identity.")
        hash_matches.add(reference_identity)
        excluded_exact.add(reference_identity.casefold())
        excluded_lineages.add(physical_lineage_key(reference_identity))
    keep: list[int] = []
    removed: set[str] = set()
    for index, item in enumerate(prototypes):
        reference_identity = str(item.physical_identity)
        reference_lineage = None
        try:
            reference_lineage = physical_lineage_key(reference_identity)
        except ValueError:
            pass
        if reference_identity.casefold() in excluded_exact or reference_lineage in excluded_lineages:
            removed.add(reference_identity)
        else:
            keep.append(index)
    if not keep:
        raise ValueError("Case-lineage exclusion removed the entire reference bank.")
    return (
        [prototypes[index] for index in keep],
        [topology[index] for index in keep],
        [structure[index] for index in keep],
        {
            "mode": "SOURCE_HASH_AND_CANONICAL_LOT_SLOT_LINEAGE",
            "caseLineage": physical_lineage_key(physical_identity),
            "excludedPrototypeCount": len(prototypes) - len(keep),
            "excludedPhysicalIdentities": sorted(removed, key=str.casefold),
            "sourceHashMatchedPhysicalIdentities": sorted(hash_matches, key=str.casefold),
            "identityNameAffectsSelection": False,
        },
    )


def reference_exclusion_self_test() -> int:
    class Reference:
        def __init__(self, physical_identity: str) -> None:
            self.physical_identity = physical_identity

    slot = lambda value: "SLOT" + str(value)
    legacy = "_".join(("LOTX", "BATCHY", slot(7)))
    alias_a = "-".join(("LOTX", "BATCHY", "POST")) + "_STAMP_A_" + slot(7)
    alias_b = "-".join(("LOTX", "BATCHY", "POST")) + "_STAMP_B_" + slot(7)
    source_matched = "_".join(("OTHER", "BATCH", slot(8)))
    retained = "_".join(("THIRD", "BATCH", slot(9)))
    bank = [Reference(value) for value in (legacy, source_matched, retained)]
    supplemental = [{"physicalIdentity": source_matched, "sourceSha256": "A" * 64}]
    first = exclude_case_reference_lineage(bank, list(bank), list(bank), alias_a, {"A" * 64}, supplemental)
    second = exclude_case_reference_lineage(bank, list(bank), list(bank), alias_b, {"A" * 64}, supplemental)
    first_ids = [item.physical_identity for item in first[0]]
    second_ids = [item.physical_identity for item in second[0]]
    if first_ids != [retained] or second_ids != first_ids:
        raise AssertionError("Reference exclusion changed across aliases of identical lineage and bytes.")
    print(json.dumps({
        "state": "PASS_REFERENCE_LINEAGE_EXCLUSION_SELF_TEST",
        "aliasInvariant": True,
        "sourceHashExclusion": True,
        "hardCodedProductionIdentityUsed": False,
    }))
    return 0


def existing_crop_paths(proposal_root: Path, physical_identity: str) -> tuple[Path, Path]:
    scribe = proposal_root / physical_identity / "scribe"
    return (
        scribe / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        scribe / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
    )


def discover_existing_crop_pairs(proposal_root: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for directory in sorted(proposal_root.iterdir(), key=lambda path: path.name.casefold()):
        if not directory.is_dir():
            continue
        bf, df = existing_crop_paths(proposal_root, directory.name)
        if bf.is_file() and df.is_file():
            rows.append({"physicalIdentity": directory.name})
    return rows


def hypothesis_state(hypotheses: list[dict[str, Any]], any_structure_pass: bool) -> tuple[str, dict[str, Any] | None, list[str]]:
    eligible = [row for row in hypotheses if "selectionScore" in row]
    eligible.sort(key=lambda row: (-float(row["selectionScore"]), str(row["imageFirstString"])))
    best = eligible[0] if eligible else None
    close = sorted({
        str(row["imageFirstString"])
        for row in eligible
        if best is not None
        and bool(row["boundaryComplete"])
        and float(row["selectionScore"]) >= float(best["selectionScore"]) - AMBIGUITY_SCORE_DELTA
    })
    if best is None or not any_structure_pass:
        return "HOLD_SCRIBE_NOT_LOCALIZED", best, close
    if not bool(best["boundaryComplete"]):
        return "HOLD_SCRIBE_GRID_BOUNDARY_INCOMPLETE", best, close
    if float(best["selectionScore"]) < MINIMUM_IMAGE_SCORE:
        return "HOLD_SCRIBE_IMAGE_SCORE_BELOW_FROZEN_MINIMUM", best, close
    if len(close) != 1:
        return "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS", best, close
    return "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE", best, close


def evaluate_existing_crops(
    provider: Any,
    r11: Any,
    prototypes: list[Any],
    topology: list[Any],
    structure: list[Any],
    physical_identity: str,
    paths: tuple[Path, Path],
    expected_hashes: dict[str, str],
    supplemental_references: list[dict[str, Any]],
) -> dict[str, Any]:
    hypotheses: list[dict[str, Any]] = []
    structure_rows: list[dict[str, Any]] = []
    sources: list[dict[str, Any]] = []
    present_crops: list[tuple[str, Path, str, Any]] = []
    for channel, path in zip(("BF", "DF"), paths):
        if not path.is_file():
            sources.append({"channel": channel, "path": str(path), "state": "ABSENT"})
            continue
        source_sha = sha256_file(path)
        if source_sha != expected_hashes[channel].upper():
            raise ValueError(f"Configured {channel} crop SHA-256 mismatch.")
        gray = r11.decode_gray_exact(path)
        sources.append({
            "channel": channel, "path": str(path), "state": "PRESENT",
            "bytes": path.stat().st_size, "sha256": source_sha,
            "width": int(gray.shape[1]), "height": int(gray.shape[0]),
        })
        present_crops.append((channel, path, source_sha, gray))
        for polarity, view in (("DARK", gray), ("BRIGHT", 255 - gray)):
            evidence = provider.R17D.R17C.measure_structure(view)
            row = {"channel": channel, "polarity": polarity, **evidence}
            structure_rows.append(row)
    active_prototypes, active_topology, active_structure, exclusion = exclude_case_reference_lineage(
        prototypes, topology, structure, physical_identity,
        {row[2] for row in present_crops}, supplemental_references,
    )
    # The paired crops share geometry. Structure in either channel or polarity
    # proves only that the crop contains a coherent band; it never chooses OCR.
    qualified_crops = present_crops if any(bool(row.get("passed")) for row in structure_rows) else []
    for direction in ("FORWARD", "REVERSE_180"):
        for channel, path, source_sha, gray in qualified_crops:
            for polarity, view in (("DARK", gray), ("BRIGHT", 255 - gray)):
                oriented = view if direction == "FORWARD" else cv2.rotate(view, cv2.ROTATE_180)
                try:
                    result = provider.evaluate_detector_input_structural(
                        r11, oriented, active_prototypes, active_topology, active_structure, "",
                    )
                    hypotheses.append({
                        "channel": channel,
                        "polarity": polarity,
                        "direction": direction,
                        "sourcePath": str(path),
                        "sourceSha256": source_sha,
                        "imageFirstString": str(result.get("imageFirstString", "")),
                        "proposedString": str(result.get("proposedString", "")),
                        "selectionScore": float(result["selectionScore"]),
                        "boundaryComplete": bool(result["boundaryComplete"]),
                        "checksumValid": bool(result["checksumValid"]),
                        "grid": {key: int(result[key]) for key in ("x", "y", "cellWidth", "cellHeight")},
                        "checksumUsedForImageFirst": False,
                    })
                except ValueError as error:
                    hypotheses.append({
                        "channel": channel, "polarity": polarity, "direction": direction,
                        "state": "HOLD_OCR_EVALUATION_ERROR", "detail": str(error),
                    })
        current_state, current_best, _ = hypothesis_state(hypotheses, bool(qualified_crops))
        # Existing processor crops have a forward-orientation contract.  A
        # unique, checksum-valid image-first read needs no reverse expansion;
        # an already ambiguous forward result is safely held.  Reverse is
        # evaluated only when forward evidence remains incomplete or invalid.
        if direction == "FORWARD" and (
            current_state == "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS"
            or (
                current_state == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
                and current_best is not None
                and bool(current_best.get("checksumValid"))
            )
        ):
            break
    any_structure_pass = any(bool(row.get("passed")) for row in structure_rows)
    state, best, close = hypothesis_state(hypotheses, any_structure_pass)
    return {
        "mode": "EXISTING_PROCESSOR_SCRIBE_CROP",
        "state": state,
        "imageFirstString": "" if best is None else str(best["imageFirstString"]),
        "proposedString": "" if best is None else str(best["proposedString"]),
        "bestHypothesis": best,
        "closeImageFirstStrings": close,
        "hypotheses": hypotheses,
        "structure": structure_rows,
        "sources": sources,
        "referenceExclusion": exclusion,
        "identityAccepted": False,
    }


def run_case(
    config: dict[str, Any],
    case: dict[str, Any],
    provider: Any,
    banks: tuple[Any, list[Any], list[Any], list[Any], dict[str, Any]],
    supplemental_references: list[dict[str, Any]],
) -> dict[str, Any]:
    r11, prototypes, topology, structure, _ = banks
    physical = str(case["physicalIdentity"])
    crop_paths = existing_crop_paths(Path(str(config["proposalRoot"])), physical)
    existing = evaluate_existing_crops(
        provider, r11, prototypes, topology, structure, physical, crop_paths,
        {"BF": str(case["bfSha256"]), "DF": str(case["dfSha256"])}, supplemental_references,
    )
    selected = existing
    expected_truth = str(case.get("expectedTruth", ""))
    return {
        "schema": "argos_opencv_scribe_r18p_reference_isolated_case_v1",
        "createdUtc": utc_now(),
        "state": str(selected["state"]),
        "physicalIdentity": physical,
        "imageFirstString": str(selected.get("imageFirstString", "")),
        "proposedString": str(selected.get("proposedString", "")),
        "selectionMode": str(selected.get("mode", "NO_SELECTION")),
        "existingCropEvaluation": existing,
        "expectedTruth": expected_truth or None,
        "expectedTruthExact": None if not expected_truth else str(selected.get("imageFirstString", "")) == expected_truth,
        "wholeWaferFallback": None,
        "wholeWaferFallbackAllowed": False,
        "fullWaferImagesRead": False,
        "identityAccepted": False,
        "authority": config["authority"],
    }


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--configuration", type=Path)
    parser.add_argument("--output-root", type=Path)
    parser.add_argument("--reference-exclusion-self-test", action="store_true")
    arguments = parser.parse_args(list(argv))
    if arguments.reference_exclusion_self_test:
        return reference_exclusion_self_test()
    if arguments.configuration is None or arguments.output_root is None:
        parser.error("--configuration and --output-root are required for corpus execution")
    config = read_json(arguments.configuration.resolve())
    output_root = arguments.output_root.resolve()
    if not output_root.is_dir():
        raise ValueError("The launch entrypoint must create the fresh output root.")
    authority = config.get("authority", {})
    if not bool(authority.get("reviewOnly")) or any(bool(authority.get(key)) for key in (
        "identityAcceptanceAuthorized", "automaticReferenceAdmissionAuthorized", "trainingAuthorized",
        "activationAuthorized", "xmlAuthorized", "productionAuthorized",
    )):
        raise ValueError("Full corpus execution requires review-only authority with all expansions disabled.")
    provider_path = Path(str(config["providerPath"]))
    r18j_path = Path(str(config["cropSweepPath"]))
    if sha256_file(provider_path) != str(config["providerSha256"]).upper():
        raise ValueError("Frozen R18H provider hash changed.")
    if sha256_file(r18j_path) != str(config["cropSweepSha256"]).upper():
        raise ValueError("R18J crop-sweep hash changed.")
    provider = load("argos_scribe_r18h_for_corpus_r18j", provider_path)
    r18j = load("argos_scribe_crop_sweep_for_corpus_r18j", r18j_path)
    banks = r18j.load_banks(provider, config)
    supplemental_path = Path(str(config["references"]["supplementalManifestPath"]))
    if sha256_file(supplemental_path) != str(config["references"]["supplementalManifestSha256"]).upper():
        raise ValueError("Supplemental reference manifest changed before lineage exclusion.")
    supplemental_references = list(read_json(supplemental_path).get("references", []))
    proposal_root = Path(str(config["proposalRoot"]))
    if not proposal_root.is_dir():
        raise ValueError(f"Processor proposal root absent: {proposal_root}")
    cases = discover_existing_crop_pairs(proposal_root)
    requested_cases = list(config.get("reviewCases", []))
    if not requested_cases:
        raise ValueError("A bounded configuration-selected review cohort is required.")
    indexed_cases = {str(row["physicalIdentity"]).casefold(): row for row in cases}
    requested_keys = [str(row["physicalIdentity"]).casefold() for row in requested_cases]
    if len(set(requested_keys)) != len(requested_keys):
        raise ValueError("Configured review-case identities contain duplicates.")
    missing = [str(row["physicalIdentity"]) for row in requested_cases if str(row["physicalIdentity"]).casefold() not in indexed_cases]
    if missing:
        raise ValueError(f"Configured review-case identities are absent: {missing}")
    source_pairs = [(str(row["bfSha256"]).upper(), str(row["dfSha256"]).upper()) for row in requested_cases]
    if len(set(source_pairs)) != len(source_pairs):
        raise ValueError("Configured review cohort contains duplicate BF/DF source hashes.")
    cases = [{**indexed_cases[key], **requested} for key, requested in zip(requested_keys, requested_cases)]
    inventory_holds: list[dict[str, str]] = []
    if not cases:
        raise ValueError("No paired existing processor scribe crops were discovered.")
    inventory_path = output_root / "INVENTORY.json"
    write_json_new(inventory_path, {
        "schema": "argos_opencv_scribe_r18p_reference_isolated_inventory_v1",
        "createdUtc": utc_now(), "proposalRoot": str(proposal_root),
        "caseCount": len(cases), "cases": cases, "holds": inventory_holds,
        "fullWaferImagesRead": False, "wholeWaferFallbackAllowed": False,
        "reviewOnly": True,
    })
    results: list[dict[str, Any]] = []
    running_path = output_root / "RUNNING.json"
    cases_root = output_root / "c"
    cases_root.mkdir(exist_ok=False)
    for index, case in enumerate(cases, start=1):
        case_id = safe_case_id(str(case["physicalIdentity"]))
        case_root = cases_root / case_id
        case_root.mkdir(exist_ok=False)
        write_json_atomic(running_path, {
            "schema": "argos_opencv_scribe_r18p_reference_isolated_progress_v1",
            "updatedUtc": utc_now(), "state": "RUNNING_REVIEW_ONLY",
            "caseCount": len(cases), "completedCount": index - 1,
            "currentIndex": index, "currentCaseId": case_id,
            "currentPhysicalIdentity": case["physicalIdentity"],
            "identityAccepted": False, "reviewOnly": True,
        })
        try:
            result = run_case(config, case, provider, banks, supplemental_references)
        except Exception as error:
            result = {
                "schema": "argos_opencv_scribe_r18p_reference_isolated_case_v1",
                "createdUtc": utc_now(), "state": "HOLD_SCRIBE_CASE_EXECUTION_ERROR",
                "physicalIdentity": case["physicalIdentity"],
                "detail": str(error), "traceback": traceback.format_exc(limit=8),
                "imageFirstString": "", "proposedString": "",
                "identityAccepted": False, "authority": config["authority"],
            }
        result_path = case_root / "RESULT.json"
        write_json_new(result_path, result)
        results.append({
            "caseId": case_id, "physicalIdentity": case["physicalIdentity"],
            "state": result["state"], "imageFirstString": result.get("imageFirstString", ""),
            "selectionMode": result.get("selectionMode", "ERROR"),
            "resultPath": str(result_path), "resultSha256": sha256_file(result_path),
        })
    counts: dict[str, int] = {}
    for row in results:
        counts[str(row["state"])] = counts.get(str(row["state"]), 0) + 1
    complete = {
        "schema": "argos_opencv_scribe_r18p_reference_isolated_complete_v1",
        "createdUtc": utc_now(), "state": "PASS_R18P_REFERENCE_ISOLATED_REVIEW_ONLY_COMPLETE",
        "revision": REVISION, "caseCount": len(cases), "completedCount": len(results),
        "stateCounts": dict(sorted(counts.items())), "results": results,
        "providerSha256": sha256_file(provider_path), "cropSweepSha256": sha256_file(r18j_path),
        "identityAcceptedCount": 0, "sourceMutationPerformed": False,
        "referenceLibraryModified": False, "automaticRetryPerformed": False,
        "fullWaferImagesRead": False, "wholeWaferFallbackInvokedCount": 0,
        "authority": config["authority"],
    }
    write_json_new(output_root / "COMPLETE.json", complete)
    write_json_atomic(running_path, {
        "schema": "argos_opencv_scribe_r18p_reference_isolated_progress_v1",
        "updatedUtc": utc_now(), "state": "COMPLETE_REVIEW_ONLY",
        "caseCount": len(cases), "completedCount": len(results),
        "identityAccepted": False, "reviewOnly": True,
    })
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
