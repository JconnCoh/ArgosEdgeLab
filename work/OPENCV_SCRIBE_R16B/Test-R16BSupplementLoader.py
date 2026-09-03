#!/usr/bin/env python3
"""Local contract test for the R16B supplemental-reference loader."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError(f"Cannot import {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--manifest-sha256", required=True)
    args = parser.parse_args()
    root = Path(args.repo_root).resolve()
    r11 = load("argos_r16b_test_r11", root / "work/OPENCV_SCRIBE_R11A/ArgosOpenCvScribeV1R11.py")
    loader = load("argos_r16b_test_loader", root / "work/OPENCV_SCRIBE_R16B/ArgosOpenCvScribeSupplementLoaderR16B.py")
    manifest = Path(args.manifest).resolve()
    supplements, evidence = loader.load_supplemental_prototypes(
        r11, manifest, args.manifest_sha256
    )
    if len(supplements) != 6 or evidence["labelCounts"] != {"J": 2, "K": 1, "Q": 2, "X": 1}:
        raise ValueError("Supplemental prototype contract failed.")

    base_labels = "0123456789ABCDEFGHLMNPRSTU"
    exemplar = supplements[0]
    base = [r11.Prototype(label, f"TEST_BASE_{label}", exemplar.descriptor) for label in base_labels]
    combined, combined_evidence = loader.combine_reference_prototypes(
        r11,
        base,
        {"referenceCount": 456, "prototypeLabels": base_labels},
        manifest,
        args.manifest_sha256,
    )
    if len(combined) != len(base) + 6:
        raise ValueError("Combined prototype count failed.")
    if combined_evidence["missingBodyReferenceLabels"] != "IOVWYZ":
        raise ValueError(f"Combined missing-label accounting failed: {combined_evidence}")
    print(json.dumps({
        "state": "PASS_R16B_SUPPLEMENT_LOADER_LOCAL",
        "supplementalReferenceCount": len(supplements),
        "labelCounts": evidence["labelCounts"],
        "combinedMissingLabels": combined_evidence["missingBodyReferenceLabels"],
        "providerActivationAuthorized": combined_evidence["providerActivationAuthorized"],
        "identityAdmissionAuthorized": combined_evidence["identityAdmissionAuthorized"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
