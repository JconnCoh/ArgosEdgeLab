#!/usr/bin/env python3
"""Targeted R18C gate on the four R18A development cases."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


EXPECTED = {
    "62633-726_20260818204139_Slot19": {"state": "SCRIBE_IMAGE_FIRST_CHECKSUM_HOLD", "imageFirstString": "148AU103SUD5", "proposedString": ""},
    "62627-182_20260810050905_Slot23": {"state": "HOLD_SCRIBE_NOT_LOCALIZED", "imageFirstString": "", "proposedString": ""},
    "62625-957_20260729124737_Slot24": {"imageFirstString": "1484P102SUC0", "proposedString": "1484P102SUC0"},
    "62613-842A-test_20260730053955_Slot25": {"state": "HOLD_SCRIBE_NOT_LOCALIZED", "imageFirstString": "", "proposedString": ""},
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_provider(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r18c_test_target", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--r17e-result-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    if args.output_root.exists():
        raise FileExistsError(f"R18C test root already exists: {args.output_root}")
    args.output_root.mkdir(parents=True)
    provider = load_provider(args.provider.resolve())
    rows = []
    for case_id, expected in EXPECTED.items():
        case_root = args.output_root / case_id
        case_root.mkdir()
        job_path = args.r17e_result_root / case_id / "SCRIBE_JOB.json"
        result_path = case_root / "R18C_RESULT.json"
        provider.run_job(job_path, result_path)
        result = json.loads(result_path.read_text(encoding="utf-8-sig"))
        for field, value in expected.items():
            if result.get(field) != value:
                raise AssertionError(f"{case_id} {field}: expected {value!r}, got {result.get(field)!r}")
        if result["provenance"].get("checksumRole") != "VERIFY_IMAGE_FIRST_ONLY":
            raise AssertionError(f"Checksum role changed: {case_id}")
        if result["provenance"].get("checksumMayRewriteGlyphs") is not False:
            raise AssertionError(f"Checksum rewrite authority changed: {case_id}")
        rows.append({
            "physicalIdentity": case_id,
            "state": result["state"],
            "imageFirstString": result["imageFirstString"],
            "proposedString": result["proposedString"],
            "resultSha256": sha256_file(result_path),
        })
    gate = {
        "schema": "argos_opencv_scribe_r18c_development_gate_v1",
        "state": "PASS_R18C_DEVELOPMENT",
        "providerSha256": sha256_file(args.provider),
        "minimumPostGridImageScore": provider.MINIMUM_POST_GRID_IMAGE_SCORE,
        "rows": rows,
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "blankProducedStringCount": sum(bool(row["imageFirstString"]) for row in rows if row["state"] == "HOLD_SCRIBE_NOT_LOCALIZED"),
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "trainingAuthorized": False,
    }
    gate_path = args.output_root / "R18C_DEVELOPMENT_GATE.json"
    gate_path.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
