#!/usr/bin/env python3
"""R32 recognizes a measured notch without requiring one internal pixel lane.

R31's contour, coverage, gap, and morphology gates remain unchanged.  Seven
existing native raw-depth nodes anywhere in a raw-signature-zero candidate are
the minimum sustained evidence. Forks and off-path responses remain authority
telemetry; this diagnostic adapter grants no notch ownership.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from types import ModuleType
from typing import Any
HERE = Path(__file__).resolve().parent
R31_NAME = "AnnularUnwrapCandidateFirstOpenCvR31.py"
R31_SHA256 = "984FF818B5370D3A081EB89AC257243E5A3EEF09EA0271E4E9E116F695ABB938"
class R32Error(RuntimeError):
    pass
def need(value: Any, message: str) -> None:
    if not value:
        raise R32Error(message)
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()
def _load_r31() -> ModuleType:
    path = (HERE / R31_NAME).resolve()
    need(path.is_file() and sha256_file(path) == R31_SHA256, "Frozen R31 changed")
    spec = importlib.util.spec_from_file_location("argos_annular_r31_for_r32", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R31")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module
r31 = _load_r31()
R27_SHA256 = r31.R27_SHA256
R30_SHA256 = r31.R30_SHA256
COMPACT_RUNNER_SHA256 = r31.COMPACT_RUNNER_SHA256
_PATH_OLD = '''        and representative_path_has_sustained_strict_core_run
        and not sustained_physical_fork
'''
_DEPTH_NEW = '''        and len(strict_core_set) >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
'''
_SCHEMA_OLD = '''                    and bool(diagnostics["representativePathHasSustainedStrictCoreRun"])
                    and not bool(diagnostics["sustainedPhysicalStrictCoreFork"])
'''
_SCHEMA_NEW = '''                    and int(diagnostics["strictCoreNodeCountOnCompleteGraph"])
                    + int(diagnostics["strictCoreNodeCountOffCompleteGraph"])
                    >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
'''
_OLD_ROLE = "SECONDARY_NATIVE_SUPPORTED_BOUNDED_GAP_SUSTAINED_CORE_SINGLE_PATH_WITNESS_WHEN_RAW_SIGNATURE_IS_ZERO"
_NEW_ROLE = "SECONDARY_NATIVE_SUPPORTED_BOUNDED_GAP_PATH_WITH_SUSTAINED_CANDIDATE_RAW_DEPTH_EVIDENCE_WHEN_RAW_SIGNATURE_IS_ZERO"
_OLD_RULE = "BOUNDED_GAP_CORE_VISITING_SINGLE_PATH_PHYSICAL_CORRIDOR_FALLBACK_WITH_RAW_SIGNATURE_RETAINED"
_NEW_RULE = "BOUNDED_GAP_PATH_WITH_SUSTAINED_CANDIDATE_RAW_DEPTH_EVIDENCE_PHYSICAL_CORRIDOR_FALLBACK_WITH_RAW_SIGNATURE_RETAINED"
_configured = False
def _once(value: str, old: str, new: str, label: str) -> str:
    need(value.count(old) == 1, f"Frozen R31 {label} changed")
    return value.replace(old, new, 1)
def _configure() -> None:
    global _configured
    if _configured:
        return
    for name in ("_RECOMPUTE_NEW", "_GENERATOR_NEW"):
        setattr(r31, name, _once(getattr(r31, name), _PATH_OLD, _DEPTH_NEW, name))
    r31._SCHEMA_RESOLUTION_NEW = _once(
        r31._SCHEMA_RESOLUTION_NEW, _SCHEMA_OLD, _SCHEMA_NEW, "schema witness"
    )
    for name in ("_RECOMPUTE_DIAGNOSTIC_NEW", "_GENERATOR_DIAGNOSTIC_NEW", "_SCHEMA_TYPES_NEW"):
        setattr(r31, name, _once(getattr(r31, name), _OLD_ROLE, _NEW_ROLE, name))
    for name in ("_RECOMPUTE_RULE_NEW", "_GENERATOR_RULE_NEW"):
        setattr(r31, name, _once(getattr(r31, name), _OLD_RULE, _NEW_RULE, name))
    _configured = True
_ENGINE: ModuleType | None = None
def load_engine(r30_path=None, r27_path=None, r18_path=None) -> ModuleType:
    _configure()
    return r31.load_engine(r30_path=r30_path, r27_path=r27_path, r18_path=r18_path)


def engine() -> ModuleType:
    global _ENGINE
    if _ENGINE is None:
        _ENGINE = load_engine()
        r31._ENGINE = _ENGINE
    return _ENGINE


def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine()
    return r31.analyze_native_strip(*args, **kwargs)


def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine()
    return r31.pair_after_channel_contours(*args, **kwargs)


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return engine().channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return engine().public_candidate_records(*args, **kwargs)


def install_compact_review_hooks(runner: ModuleType) -> None:
    engine()
    r31.install_compact_review_hooks(runner)


def adapter_evidence() -> dict[str, Any]:
    loaded = engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r32_notch_classification_v1",
        "state": "PASS_R32_COMPLETE_CONTOUR_AND_CANDIDATE_RAW_DEPTH_WITNESS_BOUND",
        "frozenR31Sha256": R31_SHA256,
        "minimumCandidateRawDepthNodeCount": int(loaded.MINIMUM_SHOULDER_SUPPORT_SAMPLES),
        "selectedNativeContoursChanged": False,
        "shapeCoverageAndGapGatesChanged": False,
        "internalLaneAmbiguityRole": "AUTHORITY_TELEMETRY_NOT_MORPHOLOGY_VETO",
        "notchOwnershipGranted": False,
        "reviewOnly": True,
        "productionEligible": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE"))
    parser.parse_args()
    print(json.dumps(adapter_evidence(), sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
