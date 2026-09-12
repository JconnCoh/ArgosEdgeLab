#!/usr/bin/env python3
"""Review-only R30 selector correction over the exact frozen R27 detector.

R30 changes one ordering decision inside R27's native path traversal: after
separated-band continuity, coverage, and gap count are equal, direct native
brightness is balanced against radial travel at 0.5 intensity units per native
pixel.  This follows a stronger measured edge inside one physical band without
letting either a flat minimum-travel lane or an isolated bright detour dominate.

The frozen R27 byte stream is hash-verified and never edited.  Its exact
import-time bootstrap and selector tuple are replaced in memory with counted,
fail-closed substitutions.  No pixels are synthesized, morphed, interpolated,
or transferred between channels, and this module grants no production,
provider, fiducial, registration, training, XML, task/process, source-mutation,
or hold-clearance authority.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
from types import ModuleType
from typing import Any


HERE = Path(__file__).resolve().parent
R27_NAME = "AnnularUnwrapCandidateFirstOpenCvR27.py"
R18_NAME = "AnnularUnwrapDiagnosticOpenCvR18.py"
R27_SHA256 = "0D6037F2DABFD682D404246F451B617FAE8E132F0BE3D26127C8C670466B71C8"
R18_SHA256 = "510F75463E8494A67442AEACBB7A16F71FE7B307EFEA9231F7CDD7FF6FE34317"

_FROZEN_BOOTSTRAP = """configure_pinned_dependency_paths()
require_exact_file(R21_PATH, R21_SHA256, \"R21 engine\")
SPEC = importlib.util.spec_from_file_location(\"argos_annular_r21_for_r27\", R21_PATH)
need(SPEC is not None and SPEC.loader is not None, f\"Cannot load {R21_PATH}\")
r21 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r21
SPEC.loader.exec_module(r21)
r18 = r21.r19.r18
"""
_PORTABLE_BOOTSTRAP = """# R30_PORTABLE_BOOTSTRAP_BEGIN
r21 = None
r18 = _R30_INJECTED_R18
# R30_PORTABLE_BOOTSTRAP_END
"""
_R27_SELECTOR_COMMENT = """        # Each state is keyed by (native row, has visited a raw-depth core).
        # Avoidable separated-band changes are ranked out before coverage and
        # the one-column no-fill allowance.  Coverage then precedes native
        # travel and every brightness witness.  Center, shape, R6, and ideal
        # curves are absent from traversal.
"""
_R30_SELECTOR_COMMENT = """        # Each state is keyed by (native row, has visited a raw-depth core).
        # Avoidable separated-band changes are ranked out before coverage and
        # the one-column no-fill allowance.  Within an equally continuous and
        # complete physical band, direct native brightness is reduced by 0.5
        # intensity units per pixel of radial travel before secondary witnesses.
        # Center, shape, R6, and ideal curves are absent from traversal.
"""
_R27_SELECTOR_RANK = """                        rank = (
                            -state[\"avoidableBandSwitches\"],
                            state[\"count\"],
                            -state[\"gaps\"],
                            -state[\"radialTravel\"],
                            state[\"directRaw\"],
                            state[\"enhanced\"],
                            state[\"raw\"],
                            -row,
                        )
"""
_R30_SELECTOR_RANK = """                        rank = (
                            -state[\"avoidableBandSwitches\"],
                            state[\"count\"],
                            -state[\"gaps\"],
                            state[\"directRaw\"] - 0.5 * state[\"radialTravel\"],
                            state[\"enhanced\"],
                            state[\"raw\"],
                            -state[\"radialTravel\"],
                            -row,
                        )
"""
_R27_RANK_LABEL = "\"THEN_NATIVE_RADIAL_TRAVEL_THEN_DIRECT_RAW_THEN_ENHANCED_THEN_RAW\""
_R30_RANK_LABEL = "\"THEN_DIRECT_RAW_MINUS_0P5_TIMES_NATIVE_RADIAL_TRAVEL_THEN_ENHANCED_THEN_RAW_THEN_NATIVE_RADIAL_TRAVEL\""
EXPORTED_FUNCTIONS = (
    "analyze_native_strip",
    "pair_after_channel_contours",
    "channel_summary",
    "public_candidate_records",
)


class R30Error(RuntimeError):
    """Fail-closed R30 detector-overlay error."""


def need(value: Any, message: str) -> None:
    if not value:
        raise R30Error(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _resolved_input(name: str, environment_name: str) -> Path:
    value = os.environ.get(environment_name)
    return Path(value).resolve() if value else (HERE / name).resolve()


def _load_module(path: Path, expected_sha256: str, module_name: str) -> ModuleType:
    need(path.is_file(), f"Missing pinned dependency: {path}")
    need(sha256_file(path) == expected_sha256, f"Dependency hash changed: {path}")
    spec = importlib.util.spec_from_file_location(module_name, path)
    need(spec is not None and spec.loader is not None, f"Cannot load dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def _transform_source(frozen_bytes: bytes) -> tuple[str, str]:
    source = frozen_bytes.decode("utf-8")
    need(source.count(_FROZEN_BOOTSTRAP) == 1, "Frozen R27 bootstrap structure changed")
    need(source.count(_R27_SELECTOR_COMMENT) == 1, "Frozen R27 selector comment structure changed")
    need(source.count(_R27_SELECTOR_RANK) == 1, "Frozen R27 selector rank structure changed")
    need(source.count(_R27_RANK_LABEL) == 2, "Frozen R27 selector telemetry structure changed")
    transformed = source.replace(_FROZEN_BOOTSTRAP, _PORTABLE_BOOTSTRAP, 1)
    transformed = transformed.replace(_R27_SELECTOR_COMMENT, _R30_SELECTOR_COMMENT, 1)
    transformed = transformed.replace(_R27_SELECTOR_RANK, _R30_SELECTOR_RANK, 1)
    transformed = transformed.replace(_R27_RANK_LABEL, _R30_RANK_LABEL, 2)
    need(_FROZEN_BOOTSTRAP not in transformed, "R27 bootstrap replacement was incomplete")
    need(_R27_SELECTOR_RANK not in transformed, "R27 selector rank replacement was incomplete")
    need(_R27_RANK_LABEL not in transformed, "R27 selector telemetry replacement was incomplete")
    transformed_sha256 = hashlib.sha256(transformed.encode("utf-8")).hexdigest().upper()
    return transformed, transformed_sha256


def load_engine(
    r27_path: Path | None = None,
    r18_path: Path | None = None,
) -> ModuleType:
    frozen_path = (r27_path or _resolved_input(R27_NAME, "ARGOS_R27_ENGINE_PATH")).resolve()
    dependency_path = (r18_path or _resolved_input(R18_NAME, "ARGOS_R18_ENGINE_PATH")).resolve()
    need(frozen_path.is_file(), f"Frozen R27 input is missing: {frozen_path}")
    frozen_bytes = frozen_path.read_bytes()
    need(hashlib.sha256(frozen_bytes).hexdigest().upper() == R27_SHA256, "Frozen R27 physical bytes changed")
    r18 = _load_module(dependency_path, R18_SHA256, "argos_annular_r18_for_r30")
    transformed, transformed_sha256 = _transform_source(frozen_bytes)

    module_name = "argos_annular_candidate_first_r30"
    module = ModuleType(module_name)
    module.__file__ = str(frozen_path)
    module.__package__ = ""
    module.__dict__["_R30_INJECTED_R18"] = r18
    module.__dict__["R30_TRANSFORMED_SOURCE_SHA256"] = transformed_sha256
    sys.modules[module_name] = module
    exec(compile(transformed, str(frozen_path), "exec"), module.__dict__)

    need(module.r18 is r18 and module.r21 is None, "R30 dependency injection failed")
    for name in EXPORTED_FUNCTIONS:
        need(callable(getattr(module, name, None)), f"Frozen R27 export is missing: {name}")
    need(float(module.r18.EDGE_ZONE_INWARD_PX) == 20.0, "Yellow inward offset changed")
    return module


_ENGINE: ModuleType | None = None


def engine() -> ModuleType:
    global _ENGINE
    if _ENGINE is None:
        _ENGINE = load_engine()
    return _ENGINE


def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return engine().analyze_native_strip(*args, **kwargs)


def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return engine().pair_after_channel_contours(*args, **kwargs)


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return engine().channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return engine().public_candidate_records(*args, **kwargs)


def adapter_evidence(loaded: ModuleType | None = None) -> dict[str, Any]:
    loaded = loaded or engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r30_selector_overlay_v1",
        "state": "PASS_R30_BALANCED_BRIGHTNESS_TRAVEL_WITHIN_CONTINUOUS_NATIVE_BAND_BOUND",
        "frozenR27Sha256": R27_SHA256,
        "packageLocalR18Sha256": R18_SHA256,
        "transformedSourceSha256": loaded.R30_TRANSFORMED_SOURCE_SHA256,
        "bootstrapReplacementCount": 1,
        "selectorRankReplacementCount": 1,
        "selectorTelemetryReplacementCount": 2,
        "selectorPriority": [
            "ZERO_AVOIDABLE_BAND_SWITCHES",
            "SUPPORTED_COUNT",
            "GAPS",
            "DIRECT_RAW_MINUS_0P5_TIMES_NATIVE_RADIAL_TRAVEL",
            "ENHANCED",
            "RAW",
            "NATIVE_RADIAL_TRAVEL",
        ],
        "directRawTravelPenaltyPerNativePx": 0.5,
        "detectorFunctionBodiesModified": True,
        "detectorModificationScope": "ONE_NATIVE_PATH_RANK_TUPLE_ONLY",
        "channelLocalNativeBrightnessContoursBeforePairing": True,
        "cyanFixedOuterCircle": True,
        "yellowExactly20PxInward": float(loaded.r18.EDGE_ZONE_INWARD_PX) == 20.0,
        "idealCurveUsed": False,
        "morphologyPerformed": False,
        "interpolationPerformed": False,
        "crossChannelPixelTransferPerformed": False,
        "r6Role": "POST_CONTOUR_SECONDARY_CORROBORATION_ONLY",
        "chipoutCanBeNotchOwned": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
        "holdClearanceAllowed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE"))
    args = parser.parse_args()
    evidence = adapter_evidence()
    if args.stage == "ADAPTER_CHECK":
        evidence = dict(evidence, requestedStage="ADAPTER_CHECK")
    print(json.dumps(evidence, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
