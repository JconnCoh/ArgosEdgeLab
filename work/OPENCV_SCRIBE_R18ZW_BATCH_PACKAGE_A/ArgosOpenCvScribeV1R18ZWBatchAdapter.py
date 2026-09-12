#!/usr/bin/env python3
"""Batch facade for the frozen R18ZW provider and paired glyph bank."""

from __future__ import annotations

import hashlib
import importlib.util
import sys
from pathlib import Path
from typing import Any

import cv2


EXPECTED_R18ZW_SHA256 = "ECC62B0B50EDE6D7D9F07868B3494D39960A8D6ECDD8CAEA8E942FAF3E069D87"
EXPECTED_PAIR_SHA256 = "FE6BA2DAFA1F535AF489862DD9B6A542142F6F08D17839B3B8E0D98CD3BAA9A9"


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


ROOT = Path(__file__).resolve().parents[1]
R18ZW_PATH = ROOT / "OPENCV_SCRIBE_R18ZW/ArgosOpenCvScribeV1R18ZW.py"
PAIR_PATH = ROOT / "OPENCV_SCRIBE_R18ZW/R18ZW_PAIRED_GLYPH_REFERENCE_MANIFEST.json"
if _sha256_file(R18ZW_PATH) != EXPECTED_R18ZW_SHA256:
    raise ValueError("Frozen R18ZW provider SHA-256 mismatch.")
if _sha256_file(PAIR_PATH) != EXPECTED_PAIR_SHA256:
    raise ValueError("Frozen R18ZW paired manifest SHA-256 mismatch.")

cv2.setNumThreads(1)
cv2.ocl.setUseOpenCL(False)
if int(cv2.getNumThreads()) != 1:
    raise RuntimeError("OpenCV thread cap was not applied.")
if cv2.ocl.useOpenCL():
    raise RuntimeError("OpenCV GPU/OpenCL execution was not disabled.")

R18ZW = _load("argos_scribe_r18zw_for_batch_adapter", R18ZW_PATH)
if R18ZW.PAIR_SHA256 != EXPECTED_PAIR_SHA256:
    raise ValueError("R18ZW paired-manifest binding changed.")


def _bind_paired_manifest(job: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(job, dict) or not isinstance(job.get("references"), dict):
        raise ValueError("R18ZW job references are required.")
    bound = dict(job)
    references = dict(job["references"])
    path_present = "pairedManifestPath" in references
    hash_present = "pairedManifestSha256" in references
    if path_present != hash_present:
        raise ValueError("Partial R18ZW paired-manifest binding is forbidden.")
    if path_present and (
        str(references["pairedManifestPath"]) != str(PAIR_PATH)
        or str(references["pairedManifestSha256"]).upper() != EXPECTED_PAIR_SHA256
    ):
        raise ValueError("Conflicting R18ZW paired-manifest binding is forbidden.")
    references["pairedManifestPath"] = str(PAIR_PATH)
    references["pairedManifestSha256"] = EXPECTED_PAIR_SHA256
    bound["references"] = references
    return bound


_ORIGINAL_LOAD_DOT_BANK = R18ZW.load_dot_bank


def _load_dot_bank(r11: Any, job: dict[str, Any]) -> Any:
    cv2.setNumThreads(1)
    if int(cv2.getNumThreads()) != 1:
        raise RuntimeError("OpenCV thread cap changed before paired-bank load.")
    return _ORIGINAL_LOAD_DOT_BANK(r11, _bind_paired_manifest(job))


R18ZW.load_dot_bank = _load_dot_bank
REVISION = R18ZW.REVISION
R18ZU = R18ZW.R18ZU
R18V = R18ZW.R18ZV1.R18V
R17D = R18ZW.R17D
R18ZV = R18ZW.R18ZV
R18H = R18ZW.R18H
run_job = R18ZW.run_job
main = R18ZW.main


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
