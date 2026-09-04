#!/usr/bin/env python3
"""Local, review-only generalization and regression gate for R18Q."""

from __future__ import annotations

import argparse
import ast
import dataclasses
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def require_hash(path: Path, expected: str) -> None:
    actual = sha256_file(path)
    if actual != expected.upper():
        raise ValueError(f"Frozen fixture changed: {path}: {actual} != {expected}")


def bank_context(provider: Any, r11: Any, appearance: list[Any], topology: list[Any], structure: list[Any]) -> tuple[Any, Any, Any, Any, Any]:
    bank = r11.PrototypeBank.from_prototypes(appearance)
    topology_matrix = np.vstack([row.descriptor.astype(np.float64) for row in topology])
    topology_indices = provider.R17D._label_indices(np.asarray([row.label for row in topology]))
    run_scaling, run_consensus = provider._run_structure_context(structure)
    return bank, topology_matrix, topology_indices, run_scaling, run_consensus


def rank_query(provider: Any, r11: Any, query: Any, query_topology: Any, query_structure: Any, active: tuple[list[Any], list[Any], list[Any]], position: int = 0) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    bank, matrix, indices, scaling, consensus = bank_context(provider, r11, *active)
    return provider.rank_with_run_structure(
        r11, query.descriptor, query_topology.descriptor, query_structure.descriptor,
        bank, matrix, indices, scaling, consensus, position,
    )


def predecessor_rank(provider: Any, r11: Any, query: Any, query_topology: Any, query_structure: Any, active: tuple[list[Any], list[Any], list[Any]], position: int = 0) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    bank, matrix, indices, scaling, consensus = bank_context(provider, r11, *active)
    return provider.R18H.rank_with_run_structure(
        r11, query.descriptor, query_topology.descriptor, query_structure.descriptor,
        bank, matrix, indices, scaling, consensus, position,
    )


def load_banks(project: Path, provider: Any, fixtures: dict[str, Any]) -> tuple[Any, list[Any], list[Any], list[Any], list[dict[str, Any]]]:
    r11 = provider.R17D.R17C.R17B._load_r11()
    base = fixtures["baseReferenceManifest"]
    supplement = fixtures["supplementalReferenceManifest"]
    manifest = project / base["path"]
    supplemental_path = project / supplement["path"]
    require_hash(manifest, base["sha256"])
    require_hash(supplemental_path, supplement["sha256"])
    roots = {
        "glyphs": manifest.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": manifest.parent / "glyphs_v5_confirmed_20260806",
    }
    appearance, evidence = r11.load_reference_prototypes(manifest, base["sha256"], roots)
    appearance, _ = provider.R18F.R18F_LOADER.combine_reference_prototypes(
        r11, appearance, evidence, supplemental_path, supplement["sha256"],
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, manifest, base["sha256"], roots, supplemental_path, supplement["sha256"],
    )
    structure = provider.load_run_structure_prototypes(
        r11, manifest, base["sha256"], roots, supplemental_path, supplement["sha256"],
    )
    keys = [(row.label, row.physical_identity) for row in appearance]
    if keys != [(row.label, row.physical_identity) for row in topology] or keys != [
        (row.label, row.physical_identity) for row in structure
    ]:
        raise AssertionError("Appearance, topology, and run-structure banks are not aligned.")
    supplemental_rows = list(read_json(supplemental_path).get("references", []))
    return r11, appearance, topology, structure, supplemental_rows


def authoritative_fixture_gate(project: Path, fixtures: dict[str, Any]) -> dict[str, Any]:
    inputs = fixtures["authoritativeInputs"]
    manifest_path = project / inputs["completeScribeManifestPath"]
    cohort_path = project / inputs["r18pReviewCohortPath"]
    manifest = read_json(manifest_path)
    cohort = read_json(cohort_path)
    evidence = manifest["validatedEvidence"]
    authoritative_visible = (
        evidence["r18hFrozenVisibleStrings"]
        + evidence["r18fBlindStrings"]
        + evidence["r18gDevelopmentStrings"]
        + evidence["additionalDevelopmentStrings"]
    )
    configured_visible = [row["expected"] for row in fixtures["directVisible"] + fixtures["resultVisible"]]
    configured_blanks = [row["physicalIdentity"] for row in fixtures["blankControls"]]
    if len(authoritative_visible) != 21 or sorted(configured_visible) != sorted(authoritative_visible):
        raise AssertionError("The 21 visible fixtures diverge from the complete scribe manifest.")
    if configured_blanks != evidence["blankWrongLocationControls"]:
        raise AssertionError("The blank-control fixtures diverge from the complete scribe manifest.")
    displaced = fixtures["displacedS17"]
    if (
        displaced["physicalIdentity"] != evidence["misplacedScribe"]["physicalIdentity"]
        or displaced["expected"] != evidence["misplacedScribe"]["string"]
    ):
        raise AssertionError("The displaced-S17 fixture diverges from the complete scribe manifest.")
    slot24 = fixtures["slot24"]
    corpus = evidence["localCorpusGate"]
    if (
        slot24["expected"] != evidence["slot24CropGate"]["string"]
        or slot24["expected"] != corpus["topImageFirstString"]
        or slot24["expectedCloseImageFirstStrings"] != sorted([corpus["closeAlternative"], corpus["topImageFirstString"]])
        or slot24["expectedWrapperState"] != corpus["state"]
    ):
        raise AssertionError("The Slot24 fixture diverges from the complete scribe manifest.")
    truth_rows = {
        row["physicalIdentity"]: {
            "expected": row["expectedTruth"], "bfSha256": row["bfSha256"], "dfSha256": row["dfSha256"],
        }
        for row in cohort["reviewCases"] if row.get("expectedTruth")
    }
    local = fixtures["isolatedTruthCases"]["locallyAvailableWholeCrop"]
    missing = fixtures["isolatedTruthCases"]["missingWholeCrop"]
    configured_truth = {
        local["physicalIdentity"]: {"expected": local["expected"], "bfSha256": local["bf"]["sha256"], "dfSha256": local["df"]["sha256"]},
        missing["physicalIdentity"]: {"expected": missing["expected"], "bfSha256": missing["bfSha256"], "dfSha256": missing["dfSha256"]},
    }
    if configured_truth != truth_rows or len(truth_rows) != 2:
        raise AssertionError("The isolated K-truth fixtures diverge from the R18P review cohort.")
    return {
        "completeScribeManifestSha256": sha256_file(manifest_path),
        "r18pReviewCohortSha256": sha256_file(cohort_path),
        "visibleStringCount": len(authoritative_visible), "blankControlCount": len(configured_blanks),
        "isolatedTruthCount": len(truth_rows), "allExact": True,
    }


def check_fixed_grid(provider: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], gray: np.ndarray, grid: tuple[int, int, int, int], expected: str, identity: str, group: str) -> tuple[dict[str, Any], dict[str, Any]]:
    checked = provider.evaluate_detector_input_structural(r11, gray, *banks, "", grid)
    checked = provider.R17E.enforce_grid_verifier_only(checked)
    if checked["imageFirstString"] != expected or checked["proposedString"] != expected:
        raise AssertionError(
            f"Frozen visible regression changed: {identity}: "
            f"{checked['imageFirstString']} / {checked['proposedString']} != {expected}"
        )
    return ({
        "group": group,
        "physicalIdentity": identity,
        "expected": expected,
        "imageFirstString": checked["imageFirstString"],
        "selectionScore": float(checked["selectionScore"]),
    }, checked)


def visible_gate(project: Path, provider: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], fixtures: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    t7_detail: dict[str, Any] | None = None
    for case in fixtures["directVisible"]:
        source = Path(case["sourcePath"])
        require_hash(source, case["sourceSha256"])
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        view = 255 - gray if case["invert"] else gray
        row, checked = check_fixed_grid(
            provider, r11, banks, view, tuple(case["grid"]),
            case["expected"], case["physicalIdentity"], case["group"],
        )
        rows.append(row)
        if case["expected"] == "1478T161SUG7":
            arbitration = checked["positions"][4]["glyphArbitration"]
            if not arbitration.get("runStructureApplied") or arbitration.get("strongStructureApplied"):
                raise AssertionError("The frozen T/7 case no longer uses only the R18H near-tie lane.")
            t7_detail = {
                "physicalIdentity": case["physicalIdentity"],
                "position": 5,
                "mode": arbitration["mode"],
                "appearanceFirst": arbitration["appearanceFirst"],
                "runStructureFirst": arbitration["runStructureFirst"],
                "strongStructureApplied": arbitration["strongStructureApplied"],
            }
    for case in fixtures["resultVisible"]:
        result_path = Path(case["resultPath"])
        require_hash(result_path, case["resultSha256"])
        frozen = read_json(result_path)
        selected = frozen["hypotheses"][0]
        channel = str(selected["channel"])
        source_row = frozen["provenance"]["sources"][channel.lower()]
        source = Path(str(source_row["path"]))
        require_hash(source, str(source_row["sha256"]))
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        view = 255 - gray if selected["polarity"] == "BRIGHT" else gray
        if selected["direction"] == "REVERSE_180":
            view = cv2.rotate(view, cv2.ROTATE_180)
        grid = tuple(int(selected[key]) for key in ("x", "y", "cellWidth", "cellHeight"))
        row, _ = check_fixed_grid(
            provider, r11, banks, view, grid, case["expected"],
            result_path.parent.name, case["group"],
        )
        rows.append(row)
    if len(rows) != 21 or t7_detail is None:
        raise AssertionError("The complete 21-string visible set or T/7 control was not executed.")
    return rows, t7_detail


def lineage_sweep(provider: Any, isolation: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], supplemental_rows: list[dict[str, Any]]) -> tuple[dict[str, Any], list[int]]:
    appearance, topology, structure = banks
    predecessor_correct = 0
    successor_correct = 0
    changes: list[dict[str, Any]] = []
    harmed: list[dict[str, Any]] = []
    kr_rows: list[dict[str, Any]] = []
    rename_indices: list[int] = []
    for index, query in enumerate(appearance):
        active_a, active_t, active_s, exclusion = isolation.exclude_case_reference_lineage(
            appearance, topology, structure, query.physical_identity, set(), supplemental_rows,
        )
        active = (active_a, active_t, active_s)
        before_ranked, _ = predecessor_rank(
            provider, r11, query, topology[index], structure[index], active,
        )
        after_ranked, arbitration = rank_query(
            provider, r11, query, topology[index], structure[index], active,
        )
        before = str(before_ranked[0]["character"])
        after = str(after_ranked[0]["character"])
        predecessor_correct += int(before == query.label)
        successor_correct += int(after == query.label)
        if float(after_ranked[0]["score"]) > float(before_ranked[0]["score"]) + 1e-12:
            raise AssertionError("R18Q increased a selected appearance score.")
        if before != after:
            changed = {
                "referenceIndex": index,
                "physicalIdentity": query.physical_identity,
                "truth": query.label,
                "before": before,
                "after": after,
                "runStructureDistance": arbitration["runStructureFirstDistance"],
                "runStructureMargin": arbitration["runStructureMargin"],
                "appearanceDeficit": arbitration["strongStructureAppearanceDeficit"],
                "excludedPrototypeCount": exclusion["excludedPrototypeCount"],
            }
            changes.append(changed)
            rename_indices.append(index)
            if before == query.label and after != query.label:
                harmed.append(changed)
        if query.label in {"K", "R"}:
            kr_rows.append({
                "referenceIndex": index,
                "physicalIdentity": query.physical_identity,
                "lineage": exclusion["caseLineage"],
                "truth": query.label,
                "predecessor": before,
                "successor": after,
                "runStructureFirst": arbitration["runStructureFirst"],
                "runStructureDistance": arbitration["runStructureFirstDistance"],
                "runStructureMargin": arbitration["runStructureMargin"],
                "strongStructureApplied": arbitration["strongStructureApplied"],
                "excludedPrototypeCount": exclusion["excludedPrototypeCount"],
            })
            rename_indices.append(index)
    if harmed or predecessor_correct != 387 or successor_correct != 389 or len(changes) != 2:
        raise AssertionError(
            f"Unexpected lineage sweep: predecessor={predecessor_correct}, "
            f"successor={successor_correct}, changes={len(changes)}, harmed={len(harmed)}"
        )
    k_rows = [row for row in kr_rows if row["truth"] == "K"]
    r_rows = [row for row in kr_rows if row["truth"] == "R"]
    k_lineages = sorted({row["lineage"] for row in k_rows})
    r_lineages = sorted({row["lineage"] for row in r_rows})
    if (
        len(k_rows) != 2 or len(r_rows) != 4 or len(k_lineages) != 2 or len(r_lineages) != 3
        or any(row["successor"] != row["truth"] for row in kr_rows)
    ):
        raise AssertionError(f"Reciprocal K/R lineage gate failed: {kr_rows}")
    return ({
        "referenceCount": len(appearance),
        "predecessorCorrect": predecessor_correct,
        "successorCorrect": successor_correct,
        "changedCount": len(changes),
        "harmedPreviouslyCorrectCount": len(harmed),
        "selectedScoreNeverIncreased": True,
        "changes": changes,
        "reciprocalKr": {
            "kExact": len(k_rows),
            "kTotal": len(k_rows),
            "rExact": len(r_rows),
            "rTotal": len(r_rows),
            "kDistinctLineageCount": len(k_lineages),
            "rDistinctLineageCount": len(r_lineages),
            "kLineages": k_lineages,
            "rLineages": r_lineages,
            "crossConfusionCount": 0,
            "rows": kr_rows,
        },
    }, sorted(set(rename_indices)))


def label_renaming_gate(provider: Any, isolation: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], supplemental_rows: list[dict[str, Any]], indices: list[int]) -> dict[str, Any]:
    appearance, topology, structure = banks
    labels = list(r11.BODY_LABELS)
    rotated = labels[7:] + labels[:7]
    mapping = dict(zip(labels, rotated))
    rows: list[dict[str, Any]] = []
    for index in indices:
        query = appearance[index]
        active = isolation.exclude_case_reference_lineage(
            appearance, topology, structure, query.physical_identity, set(), supplemental_rows,
        )[:3]
        original, _ = rank_query(provider, r11, query, topology[index], structure[index], active)
        renamed = tuple([
            dataclasses.replace(row, label=mapping[row.label]) for row in bank
        ] for bank in active)
        renamed_ranked, _ = rank_query(
            provider, r11, query, topology[index], structure[index], renamed,
        )
        expected = mapping[str(original[0]["character"])]
        actual = str(renamed_ranked[0]["character"])
        if actual != expected:
            raise AssertionError(f"Label-renaming invariance failed: {query.physical_identity}")
        rows.append({
            "referenceIndex": index,
            "originalWinner": original[0]["character"],
            "renamedWinner": actual,
            "expectedRenamedWinner": expected,
        })
    return {"bijectionOffset": 7, "caseCount": len(rows), "allInvariant": True, "rows": rows}


def engine_hardcode_gate(project: Path, provider_path: Path, fixtures: dict[str, Any], r11: Any) -> dict[str, Any]:
    sources = [project / path for path in fixtures["runtimeSources"]]
    forbidden_exact: set[str] = set()
    cohort = read_json(project / fixtures["authoritativeInputs"]["r18pReviewCohortPath"])
    forbidden_exact.update(
        str(row["physicalIdentity"]) for row in cohort["reviewCases"] if row.get("physicalIdentity")
    )
    for row in fixtures["directVisible"]:
        forbidden_exact.update((row["physicalIdentity"], row["expected"]))
    for row in fixtures["resultVisible"]:
        forbidden_exact.add(row["expected"])
        forbidden_exact.add(Path(row["resultPath"]).parent.name)
    for row in fixtures["blankControls"]:
        forbidden_exact.add(row["physicalIdentity"])
    for row in fixtures["isolatedTruthCases"].values():
        forbidden_exact.update((row["physicalIdentity"], row["expected"]))
    forbidden_exact.update((fixtures["displacedS17"]["physicalIdentity"], fixtures["displacedS17"]["expected"]))
    forbidden_exact.update((fixtures["slot24"]["physicalIdentity"], fixtures["slot24"]["expected"]))
    forbidden_exact.update(fixtures["slot24"]["expectedCloseImageFirstStrings"])
    production_pattern = re.compile(
        r"(?i)(?<![A-Z0-9])(?:lot[-_])?\d{5,6}[-_]\d{3}(?![A-Z0-9])"
        r"|(?<![A-Z0-9])slot\d+(?![A-Z0-9])"
    )
    violations: list[dict[str, Any]] = []
    hashes: list[dict[str, Any]] = []
    for path in sources:
        text = path.read_text(encoding="utf-8-sig")
        casefolded = text.casefold()
        hashes.append({"path": str(path.relative_to(project)).replace("\\", "/"), "sha256": sha256_file(path)})
        matches = sorted(set(match.group(0) for match in production_pattern.finditer(text)))
        exact = sorted(value for value in forbidden_exact if value and value.casefold() in casefolded)
        literals = [
            node.value for node in ast.walk(ast.parse(text))
            if isinstance(node, ast.Constant) and isinstance(node.value, str)
        ]
        absolute = sorted(set(
            value for value in literals
            if re.match(r"(?i)^[A-Z]:[\\/]", value) or value.startswith("\\\\")
        ))
        if matches or exact or absolute:
            violations.append({
                "path": str(path), "productionTokens": matches,
                "fixtureLiterals": exact, "absoluteRootLiterals": absolute,
            })
    source = provider_path.read_text(encoding="utf-8-sig")
    tree = ast.parse(source)
    arbitration = next(
        node for node in tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == "rank_with_run_structure"
    )
    label_literals = sorted({
        node.value for node in ast.walk(arbitration)
        if isinstance(node, ast.Constant) and isinstance(node.value, str)
        and len(node.value) == 1 and node.value.upper() in set(r11.BODY_LABELS)
    })
    if violations or label_literals:
        raise AssertionError(f"Runtime hardcode gate failed: {violations}; labels={label_literals}")
    lowered = "\n".join(path.read_text(encoding="utf-8-sig").lower() for path in sources)
    if "synthetic" in lowered or "notch" in lowered:
        raise AssertionError("Runtime OCR sources introduced synthetic or notch-dependent behavior.")
    return {
        "runtimeSourceCount": len(sources),
        "runtimeSources": hashes,
        "productionShapedLiteralCount": 0,
        "configuredIdentityOrTruthLiteralCount": 0,
        "oneCharacterLabelLiteralCountInArbitration": 0,
        "labelSpecificArbitration": False,
        "syntheticDotCreationCodeFound": False,
        "notchDependencyCodeFound": False,
    }


def isolated_whole_crop_gate(provider: Any, isolation: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], supplemental_rows: list[dict[str, Any]], fixtures: dict[str, Any]) -> dict[str, Any]:
    case = fixtures["isolatedTruthCases"]["locallyAvailableWholeCrop"]
    for source in (case["bf"], case["df"]):
        require_hash(Path(source["path"]), source["sha256"])
    active = isolation.exclude_case_reference_lineage(
        *banks, case["physicalIdentity"], {case["bf"]["sha256"], case["df"]["sha256"]}, supplemental_rows,
    )
    gray = cv2.imread(str(Path(case["bf"]["path"])), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise FileNotFoundError(case["bf"]["path"])
    checked = provider.evaluate_detector_input_structural(
        r11, gray, active[0], active[1], active[2], "", tuple(case["grid"]),
    )
    checked = provider.R17E.enforce_grid_verifier_only(checked)
    if checked["imageFirstString"] != case["expected"] or checked["proposedString"] != case["expected"]:
        raise AssertionError("The exact locally available isolated whole-crop truth failed.")
    arbitration = checked["positions"][4]["glyphArbitration"]
    if not arbitration.get("strongStructureApplied") or arbitration["runStructureFirst"] != "K":
        raise AssertionError("The Slot22 correction did not use the generic strong-structure lane.")
    print(json.dumps({"progress": "slot22_wrapper_start"}), flush=True)
    wrapped = isolation.evaluate_existing_crops(
        provider, r11, *banks, case["physicalIdentity"],
        (Path(case["bf"]["path"]), Path(case["df"]["path"])),
        {"BF": case["bf"]["sha256"], "DF": case["df"]["sha256"]}, supplemental_rows,
    )
    if (
        wrapped["state"] != case["expectedWrapperState"]
        or wrapped["imageFirstString"] != case["expected"]
        or wrapped["proposedString"] != case["expected"]
        or wrapped["closeImageFirstStrings"] != [case["expected"]]
        or len(wrapped["hypotheses"]) != case["expectedHypothesisCount"]
        or wrapped["bestHypothesis"] is None
        or wrapped["bestHypothesis"]["checksumValid"] is not True
        or any(row.get("checksumUsedForImageFirst") is not False for row in wrapped["hypotheses"])
        or wrapped["identityAccepted"] is not False
    ):
        raise AssertionError(f"The exact Slot22 existing-crop wrapper failed: {wrapped}")
    missing = fixtures["isolatedTruthCases"]["missingWholeCrop"]
    return {
        "locallyAvailableExact": 1,
        "locallyAvailableTotal": 1,
        "fixedGrid": {
            "physicalIdentity": case["physicalIdentity"],
            "expected": case["expected"],
            "imageFirstString": checked["imageFirstString"],
            "proposedString": checked["proposedString"],
            "checksumValid": bool(checked["checksumValid"]),
            "selectionScore": float(checked["selectionScore"]),
            "referenceExclusion": active[3],
            "position5Arbitration": arbitration,
        },
        "existingCropWrapper": {
            "state": wrapped["state"], "imageFirstString": wrapped["imageFirstString"],
            "proposedString": wrapped["proposedString"], "checksumValid": wrapped["bestHypothesis"]["checksumValid"],
            "hypothesisCount": len(wrapped["hypotheses"]), "closeImageFirstStrings": wrapped["closeImageFirstStrings"],
            "identityAccepted": wrapped["identityAccepted"], "referenceExclusion": wrapped["referenceExclusion"],
        },
        "missingExactLocalFixture": {
            "physicalIdentity": missing["physicalIdentity"],
            "expected": missing["expected"],
            "bfSha256": missing["bfSha256"],
            "dfSha256": missing["dfSha256"],
            "state": missing["localStatus"],
            "truthMayNotSelectGlyph": True,
        },
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
    }


def blank_gate(provider: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], fixtures: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for case in fixtures["blankControls"]:
        scores: list[float] = []
        for channel in ("BF", "DF"):
            source = case["sources"][channel]
            path = Path(source["path"])
            require_hash(path, source["sha256"])
            gray = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
            if gray is None:
                raise FileNotFoundError(path)
            for view in (gray, 255 - gray, cv2.rotate(gray, cv2.ROTATE_180), cv2.rotate(255 - gray, cv2.ROTATE_180)):
                checked = provider.evaluate_detector_input_structural(r11, view, *banks, "")
                scores.append(float(checked["selectionScore"]))
        maximum = max(scores)
        if len(scores) != 8 or maximum >= provider.MINIMUM_POST_GRID_IMAGE_SCORE:
            raise AssertionError(f"Blank control reached the frozen presence floor: {case['physicalIdentity']}: {maximum}")
        rows.append({
            "physicalIdentity": case["physicalIdentity"],
            "evaluatedViewCount": len(scores),
            "maximumSelectionScore": maximum,
            "presenceFloor": provider.MINIMUM_POST_GRID_IMAGE_SCORE,
            "decision": "HOLD_SCRIBE_NOT_LOCALIZED",
            "outputStringAllowed": False,
        })
        print(json.dumps({"progress": "blank", "physicalIdentity": case["physicalIdentity"], "maximum": maximum}), flush=True)
    return rows


def displaced_gate(project: Path, provider: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], fixtures: dict[str, Any]) -> dict[str, Any]:
    case = fixtures["displacedS17"]
    gate_path = project / case["gatePath"]
    result_path = Path(case["caseResultPath"])
    require_hash(gate_path, case["gateSha256"])
    require_hash(result_path, case["caseResultSha256"])
    frozen = read_json(result_path)
    if (
        frozen["state"] != case["expectedState"] or frozen["canonicalTruth"] != case["expected"]
        or frozen["eligibleIdentity"] is not case["expectedEligibleIdentity"]
    ):
        raise AssertionError("The displaced-S17 frozen state, truth, or identity hold changed.")
    artifact = next(row for row in frozen["artifacts"] if row["kind"] == "ORIENTED_GRID")
    selected_grid = Path(case["selectedGridPath"])
    if artifact["sha256"] != case["selectedGridSha256"]:
        raise AssertionError("R13B result no longer names the pinned selected-grid bytes.")
    require_hash(selected_grid, case["selectedGridSha256"])
    gray = cv2.imread(str(selected_grid), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise FileNotFoundError(selected_grid)
    if tuple(gray.shape) != (210, 1164) or gray.shape[1] != 12 * int(case["grid"][2]):
        raise AssertionError(f"Displaced-S17 selected-grid dimensions changed: {gray.shape}")
    if case["invert"]:
        gray = 255 - gray
    checked = provider.evaluate_detector_input_structural(r11, gray, *banks, "", tuple(case["grid"]))
    checked = provider.R17E.enforce_grid_verifier_only(checked)
    if checked["imageFirstString"] != case["expected"] or checked["proposedString"] != case["expected"]:
        raise AssertionError("R18Q changed the frozen displaced-S17 selected-grid read.")
    modes = [row["glyphArbitration"]["mode"] for row in checked["positions"]]
    if modes != ["APPEARANCE"] * 12:
        raise AssertionError(f"Displaced-S17 arbitration unexpectedly changed: {modes}")
    return {
        "scope": "FROZEN_R13B_SELECTED_GRID_ARBITRATION_REPLAY_NOT_RELOCALIZATION",
        "inheritedLocalizationGateSha256": case["gateSha256"],
        "caseResultSha256": case["caseResultSha256"],
        "physicalIdentity": case["physicalIdentity"],
        "frozenState": frozen["state"],
        "selectedGridPath": case["selectedGridPath"],
        "selectedGridSha256": case["selectedGridSha256"],
        "selectedGridDimensions": [1164, 210],
        "imageFirstString": checked["imageFirstString"],
        "proposedString": checked["proposedString"],
        "checksumValid": bool(checked["checksumValid"]),
        "strongStructureAppliedPositions": [
            row["position"] for row in checked["positions"]
            if row["glyphArbitration"].get("strongStructureApplied")
        ],
        "allArbitrationModes": modes,
        "identityAccepted": False,
        "holdPreserved": True,
    }


def slot24_gate(provider: Any, isolation: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]], supplemental_rows: list[dict[str, Any]], fixtures: dict[str, Any]) -> dict[str, Any]:
    case = fixtures["slot24"]
    source = Path(case["sourcePath"])
    require_hash(source, case["sourceSha256"])
    gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise FileNotFoundError(source)
    fixed = provider.evaluate_detector_input_structural(r11, gray, *banks, "", tuple(case["grid"]))
    fixed = provider.R17E.enforce_grid_verifier_only(fixed)
    if fixed["imageFirstString"] != case["expected"] or fixed["proposedString"] != case["expected"]:
        raise AssertionError("Slot24 frozen crop/grid changed.")
    root = Path(case["wrapperRoot"])
    scribe = root / case["physicalIdentity"] / "scribe"
    paths = (
        scribe / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        scribe / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
    )
    print(json.dumps({"progress": "slot24_wrapper_start"}), flush=True)
    wrapped = isolation.evaluate_existing_crops(
        provider, r11, *banks, case["physicalIdentity"], paths,
        {"BF": case["bfSha256"], "DF": case["dfSha256"]}, supplemental_rows,
    )
    if (
        wrapped["state"] != case["expectedWrapperState"]
        or wrapped["imageFirstString"] != case["expected"]
        or wrapped["closeImageFirstStrings"] != case["expectedCloseImageFirstStrings"]
        or len(wrapped["hypotheses"]) != case["expectedHypothesisCount"]
        or any(row.get("checksumUsedForImageFirst") is not False for row in wrapped["hypotheses"])
        or wrapped["identityAccepted"] is not False
    ):
        raise AssertionError(f"Slot24 wrapper semantics changed: {wrapped}")
    return {
        "fixedGrid": {
            "imageFirstString": fixed["imageFirstString"],
            "proposedString": fixed["proposedString"],
            "selectionScore": float(fixed["selectionScore"]),
            "sourceSha256": case["sourceSha256"],
            "lineGridOrNotchAlignmentUsed": False,
            "syntheticDotReconstructionUsed": False,
        },
        "existingCropWrapper": {
            "state": wrapped["state"],
            "imageFirstString": wrapped["imageFirstString"],
            "closeImageFirstStrings": wrapped["closeImageFirstStrings"],
            "hypothesisCount": len(wrapped["hypotheses"]),
            "identityAccepted": wrapped["identityAccepted"],
            "referenceExclusion": wrapped["referenceExclusion"],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--fixtures", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    if arguments.output.exists():
        raise FileExistsError(arguments.output)
    if not sys.dont_write_bytecode:
        raise RuntimeError("Run the gate with Python bytecode writes disabled (-B).")
    project = arguments.project.resolve()
    fixture_path = arguments.fixtures.resolve()
    fixtures = read_json(fixture_path)
    for dependency in fixtures["pinnedDependencies"]:
        require_hash(project / dependency["path"], dependency["sha256"])
    print(json.dumps({"progress": "dependencies_verified"}), flush=True)
    provider_path = project / "work/OPENCV_SCRIBE_R18Q/ArgosOpenCvScribeV1R18Q.py"
    provider = load("argos_scribe_r18q_local_gate", provider_path)
    isolation = load(
        "argos_scribe_r18p_isolation_for_r18q_gate",
        project / "work/OPENCV_SCRIBE_R18P/Run-R18PReferenceIsolatedCorpus.py",
    )
    print(json.dumps({"progress": "reference_banks_start"}), flush=True)
    r11, appearance, topology, structure, supplemental_rows = load_banks(project, provider, fixtures)
    banks = (appearance, topology, structure)
    print(json.dumps({"progress": "reference_banks_complete", "referenceCount": len(appearance)}), flush=True)

    authoritative = authoritative_fixture_gate(project, fixtures)
    hardcode = engine_hardcode_gate(project, provider_path, fixtures, r11)
    print(json.dumps({"progress": "slot22_fixed_and_wrapper_start"}), flush=True)
    isolated = isolated_whole_crop_gate(provider, isolation, r11, banks, supplemental_rows, fixtures)
    print(json.dumps({"progress": "lineage_sweep_start"}), flush=True)
    sweep, rename_indices = lineage_sweep(provider, isolation, r11, banks, supplemental_rows)
    renaming = label_renaming_gate(provider, isolation, r11, banks, supplemental_rows, rename_indices)
    print(json.dumps({"progress": "visible_regression_start"}), flush=True)
    visible, t7 = visible_gate(project, provider, r11, banks, fixtures)
    print(json.dumps({"progress": "displaced_s17_start"}), flush=True)
    displaced = displaced_gate(project, provider, r11, banks, fixtures)
    print(json.dumps({"progress": "blank_controls_start"}), flush=True)
    blanks = blank_gate(provider, r11, banks, fixtures)
    print(json.dumps({"progress": "slot24_start"}), flush=True)
    slot24 = slot24_gate(provider, isolation, r11, banks, supplemental_rows, fixtures)

    pycache = [str(path) for path in (project / "work/OPENCV_SCRIBE_R18Q").rglob("__pycache__")]
    if pycache:
        raise AssertionError(f"Bytecode cache exists in R18Q: {pycache}")
    gate = {
        "schema": "argos_opencv_scribe_r18q_local_gate_v1",
        "state": "PASS_R18Q_GENERIC_STRUCTURE_LOCAL_GATE_FULL_SLOT25_CROP_REPLAY_PENDING",
        "classification": "PENDING_GATE",
        "provider": {
            "path": str(provider_path.relative_to(project)).replace("\\", "/"),
            "sha256": sha256_file(provider_path),
            "revision": provider.REVISION,
            "strongStructureMaximumDistance": provider.STRONG_STRUCTURE_MAXIMUM_DISTANCE,
            "strongStructureMinimumMargin": provider.STRONG_STRUCTURE_MINIMUM_MARGIN,
            "strongStructureMaximumAppearanceDeficit": provider.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
            "strongStructureMaximumAppearanceLeaderScore": provider.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE,
        },
        "testSha256": sha256_file(Path(__file__)),
        "fixturesSha256": sha256_file(fixture_path),
        "authoritativeFixtureBinding": authoritative,
        "engineHardcodeGate": hardcode,
        "canonicalLineageReferenceSweep": sweep,
        "labelRenamingBehavioralInvariant": renaming,
        "isolatedWholeCropTruth": isolated,
        "frozenVisibleRegression": {
            "exactCount": len(visible),
            "expectedCount": 21,
            "semantics": "REFERENCE_PRESENT_FROZEN_GRID_REGRESSION; GENERALIZATION IS PROVED SEPARATELY",
            "rows": visible,
        },
        "t7NearTieRegression": t7,
        "blankControls": {
            "caseCount": len(blanks),
            "evaluatedViewCount": sum(row["evaluatedViewCount"] for row in blanks),
            "allBelowPresenceFloor": True,
            "rows": blanks,
        },
        "displacedS17": displaced,
        "slot24": slot24,
        "invariants": {
            "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
            "noSyntheticDots": True,
            "noNotchDependence": True,
            "readerCropWorkerAndReferencesModified": False,
            "fullWaferImagesRead": False,
            "sourceMutationPerformed": False,
            "externalAccessPerformed": False,
            "pycacheCount": 0,
        },
        "knownCoverageHolds": {
            "missingBodyReferenceLabels": "IOVY",
            "singleLineageOnlyLabels": "WZ",
            "fullSlot25WholeCropLocalReplay": "PENDING_MISSING_EXACT_LOCAL_PAIR",
        },
        "authority": fixtures["authority"],
        "publicationReady": False,
        "fullKlarfReady": False,
        "nextAction": "Acquire or execute the exact pinned Slot25 crop pair in a separately authorized bounded gate, then reassess publication. Do not use truth to select glyphs and do not publish from this local gate.",
    }
    arguments.output.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "state": gate["state"],
        "providerSha256": gate["provider"]["sha256"],
        "referenceCorrect": sweep["successorCorrect"],
        "referenceHarmed": sweep["harmedPreviouslyCorrectCount"],
        "krExact": sweep["reciprocalKr"]["kExact"] + sweep["reciprocalKr"]["rExact"],
        "visibleExact": len(visible),
        "blankHeld": len(blanks),
        "slot24State": slot24["existingCropWrapper"]["state"],
        "gateSha256": sha256_file(arguments.output),
    }, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
