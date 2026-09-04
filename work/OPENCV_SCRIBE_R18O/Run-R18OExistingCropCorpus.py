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
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import cv2


REVISION = "ARGOS_OPENCV_SCRIBE_R18O_EXISTING_CROPS_ONLY_REVIEW_ONLY_20260904"
MINIMUM_IMAGE_SCORE = 0.60
AMBIGUITY_SCORE_DELTA = 0.03
BRIGHT_TOKEN = "BrightfieldFrontsideWafer"
DARK_TOKEN = "DarkfieldFrontsideWafer"
BRIGHT_SUFFIX = "_BrightfieldFrontsideWafer_PM2_resizedImage.bmp"


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


def discover_source_pairs(source_root: Path) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    rows: list[dict[str, Any]] = []
    holds: list[dict[str, str]] = []
    seen: set[str] = set()
    for directory, names, files in os.walk(source_root):
        names.sort(key=str.casefold)
        files.sort(key=str.casefold)
        if Path(directory).name.casefold() != "resizedimage":
            continue
        for filename in files:
            if not filename.casefold().endswith(BRIGHT_SUFFIX.casefold()):
                continue
            bf = Path(directory) / filename
            slot_root = bf.parent.parent.parent
            slot = slot_root.name
            acquisition = slot_root.parent.name
            if not slot.casefold().startswith("slot") or not acquisition:
                holds.append({"path": str(bf), "reason": "UNRECOGNIZED_SOURCE_IDENTITY_PATH"})
                continue
            physical = f"{acquisition}_{slot}"
            key = physical.casefold()
            if key in seen:
                holds.append({"path": str(bf), "reason": "DUPLICATE_PHYSICAL_IDENTITY"})
                continue
            dark_directory = Path(str(bf.parent.parent).replace(BRIGHT_TOKEN, DARK_TOKEN)) / bf.parent.name
            dark_filename = filename.replace(BRIGHT_TOKEN, DARK_TOKEN)
            df = dark_directory / dark_filename
            if not df.is_file():
                holds.append({"path": str(bf), "reason": "PAIRED_DARKFIELD_SOURCE_ABSENT"})
                continue
            seen.add(key)
            rows.append({
                "physicalIdentity": physical,
                "lotRoot": str(slot_root.parent.parent),
                "acquisitionId": acquisition,
                "slotId": slot,
                "bfPath": str(bf),
                "dfPath": str(df),
                "bfBytes": bf.stat().st_size,
                "dfBytes": df.stat().st_size,
            })
    rows.sort(key=lambda row: str(row["physicalIdentity"]).casefold())
    return rows, holds


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
) -> dict[str, Any]:
    hypotheses: list[dict[str, Any]] = []
    structure_rows: list[dict[str, Any]] = []
    sources: list[dict[str, Any]] = []
    present_crops: list[tuple[str, Path, str, Any]] = []
    for channel, path in zip(("BF", "DF"), paths):
        if not path.is_file():
            sources.append({"channel": channel, "path": str(path), "state": "ABSENT"})
            continue
        gray = r11.decode_gray_exact(path)
        source_sha = sha256_file(path)
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
    # The paired BF/DF crops share geometry.  Structure in either channel or
    # polarity proves only that the crop contains a coherent scribe band; it
    # must never choose the OCR channel or polarity.  Slot24 is structurally
    # strongest as BF BRIGHT, reads correctly as BF DARK, and retains a close
    # DF BRIGHT alternative that must remain visible to the ambiguity hold.
    qualified_crops = present_crops if any(bool(row.get("passed")) for row in structure_rows) else []
    for direction in ("FORWARD", "REVERSE_180"):
        for channel, path, source_sha, gray in qualified_crops:
            for polarity, view in (("DARK", gray), ("BRIGHT", 255 - gray)):
                oriented = view if direction == "FORWARD" else cv2.rotate(view, cv2.ROTATE_180)
                try:
                    result = provider.evaluate_detector_input_structural(
                        r11, oriented, prototypes, topology, structure, physical_identity,
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
        "identityAccepted": False,
    }


def whole_wafer_job(config: dict[str, Any], case: dict[str, Any], bf_sha: str, df_sha: str) -> dict[str, Any]:
    return {
        "schema": "argos_opencv_scribe_crop_sweep_job_v1",
        "revision": REVISION,
        "jobId": f"R18J_{safe_case_id(str(case['physicalIdentity']))}",
        "identity": {
            "lotId": Path(str(case["lotRoot"])).name,
            "acquisitionId": case["acquisitionId"],
            "slotId": case["slotId"],
            "physicalIdentity": case["physicalIdentity"],
        },
        "inputs": {
            "bf": {"path": case["bfPath"], "sha256": bf_sha, "bytes": case["bfBytes"]},
            "df": {"path": case["dfPath"], "sha256": df_sha, "bytes": case["dfBytes"]},
        },
        "references": config["references"],
        "authority": config["authority"],
    }


def run_case(
    config: dict[str, Any],
    case: dict[str, Any],
    case_root: Path,
    provider: Any,
    r18j: Any,
    banks: tuple[Any, list[Any], list[Any], list[Any], dict[str, Any]],
) -> dict[str, Any]:
    r11, prototypes, topology, structure, _ = banks
    physical = str(case["physicalIdentity"])
    crop_paths = existing_crop_paths(Path(str(config["proposalRoot"])), physical)
    existing = evaluate_existing_crops(provider, r11, prototypes, topology, structure, physical, crop_paths)
    selected = existing
    return {
        "schema": "argos_opencv_scribe_r18o_existing_crop_case_v1",
        "createdUtc": utc_now(),
        "state": str(selected["state"]),
        "physicalIdentity": physical,
        "imageFirstString": str(selected.get("imageFirstString", "")),
        "proposedString": str(selected.get("proposedString", "")),
        "selectionMode": str(selected.get("mode", "WHOLE_WAFER_R18J_FALLBACK")),
        "existingCropEvaluation": existing,
        "wholeWaferFallback": None,
        "wholeWaferFallbackAllowed": False,
        "fullWaferImagesRead": False,
        "identityAccepted": False,
        "authority": config["authority"],
    }


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--configuration", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    arguments = parser.parse_args(list(argv))
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
    proposal_root = Path(str(config["proposalRoot"]))
    if not proposal_root.is_dir():
        raise ValueError(f"Processor proposal root absent: {proposal_root}")
    cases = discover_existing_crop_pairs(proposal_root)
    inventory_holds: list[dict[str, str]] = []
    if not cases:
        raise ValueError("No paired existing processor scribe crops were discovered.")
    inventory_path = output_root / "INVENTORY.json"
    write_json_new(inventory_path, {
        "schema": "argos_opencv_scribe_r18o_existing_crop_inventory_v1",
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
            "schema": "argos_opencv_scribe_r18j_corpus_progress_v1",
            "updatedUtc": utc_now(), "state": "RUNNING_REVIEW_ONLY",
            "caseCount": len(cases), "completedCount": index - 1,
            "currentIndex": index, "currentCaseId": case_id,
            "currentPhysicalIdentity": case["physicalIdentity"],
            "identityAccepted": False, "reviewOnly": True,
        })
        try:
            result = run_case(config, case, case_root, provider, r18j, banks)
        except Exception as error:
            result = {
                "schema": "argos_opencv_scribe_r18o_existing_crop_case_v1",
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
        "schema": "argos_opencv_scribe_r18o_existing_crop_complete_v1",
        "createdUtc": utc_now(), "state": "PASS_R18O_EXISTING_CROPS_REVIEW_ONLY_COMPLETE",
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
        "schema": "argos_opencv_scribe_r18j_corpus_progress_v1",
        "updatedUtc": utc_now(), "state": "COMPLETE_REVIEW_ONLY",
        "caseCount": len(cases), "completedCount": len(results),
        "identityAccepted": False, "reviewOnly": True,
    })
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
