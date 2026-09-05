#!/usr/bin/env python3
"""R18V with frozen references keyed by exact confirmed scribe lineage."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Iterable


EXPECTED_R18V_PROVIDER_SHA256 = "6DF8F25F4D56C8DBB0097C411053CE3DCD38D48A97E1DF88D18A5EA82A6E0D15"
EXPECTED_LINEAGE_CROSSWALK_SHA256 = "EAF725D04C899CCEFC70E29DDA990D4058F226D7C602C1607D7ADB2E9CED1099"
EXPECTED_REFERENCE_COUNT = 465
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18Y_EXACT_SCRIBE_LINEAGE_ENVELOPES_DIAGNOSTIC_20260905"


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
R18V_PATH = ROOT / "OPENCV_SCRIBE_R18V/ArgosOpenCvScribeV1R18V.py"
if _sha256_file(R18V_PATH) != EXPECTED_R18V_PROVIDER_SHA256:
    raise ValueError("Frozen R18V provider SHA-256 mismatch.")
R18V = _load("argos_scribe_r18v_for_r18y", R18V_PATH)


def load_lineage_mapping(path: Path, expected_sha256: str) -> tuple[dict[str, str], str]:
    actual = _sha256_file(path)
    if actual != expected_sha256.upper() or actual != EXPECTED_LINEAGE_CROSSWALK_SHA256:
        raise ValueError("R18Y exact-scribe lineage crosswalk SHA-256 mismatch.")
    manifest = json.loads(path.read_text(encoding="utf-8-sig"))
    if (
        manifest.get("schema") != "argos_opencv_scribe_r18x_exact_scribe_lineage_crosswalk_v1"
        or manifest.get("state")
        != "PASS_R18X_EXACT_SCRIBE_LINEAGE_REKEY_CARDINALITY_PRESERVED"
        or int(manifest.get("summary", {}).get("verifiedReferenceRows", -1))
        != EXPECTED_REFERENCE_COUNT
    ):
        raise ValueError("R18Y exact-scribe lineage crosswalk contract mismatch.")
    mapping: dict[str, str] = {}
    lineage_keys: set[str] = set()
    for row in manifest.get("baseLineages", []):
        raw = str(row.get("legacyPhysicalIdentity", "")).strip()
        lineage = str(row.get("exactScribeLineage", "")).strip().upper()
        if not raw or len(lineage) != 12 or not lineage.isalnum():
            raise ValueError("R18Y invalid base exact-scribe lineage mapping.")
        key = raw.casefold()
        if key in mapping or lineage in lineage_keys:
            raise ValueError("R18Y duplicate base exact-scribe lineage mapping.")
        mapping[key] = lineage
        lineage_keys.add(lineage)
    for row in manifest.get("supplementalLineages", []):
        raw = str(row.get("physicalIdentity", "")).strip()
        lineage = str(row.get("exactScribeLineage", "")).strip().upper()
        if not raw or len(lineage) != 12 or not lineage.isalnum():
            raise ValueError("R18Y invalid supplemental exact-scribe lineage mapping.")
        key = raw.casefold()
        if key in mapping or lineage in lineage_keys:
            raise ValueError("R18Y duplicate supplemental exact-scribe lineage mapping.")
        mapping[key] = lineage
        lineage_keys.add(lineage)
    if len(mapping) != 41 or len(lineage_keys) != 41:
        raise ValueError("R18Y requires exactly 41 current exact-scribe reference lineages.")
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
        raise ValueError(f"R18Y unmapped frozen reference identities: {sorted(missing)}")
    if len(output) != EXPECTED_REFERENCE_COUNT:
        raise ValueError(f"R18Y requires exactly {EXPECTED_REFERENCE_COUNT} re-keyed references.")
    return output


def map_excluded_identity(excluded_identity: str, mapping: dict[str, str]) -> str:
    normalized = excluded_identity.strip()
    return mapping.get(normalized.casefold(), normalized)


def run_job(job_path: Path, result_path: Path) -> int:
    r11 = R18V.R17D.R17C.R17B._load_r11()
    job = r11.read_json(job_path)
    references = job.get("references", {})
    crosswalk_path = Path(str(references.get("exactScribeLineageCrosswalkPath", "")))
    crosswalk_sha256 = str(references.get("exactScribeLineageCrosswalkSha256", "")).upper()
    if not crosswalk_path.is_file():
        raise ValueError("R18Y exact-scribe lineage crosswalk is missing.")
    mapping, mapping_fingerprint = load_lineage_mapping(crosswalk_path, crosswalk_sha256)

    original_evaluate = R18V.evaluate_detector_input_enveloped
    original_apply = R18V._apply_result_envelope_state
    original_revision = R18V.REVISION

    def evaluate(
        r11: Any,
        gray: Any,
        prototypes: list[Any],
        topology_prototypes: list[Any],
        run_structure_prototypes: list[Any],
        excluded_identity: str,
        frozen_grid: tuple[int, int, int, int] | None = None,
    ) -> dict[str, Any]:
        return original_evaluate(
            r11,
            gray,
            rekey_prototypes(prototypes, mapping),
            rekey_prototypes(topology_prototypes, mapping),
            rekey_prototypes(run_structure_prototypes, mapping),
            map_excluded_identity(excluded_identity, mapping),
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

    R18V.evaluate_detector_input_enveloped = evaluate
    R18V._apply_result_envelope_state = apply_result
    R18V.REVISION = REVISION
    try:
        return R18V.run_job(job_path, result_path)
    finally:
        R18V.REVISION = original_revision
        R18V._apply_result_envelope_state = original_apply
        R18V.evaluate_detector_input_enveloped = original_evaluate


def main(argv: Iterable[str]) -> int:
    r11 = R18V.R17D.R17C.R17B._load_r11()
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
