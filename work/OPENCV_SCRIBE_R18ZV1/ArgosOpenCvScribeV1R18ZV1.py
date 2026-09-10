#!/usr/bin/env python3
"""R18ZU with one target-excluded generic envelope-boundary revision."""

from __future__ import annotations

import hashlib
import importlib.util
import sys
import threading
from pathlib import Path
from typing import Any, Iterable


EXPECTED_R18ZU_SHA256 = "935BAAE98331FF128D4204B6C8AB2E7EBEF8A38B2773F4ACCE59AE3A78C7FF87"
EXPECTED_DEVELOPMENT_FREEZE_SHA256 = "DF38E45781E9CFEC81524D7C2C3F5EB1A21BED61D6E945A9F51198779C6E72CA"
EXPECTED_R18ZU_REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZU_CANONICAL_Z_GEOMETRY_DIAGNOSTIC_20260908"
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZV1_GENERIC_ENVELOPE_BOUNDARY_DIAGNOSTIC_20260910"
INHERITED_ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE = 0.80
FROZEN_ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE = 0.83


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
R18ZU_PATH = ROOT / "OPENCV_SCRIBE_R18ZU/ArgosOpenCvScribeV1R18ZU.py"
DEVELOPMENT_FREEZE_PATH = ROOT / "OPENCV_SCRIBE_R18ZV1/R18ZV1_GENERIC_ALTERNATIVE_ENVELOPE_DEVELOPMENT_FREEZE.json"
if _sha256_file(R18ZU_PATH) != EXPECTED_R18ZU_SHA256:
    raise ValueError("Frozen R18ZU provider SHA-256 mismatch.")
if _sha256_file(DEVELOPMENT_FREEZE_PATH) != EXPECTED_DEVELOPMENT_FREEZE_SHA256:
    raise ValueError("Frozen R18ZV1 development-freeze SHA-256 mismatch.")

R18ZU = _load("argos_scribe_r18zu_for_r18zv1", R18ZU_PATH)
R18V = R18ZU.R18ZT.R18V
R17D = R18ZU.R17D
_LOCAL_RUN_LOCK = threading.Lock()


def run_job(job_path: Path, result_path: Path) -> int:
    with _LOCAL_RUN_LOCK:
        old_threshold = R18V.ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE
        old_loader = R17D.R17C.R17B._load_r11
        r11 = old_loader()
        old_write = r11.write_json_new
        if old_threshold != INHERITED_ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE:
            raise RuntimeError("Inherited R18V envelope boundary is not frozen at 0.80.")
        if R18ZU.REVISION != EXPECTED_R18ZU_REVISION:
            raise RuntimeError("Inherited R18ZU revision is not the frozen predecessor.")

        def write_result(path: Path, result: dict[str, Any]) -> None:
            if result.get("revision") != EXPECTED_R18ZU_REVISION:
                raise RuntimeError("Predecessor result revision mismatch.")
            result["revision"] = REVISION
            result.setdefault("provenance", {}).update({
                "engineRevision": REVISION,
                "r18zuProviderSha256": EXPECTED_R18ZU_SHA256,
                "r18zv1DevelopmentFreezeSha256": EXPECTED_DEVELOPMENT_FREEZE_SHA256,
                "alternativeLabelMaximumNormalizedDistance": (
                    FROZEN_ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE
                ),
                "executionIsolation": "SEQUENTIAL_CONFIG_SELECTED_PROVIDER_PROCESS",
            })
            old_write(path, result)

        try:
            R18V.ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE = (
                FROZEN_ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE
            )
            r11.write_json_new = write_result
            R17D.R17C.R17B._load_r11 = lambda: r11
            return R18ZU.run_job(job_path, result_path)
        finally:
            R17D.R17C.R17B._load_r11 = old_loader
            r11.write_json_new = old_write
            R18V.ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE = old_threshold


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
