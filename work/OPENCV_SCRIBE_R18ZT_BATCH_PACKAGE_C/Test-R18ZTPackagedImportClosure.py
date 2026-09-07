#!/usr/bin/env python3
"""No-image import-closure smoke gate for the staged R18ZT payload."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
from typing import Any


SHA256_PATTERN = re.compile(r"^[A-F0-9]{64}$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def load_module(name: str, path: Path) -> Any:
    specification = importlib.util.spec_from_file_location(name, path)
    require(specification is not None and specification.loader is not None, f"Cannot load {path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--payload-files-root", required=True, type=Path)
    parser.add_argument("--runner-sha256", required=True)
    parser.add_argument("--provider-sha256", required=True)
    parser.add_argument("--r11-sha256", required=True)
    arguments = parser.parse_args()
    sys.dont_write_bytecode = True

    payload_root = arguments.payload_files_root.resolve(strict=True)
    runner_path = payload_root / "OPENCV_SCRIBE_R18ZT_BATCH/Run-R18ZTExistingOrientedCrops.py"
    provider_path = payload_root / "OPENCV_SCRIBE_R18ZT/ArgosOpenCvScribeV1R18ZT.py"
    r11_path = payload_root / "OPENCV_SCRIBE_R11A/ArgosOpenCvScribeV1R11.py"
    pins = {
        "runner": (runner_path, arguments.runner_sha256.upper()),
        "provider": (provider_path, arguments.provider_sha256.upper()),
        "r11Analyzer": (r11_path, arguments.r11_sha256.upper()),
    }
    for name, (path, expected_sha) in pins.items():
        require(SHA256_PATTERN.fullmatch(expected_sha) is not None, f"Invalid {name} SHA-256")
        require(path.is_file(), f"Missing packaged {name}: {path}")
        require(sha256_file(path) == expected_sha, f"Packaged {name} hash mismatch")

    runner = load_module("r18zt_packaged_runner_smoke", runner_path)
    provider = load_module("r18zt_packaged_provider_smoke", provider_path)
    r11 = load_module("r18zt_packaged_r11_smoke", r11_path)
    require(
        getattr(runner, "REVISION", "")
        == "R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906C",
        "Packaged runner revision mismatch",
    )
    require(
        getattr(provider, "REVISION", "")
        == "ARGOS_OPENCV_SCRIBE_V1R18ZT_GENERIC_HOLD_RESCUE_DIAGNOSTIC_20260906",
        "Packaged provider revision mismatch",
    )
    require(
        getattr(r11, "ENGINE_REVISION", "") == "ARGOS_OPENCV_SCRIBE_V1R11_20260902",
        "Packaged R11 analyzer revision mismatch",
    )
    require(callable(getattr(runner, "main", None)), "Packaged runner main is unavailable")
    require(callable(getattr(provider, "run_job", None)), "Packaged provider run_job is unavailable")
    require(callable(getattr(r11, "analyze_images", None)), "Packaged R11 analyze_images is unavailable")

    print(
        json.dumps(
            {
                "schema": "argos_opencv_scribe_r18zt_packaged_import_closure_gate_v1",
                "state": "PASS_R18ZT_PACKAGED_IMPORT_CLOSURE_NO_IMAGE",
                "payloadFilesRoot": str(payload_root),
                "runnerSha256": pins["runner"][1],
                "providerSha256": pins["provider"][1],
                "r11AnalyzerSha256": pins["r11Analyzer"][1],
                "runnerRevision": getattr(runner, "REVISION"),
                "providerRevision": getattr(provider, "REVISION"),
                "r11AnalyzerRevision": getattr(r11, "ENGINE_REVISION"),
                "runnerMainCallable": True,
                "providerRunJobCallable": True,
                "r11AnalyzeImagesCallable": True,
                "runJobCalled": False,
                "analyzeImagesCalled": False,
                "imageBytesRead": False,
                "sourceMutationPerformed": False,
                "productionRoutingEnabled": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
