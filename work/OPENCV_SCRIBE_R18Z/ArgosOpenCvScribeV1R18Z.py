#!/usr/bin/env python3
"""R18Z 475-reference envelopes keyed by exact confirmed scribe lineage."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Iterable


EXPECTED_R18ZV_PROVIDER_SHA256 = "BA85E9594562334C54A7CC7A0D7B2DDA3868714D8A87A223E2B2A04F589FDC0B"
EXPECTED_LINEAGE_CROSSWALK_SHA256 = "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2"
EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256 = "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD"
EXPECTED_REFERENCE_COUNT = 475
EXPECTED_LINEAGE_COUNT = 49
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18Z_EXACT_SCRIBE_LINEAGE_ENVELOPES_DIAGNOSTIC_20260905"


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
R18ZV_PATH = ROOT / "OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18ZV.py"
if _sha256_file(R18ZV_PATH) != EXPECTED_R18ZV_PROVIDER_SHA256:
    raise ValueError("R18Z envelope provider SHA-256 mismatch.")
R18ZV = _load("argos_scribe_r18zv_for_r18z", R18ZV_PATH)
R18V = R18ZV.R18V
R18H = R18ZV.R18H
R17E = R18ZV.R17E
R17D = R18ZV.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18ZV.MINIMUM_POST_GRID_IMAGE_SCORE
build_glyph_envelope_bank = R18ZV.build_glyph_envelope_bank
coverage_evidence = R18ZV.coverage_evidence
assess_glyph_envelope = R18ZV.assess_glyph_envelope
load_run_structure_prototypes = R18H.load_run_structure_prototypes
_BASE_R18ZV_EVALUATE = R18ZV.evaluate_detector_input_enveloped
_RUNTIME_PATCH_LOCK = R18ZV._RUNTIME_PATCH_LOCK


class _R18FFacade:
    """Expose the frozen R18F surface with the exact R18Z supplement loader."""

    def __init__(self, base: Any) -> None:
        self._base = base
        self.R18F_LOADER = R18ZV.R18Z_LOADER

    def __getattr__(self, name: str) -> Any:
        return getattr(self._base, name)


R18F = _R18FFacade(R18ZV.R18F)
DEFAULT_LINEAGE_CROSSWALK_PATH = (
    Path(__file__).with_name("reference_bank")
    / "R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
)


def load_lineage_mapping(path: Path, expected_sha256: str) -> tuple[dict[str, str], str]:
    actual = _sha256_file(path)
    if actual != expected_sha256.upper() or actual != EXPECTED_LINEAGE_CROSSWALK_SHA256:
        raise ValueError("R18Z exact-scribe lineage crosswalk SHA-256 mismatch.")
    manifest = json.loads(path.read_text(encoding="utf-8-sig"))
    if (
        manifest.get("schema")
        != "argos_opencv_scribe_r18z_exact_scribe_lineage_crosswalk_v1"
        or manifest.get("state")
        != "PASS_R18Z_475_REFERENCES_49_EXACT_SCRIBE_LINEAGES"
        or int(manifest.get("referenceCount", -1)) != EXPECTED_REFERENCE_COUNT
        or int(manifest.get("exactScribeLineageCount", -1)) != EXPECTED_LINEAGE_COUNT
        or manifest.get("supplementalManifestSha256")
        != EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256
        or manifest.get("identityAccepted") is not False
        or manifest.get("activationAuthorized") is not False
        or manifest.get("trainingAuthorized") is not False
        or manifest.get("productionAuthorized") is not False
    ):
        raise ValueError("R18Z exact-scribe lineage crosswalk contract mismatch.")
    rows = list(manifest.get("mappingRows", []))
    if len(rows) != EXPECTED_LINEAGE_COUNT:
        raise ValueError("R18Z requires exactly 49 exact-scribe lineage mappings.")
    mapping: dict[str, str] = {}
    lineage_keys: set[str] = set()
    for row in rows:
        raw = str(row.get("physicalIdentity", "")).strip()
        lineage = str(row.get("exactScribeLineage", "")).strip().upper()
        key = raw.casefold()
        if (
            not raw
            or len(lineage) != 12
            or not lineage.isalnum()
            or key in mapping
            or lineage in lineage_keys
        ):
            raise ValueError("R18Z invalid or duplicate exact-scribe lineage mapping.")
        mapping[key] = lineage
        lineage_keys.add(lineage)
    digest = hashlib.sha256()
    for raw, lineage in sorted(mapping.items()):
        digest.update(f"{raw}\0{lineage}\n".encode("utf-8"))
    return mapping, digest.hexdigest().upper()


def rekey_prototypes(rows: list[Any], mapping: dict[str, str]) -> list[Any]:
    output: list[Any] = []
    missing: set[str] = set()
    for row in rows:
        raw = str(row.physical_identity).strip()
        lineage = mapping.get(raw.casefold())
        if lineage is None:
            missing.add(raw)
            continue
        output.append(type(row)(str(row.label), lineage, row.descriptor))
    if missing:
        raise ValueError(f"R18Z unmapped frozen reference identities: {sorted(missing)}")
    if len(output) != EXPECTED_REFERENCE_COUNT:
        raise ValueError(
            f"R18Z requires exactly {EXPECTED_REFERENCE_COUNT} re-keyed references."
        )
    return output


def assert_aligned_reference_banks(
    prototypes: list[Any],
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
) -> None:
    R18ZV.assert_aligned_reference_banks(
        prototypes, topology_prototypes, run_structure_prototypes
    )


def map_excluded_identity(excluded_identity: str, mapping: dict[str, str]) -> str:
    normalized = excluded_identity.strip()
    return mapping.get(normalized.casefold(), normalized)


def evaluate_detector_input_exact_lineage(
    r11: Any,
    gray: Any,
    prototypes: list[Any],
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
    excluded_identity: str,
    mapping: dict[str, str],
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    assert_aligned_reference_banks(
        prototypes, topology_prototypes, run_structure_prototypes
    )
    rekeyed_prototypes = rekey_prototypes(prototypes, mapping)
    rekeyed_topology = rekey_prototypes(topology_prototypes, mapping)
    rekeyed_run_structure = rekey_prototypes(run_structure_prototypes, mapping)
    assert_aligned_reference_banks(
        rekeyed_prototypes, rekeyed_topology, rekeyed_run_structure
    )
    return _BASE_R18ZV_EVALUATE(
        r11,
        gray,
        rekeyed_prototypes,
        rekeyed_topology,
        rekeyed_run_structure,
        map_excluded_identity(excluded_identity, mapping),
        frozen_grid,
    )


def evaluate_detector_input_structural(
    r11: Any,
    gray: Any,
    prototypes: list[Any],
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
    excluded_identity: str,
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    mapping, _ = load_lineage_mapping(
        DEFAULT_LINEAGE_CROSSWALK_PATH, EXPECTED_LINEAGE_CROSSWALK_SHA256
    )
    return evaluate_detector_input_exact_lineage(
        r11,
        gray,
        prototypes,
        topology_prototypes,
        run_structure_prototypes,
        excluded_identity,
        mapping,
        frozen_grid,
    )


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18Z provider invocation is not allowed.")

    try:
        r11 = R17D.R17C.R17B._load_r11()
        job = r11.read_json(job_path)
        references = job.get("references", {})
        crosswalk_path = Path(str(references.get("exactScribeLineageCrosswalkPath", "")))
        crosswalk_sha256 = str(
            references.get("exactScribeLineageCrosswalkSha256", "")
        ).upper()
        if not crosswalk_path.is_file():
            raise ValueError("R18Z exact-scribe lineage crosswalk is missing.")
        mapping, mapping_fingerprint = load_lineage_mapping(
            crosswalk_path, crosswalk_sha256
        )

        original_evaluate = R18ZV.evaluate_detector_input_enveloped
        original_apply = R18ZV._apply_result_envelope_state

        def evaluate(
            r11: Any,
            gray: Any,
            prototypes: list[Any],
            topology_prototypes: list[Any],
            run_structure_prototypes: list[Any],
            excluded_identity: str,
            frozen_grid: tuple[int, int, int, int] | None = None,
        ) -> dict[str, Any]:
            return evaluate_detector_input_exact_lineage(
                r11,
                gray,
                prototypes,
                topology_prototypes,
                run_structure_prototypes,
                excluded_identity,
                mapping,
                frozen_grid,
            )

        def apply_result(result: dict[str, Any]) -> None:
            original_apply(result)
            result.setdefault("provenance", {}).update(
                {
                    "referencePhysicalLineageKey": "EXACT_HUMAN_CONFIRMED_12_CHARACTER_SCRIBE",
                    "exactScribeLineageCrosswalkSha256": crosswalk_sha256,
                    "exactScribeLineageMappingFingerprint": mapping_fingerprint,
                    "runtimeExpectedTruthUsedForGlyphSelection": False,
                }
            )
            result["revision"] = REVISION

        R18ZV.evaluate_detector_input_enveloped = evaluate
        R18ZV._apply_result_envelope_state = apply_result
        try:
            return R18ZV._run_job_locked(job_path, result_path)
        finally:
            R18ZV._apply_result_envelope_state = original_apply
            R18ZV.evaluate_detector_input_enveloped = original_evaluate
    finally:
        _RUNTIME_PATCH_LOCK.release()


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(
            json.dumps(
                {
                    "state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR",
                    "errorType": type(error).__name__,
                    "detail": str(error),
                }
            ),
            file=sys.stderr,
        )
        raise
