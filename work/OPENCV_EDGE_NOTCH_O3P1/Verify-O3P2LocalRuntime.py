#!/usr/bin/env python3
"""Read-only verifier for an isolated, target-installed OpenCV runtime."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
from typing import Any


SCHEMA = "argos_ocv03_o3p2_local_runtime_verify_manifest_v1"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_manifest(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise RuntimeError("Verification manifest schema changed.")
    return value


def inventory(root: Path) -> dict[str, Any]:
    file_count = 0
    byte_count = 0
    reparse_points: list[str] = []
    for current_root, directory_names, file_names in os.walk(root, followlinks=False):
        current = Path(current_root)
        for name in sorted(directory_names):
            candidate = current / name
            attributes = getattr(candidate.lstat(), "st_file_attributes", 0)
            if candidate.is_symlink() or attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                reparse_points.append(str(candidate.resolve(strict=False)))
        for name in sorted(file_names):
            candidate = current / name
            row = candidate.lstat()
            attributes = getattr(row, "st_file_attributes", 0)
            if candidate.is_symlink() or attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                reparse_points.append(str(candidate.resolve(strict=False)))
                continue
            file_count += 1
            byte_count += row.st_size
    return {
        "fileCount": file_count,
        "byteCount": byte_count,
        "topLevelNames": sorted(child.name for child in root.iterdir()),
        "reparsePoints": sorted(reparse_points),
    }


def require_under(module_path: Path, root: Path, label: str) -> str:
    resolved = module_path.resolve(strict=True)
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise RuntimeError(f"{label} did not load from the isolated target: {resolved}") from exc
    return str(resolved)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--preflight", action="store_true", required=True)
    arguments = parser.parse_args()

    manifest_path = Path(arguments.manifest).resolve(strict=True)
    manifest = load_manifest(manifest_path)
    if not manifest.get("reviewOnly") or manifest.get("productionRoutingEnabled"):
        raise RuntimeError("Verification authority widened.")
    if manifest.get("networkAllowed") or manifest.get("mutationsAllowed"):
        raise RuntimeError("Verification manifest permits mutation or network use.")

    root = Path(str(manifest["targetRoot"])).resolve(strict=True)
    if not root.is_dir():
        raise RuntimeError(f"Verification target is not a directory: {root}")

    interpreter = Path(sys.executable).resolve(strict=True)
    if sha256(interpreter) != str(manifest["pythonSha256"]).upper():
        raise RuntimeError("Python interpreter SHA-256 changed.")

    sys.dont_write_bytecode = True
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    before = inventory(root)
    if before["reparsePoints"]:
        raise RuntimeError("Verification target contains a reparse point.")
    if before["fileCount"] != int(manifest["expectedFileCount"]):
        raise RuntimeError("Verification target file count changed.")
    if before["byteCount"] != int(manifest["expectedByteCount"]):
        raise RuntimeError("Verification target byte count changed.")
    if before["topLevelNames"] != list(manifest["expectedTopLevelNames"]):
        raise RuntimeError("Verification target top-level names changed.")
    if before["fileCount"] > int(manifest["maximumFileCount"]):
        raise RuntimeError("Verification target exceeds the file-count bound.")
    if before["byteCount"] > int(manifest["maximumByteCount"]):
        raise RuntimeError("Verification target exceeds the byte-count bound.")

    sys.path.insert(0, str(root))
    import cv2  # type: ignore[import-not-found]
    import numpy  # type: ignore[import-not-found]

    cv2_path = require_under(Path(cv2.__file__), root, "OpenCV")
    numpy_path = require_under(Path(numpy.__file__), root, "NumPy")
    if sys.version.split()[0] != str(manifest["expectedPythonVersion"]):
        raise RuntimeError("Python version changed.")
    if cv2.__version__ != str(manifest["expectedOpenCvVersion"]):
        raise RuntimeError("OpenCV version changed.")
    if numpy.__version__ != str(manifest["expectedNumpyVersion"]):
        raise RuntimeError("NumPy version changed.")

    after = inventory(root)
    if after != before:
        raise RuntimeError("Read-only import changed the target inventory.")

    result = {
        "schema": "argos_ocv03_o3p2_local_runtime_verify_result_v1",
        "state": "PASS_O3P2_LOCAL_RUNTIME_VERIFICATION",
        "manifestPath": str(manifest_path),
        "manifestSha256": sha256(manifest_path),
        "targetRoot": str(root),
        "pythonPath": str(interpreter),
        "pythonSha256": sha256(interpreter),
        "pythonVersion": sys.version.split()[0],
        "opencvVersion": cv2.__version__,
        "numpyVersion": numpy.__version__,
        "opencvModulePath": cv2_path,
        "numpyModulePath": numpy_path,
        "fileCount": after["fileCount"],
        "byteCount": after["byteCount"],
        "topLevelNames": after["topLevelNames"],
        "reparsePointCount": len(after["reparsePoints"]),
        "beforeAfterInventoryEqual": True,
        "mutationsPerformed": False,
        "networkUsed": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"O3P2 runtime verification failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
