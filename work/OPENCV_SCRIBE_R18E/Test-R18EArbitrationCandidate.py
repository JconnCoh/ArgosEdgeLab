#!/usr/bin/env python3
"""Regression-test a lower topology-margin candidate without changing R18D."""

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


CANDIDATE_MARGIN = 0.12
R18D_PROVIDER_SHA256 = "39E44AE48A76DA0BDF25490BD3EFE49EC98770B0B10BE6DF0FF57373951B95A1"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output_root.resolve()
    if output.exists():
        raise FileExistsError(output)
    output.mkdir(parents=True)

    provider_path = project / "work/OPENCV_SCRIBE_R18D/ArgosOpenCvScribeV1R18D.py"
    if sha256_file(provider_path) != R18D_PROVIDER_SHA256:
        raise ValueError("Frozen R18D provider changed")
    provider = load("argos_scribe_r18e_arbitration_candidate", provider_path)
    chain = provider.R18C.R17E.R17D
    frozen_margin = float(chain.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN)
    if frozen_margin != 0.15:
        raise ValueError("Frozen R18D topology margin changed")
    chain.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN = CANDIDATE_MARGIN

    finalizer = load(
        "argos_scribe_r18e_candidate_finalizer",
        project / "work/OPENCV_SCRIBE_R18D/Finalize-R18DGate.py",
    )
    finalizer.load_module = lambda _name, _path: provider
    regression_path = output / "CANDIDATE_R18D_REGRESSION.json"
    previous_argv = list(sys.argv)
    sys.argv = [
        "Finalize-R18DGate.py",
        "--project", str(project),
        "--provider", str(provider_path),
        "--supplement", str(project / "work/OPENCV_SCRIBE_R18D/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"),
        "--wz-root", r"C:\P2COHORT\results\R18D_WZ_REFERENCE_GATE_20260903B",
        "--output", str(regression_path),
    ]
    try:
        finalizer.main()
    finally:
        sys.argv = previous_argv

    case_root = Path(r"C:\P2COHORT\results\R18E_R18D_DEVELOPMENT_20260903A\62546-481-POST_20260713041740_Slot22")
    job = json.loads((case_root / "SCRIBE_JOB.json").read_text(encoding="utf-8-sig"))
    result = json.loads((case_root / "R18D_RESULT.json").read_text(encoding="utf-8-sig"))
    selected = result["hypotheses"][0]
    r11 = provider.R18C.R17E.R17D.R17C.R17B._load_r11()
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    manifest = Path(job["references"]["manifestPath"])
    prototypes, evidence = r11.load_reference_prototypes(manifest, job["references"]["manifestSha256"], roots)
    supplement = Path(job["references"]["supplementalManifestPath"])
    supplement_sha = str(job["references"]["supplementalManifestSha256"])
    prototypes, _ = provider.R18D_LOADER.combine_reference_prototypes(r11, prototypes, evidence, supplement, supplement_sha)
    topology = chain.load_topology_prototypes(r11, manifest, job["references"]["manifestSha256"], roots, supplement, supplement_sha)
    gray = cv2.imread(job["inputs"]["bf"]["path"], cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise FileNotFoundError(job["inputs"]["bf"]["path"])
    appearance_bank = r11.PrototypeBank.from_prototypes(prototypes)
    topology_matrix = np.vstack([item.descriptor.astype(np.float64) for item in topology])
    topology_indices = chain._label_indices(np.asarray([item.label for item in topology]))
    residual = r11.dark_residual_exact(gray, 12)
    grid = chain.evaluate_hybrid_grid(
        r11, residual, appearance_bank, topology_matrix, topology_indices,
        int(selected["x"]), int(selected["y"]), int(selected["cellWidth"]), int(selected["cellHeight"]),
    )
    if grid is None:
        raise RuntimeError("Slot22 candidate grid evaluation failed")
    candidate_string = "".join(str(row["imageFirst"]) for row in grid["positions"])
    if candidate_string != "13DCR060SUF5":
        raise AssertionError(f"Candidate margin changed Slot22 unexpectedly: {candidate_string}")
    p2 = grid["positions"][1]
    if p2["glyphArbitration"]["mode"] != "TOPOLOGY_OVERRIDE" or p2["imageFirst"] != "3":
        raise AssertionError("Candidate margin did not correct the clear position-2 glyph to 3")

    regression = json.loads(regression_path.read_text(encoding="utf-8-sig"))
    gate = {
        "schema": "argos_opencv_scribe_r18e_arbitration_candidate_gate_v1",
        "state": "PASS_CANDIDATE_MARGIN_VISIBLE_AND_BLANK_REGRESSION",
        "frozenProviderSha256": R18D_PROVIDER_SHA256,
        "frozenTopologyOverrideMinimumMargin": frozen_margin,
        "candidateTopologyOverrideMinimumMargin": CANDIDATE_MARGIN,
        "visibleRegressionExact": len(regression["visibleRegression"]),
        "blankRegressionHeld": len(regression["blankRegression"]),
        "slot22Before": "11DCR060SUF5",
        "slot22AfterArbitrationCandidate": candidate_string,
        "slot22Position2": p2,
        "slot22Position5StillRequiresReferenceWork": grid["positions"][4],
        "checksumUsedToSelectGlyph": False,
        "blindAcquisitionsRead": 0,
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "automaticReferenceAdmissionAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    gate_path = output / "R18E_ARBITRATION_CANDIDATE_GATE.json"
    gate_path.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"state": gate["state"], "slot22After": candidate_string, "gateSha256": sha256_file(gate_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
