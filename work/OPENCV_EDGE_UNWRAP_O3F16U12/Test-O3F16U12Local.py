#!/usr/bin/env python3
"""Read-only local gate for the R12 annular unwrap draft."""

from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "work" / "O3F8" / "AnnularUnwrapDiagnosticOpenCvR12.py"
U10 = Path(r"C:\O3F16U10OBS1A\u10")
EXAMPLES = Path(
    r"\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General"
    r"\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ProjectPortalRO\responses"
    r"\ArgosUnwrapExamples"
)
EXPECTED_ENGINE_SHA256 = "1696DBE407E4461B351C6B939C591A4E652E558DF15BF4AC5CEFB369950FF7F6"
EXPECTED_SUMMARY_SHA256 = "2D1A46CBB7C69782CF60C621A4F746998F18F392F42748537EC2433DF792C378"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def extract_helpers(source: str) -> dict[str, object]:
    tree = ast.parse(source, filename=str(ENGINE))
    selected = []
    wanted = {"MAX_REFERENCE_STEP_PX", "CONTINUITY_PASSES"}
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id in wanted for target in node.targets
        ):
            selected.append(node)
        if isinstance(node, ast.FunctionDef) and node.name in {"global_minmax", "limit_cyclic_step"}:
            selected.append(node)
    module = ast.Module(body=selected, type_ignores=[])
    namespace: dict[str, object] = {"cv2": cv2, "np": np}
    exec(compile(module, str(ENGINE), "exec"), namespace)
    return namespace


def overlay_path(path: Path) -> np.ndarray:
    image = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if image is None:
        raise RuntimeError(f"OpenCV decode failed: {path}")
    colored = np.all(image == [0, 0, 255], axis=2) | np.all(image == [255, 0, 255], axis=2)
    result = np.full(image.shape[1], np.nan)
    for column in range(image.shape[1]):
        rows = np.flatnonzero(colored[:, column])
        if rows.size:
            result[column] = float(np.median(rows))
    valid = np.flatnonzero(np.isfinite(result))
    if valid.size < 2:
        raise RuntimeError(f"Insufficient rendered path: {path}")
    columns = result.size
    return np.interp(
        np.arange(columns),
        np.concatenate((valid[-1:] - columns, valid, valid[:1] + columns)),
        np.concatenate((result[valid[-1:]], result[valid], result[valid[:1]])),
    )


def main() -> int:
    source = ENGINE.read_text(encoding="utf-8")
    compile(source, str(ENGINE), "exec")
    if sha256(ENGINE) != EXPECTED_ENGINE_SHA256:
        raise RuntimeError("R12 engine hash changed")
    if sha256(U10 / "SUMMARY.json") != EXPECTED_SUMMARY_SHA256:
        raise RuntimeError("U10 summary hash changed")
    for token in (
        '"full_clean"',
        '"full_enhanced"',
        '"full_overlay"',
        "GLOBAL_MINMAX_ON_NATIVE_ANNULAR_SAMPLE",
        "continuityAdjustedColumnsEligibleAsMeasuredEvidence",
    ):
        if token not in source:
            raise RuntimeError(f"R12 source token missing: {token}")
    if "createCLAHE" in source:
        raise RuntimeError("R12 must not feed CLAHE into tracking or review")

    helpers = extract_helpers(source)
    global_minmax = helpers["global_minmax"]
    limit_cyclic_step = helpers["limit_cyclic_step"]
    raw_example = cv2.imread(str(EXAMPLES / "00_unwoundWaferRing_unprocessed.png"), cv2.IMREAD_GRAYSCALE)
    processed_example = cv2.imread(str(EXAMPLES / "01_unwoundWaferRing_processed.png"), cv2.IMREAD_GRAYSCALE)
    if raw_example is None or processed_example is None:
        raise RuntimeError("Argos example decode failed")
    normalized, normalization_evidence = global_minmax(raw_example)
    if not np.array_equal(normalized, processed_example):
        raise RuntimeError("R12 global min/max does not reproduce the Argos example")

    rows = []
    for path in sorted((U10 / "cases").glob("C*/*_annular_overlay.png")):
        original = overlay_path(path)
        limited = limit_cyclic_step(original)
        maximum_jump = float(np.max(np.abs(limited - np.roll(limited, 1))))
        changed = np.abs(limited - original) > 0.5
        if maximum_jump > 1.000001:
            raise RuntimeError(f"Continuity limit failed: {path}")
        if not np.any(changed):
            raise RuntimeError(f"Expected discontinuity control did not exercise: {path}")
        rows.append(
            {
                "asset": str(path.relative_to(U10)).replace("\\", "/"),
                "preMaximumJumpPx": float(np.max(np.abs(original - np.roll(original, 1)))),
                "postMaximumJumpPx": maximum_jump,
                "continuityChangedColumnCount": int(np.count_nonzero(changed)),
                "continuityChangedColumnsEligibleAsMeasuredEvidence": False,
            }
        )
    if len(rows) != 8:
        raise RuntimeError("Expected eight U10 BF/DF overlays")

    result = {
        "schema": "argos_ocv03_o3f16u12_local_gate_v1",
        "state": "PASS_O3F16U12_LOCAL_REAL_STRIP_RECONSTRUCTION_GATE",
        "engineSha256": sha256(ENGINE),
        "u10SummarySha256": sha256(U10 / "SUMMARY.json"),
        "argosGlobalMinmaxExactMatch": True,
        "argosNormalizationEvidence": normalization_evidence,
        "channelCount": len(rows),
        "channels": rows,
        "maximumPostContinuityJumpPx": max(row["postMaximumJumpPx"] for row in rows),
        "fullRuntimeImportTested": False,
        "fullRuntimeImportReason": "EXACT_INSTALLED_DEPENDENCIES_EXIST_ONLY_ON_JBOD",
        "sourceMutationPerformed": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
