#!/usr/bin/env python3
"""Build bounded visual OCR evidence from a frozen R17E local gate."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENT_MANIFEST_SHA256 = "9F78AD34B8707DBB925AE5D569785FD5F67782B92E9FC35A664CD8887C63BBEC"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def load_provider(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r17e_review", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_banks(provider: Any, project: Path) -> tuple[Any, list[Any], list[Any]]:
    r11 = provider.R17D.R17C.R17B._load_r11()
    manifest = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    roots = {
        "glyphs": manifest.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": manifest.parent / "glyphs_v5_confirmed_20260806",
    }
    prototypes, evidence = r11.load_reference_prototypes(manifest, BASE_MANIFEST_SHA256, roots)
    supplement = project / "work/OPENCV_SCRIBE_R16A_LOCAL_RESULT_R3/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    loader = provider.R17D.R17C.R17B._load_supplement_loader()
    prototypes, _ = loader.combine_reference_prototypes(
        r11, prototypes, evidence, supplement, SUPPLEMENT_MANIFEST_SHA256,
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, manifest, BASE_MANIFEST_SHA256, roots,
        supplement, SUPPLEMENT_MANIFEST_SHA256,
    )
    return r11, prototypes, topology


def put_label(image: np.ndarray, text: str, origin: tuple[int, int], color: tuple[int, int, int]) -> None:
    cv2.putText(image, text, origin, cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2, cv2.LINE_AA)


def build_visible_case(
    provider: Any,
    r11: Any,
    prototypes: list[Any],
    topology: list[Any],
    source_root: Path,
    output_root: Path,
    row: dict[str, Any],
) -> dict[str, Any]:
    case_id = str(row["caseId"])
    channel, polarity = str(row["channelPolarity"]).split("_", 1)
    source = source_root / case_id / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
    expected_hash = str(row["inputs"][f"{channel.lower()}Sha256"])
    if sha256_file(source) != expected_hash:
        raise ValueError(f"Source image changed: {case_id} {channel}")
    gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise ValueError(f"OpenCV could not decode: {source}")
    view = 255 - gray if polarity == "BRIGHT" else gray
    grid = row["grid"]
    frozen_grid = (
        int(grid["x"]), int(grid["y"]),
        int(grid["cellWidth"]), int(grid["cellHeight"]),
    )
    evaluated = provider.R17D.evaluate_detector_input_hybrid(
        r11, view, prototypes, topology, "", frozen_grid,
    )
    evaluated = provider.enforce_grid_verifier_only(evaluated)
    if evaluated["imageFirstString"] != str(row["imageFirstString"]):
        raise AssertionError(f"Frozen image-first result changed: {case_id}")

    case_root = output_root / case_id
    case_root.mkdir()
    x, y, cell_width, cell_height = frozen_grid
    overlay = cv2.cvtColor(view, cv2.COLOR_GRAY2BGR)
    cv2.rectangle(overlay, (x, y), (x + 12 * cell_width, y + cell_height), (255, 0, 255), 3)
    for index, position in enumerate(evaluated["positions"]):
        cell_x = x + index * cell_width
        cv2.line(overlay, (cell_x, y), (cell_x, y + cell_height), (0, 255, 0), 1)
        color = (255, 0, 255) if position["glyphArbitration"]["overrideApplied"] else (0, 255, 0)
        put_label(overlay, str(position["imageFirst"]), (cell_x + 6, max(24, y - 8)), color)
    cv2.line(overlay, (x + 12 * cell_width, y), (x + 12 * cell_width, y + cell_height), (0, 255, 0), 1)
    margin = 35
    overlay_crop = overlay[
        max(0, y - margin):min(overlay.shape[0], y + cell_height + margin),
        max(0, x - margin):min(overlay.shape[1], x + 12 * cell_width + margin),
    ]
    if not cv2.imwrite(str(case_root / "GRID_OVERLAY.png"), overlay_crop):
        raise IOError("Could not write grid overlay.")

    tile_width, tile_height, header = 210, 300, 68
    sheet = np.full((3 * tile_height, 4 * tile_width, 3), 245, dtype=np.uint8)
    for index, position in enumerate(evaluated["positions"]):
        cell = view[y:y + cell_height, x + index * cell_width:x + (index + 1) * cell_width]
        cell_bgr = cv2.cvtColor(cell, cv2.COLOR_GRAY2BGR)
        scaled = cv2.resize(cell_bgr, (tile_width, tile_height - header), interpolation=cv2.INTER_NEAREST)
        row_index, column_index = divmod(index, 4)
        y0, x0 = row_index * tile_height, column_index * tile_width
        sheet[y0 + header:y0 + tile_height, x0:x0 + tile_width] = scaled
        top = position["candidates"][0]
        color = (180, 0, 180) if position["glyphArbitration"]["overrideApplied"] else (0, 110, 0)
        put_label(sheet, f"{index + 1:02d}: {position['imageFirst']}", (x0 + 8, y0 + 24), color)
        put_label(
            sheet,
            f"A {top['appearanceScore']:.3f}  T {top['topologyScore']:.3f}",
            (x0 + 8, y0 + 52), (50, 50, 50),
        )
    if not cv2.imwrite(str(case_root / "CHARACTER_SHEET.png"), sheet):
        raise IOError("Could not write character sheet.")

    diagnostic = {
        "schema": "argos_opencv_scribe_r17e_case_diagnostic_v1",
        "caseId": case_id,
        "source": str(source),
        "sourceSha256": expected_hash,
        "channelPolarity": row["channelPolarity"],
        "grid": grid,
        "imageFirstString": evaluated["imageFirstString"],
        "proposedString": evaluated["proposedString"],
        "checksumValid": evaluated["checksumValid"],
        "checksumRole": evaluated["checksumRole"],
        "positions": evaluated["positions"],
        "reviewOnly": True,
        "operatorConfirmationRequired": True,
    }
    write_json_new(case_root / "OCR_DIAGNOSTIC.json", diagnostic)
    return {
        "caseId": case_id,
        "decision": "CHECKSUM_VERIFIED_IMAGE_FIRST_DIAGNOSTIC",
        "imageFirstString": evaluated["imageFirstString"],
        "gridOverlay": f"{case_id}/GRID_OVERLAY.png",
        "characterSheet": f"{case_id}/CHARACTER_SHEET.png",
    }


def build_not_localized_case(
    provider: Any,
    source_root: Path,
    output_root: Path,
    row: dict[str, Any],
) -> dict[str, Any]:
    case_id = str(row["caseId"])
    images = []
    for channel in ("BF", "DF"):
        path = source_root / case_id / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        expected = str(row["inputs"][f"{channel.lower()}Sha256"])
        if sha256_file(path) != expected:
            raise ValueError(f"Source image changed: {case_id} {channel}")
        gray = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise ValueError(f"OpenCV could not decode: {path}")
        images.append(gray)
    evidence = provider.paired_presence_evidence(images[0], images[1])
    if evidence["decision"] != "HOLD_SCRIBE_NOT_LOCALIZED":
        raise AssertionError(f"Not-localized case reached OCR: {case_id}")
    case_root = output_root / case_id
    case_root.mkdir()
    panels = []
    for channel, gray in zip(("BF", "DF"), images):
        panel = cv2.resize(gray, (1000, 400), interpolation=cv2.INTER_AREA)
        panel = cv2.cvtColor(panel, cv2.COLOR_GRAY2BGR)
        put_label(panel, f"{channel} - OCR BLOCKED: SCRIBE NOT LOCALIZED", (20, 35), (0, 0, 255))
        panels.append(panel)
    if not cv2.imwrite(str(case_root / "NOT_LOCALIZED_PAIR.png"), np.hstack(panels)):
        raise IOError("Could not write not-localized pair.")
    write_json_new(case_root / "PRESENCE_DIAGNOSTIC.json", {
        "schema": "argos_opencv_scribe_r17e_not_localized_diagnostic_v1",
        "caseId": case_id,
        "decision": evidence["decision"],
        "imageFirstString": "",
        "proposedString": "",
        "presenceEvidence": evidence,
        "reviewOnly": True,
    })
    return {
        "caseId": case_id,
        "decision": evidence["decision"],
        "imageFirstString": "",
        "pairReview": f"{case_id}/NOT_LOCALIZED_PAIR.png",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--gate", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    arguments = parser.parse_args()
    gate = read_json(arguments.gate)
    if gate.get("state") != "PASS_DIAGNOSTIC_ONLY":
        raise ValueError("R17E local gate is not diagnostic PASS.")
    if arguments.output_root.exists():
        raise FileExistsError(f"Output root already exists: {arguments.output_root}")
    provider_path = arguments.provider.resolve()
    if sha256_file(provider_path) != str(gate["provider"]["sha256"]):
        raise ValueError("Provider changed after the R17E gate.")
    provider = load_provider(provider_path)
    r11, prototypes, topology = load_banks(provider, arguments.project.resolve())
    arguments.output_root.mkdir(parents=True)
    cohort = gate["predecessorFailureRecoveryCohort"]
    source_root = Path(str(cohort["sourceRoot"]))
    rows = []
    for row in cohort["rows"]:
        if str(row.get("imageFirstString", "")):
            rows.append(build_visible_case(
                provider, r11, prototypes, topology,
                source_root, arguments.output_root, row,
            ))
        else:
            rows.append(build_not_localized_case(
                provider, source_root, arguments.output_root, row,
            ))
    summary = {
        "schema": "argos_opencv_scribe_r17e_failure_review_v1",
        "state": "PASS_DIAGNOSTIC_ONLY",
        "gateSha256": sha256_file(arguments.gate),
        "providerSha256": sha256_file(provider_path),
        "caseCount": len(rows),
        "visibleImageFirstCount": sum(bool(row["imageFirstString"]) for row in rows),
        "notLocalizedCount": sum(row["decision"] == "HOLD_SCRIBE_NOT_LOCALIZED" for row in rows),
        "rows": rows,
        "authority": gate["authority"],
    }
    write_json_new(arguments.output_root / "SUMMARY.json", summary)
    print(json.dumps({
        "state": summary["state"],
        "outputRoot": str(arguments.output_root),
        "caseCount": summary["caseCount"],
        "visibleImageFirstCount": summary["visibleImageFirstCount"],
        "notLocalizedCount": summary["notLocalizedCount"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
