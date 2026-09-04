#!/usr/bin/env python3
"""Bounded local gate for the R13 review rendering over exact U12 intermediates."""

from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace

import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "work" / "O3F8" / "AnnularUnwrapDiagnosticOpenCvR13.py"
U12 = Path(r"C:\O3F16U12PULL1\u12")
OUTPUT = Path(r"C:\O3F16U13LAB\rendered")
EXPECTED_ENGINE_SHA256 = "35940B211AEB51898B7BA9F279004D404D1C0AF2013B933414D1F58B30EF7748"
EXPECTED_U12_SUMMARY_SHA256 = "7B5760BEBFB4C5096201A8D81535D27807D6EA6331510BC85C194065303A8CBC"
EXPECTED_ROLES = {
    "clean", "enhanced", "overlay", "mask", "hold_mask", "edge_review",
    "normalized_review", "full_clean", "full_enhanced", "full_overlay",
    "full_review", "damage_review",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def runs(mask: np.ndarray) -> list[np.ndarray]:
    indices = np.flatnonzero(mask)
    return [] if not indices.size else list(np.split(indices, np.where(np.diff(indices) > 1)[0] + 1))


def segmented_review(image: np.ndarray, legend: str) -> np.ndarray:
    segment_width, header = 2048, 24
    segments = []
    for start in range(0, image.shape[1], segment_width):
        stop = min(start + segment_width, image.shape[1])
        part = image[:, start:stop]
        canvas_shape = (image.shape[0] + header, segment_width, *image.shape[2:])
        canvas = np.zeros(canvas_shape, dtype=image.dtype)
        canvas[header:, : part.shape[1]] = part
        color = (255, 255, 255) if image.ndim == 3 else 255
        degrees = f"{start * 360.0 / image.shape[1]:.3f}-{stop * 360.0 / image.shape[1]:.3f}deg"
        cv2.putText(canvas, f"{legend} | arc {start}:{stop}px | {degrees}", (5, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.40, color, 1, cv2.LINE_8)
        segments.append(canvas)
    return np.vstack(segments)


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def helpers() -> dict[str, object]:
    source = ENGINE.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(ENGINE))
    names = {"review_clahe", "reference_overlay", "normalized_overlay", "render"}
    constants = {"CLAHE_CLIP_LIMIT", "CLAHE_TILE_GRID", "HOLD_BAR_ROWS"}
    selected = []
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id in constants for t in node.targets):
            selected.append(node)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name in names:
            selected.append(node)
    module = ast.Module(body=selected, type_ignores=[])
    diagnostic = SimpleNamespace(
        need=need,
        runs=runs,
        segmented_review=segmented_review,
        sha256=sha256,
    )
    namespace: dict[str, object] = {
        "Any": object,
        "Path": Path,
        "cv2": cv2,
        "np": np,
        "hashlib": hashlib,
        "diagnostic": diagnostic,
    }
    exec(compile(module, str(ENGINE), "exec"), namespace)
    return namespace


def recover_measurement(case_root: Path, stem: str, channel: str) -> dict[str, object]:
    full_clean_path = case_root / f"{stem}_{channel}_annular_full_clean.png"
    edge_clean_path = case_root / f"{stem}_{channel}_annular_clean.png"
    overlay_path = case_root / f"{stem}_{channel}_annular_overlay.png"
    full_clean = cv2.imread(str(full_clean_path), cv2.IMREAD_GRAYSCALE)
    edge_clean = cv2.imread(str(edge_clean_path), cv2.IMREAD_GRAYSCALE)
    overlay = cv2.imread(str(overlay_path), cv2.IMREAD_COLOR)
    need(full_clean is not None and edge_clean is not None and overlay is not None, f"OpenCV decode failed: {stem} {channel}")
    red = np.all(overlay == (0, 0, 255), axis=2)
    magenta = np.all(overlay == (255, 0, 255), axis=2)
    green = np.all(overlay == (0, 200, 0), axis=2)
    zero = int(np.median(np.argwhere(green)[:, 0]))
    path = np.full(overlay.shape[1], np.nan, dtype=np.float64)
    measured = np.zeros(overlay.shape[1], dtype=bool)
    for column in range(overlay.shape[1]):
        rows_here = np.flatnonzero(red[:, column] | magenta[:, column])
        if rows_here.size:
            path[column] = float(np.median(rows_here) - zero)
        measured[column] = bool(np.any(red[:, column]))
    valid = np.flatnonzero(np.isfinite(path))
    need(valid.size > 2, f"Rendered R12 path cannot be recovered: {stem} {channel}")
    columns = path.size
    path = np.interp(
        np.arange(columns),
        np.concatenate((valid[-1:] - columns, valid, valid[:1] + columns)),
        np.concatenate((path[valid[-1:]], path[valid], path[valid[:1]])),
    ).astype(np.float32)
    offsets = np.arange(-180, 56, dtype=np.float32)
    edge_offsets = np.arange(-32, 17, dtype=np.float32)
    map_x = np.broadcast_to(np.arange(columns, dtype=np.float32)[None, :], (edge_offsets.size, columns)).copy()
    map_y = (180.0 + path[None, :] + edge_offsets[:, None]).astype(np.float32)
    normalized = cv2.remap(full_clean, map_x, map_y, cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    return {
        "strip": full_clean,
        "edgeStrip": edge_clean,
        "normalizedStrip": normalized,
        "offsets": offsets,
        "edgeOffsets": edge_offsets,
        "paths": {"cyclic": path},
        "pathMeasured": measured,
        "sourcePaths": [full_clean_path, edge_clean_path, overlay_path],
    }


def assert_magenta_is_top_bar(image: np.ndarray, header: int, image_rows: int, label: str) -> None:
    magenta = np.all(image == (255, 0, 255), axis=2)
    rows = np.flatnonzero(np.any(magenta, axis=1))
    for row in rows:
        relative = int(row % (header + image_rows))
        need(header <= relative < header + 3, f"Held interpolation rendered away from semantic top bar: {label} row {row}")


def main() -> int:
    source = ENGINE.read_text(encoding="utf-8")
    compile(source, str(ENGINE), "exec")
    need(sha256(ENGINE) == EXPECTED_ENGINE_SHA256, "R13 engine hash changed")
    need(sha256(U12 / "SUMMARY.json") == EXPECTED_U12_SUMMARY_SHA256, "U12 summary hash changed")
    for token in (
        "trackingEnhancementChangedFromR12\": False",
        "reviewEnhancementAffectsReferenceSelection\": False",
        "heldInterpolatedPathRenderedAcrossImage\": False",
        "postResultSelectorRelaxationPerformed\": False",
    ):
        need(token in source, f"Required R13 evidence token missing: {token}")

    namespace = helpers()
    render = namespace["render"]
    rows = []
    for source_overlay in sorted((U12 / "cases").glob("C*/*_annular_overlay.png")):
        case_root = source_overlay.parent
        stem, channel = source_overlay.name.split("_")[:2]
        measurement = recover_measurement(case_root, stem, channel)
        output_root = OUTPUT / case_root.name
        output_root.mkdir(parents=True, exist_ok=True)
        assets = render(output_root, f"{case_root.name}-{channel}", channel, measurement)
        need(set(assets) == EXPECTED_ROLES, f"Unexpected R13 asset roles: {case_root.name} {channel}")
        edge_review = cv2.imread(assets["edge_review"]["path"], cv2.IMREAD_COLOR)
        damage_review = cv2.imread(assets["damage_review"]["path"], cv2.IMREAD_COLOR)
        full_review = cv2.imread(assets["full_review"]["path"], cv2.IMREAD_COLOR)
        assert_magenta_is_top_bar(edge_review, 24, 49, f"{case_root.name}-{channel}-edge")
        assert_magenta_is_top_bar(damage_review, 24, 236, f"{case_root.name}-{channel}-damage")
        need(not np.any(np.all(full_review == (255, 0, 255), axis=2)), "Clean full review contains magenta annotation")
        enhanced = cv2.imread(assets["full_enhanced"]["path"], cv2.IMREAD_GRAYSCALE)
        need(not np.array_equal(enhanced, measurement["strip"]), "CLAHE review did not change pixels")
        rows.append(
            {
                "case": case_root.name,
                "channel": channel.upper(),
                "sourceFullCleanSha256": sha256(measurement["sourcePaths"][0]),
                "renderedCleanSha256": assets["full_clean"]["sha256"],
                "renderedFullEnhancedSha256": assets["full_enhanced"]["sha256"],
                "assetRoleCount": len(assets),
                "heldPathRenderedAcrossImage": False,
                "cleanFullBandReviewContainsTrackingAnnotation": False,
            }
        )
        need(rows[-1]["sourceFullCleanSha256"] == rows[-1]["renderedCleanSha256"], "Raw full-band bytes changed")
    need(len(rows) == 8, "Expected eight BF/DF channels")
    result = {
        "schema": "argos_ocv03_o3f16u13_local_review_render_gate_v1",
        "state": "PASS_O3F16U13_LOCAL_REVIEW_RENDER_GATE",
        "engineSha256": sha256(ENGINE),
        "u12SummarySha256": sha256(U12 / "SUMMARY.json"),
        "channelCount": len(rows),
        "channels": rows,
        "trackingAlgorithmChangedFromR12": False,
        "numericThresholdRelaxationPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "heldInterpolationRenderedAsEdgeEvidence": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
