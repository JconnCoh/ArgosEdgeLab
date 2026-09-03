#!/usr/bin/env python3
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
    parser.add_argument("--config-sha256", required=True)
    parser.add_argument("--supplement-manifest", required=True)
    parser.add_argument("--supplement-sha256", required=True)
    args = parser.parse_args()
    root = Path(args.repo_root).resolve()
    r11 = load("argos_r16c_test_r11", root / "work/OPENCV_SCRIBE_R11A/ArgosOpenCvScribeV1R11.py")
    module = load("argos_r16c_test", root / "work/OPENCV_SCRIBE_R16C/ArgosOpenCvScribeAlphabetConfigR16C.py")
    evidence = module.configure(r11, root / "work/OPENCV_SCRIBE_R16C/R16C_CHARACTER_ALPHABET.json", args.config_sha256)
    if r11.BODY_LABELS != "0123456789ABCDEFGHJKLMNPQRSTUX":
        raise ValueError("Configured provider alphabet mismatch.")
    if any(label in r11.allowed_labels(0) for label in "IOVWYZ"):
        raise ValueError("Excluded labels remain rankable.")
    loader = load("argos_r16c_test_loader", root / "work/OPENCV_SCRIBE_R16B/ArgosOpenCvScribeSupplementLoaderR16B.py")
    supplements, _ = loader.load_supplemental_prototypes(
        r11, Path(args.supplement_manifest).resolve(), args.supplement_sha256
    )
    base_labels = "0123456789ABCDEFGHLMNPRSTU"
    base = [r11.Prototype(label, f"TEST_BASE_{label}", supplements[0].descriptor) for label in base_labels]
    _, combined = loader.combine_reference_prototypes(
        r11, base, {"prototypeLabels": base_labels},
        Path(args.supplement_manifest).resolve(), args.supplement_sha256
    )
    if combined["missingBodyReferenceLabels"] or not combined["referenceCoverageComplete"]:
        raise ValueError("Configured-alphabet reference coverage did not close.")
    print(json.dumps({
        "state": "PASS_R16C_CONFIGURED_ALPHABET_LOCAL",
        "configuredCoverageComplete": True,
        "missingConfiguredLabels": "",
        **evidence
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
