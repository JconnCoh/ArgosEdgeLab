#!/usr/bin/env python3
"""Build the review-only R18Z supplement from the signed R18W3 crop pull."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import numpy as np


SELECTION_RELATIVE = "work/OPENCV_SCRIBE_R18W3/R18W3_SELECTION.json"
INVENTORY_RELATIVE = "work/OPENCV_SCRIBE_R18W3/R18W3_RETURNED_FILE_INVENTORY.json"
TERMINAL_GATE_RELATIVE = "work/OPENCV_SCRIBE_R18W3/R18W3_TERMINAL_RESPONSE_GATE.json"
RESPONSE_CHECKPOINT_RELATIVE = (
    "work/OPENCV_SCRIBE_R18W3/"
    "R18W3_SIGNED_TERMINAL_RESPONSE_CHECKPOINT_20260905.md"
)
BASE_MANIFEST_RELATIVE = (
    "work/SCRIBE_REVIEW_ONLY/scratch/"
    "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
    "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
)
OLD_SUPPLEMENT_RELATIVE = (
    "work/OPENCV_SCRIBE_R18F/reference_bank/"
    "SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
)
OLD_CROSSWALK_RELATIVE = (
    "work/OPENCV_SCRIBE_R18X/R18X_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
)
R18H_PROVIDER_RELATIVE = "work/OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py"
R18J_RUNNER_RELATIVE = "work/OPENCV_SCRIBE_R18J/Run-R18JScribeCorpus.py"
R18F_LOADER_RELATIVE = (
    "work/OPENCV_SCRIBE_R18F/ArgosOpenCvScribeSupplementLoaderR18F.py"
)
R11_PROVIDER_RELATIVE = "work/OPENCV_SCRIBE_R11A/ArgosOpenCvScribeV1R11.py"

EXPECTED_SHA256 = {
    SELECTION_RELATIVE: "48795396398ED73F73C87509803FC1B647389872CDDC5F31B532995906181D7E",
    INVENTORY_RELATIVE: "3ABE5D9E4D328917318C72CD6EC1AD84D56E92C99AB71FF11C1BEF05B330A281",
    TERMINAL_GATE_RELATIVE: "925B47C4C04CEB916D312C34B842DDEE9FE54327E55AF4F851729744800A474F",
    RESPONSE_CHECKPOINT_RELATIVE: "722BD38D92A967CF2E6C045B8B9D5B623746F0FB7441906D287C83E7C3002450",
    BASE_MANIFEST_RELATIVE: "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    OLD_SUPPLEMENT_RELATIVE: "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114",
    OLD_CROSSWALK_RELATIVE: "EAF725D04C899CCEFC70E29DDA990D4058F226D7C602C1607D7ADB2E9CED1099",
    R18H_PROVIDER_RELATIVE: "3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD",
    R18J_RUNNER_RELATIVE: "E8C193024317C683EA0E8DC999F3D632BF113B65C1E6F528949AE5B33F83A069",
    R18F_LOADER_RELATIVE: "D458E7D97B846A6DE44175CDDC70928E48632C3EFBE3014DC5555026C64BE2D5",
    R11_PROVIDER_RELATIVE: "7C6632B2D1C56DA4CA565DAB5BF7D46A366BCAE6663793CE5AB1ABB4739F72C9",
}

BODY_LABELS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
MINIMUM_IMAGE_SCORE = 0.60
AMBIGUITY_SCORE_DELTA = 0.03
EXPECTED_OLD_COUNTS = {"J": 2, "K": 2, "Q": 2, "W": 1, "X": 1, "Z": 1}
EXPECTED_COMBINED_COUNTS = {
    "D": 1, "H": 1, "J": 2, "K": 2, "L": 1, "M": 1, "N": 3,
    "Q": 2, "R": 1, "T": 1, "W": 1, "X": 2, "Z": 1,
}
EXTRACTED_ROOT = Path(r"C:\R18W3\data\JBOD_PROCESSOR_REVIEW")
SCRIBE_PATTERN = re.compile(r"^[A-Z0-9]{12}$")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True, ensure_ascii=True)
        stream.write("\n")


def copy_new(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    with source.open("rb") as incoming, os.fdopen(descriptor, "wb") as outgoing:
        shutil.copyfileobj(incoming, outgoing, 4 * 1024 * 1024)


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def m12_remainder(text: str) -> int:
    remainder = 0
    for character in text:
        value = ord(character) - 32
        if value < 0 or value > 58:
            return -1
        remainder = (8 * remainder + value) % 59
    return remainder


def require_canonical_scribe(value: Any, context: str) -> str:
    text = str(value).strip().upper()
    if not SCRIBE_PATTERN.fullmatch(text) or m12_remainder(text) != 0:
        raise ValueError(f"{context} is not a canonical SEMI M12 scribe: {value!r}")
    return text


def verify_project_pins(project: Path) -> list[dict[str, Any]]:
    pins: list[dict[str, Any]] = []
    for relative, expected in EXPECTED_SHA256.items():
        path = project / relative
        if not path.is_file():
            raise FileNotFoundError(path)
        actual = sha256_file(path)
        if actual != expected:
            raise ValueError(f"Frozen dependency changed: {relative}")
        pins.append({"relativePath": relative, "bytes": path.stat().st_size, "sha256": actual})
    return pins


def inventory_case_rows(inventory: dict[str, Any]) -> dict[str, dict[str, dict[str, Any]]]:
    if (
        inventory.get("schema") != "argos_opencv_scribe_r18w3_returned_file_inventory_v1"
        or inventory.get("state") != "PASS_R18W3_EXACT_24_FILE_HASH_INVENTORY"
        or int(inventory.get("returnedFileCount", -1)) != 24
        or inventory.get("pixelsDecoded") is not False
        or inventory.get("referenceAdmissionPerformed") is not False
    ):
        raise ValueError("R18W3 returned inventory contract changed.")
    cases: dict[str, dict[str, dict[str, Any]]] = {}
    seen_paths: set[str] = set()
    for row in inventory.get("rows", []):
        relative = str(row.get("relativePath", "")).replace("\\", "/")
        if relative in seen_paths:
            raise ValueError(f"Duplicate inventory path: {relative}")
        seen_paths.add(relative)
        match = re.fullmatch(
            r"identity/proposals/([^/]+)/(SCRIBE_PROPOSAL\.json|scribe/(BF|DF)_SCRIBE_ORIENTED_DETECTOR_INPUT\.png)",
            relative,
        )
        if match is None:
            raise ValueError(f"Unexpected R18W3 inventory path: {relative}")
        identity = match.group(1)
        leaf = "PROPOSAL" if match.group(2) == "SCRIBE_PROPOSAL.json" else str(match.group(3))
        bucket = cases.setdefault(identity.casefold(), {})
        if leaf in bucket:
            raise ValueError(f"Duplicate {leaf} inventory row: {identity}")
        expected_kind = {
            "PROPOSAL": "PROPOSAL_JSON",
            "BF": "BF_ORIENTED_INPUT_PNG",
            "DF": "DF_ORIENTED_INPUT_PNG",
        }[leaf]
        if row.get("kind") != expected_kind:
            raise ValueError(f"Inventory kind mismatch: {relative}")
        extracted = Path(str(row.get("extractedPath", "")))
        root = EXTRACTED_ROOT.resolve()
        resolved = extracted.resolve()
        if root not in resolved.parents:
            raise ValueError(f"Extracted source escaped frozen root: {extracted}")
        if not extracted.is_file():
            raise FileNotFoundError(extracted)
        actual_bytes = extracted.stat().st_size
        actual_sha = sha256_file(extracted)
        if actual_bytes != int(row.get("bytes", -1)) or actual_sha != str(row.get("sha256", "")).upper():
            raise ValueError(f"Extracted source changed: {extracted}")
        bucket[leaf] = {
            "relativePath": relative,
            "extractedPath": str(extracted),
            "bytes": actual_bytes,
            "sha256": actual_sha,
            "kind": expected_kind,
        }
    if len(seen_paths) != 24 or len(cases) != 8 or any(set(row) != {"PROPOSAL", "BF", "DF"} for row in cases.values()):
        raise ValueError("R18W3 inventory does not contain eight exact proposal/BF/DF triples.")
    return cases


def expected_oriented_suffix(identity: str, channel: str) -> str:
    return (
        f"identity\\proposals\\{identity}\\scribe\\"
        f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
    ).casefold()


def validate_sources(project: Path) -> dict[str, Any]:
    pins = verify_project_pins(project)
    terminal = read_json(project / TERMINAL_GATE_RELATIVE)
    if (
        terminal.get("state") != "PASS_R18W3_SIGNED_EIGHT_LINEAGE_DATA_PULL_COLLECTED"
        or terminal.get("requestId") != "REQ_R18W3"
        or terminal.get("pixelsDecoded") is not False
        or terminal.get("identityAccepted") is not False
        or terminal.get("referenceAdmissionPerformed") is not False
    ):
        raise ValueError("R18W3 terminal response gate contract changed.")
    inventory = read_json(project / INVENTORY_RELATIVE)
    rows_by_case = inventory_case_rows(inventory)
    selection = read_json(project / SELECTION_RELATIVE)
    if (
        selection.get("schema") != "argos_opencv_scribe_r18w3_selection_v1"
        or selection.get("state") != "PASS_R18W3_CORRECTED_EIGHT_SELECTION_VALIDATED"
        or int(selection.get("selectedCount", -1)) != 8
        or len(selection.get("selected", [])) != 8
    ):
        raise ValueError("R18W3 selection contract changed.")
    partition = selection.get("partitionBoundary", {})
    if any(bool(partition.get(field)) for field in (
        "reservedValidationIncluded", "sameTruthPostAcquisitionIncluded",
        "localOnlyPackageExcludedIncluded",
    )):
        raise ValueError("R18W3 development/validation partition changed.")
    selected_truths: set[str] = set()
    selected_lineages: set[str] = set()
    cases: list[dict[str, Any]] = []
    missing_segmentation = 0
    for expected_ordinal, selected in enumerate(selection["selected"], start=1):
        if int(selected.get("ordinal", -1)) != expected_ordinal:
            raise ValueError("R18W3 selection ordinal changed.")
        identity = str(selected.get("requestIdentity", ""))
        truth = require_canonical_scribe(selected.get("scribe"), identity)
        lineage = str(selected.get("independentLineageKey", ""))
        if not identity or truth in selected_truths or not lineage or lineage.casefold() in selected_lineages:
            raise ValueError("R18W3 selection does not contain eight independent exact lineages.")
        selected_truths.add(truth)
        selected_lineages.add(lineage.casefold())
        triple = rows_by_case.get(identity.casefold())
        if triple is None:
            raise ValueError(f"Selected identity is absent from returned inventory: {identity}")
        proposal = read_json(Path(triple["PROPOSAL"]["extractedPath"]))
        if (
            proposal.get("schema") != "argos_jbod_scribe_proposal_v1"
            or str(proposal.get("physicalIdentity", "")) != identity
            or proposal.get("readerState") != "SCRIBE_REFERENCE_COVERAGE_HOLD"
            or proposal.get("referenceCoverageComplete") is not False
            or proposal.get("operatorConfirmationRequired") is not True
            or proposal.get("imageBytesEmbedded") is not False
            or proposal.get("frontsideDefectInspectionPerformed") is not False
            or proposal.get("reviewOnly") is not True
            or any(proposal.get(field) is not False for field in (
                "trainingEligible", "xmlEligible", "productionEligible"
            ))
        ):
            raise ValueError(f"Returned proposal authority contract changed: {identity}")
        for field, channel in (("bfOrientedReviewPath", "BF"), ("dfOrientedReviewPath", "DF")):
            normalized = str(proposal.get(field, "")).replace("/", "\\").casefold()
            if not normalized.endswith(expected_oriented_suffix(identity, channel)):
                raise ValueError(f"Proposal does not bind the oriented {channel} input: {identity}")
        reader_suffix = (
            f"identity\\proposals\\{identity}\\scribe\\IMAGE_FIRST_READER_RESULT.json"
        ).casefold()
        if not str(proposal.get("readerResultPath", "")).replace("/", "\\").casefold().endswith(reader_suffix):
            raise ValueError(f"Proposal reader-result path contract changed: {identity}")
        segmentation = proposal.get("segmentationState")
        if segmentation is None:
            missing_segmentation += 1
        elif segmentation != "SCRIBE_GRID_BOUNDARY_COMPLETE":
            raise ValueError(f"Proposal segmentation state changed: {identity}")
        labels = [str(value).upper() for value in selected.get("requestedGlyphLabels", [])]
        if not labels or len(labels) != len(set(labels)) or any(label not in BODY_LABELS for label in labels):
            raise ValueError(f"Invalid requested glyph set: {identity}")
        positions = []
        for label in labels:
            found = [index + 1 for index, character in enumerate(truth) if character == label]
            if len(found) != 1:
                raise ValueError(f"Requested label is not unique in exact truth: {identity} {label}")
            positions.append({"label": label, "position1Based": found[0]})
        cases.append({
            "ordinal": expected_ordinal,
            "physicalIdentity": identity,
            "sourceAcquisitionKey": str(selected.get("sourceAcquisitionKey", "")),
            "queryLot": str(selected.get("queryLot", "")),
            "issuedWaferContainer": str(selected.get("issuedWaferContainer", "")),
            "exactScribeLineage": truth,
            "independentLineageKey": lineage,
            "requestedGlyphs": positions,
            "proposal": triple["PROPOSAL"],
            "bf": triple["BF"],
            "df": triple["DF"],
            "proposalState": str(proposal.get("state", "")),
            "proposalImageFirstString": str(proposal.get("imageFirstString", "")),
            "proposalString": str(proposal.get("proposal", "")),
            "proposalMatchesExactTruth": str(proposal.get("proposal", "")) == truth,
            "proposalSegmentationState": "MISSING" if segmentation is None else str(segmentation),
            "proposalAcceptedAsIdentity": False,
        })
    if set(rows_by_case) != {str(row["physicalIdentity"]).casefold() for row in cases}:
        raise ValueError("Returned inventory contains an unselected identity.")
    if missing_segmentation != 1 or sum(len(row["requestedGlyphs"]) for row in cases) != 10:
        raise ValueError("R18W3 proposal/declared-glyph cardinality changed.")
    return {
        "schema": "argos_opencv_scribe_r18z_source_binding_gate_v1",
        "createdUtc": utc_now(),
        "state": "PASS_R18Z_EXACT_R18W3_SOURCES_BOUND_BEFORE_IMAGE_DECODE",
        "classification": "DIAGNOSTIC_ONLY",
        "builderSha256": sha256_file(Path(__file__)),
        "inputPins": pins,
        "requestId": "REQ_R18W3",
        "responseId": str(terminal.get("responseId", "")),
        "caseCount": len(cases),
        "declaredGlyphCount": sum(len(row["requestedGlyphs"]) for row in cases),
        "missingLegacyProposalSegmentationStateCount": missing_segmentation,
        "cases": cases,
        "pixelsDecoded": False,
        "referenceAdmissionPerformed": False,
        "identityAccepted": False,
        "truthUsedForGridOrViewSelection": False,
        "checksumUsedForGridOrViewSelection": False,
        "sourceMutationPerformed": False,
        "trainingAuthorized": False,
        "xmlAuthorized": False,
        "productionAuthorized": False,
    }


def load_source_gate(path: Path, expected_sha256: str) -> dict[str, Any]:
    if sha256_file(path) != expected_sha256.upper():
        raise ValueError("R18Z source-binding gate SHA-256 mismatch.")
    gate = read_json(path)
    if (
        gate.get("state") != "PASS_R18Z_EXACT_R18W3_SOURCES_BOUND_BEFORE_IMAGE_DECODE"
        or gate.get("builderSha256") != sha256_file(Path(__file__))
        or int(gate.get("caseCount", -1)) != 8
        or int(gate.get("declaredGlyphCount", -1)) != 10
        or gate.get("pixelsDecoded") is not False
        or gate.get("identityAccepted") is not False
    ):
        raise ValueError("R18Z source-binding gate contract mismatch.")
    return gate


def load_frozen_banks(project: Path) -> tuple[Any, Any, list[Any], list[Any], list[Any]]:
    r18h = load_module("argos_r18z_frozen_r18h", project / R18H_PROVIDER_RELATIVE)
    r11 = r18h.R17D.R17C.R17B._load_r11()
    base = project / BASE_MANIFEST_RELATIVE
    supplement = project / OLD_SUPPLEMENT_RELATIVE
    roots = {
        "glyphs": base.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": base.parent / "glyphs_v5_confirmed_20260806",
    }
    appearance, base_evidence = r11.load_reference_prototypes(
        base, EXPECTED_SHA256[BASE_MANIFEST_RELATIVE], roots
    )
    appearance, _ = r18h.R18F.R18F_LOADER.combine_reference_prototypes(
        r11, appearance, base_evidence, supplement,
        EXPECTED_SHA256[OLD_SUPPLEMENT_RELATIVE],
    )
    topology = r18h.R17D.load_topology_prototypes(
        r11, base, EXPECTED_SHA256[BASE_MANIFEST_RELATIVE], roots,
        supplement, EXPECTED_SHA256[OLD_SUPPLEMENT_RELATIVE],
    )
    run_structure = r18h.load_run_structure_prototypes(
        r11, base, EXPECTED_SHA256[BASE_MANIFEST_RELATIVE], roots,
        supplement, EXPECTED_SHA256[OLD_SUPPLEMENT_RELATIVE],
    )
    keys = [(row.label, row.physical_identity) for row in appearance]
    if len(keys) != 465 or keys != [(row.label, row.physical_identity) for row in topology]:
        raise ValueError("Frozen appearance/topology bank alignment changed.")
    if keys != [(row.label, row.physical_identity) for row in run_structure]:
        raise ValueError("Frozen appearance/run-structure bank alignment changed.")
    return r18h, r11, appearance, topology, run_structure


def compact_structure(value: dict[str, Any]) -> dict[str, Any]:
    allowed = (
        "passed", "componentCount", "qualifiedCellCount", "horizontalPairRatio",
        "verticalPairRatio", "characterPairRatio", "concentrationRatio",
    )
    return {key: value[key] for key in allowed if key in value}


def run_case(
    project: Path,
    source_gate_path: Path,
    source_gate_sha256: str,
    ordinal: int,
    output_root: Path,
) -> dict[str, Any]:
    gate = load_source_gate(source_gate_path, source_gate_sha256)
    if output_root.exists():
        raise FileExistsError(f"Fresh per-case output root required: {output_root}")
    if ordinal < 1 or ordinal > len(gate["cases"]):
        raise ValueError("Case ordinal is outside the frozen eight-case selection.")
    case = gate["cases"][ordinal - 1]
    if int(case.get("ordinal", -1)) != ordinal:
        raise ValueError("Source-gate case ordinal mismatch.")
    for key in ("proposal", "bf", "df"):
        row = case[key]
        path = Path(str(row["extractedPath"]))
        if path.stat().st_size != int(row["bytes"]) or sha256_file(path) != str(row["sha256"]):
            raise ValueError(f"Case source changed after source binding: {path}")
    output_root.mkdir(parents=True)
    r18h, r11, appearance, topology, run_structure = load_frozen_banks(project)
    decoded: dict[str, np.ndarray] = {}
    sources: list[dict[str, Any]] = []
    for channel, key in (("BF", "bf"), ("DF", "df")):
        source = Path(str(case[key]["extractedPath"]))
        gray = r11.decode_gray_exact(source)
        decoded[channel] = gray
        sources.append({
            "channel": channel,
            "path": str(source),
            "bytes": source.stat().st_size,
            "sha256": sha256_file(source),
            "width": int(gray.shape[1]),
            "height": int(gray.shape[0]),
        })
    if decoded["BF"].shape != decoded["DF"].shape:
        raise ValueError("R18W3 paired oriented-input dimensions differ.")
    hypotheses: list[dict[str, Any]] = []
    views: dict[tuple[str, str], np.ndarray] = {}
    for channel in ("BF", "DF"):
        for polarity, view in (("DARK", decoded[channel]), ("BRIGHT", 255 - decoded[channel])):
            views[(channel, polarity)] = view
            structure = r18h.R17D.R17C.measure_structure(view)
            hypothesis: dict[str, Any] = {
                "channel": channel,
                "polarity": polarity,
                "direction": "FORWARD_ORIENTED_INPUT_CONTRACT",
                "structure": compact_structure(structure),
            }
            if bool(structure.get("passed")):
                try:
                    result = r18h.evaluate_detector_input_structural(
                        r11, view, appearance, topology, run_structure, "", None
                    )
                    hypothesis.update({
                        "imageFirstString": str(result.get("imageFirstString", "")),
                        "selectionScore": float(result["selectionScore"]),
                        "meanTopScore": float(result["meanTopScore"]),
                        "boundaryComplete": bool(result["boundaryComplete"]),
                        "grid": {
                            key: int(result[key])
                            for key in ("x", "y", "cellWidth", "cellHeight")
                        },
                        "checksumUsedForSelection": False,
                    })
                except ValueError as error:
                    hypothesis.update({"state": "HOLD_OCR_EVALUATION_ERROR", "detail": str(error)})
            else:
                hypothesis["state"] = "HOLD_STRUCTURE_NOT_PRESENT"
            hypotheses.append(hypothesis)
    eligible = [
        row for row in hypotheses
        if "selectionScore" in row
        and bool(row.get("boundaryComplete"))
        and float(row["selectionScore"]) >= MINIMUM_IMAGE_SCORE
        and len(str(row.get("imageFirstString", ""))) == 12
    ]
    eligible.sort(key=lambda row: (
        -float(row["selectionScore"]), str(row["imageFirstString"]),
        str(row["channel"]), str(row["polarity"]),
    ))
    if not eligible:
        raise ValueError("No forward image-only hypothesis passed structure, boundary, and score gates.")
    best = eligible[0]
    close = [
        row for row in eligible
        if float(row["selectionScore"]) >= float(best["selectionScore"]) - AMBIGUITY_SCORE_DELTA
    ]
    close_strings = sorted({str(row["imageFirstString"]) for row in close})
    close_grids = {
        tuple(int(row["grid"][key]) for key in ("x", "y", "cellWidth", "cellHeight"))
        for row in close
    }
    close_text_consensus = len(close_strings) == 1
    close_grid_consensus = len(close_grids) == 1
    if not close_text_consensus and not close_grid_consensus:
        raise ValueError(
            "Forward image-only hypotheses are ambiguous in both text and source grid: "
            f"strings={close_strings}, grids={sorted(close_grids)}"
        )
    grid = dict(best["grid"])
    view = views[(str(best["channel"]), str(best["polarity"]))]
    references: list[dict[str, Any]] = []
    glyph_root = output_root / "glyphs"
    glyph_root.mkdir()
    for requested in case["requestedGlyphs"]:
        position = int(requested["position1Based"])
        label = str(requested["label"])
        x = int(grid["x"]) + (position - 1) * int(grid["cellWidth"])
        y = int(grid["y"])
        width = int(grid["cellWidth"])
        height = int(grid["cellHeight"])
        crop = view[y:y + height, x:x + width]
        if crop.shape != (height, width):
            raise ValueError(f"Selected glyph crop escaped source bounds: P{position:02d}")
        filename = f"C{ordinal:02d}_P{position:02d}_{label}.png"
        destination = glyph_root / filename
        if not cv2.imwrite(str(destination), crop):
            raise IOError(destination)
        references.append({
            "label": label,
            "position1Based": position,
            "relativePath": f"glyphs/{filename}",
            "bytes": destination.stat().st_size,
            "sha256": sha256_file(destination),
            "width": int(crop.shape[1]),
            "height": int(crop.shape[0]),
            "sourceRect": {"x": x, "y": y, "width": width, "height": height},
        })
    source_key = str(best["channel"]).lower()
    selected_source = case[source_key]
    coordinate_frame = (
        f"R18W3:{gate['responseId']}:{case['physicalIdentity']}:"
        f"{best['channel']}:FORWARD:{best['polarity']}:{selected_source['sha256']}"
    )
    result = {
        "schema": "argos_opencv_scribe_r18z_declared_glyph_extraction_case_v1",
        "createdUtc": utc_now(),
        "state": "PASS_R18Z_EXACT_DECLARED_GLYPHS_EXTRACTED",
        "classification": "DIAGNOSTIC_ONLY",
        "builderSha256": sha256_file(Path(__file__)),
        "sourceBindingGate": {
            "path": str(source_gate_path), "sha256": source_gate_sha256.upper(),
        },
        "ordinal": ordinal,
        "physicalIdentity": case["physicalIdentity"],
        "sourceAcquisitionKey": case["sourceAcquisitionKey"],
        "queryLot": case["queryLot"],
        "issuedWaferContainer": case["issuedWaferContainer"],
        "exactScribeLineage": case["exactScribeLineage"],
        "independentLineageKey": case["independentLineageKey"],
        "proposal": case["proposal"],
        "sources": sources,
        "hypothesisCount": len(hypotheses),
        "hypotheses": hypotheses,
        "minimumImageScore": MINIMUM_IMAGE_SCORE,
        "ambiguityScoreDelta": AMBIGUITY_SCORE_DELTA,
        "closeImageFirstStrings": close_strings,
        "closeExactGridCount": len(close_grids),
        "closeTextConsensus": close_text_consensus,
        "closeExactGridConsensus": close_grid_consensus,
        "gridAcceptanceMode": (
            "UNIQUE_CLOSE_IMAGE_FIRST_STRING"
            if close_text_consensus
            else "EXACT_CLOSE_HYPOTHESIS_GRID_CONSENSUS"
        ),
        "ocrStringAgreementRequiredForGridAcceptance": False,
        "selectedHypothesis": best,
        "coordinateFrameId": coordinate_frame,
        "newReferences": references,
        "declaredGlyphCount": len(references),
        "incidentalGlyphCountAdmitted": 0,
        "pixelsDecodedAndProcessedByOpenCv": True,
        "truthUsedForGridOrViewSelection": False,
        "checksumUsedForGridOrViewSelection": False,
        "notchUsedForGridOrViewSelection": False,
        "fixedGridReused": False,
        "sourceMutationPerformed": False,
        "identityAccepted": False,
        "trainingAuthorized": False,
        "xmlAuthorized": False,
        "productionAuthorized": False,
        "opencvVersion": cv2.__version__,
        "numpyVersion": np.__version__,
    }
    write_json_new(output_root / "CASE_GATE.json", result)
    return result


def contained_reference(manifest_path: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ValueError(f"Unsafe supplemental reference path: {relative}")
    root = manifest_path.parent.resolve()
    path = (root / Path(relative.replace("/", os.sep))).resolve()
    if root not in path.parents:
        raise ValueError(f"Supplemental reference escaped its root: {relative}")
    return path


def aggregate(
    project: Path,
    source_gate_path: Path,
    source_gate_sha256: str,
    case_manifest_path: Path,
    output_root: Path,
) -> dict[str, Any]:
    source_gate = load_source_gate(source_gate_path, source_gate_sha256)
    if output_root.exists():
        raise FileExistsError(f"Fresh aggregate output root required: {output_root}")
    case_manifest = read_json(case_manifest_path)
    if (
        case_manifest.get("schema") != "argos_opencv_scribe_r18z_case_outputs_v1"
        or int(case_manifest.get("caseCount", -1)) != 8
        or len(case_manifest.get("cases", [])) != 8
    ):
        raise ValueError("R18Z case-output manifest contract mismatch.")
    output_root.mkdir(parents=True)
    references_root = output_root / "supplemental_refs"
    references_root.mkdir()
    old_manifest_path = project / OLD_SUPPLEMENT_RELATIVE
    old_manifest = read_json(old_manifest_path)
    old_counts = {str(k): int(v) for k, v in old_manifest.get("labelCounts", {}).items()}
    if (
        old_manifest.get("schema") != "argos_opencv_scribe_supplemental_glyph_references_v1"
        or old_counts != EXPECTED_OLD_COUNTS
        or len(old_manifest.get("references", [])) != 9
    ):
        raise ValueError("Frozen R18F supplement contract changed.")
    combined_rows: list[dict[str, Any]] = []
    copied_names: set[str] = set()
    for row in old_manifest["references"]:
        source = contained_reference(old_manifest_path, str(row.get("relativePath", "")))
        if sha256_file(source) != str(row.get("sha256", "")).upper():
            raise ValueError(f"Frozen predecessor glyph changed: {source}")
        name = source.name
        if name.casefold() in copied_names:
            raise ValueError(f"Duplicate predecessor glyph filename: {name}")
        copied_names.add(name.casefold())
        destination = references_root / name
        copy_new(source, destination)
        if sha256_file(destination) != str(row["sha256"]).upper():
            raise ValueError(f"Copied predecessor glyph changed: {destination}")
        copied = dict(row)
        copied["relativePath"] = f"supplemental_refs/{name}"
        combined_rows.append(copied)
    case_evidence: list[dict[str, Any]] = []
    expected_ordinals = list(range(1, 9))
    actual_ordinals = [int(row.get("ordinal", -1)) for row in case_manifest["cases"]]
    if actual_ordinals != expected_ordinals:
        raise ValueError("R18Z case-output manifest ordinals are not exact and ordered.")
    for manifest_row, source_case in zip(case_manifest["cases"], source_gate["cases"]):
        gate_path = Path(str(manifest_row.get("gatePath", "")))
        expected_gate_sha = str(manifest_row.get("gateSha256", "")).upper()
        if not gate_path.is_file() or sha256_file(gate_path) != expected_gate_sha:
            raise ValueError(f"R18Z per-case gate changed: {gate_path}")
        case_gate = read_json(gate_path)
        ordinal = int(source_case["ordinal"])
        if (
            case_gate.get("state") != "PASS_R18Z_EXACT_DECLARED_GLYPHS_EXTRACTED"
            or int(case_gate.get("ordinal", -1)) != ordinal
            or case_gate.get("physicalIdentity") != source_case["physicalIdentity"]
            or case_gate.get("exactScribeLineage") != source_case["exactScribeLineage"]
            or int(case_gate.get("declaredGlyphCount", -1)) != len(source_case["requestedGlyphs"])
            or int(case_gate.get("incidentalGlyphCountAdmitted", -1)) != 0
            or case_gate.get("truthUsedForGridOrViewSelection") is not False
            or case_gate.get("checksumUsedForGridOrViewSelection") is not False
            or case_gate.get("identityAccepted") is not False
        ):
            raise ValueError(f"R18Z per-case extraction contract changed: {gate_path}")
        requested = {
            (str(row["label"]), int(row["position1Based"]))
            for row in source_case["requestedGlyphs"]
        }
        observed = {
            (str(row["label"]), int(row["position1Based"]))
            for row in case_gate["newReferences"]
        }
        if observed != requested or len(observed) != len(case_gate["newReferences"]):
            raise ValueError(f"R18Z extracted an undeclared or duplicate glyph: {gate_path}")
        for extracted in case_gate["newReferences"]:
            source = contained_reference(gate_path, str(extracted["relativePath"]))
            if source.stat().st_size != int(extracted["bytes"]) or sha256_file(source) != str(extracted["sha256"]):
                raise ValueError(f"R18Z extracted glyph changed: {source}")
            label = str(extracted["label"])
            position = int(extracted["position1Based"])
            name = f"R18Z_C{ordinal:02d}_P{position:02d}_{label}.png"
            if name.casefold() in copied_names:
                raise ValueError(f"R18Z aggregate glyph filename collision: {name}")
            copied_names.add(name.casefold())
            destination = references_root / name
            copy_new(source, destination)
            glyph_sha = sha256_file(destination)
            if glyph_sha != str(extracted["sha256"]):
                raise ValueError(f"R18Z aggregate copy changed glyph bytes: {destination}")
            selected_hypothesis = case_gate["selectedHypothesis"]
            source_channel = str(selected_hypothesis["channel"])
            selected_source = next(row for row in case_gate["sources"] if row["channel"] == source_channel)
            combined_rows.append({
                "label": label,
                "caseId": f"R18Z_C{ordinal:02d}",
                "physicalIdentity": source_case["physicalIdentity"],
                "truth": source_case["exactScribeLineage"],
                "exactScribeLineage": source_case["exactScribeLineage"],
                "queryLot": source_case["queryLot"],
                "issuedWaferContainer": source_case["issuedWaferContainer"],
                "independentLineageKey": source_case["independentLineageKey"],
                "position": position,
                "relativePath": f"supplemental_refs/{name}",
                "bytes": destination.stat().st_size,
                "sha256": glyph_sha,
                "sourcePath": selected_source["path"],
                "sourceSha256": selected_source["sha256"],
                "sourceChannel": source_channel,
                "sourcePolarity": str(selected_hypothesis["polarity"]),
                "sourceDirection": "FORWARD_ORIENTED_INPUT_CONTRACT",
                "sourceGrid": dict(selected_hypothesis["grid"]),
                "sourceRect": dict(extracted["sourceRect"]),
                "coordinateFrameId": case_gate["coordinateFrameId"],
                "proposalSha256": source_case["proposal"]["sha256"],
                "operatorConfirmed": False,
                "exactMesTruthBound": True,
                "declaredByR18W3Selection": True,
                "incidentalGlyph": False,
                "identityAccepted": False,
            })
        case_evidence.append({
            "ordinal": ordinal,
            "physicalIdentity": source_case["physicalIdentity"],
            "exactScribeLineage": source_case["exactScribeLineage"],
            "caseGatePath": str(gate_path),
            "caseGateSha256": expected_gate_sha,
            "declaredGlyphCount": len(case_gate["newReferences"]),
        })
    counts: dict[str, int] = {}
    for row in combined_rows:
        label = str(row["label"])
        counts[label] = counts.get(label, 0) + 1
    counts = dict(sorted(counts.items()))
    if counts != EXPECTED_COMBINED_COUNTS or len(combined_rows) != 19:
        raise ValueError(f"Unexpected R18Z supplemental counts: {counts}")
    manifest = {
        "schema": "argos_opencv_scribe_supplemental_glyph_references_v1",
        "revision": "OCV02_R18Z_EXACT_DECLARED_GLYPHS_DIAGNOSTIC_20260905A",
        "state": "PASS_R18Z_EXACT_DECLARED_GLYPH_REFERENCE_REVISION_BUILT",
        "disposition": "DIAGNOSTIC_ONLY",
        "references": combined_rows,
        "labelCounts": counts,
        "referenceCount": len(combined_rows),
        "predecessorSupplementalManifestSha256": EXPECTED_SHA256[OLD_SUPPLEMENT_RELATIVE],
        "r18w3SourceBindingGateSha256": source_gate_sha256.upper(),
        "newDeclaredReferenceCount": 10,
        "incidentalReferenceCount": 0,
        "remainingMissingLabelsAfterSupplement": "IOVY",
        "identityAdmissionAuthorized": False,
        "activationAuthorized": False,
        "trainingAuthorized": False,
        "productionAuthorized": False,
    }
    manifest_path = output_root / "SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    write_json_new(manifest_path, manifest)
    old_crosswalk = read_json(project / OLD_CROSSWALK_RELATIVE)
    if (
        old_crosswalk.get("state") != "PASS_R18X_EXACT_SCRIBE_LINEAGE_REKEY_CARDINALITY_PRESERVED"
        or int(old_crosswalk.get("summary", {}).get("verifiedReferenceRows", -1)) != 465
        or int(old_crosswalk.get("summary", {}).get("combinedExactScribeLineages", -1)) != 41
    ):
        raise ValueError("Frozen R18X crosswalk contract changed.")
    mappings: list[dict[str, str]] = []
    for row in old_crosswalk.get("baseLineages", []):
        mappings.append({
            "sourceKind": "FROZEN_R18X_BASE",
            "physicalIdentity": str(row["legacyPhysicalIdentity"]),
            "exactScribeLineage": str(row["exactScribeLineage"]),
        })
    for row in old_crosswalk.get("supplementalLineages", []):
        mappings.append({
            "sourceKind": "FROZEN_R18X_SUPPLEMENTAL",
            "physicalIdentity": str(row["physicalIdentity"]),
            "exactScribeLineage": str(row["exactScribeLineage"]),
        })
    for row in source_gate["cases"]:
        mappings.append({
            "sourceKind": "R18Z_R18W3_DECLARED_GLYPHS",
            "physicalIdentity": str(row["physicalIdentity"]),
            "exactScribeLineage": str(row["exactScribeLineage"]),
        })
    raw_keys = [row["physicalIdentity"].casefold() for row in mappings]
    truths = [require_canonical_scribe(row["exactScribeLineage"], "mapping") for row in mappings]
    if len(mappings) != 49 or len(set(raw_keys)) != 49 or len(set(truths)) != 49:
        raise ValueError("R18Z exact-scribe lineage mapping is not 49 unique rows.")
    lineage_by_identity = {row["physicalIdentity"].casefold(): row["exactScribeLineage"] for row in mappings}
    base_manifest_path = project / BASE_MANIFEST_RELATIVE
    base_manifest = read_json(base_manifest_path)
    coverage_sets: dict[str, set[str]] = {label: set() for label in BODY_LABELS}
    for row in base_manifest.get("references", []):
        identity = str(row.get("physicalIdentity", ""))
        lineage = lineage_by_identity.get(identity.casefold())
        if lineage is None:
            raise ValueError(f"R18Z base reference lineage is unmapped: {identity}")
        coverage_sets[str(row["label"]).upper()].add(lineage)
    for row in combined_rows:
        coverage_sets[str(row["label"]).upper()].add(require_canonical_scribe(row["truth"], "supplement"))
    coverage = []
    for label in BODY_LABELS:
        count = len(coverage_sets[label])
        coverage.append({
            "character": label,
            "exactScribeLineageCount": count,
            "state": "UNOBSERVED" if count == 0 else "COVERED" if count >= 4 else "SPARSE",
            "minimumEnforceableLineages": 4,
        })
    covered = "".join(row["character"] for row in coverage if row["state"] == "COVERED")
    sparse = "".join(row["character"] for row in coverage if row["state"] == "SPARSE")
    unobserved = "".join(row["character"] for row in coverage if row["state"] == "UNOBSERVED")
    if sparse != "JKMQWXZ" or unobserved != "IOVY":
        raise ValueError(f"R18Z projected sparse/unobserved coverage changed: {sparse} / {unobserved}")
    crosswalk = {
        "schema": "argos_opencv_scribe_r18z_exact_scribe_lineage_crosswalk_v1",
        "revision": "OCV02_R18Z_EXACT_SCRIBE_LINEAGE_20260905A",
        "state": "PASS_R18Z_475_REFERENCES_49_EXACT_SCRIBE_LINEAGES",
        "classification": "DIAGNOSTIC_ONLY",
        "predecessorCrosswalkSha256": EXPECTED_SHA256[OLD_CROSSWALK_RELATIVE],
        "supplementalManifestSha256": sha256_file(manifest_path),
        "referenceCount": 475,
        "exactScribeLineageCount": 49,
        "mappingRows": sorted(mappings, key=lambda row: row["physicalIdentity"].casefold()),
        "coverage": coverage,
        "coveredCharacters": covered,
        "sparseCharacters": sparse,
        "unobservedCharacters": unobserved,
        "identityAccepted": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    crosswalk_path = output_root / "R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
    write_json_new(crosswalk_path, crosswalk)
    build_gate = {
        "schema": "argos_opencv_scribe_r18z_reference_build_gate_v1",
        "createdUtc": utc_now(),
        "state": "PASS_R18Z_EXACT_DECLARED_GLYPH_REFERENCE_REVISION_BUILT",
        "classification": "DIAGNOSTIC_ONLY",
        "builderSha256": sha256_file(Path(__file__)),
        "sourceBindingGateSha256": source_gate_sha256.upper(),
        "caseOutputManifestSha256": sha256_file(case_manifest_path),
        "caseEvidence": case_evidence,
        "supplementalManifestSha256": sha256_file(manifest_path),
        "exactScribeLineageCrosswalkSha256": sha256_file(crosswalk_path),
        "predecessorReferenceCount": 465,
        "newDeclaredReferenceCount": 10,
        "combinedReferenceCount": 475,
        "predecessorExactScribeLineageCount": 41,
        "newExactScribeLineageCount": 8,
        "combinedExactScribeLineageCount": 49,
        "labelCounts": counts,
        "coveredCharacters": covered,
        "sparseCharacters": sparse,
        "unobservedCharacters": unobserved,
        "incidentalReferenceCount": 0,
        "sourceMutationPerformed": False,
        "identityAccepted": False,
        "reviewOnly": True,
        "trainingAuthorized": False,
        "xmlAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    write_json_new(output_root / "R18Z_REFERENCE_BUILD_GATE.json", build_gate)
    return build_gate


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    source_parser = subparsers.add_parser("source-gate")
    source_parser.add_argument("--project", required=True, type=Path)
    source_parser.add_argument("--output", required=True, type=Path)
    case_parser = subparsers.add_parser("case")
    case_parser.add_argument("--project", required=True, type=Path)
    case_parser.add_argument("--source-gate", required=True, type=Path)
    case_parser.add_argument("--source-gate-sha256", required=True)
    case_parser.add_argument("--ordinal", required=True, type=int)
    case_parser.add_argument("--output-root", required=True, type=Path)
    aggregate_parser = subparsers.add_parser("aggregate")
    aggregate_parser.add_argument("--project", required=True, type=Path)
    aggregate_parser.add_argument("--source-gate", required=True, type=Path)
    aggregate_parser.add_argument("--source-gate-sha256", required=True)
    aggregate_parser.add_argument("--case-manifest", required=True, type=Path)
    aggregate_parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    if args.command == "source-gate":
        gate = validate_sources(project)
        write_json_new(args.output.resolve(), gate)
        print(json.dumps({"state": gate["state"], "caseCount": gate["caseCount"]}, sort_keys=True))
        return 0
    if args.command == "case":
        gate = run_case(
            project, args.source_gate.resolve(), args.source_gate_sha256,
            args.ordinal, args.output_root.resolve(),
        )
        print(json.dumps({
            "state": gate["state"], "ordinal": gate["ordinal"],
            "declaredGlyphCount": gate["declaredGlyphCount"],
            "selectedChannel": gate["selectedHypothesis"]["channel"],
            "selectedPolarity": gate["selectedHypothesis"]["polarity"],
        }, sort_keys=True))
        return 0
    gate = aggregate(
        project, args.source_gate.resolve(), args.source_gate_sha256,
        args.case_manifest.resolve(), args.output_root.resolve(),
    )
    print(json.dumps({
        "state": gate["state"], "combinedReferenceCount": gate["combinedReferenceCount"],
        "combinedExactScribeLineageCount": gate["combinedExactScribeLineageCount"],
        "supplementalManifestSha256": gate["supplementalManifestSha256"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
