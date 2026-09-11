#!/usr/bin/env python3
"""Batch-only facade for the frozen R18ZV1 provider.

The frozen batch runner temporarily replaces four reference-bank loaders.  The
R18ZV1 provider already uses the exact inherited R18ZV and R18H module objects,
but did not expose them on its outer module.  This facade adds only those two
aliases; detector, ranking, envelope, reference, and result semantics remain in
the hash-pinned R18ZV1 provider.
"""

from __future__ import annotations

import hashlib
import importlib.util
import sys
from pathlib import Path
from typing import Any


EXPECTED_R18ZV1_SHA256 = "81B0AAAE1CBC044321CD0CDA5F1147202F7D8CB384D7E721A36B93AE0C24E2D7"


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
R18ZV1_PATH = ROOT / "OPENCV_SCRIBE_R18ZV1/ArgosOpenCvScribeV1R18ZV1.py"
if _sha256_file(R18ZV1_PATH) != EXPECTED_R18ZV1_SHA256:
    raise ValueError("Frozen R18ZV1 provider SHA-256 mismatch.")

R18ZV1 = _load("argos_scribe_r18zv1_for_batch_adapter", R18ZV1_PATH)
REVISION = R18ZV1.REVISION
R18ZU = R18ZV1.R18ZU
R18V = R18ZV1.R18V
R17D = R18ZV1.R17D
R18ZV = R18ZU.R18ZV
R18H = R18ZU.R18H
run_job = R18ZV1.run_job
main = R18ZV1.main


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
