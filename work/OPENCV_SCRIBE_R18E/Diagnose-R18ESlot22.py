#!/usr/bin/env python3
"""Read-only full-rank diagnostic for the two wrong R18D Slot22 glyphs."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import cv2
import numpy as np


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    project = Path(__file__).resolve().parents[2]
    provider = load("r18d_slot22_diagnostic", project / "work/OPENCV_SCRIBE_R18D/ArgosOpenCvScribeV1R18D.py")
    root = Path(r"C:\P2COHORT\results\R18E_R18D_DEVELOPMENT_20260903A\62546-481-POST_20260713041740_Slot22")
    job = json.loads((root / "SCRIBE_JOB.json").read_text(encoding="utf-8-sig"))
    result = json.loads((root / "R18D_RESULT.json").read_text(encoding="utf-8-sig"))
    selected = result["hypotheses"][0]
    r11 = provider.R18C.R17E.R17D.R17C.R17B._load_r11()
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    manifest = Path(job["references"]["manifestPath"])
    prototypes, evidence = r11.load_reference_prototypes(manifest, job["references"]["manifestSha256"], roots)
    supplement = Path(job["references"]["supplementalManifestPath"])
    supplement_sha = job["references"]["supplementalManifestSha256"]
    prototypes, _ = provider.R18D_LOADER.combine_reference_prototypes(r11, prototypes, evidence, supplement, supplement_sha)
    topology = provider.R18C.R17E.R17D.load_topology_prototypes(r11, manifest, job["references"]["manifestSha256"], roots, supplement, supplement_sha)
    gray = cv2.imread(job["inputs"]["bf"]["path"], cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise FileNotFoundError(job["inputs"]["bf"]["path"])
    view = 255 - gray if selected["polarity"] == "BRIGHT" else gray
    if selected["direction"] == "REVERSE_180":
        view = cv2.rotate(view, cv2.ROTATE_180)
    active = prototypes
    appearance_bank = r11.PrototypeBank.from_prototypes(active)
    topology_matrix = np.vstack([item.descriptor.astype(np.float64) for item in topology])
    topology_indices = provider.R18C.R17E.R17D._label_indices(np.asarray([item.label for item in topology]))
    residual = r11.dark_residual_exact(view, 12)
    grid = provider.R18C.R17E.R17D.evaluate_hybrid_grid(
        r11, residual, appearance_bank, topology_matrix, topology_indices,
        int(selected["x"]), int(selected["y"]), int(selected["cellWidth"]), int(selected["cellHeight"]),
    )
    if grid is None:
        raise RuntimeError("Grid diagnostic failed")
    rows = []
    for index in (1, 4):
        position = grid["positions"][index]
        rows.append({
            "position": index + 1,
            "visibleTruth": "3" if index == 1 else "K",
            "imageFirst": position["imageFirst"],
            "glyphArbitration": position["glyphArbitration"],
            "allCandidates": position["allCandidates"],
        })
    print(json.dumps(rows, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
