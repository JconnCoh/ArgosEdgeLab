#!/usr/bin/env python3
"""Fresh exact-scribe-lineage leave-one-out gate for the R18Z reference bank.

The frozen R18V/R18Y algorithms and thresholds are reused without mutation.
Runtime truth is compared only after image-only ranking and envelope assessment.
The first 465 queries must reproduce and remain accepted wherever frozen R18Y
accepted them; the ten R18Z queries are then evaluated under the same rule.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np


BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
OLD_SUPPLEMENTAL_MANIFEST_SHA256 = "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114"
OLD_CROSSWALK_SHA256 = "EAF725D04C899CCEFC70E29DDA990D4058F226D7C602C1607D7ADB2E9CED1099"
R18V_GATE_SHA256 = "BEA75FAC417BEE9D0DB5B3302AEEAD15053C46A2AC434BBB7A49E04AADC437C9"
R18Y_PROVIDER_SHA256 = "A3F092E85E074F468A824DB29289A238821C3AB32B63322CB4B2A162BD581CB8"
R18Y_TEST_SHA256 = "AF820A584E1E9D8D25CDA046783AE114D40ED0386712FD2D3140549085983A49"
R18Y_GATE_SHA256 = "166BF86170A50D84CCB02F196B55A59DEB1C3764E1EC2A2FECD351BC0AD25F81"

BUILDER_SHA256 = "D85CF04DAED955A3B07D4810B6C5F0E487BF42800607D41D1A6FBD4ECD78268C"
SOURCE_BINDING_GATE_SHA256 = "47135F5F069F5FF203C0E53C8F5075789E81FC112CA988C81A21B2B426422542"
CASE_OUTPUTS_SHA256 = "2B3DC84F9B62F6EA51F433AA935E77727B67B72658286534C79FA229E73245C5"
BUILD_GATE_SHA256 = "81BFDA2F7427BBC83F603B22D695086722B6CAA268602C6440CCEC0C0E997039"
NEW_SUPPLEMENTAL_MANIFEST_SHA256 = "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD"
NEW_CROSSWALK_SHA256 = "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2"

BASELINE_REFERENCE_COUNT = 465
NEW_REFERENCE_COUNT = 475
BASELINE_LINEAGE_COUNT = 41
NEW_LINEAGE_COUNT = 49
EXPECTED_COUNTS = {
    "D": 1,
    "H": 1,
    "J": 2,
    "K": 2,
    "L": 1,
    "M": 1,
    "N": 3,
    "Q": 2,
    "R": 1,
    "T": 1,
    "W": 1,
    "X": 2,
    "Z": 1,
}
EXPECTED_NEW_REFERENCES = {
    ("62627-140_20260802111846_Slot24", "147MH067SUD2", "D", 11),
    ("62627-140_20260802111846_Slot24", "147MH067SUD2", "H", 5),
    ("62627-140_20260802111846_Slot24", "147MH067SUD2", "M", 4),
    ("62625-907-POST-20260714155300_20260714155354_Slot14", "146XF109SUG7", "X", 4),
    ("62546-481-POST_20260708155428_Slot03", "0303N050FEE4", "N", 5),
    ("62546-481-POST_20260708155428_Slot04", "0303N049FEB3", "N", 5),
    ("62546-481_20260707164232_Slot05", "0303N047FEA2", "N", 5),
    ("62619-451-PRE_20260717143452_Slot01", "146AR068SUC7", "R", 5),
    ("62619-451-PRE_20260717143452_Slot09", "1478T059SUA3", "T", 5),
    ("62620-548_20260810154124_Slot02", "L0751042FEF5", "L", 1),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def sha256_json(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def contained_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ValueError(f"Supplement path must be relative: {relative}")
    resolved_root = root.resolve()
    path = (resolved_root / Path(relative.replace("/", "\\"))).resolve()
    if path != resolved_root and resolved_root not in path.parents:
        raise ValueError(f"Supplement path escaped its root: {relative}")
    return path


def validate_new_source_chain(
    project: Path,
    supplemental_path: Path,
    crosswalk_path: Path,
    build_gate_path: Path,
) -> dict[str, Any]:
    builder_path = project / "work/OPENCV_SCRIBE_R18Z/Build-R18ZSupplementalGlyphs.py"
    source_gate_path = project / "work/OPENCV_SCRIBE_R18Z/R18Z_SOURCE_BINDING_GATE_V3.json"
    case_outputs_path = project / "work/OPENCV_SCRIBE_R18Z/R18Z_CASE_OUTPUTS_V3.json"
    pins = {
        "builder": (builder_path, BUILDER_SHA256),
        "sourceBindingGate": (source_gate_path, SOURCE_BINDING_GATE_SHA256),
        "caseOutputs": (case_outputs_path, CASE_OUTPUTS_SHA256),
        "buildGate": (build_gate_path, BUILD_GATE_SHA256),
        "supplementalManifest": (supplemental_path, NEW_SUPPLEMENTAL_MANIFEST_SHA256),
        "exactScribeLineageCrosswalk": (crosswalk_path, NEW_CROSSWALK_SHA256),
    }
    for name, (path, expected) in pins.items():
        if not path.is_file() or sha256_file(path) != expected:
            raise ValueError(f"R18Z source-chain pin mismatch: {name}")
    gate = read_json(build_gate_path)
    required = {
        "schema": "argos_opencv_scribe_r18z_reference_build_gate_v1",
        "state": "PASS_R18Z_EXACT_DECLARED_GLYPH_REFERENCE_REVISION_BUILT",
        "builderSha256": BUILDER_SHA256,
        "sourceBindingGateSha256": SOURCE_BINDING_GATE_SHA256,
        "caseOutputManifestSha256": CASE_OUTPUTS_SHA256,
        "supplementalManifestSha256": NEW_SUPPLEMENTAL_MANIFEST_SHA256,
        "exactScribeLineageCrosswalkSha256": NEW_CROSSWALK_SHA256,
        "combinedReferenceCount": NEW_REFERENCE_COUNT,
        "combinedExactScribeLineageCount": NEW_LINEAGE_COUNT,
        "newDeclaredReferenceCount": 10,
        "incidentalReferenceCount": 0,
        "identityAccepted": False,
        "activationAuthorized": False,
        "trainingAuthorized": False,
        "productionAuthorized": False,
        "xmlAuthorized": False,
    }
    for key, expected in required.items():
        if gate.get(key) != expected:
            raise ValueError(f"R18Z build-gate contract mismatch: {key}")
    return gate


def validate_and_load_new_supplement(
    r11: Any,
    new_path: Path,
    old_path: Path,
) -> tuple[list[Any], dict[str, Any]]:
    if sha256_file(new_path) != NEW_SUPPLEMENTAL_MANIFEST_SHA256:
        raise ValueError("R18Z supplemental manifest changed.")
    if sha256_file(old_path) != OLD_SUPPLEMENTAL_MANIFEST_SHA256:
        raise ValueError("Frozen R18F supplemental manifest changed.")
    manifest = read_json(new_path)
    old_manifest = read_json(old_path)
    if (
        manifest.get("schema") != "argos_opencv_scribe_supplemental_glyph_references_v1"
        or manifest.get("disposition") != "DIAGNOSTIC_ONLY"
        or manifest.get("remainingMissingLabelsAfterSupplement") != "IOVY"
    ):
        raise ValueError("R18Z supplemental manifest contract mismatch.")
    for field in (
        "identityAdmissionAuthorized",
        "activationAuthorized",
        "trainingAuthorized",
        "productionAuthorized",
    ):
        if manifest.get(field) is not False:
            raise ValueError(f"R18Z supplemental authority mismatch: {field}")
    references = list(manifest.get("references", []))
    old_references = list(old_manifest.get("references", []))
    if len(references) != 19 or references[:9] != old_references:
        raise ValueError("R18Z did not preserve the exact nine frozen R18F rows first.")
    declared_counts = {
        str(key): int(value) for key, value in dict(manifest.get("labelCounts", {})).items()
    }
    if declared_counts != EXPECTED_COUNTS:
        raise ValueError("R18Z supplemental declared label counts changed.")
    observed_new = {
        (
            str(row.get("physicalIdentity", "")),
            str(row.get("truth", "")),
            str(row.get("label", "")),
            int(row.get("position", 0)),
        )
        for row in references[9:]
    }
    if observed_new != EXPECTED_NEW_REFERENCES:
        raise ValueError("R18Z ten declared reference identities changed.")

    prototypes: list[Any] = []
    counts: dict[str, int] = {}
    seen: set[tuple[str, str, int]] = set()
    glyph_hashes: list[str] = []
    for index, row in enumerate(references):
        label = str(row.get("label", ""))
        case_id = str(row.get("caseId", ""))
        position = int(row.get("position", 0))
        physical_identity = str(row.get("physicalIdentity", ""))
        key = (label, case_id, position)
        if len(label) != 1 or label not in r11.BODY_LABELS or key in seen:
            raise ValueError(f"Invalid or duplicate R18Z supplemental reference: {key}")
        seen.add(key)
        if index >= 9:
            truth = str(row.get("truth", ""))
            if (
                len(truth) != 12
                or truth[position - 1] != label
                or row.get("exactScribeLineage") != truth
                or row.get("declaredByR18W3Selection") is not True
                or row.get("exactMesTruthBound") is not True
                or row.get("incidentalGlyph") is not False
                or row.get("identityAccepted") is not False
                or row.get("operatorConfirmed") is not False
                or row.get("sourceDirection") != "FORWARD_ORIENTED_INPUT_CONTRACT"
            ):
                raise ValueError(f"R18Z declared-glyph authority mismatch: {key}")
        path = contained_path(new_path.parent, str(row.get("relativePath", "")))
        actual_hash = sha256_file(path) if path.is_file() else ""
        if actual_hash != str(row.get("sha256", "")).upper():
            raise ValueError(f"R18Z supplemental glyph is absent or changed: {path}")
        if "bytes" in row and path.stat().st_size != int(row["bytes"]):
            raise ValueError(f"R18Z supplemental glyph byte count changed: {path}")
        gray = r11.decode_gray_exact(path)
        residual = r11.dark_residual_exact(gray, max(4, min(12, gray.shape[1] // 8)))
        descriptor = r11.describe_exact(residual, 0, 0, gray.shape[1], gray.shape[0])
        if descriptor is None:
            raise ValueError(f"R18Z supplemental glyph could not be described: {path}")
        prototypes.append(r11.Prototype(label, physical_identity, descriptor))
        counts[label] = counts.get(label, 0) + 1
        glyph_hashes.append(actual_hash)
    if counts != EXPECTED_COUNTS or len(prototypes) != 19:
        raise ValueError(f"R18Z supplemental observed counts changed: {counts}")
    return prototypes, {
        "referenceCount": len(prototypes),
        "labelCounts": counts,
        "orderedGlyphHashFingerprint": sha256_json(glyph_hashes),
        "oldRowsPreservedExactly": True,
        "newDeclaredReferenceCount": 10,
        "incidentalReferenceCount": 0,
    }


def load_new_mapping(path: Path) -> tuple[dict[str, str], str, dict[str, Any]]:
    if sha256_file(path) != NEW_CROSSWALK_SHA256:
        raise ValueError("R18Z exact-scribe lineage crosswalk changed.")
    manifest = read_json(path)
    required = {
        "schema": "argos_opencv_scribe_r18z_exact_scribe_lineage_crosswalk_v1",
        "state": "PASS_R18Z_475_REFERENCES_49_EXACT_SCRIBE_LINEAGES",
        "classification": "DIAGNOSTIC_ONLY",
        "referenceCount": NEW_REFERENCE_COUNT,
        "exactScribeLineageCount": NEW_LINEAGE_COUNT,
        "predecessorCrosswalkSha256": OLD_CROSSWALK_SHA256,
        "supplementalManifestSha256": NEW_SUPPLEMENTAL_MANIFEST_SHA256,
        "coveredCharacters": "0123456789ABCDEFGHLNPRSTU",
        "sparseCharacters": "JKMQWXZ",
        "unobservedCharacters": "IOVY",
        "identityAccepted": False,
        "activationAuthorized": False,
        "trainingAuthorized": False,
        "productionAuthorized": False,
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            raise ValueError(f"R18Z crosswalk contract mismatch: {key}")
    rows = list(manifest.get("mappingRows", []))
    if len(rows) != NEW_LINEAGE_COUNT:
        raise ValueError("R18Z crosswalk row count changed.")
    mapping: dict[str, str] = {}
    lineages: set[str] = set()
    for row in rows:
        raw = str(row.get("physicalIdentity", "")).strip()
        lineage = str(row.get("exactScribeLineage", "")).strip().upper()
        key = raw.casefold()
        if (
            not raw
            or len(lineage) != 12
            or not lineage.isalnum()
            or key in mapping
            or lineage in lineages
        ):
            raise ValueError("R18Z crosswalk contains an invalid or duplicate mapping.")
        mapping[key] = lineage
        lineages.add(lineage)
    digest = hashlib.sha256()
    for raw, lineage in sorted(mapping.items()):
        digest.update(f"{raw}\0{lineage}\n".encode("utf-8"))
    return mapping, digest.hexdigest().upper(), manifest


def rekey_prototypes(rows: list[Any], mapping: dict[str, str], expected_count: int) -> list[Any]:
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
        raise ValueError(f"R18Z unmapped reference identities: {sorted(missing)}")
    if len(output) != expected_count:
        raise ValueError(f"R18Z expected {expected_count} re-keyed references.")
    return output


def assert_aligned(appearance: list[Any], topology: list[Any], run_structure: list[Any]) -> None:
    appearance_keys = [(row.label, row.physical_identity) for row in appearance]
    if appearance_keys != [(row.label, row.physical_identity) for row in topology]:
        raise ValueError("Appearance and topology exact-scribe keys differ.")
    if appearance_keys != [(row.label, row.physical_identity) for row in run_structure]:
        raise ValueError("Appearance and ordered-run exact-scribe keys differ.")


def assert_bank_prefix(baseline: list[Any], candidate: list[Any], name: str) -> None:
    if len(baseline) != BASELINE_REFERENCE_COUNT or len(candidate) != NEW_REFERENCE_COUNT:
        raise ValueError(f"{name} bank cardinality changed.")
    for index, (old, new) in enumerate(zip(baseline, candidate)):
        if (
            str(old.label) != str(new.label)
            or str(old.physical_identity) != str(new.physical_identity)
            or not np.array_equal(old.descriptor, new.descriptor)
        ):
            raise ValueError(f"R18Z changed predecessor {name} descriptor {index}.")


def run_loo(
    provider: Any,
    r11: Any,
    appearance: list[Any],
    topology: list[Any],
    run_structure: list[Any],
) -> dict[str, Any]:
    accepted = 0
    accepted_correct = 0
    accepted_wrong = 0
    held = 0
    upstream_correct = 0
    corrections: list[dict[str, Any]] = []
    query_results: list[dict[str, Any]] = []
    per_label: dict[str, dict[str, int]] = {}
    fold_cache: dict[str, tuple[Any, ...]] = {}
    for index, query in enumerate(appearance):
        excluded = str(query.physical_identity).casefold()
        cached = fold_cache.get(excluded)
        if cached is None:
            active_indices = [
                row_index
                for row_index, row in enumerate(appearance)
                if str(row.physical_identity).casefold() != excluded
            ]
            active_appearance = [appearance[row_index] for row_index in active_indices]
            active_topology = [topology[row_index] for row_index in active_indices]
            active_run = [run_structure[row_index] for row_index in active_indices]
            appearance_bank = r11.PrototypeBank.from_prototypes(active_appearance)
            topology_matrix = np.vstack(
                [row.descriptor.astype(np.float64) for row in active_topology]
            )
            topology_indices = provider.R18V.R17D._label_indices(
                np.asarray([row.label for row in active_topology])
            )
            run_scaling, run_consensus = provider.R18V.R18H._run_structure_context(active_run)
            envelope_bank = provider.R18V.build_glyph_envelope_bank(active_topology, active_run)
            cached = (
                appearance_bank,
                topology_matrix,
                topology_indices,
                run_scaling,
                run_consensus,
                envelope_bank,
            )
            fold_cache[excluded] = cached
        (
            appearance_bank,
            topology_matrix,
            topology_indices,
            run_scaling,
            run_consensus,
            envelope_bank,
        ) = cached
        ranked, _ = provider.R18V.R18H.rank_with_run_structure(
            r11,
            query.descriptor,
            topology[index].descriptor,
            run_structure[index].descriptor,
            appearance_bank,
            topology_matrix,
            topology_indices,
            run_scaling,
            run_consensus,
            0,
        )
        upstream = str(ranked[0]["character"])
        decision = provider.R18V.assess_glyph_envelope(
            envelope_bank,
            topology[index].descriptor,
            run_structure[index].descriptor,
            r11.BODY_LABELS,
            upstream,
        )
        truth = str(query.label)
        selected = str(decision["selectedLabel"])
        is_accepted = bool(decision["accepted"])
        is_correct = is_accepted and selected == truth
        is_wrong = is_accepted and selected != truth
        upstream_correct += int(upstream == truth)
        accepted += int(is_accepted)
        accepted_correct += int(is_correct)
        accepted_wrong += int(is_wrong)
        held += int(not is_accepted)
        label_summary = per_label.setdefault(
            truth,
            {
                "referenceQueries": 0,
                "upstreamCorrect": 0,
                "accepted": 0,
                "acceptedCorrect": 0,
                "acceptedWrong": 0,
                "held": 0,
            },
        )
        label_summary["referenceQueries"] += 1
        label_summary["upstreamCorrect"] += int(upstream == truth)
        label_summary["accepted"] += int(is_accepted)
        label_summary["acceptedCorrect"] += int(is_correct)
        label_summary["acceptedWrong"] += int(is_wrong)
        label_summary["held"] += int(not is_accepted)
        if is_accepted and selected != upstream:
            corrections.append(
                {
                    "referenceIndex": index,
                    "exactScribeLineage": str(query.physical_identity),
                    "truth": truth,
                    "upstream": upstream,
                    "accepted": selected,
                }
            )
        query_results.append(
            {
                "referenceIndex": index,
                "exactScribeLineage": str(query.physical_identity),
                "truth": truth,
                "upstream": upstream,
                "accepted": is_accepted,
                "selected": selected,
                "acceptedCorrect": is_correct,
                "acceptedWrong": is_wrong,
                "decision": str(decision["decision"]),
            }
        )
    summary = {
        "referenceQueries": len(appearance),
        "upstreamCorrect": upstream_correct,
        "accepted": accepted,
        "acceptedCorrect": accepted_correct,
        "acceptedWrong": accepted_wrong,
        "held": held,
        "genericEnvelopeCorrections": len(corrections),
    }
    return {
        "summary": summary,
        "acceptedCorrections": corrections,
        "perLabel": {label: per_label[label] for label in sorted(per_label)},
        "queryResults": query_results,
        "queryResultFingerprint": sha256_json(query_results),
        "foldCount": len(fold_cache),
    }


def verify_coverage(
    provider: Any,
    topology: list[Any],
    run_structure: list[Any],
    crosswalk: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], str]:
    bank = provider.R18V.build_glyph_envelope_bank(topology, run_structure)
    coverage = provider.R18V.coverage_evidence(bank)
    declared = {str(row["character"]): row for row in crosswalk.get("coverage", [])}
    if set(declared) != set(provider.R18V.BODY_LABELS):
        raise ValueError("R18Z crosswalk coverage labels changed.")
    for label, evidence in coverage.items():
        row = declared[label]
        if (
            row.get("state") != evidence["state"]
            or int(row.get("exactScribeLineageCount", -1))
            != int(evidence["independentPhysicalLineageCount"])
            or int(row.get("minimumEnforceableLineages", -1))
            != int(provider.R18V.MINIMUM_ENFORCEABLE_LINEAGES)
        ):
            raise ValueError(f"R18Z declared coverage differs for label {label}.")
    return coverage, bank.fingerprint


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--supplemental-manifest", required=True, type=Path)
    parser.add_argument("--crosswalk", required=True, type=Path)
    parser.add_argument("--build-gate", required=True, type=Path)
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output-root", type=Path)
    destination.add_argument("--expected-output", type=Path)
    args = parser.parse_args()

    project = args.project.resolve()
    supplemental_path = args.supplemental_manifest.resolve()
    crosswalk_path = args.crosswalk.resolve()
    build_gate_path = args.build_gate.resolve()
    provider_path = project / "work/OPENCV_SCRIBE_R18Y/ArgosOpenCvScribeV1R18Y.py"
    frozen_test_path = project / "work/OPENCV_SCRIBE_R18Y/Test-R18Y.py"
    r18y_gate_path = project / "work/OPENCV_SCRIBE_R18Y/R18Y_EXACT_SCRIBE_LINEAGE_GATE.json"
    r18v_gate_path = project / "work/OPENCV_SCRIBE_R18V/R18V_GLYPH_ENVELOPE_GATE.json"
    old_crosswalk_path = project / "work/OPENCV_SCRIBE_R18X/R18X_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
    old_supplemental_path = project / (
        "work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    )
    base_path = project / (
        "work/SCRIBE_REVIEW_ONLY/scratch/"
        "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
        "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    )
    frozen_pins = {
        "baseManifest": (base_path, BASE_MANIFEST_SHA256),
        "oldSupplementalManifest": (old_supplemental_path, OLD_SUPPLEMENTAL_MANIFEST_SHA256),
        "oldCrosswalk": (old_crosswalk_path, OLD_CROSSWALK_SHA256),
        "r18vGate": (r18v_gate_path, R18V_GATE_SHA256),
        "r18yProvider": (provider_path, R18Y_PROVIDER_SHA256),
        "r18yTest": (frozen_test_path, R18Y_TEST_SHA256),
        "r18yGate": (r18y_gate_path, R18Y_GATE_SHA256),
    }
    for name, (path, expected) in frozen_pins.items():
        if not path.is_file() or sha256_file(path) != expected:
            raise ValueError(f"Frozen predecessor pin mismatch: {name}")
    validate_new_source_chain(project, supplemental_path, crosswalk_path, build_gate_path)

    provider = load("argos_scribe_r18y_for_r18z_gate", provider_path)
    r11 = provider.R18V.R17D.R17C.R17B._load_r11()
    roots = {
        "glyphs": base_path.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": base_path.parent / "glyphs_v5_confirmed_20260806",
    }

    base_appearance, base_evidence = r11.load_reference_prototypes(
        base_path, BASE_MANIFEST_SHA256, roots
    )
    baseline_appearance, _ = provider.R18V.R18F.R18F_LOADER.combine_reference_prototypes(
        r11,
        base_appearance,
        base_evidence,
        old_supplemental_path,
        OLD_SUPPLEMENTAL_MANIFEST_SHA256,
    )
    baseline_topology = provider.R18V.R17D.load_topology_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        old_supplemental_path,
        OLD_SUPPLEMENTAL_MANIFEST_SHA256,
    )
    baseline_run = provider.R18V.R18H.load_run_structure_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        old_supplemental_path,
        OLD_SUPPLEMENTAL_MANIFEST_SHA256,
    )
    old_mapping, old_mapping_fingerprint = provider.load_lineage_mapping(
        old_crosswalk_path, OLD_CROSSWALK_SHA256
    )
    baseline_appearance = provider.rekey_prototypes(baseline_appearance, old_mapping)
    baseline_topology = provider.rekey_prototypes(baseline_topology, old_mapping)
    baseline_run = provider.rekey_prototypes(baseline_run, old_mapping)
    assert_aligned(baseline_appearance, baseline_topology, baseline_run)

    r18v_gate = read_json(r18v_gate_path)
    r18y_gate = read_json(r18y_gate_path)
    baseline_full_bank = provider.R18V.build_glyph_envelope_bank(
        baseline_topology, baseline_run
    )
    baseline_coverage = provider.R18V.coverage_evidence(baseline_full_bank)
    if baseline_coverage != r18v_gate.get("coverage") or baseline_coverage != r18y_gate.get("coverage"):
        raise ValueError("Frozen R18Y full-bank coverage no longer reproduces.")
    baseline_loo = run_loo(
        provider, r11, baseline_appearance, baseline_topology, baseline_run
    )
    frozen_expected = dict(r18y_gate.get("leaveOneExactScribeLineageOut", {}))
    for key, value in baseline_loo["summary"].items():
        if int(frozen_expected.get(key, -1)) != int(value):
            raise ValueError(f"Frozen R18Y LOO no longer reproduces {key}: {value}")
    if baseline_loo["acceptedCorrections"] != frozen_expected.get("acceptedCorrections"):
        raise ValueError("Frozen R18Y accepted corrections no longer reproduce.")
    if old_mapping_fingerprint != r18y_gate.get("mappingFingerprint"):
        raise ValueError("Frozen R18Y lineage mapping fingerprint changed.")

    new_supplements, supplement_evidence = validate_and_load_new_supplement(
        r11, supplemental_path, old_supplemental_path
    )
    new_appearance_raw = list(base_appearance) + new_supplements
    new_topology_raw = provider.R18V.R17D.load_topology_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        supplemental_path,
        NEW_SUPPLEMENTAL_MANIFEST_SHA256,
    )
    new_run_raw = provider.R18V.R18H.load_run_structure_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        supplemental_path,
        NEW_SUPPLEMENTAL_MANIFEST_SHA256,
    )

    baseline_appearance_raw, _ = provider.R18V.R18F.R18F_LOADER.combine_reference_prototypes(
        r11,
        base_appearance,
        base_evidence,
        old_supplemental_path,
        OLD_SUPPLEMENTAL_MANIFEST_SHA256,
    )
    baseline_topology_raw = provider.R18V.R17D.load_topology_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        old_supplemental_path,
        OLD_SUPPLEMENTAL_MANIFEST_SHA256,
    )
    baseline_run_raw = provider.R18V.R18H.load_run_structure_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        old_supplemental_path,
        OLD_SUPPLEMENTAL_MANIFEST_SHA256,
    )
    assert_bank_prefix(baseline_appearance_raw, new_appearance_raw, "appearance")
    assert_bank_prefix(baseline_topology_raw, new_topology_raw, "topology")
    assert_bank_prefix(baseline_run_raw, new_run_raw, "ordered-run")

    new_mapping, new_mapping_fingerprint, crosswalk = load_new_mapping(crosswalk_path)
    if len(old_mapping) != BASELINE_LINEAGE_COUNT or len(new_mapping) != NEW_LINEAGE_COUNT:
        raise ValueError("Exact-scribe lineage mapping cardinality changed.")
    for raw, lineage in old_mapping.items():
        if new_mapping.get(raw) != lineage:
            raise ValueError(f"R18Z changed predecessor lineage mapping: {raw}")
    new_appearance = rekey_prototypes(new_appearance_raw, new_mapping, NEW_REFERENCE_COUNT)
    new_topology = rekey_prototypes(new_topology_raw, new_mapping, NEW_REFERENCE_COUNT)
    new_run = rekey_prototypes(new_run_raw, new_mapping, NEW_REFERENCE_COUNT)
    assert_aligned(new_appearance, new_topology, new_run)
    assert_bank_prefix(baseline_appearance, new_appearance, "re-keyed appearance")
    assert_bank_prefix(baseline_topology, new_topology, "re-keyed topology")
    assert_bank_prefix(baseline_run, new_run, "re-keyed ordered-run")

    coverage, full_bank_fingerprint = verify_coverage(
        provider, new_topology, new_run, crosswalk
    )
    new_loo = run_loo(provider, r11, new_appearance, new_topology, new_run)
    baseline_accepted_correct = {
        int(row["referenceIndex"])
        for row in baseline_loo["queryResults"]
        if bool(row["acceptedCorrect"])
    }
    new_predecessor_accepted_correct = {
        int(row["referenceIndex"])
        for row in new_loo["queryResults"][:BASELINE_REFERENCE_COUNT]
        if bool(row["acceptedCorrect"])
    }
    lost = sorted(baseline_accepted_correct - new_predecessor_accepted_correct)
    gained = sorted(new_predecessor_accepted_correct - baseline_accepted_correct)
    new_queries = new_loo["queryResults"][BASELINE_REFERENCE_COUNT:]
    criteria = {
        "baselineReproducedExactly": True,
        "predecessorDescriptorsPreservedExactly": True,
        "predecessorAcceptedCorrectLostCount": len(lost),
        "acceptedWrong": int(new_loo["summary"]["acceptedWrong"]),
        "nonVacuousAcceptedCount": int(new_loo["summary"]["accepted"]),
        "all475QueriesEvaluated": int(new_loo["summary"]["referenceQueries"]) == NEW_REFERENCE_COUNT,
    }
    passed = (
        not lost
        and criteria["acceptedWrong"] == 0
        and criteria["nonVacuousAcceptedCount"] > 0
        and criteria["all475QueriesEvaluated"]
    )
    state = (
        "PASS_R18Z_ZERO_WRONG_ACCEPTED_EXACT_SCRIBE_LINEAGE_LOO"
        if passed
        else "HOLD_R18Z_EXACT_SCRIBE_LINEAGE_LOO_REGRESSION"
    )
    gate = {
        "schema": "argos_opencv_scribe_r18z_exact_scribe_lineage_loo_gate_v1",
        "state": state,
        "testSha256": sha256_file(Path(__file__)),
        "frozenAuthorities": {
            "baseManifestSha256": BASE_MANIFEST_SHA256,
            "r18fSupplementalManifestSha256": OLD_SUPPLEMENTAL_MANIFEST_SHA256,
            "r18xCrosswalkSha256": OLD_CROSSWALK_SHA256,
            "r18vGateSha256": R18V_GATE_SHA256,
            "r18yProviderSha256": R18Y_PROVIDER_SHA256,
            "r18yTestSha256": R18Y_TEST_SHA256,
            "r18yGateSha256": R18Y_GATE_SHA256,
        },
        "r18zAuthorities": {
            "builderSha256": BUILDER_SHA256,
            "sourceBindingGateSha256": SOURCE_BINDING_GATE_SHA256,
            "caseOutputsSha256": CASE_OUTPUTS_SHA256,
            "referenceBuildGateSha256": BUILD_GATE_SHA256,
            "supplementalManifestSha256": NEW_SUPPLEMENTAL_MANIFEST_SHA256,
            "exactScribeLineageCrosswalkSha256": NEW_CROSSWALK_SHA256,
            "mappingFingerprint": new_mapping_fingerprint,
        },
        "supplement": supplement_evidence,
        "coverage": coverage,
        "fullBankFingerprint": full_bank_fingerprint,
        "baselineReproduction": {
            **baseline_loo["summary"],
            "mappingFingerprint": old_mapping_fingerprint,
            "queryResultFingerprint": baseline_loo["queryResultFingerprint"],
            "acceptedCorrections": baseline_loo["acceptedCorrections"],
        },
        "leaveOneExactScribeLineageOut": {
            **new_loo["summary"],
            "exactFoldCount": new_loo["foldCount"],
            "queryResultFingerprint": new_loo["queryResultFingerprint"],
            "perLabel": new_loo["perLabel"],
            "acceptedCorrections": new_loo["acceptedCorrections"],
            "newReferenceQueries": new_queries,
        },
        "predecessorAcceptedCorrectRegression": {
            "frozenAcceptedCorrectCount": len(baseline_accepted_correct),
            "currentAcceptedCorrectCountForSame465Queries": len(new_predecessor_accepted_correct),
            "lostReferenceIndices": lost,
            "gainedReferenceIndices": gained,
        },
        "criteria": criteria,
        "nextAction": "UNTOUCHED_SLOT21_ONLY" if passed else "STOP_NO_SLOT21",
        "invariants": {
            "runtimeExpectedTruthUsedForSelection": False,
            "truthComparedOnlyAfterSelection": True,
            "checksumUsedForSelection": False,
            "lotOrSlotUsedAsReferenceLineageAuthority": False,
            "exactScribeLineageExcludedAsWholeFold": True,
            "syntheticDotsUsed": False,
            "notchUsed": False,
            "referenceBytesResampled": False,
            "identityAccepted": False,
            "providerActivationAuthorized": False,
            "xmlAuthorized": False,
            "trainingAuthorized": False,
            "productionAuthorized": False,
            "publicationAuthorized": False,
        },
    }
    payload = json.dumps(gate, indent=2, sort_keys=True) + "\n"
    if args.expected_output:
        if args.expected_output.read_text(encoding="utf-8") != payload:
            raise ValueError("R18Z LOO gate does not reproduce from frozen inputs.")
    else:
        output_root = args.output_root.resolve()
        if output_root.exists():
            raise FileExistsError(f"R18Z LOO output root already exists: {output_root}")
        if not output_root.parent.is_dir():
            raise FileNotFoundError(f"R18Z LOO output parent is missing: {output_root.parent}")
        output_root.mkdir()
        output_path = output_root / "R18Z_EXACT_LINEAGE_LOO_GATE.json"
        with output_path.open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(payload)
        print(f"gate={output_path}")
        print(f"gateSha256={sha256_file(output_path)}")
    print(state)
    return 0 if passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
